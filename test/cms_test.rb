ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'test/spec'
require 'fileutils'

require_relative '../cms.rb'

describe 'File-base CMS test' do
  include Rack::Test::Methods

  before(:each) do
    FileUtils.mkdir_p(data_path)
  end

  after(:each) do
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def admin_session
    { 'rack.session' => { signed_in: 'admin' } }
  end

  def session
    last_request.env['rack.session']
  end

  def app
    Sinatra::Application
  end

  it 'displays the list of text files on the index page' do
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'

    last_response.status.should.equal 200
    last_response['Content-Type'].should.equal 'text/html;charset=utf-8'
    last_response.body.should.include 'about.md'
    last_response.body.should.include 'changes.txt'
  end

  it 'displays the content of the history file' do
    create_document 'changes.txt', 'Duis'

    get '/changes.txt'

    last_response.status.should.equal 200
    last_response['Content-Type'].should.equal 'text/plain'
    last_response.body.should.include 'Duis'
  end

  it 'displays a message and returns to index page if not found' do
    get '/not_found.txt'

    session[:error].should.equal 'Sorry the file you are looking for does not exist (404)'
    last_response.status.should.equal 302
  end

  it 'renders a markdown page' do
    create_document 'about.md', '# Dummy'
    get '/about.md'

    last_response.status.should.equal 200
    last_response['Content-Type'].should.equal 'text/html;charset=utf-8'
    last_response.body.should.include '<h1>Dummy'
  end

  it 'loads a page for editing file content' do
    create_document 'changes.txt', 'Duis'
    get '/changes.txt/edit', {}, admin_session

    last_response.status.should.equal 200
    last_response['Content-Type'].should.equal 'text/html;charset=utf-8'
    last_response.body.should.include '<form'
    last_response.body.should.include %q(<button type='submit')
  end

  it 'saves the changes to an edited file' do
    create_document 'changes.txt', 'Duis'
    post '/changes.txt/edit', { file_contents: 'new content' }, admin_session

    last_response.status.should.equal 302
    get last_response['Location']
    last_response['Content-Type'].should.equal 'text/html;charset=utf-8'
    last_response.body.should.include 'changes.txt has been updated.'

    get '/'
    last_response.status.should.equal 200
    last_response.body.should.not.include 'changes.txt has been updated.'

    get '/changes.txt'
    last_response['Content-Type'].should.equal 'text/plain'
    last_response.body.should.include 'new content'
  end

  it 'displays a page for creating a new document' do
    get '/document/new', {}, admin_session

    last_response.status.should.equal 200
    last_response.body.should.include '<form'
    last_response.body.should.include %q(<button type='submit')
    last_response.body.should.include 'Add a new document:'
  end

  it 'creates a new document and redirects the user to the index page' do
    post '/document/new', { filename: 'New Document.txt' }, admin_session

    last_response.status.should.equal 302
    get last_response['Location']

    last_response.body.should.include 'New Document.txt has been created.'
  end

  it 'fails to create a new document for empty name and informs the user' do
    post '/document/new', { filename: '' }, admin_session

    last_response.status.should.equal 302
    get last_response['Location']


    last_response.body.should.include 'Failed to create new document'
  end

  it 'fails to create a new document for no extension  and informs the user' do
    post '/document/new', { filename: 'New Document' }, admin_session

    last_response.status.should.equal 302
    get last_response['Location']

    last_response.body.should.include 'Failed to create new document'
  end

  it 'deletes a document' do
    create_document 'changes.txt', 'Duis'

    post '/changes.txt/delete', {}, admin_session

    last_response.status.should.equal 302
    get last_response['Location']

    last_response.body.should.include 'changes.txt has been deleted.'
  end

  it 'gives an option to delete in the index page' do
    create_document 'changes.txt', 'Duis'

    get '/'

    last_response.body.should.include 'delete'
    last_response.body.should.include '<a href'
  end

  it 'logs in a user' do
    post '/users/signin', { username: 'admin', password: '123' }

    last_response.status.should.equal 302
    get last_response['Location']

    last_response.body.should.include 'admin is now logged in.'
    last_response.body.should.include 'Sign out'
    last_response.body.should.not.include 'Sign in'
  end

  it 'allows a logged out user to sign in' do
    get '/'

    last_response.status.should.equal 200
    last_response.body.should.include "<button type='submit'"
    last_response.body.should.include 'Sign in'

    get '/users/signin'

    last_response.body.should.include "<label for='username'"
    last_response.body.should.include "<label for='password'"
    last_response.body.should.include 'Sign in'
  end

  it 'retains the username when a user has provided invalid credentials' do
    post '/users/signin', { username: 'admin', password: '1' }

    last_response.status.should.equal 200
    last_response.body.should.include 'Invalid Credentials'
    last_response.body.should.include 'admin'
  end
end
