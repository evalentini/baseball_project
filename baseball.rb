
#questions for Phil: 
##1.) How can I create a local variable in the linux terminal that I can use to save my password? Can't even remember the terminology for this. 

##2.) How could I write a script to automatically create the local database and correct tables? 

#in order to get this to work you'll need a mysql database instance installed with a database called baseball_data and a user called baseball with full access to baseball database 
##CREATE DATABASE baseball_data 
##GRANT ALL PRIVILEGES ON *.* TO 'baseball'@'localhost' IDENTIFIED BY 'baseballrocks';
##CREATE TABLE games (gid VARCHAR(100), home_team_name VARCHAR(100), away_team_name VARCHAR(100), home_team_score INT, away_team_score INT, gdate DATE);

#the baseball database has a games table with home and away team names and run totals along with game id 

require 'open-uri'
require 'nokogiri'

class Game 

	attr_accessor :gid

	def self.openingday
		puts "hello, its opening day!" 
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
		score={}
		doc = Nokogiri::HTML(open(game_url))
		at=doc.xpath("//linescore").attribute("away_team_runs").value 
		ht=doc.xpath("//linescore").attribute("home_team_runs").value	
		score[:at_runs]=at
		score[:ht_runs]=ht
		score
	end 
end 

class String 
	def date_with_zero 
		if self.to_i<10 then "0"+self
		else self
		end  	
	end 
end 

#notes 

#to change working directory in irb: (1) Dir.getwd() to find out current directory (2) Dir.chdir([insert directory]) to change the directory
