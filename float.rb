class Float
	def odds_to_ml
		if self>=0.5 then
			return self*100/(self-1.to_f)
		else 
			return ((1.to_f-self)/self) * 100.to_f
		end 
	end 

	def ml_to_odds
		if self<0 then 
			return self/(self-100.to_f)
		else 
			return 100.to_f/(self.to_f+100.to_f)
		end 
	end 

	def odds_against_opponent(opp_win_pct)
		#bill james log5 formula 
		return (self-self*opp_win_pct)/(self+opp_win_pct-2*self*opp_win_pct)
	end 

end 
