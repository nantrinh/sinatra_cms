require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'super_secret'
end

root = File.expand_path("..", __FILE__)
puts root

get '/' do
  @filenames = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :index
end

get '/:filename' do
  file_path = "data/#{params[:filename]}"
  if FileTest.file?(file_path)
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end
