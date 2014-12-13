module Padrino
  module Cache
    ##
    # Helpers supporting page or fragment caching within a request route.
    #
    module Helpers
      ##
      # Page caching is easy to integrate into your application. To turn it on, simply provide the
      # <tt>:cache => true</tt> option on either a controller or one of its routes.
      # By default, cached content is persisted with a "file store" --that is, in a
      # subdirectory of your application root.
      #
      # @example
      #   # Setting content expiry time.
      #   class CachedApp < Padrino::Application
      #     enable :caching          # turns on caching mechanism
      #
      #     controller '/blog', :cache => true do
      #       expires 15
      #
      #       get '/entries' do
      #         # expires 15 => can also be defined inside a single route
      #         'Just broke up eating twinkies, lol'
      #       end
      #
      #       get '/post/:id' do
      #         cache_key :my_name
      #         @post = Post.find(params[:id])
      #       end
      #     end
      #   end
      #
      # You can manually expire cache with CachedApp.cache.delete(:my_name)
      #
      # Note that the "latest" method call to <tt>expires</tt> determines its value: if
      # called within a route, as opposed to a controller definition, the route's
      # value will be assumed.
      #
      module Page
        ##
        # This helper is used within a controller or route to indicate how often content
        # should persist in the cache.
        #
        # After <tt>seconds</tt> seconds have passed, content previously cached will
        # be discarded and re-rendered. Code associated with that route will <em>not</em>
        # be executed; rather, its previous output will be sent to the client with a
        # 200 OK status code.
        #
        # @param [Integer] time
        #   Time til expiration (seconds)
        #
        # @example
        #   controller '/blog', :cache => true do
        #     expires 15
        #
        #     get '/entries' do
        #       'Just broke up eating twinkies, lol'
        #     end
        #   end
        #
        # @api public
        def expires(time)
          @route.cache_expires = time
        end

        ##
        # This helper is used within a route or route to indicate the name in the cache.
        #
        # @param [Symbol] name
        #   cache key
        # @param [Proc] block
        #   block to be evaluated to cache key
        #
        # @example
        #   controller '/blog', :cache => true do
        #
        #     get '/post/:id' do
        #       cache_key :my_name
        #       @post = Post.find(params[:id])
        #     end
        #   end
        #
        # @example
        #     get '/foo', :cache => true do
        #       cache_key { param[:id] }
        #       "My id is #{param[:id}"
        #     end
        #   end
        #
        def cache_key(name = nil, &block)
          fail "Can not provide both cache_key and a block" if name && block
          @route.cache_key = name || block
        end

        CACHED_VERBS = { 'GET' => true, 'HEAD' => true }.freeze

        def load_cached_response
          began_at = Time.now
          route_cache_key = resolve_cache_key || env['PATH_INFO']

          value = settings.cache[route_cache_key]
          logger.debug "GET Cache", began_at, route_cache_key if defined?(logger) && value

          value
        end

        def save_cached_response(cache_expires)
          response_body = @_response_buffer || response.body.last
          return unless response_body.kind_of?(String)

          began_at = Time.now
          route_cache_key = resolve_cache_key || request.env['PATH_INFO']

          content = {
            :body         => response_body,
            :content_type =>  response.content_type
          }

          settings.cache.store(route_cache_key, content, :expires => cache_expires)

          logger.debug "SET Cache", began_at, route_cache_key if defined?(logger)
        end

        ##
        # Resolve the cache_key when it's a block in the correct context.
        #
        def resolve_cache_key
          return unless @route
          key = @route.cache_key
          key.is_a?(Proc) ? instance_eval(&key) : key
        end

        def cache_expired?
          settings.caching? && @__caching_route && !@__cache_available
        end

        CACHE_VARIABLES = [:cache_available, :cache_expires, :caching_route].freeze

        def reset_cache_variables
          CACHE_VARIABLES.each do |name|
            remove_instance_variable(:"@#{name}") if instance_variable_defined?(:"@#{name}")
          end
        end

        module ClassMethods
          ##
          # A method to set `expires` time inside `controller` blocks.
          #
          # @example
          #   controller :users do
          #     expires 15
          #
          #     get :show do
          #       'shown'
          #     end
          #   end
          #
          def expires(time)
            @_expires = time
          end

          def cache(*args)
            if cache_condition?(args)
              cache_expires = @_expires
              if expires = extract_expires(args)
                cache_expires = expires
              end
              condition do
                return true unless settings.caching? && Padrino::Cache::Helpers::Page::CACHED_VERBS[request.request_method]
                cache_expires = @route.cache_expires if @route && @route.cache_expires
                @__cache_expires = cache_expires
                @__caching_route = true
                if cached_response = load_cached_response
                  @__cache_available = true
                  content_type cached_response[:content_type]
                  halt 200, cached_response[:body]
                end
              end
            else
              settings.cache_adapter
            end
          end

          private

          def extract_expires(args)
            head = args.pop
            head.kind_of?(Hash) ? head[:expires] : nil
          end

          def cache_condition?(args)
            if args.empty?
              false
            elsif args.length == 1 
              !!args.first
            else
              args
            end
          end
        end
      end
    end
  end
end
