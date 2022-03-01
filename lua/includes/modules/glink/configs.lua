--[[
	Mandatory Configs
	TODO: All of these configs maybe should be convars.. I mean that's literally what they're for.
]]
local WEBHOOK = assert( cookie.GetString("DISCORD_WEBHOOK"), "Webhook link is not set! Use cookie.Set('DISCORD_WEBHOOK', 'xyz')" )
local BOT_TOKEN = assert( cookie.GetString("DISCORD_TOKEN"), "Bot token is not set! Use cookie.Set('DISCORD_TOKEN', 'xyz')" )

--[[
	Optional Configs
]]

--[[
	Content / Images
]]
-- Avatar shown in discord channel messages
local AVATAR = cookie.GetString("DISCORD_AVATAR", "https://cdn.discordapp.com/attachments/732861600708690010/937171111421038592/glua.png")

-- Gateway used to communicate w/ discord.
local GATEWAY = cookie.GetString("DISCORD_GATEWAY", "wss://gateway.discord.gg")

-- Bot / Webhook ID
local BOT_ID = cookie.GetString("DISCORD_BOT_ID")

-- Steam question mark if we couldn't get the avatar of someone, or haven't yet.
local QMARK_AVATAR = cookie.GetString("DISCORD_UNKNOWNAVATAR", "https://cdn.discordapp.com/attachments/732861600708690010/937444253993422848/qmark.jpg")

local function CvarInt(...)
	return { "GetInt", CreateConVar(...) }
end

local function CvarStr(...)
	return { "GetString", CreateConVar(...) }
end

local function CvarBool(...)
	return { "GetBool", CreateConVar(...) }
end

local Convars = {
	LinkChannel = CvarStr("glink_channel_id", "", {FCVAR_PROTECTED, FCVAR_ARCHIVE, FCVAR_UNLOGGED, FCVAR_DONTRECORD}, "Channel ID to send messages to and listen to."),
	Prefix = CvarStr("glink_bot_prefix", "!", FCVAR_ARCHIVE, "Prefix to use with glink discord-side. Default !"),
	PermsRole = CvarStr("glink_perms_role", "", FCVAR_ARCHIVE, "ID of Admin / OP Role for permissions with glink commands."),
	Enabled = CvarBool("glink_enabled", "1", FCVAR_ARCHIVE, "Enable Glink"),
}

---@class DiscordConfigs
---@field LinkChannel string
---@field Prefix string
---@field PermsRole string
---@field Enabled boolean
local Configs = {
	AVATAR = AVATAR,
	WEBHOOK = WEBHOOK,
	BOT_TOKEN = BOT_TOKEN,

	BOT_ID = BOT_ID,
	GATEWAY = GATEWAY,
	QMARK_AVATAR = QMARK_AVATAR,
}

-- Indexing will get the convar value dynamically.
setmetatable(Configs, {
	__index = function(_, k)
		local cvar_data = rawget(Convars, k)
		if cvar_data then
			local cvar_access, cvar = cvar_data[1], cvar_data[2]
			return cvar[cvar_access](cvar)
		end
	end
})

assert(Convars.LinkChannel and Convars.LinkChannel ~= "", "Channel ID is not set! Use glink_channel_id cvar.")

return Configs