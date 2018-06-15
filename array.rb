class Array
	def order_hash 
		result_hash={}
		self.each do |v|
			counter=1
			self.sort.each do |sv|
				result_hash[v]=counter if v==sv
				counter+=1			
			end 
		end 
		return result_hash
	end  
end 
