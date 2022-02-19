util.AddNetworkString("discord_msg")
CreateConVar("glink_enabled", "1", FCVAR_ARCHIVE)

require("gwsockets")

---@type DiscordConfigs
local CONFIGS = include("glink/configs.lua")
assert(CONFIGS.BOT_TOKEN, "Bot token is not set! Use cookie.Set('DISCORD_TOKEN', 'xyz')")

---@type fun()
local Startup = include("glink/bot.lua")

local rgb = Color
local BLACK, BLURPLE, WHITE = rgb(0, 0, 0), rgb(88, 101, 242), rgb(255, 255, 255)

---@param username string
---@param content string
---@param _data table
hook.Add("glink.message_created", "glink.message_created.main", function(username, content, _data)
	MsgC(BLACK, "[", BLURPLE, "Discord", BLACK, "] ", BLURPLE, username, WHITE, ": ", content, "\n")
end)

cvars.AddChangeCallback("glink_enabled", function(_, old, new)
	if new == "0" and old == "1" then
		print("Disabled glink!")
		hook.Run("glink.shutdown", false)
	elseif new == "1" and old == "0" then
		print("Enabled glink!")
		Startup()
	else
		print("glink is already enabled.")
	end
end, "main2")