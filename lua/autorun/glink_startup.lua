if SERVER then
	util.AddNetworkString("discord_msg")

	CreateConVar("glink_enabled", "1", FCVAR_ARCHIVE)
end

if CLIENT then
	local rgb = Color
	local BLACK, BLURPLE, WHITE = rgb(0, 0, 0), rgb(88, 101, 242), rgb(255, 255, 255)

	net.Receive("discord_msg", function(len)
		local name, content, nattachments = net.ReadString(), net.ReadString(), net.ReadUInt(4)
		for _ = 1, nattachments do
			local url = net.ReadString()
			if string.Trim(content) ~= "" then
				content = content .. "\n" .. url
			else
				content = url
			end
		end
		chat.AddText(BLACK, "[", BLURPLE, "Discord", BLACK, "] ", BLURPLE, name, WHITE, ": ", content)
	end)
end