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
  end

  def test_viewing_text_document
    create_document '/history.txt', 'Ruby 0.95 released'

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_document_not_found
    get "/notafile.ext"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"

    get "/"
    refute_includes last_response.body, "notafile.ext does not exist"
  end

  def test_viewing_markdown_document
    create_document '/about.md', '# Ruby is...'
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"    
  end

  def test_viewing_edit_document_form
    create_document '/changes.txt'

    get '/changes.txt/edit'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "</form>"    
    assert_includes last_response.body, "</textarea>"
  end

  def test_updating_document
    create_document '/changes.txt'

    post '/changes.txt/edit', content: 'new content'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, "changes.txt has been updated."    

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end

  def test_viewing_new_file_form
    get '/new'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<button type"
    assert_includes last_response.body, "</form>"
  end

  def test_create_new_document
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_create_new_document_without_filename
    post "/create", filename: "sperlonga"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "File must have either a .md or .txt extension"
  end
end
