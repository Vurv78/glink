local CONFIGS = require("glink/configs")
local fmt = string.format

-- Basic escape patcher
local function discordEscape(msg)
	return string.gsub(msg, "`", "\\`")
end

local Hints = {
	["restart"] = "You might be looking for the ``reload`` command.",
	["shutdown"] = "You might be looking for the ``exit`` command."
}

---@class CommandPerms
local PERMS = {
	Everyone = 1,
	Operator = 2,
	Owner = 3
}

---@param member table
---@return CommandPerms
local function getPermsFromMember(member)
	for _, role_id in ipairs(member.roles) do
		if role_id == CONFIGS.PermsRole then
			return PERMS.Operator
		end
	end
	return PERMS.Everyone
end

---@type table<string, { desc: string, perms: CommandPerms, func: fun(bot: DiscordBot, data: table, rest: string) }>
local Commands = {}

---@param name string
---@param desc string
---@param perms CommandPerms? # Default is Everyone
---@param func fun(bot: DiscordBot, data: table, rest: string)
local function Command(name, desc, perms, func)
	Commands[name] = {
		["desc"] = desc,
		["perms"] = perms or PERMS.Everyone,
		["func"] = func
	}
end

--- Limits a string to dedicated length, or cuts off with ...
---@param str string
---@param len integer
local function limitString(str, len)
	if #str >= math.min(len - 3) then
		return str:sub(1, len) .. "..."
	else
		return str
	end
end

---@param cmd string
---@param bot DiscordBot
---@param data table
---@param rest string
---@return string msg?
local function runCommand(cmd, bot, data, rest)
	local cdata = Commands[cmd]
	if cdata then
		local perms = getPermsFromMember(data.member)

		if perms >= cdata.perms then
			limitString( cdata.func(bot, data, rest), 2000 )
		else
			return "❌ You don't have permission to use this command!"
		end
	elseif Hints[cmd] then
		return fmt("❌ Command ``%s`` does not exist! (HINT: %s)", cmd, Hints[cmd])
	else
		return fmt("❌ Command ``%s`` does not exist!", cmd)
	end
end

Command (
	"help",
	"❓ Shows this message. Optionally shows full description for certain command",
	nil,
	function(bot, data, rest)
		local cmd = string.match(rest, "%w+")
		if cmd then
			if Commands[cmd] then
				return fmt("Help for ``%s``:\n\t```%s```", cmd, Commands[cmd].desc)
			else
				return fmt("❌ Command ``%s`` not found.", cmd)
			end
		end
		local out, nout = {}, 1
		for name, cdata in pairs(Commands) do
			out[nout] = name .. " -- " .. limitString(cdata.desc, 50)
			nout = nout + 1
		end
		return fmt("Commands: \n```hs\n%s\n```", table.concat(out, "\n"))
	end
)

Command (
	"ping",
	"🏓 Sends a ping to gmod, and replies with ``Pong!`` afterward",
	nil,
	function(bot, data, rest)
		return "🏓 Pong!"
	end
)

Command (
	"players",
	"📋 Replies with the list of players currently on the server.",
	nil,
	function(bot, data, rest)
		local plys, out = player.GetAll(), {}

		if #plys > 0 then
			for k, ply in ipairs(plys) do
				out[k] = ply:Nick() .. " (" .. ply:SteamID64() .. ")"
			end
			return fmt("🤵 Players online:\n```lua\n%s```", table.concat(out, "\n"))
		end
		return "No players online. 😔"
	end
)

Command (
	"map",
	"🗺️ Replies with the map the server is on.",
	nil,
	function(bot, data, rest)
		return fmt("🗺️ Current Map:\n``%s``", game.GetMap())
	end
)

Command (
	"payers",
	"yeah",
	nil,
	function()
		return "shut up 🤬"
	end
)

local LuaStdout = {}
local LuaEnv = setmetatable({}, { __index = _G })

