
#questions for Phil: 
##1.) How can I create a local variable in the linux terminal that I can use to save my password? Can't even remember the terminology for this. 

##2.) How could I write a script to automatically create the local database and correct tables?


#create table hitters (gid varchar(100), id INT, name VARCHAR(200), atbats INT, hits INT, walks INT, hbp INT, sacrifice INT, homeruns INT, slugging float, team VARCHAR(100)) 

#create table plateappearances (gid varchar(100), hitter_id INT, hitter_name VARCHAR(100), game_ab INT, inning INT, event VARCHAR(200), UNIQUE (gid, hitter_id,game_ab));

#in order to get this to work you'll need a mysql database instance installed with a database called baseball_data and a user called baseball with full access to baseball database 
##CREATE DATABASE baseball_data 
##GRANT ALL PRIVILEGES ON *.* TO 'baseball'@'localhost' IDENTIFIED BY 'baseballrocks';
##CREATE TABLE games (gid VARCHAR(100), home_team_name VARCHAR(100), away_team_name VARCHAR(100), home_team_score INT, away_team_score INT, gdate DATE, UNIQUE(gid));

#the baseball database has a games table with home and away team names and run totals along with game id 

require 'open-uri'
require 'nokogiri'
require 'mysql2'
#load 'player.rb'

class Game 

	attr_accessor :gid
	
	def self.parsegamestring(game_string) 
		g_array=game_string.split("_")
		g_hash={:year=>g_array[1], :month=>g_array[2], :day=>g_array[3]}
		g_hash[:awayt]=g_array[4].sub("mlb","")
		g_hash[:homet]=g_array[5].sub("mlb","")
		g_hash[:gnum]=g_array[6]
		g_hash 
	end 

	def self.openingday
		puts "hello, its opening day!" 
	end 

	def game_url
		url="https://gd2.mlb.com/components/game/mlb"
		url+="/year_#{gid[:year].to_s}"
		url+="/month_#{gid[:month].to_s.date_with_zero}"
		url+="/day_#{gid[:day].to_s.date_with_zero}"
		url+="/"+self.gid_string+"/boxscore.xml"
		puts url		
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
		doc = Nokogiri::HTML(open(self.game_url))
		at=doc.xpath("//linescore").attribute("away_team_runs").value 
		ht=doc.xpath("//linescore").attribute("home_team_runs").value	
		score[:at_runs]=at
		score[:ht_runs]=ht
		score
	
	end  

	def batting_lines(doc)
		#connect to db
		client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")

		doc.xpath("//batting").each do |teambatting|
				teambatting.xpath('.//batter').each do |batter|
					#delete records if they already exist (at most 1 record per batter)
					deletesyntax="DELETE FROM hitters WHERE gid='#{self.gid_string}' AND id=#{batter.attribute('id').value};"
					insertsyntax = "INSERT INTO hitters (gid, id, name, atbats, hits, walks, hbp, sacrifice, homeruns, team) VALUES ("
					insertsyntax+="'#{self.gid_string}', #{batter.attribute("id").value}, "
					insertsyntax+="'#{batter.attribute('name_display_first_last')}', "
					insertsyntax+="#{batter.attribute('ab').value}, "
					insertsyntax+="#{batter.attribute('h').value}, "
					insertsyntax+="#{batter.attribute('bb').value}, "
					insertsyntax+="#{batter.attribute('hbp').value}, "
					insertsyntax+="#{batter.attribute('sac').value}, "
					insertsyntax+="#{batter.attribute('hr').value}, "
					batter_team=self.gid[:awayt]
					batter_team=self.gid[:homet] if teambatting.attribute('team_flag').value=='home'
					insertsyntax+="'#{batter_team}');"

					client.query(deletesyntax)
					client.query(insertsyntax)
				end 
		end

		#add plate appearance information 
		#get url for hitters 
		hitter_folder_url=self.game_url.sub('boxscore.xml', 'batters')
		puts hitter_folder_url
		hitter_list=Nokogiri::HTML(open(hitter_folder_url))
		hitter_list.xpath("//a").each do |hitter|
			if hitter.attribute('href').value =~ /batters\/[0-9]+\.xml/
				hitter_pa_url=self.game_url.sub('boxscore.xml', hitter.attribute('href').value)	
				#pull PA data for hitter
				pa_data=Nokogiri::HTML(open(hitter_pa_url))
				pa_data.xpath('//ab').each do |ab|
					puts ab.attribute("event").value				
				end 
			end 
		end 
		
  
	end 

	def add_game_score 
		#connect to db
		client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")
		sql_syntax="INSERT INTO games (gid, home_team_name, away_team_name, home_team_score, away_team_score, gdate) VALUES ("
		score=self.game_score 
		sql_syntax+="'#{self.gid_string}', "
		sql_syntax+="'#{self.gid[:homet]}', "
		sql_syntax+="'#{self.gid[:awayt]}', "
		sql_syntax+="#{score[:ht_runs]}, "
		sql_syntax+="#{score[:at_runs]}, "
		sql_syntax+="'#{self.gid[:year].to_s}"+"-"
		sql_syntax+="#{self.gid[:month].to_s.date_with_zero}"+"-"
		sql_syntax+="#{self.gid[:day].to_s.date_with_zero}'"
		sql_syntax+=");"
		sql_syntax
		#delete game from db if exists 
		client.query("DELETE FROM games WHERE gid='#{self.gid_string}';")
		client.query(sql_syntax)
		
	end 
