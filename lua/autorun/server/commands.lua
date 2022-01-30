local fmt = string.format

-- Hardcoded whitelist for now until I figure out how to do roles.
local PermOperators = {
	["363590853140152321"] = true,
	["467262196418740224"] = true,
	["895801459407474689"] = true
}

local Operators = setmetatable({}, {__index = PermOperators})

-- Basic escape patcher
local function discordEscape(msg)
	return string.gsub(msg, "`", "\\`")
end

local Commands
Commands = {
	["help"] = function(bot, data)
		return fmt("Commands: [%s]", table.concat( table.GetKeys(Commands), ", " ))
	end,

	["ping"] = function(bot, data)
		return "Pong!"
	end,

	["players"] = function(bot, data)
		local plys, out = player.GetAll(), {}
		for k, ply in ipairs(plys) do
			out[k] = ply:Nick() .. " (" .. ply:SteamID64() .. ")"
		end
		return fmt("Players online:\n```%s```", table.concat(out, "\n"))
	end,

	["map"] = game.GetMap,
	["payers"] = function(bot, data) return "shut up" end,

	["lua"] = function(bot, data, rest)
		if Operators[data.author.id] then
			rest = string.match("^```lua\n?\r?(.*)```$") or rest

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
			local args = string.Explode(" ", rest)
			local first = args[1]

			if first and string.Trim(first) ~= "" then
				RunConsoleCommand(first, unpack(args, 2))
				return "Ran command: " .. first .. " " .. table.concat(args, " ", 2)
			else
				return "Usage: ``rcon <command> <args...>`` (Like RunConsoleCommand)"
			end
		else
			return "No access!"
		end
	end,

	["op"] = function(bot, data, rest)
		if Operators[data.author.id] then
			local id = string.match(rest, "%d+")
			if id then
				if Operators[id] then
					return "Already an operator!"
				end
				Operators[id] = true
				return "Added " .. id .. " to the operator list."
			end
			return "Usage: ``op <id: number>``"
		else
			return "No access!"
		end
	end,

	["deop"] = function(bot, data, rest)
		if Operators[data.author.id] then
			local id = string.match(rest, "%d+")
			if id then
				if id == data.author.id then
					return "You can't deop yourself!"
				end

				Operators[id] = nil
				return "Removed " .. id .. " from the operator list."
			end
			return "Usage: ``op <id: number>``"
		else
			return "No access!"
		end
	end,

	["ram"] = function(bot, data, rest)
		return string.NiceSize( collectgarbage("count") * 1000 )
	end,

	["kick"] = function(bot, data, rest)
		if Operators[data.author.id] then
			local name = string.match(rest, "%S+")
			if name then
				name = string.lower(name)
				for _, ply in ipairs(player.GetAll()) do
					if string.find(string.lower( ply:Nick() ), name, 1, true) then
						ply:Kick("Kicked by " .. data.author.username)
						return "Kicked ``" .. discordEscape(ply:Nick()) .. "``"
					end
				end
				return "Couldn't find anyone with that name!"
			end
			return "Usage: ``!kick <name>``"
		else
			return "No access!"
		end
	end,

	["kill"] = function(bot, data, rest)
		if Operators[data.author.id] then
			local name = string.match(rest, "%S+")
			if name then
				name = string.lower(name)

				for _, ply in pairs(player.GetAll()) do
					if string.find(string.lower( ply:Nick() ), name, 1, true) then
						ply:Kill()
						return
					end
				end
				return "Couldn't find anyone with that name!"
			else
				return "Usage: ``!kill <name>``"
			end
		else
			return "No access!"
		end
	end
}

return Commands