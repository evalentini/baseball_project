
load 'string.rb'
load 'game.rb'
load 'hitter.rb'
load 'matchup.rb'
require 'open-uri'
require 'nokogiri'
require 'mysql2'
require 'nikkou'


#questions for phil: 
#1.) How can I avoid putting the code to connect to the DB in all classes? 

class Teamseason
	attr_accessor :team, :year
	
	#return a hash of gids for all games team has played so far in season 
	def completed_games 
		game_list=[]
		base_url="https://gd2.mlb.com/components/game/mlb/year_#{self.year.to_s}"
		days_in_month=[]
		days_in_month[3] = 31
		days_in_month[4]=30
		days_in_month[5]=31
		days_in_month[6]=30
		days_in_month[7]=31
		days_in_month[8]=31
		days_in_month[9]=30
		days_in_month[10]=31 
		for month in 3..10 do 
			for day in 1..days_in_month[month] do 
				puts "month is #{month} and day is #{day}"
				day_url=base_url+"/month_"+month.to_s.date_with_zero+"/day_"+day.to_s.date_with_zero
				day_doc=Nokogiri::HTML(open(day_url))
				day_doc.xpath("//a").each do |day_a|
					day_a_link=day_a.attribute("href").value 
					if day_a_link =~ /gid/ && day_a_link =~ /#{team}mlb/
						game_path=base_url+"/month_"+month.to_s.date_with_zero+"/"+day_a.attribute("href").value
						game_doc=Nokogiri::HTML(open(game_path))
						game_doc.xpath("//a").each do |game_a|
								if game_a.attribute("href").value == "boxscore.xml"
									game_list.push(game_path)								
								end 
						end 
					end 
				end
			end 
		end

		return game_list 

	end 

	def save_game_info
		games = self.completed_games 
		games.each do |game|
			gidstring=game.split("/")[-1]
			current_game=Game.new
			begin
				current_game.gid=current_game.parsegamestring(gidstring)
				current_game.add_game_score 
				#current_game.batting_lines
				puts "added score and batting lines for game #{current_game.gid_string}"
			rescue 
				puts "url error" 
			end 
		end  
	end

	def wins
		client=self.db_connect
		home_wins="SELECT COUNT(*) AS wins FROM games "
		home_wins+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND home_team_name='#{self.team}' AND home_team_score>away_team_score;"
		home_wins=client.query(home_wins).first["wins"]
		away_wins="SELECT COUNT(*) AS wins FROM games "
		away_wins+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND away_team_name='#{self.team}' AND home_team_score<away_team_score;"
		away_wins=client.query(away_wins).first["wins"]
		return home_wins+away_wins
	end 
	
	def games_played 
		client=self.db_connect
		games_played="SELECT COUNT(*) AS games_played FROM games "
		games_played+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND (away_team_name='#{self.team}' OR home_team_name='#{self.team}')"
		client.query(games_played).first["games_played"]
	end 

	def losses
		self.games_played-self.wins
	end 

	def runs_scored
		client=self.db_connect 
		home_game_runs="SELECT SUM(home_team_score) AS runs FROM games "
		home_game_runs+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND home_team_name='#{self.team}'"
		home_game_runs=client.query(home_game_runs).first["runs"].to_i

		away_game_runs="SELECT SUM(away_team_score) AS runs FROM games "
		away_game_runs+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND away_team_name='#{self.team}'"
		away_game_runs=client.query(away_game_runs).first["runs"].to_i
			
		home_game_runs+away_game_runs
	end 

	def runs_allowed
		client=self.db_connect 
		home_game_runs="SELECT SUM(away_team_score) AS runs FROM games "
		home_game_runs+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND home_team_name='#{self.team}'"
		home_game_runs=client.query(home_game_runs).first["runs"].to_i

		away_game_runs="SELECT SUM(home_team_score) AS runs FROM games "
		away_game_runs+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND away_team_name='#{self.team}'"
		away_game_runs=client.query(away_game_runs).first["runs"].to_i
			
		home_game_runs+away_game_runs 
	end 

	def pythag(coef=1.83)
		((self.runs_scored**coef).to_f)/((self.runs_scored**coef).to_f+(self.runs_allowed**coef).to_f)
	end 

	def wins_above_pythag
		self.wins-self.pythag*self.games_played
	end 

	def win_pct
		self.wins.to_f/self.games_played.to_f
	end 

	def db_connect
				client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")
				client
	end 

	def self.teamList
		["atl","bal","bos","chn","cin","cle","col","det",
		"flo","hou","kca","lan","mil","min","nya","nyn","oak","phi","pit",
		"sdn","sea","sfn","sln","tba","tex","tor","was"]
	end 

	def self.saveAllGames(year=2018) 
		self.teamList.each do |team|
			myteam=Teamseason.new
			myteam.year=year 
			myteam.team=team
			myteam.save_game_info
		end 
	end 
	 
end 
