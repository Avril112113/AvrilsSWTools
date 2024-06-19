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


TEST.addTest("matchers-string", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.string(),
			gen_default_handler("arg test string")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={"potato!"}}, AVCmds.onCustomCommand("?test potato!", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"quoted string"}}, AVCmds.onCustomCommand("?test \"quoted string\"", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"single quoted string with \" in it"}}, AVCmds.onCustomCommand("?test 'single quoted string with \" in it'", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"Big 'ol string"}}, AVCmds.onCustomCommand("?test [[Big 'ol string]]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"Even with the fancier \"=\" in 'em"}}, AVCmds.onCustomCommand("?test [==[Even with the fancier \"=\" in 'em]==]", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.string{min=5,max=7,strict=true},
			gen_default_handler("arg test string")
		}

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_STRING_LEN}, AVCmds.onCustomCommand("?test 'smol'", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={"valid"}}, AVCmds.onCustomCommand("?test 'valid'", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={"valid12"}}, AVCmds.onCustomCommand("?test 'valid12'", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_STRING_LEN}, AVCmds.onCustomCommand("?test 'too_long'", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.string{simple=true},
			gen_default_handler("arg test string")
		}

	TEST.check(Utils.cmd_expect({handled=true, args={"simple_string"}}, AVCmds.onCustomCommand("?test simple_string", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_STRING}, AVCmds.onCustomCommand("?test 'non-simple string'", 0)))
end)

TEST.addTest("matchers-number", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.number{allow_inf=true, allow_nan=true},
			gen_default_handler("arg test number")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={123}}, AVCmds.onCustomCommand("?test 123", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={-321}}, AVCmds.onCustomCommand("?test -321", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={1.23}}, AVCmds.onCustomCommand("?test 1.23", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={-32.1}}, AVCmds.onCustomCommand("?test -32.1", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={0xFFAA66}}, AVCmds.onCustomCommand("?test 0xFFAA66", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={4.57e-3}}, AVCmds.onCustomCommand("?test 4.57e-3", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={0.3e12}}, AVCmds.onCustomCommand("?test 0.3e12", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={5e+20}}, AVCmds.onCustomCommand("?test 5e+20", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={1/0}}, AVCmds.onCustomCommand("?test inf", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={1/0}}, AVCmds.onCustomCommand("?test +inf", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={-1/0}}, AVCmds.onCustomCommand("?test -inf", 0)))
	-- We can't reasonably check for nan, so we just make sure it parsed and assume it's the correct value.
	TEST.check(Utils.cmd_expect({handled=true}, AVCmds.onCustomCommand("?test nan", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.number{min=0,max=3},
			gen_default_handler("arg test number")
		}

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_NUMBER_RANGE}, AVCmds.onCustomCommand("?test -99999", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={0}}, AVCmds.onCustomCommand("?test 0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={3}}, AVCmds.onCustomCommand("?test 3", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_NUMBER_RANGE}, AVCmds.onCustomCommand("?test 999999", 0)))
end)

TEST.addTest("matchers-boolean", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.boolean(),
			gen_default_handler("arg test boolean")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test yes", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test ye", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test y", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test false", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test no", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test n", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.boolean{strict=true},
			gen_default_handler("arg test boolean")
		}

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_BOOLEAN}, AVCmds.onCustomCommand("?test yes", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_BOOLEAN}, AVCmds.onCustomCommand("?test no", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={false}}, AVCmds.onCustomCommand("?test false", 0)))
end)

TEST.addTest("matchers-wildcard", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.wildcard(),
			gen_default_handler("arg test wildcard")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={"potato 123 abc true through me."}}, AVCmds.onCustomCommand("?test potato 123 abc true through me.", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"remove_trailing_space?"}}, AVCmds.onCustomCommand("?test remove_trailing_space?   ", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_WILDCARD}, AVCmds.onCustomCommand("?test", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.wildcard{min=5,max=7},
			gen_default_handler("arg test wildcard")
		}

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_WILDCARD_LEN}, AVCmds.onCustomCommand("?test smol", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={"valid"}}, AVCmds.onCustomCommand("?test valid", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={"valid12"}}, AVCmds.onCustomCommand("?test valid12", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_WILDCARD_LEN}, AVCmds.onCustomCommand("?test too_long", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.wildcard{cut_pat=";"},
			AVCmds.wildcard(),
			gen_default_handler("arg test wildcard")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={"foo bar baz", "yupee, it cut!"}}, AVCmds.onCustomCommand("?test foo bar baz; yupee, it cut!", 0)))
