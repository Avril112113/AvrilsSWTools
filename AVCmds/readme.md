# AVCmds
A full commands parser for Stormworks.  

Simply copy `avcmds.lua` and then `require("avcmds")`, if using a tool that combines files.  
Otherwise, just copy the contents of `avcmds.lua` into the top of your `script.lua`.  

See `./tests/` for many more examples.  

```lua
AVCmds.createCommand {name="poke"}
	:registerGlobalCommand()
	-- ?poke some_player
	-- ?poke 1
	-- ?poke 70123456781234567
	:addHandler {
		AVCmds.player(),
		---@param ctx AVCommandContext
		---@param target SWPlayer
		function(ctx, target)
			AVCmds.response{ctx, peer_id=target.id, "You were poked by", ctx.player.name}
			AVCmds.response{ctx, "You poked", target.name}
		end
	}
```

```lua
AVCmds.createCommand {name="test"}
	:registerGlobalCommand()
	-- ?foo
	:addHandler {
		AVCmds.const{"foo"},
		---@param ctx AVCommandContext
		function(ctx, _)
			AVCmds.response{ctx, "Foo?"}
		end
	}
	-- This handler will be checked before the one above, despite having the same first argument.
	-- ?foo abc123
	-- ?foo "quoted can have spaces"
	-- ?foo 'or if you need a " you can use single quotes'
	:addHandler {
		AVCmds.const{"foo"},
		AVCmds.string(),
		---@param ctx AVCommandContext
		---@param s string
		function(ctx, _, s)
			AVCmds.response{ctx, "Foo!", s}
		end
	}
	-- ?bar true
	-- ?bar yes
	-- ?bar no
	-- ?bar y
	-- ?bar n
	-- ?bar 123456
	-- ?bar -654321
	:addHandler {
		AVCmds.const{"bar"},
		AVCmds.or_{AVCmds.boolean(), AVCmds.number()},
		---@param ctx AVCommandContext
		---@param value boolean|number
		function(ctx, _, value)
			AVCmds.response{ctx, "Bar:", type(value), value}
		end
	}
```

```lua
-- A `?savedata` command for reading or modifying g_savedata

g_savedata = {}
g_savedata.somedata = {123, "456", [123]="potato"}

AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
AVCmds.createCommand {name="savedata"}
	:registerGlobalCommand()
	:addHandler {
		AVCmds.index(),
		AVCmds.if_{AVCmds.const{"="}, AVCmds.value()},
		---@param ctx AVCommandContext
		---@param path any[]|{raw:string}
		---@param value any
		function(ctx, path, value)
			local part = g_savedata
			for i=1,#path-1 do
				local key = path[i]
				part = part[key]
				if type(part) ~= "table" then
					part = {}
				end
			end
			local prefix
			if value == nil then
				value = part and part[path[#path]] or nil
				prefix = "GET"
			else
				part[path[#path]] = value
				prefix = "SET"
			end
			-- You can replace `tostring` with something that handles tables better.
			local value_str = tostring(value)
			local sep = (value_str:find("\n") or #value_str > 23) and "\n" or " "
			AVCmds.response{ctx, prefix, path.raw, "=" .. sep .. value_str}
		end
	}

--[[
	Example usages:
		?savedata somedata
		?savedata ['somedata']
		?savedata somedata[1]
		?savedata somedata[2]
		?savedata somedata[123]

		?savedata n = 123
		?savedata foo = ()
		?savedata foo.bar = 123
]]
```


To run the tests, ensure lua 5.3+ is installed and run `lua test/test.lua tests/cmds.lua`.  
