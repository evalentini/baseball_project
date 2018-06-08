
load 'dbconnection.rb'
load 'string.rb'
load 'game.rb'
load 'hitter.rb'
load 'matchup.rb'
load 'float.rb'
load 'petcoa.rb'
require 'open-uri'
require 'nokogiri'
require 'mysql2'
require 'nikkou'

#connect to the database 
$globalClient=DbConnection.startConnection

#questions for phil: 
#1.) How can I avoid putting the code to connect to the DB in all classes? 

class Teamseason
	attr_accessor :team, :year
	
	#return a hash of gids for all games team has played so far in season 
	def completed_games(start_date=Date.new(self.year, 01,01))
		game_list=[]
		base_url="https://gd2.mlb.com/components/game/mlb/year_#{self.year.to_s}"
		
		od=self.openingDay[self.team]

		od>start_date ? begin_date=od : begin_date=start_date
		eofseason=self.closingDay
		eofseason=Date.today if Date.today < eofseason
		
		begin_date.upto(eofseason).each do |curr_day|
			puts "day is #{curr_day}"
			day_url=base_url+"/month_"+curr_day.month.to_s.date_with_zero+"/day_"+curr_day.day.to_s.date_with_zero
			day_doc=Nokogiri::HTML(open(day_url))
			day_doc.xpath("//a").each do |day_a|
				day_a_link=day_a.attribute("href").value 
				if day_a_link =~ /gid/ && day_a_link =~ /#{team}mlb/
					game_path=base_url+"/month_"+curr_day.month.to_s.date_with_zero+"/"+day_a.attribute("href").value
					game_doc=Nokogiri::HTML(open(game_path))
					game_doc.xpath("//a").each do |game_a|
						if game_a.attribute("href").value == "boxscore.xml"
							game_list.push(game_path)								
						end 
					end 
				end 
			end
		end  		
		return game_list		
	end

	def save_game_info(keep_past_games=true)
		startdate=Date.new(self.year, 01,01) 
		if keep_past_games == true 
			client=$globalClient
			puts "SELECT MAX(gdate) as maxdate FROM games WHERE (home_team_name='#{self.team}' OR away_team_name='#{self.team}') AND partofseason='reg' AND YEAR(gdate)=#{self.year};"
			maxdate=client.query("SELECT MAX(gdate) as maxdate FROM games WHERE (home_team_name='#{self.team}' OR away_team_name='#{self.team}') AND partofseason='reg' AND YEAR(gdate)=#{self.year};")
			puts maxdate.first["maxdate"].class			
			startdate=maxdate.first["maxdate"] unless maxdate.first["maxdate"].nil?
			#startdate=Date.new(maxdate.first["maxdate"].sql_d_parsed[:year],maxdate.first["maxdate"].sql_d_parsed[:month],
			#									maxdate.first["maxdate"].sql_d_parsed[:day]) unless maxdate.first["maxdate"].nil?
			startdate=startdate-1 unless maxdate.first[:maxdate].nil?
		end 
		puts startdate
		games = self.completed_games(startdate)
		games.each do |game|
			gidstring=game.split("/")[-1]
			current_game=Game.new
				current_game.gid=current_game.parsegamestring(gidstring)
				current_game.add_game_score 
				current_game.batting_lines
				puts "added score and batting lines for game #{current_game.gid_string}"
				#change part of season
				od=self.openingDay[self.team]
				current_game_date = Date.parse("'#{current_game.gid[:day].to_s}-#{current_game.gid[:month].to_s}-#{current_game.gid[:year].to_s}'")
				current_game_date < od ? partofseason='spring' : partofseason='reg' 
				client=$globalClient
				puts "--UPDATE games SET partofseason='#{partofseason}' WHERE gid='#{current_game.gid_string}'";
				client.query("UPDATE games SET partofseason='#{partofseason}' WHERE gid='#{current_game.gid_string}';")
				client.query("UPDATE games SET partofseason='rain' WHERE home_team_score=away_team_score;")  
		end  
	end

	def wins
		client=$globalClient
		home_wins="SELECT COUNT(*) AS wins FROM games "
		home_wins+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND home_team_name='#{self.team}' AND home_team_score>away_team_score;"
		home_wins=client.query(home_wins).first["wins"]
		away_wins="SELECT COUNT(*) AS wins FROM games "
		away_wins+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND away_team_name='#{self.team}' AND home_team_score<away_team_score;"
		away_wins=client.query(away_wins).first["wins"]
		return home_wins+away_wins
	end 

	def wins_by_month(month=4) 
		home_wins="SELECT COUNT(*) AS wins FROM games "
		home_wins+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND month(gdate)=#{month} AND home_team_name='#{self.team}' AND home_team_score>away_team_score;"
		home_wins=client.query(home_wins).first["wins"]
		away_wins="SELECT COUNT(*) AS wins FROM games "
		away_wins+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND month(gdate)=#{month} AND away_team_name='#{self.team}' AND home_team_score<away_team_score;"
		away_wins=client.query(away_wins).first["wins"]		
		return home_wins+away_wins
	end 
	
	def games_played 
		client=$globalClient
		games_played="SELECT COUNT(*) AS games_played FROM games "
		games_played+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND (away_team_name='#{self.team}' OR home_team_name='#{self.team}')"
		client.query(games_played).first["games_played"]
	end 

	def games_played_by_month(month=4)
		client=self.db_connect
		games_played="SELECT COUNT(*) AS games_played FROM games "
		games_played+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND month(gdate)=#{month} AND (away_team_name='#{self.team}' OR home_team_name='#{self.team}')"
		client.query(games_played).first["games_played"]
	end 


	def losses
		self.games_played-self.wins
	end 

	def runs_scored
		client=$globalClient 
		home_game_runs="SELECT SUM(home_team_score) AS runs FROM games "
		home_game_runs+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND home_team_name='#{self.team}'"
		home_game_runs=client.query(home_game_runs).first["runs"].to_i

		away_game_runs="SELECT SUM(away_team_score) AS runs FROM games "
		away_game_runs+="WHERE partofseason='reg' AND year(gdate)=#{self.year} AND away_team_name='#{self.team}'"
		away_game_runs=client.query(away_game_runs).first["runs"].to_i
			
		home_game_runs+away_game_runs
	end 

	def runs_allowed
		client=$globalClient
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

