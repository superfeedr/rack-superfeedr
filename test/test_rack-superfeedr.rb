require 'json'
require 'rack'
require_relative 'helper.rb'

# To run tests locally, we're using runscope's passageway which proxies requests inside the firewall. (make sure you bind to port 4567)
HOST = '3bbb3b2e39fe.a.passageway.io'
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
	opts = {
		:Port => 4567, 
		# Logger: WEBrick::Log.new("/dev/null"), 
		AccessLog: []
	}
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


	end, opts) 
end
sleep 3

# Configure the middleware
Rack::Superfeedr.host = HOST
Rack::Superfeedr.port = PORT
Rack::Superfeedr.login = LOGIN
Rack::Superfeedr.password = PASSWORD

class TestRackSuperfeedr < Test::Unit::TestCase

	context "Without Callbacks" do

		context "Listing" do
			should "yield a list of subscriptions" do
				body, success, response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '12345')
				success || flunk("Could not subscribe")
				body, success, response = Rack::Superfeedr.list
				success || flunk("Could not list #{body}")
				hash = JSON.parse body
				hash["subscriptions"] || flunk("List empty")
			end
		end

		context "Subscribing" do

			should "yield true with a simple subscribe" do 
				body, success, response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '12345')
				success || flunk("Fail")
			end

			should "support sync mode and call the verification callback before yielding true" do 
				body, success, response =  Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', 'accept-subscribe', {:sync => true}) 
				success || flunk("Fail")
			end

			should "support sync mode and call the verification callback before yielding false if verification fails" do 
				body, success, response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', 'refuse-subscribe', {:sync => true})
				!success || flunk('Fail')
			end

			should "support async mode and yield true" do 
				body, success, response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', 'refuse-subscribe', {:async => true})
				success || flunk("Fail")
			end

			should "return the content of Atom subscriptions with retrieve" do 
				body, success, response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '1234', {:retrieve => true})
				assert_equal "application/atom+xml", response['Content-Type']
				success || flunk("Fail")
				assert body 
			end

			should "return the content of Json subscriptions with retrieve" do 
				body, success, response = Rack::Superfeedr.subscribe('http://push-pub.appspot.com/feed', '1234', {:format => "json", :retrieve => true})
				assert_equal "application/json; charset=utf-8", response['Content-Type']
				success || flunk("Fail")
				assert body
			end
		end

		context "Unsubscribing" do
			should 'successfully unsubscribe with 204 when not using sync nor asyc' do
				body, success, response = Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', '12345')
				success || flunk("Fail")
			end

			should 'successfully unsubscribe with 204 when using sync when verification yields true' do
				body, success, response = Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', 'accept-unsubscribe', {:sync => true})
				success || flunk("Fail")
			end

			should 'fail to unsubscribe with 204 when using sync when verification yields false'  do
				body, success, response = Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', 'refuse-unsubscribe', {:sync => true}) 
				!success || flunk('Fail')
			end

			should 'return 202 when using async' do
				body, success, response = Rack::Superfeedr.unsubscribe('http://push-pub.appspot.com/feed', 'accept-unsubscribe', {:async => true})
				success || flunk("Fail")
			end
		end

		context "Retrieving" do
			should 'yield content from Superfeedr in Atom when asking for no specific format' do
				body, success, response = Rack::Superfeedr.retrieve_by_topic_url('http://push-pub.appspot.com/feed')
				success || flunk("Fail")
			end			

			should 'yield content from Superfeedr in JSON when asking for JSON' do
				body, success, response = Rack::Superfeedr.retrieve_by_topic_url('http://push-pub.appspot.com/feed', {:format => 'json'})
				success || flunk("Fail")
				hash = JSON.parse body
				hash['status'] || flunk("Not JSON")
			end			

			should 'yield content from Superfeedr in JSON when asking for JSON and only yield the right number of items' do
				body, success, response = Rack::Superfeedr.retrieve_by_topic_url('http://push-pub.appspot.com/feed', {:format => 'json', :count => 3}) 
				success || flunk("Fail")
				hash = JSON.parse body
				hash['items'].length == 3 || flunk("Not the right number of items")
			end			
		end

		context "Searching" do
			should 'yield content from Superfeedr in Atom when asking for no specific format' do
				body, success, response = Rack::Superfeedr.search('superfeedr', {:login => 'tracker', :password => 'a0234221feebbd9c1ee30d33a49c505d'})
				success || flunk("Fail")
			end			

			should 'yield content from Superfeedr in JSON when asking for JSON' do
				body, success, response = Rack::Superfeedr.search('superfeedr', {:login => 'tracker', :password => 'a0234221feebbd9c1ee30d33a49c505d', :format => 'json'})
				success || flunk("Fail")
				hash = JSON.parse body
				hash['status'] || flunk("Not JSON")
			end			

		end
	end

	context "With Callbacks" do

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
					assert body 
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
	end

	context "Notifications" do
		should 'handle json notifications' 
		should 'handle atom notifications'
		should 'handle error notification (with no entry in them)'
	end

end
