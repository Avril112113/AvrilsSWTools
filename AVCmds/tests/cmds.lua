require "test_game_fill"


local function str_value(value)
	if type(value) == "table" then
		local parts = {"{"}
		for i, v in ipairs(value) do
			table.insert(parts, ("%s,"):format(str_value(v)))
		end
		for i, v in pairs(value) do
			if type(i) ~= "number" or i > #parts then
				if type(i) == "string" and i:match("^[a-z]%w*$") then
					table.insert(parts, ("%s=%s,"):format(i, str_value(v)))
				else
					table.insert(parts, ("[%s]=%s,"):format(str_value(i), str_value(v)))
				end
			end
		end
		return table.concat(parts, ""):sub(1, -2) .. "}"
	elseif type(value) == "string" then
		local q = "'" and value:find("\"") or  "\""
		return ("%s%s%s"):format(q, value, q)
	else
		return tostring(value)
	end
end


--- If `expect.handled=false` then no other checks are performed.
---@param expect {handled:boolean?,err:AVMatchErrorCode|string|true?,args:any[]?}
---@param handled boolean
---@param ctx AVCommandContext
---@return string, boolean, string
local function cmd_expect(expect, handled, ctx)
	local cmd_str = "<NO_CTX>"
	if ctx == nil then
		return cmd_str, false, "No context"
	end
	cmd_str = ctx.raw
	if expect.handled ~= nil and expect.handled ~= handled then
		return cmd_str, false, expect.handled and "Was not handled" or "Was handled"
	elseif expect.handled ~= nil and handled == false then
		goto skip
	end
	if expect.err ~= nil then
		if ctx.err then
			-- If not any error, check for spesific error.
			if expect.err ~= true and expect.err ~= ctx.err.err then
				return cmd_str, false, ("Expected '%s' but got '%s': %s"):format(expect.err, ctx.err.err, ctx.err.msg)
			end
		else
			-- Check all children for any or spesific error.
			for handler, child_ctx in pairs(ctx.children) do
				if child_ctx.err then
					if expect.err == true then
						goto err_found
					elseif expect.err == child_ctx.err.err then
						goto err_found
					end
				end
			end
			do
				return cmd_str, false, ("Expected %s error, but the error was not found.\n%s"):format(
					expect.err ~= true and expect.err or "any",
					table.concat(AVCmds.toparts_context_tree(ctx), "\n")
				)
			end
			::err_found::
		end
	else
		if ctx.err then
			return cmd_str, false, ("Unexpected error %s.\n%s\n%s"):format(
				ctx.err.err,
				ctx.err.msg,
				table.concat(AVCmds.toparts_context_tree(ctx), "\n")
			)
		end
		for handler, child_ctx in pairs(ctx.children) do
			if child_ctx.err then
				return cmd_str, false, ("Unexpected error %s.\n%s\n%s"):format(
					child_ctx.err.err,
					child_ctx.err.msg,
					table.concat(AVCmds.toparts_context_tree(ctx), "\n")
				)
			end
		end
	end
	if expect.args ~= nil then
		local ok, msg = TEST.eqDeep(ctx.args, expect.args, false)
		if not ok then
			---@cast msg -?
			return cmd_str, false, msg
		end
	end
	::skip::
	return cmd_str, true, str_value(expect) .. "\n" .. table.concat(AVCmds.toparts_context_tree(ctx), "\n")
end


require "avcmds"

for i, v in pairs(AVCmds.TEXT_WIDTH_DATA) do
	AVCmds.TEXT_WIDTH_DATA[i] = 1
end

---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.assert(v, message, ...)
	if not v then
		error(message)
	end
	return v, message, ...
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

	TEST.check(cmd_expect({handled=true}, AVCmds.onCustomCommand("?test", 0)))
	TEST.check(cmd_expect({handled=true}, AVCmds.onCustomCommand("?test test test", 0)))
	TEST.check(cmd_expect({handled=false}, AVCmds.onCustomCommand("?testtest", 0)))  --
	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_CONST}, AVCmds.onCustomCommand("?test testtest", 0)))  --
	TEST.check(cmd_expect({handled=false}, AVCmds.onCustomCommand("?non_existo", 0)))

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

	TEST.check(cmd_expect({handled=true,err="CUSTOM_ERR"}, AVCmds.onCustomCommand("?test", 0)))
	TEST.check(cmd_expect({handled=true,err="SCARY_123"}, AVCmds.onCustomCommand("?test 123", 0)))