#	def db_connect
#				client = Mysql2::Client.new(:host => "localhost", 
#					:username => "baseball", 
#					:password => "baseballrocks", 
#					:db => "baseball_data")
#				client
#	end 

	def self.teamList
		["ana", "ari", "atl","bal","bos","chn","cin","cle","col","det",
		"mia","hou","kca","lan","mil","min","nya","nyn","oak","phi","pit",
		"sdn","sea","sfn","sln","tba","tex","tor","was"]
	end 

	def self.saveAllGames(year=2018, update_only=true) 
		self.teamList.each do |team|
			puts "starting on team ---#{team}----"			
			myteam=Teamseason.new
			myteam.year=year 
			myteam.team=team
			myteam.save_game_info(update_only)
		end 
	end 

	def openingDay 
		output={}
		if self.year==2018
			Teamseason.teamList.each do |team|
				output[team]=Date.parse('29-03-2018')
				#set up later to work for other years
			end
		end 
		if self.year==2017
			Teamseason.teamList.each do |team|
				output[team]=Date.parse('03-04-2017')
				#set up later to work for other years
			end 
			earlystartteams=['ari', 'sfn', 'chn', 'sln', 'nya', 'tba']
			earlystartteams.each {|team| output[team]=Date.parse('02-04-2017')}
		end  	 
		output
	end 
	
	def closingDay 
		Date.parse('02-10-'+self.year.to_s)
	end 

	def hitter_plate_appearances (hitter_id) 
			syntax="SELECT COUNT(*) as pa_count FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id}"
			client=Teamseason.db_connect			
			client.query(syntax).first["pa_count"]
	end 

		def plate_appearances 
			syntax="SELECT COUNT(*) as pa_count FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year}"
			client=Teamseason.db_connect			
			client.query(syntax).first["pa_count"]
	end 

	def hitter_hits(hitter_id)
		syntax="SELECT COUNT(*) as hits FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND (event='Single' or event='Double' or event='Triple' or event='Home Run')"
		client=Teamseason.db_connect			
		client.query(syntax).first["hits"]
	end 

	def hits
		syntax="SELECT COUNT(*) as hits FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND (event='Single' or event='Double' or event='Triple' or event='Home Run')"
		client=Teamseason.db_connect			
		client.query(syntax).first["hits"]
	end 


	def hitter_singles(hitter_id)
		syntax="SELECT COUNT(*) as singles FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND (event='Single')"
		client=Teamseason.db_connect			
		client.query(syntax).first["singles"]
	end 

	def singles
		syntax="SELECT COUNT(*) as singles FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND (event='Single')"
		client=Teamseason.db_connect			
		client.query(syntax).first["singles"]
	end 

	def hitter_doubles(hitter_id)
		syntax="SELECT COUNT(*) as doubles FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND event='Double'"
		client=Teamseason.db_connect			
		client.query(syntax).first["doubles"]
	end 

	def doubles
		syntax="SELECT COUNT(*) as doubles FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND event='Double'"
		client=Teamseason.db_connect			
		client.query(syntax).first["doubles"]
	end 


	def hitter_triples(hitter_id)
		syntax="SELECT COUNT(*) as triples FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND event='Triple'"
		client=Teamseason.db_connect			
		client.query(syntax).first["triples"]
	end 

	def triples
		syntax="SELECT COUNT(*) as triples FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND event='Triple'"
		client=Teamseason.db_connect			
		client.query(syntax).first["triples"]
	end 


	def hitter_home_runs(hitter_id)
		syntax="SELECT COUNT(*) as hr FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND event='Home Run'"
		client=Teamseason.db_connect			
		client.query(syntax).first["hr"]
	end 

	def home_runs
		syntax="SELECT COUNT(*) as hr FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND event='Home Run'"
		client=Teamseason.db_connect			
		client.query(syntax).first["hr"]
	end 

	def hitter_walks(hitter_id)
		syntax="SELECT COUNT(*) as walks FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND (event='Walk' OR event='Intent Walk')"
		client=Teamseason.db_connect			
		client.query(syntax).first["walks"]
	end 

	def walks
		syntax="SELECT COUNT(*) as walks FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND (event='Walk' OR event='Intent Walk')"
		client=Teamseason.db_connect			
		client.query(syntax).first["walks"]
	end 

	def hitter_hbp(hitter_id)
				syntax="SELECT COUNT(*) as hbp FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
		syntax+="AND (event='Hit By Pitch')"
		client=Teamseason.db_connect			
		client.query(syntax).first["hbp"]
	end 

	def hbp
				syntax="SELECT COUNT(*) as hbp FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
		syntax+="AND (event='Hit By Pitch')"
		client=Teamseason.db_connect			
		client.query(syntax).first["hbp"]
	end 

	def hitter_at_bats(hitter_id)
		result={}
		totalouts=0
		out_plays=['Bunt Groundout', 'Bunt Lineout', 'Bunt Pop Out', 'Double Play', 'Field Error', 'Fielders Choice', 'Fielders Choice Out', 'Flyout', 'Forceout', 'Grounded Into DP', 'Groundout', 'Lineout', 'Pop Out', 'Strikeout', 'Strikeout - DP', 'Triple Play']
		client=Teamseason.db_connect
		out_plays.each do |play|
			syntax="SELECT COUNT(*) as outplays FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} AND hitter_id=#{hitter_id} "
			syntax+="AND (event='#{play}')"
			result[play]=client.query(syntax).first["outplays"]
			totalouts+=result[play].to_i
		end 
		totalouts+hitter_hits(hitter_id)
	end 

	def at_bats
		result={}
		totalouts=0
		out_plays=['Bunt Groundout', 'Bunt Lineout', 'Bunt Pop Out', 'Double Play', 'Field Error', 'Fielders Choice', 'Fielders Choice Out', 'Flyout', 'Forceout', 'Grounded Into DP', 'Groundout', 'Lineout', 'Pop Out', 'Strikeout', 'Strikeout - DP', 'Triple Play']
		client=Teamseason.db_connect
		out_plays.each do |play|
			syntax="SELECT COUNT(*) as outplays FROM plateappearances WHERE partofseason='reg' AND team='#{self.team}' AND year(gdate)=#{self.year} "
			syntax+="AND (event='#{play}')"
			result[play]=client.query(syntax).first["outplays"]
			totalouts+=result[play].to_i
		end 
		totalouts+self.hits
	end 


	def hitter_batting_average(hitter_id) 
		self.hitter_hits(hitter_id).to_f/self.hitter_at_bats(hitter_id)
	end 

	def batting_average 
		self.hits.to_f/self.at_bats.to_f
	end 

	def hitter_obp(hitter_id)
		numerator=self.hitter_hits(hitter_id).to_f+self.hitter_walks(hitter_id).to_f+self.hitter_hbp(hitter_id).to_f
		denominator=self.hitter_at_bats(hitter_id).to_f+self.hitter_walks(hitter_id).to_f+self.hitter_hbp(hitter_id).to_f
		numerator/denominator
	end 

	def hitter_slg(hid)
		numerator=self.hitter_singles(hid)+self.hitter_doubles(hid)*2+self.hitter_triples(hid)*3+self.hitter_home_runs(hid)*4
		denominator=self.hitter_at_bats(hid).to_f
		numberator=numerator.to_f
		numerator/denominator
	end 

	def team_at_bats
		client=$globalClient
		syntax="SELECT COUNT(*) as pa, hitter_id, hitter_name FROM plateappearances " 
		syntax+="WHERE team='"+self.team+"' AND partofseason='reg' AND year(gdate)="+self.year.to_s+" "
		syntax+="GROUP BY hitter_id, hitter_name ORDER By pa DESC;"
		result=client.query(syntax).first
		result["hitter_name"].to_s+" with "+result["pa"].to_s+" plate appearances"
	end 

	def self.db_connect
				client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")
				client
	end 

	def bp_ros_win_pct 
		raise "not relevant for historical seasons" unless self.year==2018
		url="https://legacy.baseballprospectus.com/fantasy/dc/index.php?tm="+self.team 
		doc=Nokogiri::HTML(open(url))
		wins = doc.xpath('//b').first.content.to_s.split("-")[0].to_i
		losses = doc.xpath('//b').first.content.to_s.split("-")[1].to_i
		return wins.to_f/(wins.to_f+losses.to_f)
	end 

end 
