require 'sinatra'
require(File.join(File.dirname(__FILE__), '..', 'lib', 'rack-superfeedr.rb'))


use Rack::Superfeedr, {:scheme => 'http', :host => "9cfc62cb6bf.a.passageway.io", :login => "demo", :password => "8ac38a53cc32f71a6445e880f76fc865", :format => 'json'} do |superfeedr|
  set :superfeedr, superfeedr # so that we can use `settings.superfeedr` to access the superfeedr object in our application.

  superfeedr.on_notification do |notification, feed_id, info|
    puts notification.to_s # You probably want to persist that data in some kind of data store...
    puts "------"
    puts feed_id
    puts "------"
    puts info[:body] # Mostly you're interested in info[:body] which includes a text version of the notification.
    puts "------"
  end

end

get '/hi' do
  "Hello World!" # Maybe serve the data you saved from Superfeedr's handler.
end

get '/subscribe' do
  subscription = settings.superfeedr.subscribe("http://push-pub.appspot.com/feed", 9999, { verbose: true, retrieve: true })
  if !subscription
    settings.superfeedr.error
  else
    'Subscribed'
  end
end

get '/unsubscribe' do
  settings.superfeedr.unsubscribe("http://push-pub.appspot.com/feed")
end

