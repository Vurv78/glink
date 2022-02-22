---@class Userdata
---@field len number # U8 (username is max 32 chars)
---@field id number # U64

-- Not gonna use sql. No thanks
---@type table<string, Userdata>
local UData = {}
local UDataLen = 0

local U32_MAX = 4294967296

---@param handle file # File handle
---@return number # U64
local function fRead64(handle)
	return handle:ReadULong() + handle:ReadULong() * U32_MAX
end

---@param handle file # File handle
local function fWrite64(handle, u64)
	handle:WriteULong( u64 % U32_MAX )
	handle:WriteULong( math.floor(u64 / U32_MAX) )
end

local function loadUserdata()
	local handle = file.Open("glink_db.txt", "rb", "DATA")
	if not handle then return end -- File doesn't exist yet.

	UDataLen = handle:ReadULong()
	for _ = 1, UDataLen do
		local name_len = handle:ReadByte()
		local name = handle:Read( name_len )
		local id = fRead64(handle)

		UData[name] = { len = name_len, id = id }
	end

	handle:Close()
end

local UDataChanged = false
local function saveUserdata()
	if not UDataChanged then return end

	local handle = file.Open("glink_db.txt", "wb", "DATA")

	for name, data in pairs(UData) do
		handle:WriteByte(data.len)
		handle:Write(name)
		fWrite64(handle, data.id)
	end
	UDataChanged = false
end

---@param name string
---@param id number # U64
local function setUserdata(name, id)
	if not UData[name] then
		UDataLen = UDataLen + 1
	end
	-- Replace
	UData[name] = { len = #name, id = id }
	UDataChanged = true
end

---@param name string
local function getUserdata(name)
	return UData[name]
end

return loadUserdata, saveUserdata, setUserdata, getUserdata