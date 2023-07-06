local SW_VEHICLES_PATH = os.getenv("APPDATA") .. "/Stormworks/data/vehicles/"

-- LifeboatAutoUpdateTest
local UPDATE_CONFIG = require("_build.update_vehicle_config")

local function stringInsert(str1, str2, pos)
    return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

--- Modified `LifeBoatAPI.Tools.FileSystemUtils.readAllText`
---reads all text from a file and returns it as a string
---@param filePath Filepath path to read from
---@return string? text from the file
local function readAllText(filePath)
	local file = io.open(filePath:win(), "r")
	if file == nil then
		return nil
	end
	local data = file:read("*a")
	file:close()
	return data
end

---@param pattern string
---@return string
local function escapePattern(pattern)
	return (pattern:gsub("[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1"))
end
---@param pattern string
---@return string
local function escapeReplPattern(pattern)
	return (pattern:gsub("%%", "%%%%"))
end

local function escapeXml(s)
	return (
		s
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub("'", "&apos;")
		:gsub("\"", "&quot;")
	)
end

---@param name string
---@return string
local function fileNameSrcToOut(name)
	return name:lower()
end

local function strConfig()
	local parts = {"return\n{\n"}
	for _, vehicle in ipairs(UPDATE_CONFIG) do
		table.insert(parts, "\t{\n")
		table.insert(parts, "\t\tvehicle=\"" .. vehicle.vehicle .. "\",\n")
		table.insert(parts, "\t\tmicrocontrollers = {\n")
		for name, nodes in pairs(vehicle.microcontrollers) do
			table.insert(parts, "\t\t\t[\"" .. name .. "\"] = {\n")
			for id, filename in pairs(nodes) do
				local value
				if type(filename) == "string" then
					value = "\"" .. filename .. "\""
				else
					value = tostring(filename)
				end
				table.insert(parts, "\t\t\t\t[" .. id .. "] = " .. value .. ",\n")
			end
			table.insert(parts, "\t\t\t},\n")
		end
		table.insert(parts, "\t\t}\n")
		table.insert(parts, "\t},\n")
	end
	table.insert(parts, "}\n")
	return table.concat(parts)
end

---@param builder Builder           builder object that will be used to build each file
---@param params MinimizerParams    params that the build process usees to control minification settings
---@param workspaceRoot Filepath    filepath to the root folder of the project
return function(builder, params, workspaceRoot)
	local FSUtils = LifeBoatAPI.Tools.FileSystemUtils
	local Filepath = LifeBoatAPI.Tools.Filepath

	local vehicleFiles = FSUtils.findFilesInDir(Filepath:new(SW_VEHICLES_PATH))
	if #vehicleFiles <= 0 then
		print("Failed to find any vehicles in \"" .. SW_VEHICLES_PATH .. "\"")
		return
	end
	local codeCache = {}
	local function readSourceFile(sourceFileName)
		if codeCache[sourceFileName] ~= nil then
			return codeCache[sourceFileName]
		end
		local outFileName = fileNameSrcToOut(sourceFileName) .. ".lua"
		local filepath = builder.outputDirectory:add("/release/"..outFileName)
		local source = FSUtils.readAllText(filepath)
		codeCache[sourceFileName] = source
		return source
	end

	for i, vehicle in ipairs(UPDATE_CONFIG) do
		local vehicleFilePath = SW_VEHICLES_PATH .. vehicle.vehicle .. ".xml"

		local vehicleData = readAllText(Filepath:new(vehicleFilePath))
		if vehicleData == nil then
			print("WARN: Skipped file \"" .. vehicleFilePath .. "\", unable to read contents.")
			goto continue
		end
		local originalVehicleData = vehicleData
		print("Updating vehicle \"" .. vehicleFilePath .. "\"")

		for microControllerXML, name in vehicleData:gmatch("(<microprocessor_definition name=\"([^\"]+)\"[^>]+>.-</microprocessor_definition>)") do
			local microcontroller = vehicle.microcontrollers[name]
			if microcontroller == nil then
				goto continue
			end
			print("- Updating MicroController \"" .. name .. "\"")
			local originalMicroControllerXML = microControllerXML

			for nodeXML, tag, nodeID in microControllerXML:gmatch("((<c type=\"56\">.-<object id=\"(%d+)\").-</object>.-</c>)") do
				nodeID = tonumber(nodeID)
				local sourceFileName = microcontroller[nodeID]
				if type(sourceFileName) ~= "string" then
					microcontroller[nodeID] = false
					goto continue
				end
				print("- - Updating LuaNode " .. nodeID)
				local originalNodeXML = nodeXML

				local newScriptSource = readSourceFile(sourceFileName)
				local tagValue = "script=\"" .. escapeXml(newScriptSource) .. "\""
				if nodeXML:find("script=[\"']") ~= nil then
					nodeXML = nodeXML:gsub("script=[\"'].-[\"']>", escapeReplPattern(tagValue .. ">"))
				else
					nodeXML = stringInsert(nodeXML, " " .. tagValue, #tag)
					print("- - - Creating new script tag value")
				end

				if originalNodeXML ~= nodeXML then
					print("- - - Changed detected, updating")
					local _, c = microControllerXML:gsub(escapePattern(originalNodeXML), escapeReplPattern(nodeXML))
					microControllerXML = microControllerXML:gsub(escapePattern(originalNodeXML), escapeReplPattern(nodeXML))
				else
					print("- - - No changes detected")
				end
				::continue::
			end

			-- We know that each section of XML is different if it needs to be updated separately
			-- The ONLY case where it MIGHT be the same, is if it is literally a copy-pasted chip, in which case it doesn't matter
			vehicleData = vehicleData:gsub(escapePattern(originalMicroControllerXML), escapeReplPattern(microControllerXML))
			::continue::
		end
		if originalVehicleData ~= vehicleData then
			print("- Writing vehicle")
			FSUtils.writeAllText(Filepath:new(vehicleFilePath .. ".backup"), originalVehicleData)
			FSUtils.writeAllText(Filepath:new(vehicleFilePath), vehicleData)
		else
			print("- No changes where actually made, skipping write")
		end
		::continue::
	end

	FSUtils.writeAllText(workspaceRoot:add("/_build/update_vehicle_config.lua"), strConfig())
end
