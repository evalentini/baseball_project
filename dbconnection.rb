class DbConnection 
	def self.startConnection
		client = Mysql2::Client.new(:host => "localhost", 
				:username => "baseball", 
				:password => "baseballrocks", 
				:db => "baseball_data")
			return client
	end  
end 
