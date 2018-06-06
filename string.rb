class String 

	def date_with_zero 
		if self.to_i<10 then "0"+self.to_i.to_s
		else self
		end  	
	end

	def insert_syntax(table_name, values, var_names) 
		#don't forget to escape single quote 
		syntax="INSERT INTO #{table_name} (" 
		var_names.each {|var| syntax+="#{var}, "}
		syntax=syntax[0...-2]
		syntax+=") VALUES ( "
		values.each do |value|
			syntax+="'" if value.is_a? String
			syntax+=value.to_s.gsub("'","\\\\'")
			syntax+="'" if value.is_a? String
			syntax+=", "			 
		end 
		syntax=syntax[0...-2]
		syntax+=");"
	end 

	def sql_d_parsed
		#convert dates of format Tue, 05 Jun 2018 to hash with year, to hash with year, month, day attributes
		d_string=self.split(',')[1] #elminate weekday info
		day=d_string.split(' ')[0]
		month=d_string.split(' ')[1].monthToNum.to_s.date_with_zero
		year=d_string.split(' ')[2]
		result={:year=>year, :month=>month, :day=>day}
		result
	end 
	
	def monthToNum 
		lookup={"Jan"=>1, "Feb"=>2, "Mar"=>3, "Apr"=>4, "May"=>5, "Jun"=>6, "Jul"=>7, "Aug"=>8, "Sep"=>9, "Oct"=>10, "Nov"=>11, "Dec"=>12}
		lookup[self]
	end 
	 
end 
