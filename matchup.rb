
#connect to the database 
$globalClient=DbConnection.startConnection

class Matchup 
	attr_accessor :homet, :awayt, :moneyline, :gid
	def ml_to_odds
		result={}
		if moneyline[:h]<0 then 
			result[:h]=moneyline[:h].to_f/(100.to_f+-1.to_f*moneyline[:h].to_f)
		else 
			result[:h]=(100.to_f)/(100.to_f+moneyline[:h].to_f)
		end 
		if moneyline[:a]<0 then 
			result[:a]=-1.to_f*moneyline[:a].to_f/(100.to_f+-1.to_f*moneyline[:a].to_f)
		else 
			result[:a]=(100.to_f)/(100.to_f+moneyline[:a].to_f)
		end 
		result
	end
	
	def self.pullMatchups(gamedate=Time.now)
		#check if odds for todays matchups have already been pulled 
		client=$globalClient
		gdate_str=gamedate.strftime('%Y-%m-%d')
		puts "SELECT COUNT(*) as ct FROM matchups WHERE gdate='"+gdate_str+"'"		
		if client.query("SELECT COUNT(*) as ct FROM matchups WHERE gdate='"+gdate_str+"'").first["ct"]==0
			Matchup.getMatchups(gamedate)
		end
		#pull matchups
		return client.query("SELECT * FROM matchups WHERE gdate='"+gdate_str+"'")
		
	end 

	def self.getMatchups(gamedate=Time.now)
		gamedate_string=gamedate.month.to_s.date_with_zero+"-"+gamedate.day.to_s.date_with_zero+"-"+gamedate.year.to_s.gsub('20','').to_i.to_s.date_with_zero
		puts gamedate_string
		#puts Time.now.year.to_s+"-"+Time.now.month.to_s.date_with_zero+"-"+Time.now.day.to_s.date_with_zero
	
		matchup_page=Nokogiri::HTML(open("http://www.vegasinsider.com/mlb/matchups/matchups.cfm/date/#{gamedate_string}"))
		#get list of games and times 
		#pull odds for each game 
		tl=Matchup.teamList
		output=[]
		betting_hash={}
		tl.each do |k,v|
			#check if team played 			
			for i in 1..matchup_page.search('a').text_equals(k).length
				matchup_detail=matchup_page.search('a').text_equals(k)[i-1].ancestors.first.ancestors.first.ancestors.first
				current_ml=matchup_page.search('a').text_equals(k)[i-1].ancestors.first.parent.children[13].content.to_i
				gametime_string=matchup_detail.text_includes('Game Time').first.content.gsub('Game Time', '')
				current_team=matchup_page.search('a').text_equals(k)[i-1].content
				awayt=matchup_detail.text_matches(/[0-9][0-9][0-9] ([A-Z](\.)*)+( )*[A-Za-z]+/)[0].content
				awayt=awayt.gsub(/[0-9]/, '').strip[0...-1]
				homet=matchup_detail.text_matches(/[0-9][0-9][0-9] ([A-Z](\.)*)+( )*[A-Za-z]+/)[2].content
				homet=homet.gsub(/[0-9]/, '').strip[0...-1]
				betting_hash[awayt+"-"+homet]={} if betting_hash[awayt+"-"+homet].nil?
				betting_hash[awayt+"-"+homet][gametime_string]={} if betting_hash[awayt+"-"+homet][gametime_string].nil? 
				betting_hash[awayt+"-"+homet][gametime_string][:ml_away]=current_ml if current_team==awayt
				betting_hash[awayt+"-"+homet][gametime_string][:ml_home]=current_ml if current_team==homet
				#betting_hash[:ml][:home]=current_ml #if current_team==homet
			end 		
		end 
		betting_hash.each do |k,v|
			if v.length==1 then
				current_game=Game.new 
				awayt_name=Matchup.teamList[k.split('-')[0]]; homet_name=Matchup.teamList[k.split('-')[1]]
				current_game.gid={:year=>gamedate.year.to_s, :month=>gamedate.month.to_s, :day => gamedate.day.to_s, :awayt=>awayt_name.to_s, :homet=>homet_name.to_s, :gnum=>1}
				odds=v.first[1]
				current_matchup=Matchup.new
				current_matchup.add_matchup(current_game,odds) 
			else 	
			#doubleheader
				earliest_game_time=9999999
				earliest_game_time_string=""
				v.each do |timek, timev|
					minutes_to_add=timek.split(' ')[1]=="PM" ? 12*60 : 0
					hour=timek.gsub('PM','').gsub('AM','').split(':')[0].to_i*60; minute=timek.gsub('PM','').gsub('AM','').split(':')[1].to_i
					time_standardized=hour+minute+minutes_to_add
					earliest_game_time_string=timek if time_standardized<earliest_game_time
					earliest_game_time=time_standardized if time_standardized<earliest_game_time
				end 
				v.each do |timek, timev|
					timek==earliest_game_time_string ? gnum=1 : gnum=2
					current_game=Game.new
					awayt_name=Matchup.teamList[k.split('-')[0]]; homet_name=Matchup.teamList[k.split('-')[1]]
					current_game.gid={:year=>gamedate.year.to_s, 
														:month=>gamedate.month.to_s, :day => 				gamedate.day.to_s, 
														:awayt=>awayt_name.to_s, :homet=>homet_name.to_s, 
														:gnum=>gnum}
				puts"---time key is #{timek} and time v is #{timev} and gid is #{current_game.gid_string}----"
				current_matchup=Matchup.new
				current_matchup.add_matchup(current_game,timev) 
				end 
			end 
		end 
	end  

	def self.db_connect
				client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")
				client
	end 

	def add_matchup(current_game, odds)
		client=$globalClient
		delete_syntax="DELETE FROM matchups WHERE gid='#{current_game.gid_string}';"
		client.query(delete_syntax)
		value_hash={:gid=>current_game.gid_string, :home_team_name=>current_game.gid[:homet], :away_team_name=>current_game.gid[:awayt]}
		value_hash[:home_ml]=odds[:ml_home].to_i
		value_hash[:away_ml]=odds[:ml_away].to_i
		value_hash[:gdate]=current_game.gid[:year].to_s+"-"+current_game.gid[:month].to_s.date_with_zero+"-"+current_game.gid[:day].to_s.date_with_zero
		variables=[]
		values=[]
		value_hash.each do |k,v|
			variables.push(k)		
			values.push(v)
		end
		client.query("test".insert_syntax('matchups', values, variables))
	end 

	def wl_odds_ml(hometeam_win_pct=nil, awayteam_win_pct=nil)

		current_game=Game.new
		current_game_hash=current_game.parsegamestring(self.gid) 


		hometeam=Teamseason.new
		hometeam.year=2018; hometeam.team=current_game_hash[:homet]
		hometeam_win_pct=hometeam.win_pct if hometeam_win_pct.nil? 
		hometeam_loss_pct=1-hometeam.win_pct
	
		awayteam=Teamseason.new 
		awayteam.year=2018; awayteam.team=current_game_hash[:awayt]
		awayteam_win_pct=awayteam.win_pct if awayteam_win_pct.nil?
		awayteam_loss_pct=1-awayteam.win_pct

		#bill james log5 formula 
		hometeam_matchup_win_probability = (hometeam_win_pct-hometeam_win_pct*awayteam_win_pct)/(hometeam_win_pct+awayteam_win_pct-2.to_f*hometeam_win_pct*awayteam_win_pct)
		awayteam_matchup_win_probability = (1-hometeam_matchup_win_probability) 

