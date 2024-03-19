require "test_game_fill"
require "avcmds"
local Utils = require "test_utils"

Utils.setup(TEST)


---@param name string
local function gen_default_handler(name)
	---@param ctx AVCommandContext
	return function (ctx, ...)
		print("~ " .. name)
		print(table.concat(AVCmds.toparts_context_path(ctx), " "))
		for i, v in pairs({...}) do
			print(i, Utils.str_value(v))
		end
	end
end


local MATCH_ERRORS = AVCmds.MATCH_ERRORS


TEST.addTest("basic", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	local test_cmd = AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			---@param ctx AVCommandContext
			function(ctx)
				print("~ test command was run!")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
			end
		}
	test_cmd:addHandler {
		AVCmds.const{"test"},
		test_cmd
	}

	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test", 0)))
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test test test", 0)))
	TEST.check(Utils.cmd_expect({handled=false}, AVCmds.onCustomCommand("?testtest", 0)))  --
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_CONST}, AVCmds.onCustomCommand("?test testtest", 0)))  --
	TEST.check(Utils.cmd_expect({handled=false}, AVCmds.onCustomCommand("?non_existo", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			---@param ctx AVCommandContext
			function(ctx)
				return {
					err="CUSTOM_ERR", pos=ctx.pos,
					msg="This is a custom error.",
					brief="Always error",
				}
			end
		}
		:addHandler {
			AVCmds.number(),
			---@param ctx AVCommandContext
			function(ctx, n)
				if n == 123 then
					return {
						err="SCARY_123", pos=ctx.pos,
						msg="Oh no, it's 123!",
						brief="Not 123",
					}
				end
			end
		}

	TEST.check(Utils.cmd_expect({handled=true,err="CUSTOM_ERR"}, AVCmds.onCustomCommand("?test", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err="SCARY_123"}, AVCmds.onCustomCommand("?test 123", 0)))
end)

TEST.addTest("prehandlers", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addPreHandler(
			---@param ctx AVCommandContext
			function(ctx)
				local args = ctx.args
				if type(args[1]) == "string" then
					if #args[1] ~= 3 then
						---@type AVMatchError
						return {
							err=MATCH_ERRORS.BAD_STRING_LEN,pos=ctx.pos,
							msg="Must be a length of 3", expected="length of 3"
						}
					end
				end
			end
		)
		:addHandler {
			AVCmds.string{},
			AVCmds.createCommand {}
				:addPreHandler(
					---@param ctx AVCommandContext
					function(ctx)
						local parent_args = ctx.parent.args
						---@cast parent_args {[1]:string}
						if parent_args[1]:sub(1, 1) ~= "f" then
							---@type AVMatchError
							return {
								err=MATCH_ERRORS.BAD_STRING,pos=ctx.pos,
								msg="Must start with 'f'", expected="Starts with 'f'"
							}
						end
					end
				)
				:addHandler {
					AVCmds.number{},
					gen_default_handler("arg test prehandlers")
				}
				:addHandler {
					AVCmds.boolean{},
					gen_default_handler("arg test prehandlers")
				}
		}

	TEST.check(Utils.cmd_expect({handled=true,args={123}}, AVCmds.onCustomCommand("?test foo 123", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test foo true", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_STRING_LEN}, AVCmds.onCustomCommand("?test foooo -2", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_STRING_LEN}, AVCmds.onCustomCommand("?test foooo false", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_STRING}, AVCmds.onCustomCommand("?test bar -1", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_STRING}, AVCmds.onCustomCommand("?test bar false", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addPreHandler(
			---@param ctx AVCommandContext
			function(ctx)
				return true
			end
		)
		:addHandler {
			AVCmds.createCommand {}
				:addHandler{
					AVCmds.string{},
					gen_default_handler("arg test prehandlers")
				}
		}

	-- Note that the arguments are empty here, if it matched further it'd have errored with BAD_STRING.
	-- It didn't match futher however, because of using a sub-command.
	TEST.check(Utils.cmd_expect({handled=true,args={}}, AVCmds.onCustomCommand("?test", 0)))

	--[[ To better describe what is happening here:
		Pre handlers are run before a normal handler,
		however this only applies to the current command, and in this case the handler does indeed match as it requires no arguments.
		So the handler is run, but before that the pre handler,
		however the pre-handler returns `true` to skip the handler.
		This results in the sub-command never being checked and it's required arguments being completley ignored, since it was told to be skipped.
		~ The detail here is, sub-commands are checked when the handler is run for them.
	]]
end)
