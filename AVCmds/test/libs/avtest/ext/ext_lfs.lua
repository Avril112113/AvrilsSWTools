local lfs = require "lfs"

local TestGroup = require "avtest.group"


---@param path string
---@param recursive boolean
---@return Group[]
---@diagnostic disable-next-line: duplicate-set-field
function TestGroup:loadFolder(path, recursive)
	local groups = {}
	for sub in lfs.dir(path) do
		local subpath = path .. "/" .. sub
		if sub:sub(-4, -1) == ".lua" then
			table.insert(groups, self:loadFile(subpath))
		elseif recursive and sub:sub(1, 1) ~= "." then
			local group = TestGroup.new(sub)
			self:addGroup(group)
			group:loadFolder(subpath, recursive)
			table.insert(groups, group)
		end
	end
	return groups
end
