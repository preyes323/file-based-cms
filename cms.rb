require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'
require 'redcarpet'
require 'pry'

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

before do
  @files = load_files(File.join(data_path, '*'))
end

get '/' do
  erb :index
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])
  load_file_content(file_path)
end

get '/:filename/edit' do
  @file = params[:filename]
  file_path = File.join(data_path, @file)
  @content = File.read(file_path)

  erb :edit
end

post '/:filename/edit' do
  file_path = File.join(data_path, params[:filename])
  File.write(file_path, params[:file_contents])

  session[:success] = "#{params[:filename]} has been updated."
  redirect '/'
end

error 404 do
  session[:error] = 'Sorry the file you are looking for does not exist'
  redirect '/'
end

error 500 do
  session[:error] = 'Sorry the file you are looking for does not exist'
  redirect '/'
end

error do
  session[:error] = 'Sorry there was error - ' + env['sinatra.error'].message
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
      render_markdown(content)
    end
  end

  def render_markdown(text)
    Redcarpet::Markdown.new(Redcarpet::Render::HTML).render(text)
  end
end