require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

get "/" do
  @filenames = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end

get "/:filename" do
  file_path = root + "/data/" + params[:filename]

  if FileTest.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = root + "/data/" + params[:filename]

  if FileTest.exist?(file_path)
    @filename = params[:filename]
    @content = File.read(file_path)
    erb :edit
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

post "/:filename/edit" do
  file_path = root + "/data/" + params[:filename]

  if FileTest.exist?(file_path)
    File.write(file_path, params[:content])
    session[:message] = "#{params[:filename]} has been updated."
    redirect "/"
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

