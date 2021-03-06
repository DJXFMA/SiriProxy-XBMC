# Copyright (C) 2011 by Rik Halfmouw <rik@iwg.nl>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


######
#  
#  Modified by: DJXFMA
#  Added: Many new features, and better advanced output with image.
#  
######


require 'cgi'
require 'cora'
require 'siri_objects'
require 'xbmc_library'
require 'chronic'

#######
# This is plugin to control XBMC
# Remember to configure the host and port for your XBMC computer in config.yml in the SiriProxy dir
######

class SiriProxy::Plugin::XBMC < SiriProxy::Plugin
	
	def initialize(config)
		appname = "SiriProxy-XBMC"
		@host = config["xbmc_host"]
		@port = config["xbmc_port"]
		username = config["xbmc_username"]
		password = config["xbmc_password"]

		@roomlist = Hash["default" => Hash["host" => @host, "port" => @port, "username" => username, "password" => password]]

		rooms = File.expand_path('~/.siriproxy/xbmc_rooms.yml')
		if (File::exists?( rooms ))
			@roomlist = YAML.load_file(rooms)
		end

		@active_room = @roomlist.keys.first

		@xbmc = XBMCLibrary.new(@roomlist, appname)
	end
	
	
	#show plugin status
	listen_for /[xX] *[bB] *[mM] *[cC] *(.*)/i do |roomname|
		roomname = roomname.downcase.strip
		roomcount = @roomlist.keys.length

		if (roomcount > 1 && roomname == "")
			say "You have #{roomcount} rooms, here is their status:"

			@roomlist.each { |name,room|
				if (@xbmc.connect(name))
					say "[#{name}] Online", spoken: "The #{name} is online"
				else
					say "[#{name}] Offline", spoken: "The #{name} is offline"
				end
			}
		else
			if (roomname == "")
				roomname = @roomlist.keys.first
			end
			if (roomname != "" && roomname != nil && @roomlist.has_key?(roomname))
				if (@xbmc.connect(roomname))
					say "XBMC is online"
				else 
					say "XBMC is offline, please check the plugin configuration and check if XBMC is running"
				end
			else
				say "There is no room defined called \"#{roomname}\""
			end
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# stop playing
	listen_for /^stop/i do 
		if (@xbmc.connect(@active_room))
			if @xbmc.stop()
				say "I stopped the video player"
			else
				say "There is no video playing"
			end
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# pause playing
	listen_for /^pause/i do 
		if (@xbmc.connect(@active_room))
			if @xbmc.pause()
				say "I paused the video player"
			else
				say "There is no video playing"
			end
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# resume playing
	listen_for /^resume|unpause|continue/i do 
		if (@xbmc.connect(@active_room))
			if @xbmc.pause()
				say "I resumed the video player", spoken: "Resuming video"
			else
				say "There is no video playing"
			end
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# now playing
	listen_for /now.*playing/i do
	  if (@xbmc.connect(@active_room))
		data = @xbmc.get_now_playing()["item"]
		
		#movie playing
		if(data["type"] == "movie")
			movie = @xbmc.get_movie(data["id"].to_i)["moviedetails"]
			
			#say
			say "Now playing \"#{movie["title"]}\"", spoken: "Now playing \"#{movie["title"]}\""
			
			#genres
			genres = ""
			movie["genre"].each do |genre|
				genres = "#{genre}, " + genres
			end
			
			#moviedetails
			encImgUrl = CGI.escape(movie["thumbnail"])
			imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
			@answers = []
			@answers << SiriAnswer.new(
				"\"#{movie["title"]} (#{movie["year"]})\"",[
					SiriAnswerLine.new("#{genres}"),
					SiriAnswerLine.new('image', imgUrl)
				]
			)
			
			#send object
			object = SiriAddViews.new
			object.make_root(last_ref_id)
			object.views << SiriAnswerSnippet.new(@answers)
			send_object object
			
			
		#episode playing
		elsif(data["type"] == "episode")
			episode = @xbmc.get_episode(data["id"].to_i)["episodedetails"]
			
			#say
			say "Now playing \"#{episode["title"]}\" (#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]})", spoken: "Now playing \"#{episode["title"]}\""
			
			#episodedetails
			encImgUrl = CGI.escape(episode["thumbnail"])
			imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
			@answers = []
			@answers << SiriAnswer.new(
				"#{episode["title"]}",[
					SiriAnswerLine.new("#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]}"),
					SiriAnswerLine.new('image', imgUrl)
				]
			)
			
			#send object
			object = SiriAddViews.new
			object.make_root(last_ref_id)
			object.views << SiriAnswerSnippet.new(@answers)
			send_object object
			
		end
	  end
	  request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# set default room
	# set default room
	listen_for /(?:(?:[Ii]'m in)|(?:[Ii] am in)|(?:[Uu]se)|(?:[Cc]ontrol)) the (.*)/i do |roomname|
		roomname = roomname.downcase.strip
		if (roomname != "" && roomname != nil && @roomlist.has_key?(roomname))
			@active_room = roomname
			say "Noted.", spoken: "Commands will be sent to the \"#{roomname}\""
		else
			say "There is no room defined called \"#{roomname}\""
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	#update library
        listen_for /^update my library/i do 
		if (@xbmc.connect(@active_room))
			@xbmc.update_library
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# recently added movies
	listen_for /recent.*movies/i do
	  if (@xbmc.connect(@active_room))
		movies = @xbmc.get_recently_added_movies()["movies"]
		
		#movies
		@answers = []
		movies.each do |movie|
			movie = @xbmc.get_movie(movie["movieid"].to_i)["moviedetails"]
			
			#genres
			genres = ""
			movie["genre"].each do |genre|
				genres = "#{genre}, " + genres
			end
			
			#moviedetails
			encImgUrl = CGI.escape(movie["thumbnail"])
			imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
			@answers << SiriAnswer.new(
				"\"#{movie["title"]} (#{movie["year"]})\"",[
					SiriAnswerLine.new("#{genres}"),
					SiriAnswerLine.new('image', imgUrl)
				]
			)
			
		end
		
		#say
		say "Here are your recently added movies"
		
		#send object
		object = SiriAddViews.new
		object.make_root(last_ref_id)
		object.views << SiriAnswerSnippet.new(@answers)
		send_object object
		
	  end
	  request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	# recently added episodes
	listen_for /recent.*episodes/i do 
	  if (@xbmc.connect(@active_room))
		episodes = @xbmc.get_recently_added_episodes()["episodes"]
		
		#episodes
		@answers = []
		episodes.each do |episode|
			episode = @xbmc.get_episode(episode["episodeid"].to_i)["episodedetails"]
			
			#episodedetails
			encImgUrl = CGI.escape(episode["thumbnail"])
			imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
			@answers << SiriAnswer.new(
				"#{episode["title"]}",[
					SiriAnswerLine.new("#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]}"),
					SiriAnswerLine.new('image', imgUrl)
				]
			)
			
		end
		
		#say
		say "Here are your recently added TV episodes"
		
		#send object
		object = SiriAddViews.new
		object.make_root(last_ref_id)
		object.views << SiriAnswerSnippet.new(@answers)
		send_object object
		
	  end
	  request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
	#play movie or episode
	listen_for /(?:(?:watch)|(?:what's)) (.+?)(?: in the (.*))?$/i do |title,roomname|
		if (roomname == "" || roomname == nil)
			roomname = @active_room
		else
			roomname = roomname.downcase.strip
		end

		if (@xbmc.connect(roomname))
			if @roomlist.has_key?(roomname)
				@active_room = roomname
			end

			tvshow = @xbmc.find_show(title.split(' season')[0])
			if (tvshow == "")
				movie = @xbmc.find_movie(title)
				if (movie == "")
					say "Title not found, please try again"
				else
					say "Now playing \"#{movie["title"]}\"", spoken: "Now playing \"#{movie["title"]}\""
					
					#genres
					genres = ""
					movie["genre"].each do |genre|
						genres = "#{genre}, " + genres
					end
					
					#Now playing Movie with Thumbnail
					encImgUrl = CGI.escape(movie["thumbnail"])
					imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
					    object = SiriAddViews.new
					    object.make_root(last_ref_id)
					    answer = SiriAnswer.new("\"#{movie["title"]} (#{movie["year"]})\"", [
						  SiriAnswerLine.new("#{genres}"),
						  SiriAnswerLine.new('logo', imgUrl)
					    ])
					    object.views << SiriAnswerSnippet.new([answer])
					    send_object object
						
					@xbmc.play(movie["file"])
				end
			else  
				numberized_title = Chronic::Numerizer.numerize(title)
				season_check = numberized_title.match('season \d+')
				if season_check
					season = season_check[0].match('\d+')[0].to_i
					episode_check = numberized_title.match('episode \d+')
					if episode_check
						episode = episode_check[0].match('\d+')
						episod = @xbmc.find_episode(tvshow["tvshowid"], season, episode)
						
						say "Now playing \"#{episod["title"]}\" (#{episod["showtitle"]}, Season #{episod["season"]}, Episode #{episod["episode"]})", spoken: "Now playing \"#{episod["title"]}\""
						
						#Now playing Episode with Thumbnail
						encImgUrl = CGI.escape(episod["thumbnail"])
						imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
							object = SiriAddViews.new
							object.make_root(last_ref_id)
							answer = SiriAnswer.new("#{episod["title"]}", [
								SiriAnswerLine.new("#{episod["showtitle"]}, Season #{episod["season"]}, Episode #{episod["episode"]}"),
								SiriAnswerLine.new('image', imgUrl)
							])
							object.views << SiriAnswerSnippet.new([answer])
							send_object object
						
						@xbmc.play(episod["file"])
						#search for spefic episode
					else
						#search for entire season 
						tvshow = @xbmc.play_season(tvshow["tvshowid"], season)
					end
				else
					episode = @xbmc.find_first_unwatched_episode(tvshow["tvshowid"])
					if (episode == "")
						say "No unwatched episode found for the \"#{tvshow["label"]}\""
					else    
						say "Now playing \"#{episode["title"]}\" (#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]})", spoken: "Now playing \"#{episode["title"]}\""
						
						#Now playing Episode with Thumbnail
						encImgUrl = CGI.escape(episode["thumbnail"])
						imgUrl = "http://#{@host}:#{@port}/image/" + encImgUrl
							object = SiriAddViews.new
							object.make_root(last_ref_id)
							answer = SiriAnswer.new("#{episode["title"]}", [
								SiriAnswerLine.new("#{episode["showtitle"]}, Season #{episode["season"]}, Episode #{episode["episode"]}"),
								SiriAnswerLine.new('image', imgUrl)
							])
							object.views << SiriAnswerSnippet.new([answer])
							send_object object
						
						@xbmc.play(episode["file"])
					end
				end
			end
		else 
			say "The XBMC interface is unavailable, please check the plugin configuration or check if XBMC is running"
		end
		request_completed #always complete your request! Otherwise the phone will "spin" at the user!
	end
	
	
end