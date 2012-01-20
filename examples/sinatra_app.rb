require 'sinatra'
require 'rack-superfeedr'

use Rack::Superfeedr, { :host => "plant-leg.showoff.io", :login => "demo", :password => "demo", :format => "json", :async => false } do |superfeedr|
  Superfeedr = superfeedr
  superfeedr.on_notification do |notification|
    puts notification.to_s
  end
end

get '/hi' do
  "Hello World!"
end

get '/subscribe' do
  Superfeedr.subscribe("http://push-pub.appspot.com/feed", 123) 
end

get '/unsubscribe' do
  Superfeedr.unsubscribe("http://push-pub.appspot.com/feed", 123)
end