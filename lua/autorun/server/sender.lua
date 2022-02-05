-- Sender portion of glink.
---@type DiscordConfigs
local CONFIGS = include("configs.lua")
-- Player avatars
local Avatars = {}

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

	success = function(status, body, headers)
		if status ~= 204 then
			ErrorNoHalt("[Discord] Error: " .. body .. "\n")
		end
	end,

	failed = function(err, errExt)
		ErrorNoHalt("[Discord] Error: " .. err .. " (" .. errExt .. ")")
	end
}

--- Gets the avatar of a player asynchronously
local function storeAvatar(player)
	http {
		method = "GET",
		url = "https://steamcommunity.com/profiles/" .. player:SteamID64() .. "?xml=1",
		timeout = 2,
		success = function(len, data)
			local avatar = string.match(data, "<avatarFull><!%[CDATA%[([^]]*)%]%]></avatarFull>")
			if #avatar <= 2048 then
				Avatars[player] = avatar
			else
				ErrorNoHalt("[Discord] Error: " .. player:Nick() .. "'s Avatar is too large, falling back to question mark!\n")
				Avatars[player] = CONFIGS.QMARK_AVATAR
			end
		end,

		failed = function(err)
			ErrorNoHalt("[Discord] Failed to retrieve avatar: " .. tostring(err) .. "\n")
		end
	}
end

---@param sender GPlayer
---@param content string
local function send(ply, content)
	local avatar = Avatars[ply]
	if not avatar then
		avatar = CONFIGS.QMARK_AVATAR
		storeAvatar(ply)
	end

	request.body = util.TableToJSON {
		["content"] = content,
		["username"] = ply:Nick(),
		["avatar_url"] = avatar
	}
	http(request)
end

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

local function addHooks()
	hook.Add("PlayerSay", "discord_playersay", function(ply, text, teamchat)
		if not teamchat then
			send(ply, text)
		end
	end)

	hook.Add("PlayerDisconnected", "discord_playerleave", function(ply)
		notify("``%s`` has left the server.", discordEscape(ply:Nick()))
		Avatars[ply] = nil
	end)

	hook.Add("PlayerConnect", "discord_playerjoin", function(name)
		notify("``%s`` is connecting to the server.", discordEscape(name))
	end)

	hook.Add("PlayerInitialSpawn", "discord_playerspawn", function(ply)
		if ply:IsBot() then
			notify("``%s`` has joined the server.", ply:Nick() or ply.OriginalName)
		else
			notify("``%s`` has joined the server.", discordEscape(ply:Nick()))
			storeAvatar(ply)
		end
	end)

	hook.Add("PlayerDeath", "discord_playerdeath", function(victim, inflictor, attacker)
		if victim == attacker then
			return notify("``%s`` suicided!", discordEscape(victim:Nick()))
		end

		if attacker:IsPlayer() then
			return notify("``%s`` was killed by ``%s``.", discordEscape(victim:Nick()), discordEscape(attacker:Nick()))
		else
			return notify("``%s`` was killed by ``%s``", discordEscape(victim:Nick()), attacker:GetClass())
		end
	end)
end

-- This should probably be centralized onto some onStartup hook or something.
cvars.AddChangeCallback("glink_enabled", function(_, old, new)
	if new == "1" and old == "0" then
		addHooks()
		print("Added glink commands!")
	end
end, "main")

hook.Add("glink.shutdown", function()
	hook.Remove("PlayerSay", "discord_playersay")
	hook.Remove("PlayerDisconnected", "discord_playerleave")
	hook.Remove("PlayerConnect", "discord_playerjoin")
	hook.Remove("PlayerInitialSpawn", "discord_playerspawn")
	hook.Remove("PlayerDeath", "discord_playerdeath")

	cvars.RemoveChangeCallback("glink_enabled", "main")
end)

return send, notify, http, request