function LuaEnv.print(...)
	local out = {}
	for k, v in ipairs(arg) do
		out[k] = tostring(v)
	end
	LuaStdout[#LuaStdout + 1] = table.concat(out, "\t") .. "\n"
end

function LuaEnv.ErrorNoHalt(...)
	local out = {}
	for k, v in ipairs(arg) do
		out[k] = tostring(v)
	end
	LuaStdout[#LuaStdout + 1] = table.concat(out, "")
end

function LuaEnv.MsgN(...)
	-- Print(...) but without the \t inserted.
	local out = {}
	for k, v in ipairs(arg) do
		out[k] = tostring(v)
	end
	LuaStdout[#LuaStdout + 1] = table.concat(out, "") .. "\n"
end

function LuaEnv.Msg(...)
	--- MsgN but without the \n at the end.
	local out = {}
	for k, v in ipairs(arg) do
		out[k] = tostring(v)
	end
	LuaStdout[#LuaStdout + 1] = table.concat(out, "")
end

Command (
	"lua",
	"🌑 Runs a block of lua code. Can be used with discord code blocks (make sure it's a \\`\\`\\`lua block.)",
	PERMS.Operator,
	function(bot, data, rest)
		rest = string.match(rest, "^```lua\n?\r?(.*)```$") or rest

		local fn = CompileString(rest, "Discord", false)
		if type(fn) == "string" then
			return "❌ Lua compile error: " .. fn
		else
			local old_hook, old_mask, old_count = debug.gethook()
			debug.sethook(error, "", 1e7)

			table.Empty(LuaStdout)
			setfenv(fn, LuaEnv)

			local ok, res = pcall(fn)
			debug.sethook(old_hook, old_mask, old_count)

			if not ok then
				return "❌ Lua runtime error: " .. res
			else
				local count = table.Count(LuaStdout)
				local lout = ""
				if count > 0 then
					lout = fmt("\n📝 Lua output:\n```\n%s```", table.concat(LuaStdout, ""))
				end

				if res ~= nil then
					return "✅ Ran successfully and returned: ``" .. tostring(res) .. "``." .. lout
				else
					return "✅ Ran successfully." .. lout
				end
			end
		end
	end
)

Command (
	"rcon",
	"💻 Runs a serverside console command",
	PERMS.Operator,
	function(bot, data, rest)
		local args = string.Explode(" ", rest)
		local first = args[1]

		if first and string.Trim(first) ~= "" then
			RunConsoleCommand(first, unpack(args, 2))
			return "✅ Ran command: " .. first .. " " .. table.concat(args, " ", 2)
		else
			return "❔ Usage: ``rcon <command> <args...>`` (Like RunConsoleCommand)"
		end
	end
)

Command (
	"ram",
	"💻 Returns current memory usage of lua through the garbage collector",
	nil,
	function(bot, data, rest)
		return fmt("🖥️ Server ram usage:\n``%s``", string.NiceSize( collectgarbage("count") * 1000 ) )
	end
)

Command (
	"kick",
	"🥾 Kicks a player from the server",
	function(bot, data, rest)
		local name = string.match(rest, "%S+")
		if name then
			name = string.lower(name)
			for _, ply in ipairs(player.GetAll()) do
				if string.find(string.lower( ply:Nick() ), name, 1, true) then
					ply:Kick("Kicked by " .. data.author.username)
					return "🥾 Kicked ``" .. discordEscape(ply:Nick()) .. "``"
				end
			end
			return "❌ Couldn't find anyone with that name!"
		end
		return "❔ Usage: ``!kick <name>``"
	end
)

Command (
	"kill",
	"⚔️ Kills a player on the server",
	PERMS.Operator,
	function(bot, data, rest)
		local name = string.match(rest, "%S+")
		if name then
			name = string.lower(name)

			for _, ply in pairs(player.GetAll()) do
				if string.find(string.lower( ply:Nick() ), name, 1, true) then
					ply:Kill()
					return
				end
			end
			return "❌ Couldn't find anyone with that name!"
		else
			return "❔ Usage: ``!kill <name>``"
		end
	end
)

Command (
	"exit",
	"💣 Kills glink",
	PERMS.Operator,
	function(bot, data, rest)
		collectgarbage("collect")
		hook.Run("glink.shutdown", false)
		return "✅ Shutting down..."
	end
)

Command (
	"reload",
	"♻️ Reloads glink",
	PERMS.Operator,
	function(bot, data, rest)
		collectgarbage("collect")
		hook.Run("glink.shutdown", true)
		return "✅ Reloading..."
	end
)

return runCommand