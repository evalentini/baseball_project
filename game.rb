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
		#check if rained out 
		score[:partofseason]='reg'
		maxinning=1
		doc.xpath('//inning_line_score').each {|inning| maxinning=inning.attribute('inning').value.to_i if inning.attribute('inning').value.to_i>maxinning} 
		puts "---------#{maxinning}-----"		
		score[:partofseason]='rain' if maxinning<5		
		score
	
	end  

	def batting_lines

		#connect to db
		client = $globalClient

		#get url for innings 
		inning_file_url=self.game_url.sub('boxscore.xml', 'inning/inning_all.xml')
		puts inning_file_url		
		inning_file=Nokogiri::HTML(open(inning_file_url))
		game_file=Nokogiri::HTML(open(self.game_url))
		outcomes={}
		pitchers={}
		inning_file.xpath('//atbat').each do |atbat|
			if outcomes[atbat.attribute('batter').value].nil?
				outcomes[atbat.attribute('batter').value]=[]
				pitchers[atbat.attribute('batter').value]=[]
				outcomes[atbat.attribute('batter').value][0]=atbat.attribute('event').value	
				pitchers[atbat.attribute('batter').value][0]=atbat.attribute('pitcher').value
			else 
				outcomes[atbat.attribute('batter').value].push(atbat.attribute('event').value)
				pitchers[atbat.attribute('batter').value].push(atbat.attribute('pitcher').value) 
			end 
		end 	
		outcomes.each do |hitter_id,events|
			
			#delete all of players at bats from given game 
			deletesyntax="DELETE FROM plateappearances WHERE gid='#{self.gid_string}' AND "
			deletesyntax+="hitter_id=#{hitter_id};"
			client.query(deletesyntax)
			
			#add at bat detail
			ab_counter=0 
			events.each do |outcome|
				ab_counter+=1
				pa_variables=["gid", "hitter_id", "hitter_name", "game_ab", "event", "team", "gdate", "partofseason", "pitcher_id"]
				#get hitters name 
				hitter_name=game_file.xpath("//batter[@id=\"#{hitter_id}\"]").first.attribute('name_display_first_last').value
				#get picther id 
				pitcher_id=pitchers[hitter_id][ab_counter-1]
				#get batters team 
				home_or_away=game_file.xpath("//batter[@id=\"#{hitter_id}\"]").first.ancestors.first.attribute('team_flag').value
				home_or_away=="away" ? player_team=self.gid[:awayt] : player_team=self.gid[:homet]
				pos=client.query("SELECT partofseason as partofseason from games where gid='#{self.gid_string}'").first["partofseason"]
				gdate=self.gid[:year].to_s.date_with_zero+"-"+self.gid[:month].to_s.date_with_zero+"-"+self.gid[:day].to_s.date_with_zero
				pa_values=[self.gid_string, hitter_id, hitter_name, ab_counter, outcome, player_team, gdate, pos, pitcher_id]
	
				client.query("test".insert_syntax('plateappearances', pa_values, pa_variables))
				
			end 

			
		end 
		#check if link is to one of the inning files 

		#add plate appearance information 
		#get url for hitters 
		#hitter_folder_url=self.game_url.sub('boxscore.xml', 'batters')
		#hitter_list=Nokogiri::HTML(open(hitter_folder_url))
		#hitter_list.xpath("//a").each do |hitter|
			
		#	if hitter.attribute('href').value =~ /batters\/[0-9]+\.xml/
		#		hitter_pa_url=self.game_url.sub('boxscore.xml', hitter.attribute('href').value)	
		#		#pull PA data for hitter
		#		pa_data=Nokogiri::HTML(open(hitter_pa_url))
		#		#delete all records for given player and given game 
		#		player_tag = pa_data.xpath('//player')
		#		player_team=player_tag.attribute('team').value
		#		hitter_id=player_tag.attribute('id').value
		#		hitter_name=player_tag.attribute('first_name').value+" "+player_tag.attribute('last_name').value
		#		deletesyntax="DELETE FROM plateappearances WHERE gid='#{self.gid_string}' AND "
		#		deletesyntax+="hitter_id=#{pa_data.xpath('//player').attribute('id').value};"
		#		client.query(deletesyntax)
		#		ab_counter=0
		#		pa_data.xpath('//ab').each do |ab|
		#			ab_counter+=1
		#			pa_variables=["gid", "hitter_id", "hitter_name", "game_ab", "inning", "event", "team"]
		#			pa_values=[self.gid_string, hitter_id, hitter_name, ab_counter, ab.attribute('inning').value, ab.attribute('event').value, player_team]								
		#			client.query("test".insert_syntax('plateappearances', pa_values, pa_variables))		
		#			puts "test".insert_syntax('plateappearances', pa_values, pa_variables)
		#		end 
		#	end 
		#end 
	end 

	def add_game_score 
		#connect to db
		client = $globalClient

		#delete game from db if exists 
		client.query("DELETE FROM games WHERE gid='#{self.gid_string}';")

		#add game to db

		variable_names=["gid", "home_team_name", "away_team_name", "home_team_score", "away_team_score", "gdate", "partofseason"]
		score=self.game_score 
		gdate=self.gid[:year].to_s+"-"+self.gid[:month].to_s.date_with_zero+"-"+self.gid[:day].to_s.date_with_zero
		values=[self.gid_string, self.gid[:homet], self.gid[:awayt], score[:ht_runs], score[:at_runs], gdate, score[:partofseason]]
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





