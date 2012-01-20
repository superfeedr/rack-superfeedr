require 'sinatra'
require 'rack-superfeedr'

use Rack::Superfeedr, { :host => "plant-leg.showoff.io", :login => "demo", :password => "demo", :format => "json", :async => false } do |superfeedr|
  Superfeedr = superfeedr
end

get '/hi' do
  "Hello World!" # Maybe serve the data you saved from Superfeedr's handler.
end

get '/subscribe' do
  Superfeedr.subscribe("http://push-pub.appspot.com/feed", 123) 
end

get '/unsubscribe' do
  Superfeedr.unsubscribe("http://push-pub.appspot.com/feed", 123)
end

Superfeedr.on_notification do |notification|
  puts notification.to_s # You probably want to persist that data in some kind of data store...
end
