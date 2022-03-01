util.AddNetworkString("discord_msg")

require("fix_require")
require("gwsockets")
require("glink/configs")

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

concommand.Add("glink_reload", function()
	MsgN("Reloading!")
	hook.Run("glink.shutdown", true)
end)