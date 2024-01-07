---@param builder Builder
---@param workspaceRoot Filepath
---@param args {missions_path:string?,addon_name:string?,script_file:string?}
return function(builder, workspaceRoot, args)
	local FilePath = LifeBoatAPI.Tools.Filepath

	local missions_path = (args.missions_path and FilePath:new(args.missions_path)) or FilePath:new(os.getenv("appdata")):add("/Stormworks/data/missions")
	local addon_name = assert(args.addon_name or workspaceRoot:filename())
	local script_name = args.script_file or "script.lua"

	local release_script_file_path = builder.outputDirectory:add("/release/" .. script_name)
	local mission_script_file_path = missions_path:add("/"..addon_name):add("/script.lua")
	LifeBoatAPI.Tools.FileSystemUtils.copyFile(release_script_file_path, mission_script_file_path)
	print(("Addon script updated \"%s\" -> \"%s\""):format(release_script_file_path:relativeTo(workspaceRoot):win():sub(2), mission_script_file_path:win()))
end
