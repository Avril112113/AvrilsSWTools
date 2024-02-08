---@meta # Shhh, less complaining LuaLS


server = {}
_G.server = server  -- Needed if we are in a test.

---@return table<number, SWPlayer> players
function server.getPlayers()
	return {
		{
			id=0,
			name="Avril112113",
			admin=true,
			auth=true,
			steam_id=76561198111587390,
		},
		{
			id=1,
			name="Foo",
			admin=false,
			auth=true,
			steam_id=60638742392402103,
		},
		{
			id=2,
			name="Bar",
			admin=false,
			auth=true,
			steam_id=60593461394127499,
		},
	}
end

function server.getAddonIndex(name)
	return 1
end

function server.getAddonData(index)
	return {
		name="Test"
	}
end

--- @param name string The display name of the user sending the message
--- @param message string The message to send the player(s)
--- @param peerID number|nil The peerID of the player you want to message. -1 messages all players. If ignored, it will message all players
---@diagnostic disable-next-line: duplicate-set-field
function server.announce(name, message, peerID)
	print(("%.0f:[%s]: %s"):format(peerID or -1, name, message))
end
