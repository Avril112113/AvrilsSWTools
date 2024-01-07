---@param workspaceRoot Filepath
---@param inputFile Filepath
return function(workspaceRoot, inputFile)
	local FSUtils = LifeBoatAPI.Tools.FileSystemUtils

	local text = FSUtils.readAllText(inputFile)
	-- Remove old require sections.
	text = text:gsub("%-%-%-@require_folder ([%w\\/]+)\n.-%-%-%-@require_folder_finish\n", function(path)
		return ("---@require_folder %s\n"):format(path)
	end)
	-- [Re]add the requires, as new sections.
	local replaceCount
	---@param pathStr string
	text, replaceCount = text:gsub("%-%-%-@require_folder ([%w\\/]+)\n", function(pathStr)
		local path = workspaceRoot
		for part in pathStr:gmatch("([^\\/]*)") do
			if #part > 0 then
				path = path:add("/" .. part)
			end
		end
		local requires = {}
		for i, dir in ipairs(FSUtils.findDirsInDir(path)) do
			local dirPath = path:add("/" .. dir)
			local initPath = dirPath:add("/" .. "init.lua")
			local f = io.open(initPath:win(), "r")
			if f then
				f:close()
				local modPath = dirPath:relativeTo(workspaceRoot, true):linux():gsub("/", ".")
				table.insert(requires, ("require(\"%s\")"):format(modPath))
			end
		end
		for i, file in ipairs(FSUtils.findFilesInDir(path)) do
			local filePath = path:add("/" .. file)
			if inputFile.rawPath ~= filePath.rawPath and file:sub(-4, -1) == ".lua" then
				local modPath = filePath:relativeTo(workspaceRoot, true):linux():sub(1, -5):gsub("/", ".")
				table.insert(requires, ("require(\"%s\")"):format(modPath))
			end
		end
		local lines = {
			"---@require_folder " .. pathStr,
			table.concat(requires, "\n"),
			"---@require_folder_finish",
			""
		}
		return table.concat(lines, "\n")
	end)
	if replaceCount > 0 then
		FSUtils.writeAllText(inputFile, text)
	end
end
