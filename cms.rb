require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require 'fileutils'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

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
    erb render_markdown(content)
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @filenames = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  @filenames.select! {|filename| filename =~ /.+\.(md||txt)/}
  erb :index
end

get '/new' do
  erb :new
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if FileTest.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = File.join(data_path, params[:filename])

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
  file_path = File.join(data_path, params[:filename])

  if FileTest.exist?(file_path)
    File.write(file_path, params[:content])
    session[:message] = "#{params[:filename]} has been updated."
    redirect "/"
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

post '/create' do
  filename = params[:filename].strip
  if filename.empty? || filename == '.md' || filename == '.txt'
    status 422
    session[:message] = "A name is required."
    erb :new
  elsif !(filename =~ /.+\.(md||txt)\z/)
    status 422
    session[:message] = "File must have either a .md or .txt extension"
    erb :new
  else
    FileUtils.touch(File.join(data_path, filename))
    session[:message] = "#{filename} has been created."
    redirect '/'
  end
end