end)

TEST.addTest("matchers-array", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.array{AVCmds.string()},
			gen_default_handler("arg test array")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a,b,c", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a,b,c]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a, b, c", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a, b, c]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test   a  ,  b  ,  c  ", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a,  b,  c]  ", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.array{AVCmds.string(),min=2,max=3},
			gen_default_handler("arg test array")
		}

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_ARRAY_COUNT}, AVCmds.onCustomCommand("?test a", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{"a", "b"}}}, AVCmds.onCustomCommand("?test a,b", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a,b,c", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_ARRAY_COUNT}, AVCmds.onCustomCommand("?test a,b,c,e", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.array{AVCmds.string(),seperator=" "},
			gen_default_handler("arg test array")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a b c", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a b c]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test a  b  c", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test [a  b  c]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{"a", "b", "c"}}}, AVCmds.onCustomCommand("?test   a     b     c  ", 0)))

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
					print(i, Utils.str_value(v))
				end
			end
		}

	TEST.check(Utils.cmd_expect({handled=true,args={"pre", {1, 2, 3}, "post"}}, AVCmds.onCustomCommand("?test pre 1 2 3 post", 0)))
end)

TEST.addTest("matchers-player", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.player(),
			gen_default_handler("arg test player")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_id(0)}}, AVCmds.onCustomCommand("?test 0", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_name("Avril112113")}}, AVCmds.onCustomCommand("?test Avril112113", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_steamid("76561198111587390")}}, AVCmds.onCustomCommand("?test 76561198111587390", 0)))

	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_id(1)}}, AVCmds.onCustomCommand("?test 1", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_name("Foo")}}, AVCmds.onCustomCommand("?test Foo", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_steamid("60638742392402103")}}, AVCmds.onCustomCommand("?test 60638742392402103", 0)))

	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_id(2)}}, AVCmds.onCustomCommand("?test 2", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_name("Bar")}}, AVCmds.onCustomCommand("?test Bar", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_steamid("60593461394127499")}}, AVCmds.onCustomCommand("?test 60593461394127499", 0)))

	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_name("Avril112113")}}, AVCmds.onCustomCommand("?test Avril", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={AVCmds.get_player_from_name("Avril112113")}}, AVCmds.onCustomCommand("?test avril", 0)))

	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_PLAYER}, AVCmds.onCustomCommand("?test 22", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_PLAYER}, AVCmds.onCustomCommand("?test nope", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_PLAYER}, AVCmds.onCustomCommand("?test 12345678901234567", 0)))
end)

