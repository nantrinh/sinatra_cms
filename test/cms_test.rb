ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require 'fileutils'

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env['rack.session']
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_nil session[:username]
  end

  def test_view_text_document
    create_document '/history.txt', 'Ruby 0.95 released'

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_document_not_found
    get "/notafile.ext"
    assert_equal 302, last_response.status
    assert_equal "notafile.ext does not exist.", session[:message]
  end

  def test_view_markdown_document
    create_document '/about.md', '# Ruby is...'
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"    
  end

  def test_view_edit_document_form
    create_document '/changes.txt'

    get '/changes.txt/edit'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "</form>"    
    assert_includes last_response.body, "</textarea>"
  end

  def test_update_document
    create_document '/changes.txt'

    post '/changes.txt/edit', content: 'new content'
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end

  def test_view_new_file_form
    get '/new'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<button type"
    assert_includes last_response.body, "</form>"
  end

  def test_create_new_document
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_equal "A name is required", session[:message]
  end

  def test_create_new_document_without_filename
    post "/create", filename: "sperlonga"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "File must have either a .md or .txt extension"  end

  def test_delete_document
    create_document 'test.txt'
    post '/test.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'test.txt has been deleted.', session[:message]

    get '/test.txt'
    assert_equal 302, last_response.status
  end

  def test_view_signin_form
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(form method="post")
    assert_includes last_response.body, %q(button type="submit")
  end

  def test_successful_signin
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]

    get '/' 
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_failed_signin
    post '/users/signin', username: 'incorrect', password: 'combination'
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"  
  end

  def test_signout
    post '/users/signin', username: 'admin', password: 'secret'
    get last_response['Location']

    post '/users/signout'
    assert_equal 302, last_response.status
    assert_equal 'You have been signed out.', session[:message]

    get '/'
    assert_includes last_response.body, 'Sign In'
  end
end
