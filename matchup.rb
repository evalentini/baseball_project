class Matchup 
	attr_accessor :homet, :awayt, :moneyline
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

	def self.getMatchups 
		puts Time.now.year.to_s+"-"+Time.now.month.to_s.date_with_zero+"-"+Time.now.day.to_s.date_with_zero
		matchup_page=Nokogiri::HTML(open("http://www.vegasinsider.com/mlb/matchups/"))
		#get list of games and times 
		#pull odds for each game 
		matchup_detail=matchup_page.search('a').text_equals('Atlanta').first.ancestors.first.ancestors.first.ancestors.first
		awayt=matchup_detail.text_matches(/[0-9][0-9][0-9] [A-Z][a-z]+/)[0].content
		homet=matchup_detail.text_matches(/[0-9][0-9][0-9] [A-Z][a-z]+/)[2].content
		puts "away team is #{awayt} and home team is #{homet}"
	end  

	def self.teamList
		#NL east
		#AL east
		#NL central 
		#AL central 
		#NL west 
		#AL west  
	end 
end 
