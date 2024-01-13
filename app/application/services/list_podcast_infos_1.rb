module TranSound
  module Service
    # Retrieves array of all listed episode entities
    class ViewListEpisodes
      include Dry::Monads::Result::Mixin

      def call(episodes_list)
        puts "episodes_list_test: #{episodes_list}"
        # Load previously viewed episodes
        episodes = Repository::For.klass(Entity::Episode)
          .find_podcast_infos(episodes_list)

        Success(episodes)
      rescue StandardError
        Failure('Could not access database')
      end
    end
  end
end

module TranSound
  module Service
    # Retrieves array of all listed show entities
    class ViewListShows
      include Dry::Monads::Result::Mixin

      def call(shows_list)
        puts "showslist_test: #{shows_list}"
        shows = Repository::For.klass(Entity::Show)
          .find_podcast_infos(shows_list)

        Success(shows)
      rescue StandardError
        Failure('Could not access database')
      end
    end
  end
end
