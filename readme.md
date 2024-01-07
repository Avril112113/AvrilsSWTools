# AvrilsSWTools
A collection of tools for developing StormWorks addons and micro controllers.  

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
