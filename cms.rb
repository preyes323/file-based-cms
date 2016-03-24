require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'
require 'redcarpet'
require 'pry'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
  set :show_exceptions, :after_handler
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV['RACK_ENV'] == 'test'
                       File.expand_path('../test/users.yml', __FILE__)
                     else
                       File.expand_path('../users.yml', __FILE__)
                     end
  YAML.load_file(credentials_path)
end

before do
  @files = load_files(File.join(data_path, '*'))
end

get '/' do
  erb :index
end

get '/users/signin' do
  erb :signin
end

post '/users/signout' do
  session[:sucess] = "#{session.delete(:signed_in)} has been logged out."

  redirect '/'
end

post '/users/signin' do
  @username = params[:username]
  @password = params[:password]

  if valid_user?(@username, @password)
    session[:signed_in] = @username
    session[:success] = "#{@username} is now logged in."
    redirect '/'
  else
    session[:error] = 'Invalid Credentials'
    erb :signin
  end
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.exist? file_path
    load_file_content(file_path)
  else
    status 404
  end
end

get '/:filename/edit' do
  require_signed_in

  @file = params[:filename]
  file_path = File.join(data_path, @file)
  @content = File.read(file_path)

  erb :edit
end

get '/document/new' do
  require_signed_in
  erb :new
end

post '/:filename/delete' do
  require_signed_in

  @file = params[:filename]
  file_path = File.join(data_path, @file)
  File.delete(file_path)

  session[:success] = "#{@file} has been deleted."
  redirect '/'
end

post '/document/new' do
  require_signed_in

  filename = params[:filename]

  if !filename.empty? && (filename =~ /.txt/ || filename =~ /.md/)
    File.new(File.join(data_path, filename), 'w')
    session[:success] = "#{params[:filename]} has been created."
  else
    session[:error] = 'Failed to create new document'
  end

  redirect '/'
end

post '/:filename/edit' do
  file_path = File.join(data_path, params[:filename])
  File.write(file_path, params[:file_contents])

  session[:success] = "#{params[:filename]} has been updated."
  redirect '/'
end

error 404 do
  session[:error] = 'Sorry the file you are looking for does not exist (404)'
  redirect '/'
end

helpers do
  def load_files(path)
    Dir.glob(path).map { |file| File.basename(file) }
  end

  def load_file_content(file_path)
    content = File.read(file_path)

    case File.extname(file_path)
    when '.txt'
      headers['Content-Type'] = 'text/plain'
      content
    when '.md'
      erb render_markdown(content)
    end
  end

  def render_markdown(text)
    Redcarpet::Markdown.new(Redcarpet::Render::HTML).render(text)
  end

  def logged_in?
    session[:signed_in]
  end

  def require_signed_in
    unless logged_in?
      session[:error] = 'You must be logged in to do that'
      redirect '/'
    end
  end

  def valid_user?(username, password)
    credentials = load_user_credentials

    if credentials.key?(username)
      bcrypt_password = BCrypt::Password.new(credentials[username])
      bcrypt_password == password
    else
      false
    end
  end
end
