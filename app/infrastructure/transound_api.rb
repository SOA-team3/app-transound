# frozen_string_literal: true

require_relative 'list_request'
require 'http'

module TranSound
  module Gateway
    # Infrastructure to call TranSound API
    class Api
      # Infrastructure to call TranSound API
      def initialize(config)
        @config = config
        @request = Request.new(@config)
      end

      def alive?
        @request.get_root.success?
      end

      def episodes_list(list)
        @request.episodes_list(list)
      end

      def add_episode(type, id)
        @request.add_episode(type, id)
      end

      def shows_list(list)
        @request.shows_list(list)
      end

      def add_show(type, id)
        @request.add_show(type, id)
      end

      # Gets view of a podcast info for episode or show from API
      # - req: PodcastInfoRequestPath
      #        with #type, #id
      def view(req)
        @request.view_podcast_info(req)
      end

      # HTTP request transmitter
      class Request
        def initialize(config)
          @api_host = config.API_HOST
          @api_root = "#{config.API_HOST}/api/v1"
        end

        def get_root # rubocop:disable Naming/AccessorMethodName
          call_api('get')
        end

        def episodes_list(list)
          call_api('get', ['podcast_info/episode'],
                   'list' => Value::WatchedList.to_encoded(list))
        end

        def add_episode(type, id)
          call_api('post', ['podcast_info', type, id])
        end

        def shows_list(list)
          puts "api, shows_list: #{shows_list}"
          call_api('get', ['podcast_info/show'],
                   'list' => Value::WatchedList.to_encoded(list))
        end

        def add_show(type, id)
          puts "api, add_show: #{type} + #{id}"
          call_api('post', ['podcast_info', type, id])
        end

        def view_podcast_info(req)
          call_api('get', ['podcast_info', req.type, req.id])
        end

        private

        def params_str(params)
          params.map { |key, value| "#{key}=#{value}" }.join('&')
            .then { |str| str ? "?#{str}" : '' }
        end

        def call_api(method, resources = [], params = {})
          api_path = resources.empty? ? @api_host : @api_root
          url = [api_path, resources].flatten.join('/') + params_str(params)
          puts "api: #{url}"
          HTTP.headers('Accept' => 'application/json').send(method, url)
            .then { |http_response| Response.new(http_response) }
        rescue StandardError
          raise "Invalid URL request: #{url}"
        end
      end

      # Decorates HTTP responses with success/error
      class Response < SimpleDelegator
        NotFound = Class.new(StandardError)

        SUCCESS_CODES = (200..299)

        def success?
          code.between?(SUCCESS_CODES.first, SUCCESS_CODES.last)
        end

        def message
          payload['message']
        end

        def payload
          body.to_s
        end
      end
    end
  end
end
