ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_viewing_text_document
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
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"    
  end

  def test_viewing_edit_document_form
    get '/changes.txt/edit'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "</form>"    
    assert_includes last_response.body, "</textarea>"
  end

  def test_updating_document
    post '/changes.txt/edit', content: 'new content'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, "changes.txt has been updated."    

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end
end
