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
	 
end 
