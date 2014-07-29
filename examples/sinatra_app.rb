require 'sinatra'
require (File.join(File.dirname(__FILE__), '..', 'lib', 'rack-superfeedr.rb'))


# Configure the middleware
Rack::Superfeedr.host = "37cb3f2fe113.a.passageway.io"
Rack::Superfeedr.login = "demo"
Rack::Superfeedr.password = "8ac38a53cc32f71a6445e880f76fc865"


use Rack::Superfeedr do |superfeedr|

  superfeedr.on_notification do |feed_id, body, url, request|
    puts "------"
    puts feed_id # You need to have supplied one upon subscription
    puts "------"
    puts body # The body of the notification, a JSON or ATOM string, based on the subscription. Use the Rack::Request object for details
    puts "------"
    puts url # The feed url
    puts "------"
  end

end

 # Maybe serve the data you saved from Superfeedr's handler.
get '/hi' do
  "Hello World!"
end

# Subscription
# Will subscribe to "http://push-pub.appspot.com/feed" and retrieve past items
# The block will yield the result: its body (useful for error or when retrieveing, a success flag and the Net::HTTP::Post)
get '/subscribe' do
  Rack::Superfeedr.subscribe("http://push-pub.appspot.com/feed", 9999, {retrieve: true }) do |body, success, response|
    body
  end
end

# Unsubscription
# Wull unsubscribe
get '/unsubscribe' do
  Rack::Superfeedr.unsubscribe("http://push-pub.appspot.com/feed")
end

