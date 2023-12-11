# frozen_string_literal: true

require 'dry/transaction'

module TranSound
  module Service
    # retrieve podcast info
    class ViewPodcastInfo
      include Dry::Transaction

      step :validate_podcast_info
      step :retrieve_podcast_info
      step :reify_view_podcast_info

      private

      # Steps

      def validate_podcast_info(input)
        requested = input[:requested]
        type = requested.type

        if type == 'episode'
          handle_validate_episode(requested, input)
        elsif type == 'show'
          handle_validate_show(requested, input)
        end
      end

      def handle_validate_episode(requested, input)
        if input[:watched_list][:episode_id].include? requested.id
          Success(input)
        else
          Failure('Please first request this episode to be added to your list')
        end
      end

      def handle_validate_show(requested, input)
        if input[:watched_list][:show_id].include? requested.id
          Success(input)
        else
          Failure('Please first request this show to be added to your list')
        end
      end

      def retrieve_podcast_info(input)
        result = Gateway::Api.new(TranSound::App.config)
          .view(input[:requested])

        result.success? ? Success(result.payload) : Failure(result.message)
      rescue StandardError
        Failure('Cannot view podcast info right now. Please try again later')
      end

      def reify_view_podcast_info(view_podcast_info_json)
        requested = input[:requested]
        type = requested.type

        if type == 'episode'
          Representer::Episode.new(Struct.new)
            .from_json(view_podcast_info_json)
            .then { |view_podcast_info| Success(view_podcast_info) }
        elsif type == 'show'
          Representer::Show.new(Struct.new)
            .from_json(view_podcast_info_json)
            .then { |view_podcast_info| Success(view_podcast_info) }
        end
      rescue StandardError
        Failure('Error in our podcast info -- please try again')
      end
    end
  end
end
