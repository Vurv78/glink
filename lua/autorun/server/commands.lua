local fmt = string.format

local Commands = {
	["help"] = function(args)
		return "Commands: [help, players, ping]"
	end,

	["ping"] = function()
		return "Pong!"
	end,

	["players"] = function()
		return fmt("```%s```", table.concat(player.GetAll(), "\n\t"))
	end
}

return Commands