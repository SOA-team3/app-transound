# frozen_string_literal: true


require 'roda'
require 'slim'
require 'slim/include'
require 'rack'


require_relative 'helpers'


TEMP_TOKEN_CONFIG = YAML.safe_load_file('config/temp_token.yml')


module EpisodeInfoAccessors
  def self.episode_info=(info)
    @episode_info = info
  end


  def self.episode_info
    @episode_info
  end


  def self.check=(info)
    @check = info
  end


  def self.check
    @check
  end
end


module TranSound
  # Application inherits from Roda
  class App < Roda
    include RouteHelpers


    include EpisodeInfoAccessors


    plugin :halt
    plugin :flash
    plugin :all_verbs # allows HTTP verbs beyond GET/POST (e.g., DELETE)
    plugin :caching
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/public'
    plugin :assets, path: 'app/presentation/assets',
                    css: 'style.css', js: ['table_row.js', 'scripts.js']
    plugin :common_logger, $stderr


    use Rack::MethodOverride # allows HTTP verbs beyond GET/POST (e.g., DELETE)


    route do |routing|
      routing.assets # load custom CSS
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public


      # GET /
      routing.root do
        # Get cookie viewer's previously seen podcast_infos
        session[:watching] ||= { episode_id: [], show_id: [] }


        session[:watching][:episode_id].insert(0, 'episode').uniq!
        session[:watching][:show_id].insert(0, 'show').uniq!


        puts "app.rb, Session watching: #{session[:watching].inspect}"


        episode_result = Service::ListEpisodes.new.call(session[:watching][:episode_id])
        show_result = Service::ListShows.new.call(session[:watching][:show_id])


        puts "session1: #{episode_result}"
        puts "session2: #{show_result}"


        if episode_result.failure?
          flash[:error] = episode_result.failure
          viewable_episodes = []
        else
          episodes = episode_result.value!.episodes
          flash.now[:notice] = 'Add a Spotify Podcast Episode or Show to get started' if episodes.none?
          session[:watching][:episode_id] = episodes.map(&:origin_id)
          viewable_episodes = Views::EpisodesList.new(episodes)
        end


        if show_result.failure?
          flash[:error] = show_result.failure
          viewable_shows = []
        else
          shows = show_result.value!.shows
          puts 'no show' if shows.none?
          flash.now[:notice] = 'Add a Spotify Podcast Episode or Show to get started' if shows.none?
          session[:watching][:show_id] = shows.map(&:origin_id)
          viewable_shows = Views::ShowsList.new(shows)
        end

        view 'home', locals: { episodes: viewable_episodes, shows: viewable_shows }
      end


      # podcast_info
      routing.on 'podcast_info' do
        TranSound::Podcast::Api::Token.new(App.config, App.config.spotify_Client_ID,
                                           App.config.spotify_Client_secret, TEMP_TOKEN_CONFIG).get
        puts "app.rb, routing on: #{TEMP_TOKEN_CONFIG}"


        routing.is do
          # POST /episode/ or /show/
          routing.post do
            url_requests = Forms::NewPodcastInfo.new.call(routing.params)
            type, id = url_requests.values[:spotify_url].split('/')[-2..]
            podcast_info_made = Service::AddPodcastInfo.new.call(url_requests)


            if podcast_info_made.failure?
              flash[:error] = podcast_info_made.failure
              routing.redirect '/'
            end


            puts "app, app.rb, type, id: #{type}, #{id}"
            podcast_info = podcast_info_made.value!
            puts "app, app.rb, podcast_info: #{podcast_info}"


            if type == 'episode'
              EpisodeInfoAccessors.check = 0
              EpisodeInfoAccessors.episode_info = OpenStruct.new(podcast_info)
              flash[:notice] = 'Episode added to your list'
              session[:watching][:episode_id].insert(0, id).uniq!
              routing.redirect "podcast_info/episode/#{id}"
            elsif type == 'show'
              # Add new podcast_info to watched set in cookies
              session[:watching][:show_id].insert(0, podcast_info.origin_id).uniq!
              flash[:notice] = 'Show added to your list'
              # Redirect viewer to show page
              routing.redirect "podcast_info/show/#{id}"
            end
          end
        end


        routing.on String, String do |type, id|
          # DELETE /podcast_info/{type}/{id}
          routing.delete do
            fullname = id.to_s


            if type == 'episode'
              session[:watching][:episode_id].delete(fullname)
            elsif type == 'show'
              session[:watching][:show_id].delete(fullname)
            end


            routing.redirect '/'
          end


          # GET /episode/id or /show/id
          routing.get do
            path_request = PodcastInfoRequestPath.new(
              type, id, request
            )


            session[:watching] ||= { episode_id: [], show_id: [] }


            if type == 'episode'
              episode_info = EpisodeInfoAccessors.episode_info
              puts "app, routing.get: #{episode_info}"


              if episode_info != nil
                if episode_info.response.processing?
                  if episode_info.response.processing? && EpisodeInfoAccessors.check == 0
                    puts 'app, app.rb, episode processing'
                    flash.now[:notice] = 'The episode is being processed...'


                    processing = Views::EpisodeProcessing.new(
                      App.config, episode_info.response
                    )


                    puts "processing: #{processing.inspect}"


                    EpisodeInfoAccessors.check = 1
                    episode_info = nil


                    view 'episode', locals: { check: EpisodeInfoAccessors.check, processing: }
                  else
                    puts 'app, app.rb, episode else'

                    result = Service::ViewPodcastInfo.new.call(
                      watched_list: session[:watching],
                      requested: path_request
                    )

                    if result.failure?
                      flash[:error] = result.failure
                      routing.redirect '/'
                    end

                    languages_dict = Views::LanguagesList.new.lang_dict
                    podcast_info = result.value!

                    puts "app.rb, routing.get, result: #{result}"

                    # Only use browser caching in production
                    App.configure :development, :test, :production do
                      response.expires 400, public: true
                    end

                    EpisodeInfoAccessors.check = 0
                    episode_info = nil

                    view 'episode',
                        locals: { check: EpisodeInfoAccessors.check, episode: podcast_info[:episodes],
                                  lang_dict: languages_dict }
                  end
                else
                  puts 'app, app.rb, episode else'


                  result = Service::ViewPodcastInfo.new.call(
                    watched_list: session[:watching],
                    requested: path_request
                  )


                  if result.failure?
                    flash[:error] = result.failure
                    routing.redirect '/'
                  end


                  languages_dict = Views::LanguagesList.new.lang_dict
                  podcast_info = result.value!


                  puts "app.rb, routing.get, result: #{result}"


                  # Only use browser caching in production
                  App.configure :development, :test, :production do
                    response.expires 400, public: true
                  end


                  EpisodeInfoAccessors.check = 0
                  episode_info = nil


                  view 'episode',
                      locals: { check: EpisodeInfoAccessors.check, episode: podcast_info[:episodes],
                                lang_dict: languages_dict }
                end
              else
                puts 'app, app.rb, episode else'


                result = Service::ViewPodcastInfo.new.call(
                  watched_list: session[:watching],
                  requested: path_request
                )


                if result.failure?
                  flash[:error] = result.failure
                  routing.redirect '/'
                end


                languages_dict = Views::LanguagesList.new.lang_dict
                podcast_info = result.value!


                puts "app.rb, routing.get, result: #{result}"


                # Only use browser caching in production
                App.configure :development, :test, :production do
                  response.expires 400, public: true
                end


                EpisodeInfoAccessors.check = 0
                episode_info = nil


                view 'episode',
                    locals: { check: EpisodeInfoAccessors.check, episode: podcast_info[:episodes],
                              lang_dict: languages_dict }


              end
            elsif type == 'show'
              result = Service::ViewPodcastInfo.new.call(
                watched_list: session[:watching],
                requested: path_request
              )


              if result.failure?
                flash[:error] = result.failure
                routing.redirect '/'
              end


              languages_dict = Views::LanguagesList.new.lang_dict
              podcast_info = result.value!


              puts "app.rb, routing.get, result: #{result}"


              # Only use browser caching in production
              App.configure :development, :test, :production do
                response.expires 400, public: true
              end


              view 'show', locals: { show: podcast_info[:shows], lang_dict: languages_dict }


            end


            # case type
            # when 'episode'
            #   view 'episode', locals: { episode: podcast_info[:episodes], lang_dict: languages_dict }
            # when 'show'
            #   view 'show', locals: { show: podcast_info[:shows], lang_dict: languages_dict }
            # else
            #   # Handle unknown URLs (unknown type)
            #   routing.redirect '/'
            # end
          end
        end
      end
    end
  end
end



