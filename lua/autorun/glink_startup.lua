if SERVER then
	util.AddNetworkString("discord_cmsg")
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