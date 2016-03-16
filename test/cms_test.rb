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

    last_response.status.should.equal 302
    get last_response['Location']

    last_response.status.should.equal 200
    last_response['Content-Type'].should.equal 'text/html;charset=utf-8'
    last_response.body.should.include 'Sorry'
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
    get '/changes.txt/edit'

    last_response.status.should.equal 200
    last_response['Content-Type'].should.equal 'text/html;charset=utf-8'
    last_response.body.should.include '<form'
    last_response.body.should.include %q(<button type='submit')
  end

  it 'saves the changes to an edited file' do
    create_document 'changes.txt', 'Duis'
    post '/changes.txt/edit', file_contents: 'new content'

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
end
