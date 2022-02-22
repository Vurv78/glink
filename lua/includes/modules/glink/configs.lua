-- Mandatory configs
local WEBHOOK = cookie.GetString("DISCORD_WEBHOOK")
local BOT_TOKEN = cookie.GetString("DISCORD_TOKEN")

-- Prefix for commands
local PREFIX = cookie.GetString("DISCORD_BOT_PREFIX", "!")

-- Avatar shown in discord channel messages
local AVATAR = cookie.GetString("DISCORD_AVATAR", "https://cdn.discordapp.com/attachments/732861600708690010/937171111421038592/glua.png")

-- Gateway used to communicate w/ discord.
local GATEWAY = cookie.GetString("DISCORD_GATEWAY", "wss://gateway.discord.gg")

-- Bot / Webhook ID
local BOT_ID = cookie.GetString("DISCORD_BOT_ID", "936817398814765096")

-- ID of the channel to send messages to and listen to.
local LINK_CHANNEL_ID = cookie.GetNumber("DISCORD_LINK_CHANNEL_ID", 936817277720997940)

-- Steam question mark if we couldn't get the avatar of someone, or haven't yet.
local QMARK_AVATAR = cookie.GetString("DISCORD_UNKNOWNAVATAR", "https://cdn.discordapp.com/attachments/732861600708690010/937444253993422848/qmark.jpg")

local ENABLED = CreateConVar("glink_enabled", "1", FCVAR_ARCHIVE, "Enable Glink")


---@class DiscordConfigs
local Configs = {
	PREFIX = PREFIX,
	AVATAR = AVATAR,
	WEBHOOK = WEBHOOK,
	ENABLED = ENABLED,

	LINK_CHANNEL_ID = LINK_CHANNEL_ID,
	BOT_ID = BOT_ID,
	GATEWAY = GATEWAY,

	BOT_TOKEN = BOT_TOKEN,
	QMARK_AVATAR = QMARK_AVATAR,
}

return Configs