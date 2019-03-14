require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require 'fileutils'
require 'yaml'
require 'bcrypt'

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

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
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
  require_signed_in_user
  erb :new
end

get '/users/signin' do
  erb :signin
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
  require_signed_in_user
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

post '/users/signin' do
  credentials = load_user_credentials
  username = params[:username]
  if valid_credentials?(username, params[:password]) 
    session[:username] = username 
    session[:message] = 'Welcome!'
    redirect '/'
  else
    status 422
    session[:message] = 'Invalid Credentials'
    erb :signin
  end
end

post '/users/signout' do
  session[:username] = nil
  session[:message] = 'You have been signed out.'
  redirect '/'
end

post "/:filename/edit" do
  require_signed_in_user
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
  require_signed_in_user
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

post '/:filename/delete' do
  require_signed_in_user
  file_path = File.join(data_path, params[:filename])

  if FileTest.exist?(file_path)
    File.delete(file_path)
    session[:message] = "#{params[:filename]} has been deleted."
    redirect "/"
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end