#		hometeam_matchup_win_probability = hometeam_win_pct*awayteam_loss_pct/(1-(hometeam_win_pct*awayteam_win_pct+hometeam_loss_pct*awayteam_loss_pct))
#		awayteam_matchup_win_probability = awayteam_win_pct*hometeam_loss_pct/(1-(awayteam_win_pct*hometeam_win_pct+awayteam_loss_pct*hometeam_loss_pct))

		
		return {:hometeam_ml_based_on_wl_record => hometeam_matchup_win_probability.odds_to_ml, 
						:awayteam_ml_based_on_wl_record => awayteam_matchup_win_probability.odds_to_ml}

	end 

	def pythag_wl_odds_ml
		current_game=Game.new
		current_game_hash=current_game.parsegamestring(self.gid) 

		hometeam=Teamseason.new
		hometeam.year=2018; hometeam.team=current_game_hash[:homet]

		awayteam=Teamseason.new 
		awayteam.year=2018; awayteam.team=current_game_hash[:awayt]
		
		puts hometeam.pythag
		puts awayteam.pythag

		self.wl_odds_ml(hometeam.pythag, awayteam.pythag) 	
		
	end 

	#estimated win probability based on season to date run differential 
	def pythag_odds_on_favorite(team=nil)
		fav_team=Teamseason.new
		fav_team.year=self.matchup_year
		fav_team.team=self.favorite 
		underdog_team=Teamseason.new
		underdog_team.year=self.matchup_year
		underdog_team.team=self.underdog
		return fav_team.pythag.to_f.odds_against_opponent(underdog_team.pythag.to_f)
	end 

	def pythag_odds_on_underdog(team=nil)
		fav_team=Teamseason.new
		fav_team.year=self.matchup_year
		fav_team.team=self.favorite 
		underdog_team=Teamseason.new
		underdog_team.year=self.matchup_year
		underdog_team.team=self.underdog	
		return underdog_team.pythag.to_f.odds_against_opponent(fav_team.pythag.to_f)
	end 

	#estimated win probability based on baseball prospectus remaining record expectation 
	def bp_odds_on_favorite
		fav_team=Teamseason.new
		fav_team.year=self.matchup_year
		fav_team.team=self.favorite 
		underdog_team=Teamseason.new
		underdog_team.year=self.matchup_year
		underdog_team.team=self.underdog
		return fav_team.bp_ros_win_pct.to_f.odds_against_opponent(underdog_team.bp_ros_win_pct.to_f)
	end

	#pull odds from fangraphs live scoreboard 
	def fangraphs_odds
		matchupgame=Game.new
		gamedate=matchupgame.parsegamestring(self.gid)[:year].to_s+"-"+matchupgame.parsegamestring(self.gid)[:month].to_s+"-"+matchupgame.parsegamestring(self.gid)[:day].to_s
		url="https://www.fangraphs.com/livescoreboard.aspx?date="+gamedate
		doc=Nokogiri::HTML(open(url))
		
		awayt=matchupgame.parsegamestring(self.gid)[:awayt]
		homet=Matchup.fangraphTeamList[matchupgame.parsegamestring(self.gid)[:homet]]
		puts awayt.to_s
	end 
	 
 
	def recommended_bet_formatted
		if self.odds_on_favorite<self.pythag_odds_on_favorite then 
			return favorite
		elsif self.odds_on_underdog<self.pythag_odds_on_underdog then 
			return underdog
		else
			return "no bet" 
		end
	end 

	def favorite_fair_ml
		return self.pythag_odds_on_favorite.odds_to_ml.round(0).to_s	
	end 

	def underdog_fair_ml
		return self.pythag_odds_on_underdog.odds_to_ml.round(0).to_s
	end 

	def expected_winnings
		if self.odds_on_favorite<self.pythag_odds_on_favorite then 
			#expected value = (100)*pythag_odds_on_favorite - (100/ml)*odds_on_underdog
			return -1.to_f*(10000.to_f/self.ml_on_favorite)*self.pythag_odds_on_favorite + -100.to_f*self.pythag_odds_on_underdog
		elsif self.odds_on_underdog<self.pythag_odds_on_underdog then 
			 #expected value = (moneyline)*pythag_odds_on_underdog - 100*odds_on_favorite
			return self.ml_on_underdog*self.pythag_odds_on_underdog + -100.to_f*self.pythag_odds_on_favorite
		else
			return 0 
		end
	end 

	def expected_winnings_formatted
		"$"+self.expected_winnings.round(2).to_s
	end 

	def pythag_odds_on_favorite_formatted(team=nil)
		return (self.pythag_odds_on_favorite(team)*100.to_f).round(1).to_s+"%"
	end 

	def matchup_year
		mygame=Game.new 
		return mygame.parsegamestring(self.gid)[:year].to_i
	end 

	def favorite
		client=$globalClient
		#pull money line from database 
		matchup=client.query("SELECT * FROM matchups WHERE gid='"+self.gid+"'").first
		if matchup['home_ml'].to_i<matchup['away_ml'].to_i then
			return matchup['home_team_name'] 
		else 
			return matchup['away_team_name'] 
		end
	end 

	def underdog
		client=$globalClient
		#pull money line from database 
		matchup=client.query("SELECT * FROM matchups WHERE gid='"+self.gid+"'").first
		if matchup['home_ml'].to_i<matchup['away_ml'].to_i then
			return matchup['away_team_name'] 
		else 
			return matchup['home_team_name'] 
		end
	end 

	def ml_on_favorite
		client=$globalClient
		matchup=client.query("SELECT * FROM matchups WHERE gid='"+self.gid+"'").first
		return [matchup['home_ml'],matchup['away_ml']].min.to_f
	end 
	
	def ml_on_underdog
		client=$globalClient
		matchup=client.query("SELECT * FROM matchups WHERE gid='"+self.gid+"'").first
		return [matchup['home_ml'],matchup['away_ml']].max.to_f
	end 

	def odds_on_favorite
		client=$globalClient
		matchup=client.query("SELECT * FROM matchups WHERE gid='"+self.gid+"'").first
		return [matchup['home_ml'],matchup['away_ml']].min.to_f.ml_to_odds
	end 

	def odds_on_favorite_formatted
		(self.odds_on_favorite*100.to_f).round(1).to_s+"%"	
	end 

	def odds_on_underdog
		client=$globalClient
		matchup=client.query("SELECT * FROM matchups WHERE gid='"+self.gid+"'").first
		return [matchup['home_ml'],matchup['away_ml']].max.to_f.ml_to_odds
	end 

	def odds_on_underdog_formatted
		(self.odds_on_underdog*100.to_f).round(1).to_s+"%"	
	end 

	def self.fangraphWinProb
		client=$globalClient
		tl={}
		tl['hou']="Astros"
		tl['tex']="Rangers"
		scoreboard_url ="https://www.fangraphs.com/livescoreboard.aspx?date="
		scoreboard_url+=Time.now.strftime('%Y-%m-%d')
		scoreboard=Nokogiri::HTML(open(scoreboard_url)) 
		team_label_tag_style="vertical-align:top; border-right: 1px dotted black; border-bottom:1px dotted black; text-align:center; padding-top: 15px; padding-bottom:15px;"
		win_prob_tag_style="border:1px solid black;"
		mhash={}		
		scoreboard.xpath('//td').each do |td|
		 	unless td.attribute('style').nil?		
				if td.attribute('style').value==team_label_tag_style				
					teams= td.content[0,100][/(\w+ )*\w+ @ (\w+ )*\w+/]
					gametime=td.content[0,100][/\d\d\:\d\d/].gsub(':','').to_i
					probs = td.content[0,100][/\d\d\.\d .\d\d\.\d/].split("%") 
					at_prob=probs[0].strip
					ht_prob=probs[1].strip
					away_team=Matchup.fgTeamList[teams.split('@')[0].strip]+"mlb"
					home_team=Matchup.fgTeamList[teams.split('@')[1].strip]+"mlb"
					mhash_key=away_team+"_"+home_team 
					mhash[mhash_key]={} if mhash[mhash_key].nil? 
					mhash[mhash_key][gametime]=[at_prob, ht_prob]
					#create hash with details for 
					#puts Matchup.fgTeamList[away_team] + "at " + Matchup.fgTeamList[home_team]
					#extract home team, away team, game time and win probs 		
				end 			
			end 			
		end 
		mhash.each do |teams,vals|
			gametimes=[]
			vals.each do |gametime, odds|
				gametimes.push(gametime)
			end 
			ordered_gametimes=gametimes.order_hash
			vals.each do |gametime, odds|
				gid_string="gid_"+Time.now.strftime('%Y_%m_%d')+"_"+teams+"_"+ordered_gametimes[gametime].to_s
				sql_syntax="UPDATE matchups SET awprob=#{odds.first}, hwprob=#{odds.last} WHERE gid='#{gid_string}';"
				puts sql_syntax				
				client.query(sql_syntax)
			end 
		end 
	end 	

	def self.teamList
		tl={}
			tl["L.A. Angels"]="ana"
			tl["Arizona"]="ari"
			tl["Atlanta"]="atl"
			tl["Baltimore"]="bal"
			tl["Boston"]="bos"
			tl["Chi. White Sox"]="cha"
			tl["Chi. Cubs"]="chn"
			tl["Cincinnati"]="cin"
			tl["Cleveland"]="cle"
			tl["Colorado"]="col"
			tl["Detroit"]="det"
			tl["Miami"]="mia"; tl["Houston"]="hou"; tl["Kansas City"]="kca"; tl["L.A. Dodgers"]="lan"
			tl["Milwaukee"]="mil"; tl["Minnesota"]="min"; tl["N.Y. Yankees"]="nya"; tl["N.Y. Mets"]="nyn"
			tl["Oakland"]="oak"; tl["Philadelphia"]="phi"; tl["Pittsburgh"]="pit"; tl["San Diego"]="sdn";
			tl["Seattle"]="sea"; tl["San Francisco"]="sfn"; tl["St. Louis"]="sln";
			tl["Tampa Bay"]="tba"; tl["Texas"]="tex"; tl["Toronto"]="tor"; tl["Washington"]="was" 		
		return tl
	end 

	def self.fgTeamList
		tl={}
		tl['Angels']='ana'
		tl['Diamondbacks']='ari'
		tl['Braves']='atl'
		tl['Orioles']='bal'
		tl['Red Sox']='bos'
		tl['White Sox']='cha'
		tl['Cubs']='chn'
		tl['Reds']='cin'
		tl['Indians']='cle'
		tl['Rockies']='col'
		tl['Tigers']='det'
		tl['Marlins']='mia'
		tl['Astros']='hou'
		tl['Royals']='kca'
		tl['Dodgers']='lan'
		tl['Brewers']='mil'
		tl['Twins']='min'
		tl['Yankees']='nya'
		tl['Mets']='nyn'
		tl['Athletics']='oak'
		tl['Phillies']='phi'
		tl['Pirates']='pit'
		tl['Padres']='sdn'
		tl['Mariners']='sea'
		tl['Giants']='sfn'
		tl['Cardinals']='sln'
		tl['Rays']='tba'
		tl['Rangers']='tex'
		tl['Blue Jays']='tor'
		tl['Nationals']='was'
		return tl
	end 
end 


