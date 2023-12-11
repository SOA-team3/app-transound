# frozen_string_literal: true

require 'dry/monads'

module TranSound
  module Service
    # Retrieves array of all listed episode entities
    class ListEpisodes
      include Dry::Transaction

      step :get_api_list
      step :reify_list

      private

      def get_api_list(episodes_list)
        Gateway::Api.new(TranSound::App.config)
          .episodes_list(episodes_list)
          .then do |result|
            result.success? ? Success(result.payload) : Failure(result.message)
          end
      rescue StandardError
        Failure('Could not access our API')
      end

      def reify_list(episodes_json)
        Representer::EpisodesList.new(Struct.new)
          .from_json(episodes_json)
          .then { |episodes| Success(episodes) }
      rescue StandardError
        Failure('Could not parse response from API')
      end
    end

    # Retrieves array of all listed show entities
    class ListShows
      include Dry::Transaction

      step :get_api_list
      step :reify_list

      private

      def get_api_list(shows_list)
        Gateway::Api.new(TranSound::App.config)
          .shows_list(shows_list)
          .then do |result|
            result.success? ? Success(result.payload) : Failure(result.message)
          end
      rescue StandardError
        Failure('Could not access our API')
      end

      def reify_list(shows_list)
        Representer::ShowsList.new(Struct.new)
          .from_json(shows_list)
          .then { |shows| Success(shows) }
      rescue StandardError
        Failure('Could not parse response from API')
      end
    end
  end
end
