
class Hitter
	attr_accessor :id
	
	def home_runs(year=2018) 
		client=self.db_connect
		select_statement="SELECT SUM(CASE WHEN event='Home Run' THEN 1 ELSE 0 END) AS home_runs "
		from_statement="FROM plateappearances "
		where_statement="WHERE hitter_id=#{id} AND partofseason='reg';"		
		#where_statement="WHERE partofseason='reg' AND YEAR(gdate)=#{year} AND hitter_id=#{id};"
		sql_command=select_statement+from_statement+where_statement
		puts sql_command
		client.query(sql_command).first["home_runs"]
	end  

		def db_connect
				client = Mysql2::Client.new(:host => "localhost", 
					:username => "baseball", 
					:password => "baseballrocks", 
					:db => "baseball_data")
				client
	end 

end 