end)

TEST.addTest("matchers-string", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.string(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test string")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={"potato!"}}, AVCmds.onCustomCommand("?test potato!", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.string{min=5,max=7,strict=true},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test string")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_STRING_LEN}, AVCmds.onCustomCommand("?test 'smol'", 0)))
	TEST.check(cmd_expect({handled=true, args={"valid"}}, AVCmds.onCustomCommand("?test 'valid'", 0)))
	TEST.check(cmd_expect({handled=true, args={"valid12"}}, AVCmds.onCustomCommand("?test 'valid12'", 0)))
	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_STRING_LEN}, AVCmds.onCustomCommand("?test 'too_long'", 0)))
end)

TEST.addTest("matchers-number", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.number(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test number")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={123}}, AVCmds.onCustomCommand("?test 123", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.number{min=0,max=3},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test number")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_NUMBER_RANGE}, AVCmds.onCustomCommand("?test -99999", 0)))
	TEST.check(cmd_expect({handled=true, args={0}}, AVCmds.onCustomCommand("?test 0", 0)))
	TEST.check(cmd_expect({handled=true, args={3}}, AVCmds.onCustomCommand("?test 3", 0)))
	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_NUMBER_RANGE}, AVCmds.onCustomCommand("?test 999999", 0)))
end)

