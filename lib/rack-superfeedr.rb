require 'base64'
require 'net/http'
require 'uri'

module Rack


  ##
  # This is a Rack Middleware that can be used in your rack-compatible web framework (Rails, Sinatra...) to perform subscriptions over at superfeedr
  # using the PubSubHubbub API.
  class Superfeedr

    @@superfeedr_endpoint = "https://push.superfeedr.com/"
    @@port = 80
    @@host = 'my-app.com'
    @@base_path = '/superfeedr/feed/'
    @@scheme = 'http'
    @@login = nil
    @@password = nil

    def self.superfeedr_endpoint= _superfeedr_endpoint
      @@superfeedr_endpoint = _superfeedr_endpoint
    end

    def self.port= _port
      @@port = _port
    end

    def self.host= _host
      @@host = _host
    end

    def self.base_path= _base_path
      @@base_path = _base_path
    end

    def self.scheme= _scheme
      @@scheme = _scheme
    end

    def self.login= _login
      @@login = _login
    end

    def self.password= _password
      @@password = _password
    end

    ##
    # Subscribe you to a url. id is optional but strongly recommanded has a unique identifier for this url. It will be used to help you identify which feed
    # is concerned by a notification.
    # A 3rd options argument can be supplied with
    # - retrive => true if you want to retrieve the previous items in the feed
    # - format => 'json' or 'atom' to specify the format of the notifications, defaults to atom
    # - secret => a secret string used to compyte HMAC signatures so you can check that the data is coming from Superfeedr
    # - sync => true (defaults to false) if you want to perfrom a verification of intent syncrhonously
    # - async => true  (defaults to false) if you want to perfrom a verification of intent asyncrhonously
    # - hub => if you want to use an explicit hub, defaults to Superfeedr's http://push.superfeedr.com
    # It yields 3 arguments to a block:
    # - body of the response (useful if you used the retrieve option)
    # - success flag 
    # - response (useful to debug failed requests mostly)
    def self.subscribe(url, id = nil, opts = {}, &blk)
      endpoint = opts[:hub] || @@superfeedr_endpoint
      request = prep_request(url, id, endpoint, opts)

      if opts[:retrieve]
        request['retrieve'] = true
      end
      
      if opts[:format] == "json"
        request['format'] = "json"
      end

      if opts[:secret]
        request['hub.secret'] = opts[:secret]
      else
        request['hub.secret'] = "WHAT DO WE PICK? A UNIQUE SCRET THE CALLBACK? SO WE CAN USE THAT ON NOTIFS?" 
      end
      
      request['hub.mode'] = 'subscribe'

      response = http_post(endpoint, request)

      blk.call(response.body, opts[:async] && Integer(response.code) == 202 || Integer(response.code) == 204 || opts[:retrieve] && Integer(response.code) == 200, response) if blk
    end

    ##
    # Unsubscribes a url. If you used an id for the susbcription, you need to use _the same_.
    # The optional block will be called to let you confirm the subscription (or not). This is not applicable for if you use params[:async] => true
    # It returns true if the unsubscription was successful (or will be confirmed if you used async => true in the options), false otherwise
    # You can also pass an opts third argument that will be merged with the options used in Typhoeus's Request (https://github.com/dbalatero/typhoeus)
    
    ##
    # Subscribe you to a url. id needs to match the id you used to subscribe. 
    # A 3rd options argument can be supplied with
    # - sync => true (defaults to false) if you want to perfrom a verification of intent syncrhonously
    # - async => true  (defaults to false) if you want to perfrom a verification of intent asyncrhonously
    # - hub => if you want to use an explicit hub, defaults to Superfeedr's http://push.superfeedr.com
    # It yields 3 arguments to a block:
    # - body of the response (useful to debug failed notifications)
    # - success flag 
    # - response (useful to debug failed requests mostly)
    def self.unsubscribe(url, id = nil, opts = {}, &blk)
      endpoint = opts[:hub] || @@superfeedr_endpoint
      request = prep_request(url, id, endpoint, opts)

      request['hub.mode'] = 'unsubscribe'

      response = http_post(endpoint, request)

      blk.call(response.body, opts[:async] && Integer(response.code) == 202 || Integer(response.code) == 204, response) if blk
    end

    ##
    # This allows you to define what happens with the notifications. The block passed in argument is called for each notification, with 4 arguments
    # - feed_id (used in subscriptions)
    # - body (Atom or JSON) based on subscription
    # - url (optional... if the hub supports that, Superfeedr does)
    # - Rack::Request object. Useful for debugging and checking signatures
    def on_notification(&block)
      @callback = block
    end

    ##
    # This allows you to define what happens with verification of intents
    # It's a block called with 
    # - mode: subscribe|unsubscribe
    # - Feed id (if available/supplied upon subscription)
    # - Feed url
    # - request (the Rack::Request object, should probably not be used, except for debugging)
    # If the block returns true, subscription will be confirmed
    # If it returns false, it will be denied
    def on_verification(&block)
      @verification = block
    end

    ##
    # Initializes the Rack Middleware
    # Make sure you define the following class attribues before that:
    # Rack::Superfeedr.superfeedr_endpoint => https://push.superfeedr.com, defaults (do not change!)
    # Rack::Superfeedr.host => Host for your application, used to build callback urls
    # Rack::Superfeedr.port =>  Port for your application, used to build callback urls, defaults to
    # Rack::Superfeedr.base_path => Base path for callback urls. Defauls to  '/superfeedr/feed/'
    # Rack::Superfeedr.scheme => Scheme to build callback urls, defaults to 'http'
    # Rack::Superfeedr.login => Superfeedr login
    # Rack::Superfeedr.password => Superfeedr password
    def initialize(app, &block)
      @app = app
      reset
      block.call(self)
      self
    end

    ##
    # Resets.
    def reset 
      @callback = Proc.new { |feed_id, body, url, request|
        # Nothing to do by default!
      }
      @verification = Proc.new { |mode, feed_id, url, request|
        true # Accept all by default!
      }
    end

    ##
    # Called by Rack!
    def call(env)
      req = Rack::Request.new(env)
      if env['REQUEST_METHOD'] == 'GET' && feed_id = env['PATH_INFO'].match(/#{@@base_path}(.*)/)
        puts "----"
        puts req.params['hub.mode'], feed_id[1], req.params['hub.topic']
        puts "----"
        if @verification.call(req.params['hub.mode'], feed_id[1], req.params['hub.topic'], req)
          Rack::Response.new(req.params['hub.challenge'], 200).finish
        else
          Rack::Response.new("not valid", 404).finish
        end
      elsif env['REQUEST_METHOD'] == 'POST' && feed_id = env['PATH_INFO'].match(/#{@@base_path}(.*)/)
        @callback.call(feed_id[1], req.body.read, req.env['HTTP_X_PUBSUBHUBBUB_TOPIC'], req)
        Rack::Response.new("Thanks!", 200).finish
      else
        @app.call(env)
      end
    end

    protected

    def self.prep_request(url, id, endpoint, opts)
      feed_id = "#{id ? id : Base64.urlsafe_encode64(url)}"

      request = {
        'hub.topic' => url,
        'hub.callback' =>  generate_callback(url, feed_id)
      }

      if endpoint == @@superfeedr_endpoint && @@login && @@password
        request['authorization'] = Base64.encode64( "#{@@login}:#{@@password}" ).chomp
      end

      if opts[:async]
        request['hub.verify'] = 'async'
      end

      if opts[:sync]
        request['hub.verify'] = 'sync'
      end

      request
    end

    def self.http_post(url, opts)
      uri = URI.parse URI.encode(url)
      uri.path=='/' if uri.path.empty?
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new uri.request_uri
      request.set_form_data (opts||{})
      http.request(request)
    end

    def self.generate_callback(url, feed_id)
      if @@scheme == "https"
        URI::HTTPS.build({:scheme => @@scheme, :host => @@host, :path => "#{@@base_path}#{feed_id}", :port => @@port }).to_s
      else
        URI::HTTP.build({:scheme => @@scheme, :host => @@host, :path => "#{@@base_path}#{feed_id}", :port => @@port }).to_s
      end
    end
  end
end
