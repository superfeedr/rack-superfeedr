require 'sinatra'
require 'rack-superfeedr'

use Rack::Superfeedr, { :host => "1pqz.showoff.io", :login => "demo", :password => "demo", :format => "json", :async => false } do |superfeedr|
  set :superfeedr, superfeedr # so that we can use `settings.superfeedr` to access the superfeedr object in our application.
  
  superfeedr.on_notification do |notification|
    puts notification.to_s # You probably want to persist that data in some kind of data store...
  end
  
end

get '/hi' do
  "Hello World!" # Maybe serve the data you saved from Superfeedr's handler.
end

get '/subscribe' do
  settings.superfeedr.subscribe("http://push-pub.appspot.com/feed") 
end

get '/unsubscribe' do
  settings.superfeedr.unsubscribe("http://push-pub.appspot.com/feed")
end

