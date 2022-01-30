if SERVER then
	util.AddNetworkString("discord_cmsg")

	local WEBHOOK = cookie.GetString("DISCORD_WEBHOOK")
	local DISCORD_AVATAR = cookie.GetString("DISCORD_AVATAR", "https://cdn.discordapp.com/attachments/732861600708690010/937171111421038592/glua.png")

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
		url = WEBHOOK,
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
			["avatar_url"] = DISCORD_AVATAR
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
			["avatar_url"] = DISCORD_AVATAR
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
end

if CLIENT then
	local rgb = Color
	local BLACK, BLURPLE, WHITE = rgb(0, 0, 0), rgb(88, 101, 242), rgb(255, 255, 255)

	print("Receiving")
	net.Receive("discord_cmsg", function(len)
		local name, content = net.ReadString(), net.ReadString()
		chat.AddText(BLACK, "[", BLURPLE, "Discord", BLACK, "] ", BLURPLE, name, WHITE, ": ", content)
	end)
end