TEST.addTest("matchers-position", function()
	---@param m SWMatrix
	---@param ox number?
	---@param oy number?
	---@param oz number?
	---@return {[1]:number,[2]:number,[3]:number}
	local function mtp(m, ox, oy, oz)
		ox = type(ox) == "number" and ox or 0
		oy = oy or 0
		oz = oz or 0
		return {m[13] + ox, m[14] + oy, m[15] + oz}
	end

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.position(),
			gen_default_handler("arg test position")
		}

	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0))}}, AVCmds.onCustomCommand("?test Avril112113", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0))}}, AVCmds.onCustomCommand("?test 76561198111587390", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(1))}}, AVCmds.onCustomCommand("?test Foo", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(1))}}, AVCmds.onCustomCommand("?test 60638742392402103", 0)))

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_POSITION}, AVCmds.onCustomCommand("?test 0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_POSITION}, AVCmds.onCustomCommand("?test 1", 0)))

	TEST.check(Utils.cmd_expect({handled=true, args={{1,2,3}}}, AVCmds.onCustomCommand("?test 1,2,3", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{1,2,3}}}, AVCmds.onCustomCommand("?test 1 2 3", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{1,2,3}}}, AVCmds.onCustomCommand("?test 1, 2, 3", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={{1,2,3}}}, AVCmds.onCustomCommand("?test 1  2  3", 0)))

	TEST.check(Utils.cmd_expect({handled=true, err=MATCH_ERRORS.BAD_POSITION}, AVCmds.onCustomCommand("?test 1,2,", 0)))

	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0), 0, 0, 0)}}, AVCmds.onCustomCommand("?test ~0 ~0 ~0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0), 0, 0, 0)}}, AVCmds.onCustomCommand("?test ~ ~ ~", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0), 1, 0, 0)}}, AVCmds.onCustomCommand("?test ~1 ~0 ~0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0), 0, 1, 0)}}, AVCmds.onCustomCommand("?test ~0 ~1 ~0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(server.getPlayerPos(0), 0, 0, 1)}}, AVCmds.onCustomCommand("?test ~0 ~0 ~1", 0)))

	local player_matrix = server.getPlayerPos(0)

	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0, 0.6, 0)}}, AVCmds.onCustomCommand("?test ^0 ^0 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0, 0.6, 0)}}, AVCmds.onCustomCommand("?test ^ ^ ^", 0)))
	server.__test_look_dir = {0, 0, 1}
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 1.0, 0.6, 0.0)}}, AVCmds.onCustomCommand("?test ^1 ^0 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 1.6, 0.0)}}, AVCmds.onCustomCommand("?test ^0 ^1 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 0.6, 1.0)}}, AVCmds.onCustomCommand("?test ^0 ^0 ^1", 0)))
	server.__test_look_dir = {1, 0, 0}
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 0.6, -1.0)}}, AVCmds.onCustomCommand("?test ^1 ^0 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 1.6, 0.0)}}, AVCmds.onCustomCommand("?test ^0 ^1 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 1.0, 0.6, 0.0)}}, AVCmds.onCustomCommand("?test ^0 ^0 ^1", 0)))
	server.__test_look_dir = {-1, 0, 0}
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 0.6, 1.0)}}, AVCmds.onCustomCommand("?test ^1 ^0 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 1.6, 0.0)}}, AVCmds.onCustomCommand("?test ^0 ^1 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, -1.0, 0.6, 0.0)}}, AVCmds.onCustomCommand("?test ^0 ^0 ^1", 0)))
	server.__test_look_dir = {0, 1, 0}
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 1.0, 0.6, 0.0)}}, AVCmds.onCustomCommand("?test ^1 ^0 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 0.6, -1.0)}}, AVCmds.onCustomCommand("?test ^0 ^1 ^0", 0)))
	TEST.check(Utils.cmd_expect({handled=true, args={mtp(player_matrix, 0.0, 1.6, 0.0)}}, AVCmds.onCustomCommand("?test ^0 ^0 ^1", 0)))
end)

TEST.addTest("matchers-optional", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.optional(AVCmds.boolean()),
			gen_default_handler("arg test optional")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test false", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={nil}}, AVCmds.onCustomCommand("?test", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.optional(AVCmds.boolean(), false),
			gen_default_handler("arg test optional")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test", 0)))

	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.optional(AVCmds.boolean()),
			AVCmds.number(),
			gen_default_handler("arg test optional")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={true, 1}}, AVCmds.onCustomCommand("?test true 1", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false, 2}}, AVCmds.onCustomCommand("?test false 2", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={nil, 3}}, AVCmds.onCustomCommand("?test 3", 0)))
end)

TEST.addTest("matchers-or", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.or_{AVCmds.boolean(), AVCmds.number()},
			gen_default_handler("arg test or")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test false", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={1234}}, AVCmds.onCustomCommand("?test 1234", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={-4321}}, AVCmds.onCustomCommand("?test -4321", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.EXCESS_INPUT}, AVCmds.onCustomCommand("?test true 666", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.OR_FAILED}, AVCmds.onCustomCommand("?test stringy", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.OR_FAILED}, AVCmds.onCustomCommand("?test", 0)))
end)

