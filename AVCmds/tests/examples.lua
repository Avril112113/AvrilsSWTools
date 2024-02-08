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
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="savedata"}
		:registerGlobalCommand()

	error("TODO: All the stuff for a savedata command.")
end)

