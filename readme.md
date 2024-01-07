# AvrilsSWTools
A collection of tools for developing StormWorks addons and micro controllers.  

Any folders starting with `CodeGen` may modify the source file to provide it's feature.  
Ensure there is a backup (like using git) before using these, in the case of code generation bugs.  


## `Libraries/`
Collection of code for micro-controllers.  
Most files are self-explanatory.  


## `AutoVehicleUpdater/`
A `_buildactions.lua` tool to automatically update code in a vehicle file.  
Upon building once, `_build/update_vehicle_config.lua` will be generated.  
Getting the lua node id can be tricky, see config example below, as this will automatically list them for you.  
Setup:  
```lua
package.path = package.path .. ";../AvrilsSWTools/AutoVehicleUpdater/?.lua"

---@param builder Builder           builder object that will be used to build each file
---@param params MinimizerParams    params that the build process usees to control minification settings
---@param workspaceRoot Filepath    filepath to the root folder of the project
function onLBBuildComplete(builder, params, workspaceRoot)
    require("update_vehicle")(builder, params, workspaceRoot)
end
```
`_build/update_vehicle_config.lua` example:  
```lua
return
{
	{
		-- Vehicle save name
		vehicle="ATAddon Interface",
		microcontrollers = {
			["MyMicroControllerName"] = {},
			-- After getting this far, run the build and the lua node IDs will fill out for you.
			-- If there are multiple lua nodes, the larger the ID, the new later they were placed.
			-- Once they are filled out, set the value from `false` to a string, being the filename without the `.lua` extension.
			["Interface Controller"] = {
				-- [LuaNodeID] = "FILENAME_WITHOUT_EXTENSION"
				[46] = "Interface Controller",
			},
		}
	},
	{
		...
	}
}
```


## `AddonUpdater`
Used to automatically update addon's `script.lua` upon building.  
Usage:  
```lua
package.path = package.path .. ";../AvrilsSWTools/AddonUpdater/?.lua"
local update_addon = require "update_addon"

---@param builder Builder
---@param params MinimizerParams
---@param workspaceRoot Filepath
function onLBBuildComplete(builder, params, workspaceRoot)
	-- Providing an empty table will use the defaults as described below.
	update_addon(builder, workspaceRoot, {})

	update_addon(builder, workspaceRoot, {
		-- Path of the missions folder, defaults to '%appdata%/Stormworks/data/missions'
		missions_path = "SomePath/Stormworks/data/missions",
		-- name of the addon in the missions folder, defaults to the name of root folder.
		addon_name = "MyAwesomeAddon",
		-- file to use to update addon script, defaults to "script.lua".
		script_file = "alternate_script.lua",
	})
end
```


## `CodeGen_RequireFolder`
Generates a `require()` call for every lua file (or folder with `init.lua`).  
As the name implies, this is using code generation and does modify the source file!  
Usage:  
```lua
package.path = package.path .. ";../AvrilsSWTools/AddonUpdater/?.lua"
local update_addon = require "update_addon"

---@param builder Builder
---@param params MinimizerParams
---@param workspaceRoot Filepath
function onLBBuildComplete(builder, params, workspaceRoot)
	-- Providing an empty table will use the defaults as described below.
	update_addon(builder, workspaceRoot, {})

	update_addon(builder, workspaceRoot, {
		-- Path of the missions folder, defaults to '%appdata%/Stormworks/data/missions'
		missions_path = "SomePath/Stormworks/data/missions",
		-- name of the addon in the missions folder, defaults to the name of root folder.
		addon_name = "MyAwesomeAddon",
		-- file to use to update addon script, defaults to "script.lua".
		script_file = "alternate_script.lua",
	})
end
```
