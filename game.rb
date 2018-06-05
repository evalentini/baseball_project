load 'string.rb'
require 'open-uri'
require 'nokogiri'
require 'mysql2'

class Game 

	attr_accessor :gid
	
	def parsegamestring(game_string) 
		g_array=game_string.split("_")
		g_hash={:year=>g_array[1], :month=>g_array[2], :day=>g_array[3]}
		g_hash[:awayt]=g_array[4].sub("mlb","")
		g_hash[:homet]=g_array[5].sub("mlb","")
		g_hash[:gnum]=g_array[6]
		g_hash 
	end 

	def game_url
		url="https://gd2.mlb.com/components/game/mlb"
		url+="/year_#{gid[:year].to_s}"
		url+="/month_#{gid[:month].to_s.date_with_zero}"
		url+="/day_#{gid[:day].to_s.date_with_zero}"
		url+="/"+self.gid_string+"/boxscore.xml"
		url
	end 

	def gid_string 
		day_wz=gid[:day].to_s.date_with_zero
		month_wz=gid[:month].to_s.date_with_zero
		gids="gid_"+gid[:year].to_s+"_"+month_wz
		gids+="_"+day_wz
		gids+="_"+gid[:awayt]+"mlb"
		gids+="_"+gid[:homet]+"mlb"
		gid[:gnum]=1 if gid[:gnum].nil? 
		gids+="_"+gid[:gnum].to_s
		gids
	end 

	def game_score 

		#record score 
		score={}
		puts "game url is ---#{self.game_url}---"
		doc = Nokogiri::HTML(open(self.game_url))
		at=doc.xpath("//linescore").attribute("away_team_runs").value 
		ht=doc.xpath("//linescore").attribute("home_team_runs").value	
		score[:at_runs]=at
		score[:ht_runs]=ht
		score
	
	end  

	def batting_lines

		#connect to db
		client = self.db_connect

		#add plate appearance information 
		#get url for hitters 
		hitter_folder_url=self.game_url.sub('boxscore.xml', 'batters')
		hitter_list=Nokogiri::HTML(open(hitter_folder_url))
		hitter_list.xpath("//a").each do |hitter|
			
			if hitter.attribute('href').value =~ /batters\/[0-9]+\.xml/
				hitter_pa_url=self.game_url.sub('boxscore.xml', hitter.attribute('href').value)	
				#pull PA data for hitter
				pa_data=Nokogiri::HTML(open(hitter_pa_url))
				#delete all records for given player and given game 
				player_tag = pa_data.xpath('//player')
				player_team=player_tag.attribute('team').value
				hitter_id=player_tag.attribute('id').value
				hitter_name=player_tag.attribute('first_name').value+" "+player_tag.attribute('last_name').value
				deletesyntax="DELETE FROM plateappearances WHERE gid='#{self.gid_string}' AND "
				deletesyntax+="hitter_id=#{pa_data.xpath('//player').attribute('id').value};"
				client.query(deletesyntax)
				ab_counter=0
				pa_data.xpath('//ab').each do |ab|
					ab_counter+=1
					pa_variables=["gid", "hitter_id", "hitter_name", "game_ab", "inning", "event", "team"]
					pa_values=[self.gid_string, hitter_id, hitter_name, ab_counter, ab.attribute('inning').value, ab.attribute('event').value, player_team]								
					client.query("test".insert_syntax('plateappearances', pa_values, pa_variables))		
					puts "test".insert_syntax('plateappearances', pa_values, pa_variables)
				end 
			end 
		end 
	end 

	def add_game_score 
		#connect to db
		client = self.db_connect

		#delete game from db if exists 
		client.query("DELETE FROM games WHERE gid='#{self.gid_string}';")

		#add game to db

		variable_names=["gid", "home_team_name", "away_team_name", "home_team_score", "away_team_score", "gdate"]
		score=self.game_score 
		gdate=self.gid[:year].to_s+"-"+self.gid[:month].to_s.date_with_zero+"-"+self.gid[:day].to_s.date_with_zero
		values=[self.gid_string, self.gid[:homet], self.gid[:awayt], score[:ht_runs], score[:at_runs], gdate]
		client.query("test".insert_syntax('games', values, variable_names))
		
	end 	

	def db_connect
				client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")
				client
	end 

end 





