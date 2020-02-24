game = {}

game.Changed = {}

function game.Changed:Connect()
	local event = {}

	function event:Disconnect()
	end

	return event
end

function game:GetService(name)
	return game[name]
end
function game.GetService(game, name)
	return game[name]
end

