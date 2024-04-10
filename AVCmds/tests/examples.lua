require "test_game_fill"
require "avcmds"
local Utils = require "test_utils"

Utils.setup(TEST)


local MATCH_ERRORS = AVCmds.MATCH_ERRORS


TEST.addTest("1", function ()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
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

	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?poke Foo", 0)))
end)


TEST.addTest("2", function ()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
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

	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test foo", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test foo abc123", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test foo \"quoted can have spaces\"", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test foo 'or if you need a \" you can use single quotes'", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar true", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar yes", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar no", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar y", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar n", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar 123456", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test bar -654321", 0)))
end)


TEST.addTest("3", function ()
	-- A `?savedata` command for reading or modifying g_savedata

	local g_savedata = {}
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

	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata", "somedata"}}}, AVCmds.onCustomCommand("?savedata somedata", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata", "somedata"}}}, AVCmds.onCustomCommand("?savedata [ 'somedata' ]", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata[1]", "somedata", 1}}}, AVCmds.onCustomCommand("?savedata somedata[1]", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata[2]", "somedata", 2}}}, AVCmds.onCustomCommand("?savedata somedata[2]", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata[123]", "somedata", 123}}}, AVCmds.onCustomCommand("?savedata somedata[123]", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata[123]", "somedata", 123}}}, AVCmds.onCustomCommand("?savedata ['somedata'][123]", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="[123]", 123}}}, AVCmds.onCustomCommand("?savedata [123]", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="a.b.c", "a", "b", "c"}}}, AVCmds.onCustomCommand("?savedata a.b.c", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata[123].foo", "somedata", 123, "foo"}}}, AVCmds.onCustomCommand("?savedata somedata[123].foo ", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="somedata[123].foo", "somedata", 123, "foo"}}}, AVCmds.onCustomCommand("?savedata somedata [ 123 ] . foo ", 0)))

	TEST.check(Utils.cmd_expect({handled=true, args={{raw="n", "n"}, 123}}, AVCmds.onCustomCommand("?savedata n = 123", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="n", "n"}}}, AVCmds.onCustomCommand("?savedata n", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="foo", "foo"}, {}}}, AVCmds.onCustomCommand("?savedata foo = ()", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="foo", "foo"}}}, AVCmds.onCustomCommand("?savedata foo", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="foo.bar", "foo", "bar"}, 123}}, AVCmds.onCustomCommand("?savedata foo.bar = 123", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{raw="foo.bar", "foo", "bar"}}}, AVCmds.onCustomCommand("?savedata foo.bar", 0)))
end)