TEST.addTest("matchers-boolean", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.boolean(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test boolean")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test yes", 0)))
	TEST.check(cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test ye", 0)))
	TEST.check(cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test y", 0)))
	TEST.check(cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test false", 0)))
	TEST.check(cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test no", 0)))
	TEST.check(cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test n", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.boolean{strict=true},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test boolean")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_BOOLEAN}, AVCmds.onCustomCommand("?test yes", 0)))
	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_BOOLEAN}, AVCmds.onCustomCommand("?test no", 0)))
	TEST.check(cmd_expect({handled=true, args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(cmd_expect({handled=true, args={false}}, AVCmds.onCustomCommand("?test false", 0)))
end)

TEST.addTest("matchers-wildcard", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.wildcard(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test wildcard")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={"potato 123 abc true through me."}}, AVCmds.onCustomCommand("?test potato 123 abc true through me.", 0)))
	TEST.check(cmd_expect({handled=true,args={"remove_trailing_space?"}}, AVCmds.onCustomCommand("?test remove_trailing_space?   ", 0)))
	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.BAD_WILDCARD}, AVCmds.onCustomCommand("?test", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.wildcard{min=5,max=7},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test string")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_WILDCARD_LEN}, AVCmds.onCustomCommand("?test smol", 0)))
	TEST.check(cmd_expect({handled=true, args={"valid"}}, AVCmds.onCustomCommand("?test valid", 0)))
	TEST.check(cmd_expect({handled=true, args={"valid12"}}, AVCmds.onCustomCommand("?test valid12", 0)))
	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_WILDCARD_LEN}, AVCmds.onCustomCommand("?test too_long", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.wildcard{cut_pat=";"},
			AVCmds.wildcard(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test wildcard")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={"foo bar baz", "yupee, it cut!"}}, AVCmds.onCustomCommand("?test foo bar baz; yupee, it cut!", 0)))
end)

TEST.addTest("matchers-array", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.array{AVCmds.string()},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test array")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a,b,c", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a,b,c]", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a, b, c", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a, b, c]", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test   a  ,  b  ,  c  ", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a,  b,  c]  ", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.array{AVCmds.string(),min=2,max=3},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test array")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_ARRAY_COUNT}, AVCmds.onCustomCommand("?test a", 0)))
	TEST.check(cmd_expect({handled=true, args={{"a", "b"}}}, AVCmds.onCustomCommand("?test a,b", 0)))
	TEST.check(cmd_expect({handled=true, args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a,b,c", 0)))
	TEST.check(cmd_expect({handled=true, err=MATCH_ERRORS.BAD_ARRAY_COUNT}, AVCmds.onCustomCommand("?test a,b,c,e", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.array{AVCmds.string(),seperator=" "},
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test array")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a b c", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a b c]", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a  b  c", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a  b  c]", 0)))
	TEST.check(cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test   a     b     c  ", 0)))

	-- The following works due to non-clashing matchers.
	-- That is, a number can not match a string, so the array matching stops for the next argument.
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.string(),
			AVCmds.array{AVCmds.number(),min=1,seperator=" "},
			AVCmds.string(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test array")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={"pre", {1, 2, 3}, "post"}}, AVCmds.onCustomCommand("?test pre 1 2 3 post", 0)))
end)

TEST.addTest("matchers-player", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.player(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test player")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_id(0)}}, AVCmds.onCustomCommand("?test 0", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_name("Avril112113")}}, AVCmds.onCustomCommand("?test Avril112113", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_steamid("76561198111587390")}}, AVCmds.onCustomCommand("?test 76561198111587390", 0)))

	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_id(1)}}, AVCmds.onCustomCommand("?test 1", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_name("Foo")}}, AVCmds.onCustomCommand("?test Foo", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_steamid("60638742392402103")}}, AVCmds.onCustomCommand("?test 60638742392402103", 0)))

	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_id(2)}}, AVCmds.onCustomCommand("?test 2", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_name("Bar")}}, AVCmds.onCustomCommand("?test Bar", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_steamid("60593461394127499")}}, AVCmds.onCustomCommand("?test 60593461394127499", 0)))

	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_name("Avril112113")}}, AVCmds.onCustomCommand("?test Avril", 0)))
	TEST.check(cmd_expect({handled=true,args={AVCmds.get_player_from_name("Avril112113")}}, AVCmds.onCustomCommand("?test avril", 0)))

	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.BAD_PLAYER}, AVCmds.onCustomCommand("?test 22", 0)))
	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.BAD_PLAYER}, AVCmds.onCustomCommand("?test nope", 0)))
	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.BAD_PLAYER}, AVCmds.onCustomCommand("?test 12345678901234567", 0)))
end)

TEST.addTest("matchers-optional", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.optional(AVCmds.boolean()),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test optional")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test false", 0)))
	TEST.check(cmd_expect({handled=true,args={nil}}, AVCmds.onCustomCommand("?test", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.optional(AVCmds.boolean()),
			AVCmds.number(),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test optional")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={true, 1}}, AVCmds.onCustomCommand("?test true 1", 0)))
	TEST.check(cmd_expect({handled=true,args={false, 2}}, AVCmds.onCustomCommand("?test false 2", 0)))
	TEST.check(cmd_expect({handled=true,args={nil, 3}}, AVCmds.onCustomCommand("?test 3", 0)))
end)

TEST.addTest("matchers-or", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.or_(AVCmds.boolean(), AVCmds.number()),
			---@param ctx AVCommandContext
			function(ctx, ...)
				print("~ arg test optional")
				print(table.concat(AVCmds.toparts_context_path(ctx), " "))
				for i, v in pairs({...}) do
					print(i, str_value(v))
				end
			end
		}

	TEST.check(cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test false", 0)))
	TEST.check(cmd_expect({handled=true,args={1234}}, AVCmds.onCustomCommand("?test 1234", 0)))
	TEST.check(cmd_expect({handled=true,args={-4321}}, AVCmds.onCustomCommand("?test -4321", 0)))
	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.EXCESS_INPUT}, AVCmds.onCustomCommand("?test true 666", 0)))
	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.OR_FAILED}, AVCmds.onCustomCommand("?test stringy", 0)))
	TEST.check(cmd_expect({handled=true,err=MATCH_ERRORS.OR_FAILED}, AVCmds.onCustomCommand("?test", 0)))
end)
