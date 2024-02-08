# AVCmds
A full commands parser for Stormworks.  

See `/tests/cmds.lua` for full usage examples.  

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


To run the tests, ensure lua is installed and run `lua test/test.lua tests/cmds.lua`.  