end 

class Season
	attr_accessor :year
	
	def savescores 
		base_url="https://gd2.mlb.com/components/game/mlb/year_#{self.year.to_s}"
		for month in 9..12 do 
			#pull month data 
			url=base_url+"/month_"+month.to_s.date_with_zero+"/"
			#loop through all days 
			month_doc=Nokogiri::HTML(open(url))
			month_doc.xpath("//a").each do |a|
				#check whether link is to a day 
				if a.attribute("href").value =~ /day/
					day_url=url+a.attribute("href").value.sub("/","")
					#pull out games for each day 
					day_doc=Nokogiri::HTML(open(day_url))
					day_doc.xpath("//a").each do |day_a|
						if day_a.attribute("href").value =~ /gid/
							#check whether game has a boxscore 
							game_path=url+day_a.attribute("href").value
							game_doc=Nokogiri::HTML(open(game_path))
							game_doc.xpath("//a").each do |game_a|
								if game_a.attribute("href").value =~ /boxscore/
									box_path=game_path+"boxscore.xml"
									gid_string=day_a.attribute("href").value.split("/").last
									#puts gid_string
									#confirm both teams are MLB teams 
									if gid_string.split("_")[4] =~ /mlb/ and gid_string.split("_")[5] =~ /mlb/
										current_game=Game.new
										current_game.gid=Game.parsegamestring(gid_string)
										current_game.add_game_score
										puts  current_game.gid
									end 
								end 
							end 				
						end 
					end 
				end  
			end 
		end 		
	end

	def winpct(team_name) 
		result={}
		client=self.dbconnect
		winquery="select count(*) as wincount from games where season=#{self.year} and partofseason='reg'and ((home_team_name='#{team_name}' and home_team_score > away_team_score) or (away_team_name='#{team_name}' and away_team_score > home_team_score));"
		
		wins=client.query(winquery).first["wincount"]
		losses=162-wins
		result[:wins]=wins
		result[:losses]=losses
		return wins.to_f / (wins.to_f + losses.to_f) 
	end   

	def standings(division)
		client=self.dbconnect
		team_query="SELECT name from teams where division='#{division}';"
		teams=client.query(team_query)
		result=[]
		teams.each do |team|
			result.push({:name => team["name"], :winpct => self.winpct(team["name"]), :wins => self.winpct(team["name"])*162})
		end 
		puts result 
		
	end 

	def dbconnect
				client = Mysql2::Client.new(:host => "localhost", 
				:username => "baseball", 
				:password => "baseballrocks", 
				:db => "baseball_data")

				return client 
	end 

end 

class String 
	def date_with_zero 
		if self.to_i<10 then "0"+self.to_i.to_s
		else self
		end  	
	end 
end 

#https://gd2.mlb.com/components/game/mlb/year_2010/month_03/day_02/gid_2010_03_02_atlmlb_nynmlb_1/boxscore.xml

#https://gd2.mlb.com/components/game/mlb/year_2010/month_03/day_02/gid_2010_03_02_flsbbcmlb_detmlb_1/boxscore.xml

#https://gd2.mlb.com/components/game/mlb/year_2010/month_03/day_02/gid_2010_03_02_flsbbc_detmlb_1/

#notes 

#to change working directory in irb: (1) Dir.getwd() to find out current directory (2) Dir.chdir([insert directory]) to change the directory
