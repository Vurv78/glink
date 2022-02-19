local rgb = Color
local BLACK, BLURPLE, WHITE = rgb(0, 0, 0), rgb(88, 101, 242), rgb(255, 255, 255)

net.Receive("discord_msg", function(len)
	local name, content, nattachments = net.ReadString(), net.ReadString(), net.ReadUInt(4)

	local attachments = {}
	for k = 1, nattachments do
		local url = net.ReadString()
		attachments[k] = url
	end

	-- Maybe data will be networked as the third arg but it's unnecessary and invasive.
	hook.Run("glink.message_created", name, content, nil, attachments)
end)

---@param username string
---@param content string
---@param attachments table<number, string> # URLs
hook.Add("glink.message_created", "glink.message_created.main", function(name, content, _, attachments)
	for _, attachment in ipairs(attachments) do
		if string.Trim(content) ~= "" then
			content = content .. "\n" .. url
		else
			content = attachment
		end
	end
	chat.AddText(BLACK, "[", BLURPLE, "Discord", BLACK, "] ", BLURPLE, name, WHITE, ": ", content)
end)