TEST.addTest("matchers-table", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.table(),
			gen_default_handler("arg test table")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={{}}}, AVCmds.onCustomCommand("?test ()", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{}}}, AVCmds.onCustomCommand("?test ( )", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 2, 3}}}, AVCmds.onCustomCommand("?test (1, 2, 3)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 2, 3}}}, AVCmds.onCustomCommand("?test (1,2,3)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{a=4, b=5, c=6}}}, AVCmds.onCustomCommand("?test (a=4, b=5, c=6)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{[true]=7, ['str']=8}}}, AVCmds.onCustomCommand("?test ([true]=7, ['str']=8)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 2, 3, a=4, b=5, c=6, [true]=7, ['str']=8}}}, AVCmds.onCustomCommand("?test (1, 2, 3, a=4, b=5, c=6, [true]=7, ['str']=8)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{a=4, b=5, c=6, [true]=7, ['str']=8}}}, AVCmds.onCustomCommand("?test ( a = 4 , b = 5 , c = 6 , [ true ] = 7 , [ 'str' ] = 8 )", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{{'depth..'}}}}, AVCmds.onCustomCommand("?test (('depth..'))", 0)))
	-- TODO: Don't use balanced `%b` pattern for tables, because the below cases fail.
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 'close in string )', 2}}}, AVCmds.onCustomCommand("?test (1, 'close in string )', 2)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 'open in string (', 2}}}, AVCmds.onCustomCommand("?test (1, 'close in string (', 2)", 0)))
end)

TEST.addTest("matchers-table_key", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.table_key(),
			gen_default_handler("arg test table_key")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={"simple"}}, AVCmds.onCustomCommand("?test simple", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={123}}, AVCmds.onCustomCommand("?test [123]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test [true]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"stringy"}}, AVCmds.onCustomCommand("?test ['stringy']", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_TABLE_KEY}, AVCmds.onCustomCommand("?test [bad_simple]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_TABLE_KEY}, AVCmds.onCustomCommand("?test [bad space]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={"valid space"}}, AVCmds.onCustomCommand("?test [ 'valid space' ]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={456}}, AVCmds.onCustomCommand("?test [ 456 ]", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={false}}, AVCmds.onCustomCommand("?test [ false ]", 0)))
end)

TEST.addTest("matchers-value", function()
	AVCmds._root_command = AVCmds.createCommand {name="ROOT"}
	AVCmds.createCommand {name="test"}
		:registerGlobalCommand()
		:addHandler {
			AVCmds.value(),
			gen_default_handler("arg test value")
		}

	TEST.check(Utils.cmd_expect({handled=true,args={"str"}}, AVCmds.onCustomCommand("?test 'str'", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={123}}, AVCmds.onCustomCommand("?test 123", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={true}}, AVCmds.onCustomCommand("?test true", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 2, 3}}}, AVCmds.onCustomCommand("?test (1, 2, 3)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 2, 3}}}, AVCmds.onCustomCommand("?test (1,2,3)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{a=4, b=5, c=6}}}, AVCmds.onCustomCommand("?test (a=4, b=5, c=6)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{[true]=7, ['str']=8}}}, AVCmds.onCustomCommand("?test ([true]=7, ['str']=8)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{1, 2, 3, a=4, b=5, c=6, [true]=7, ['str']=8}}}, AVCmds.onCustomCommand("?test (1, 2, 3, a=4, b=5, c=6, [true]=7, ['str']=8)", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{a=4, b=5, c=6, [true]=7, ['str']=8}}}, AVCmds.onCustomCommand("?test ( a = 4 , b = 5 , c = 6 , [ true ] = 7 , [ 'str' ] = 8 )", 0)))
	TEST.check(Utils.cmd_expect({handled=true,args={{{'depth..'}}}}, AVCmds.onCustomCommand("?test (('depth..'))", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_LUA_VALUE}, AVCmds.onCustomCommand("?test no", 0)))
	TEST.check(Utils.cmd_expect({handled=true,err=MATCH_ERRORS.BAD_LUA_VALUE}, AVCmds.onCustomCommand("?test simplestr", 0)))
end)
