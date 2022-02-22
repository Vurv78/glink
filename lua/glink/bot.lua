local ENABLED = GetConVar("glink_enabled")

local CONFIGS = require("glink/configs")

---@type DiscordBot
local Bot, INTENT = include("glink/api.lua")

---@type fun(cmd: string, bot: DiscordBot, data: table, rest: string): string?
local runCommand = include("glink/commands.lua")

local Send, Notify, Http, Request = include("glink/webhook.lua")

local CURRENT_BOT

function Bot:onGC()
	print("Discord link was gc'd")
	self:kill()
end

---@param msg string
function Bot:onError(msg)
	ErrorNoHalt("[Discord] Errored: ", msg)
end

function Bot:onConnected() end

local Startup

function Bot:onDisconnected()
	if self.killed then return end -- Manually killed
	self:kill()

	print("Bot was disconnected, reconnecting in 5 seconds....")
	timer.Simple(5, Startup)
end

local loadUserdata, saveUserdata, setUserdata = require("glink/db")

function Startup()
	-- Hot reload probably
	if CURRENT_BOT then
		if CURRENT_BOT.socket:isConnected() then
			CURRENT_BOT:kill()
		end
		CURRENT_BOT = nil
	end

	loadUserdata()

	local bot = Bot.new(CONFIGS.BOT_TOKEN)
	bot:addIntent(INTENT.GUILD_MESSAGES)

	bot:onEvent("GUILD_CREATE", function(data)
		print("Bot linked to: ", data.name)
	end)

	-- Cache user names and IDs for mentions.
	bot:onEvent("MESSAGE_CREATE", function(data)
		local author_name, author_id = data.author.username, data.author.id

		local channel_id = tonumber(data.channel_id)
		if channel_id == CONFIGS.LINK_CHANNEL_ID and author_id ~= CONFIGS.BOT_ID then
			setUserdata(author_name, author_id)
		end
	end)

	bot:onEvent("MESSAGE_CREATE", function(data)
		local attachments, nattach = data.attachments, #data.attachments
		if nattach > 0 then
			for k = 1, math.min(nattach, 15) do
				attachments[k] = attachments[k].url
			end
		end

		-- https://discord.com/developers/docs/resources/channel#message-object
		local channel_id = tonumber(data.channel_id)
		if channel_id == CONFIGS.LINK_CHANNEL_ID and data.author.id ~= CONFIGS.BOT_ID then
			local username, content = data.author.username, data.content

			if string.sub(content, 1, 1) == CONFIGS.PREFIX then
				local cmd = string.match(content, "^(%w+)", 2)

				if cmd then
					-- Get rest of the message, excluding the initial invocation and the space afterward.
					-- !lua ```lua
					--      ^ After here, so rest would be "```lua".
					-- Add 3 to length of command for the prefix, the space and to start at 1.
					-- This wouldn't support prefixes larger than 1 character (but that's awful anyway).
					local rest = string.sub(content, #cmd + 3)
					cmd = string.lower(cmd)

					local msg = runCommand(cmd, bot, data, rest)
					if msg then
						Notify("%s", msg)
					end
				end
			end

			hook.Run("glink.message_created", username, content, data, attachments)

			net.Start("discord_msg")
				net.WriteString(username)
				net.WriteString(content)

				net.WriteUInt(nattach, 4)
				for k = 1, nattach do
					net.WriteString(attachments[k])
				end
			net.Broadcast()
		end
	end)

	bot:connect()
	CURRENT_BOT = bot
end

if ENABLED:GetBool() then
	Startup()
end

hook.Add("glink.shutdown", "glink.shutdown.main", function(restart)
	if CURRENT_BOT then
		CURRENT_BOT:kill()
	end
	if restart then
		-- Include self, autorefresh
		include("autorun/server/glink.lua")
	end

	cvars.RemoveChangeCallback("glink_enabled", "main")
	cvars.RemoveChangeCallback("glink_enabled", "main2")
end)

return Startup