require 'json'
require 'rack'
require_relative 'helper.rb'

# To run tests locally, we're using runscope's passageway which proxies requests inside the firewall. (make sure you bind to port 4567)
HOST = '5f83728c358.b.passageway.io'
PORT = 80
# Also, we need superfeedr credentials.
LOGIN = 'demo'
PASSWORD = '8ac38a53cc32f71a6445e880f76fc865'


class MyRackApp
	def call(env)
		[ 200, {'Content-Type' => 'text/plain'}, ['hello world'] ]
	end
end

def notified(url, feed_id, details)
	# puts url, feed_id, details
end

# Run an app in a thread
Thread.new do
	Rack::Handler::WEBrick.run(Rack::Superfeedr.new(MyRackApp.new) do |superfeedr|
	
	superfeedr.on_verification do |mode, feed_id, url, request|
		if mode == 'subscribe' && feed_id == 'accept-subscribe'
			true
		elsif mode == 'unsubscribe' && feed_id == 'accept-unsubscribe'
			true
		else
			false
		end
	end	

	superfeedr.on_notification do |url, feed_id, details|
		notified(url, feed_id, details)
	end	


	end, :Port => 4567, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [],) 
end
sleep 3

# Configure the middleware
Rack::Superfeedr.host = HOST
Rack::Superfeedr.port = PORT
Rack::Superfeedr.login = LOGIN
Rack::Superfeedr.password = PASSWORD

class TestRackSuperfeedr < Test::Unit::TestCase

	context "Subscribing" do

		should "yield true with a simple subscribe" do 
			Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '12345') do |body, success, response|
				success || flunk("Fail")
			end
		end

		should "support sync mode and call the verification callback before yielding true" do 
			Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', 'accept-subscribe', {:sync => true}) do |body, success, response|
				success || flunk("Fail")
			end
		end

		should "support sync mode and call the verification callback before yielding false if verification fails" do 
			Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', 'refuse-subscribe', {:sync => true}) do |body, success, response|
				!success || flunk('Fail')
			end
		end

		should "support async mode and yield true" do 
			Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', 'refuse-subscribe', {:async => true}) do |body, success, response|
				success || flunk("Fail")
			end
		end

		should "return the content of Atom subscriptions with retrieve" do 
			Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '1234', {:retrieve => true}) do |body, success, response|
				assert_equal "application/atom+xml", response['Content-Type']
				success || flunk("Fail")
				assert body # Some XML
			end
		end

		should "return the content of Json subscriptions with retrieve" do 
			response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '1234', {:format => "json", :retrieve => true})  do |body, success, response|
				assert_equal "application/json; charset=utf-8", response['Content-Type']
				success || flunk("Fail")
				assert body
			end
		end

	end

	context "Unsubscribing" do
		should 'successfully unsubscribe with 204 when not using sync nor asyc' do
			Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', '12345') do |body, success, response|
				success || flunk("Fail")
			end
		end

		should 'successfully unsubscribe with 204 when using sync when verification yields true' do
			Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', 'accept-unsubscribe', {:sync => true}) do |body, success, response|
				success || flunk("Fail")
			end
		end

		should 'fail to unsubscribe with 204 when using sync when verification yields false'  do
			Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', 'refuse-unsubscribe', {:sync => true}) do |body, success, response|
				!success || flunk('Fail')
			end
		end

		should 'return 202 when using async' do
			Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', 'accept-unsubscribe', {:async => true}) do |body, success, response|
				success || flunk("Fail")
			end
		end
	end

	context "Retrieving" do
		should 'yield content from Superfeedr in Atom when asking for no specific format' do
			Rack::Superfeedr.retrieve_by_topic_url('http://push-pub.appspot.com/feed') do |body, success, response|
				success || flunk("Fail")
			end			
		end

		should 'yield content from Superfeedr in JSON when asking for JSON' do
			Rack::Superfeedr.retrieve_by_topic_url('http://push-pub.appspot.com/feed', {:format => 'json'}) do |body, success, response|
				success || flunk("Fail")
				hash = JSON.parse body
				hash['status'] || flunk("Not JSON")
			end			
		end

		should 'yield content from Superfeedr in JSON when asking for JSON and only yield the right number of items' do
			Rack::Superfeedr.retrieve_by_topic_url('http://push-pub.appspot.com/feed', {:format => 'json', :count => 3}) do |body, success, response|
				success || flunk("Fail")
				hash = JSON.parse body
				hash['items'].length == 3 || flunk("Not the right number of items")
			end			
		end
	end

	context "Notifications" do
		should 'handle json notifications' 
		should 'handle atom notifications'
		should 'handle error notification (with no entry in them)'
	end

end
