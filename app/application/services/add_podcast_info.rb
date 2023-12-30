# frozen_string_literal: true

require 'dry/transaction'

TEMP_TOKEN_CONFIG = YAML.safe_load_file('config/temp_token.yml')

module TranSound
  module Service
    # Transaction to store episode from Spotify API to database
    class AddPodcastInfo
      include Dry::Transaction

      step :validate_input
      step :request_podcast_info
      step :reify_podcast_info

      private

      def validate_input(input)
        puts "add_podcast_info1: #{input.inspect}"
        if input.success?
          @type, id = input.values[:spotify_url].split('/')[-2..]
          Success(type: @type, id:)
        else
          Failure("URL #{input.errors.messages.first}")
        end
      end

      def request_podcast_info(input)
        if @type == 'episode'
          handle_request_episode(input)
        elsif @type == 'show'
          handle_request_show(input)
        end
      rescue StandardError => e
        puts e.inspect
        puts e.backtrace
        Failure('Cannot add podcast info right now; please try again later')
      end

      def reify_podcast_info(input_json)
        puts "add: #{input_json}"
        if @type == 'episode'
          handle_reify_episode(input_json)
        elsif @type == 'show'
          handle_reify_show(input_json)
        end
      rescue StandardError => e
        App.logger.error e.backtrace.join("\n")
        Failure('Error in the podcast info -- please try again')
      end

      # following are support methods that other services could use

      def handle_request_episode(input)
        result = Gateway::Api.new(TranSound::App.config)
          .add_episode(input[:type], input[:id])
        result.success? ? Success(result.payload) : Failure(result.message)
      end

      def handle_request_show(input)
        result = Gateway::Api.new(TranSound::App.config)
          .add_show(input[:type], input[:id])
        result.success? ? Success(result.payload) : Failure(result.message)
      end

      def handle_reify_episode(episode_json)
        puts "episode_json: #{episode_json}"
        Representer::Episode.new(OpenStruct.new)
          .from_json(episode_json)
          .then { |episode| Success(episode) }
      end

      def handle_reify_show(show_json)
        puts "show_json: #{show_json}"
        Representer::Show.new(OpenStruct.new)
          .from_json(show_json)
          .then { |show| Success(show) }
      end
    end
  end
end
