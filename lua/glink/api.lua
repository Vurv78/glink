local CONFIGS = include("glink/configs.lua")

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

---@param intent number
function Bot:addIntent(intent)
	assert( not self.socket:isConnected(), "Cannot change intents while online!" )
	self.intent = self.intent + bit.lshift(1, intent)
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

function Bot:kill()
	self.callbacks = {}
	self.killed = true
	self:disconnect()
	timer.Remove(fmt("discord_heartbeat_%p", self))
end

---@param evt string
---@param callback fun(data: table)
function Bot:onEvent(evt, callback)
	self.callbacks[evt] = self.callbacks[evt] or {}
	self.callbacks[evt][callback] = true
end

--- Connect to discord.
function Bot:connect()
	self.socket:open()
end

function Bot:disconnect()
	self.socket:closeNow()
end

return Bot, INTENT