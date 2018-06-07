require 'erb'

test=Matchup.pullMatchups

template = %q{
		<html>

		From: Evan Valentini <evan.valentini@gmail.com>
		<br>
		To: rburg7777@hotmail.com 
		<br><br>
		Richard: 
		<br>
		Please find a summary of todays action below: 
		<br><br>
		<table border=1> 
			<tr>
				<td>game id</td>
				<td>vegas favorite</td> 
				<td>vegas odds on favorite</td> 
				<td>vegas odds on underdog</td> 
				<td>modeled odds on favorite</td>  
				<td>recommended bet</td> 
			</tr>
			<% test.each do |matchup| %>  
			<% current_matchup=Matchup.new %> 
			<% current_matchup.gid=matchup['gid'] %> 
			<tr>
				<td><%= matchup['gid'] %></td>
				<td><%= current_matchup.favorite %></td>
				<td><%= current_matchup.odds_on_favorite_formatted %></td>
				<td><%= current_matchup.odds_on_underdog_formatted %></td>
				<td><%# current_matchup.pythag_odds_on_favorite_formatted %></td>
				<td>fill</td>
			</tr>
			<% end %> 
		</table> 	

		</html>

}

message = ERB.new(template, 0, "%<>")

email = message.result(binding) 

filepath='/home/evan/Desktop/A-F/baseball_newsletter/newsletter'+Time.now.strftime("%Y_%m_%d")+'.html'
newsletter=File.open(filepath, 'w') {|f| f.write(email) }

