require 'sinatra'
require(File.join(File.dirname(__FILE__), '..', 'lib', 'rack-superfeedr.rb'))


use Rack::Superfeedr, { :host => "pstx.showoff.io", :login => "julien", :password => "f8054b405e68aa2067df25fb21665bab", :format => "json", :async => false } do |superfeedr|
  set :superfeedr, superfeedr # so that we can use `settings.superfeedr` to access the superfeedr object in our application.

  superfeedr.on_notification do |notification|
    puts notification.to_s # You probably want to persist that data in some kind of data store...
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

