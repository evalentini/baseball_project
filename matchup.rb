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
		client=Matchup.db_connect		
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

		hometeam_matchup_win_probability = hometeam_win_pct*awayteam_loss_pct/(1-(hometeam_win_pct*awayteam_win_pct+hometeam_loss_pct*awayteam_loss_pct))
		awayteam_matchup_win_probability = awayteam_win_pct*hometeam_loss_pct/(1-(awayteam_win_pct*hometeam_win_pct+awayteam_loss_pct*hometeam_loss_pct))
		
		if hometeam_matchup_win_probability>=0.5 then 
			hometeam_ml_based_on_wl_record=100.to_f*hometeam_matchup_win_probability/(1.to_f-hometeam_matchup_win_probability)
			awayteam_ml_based_on_wl_record=-1*100.to_f*(1.to_f-awayteam_matchup_win_probability)/awayteam_matchup_win_probability
		else 
			awayteam_ml_based_on_wl_record=100.to_f*awayteam_matchup_win_probability/(1.to_f-awayteam_matchup_win_probability)
			hometeam_ml_based_on_wl_record=-1*100.to_f*(1.to_f-hometeam_matchup_win_probability)/hometeam_matchup_win_probability
		end 		
		
		result={:hometeam_ml_based_on_wl_record => hometeam_ml_based_on_wl_record, :awayteam_ml_based_on_wl_record => awayteam_ml_based_on_wl_record}
		return result

	end 

	def pythag_wl_odds_ml
		current_game=Game.new
		current_game_hash=current_game.parsegamestring(self.gid) 

		hometeam=Teamseason.new
		hometeam.year=2018; hometeam.team=current_game_hash[:homet]

		awayteam=Teamseason.new 
		awayteam.year=2018; awayteam.team=current_game_hash[:awayt]

		self.wl_odds_ml(hometeam.pythag, awayteam.pythag) 	
		
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
end 
