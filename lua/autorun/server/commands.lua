local fmt = string.format

-- Hardcoded whitelist for now until I figure out how to do roles.
local Operators = {
	["363590853140152321"] = true,
	["467262196418740224"] = true,
	["895801459407474689"] = true,
}

local Commands
Commands = {
	["help"] = function(bot, data)
		return fmt("Commands: [%s]", table.concat( table.GetKeys(Commands), ", " ))
	end,

	["ping"] = function(bot, data)
		return "Pong!"
	end,

	["players"] = function(bot, data)
		local plys = player.GetAll()
		for k, ply in pairs(plys) do
			plys[k] = ply:Nick()
		end
		return fmt("Players online:\n```%s```", table.concat(plys, "\n\t"))
	end,

	["map"] = game.GetMap,
	["payers"] = function(bot, data) return "shut up" end,

	["lua"] = function(bot, data, rest)
		if Operators[data.author.id] then
			local fn = CompileString(rest, "Discord", false)
			if type(fn) == "string" then
				return "Lua compile error: " .. fn
			else
				local old_hook, old_mask, old_count = debug.gethook()
				debug.sethook(error, "", 1e7)

				local ok, res = pcall(fn)
				debug.sethook(old_hook, old_mask, old_count)

				if not ok then
					return "Lua runtime error: " .. res
				else
					return "Ran successfully and returned: " .. tostring(res)
				end
			end

			local ok, reason = pcall(RunString, rest)
			if not ok then
				return "Lua runtime error: " .. reason
			else
				return "Ran successfully"
			end
		else
			return "No access!"
		end
	end,

	["rcon"] = function(bot, data, rest)
		if Operators[data.author.id] then
			RunConsoleCommand(rest)
		else
			return "No access!"
		end
	end,

	["op"] = function(bot, data, rest)
		if Operators[data.author.id] then
			rest = string.Trim(rest)
			Operators[rest] = true
			return "Added " .. rest .. " to the operator list."
		else
			return "No access!"
		end
	end,

	["ram"] = function(bot, data, rest)
		return collectgarbage("count")
	end
}

return Commands