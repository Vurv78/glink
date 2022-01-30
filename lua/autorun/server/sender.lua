-- Sender portion of glink.
---@type DiscordConfigs
local CONFIGS = include("configs.lua")
local http

-- Need reqwest or CHTTP to avoid the discord ban on steam requests.
if pcall(require, "reqwest") and reqwest ~= nil then
	http = reqwest
end

-- If you have chttp.
if not http and pcall(require, "chttp") and CHTTP ~= nil then
	http = CHTTP
end

-- Request template to re-use
local request = {
	method = "POST",
	url = CONFIGS.WEBHOOK,
	timeout = 3,

	body = "",

	headers = {
		["User-Agent"] = "", -- Bypass discord ban on steam user agent
		["Content-type"] = "application/json"
	},

	success = function(status, body, headers) end,

	failed = function(err, errExt)
		ErrorNoHalt("[Discord] Error: " .. err .. " (" .. errExt .. ")")
	end
}

---@param sender string
---@param content string
local function send(sender, content)
	request.body = util.TableToJSON {
		["content"] = content,
		["username"] = sender,
		["avatar_url"] = CONFIGS.AVATAR
	}
	http(request)
end

hook.Add("PlayerSay", "discord_playersay", function(ply, text, teamchat)
	if not teamchat then
		send(ply:Nick(), text)
	end
end)

local function notify(fmt, ...)
	local content = string.format(fmt, ...)
	request.body = util.TableToJSON {
		["content"] = content,
		["username"] = "GLua",
		["avatar_url"] = CONFIGS.AVATAR
	}
	http(request)
end

-- Basic escape patcher
local function discordEscape(msg)
	return string.gsub(msg, "`", "\\`")
end

hook.Add("PlayerDisconnected", "discord_playerleave", function(ply)
	local name = ply:Nick()
	notify("``%s`` has left the server.", discordEscape(name))
end)

hook.Add("PlayerConnect", "discord_playerjoin", function(name)
	notify("``%s`` is connecting to the server.", discordEscape(name))
end)

return send, notify, http, request