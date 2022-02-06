require("gwsockets")

---@type DiscordConfigs
local CONFIGS = include("configs.lua")
assert(CONFIGS.BOT_TOKEN, "Bot token is not set! Use cookie.Set('DISCORD_TOKEN', 'xyz')")

local ENABLED = GetConVar("glink_enabled")

---@class DiscordIntent
local INTENT = {
	GUILDS = 0,
	GUILD_MEMBERS = 1,
	GUILD_BANS = 2,
	GUILD_EMOJIS = 3,
	GUILD_INTEGRATIONS = 4,
	GUILD_WEBHOOKS = 5,
	GUILD_INVITES = 6,
	GUILD_VOICE_STATES = 7,
	GUILD_PRESENCES = 8,
	GUILD_MESSAGES = 9,
	GUILD_MESSAGE_REACTIONS = 10,
	GUILD_MESSAGE_TYPING = 11,
	DIRECT_MESSAGES = 12,
	DIRECT_MESSAGE_REACTIONS = 13,
	DIRECT_MESSAGE_TYPING = 14
}

-- Current bot
local CURRENT

--- Encode json and remove decimals (so use integers)
---@param input string
local function json(input)
	return string.gsub( util.TableToJSON(input), "(%d+)%.%d+", "%1" )
end
local fmt = string.format

---@alias EventData table

---@class DiscordMessage
---@field op number # Opcode of the packet
---@field d EventData
---@field t string # Name of the event being dispatched if d == 0

local Handlers = {
	---@param self DiscordBot
	---@param packet DiscordMessage
	[11] = function(self, packet)
		-- Heartbeat acknowledged
		-- Check in 5s to make sure discord has responded to heartbeat, else cut off connections.
		self.heartbeat_ack = true
	end,

	---@param self DiscordBot
	---@param packet DiscordMessage
	[10] = function(self, packet)
		-- Handshake
		local evt = packet.d

		self.socket:write(json {
			op = 2,
			d = {
				token = self.token,
				properties = { ["$os"] = "lua" },
				intents = self.intent
			}
		})

		local interval = evt.heartbeat_interval
		self.heartbeat = interval

		self:sendHeartbeat()

		timer.Create(fmt("discord_heartbeat_%p", self), interval / 1000, 0, function()
			assert( self.heartbeat_ack, "Discord failed to acknowledge heartbeat in time" )

			self:sendHeartbeat()
		end)
	end,

	---@param self DiscordBot
	---@param packet DiscordMessage
	[9] = function(self, packet)
		-- Invalid session
		self:kill()
	end,

	---@param self DiscordBot
	---@param packet DiscordMessage
	[7] = function(self, packet)
		-- Reconnect: Usually intents are wrong.
		ErrorNoHalt("[Discord] Reconnect!\n")
	end,

	---@param self DiscordBot
	---@param packet DiscordMessage
	[0] = function(self, packet)
		-- Dispatch
		local evt_data = packet.d
		local evt_name = packet.t

		local evt_callbacks = self.callbacks[evt_name]
		if evt_callbacks then
			for cb in pairs(evt_callbacks) do
				cb(evt_data)
			end
		end
	end
}

---@class DiscordBot
---@field socket userdata
---@field token string # Discord token
---@field callbacks table<string, table<number, fun(data: EventData)>>
---@field intent number
---@field heartbeat number # Heartbeat interval
---@field heartbeat_ack boolean # Whether the heartbeat has been acknowledged by discord.
---@field gc userdata # Userdata to detect being gc'd
local Bot = {}
Bot.__index = Bot

local function wrap(tbl, fn)
	return function(_, ...) return fn(tbl, ...) end
end

---@param token string
function Bot.new(token)
	local socket = GWSockets.createWebSocket(CONFIGS.GATEWAY)

	local instance = {
		socket = socket,
		token = token,
		intent = bit.lshift(1, 0), -- https://discord.com/developers/docs/topics/gateway#list-of-intents

		heartbeat_ack = false,
		heartbeat = 40000,

		callbacks = {},

		gc = newproxy(true)
	}

	socket.onMessage = wrap(instance, Bot.onMessage)
	socket.onError = wrap(instance, Bot.onError)
	socket.onConnected = wrap(instance, Bot.onConnected)
	socket.onDisconnected = wrap(instance, Bot.onDisconnected)

	debug.setmetatable(instance.gc, {
		__gc = function()
			instance:onGC()
		end
	})

	return setmetatable(instance, Bot)
end

function Bot:sendHeartbeat()
	self.socket:write(json {
		op = 1,
		d = 251
	})
	self.heartbeat_ack = false
end

function Bot:onGC()
	print("Discord link was gc'd")
	self:kill()
end

---@param intent number
function Bot:addIntent(intent)
	assert( not self.socket:isConnected(), "Cannot change intents while online!" )
	self.intent = self.intent + bit.lshift(1, intent)
end

function Bot:kill()
	self.callbacks = {}
	self.killed = true
	self:disconnect()
	timer.Remove(fmt("discord_heartbeat_%p", self))
end

---@param msg string
function Bot:onMessage(msg)
	---@type DiscordMessage
	local data = util.JSONToTable(msg)

	local handler = Handlers[data.op]
	if handler then
		handler(self, data)
	end
end

---@param evt string
---@param callback fun(data: table)
function Bot:onEvent(evt, callback)
	self.callbacks[evt] = self.callbacks[evt] or {}
	self.callbacks[evt][callback] = true
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

--- Connect to discord.
function Bot:connect()
	self.socket:open()
end

function Bot:disconnect()
	self.socket:closeNow()
end

local rgb = Color

local BLACK, BLURPLE, WHITE = rgb(0, 0, 0), rgb(88, 101, 242), rgb(255, 255, 255)

local Commands = include("commands.lua")
local Send, Notify, Http, Request = include("sender.lua")

function Startup()
	-- Hot reload probably
	if CURRENT then
		if CURRENT.socket:isConnected() then
			CURRENT:kill()
		end
		CURRENT = nil
	end

	local bot = Bot.new(CONFIGS.BOT_TOKEN)
	bot:addIntent(INTENT.GUILD_MESSAGES)

	bot:onEvent("GUILD_CREATE", function(data)
		print("Bot linked to: ", data.name)
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
				content = string.lower(content)
				local cmd = string.match(content, "^[%l]+$", 2)

				if cmd then
					local handler = Commands[cmd]
					if handler then
						local rest = string.match(content, "%S+%s+(.*)$") or ""
						local out = handler(bot, data, rest)
						if out then
							Notify(out)
						end
					else
						-- TODO: Say command not found.
						Notify("Command ``%s`` does not exist!", cmd)
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
	CURRENT = bot
end

---@param username string
---@param content string
---@param _data table
hook.Add("glink.message_created", "glink.message_created.main", function(username, content, _data)
	MsgC(BLACK, "[", BLURPLE, "Discord", BLACK, "] ", BLURPLE, username, WHITE, ": ", content, "\n")
end)

hook.Add("glink.shutdown", "glink.shutdown.main", function(restart)
	if CURRENT then
		CURRENT:kill()
	end
	if restart then
		-- Include self, autorefresh
		include("autorun/server/glink.lua")
	end
end)

if ENABLED:GetBool() then
	Startup()
end

cvars.AddChangeCallback("glink_enabled", function(_, old, new)
	if new == "0" and old == "1" and CURRENT then
		print("Disabled glink!")
		hook.Run("glink.shutdown", false)
	elseif new == "1" and old == "0" then
		print("Enabled glink!")
		Startup()
	else
		print("glink is already enabled.")
	end
end)