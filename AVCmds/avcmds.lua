--- Avrils Commands Library
--- Version: 0.3.3

--[[
	Terminology:
		A 'command' is as created by `AVCmds.createCommand`.
		A 'pre-handler' is as created by `some_cmd:addPreHandler`
		A 'handler' is as created by `some_cmd:addHandler`
		A 'handler function' is the last value provided to `some_cmd:addHandler`
		A 'sub-command' is a command from `AVCmds.createCommand` that is used as a handler function.

	There are numerous methods that can be overriden, these will all be above AVCmds.onCustomCommand in this file.
	However, all of these do have "works out of the box" defaults.
	
	If you want to create custom matchers, use `AVCmds.player` as an example, as that is likley the closest to your use case.
	`AVCmds.player` uses another existing matcher, so it should be simple to adjust to your own needs.
	For errors, `BAD_PLAYER` can be any reasonable unique string.

	Pre-handlers are called before the handler that has been matched.
	They only take a context, but are free to modify it safely.
	These are intended for argument validation and transformation.
	They can be an easier and quicker alternative to creating a custom matcher, but have more things to keep in-mind.
	NOTE that pre-handlers might be called even if the subsequent handlers never match anything! This is the case with sub-commands.

	Handlers and pre-handlers can return a AVMatchError, which will act the same as if an argument failed to match.
	This allows using the default error handling to provide additional argument validation.
	Do feel free to handle invalid input without this, it's not always desired to use the default handling!
]]

--[[ Grand TODO list:
	Remove all TODO's within the code.
	Solve all FIXME's within the code.
]]


---@class AVMatchValue
---@field matcher AVMatcher
---@field start integer
---@field finish integer
---@field raw string
---@field cut string
---@field value any

---@class AVMatchError
---@field matcher AVMatcher?
---@field pos integer
---@field err AVMatchErrorCode
---@field msg string
---@field expected string?  # Used over matcher, for multi-error list.

---@alias AVMatcherResult AVMatchValue|AVMatchError

---@class AVMatcher
---@field usage string # type name for this matcher, used for usage info, this can be anything.
---@field help string? # Argument help info.
---@field match fun(self, ctx:AVCommandContext, raw:string, pos:integer, cut:string?):AVMatcherResult

---@class AVCommandContext
---@field handler AVCommandHandlerTbl?  # The corosponding handler from command.
---@field command AVCommand # The command this context is from
---@field parent AVCommandContext?  # Parent context, if there is one.
---@field children table<AVCommandHandlerTbl|AVCommand,AVCommandContext>  # Children context's, empty for called handler context.
---@field children_order (AVCommandHandlerTbl|AVCommand)[]  # Children in order of being checked.
---@field raw string  # The raw string this context is from.
---@field pos integer  # Position in the input this context starts.
---@field finish integer  # Position in the input this context finishes.
---@field player SWPlayer  # The player that run the command (peer_id of `0` for server)
---@field argsData table<number|string, AVMatchValue|AVMatchError>  # The full info about all arguments.
---@field args table<number|string,any>  # Quick access to argument values, primarily used for flags.
---@field err AVMatchError?  # Error for this context.

---@class AVCreateCommandTbl
---@field name string?
---@field permission any?
---@field description string?
---@field addUsageHandler boolean?
---@field addHelpHandler boolean?
---@field handler AVCommand|AVCommandHandlerTbl?
---@field handlers (AVCommand|AVCommandHandlerTbl)[]?

---@alias AVCommandHandlerFun fun(ctx:AVCommandContext, ...):AVMatchError?  # Returned error does not need matcher field, but all other are required.
---@class AVCommandHandlerTbl
---@field [integer] AVMatcher|AVCommand|AVCommandHandlerFun
---@field [string] AVMatcher|AVCommand

---@alias AVCommandPreHandlerFun fun(ctx:AVCommandContext):AVMatchError|true?  # Returned error does not need matcher field, but all other are required.


local ADDON_NAME = server.getAddonData((server.getAddonIndex())).name

---@param text string
---@return string
local function escape_pattern(text)
	return (text:gsub("(%W)", "%%%1"))
end


---@class AVCmds
AVCmds = {}
AVCmds._PREFIX = "?"

---@type SWPlayer
AVCmds._SERVER_PLAYER = {
	id=-1,
	name="SERVER",
	admin=true,
	auth=true,
	steam_id=0,
	object_id=-1,
}

---@enum AVMatchErrorCode
AVCmds.MATCH_ERRORS = {
	EXCESS_INPUT="EXCESS_INPUT",
	BAD_CONST="BAD_CONST",  -- When a constant fails to match.
	BAD_STRING="BAD_STRING",
	BAD_STRING_LEN="BAD_STRING_LEN",
	BAD_BOOLEAN="BAD_BOOLEAN",
	BAD_NUMBER="BAD_NUMBER",
	BAD_NUMBER_RANGE="BAD_NUMBER_RANGE",
	BAD_NUMBER_INTEGER="BAD_NUMBER_INTEGER",
	BAD_WILDCARD="BAD_WILDCARD",  -- Only happens when no input or custom cut_pat failed.
	BAD_WILDCARD_LEN="BAD_WILDCARD_LEN",
	BAD_ARRAY="BAD_ARRAY",
	BAD_ARRAY_COUNT="BAD_ARRAY_COUNT",
	BAD_TABLE="BAD_TABLE",
	BAD_TABLE_COUNT="BAD_TABLE_COUNT",
	BAD_TABLE_KEY="BAD_TABLE_KEY",
	BAD_INDEX="BAD_INDEX",
	BAD_LUA_VALUE="BAD_LUA_VALUE",
	BAD_PLAYER="BAD_PLAYER",
	BAD_COORDINATE="BAD_COORDINATE",
	BAD_POSITION="BAD_POSITION",
	OR_FAILED="OR_FAILED",
	UNKNOWN="UNKNOWN",
}

--- This should be overridden if you want to handle permissions differently.
--- Note that, this is still checked for the server as well.
---@param ctx AVCommandContext
---@return boolean  # If the player has permission to run the command.
---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.checkPermission(ctx)
	-- If admin, always can run command.
	-- If permission "all", no permission is needed.
	-- If permission "auth", only authenticated players can run it.
	return (
		ctx.player.admin or
		(ctx.command.permission == "all") or
		(ctx.command.permission == "auth" and ctx.player.auth)
	)
end

function AVCmds.log(message)
	debug.log(("[SW-%s] %s"):format(ADDON_NAME, tostring(message)))
end

--- This can be overridden to adjust how asstertions are handled and displayed.
--- Expects similar behaviour to Lua's `assert()`
---@generic T
---@param v? T
---@param message? any
---@param ... any
---@return T
---@return any ...
---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.assert(v, message, ...)
	if not v then
		AVCmds.log(("[error] %s"):format(tostring(message)))
		-- `error()` doesn't exist in SW, but it will stop execution, since it doesn't.
		error(message)
	end
	return v, message, ...
end

--- This can be overridden to get players that may be offline or a more efficent method.
---@param peer_id integer
---@return SWPlayer?
---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.get_player_from_id(peer_id)
	for _, player in pairs(server.getPlayers()) do
		if player.id == peer_id then
			return player
		end
	end
end

--- This can be overridden to get players that may be offline or a more efficent method.
---@param name string
---@return SWPlayer?
---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.get_player_from_name(name)
	local players = server.getPlayers()
	for _, player in pairs(players) do
		if player.name == name then
			return player
		end
	end
	for _, player in pairs(players) do
		if player.name:sub(1, math.max(#name, 4)):lower() == name:lower() then
			return player
		end
	end
end

--- This can be overridden to get players that may be offline or a more efficent method.
---@param steamid string
---@return SWPlayer?
---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.get_player_from_steamid(steamid)
	for _, player in pairs(server.getPlayers()) do
		if tostring(player.steam_id) == steamid then
			return player
		end
	end
end

---@param tbl {[1]:AVCommandContext,[integer]:any,name:string?,peer_id:integer?}
function AVCmds.response(tbl)
	local ctx = tbl[1]
	for i=2,#tbl do
		tbl[i] = tostring(tbl[i])
	end
	server.announce(tbl.name or ADDON_NAME, table.concat(tbl, " ", 2), tbl.peer_id or ctx.player.id)
end

--- This can be overridden for custom errors.
---@param ctx AVCommandContext # Furthest handled context of which all of it's command children handlers failed to match.
---@return string
---@diagnostic disable-next-line: duplicate-set-field
function AVCmds.formatContextErr(ctx)
	-- `ctx` where `ctx.command` was unable to match any of it's handlers.
	-- All `ctx.children` are context's that contain an error.

	---@param values string[]
	---@param sep string
	---@param final string
	---@return string
	local function concat_english(values, sep, final)
		if #values <= 1 then
			return values[1]
		end
		return table.concat(values, sep, 1, #values-1) .. final .. values[#values]
	end

	local err_ctxs = {}
	local options = {}
	local options_set = {}
	local pos = ctx.finish
	local arg_depth = 0
	for _, handler in ipairs(ctx.children_order) do
		-- Typing system messed up after `ipairs`
		---@cast handler AVCommand|AVCommandHandlerTbl
		local child_ctx = ctx.children[handler]
		-- Ensure we only get the options for the furthest matched handler[s] (in terms of arg count).
		if #child_ctx.args >= arg_depth and child_ctx.err ~= nil then
			if #child_ctx.args > arg_depth then
				err_ctxs = {}
				options = {}
				options_set = {}
				arg_depth = #child_ctx.args
			end
			local option
			if child_ctx.err.expected then
				option = child_ctx.err.expected
			elseif child_ctx.err.matcher then
				option = child_ctx.err.matcher.usage
			else  -- In the case of "EXCESS_INPUT" or custom handler errors, there is no matcher.
				option = child_ctx.err.err
			end
			-- Typing system didn't get the memo apparently.
			---@cast option -?
			-- Prevent duplicates
			if not options_set[option] then
				options_set[option] = true
				table.insert(options, option)
				table.insert(err_ctxs, child_ctx)
				-- Get the smallest error position that isn't the parents error position.
				-- Plus sanity check, as possible bugs could cause the child error position to be less than it's parent.
				if (ctx.finish == pos or child_ctx.err.pos < pos) and child_ctx.err.pos > ctx.finish then
					pos = child_ctx.err.pos
				end
			end
		end
	end
	-- If there is only 1 error, show that error in full.
	if #err_ctxs == 1 then
		local child_ctx = err_ctxs[1]
		local spaces = (AVCmds.getTextWidth(ctx.raw:sub(1, child_ctx.err.pos)) - AVCmds.TEXT_WIDTH_DATA["^"]) / AVCmds.TEXT_WIDTH_DATA[" "]
		return ("%s\n%s\n%s"):format(child_ctx.err.msg, child_ctx.raw, string.rep(" ", math.ceil(spaces - 0.1)) .. "^")
	end
	if #options <= 0 then
		return "Unknown error processing command."
	end
	local spaces = (AVCmds.getTextWidth(ctx.raw:sub(1, pos)) - AVCmds.TEXT_WIDTH_DATA["^"]) / AVCmds.TEXT_WIDTH_DATA[" "]
	return ("Expected %s\n%s\n%s"):format(concat_english(options, ", ", " or "), ctx.raw, string.rep(" ", math.ceil(spaces - 0.1)) .. "^")
end

--- If this returns true, the command was handled.
function AVCmds.onCustomCommand(full_message, peer_id)
	-- Only handle player commands.
	if full_message:sub(1, #AVCmds._PREFIX) ~= AVCmds._PREFIX then return false end

	local player
	if peer_id == -1 then
		player = AVCmds._SERVER_PLAYER
	else
		player = AVCmds.get_player_from_id(peer_id)
	end
	if player == nil then
		return false
	end

	-- Start at pos after prefix
	local pos = 1 + #AVCmds._PREFIX

	---@type AVCommandContext
	local ctx = AVCmds._root_command:_create_context {
		pos=pos, raw=full_message,
		player=player,
	}

	-- Add an extra space, since most matchers consume and stop at a space.
	-- Lua patterns don't support a (stop at space OR end of string)
	local handled, handled_ctx = AVCmds._root_command:_handle(ctx, full_message .. " ", pos)
	if handled then
		return true, handled_ctx
	elseif handled_ctx ~= nil and handled_ctx ~= ctx then
		-- An error occurned.
		local msg = handled_ctx.err or AVCmds.formatContextErr(handled_ctx)
		AVCmds.response{ctx, msg or "ERR_MISSING"}
		return true, handled_ctx
	end

	return false, handled_ctx
end

-- noto.ttf
AVCmds.TEXT_WIDTH_DATA = {[' ']=532,['!']=551,['"']=836,['#']=1323,['$']=1171,['%']=1702,['&']=1499,["'"]=461,['(']=614,[')']=614,['*']=1128,['+']=1171,[',']=549,['-']=659,['.']=549,['/']=762,['0']=1171,['1']=1171,['2']=1171,['3']=1171,['4']=1171,['5']=1171,['6']=1171,['7']=1171,['8']=1171,['9']=1171,[':']=549,[';']=549,['<']=1171,['=']=1171,['>']=1171,['?']=889,['@']=1841,['A']=1309,['B']=1331,['C']=1294,['D']=1495,['E']=1139,['F']=1063,['G']=1491,['H']=1518,['I']=694,['J']=559,['K']=1268,['L']=1073,['M']=1858,['N']=1556,['O']=1599,['P']=1239,['Q']=1599,['R']=1274,['S']=1124,['T']=1139,['U']=1497,['V']=1229,['W']=1905,['X']=1200,['Y']=1159,['Z']=1171,['[']=674,['\\']=762,[']']=674,['^']=1171,['_']=909,['`']=1188,['a']=1149,['b']=1260,['c']=983,['d']=1260,['e']=1155,['f']=705,['g']=1260,['h']=1266,['i']=528,['j']=528,['k']=1094,['l']=528,['m']=1915,['n']=1266,['o']=1239,['p']=1260,['q']=1260,['r']=846,['s']=981,['t']=739,['u']=1266,['v']=1040,['w']=1610,['x']=1083,['y']=1044,['z']=963,['{']=778,['|']=1128,['}']=778,['~']=1171}
AVCmds.TEXT_WIDTH_DEFAULT = 1229
--- Gets the width of some text in chat.
---@param text string
---@return number
function AVCmds.getTextWidth(text)
	local width = 0
	for char in text:gmatch(".") do
		local char_width = AVCmds.TEXT_WIDTH_DATA[char]
		if char_width == nil then
			AVCmds.log(("No width for char 0x%X '%s'"):format(string.byte(char), char))
			char_width = AVCmds.TEXT_WIDTH_DEFAULT
		end
		width = width + char_width
	end
	return width
end

---@param tbl AVCreateCommandTbl?
---@return AVCommand
function AVCmds.createCommand(tbl)
	---@class AVCommand
	---@field name string
	---@field description string?
	---@field permission any?
	local command = {__name="AVCommand"}
	---@type AVCommandHandlerFun[]
	command._pre_handlers = {}
	---@type table<AVCommandHandlerFun,integer>
	command._pre_handlers_indicies = {}  -- A look up to get pre handler index from pre handler
	---@type (AVCommandHandlerTbl|AVCommand)[]
	command._handlers = {}
	---@type table<AVCommandHandlerTbl|AVCommand,integer>
	command._handlers_indicies = {}  -- A look up to get handler index from handler

	---@param name string
	function command:setName(name)
		self.name = name
		return self
	end
	---@param description string
	function command:setDescription(description)
		self.description = description
		return self
	end
	---@param permission any
	function command:setPermission(permission)
		self.permission = permission
		return self
	end
	--- Global commands follow the same rules for addHandler.
	---@param matcher string|AVMatcher|nil # If nil, uses command name. If string, it will be converted to a const matcher.
	function command:registerGlobalCommand(matcher)
		matcher = matcher or command.name
		if type(matcher) == "string" then
			matcher = AVCmds.const{matcher}
		end
		AVCmds._root_command:addHandler {
			matcher,
			self
		}
		return self
	end
	--- WARN: A pre-handler might be called when a futher match fails, ensure to be careful what you do in a pre-handler (happens with sub-commands, using a command in a handler)  
	--- Pre-handlers are called before a normal handler, they are intended to modify the context and add additional validation.  
	--- Helpful in reducing duplicate code for handlers and sub-commands.  
	--- Pre-handlers can return `true` to skip the original handler and any deeper pre-handlers, acting as if it were sucsessfully handled.  
	---@param pre_handler AVCommandPreHandlerFun
	function command:addPreHandler(pre_handler)
		AVCmds.assert(type(pre_handler) == "function", "Invalid pre handler, was not a function.")
		table.insert(self._pre_handlers, pre_handler)
		self._pre_handlers_indicies[pre_handler] = #self._pre_handlers
		return self
	end
	--- Add the default usage handler.
	--- Should be called before adding any other handlers.
	function command:addUsageHandler()
		error("TODO")
		return self
	end
	--- Add the default help handler.
	--- Should be called before adding other handlers, except after the usage handler.
	function command:addHelpHandler()
		-- This will need non-positionals for `--help`
		error("TODO")
		return self
	end
	--- Handlers are checked in reverse order than they are added.
	--- Meaning, the last added handler is the first to be checked.
	---@param handler AVCommandHandlerTbl|AVCommand
	function command:addHandler(handler)
		if handler.__name == "AVCommand" then
			---@cast handler AVCommand
			table.insert(self._handlers, handler)
			self._handlers_indicies[handler] = #self._handlers
		else
			---@cast handler AVCommandHandlerTbl
			local handle = handler[#handler]
			AVCmds.assert(
				type(handle) == "function" or (type(handle) == "table" and handle.__name == "AVCommand"),
				"Invalid handler, last value in table was not of AVCommand or function."
			)
			table.insert(self._handlers, handler)
			self._handlers_indicies[handler] = #self._handlers
		end
		return self
	end
	--- Handle a command
	---@param parent_ctx AVCommandContext
	---@param raw string
	---@param pos integer
	---@return boolean, AVCommandContext?
	function command:_handle(parent_ctx, raw, pos)
		for handler_index=#self._handlers,1,-1 do
			local handler = self._handlers[handler_index]
			if handler.__name == "AVCommand" then
				---@cast handler AVCommand
				-- TODO: Test this
				local hanled, ctx = handler:_handle(parent_ctx, raw, pos)
				-- FIXME: There is no ctx to be set if there is an error.
				parent_ctx.children[handler] = ctx
				parent_ctx.children_order[handler_index] = handler
				if hanled then
					return hanled, ctx
				end
			else
				local pos_parse = pos
				---@cast handler AVCommandHandlerTbl
				local ctx = self:_create_context({handler=handler, pos=pos_parse}, parent_ctx)
				parent_ctx.children[handler] = ctx
				parent_ctx.children_order[handler_index] = handler
				-- Check all positional arguments
				for i, _ in pairs(handler) do
					AVCmds.assert(type(i) == "number", "non-positionals are not yet supported.")
				end
				for i=1,#handler-1 do
					local match = handler[i]:match(ctx, raw, pos_parse)
					ctx.argsData[i] = match
					if match.err ~= nil then
						---@cast match AVMatchError
						ctx.err = match
						goto continue
					end
					---@cast match AVMatchValue
					ctx.args[i] = match.value
					pos_parse = raw:match("^ *()", match.finish)  -- Ensure all spaces are consumed
					ctx.finish = pos_parse
				end
				for _, pre_handler in ipairs(self._pre_handlers) do
					local result = pre_handler(ctx)
					if type(result) == "table" then
						AVCmds.assert(type(result.err) == "string" and type(result.msg) == "string" and type(result.pos) == "number", "Invalid handler error.")
						ctx.err = result
						goto continue
					elseif result == true then
						return true, ctx
					end
				end
				local handle = handler[#handler]
				if type(handle) == "function" then
					-- Check that all input has been consumed before running the handler function.
					if pos_parse < #raw then
						ctx.err = {
							matcher=nil, pos=pos_parse, err=AVCmds.MATCH_ERRORS.EXCESS_INPUT,
							msg=("Excess input at position %.0f"):format(pos_parse),
						}
						goto continue
					end
					---@type AVMatchError?
					local result = handle(ctx, table.unpack(ctx.args, 1, #ctx.argsData))
					if type(result) == "table" then
						AVCmds.assert(type(result.err) == "string" and type(result.msg) == "string" and type(result.pos) == "number", "Invalid handler error.")
						ctx.err = result
						goto continue
					end
				elseif handle.__name == "AVCommand" then
					return handle:_handle(ctx, raw, pos_parse)
				else
					AVCmds.assert(false, "Was not function or AVCommand?! (This is a AVCmds bug)")
				end
				return true, ctx
			end
			::continue::
		end
		return false, parent_ctx
	end
	---@param ctx (AVCommandContext|{})?
	---@param parent_ctx AVCommandContext?
	---@return AVCommandContext
	function command:_create_context(ctx, parent_ctx)
		ctx = ctx or {}
		ctx.command = self
		ctx.parent = parent_ctx
		ctx.children = ctx.children or {}
		ctx.children_order = ctx.children_order or {}
		ctx.raw = ctx.raw or (parent_ctx and parent_ctx.raw) or AVCmds.assert(false, "context missing `raw` string.")
		ctx.pos = ctx.pos or (parent_ctx and parent_ctx.pos) or AVCmds.assert(false, "context missing `pos`.")
		ctx.finish = ctx.finish or (parent_ctx and parent_ctx.finish) or ctx.pos
		ctx.player = ctx.player or (parent_ctx and parent_ctx.player) or nil
		ctx.argsData = ctx.argsData or {}
		ctx.args = ctx.args or {}
		return ctx
	end

	if tbl ~= nil then
		if tbl.name then command.name = tbl.name end
		if tbl.permission then command.permission = tbl.permission end
		if tbl.description then command.description = tbl.description end
		if tbl.addUsageHandler then command:addUsageHandler() end
		if tbl.addHelpHandler then command:addHelpHandler() end
		if tbl.handler then
			command:addHandler(tbl.handler)
		end
		if tbl.handlers then
			for _, handler in ipairs(tbl.handlers) do
				-- Typing system is a bit lost after the ipairs :/
				---@cast handler AVCommand|AVCommandHandlerTbl
				command:addHandler(handler)
			end
		end
	end

	return command
end


--- Validates a matcher cut and ensure it contains a position match.
---@param match_cut string?
---@param user_cut string?
---@param default_cut string
---@return string
function AVCmds._check_cut(match_cut, user_cut, default_cut)
	-- if `user_cut`, always cut with this.
	-- if `match_cut` must always end with this (append to user_cut)
	-- `default_cut` should be used if no `match_cut` or `user_cut`
	local cut = default_cut
	if match_cut or user_cut then
		cut = (user_cut or "") .. (match_cut or "")
	end
	if not cut:find("%(%)") then
		cut = cut .. "()"
	end
	if cut:sub(-1, -1) == "$" then
		if not cut:match("^%(.*%)%$$") then
			cut = "(" .. cut:sub(1, -2) .. ")$"
		end
	else
		if not cut:match("^%(.*%)$") then
			cut = "(" .. cut .. ")"
		end
	end
	return cut
end

---@param min integer?
---@param max integer?
function AVCmds._bounds_err_msg(min, max)
	if min and max then
		return ("between %s and %s"):format(min, max)
	elseif min then
		return ("to be at least %s"):format(min)
	elseif max then
		return ("to be at most %s"):format(max)
	end
	return ("(no expected bounds, this is a bug)")
end


---@param tbl {[1]:string,cut_pat:string?,help:string?,usage:string?}
---@return AVMatcher
function AVCmds.const(tbl)
	AVCmds.assert(type(tbl[1]) == "string", "AVCmds.const expects a string.")
	local pattern = "^(" .. escape_pattern(tbl[1]) .. ")"
	---@type AVMatcher
	return {
		usage=tbl.usage or ("'%s'"):format(tbl[1]),
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match, cut_value, finish = raw:match(pattern .. AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
			if match then
				---@type AVMatchValue
				return {matcher=self, start=pos, finish=finish, raw=match, cut=cut_value, value=match}
			end
			---@type AVMatchError
			return {
				matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_CONST,
				msg=("Failed to match constant '%s'"):format(tbl[1]),
			}
		end,
	}
end

---@param tbl {cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.nil_(tbl)
	tbl = tbl or {}
	local pattern = "^(nil)"
	---@type AVMatcher
	return {
		usage=tbl.usage or "nil",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match, cut_value, finish = raw:match(pattern .. AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
			if match then
				---@type AVMatchValue
				return {matcher=self, start=pos, finish=finish, raw=match, cut=cut_value, value=nil}
			end
			---@type AVMatchError
			return {
				matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_CONST,
				msg=("Failed to match constant '%s'"):format(tbl[1]),
			}
		end,
	}
end

--- - `min` - min string length
--- - `max` - max string length
--- - `strict` - If `true`, only allow quoted strings.
--- - `simple` - If `true`, only allow simple strings.
---@param tbl {min:integer,max:integer,strict:boolean?,simple:boolean?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.string(tbl)
	tbl = tbl or {}
	AVCmds.assert(not (tbl.strict and tbl.simple), "AVCmds.string `strict` is not compatible with `simple`.")
	local PATTERN_SIMPLE = "^([^ ]-)"
	local CHAR_TO_PAT = {
		["\""]="^()(\"[^\"]+\")",
		["'"]="^()('[^']+')",
		["["]="^%[(=*)(%[.*%])%1%]",
	}
	---@type AVMatcher
	return {
		usage=tbl.usage or (tbl.strict and "q-string" or tbl.simple and "s-string" or "string"),
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match, cut_value, finish, value, msg
			local char = raw:sub(pos, pos)
			if CHAR_TO_PAT[char] then
				_, match, cut_value, finish = raw:match(CHAR_TO_PAT[char] .. AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
				if tbl.simple then
					msg = "Expected simple string."
				elseif match == nil then
					msg = "Failed to match quoted string."
				else
					value = match:sub(2, -2)
				end
			elseif tbl.strict ~= true then
				match, cut_value, finish = raw:match(PATTERN_SIMPLE .. AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
				if match == nil then
					msg = "Failed to match string."
				else
					value = match
				end
			else
				msg = (tbl.strict == true and "Expected quoted string.") or (tbl.simple and "Expected simple string.") or "Expected ??? string."
			end
			if match ~= nil and msg == nil then
				if tbl.min and #value < tbl.min then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_STRING_LEN,
						msg=("String was too short, expected length %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
					}
				elseif tbl.max and #value > tbl.max then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_STRING_LEN,
						msg=("String was too long, expected length %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
					}
				end
				---@type AVMatchValue
				return {matcher=self, start=pos, finish=finish, raw=match, cut=cut_value, value=value}
			end
			---@type AVMatchError
			return {
				matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_STRING,
				msg=msg,
			}
		end,
	}
end

local INF = 1/0
local NAN = -(0/0)
--- - `allow_inf` Allow parsing of INF, default false.
--- - `allow_nan` Allow parsing of NAN, default false.
---@param tbl {min:number?,max:number?,allow_inf:boolean?,allow_nan:boolean?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.number(tbl)
	tbl = tbl or {}
	-- local type_name = "number"
	-- if tbl.min and tbl.max then
	-- 	type_name = ("number(%s..%s)"):format(tbl.min, tbl.max)
	-- elseif tbl.min then
	-- 	type_name = ("number(%s..)"):format(tbl.min)
	-- elseif tbl.max then
	-- 	type_name = ("number(..%s)"):format(tbl.max)
	-- end
	local pattern_simple = "^([^ ]-)"
	---@type AVMatcher
	return {
		usage=tbl.usage or "number",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match, cut_value, finish = raw:match(pattern_simple .. AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
			if match ~= nil then
				local value
				if tbl.allow_inf and match:match("[+-]?[Ii][Nn][Ff]") then
					value = match:sub(1, 1) == "-" and -INF or INF
				elseif tbl.allow_nan and match:lower() == "nan" then
					value = NAN
				end
				value = value or tonumber(match)
				if value == nil then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_NUMBER,
						msg=("Invalid number."),
					}
				elseif tbl.min and value < tbl.min then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_NUMBER_RANGE,
						msg=("Number out of range, %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
					}
				elseif tbl.max and value > tbl.max then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_NUMBER_RANGE,
						msg=("Number out of range, %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
					}
				end
				---@type AVMatchValue
				return {matcher=self, start=pos, finish=finish, raw=match, cut=cut_value, value=value}
			end
			---@type AVMatchError
			return {
				matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_NUMBER,
				msg=("Invalid number."),
			}
		end,
	}
end

--- Wrapper around `AVCmds.number` but additional check to ensure a integer.
---@param tbl {min:integer?,max:integer?,allow_inf:boolean?,allow_nan:boolean?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.integer(tbl)
	tbl = tbl or {}
	local matcher = AVCmds.number(tbl)
	matcher.usage = tbl.usage or "integer"
	local original_match = matcher.match
	matcher.match = function(self, ctx, raw, pos)
		local result = original_match(self, ctx, raw, pos)
		if result.err then
			return result
		end
		if result.value % 1 ~= 0 then
			---@type AVMatchError
			return {
				matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_NUMBER_INTEGER,
				msg="Must be a whole number.",
			}
		end
		return result
	end
	---@type AVMatcher
	return matcher
end

local BOOLEAN_MATCHS = {
	["true"]=true, ["yes"]=true, ["ye"]=true, ["y"]=true,
	["false"]=false, ["no"]=false, ["n"]=false,
}
--- - `strict` only allow "true" and "false", no other variants.
---@param tbl {strict:boolean?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.boolean(tbl)
	tbl = tbl or {}
	local pattern = "^(%w+)"
	---@type AVMatcher
	return {
		usage=tbl.usage or "boolean",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match, cut_value, finish = raw:match(pattern .. AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
			if not match or (tbl.strict and match ~= "true" and match ~= "false") or (BOOLEAN_MATCHS[match] == nil) then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_BOOLEAN,
					msg="Failed to match boolean.",
				}
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=finish, raw=match, cut=cut_value, value=BOOLEAN_MATCHS[match]}
		end,
	}
end

--- Match everything, there is no rules.
---@param tbl {min:integer?,max:integer?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.wildcard(tbl)
	tbl = tbl or {}
	local pattern = "^(.-)"
	---@type AVMatcher
	return {
		usage=tbl.usage or "wildcard*",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match, cut_value, finish = raw:match(pattern .. AVCmds._check_cut(cut, tbl.cut_pat, " +()$"), pos)
			if not match then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_WILDCARD,
					msg="Missing cut-off point.",
				}
			end
			finish = finish or pos
			if tbl.min and #match < tbl.min then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_WILDCARD_LEN,
					msg=("Input was too short, expected length %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
				}
			elseif tbl.max and #match > tbl.max then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_WILDCARD_LEN,
					msg=("Input was too long, expected length %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
				}
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=finish, raw=match, cut=cut_value, value=match}
		end,
	}
end

--- #### NOTE for space seperator:  
--- . When not hard limiting the amount of elements with `n`  
--- . some element matchers will cause subsequent arguments to not be matched.  
--- . For example, a non-strict string matcher will consume nearly anything, and so the subsequent argument to the command will 'not exist'.  
--- [integer] repeating pattern of elements.  
--- - `n` match exactly this elements.  
--- - `min` at least this many elements.  
--- - `max` at most this many elements.  
--- - `strict` force use of braces arround array.  
--- - `loose` do not check for braces.  
--- - `seperator` the seperator charecter to use, space seperator is supported, default ",". 
--- - `braces` string of 2 charecters for opening and closing of a array, default "[]".  
---@param tbl {[integer]:AVMatcher,[integer]:AVMatcher,n:integer?,min:integer?,max:integer?,strict:boolean?,loose:boolean?,seperator:string?,braces:string?,cut_pat:string?,help:string?,usage:string?}
---@return AVMatcher
function AVCmds.array(tbl)
	AVCmds.assert(not (tbl.strict and tbl.loose), "AVCmds.array `strict` is not compatible with `loose`.")
	AVCmds.assert(tbl.seperator == nil or #tbl.seperator == 1, "AVCmds.array `seperator` should be 1 charecter.")
	AVCmds.assert(tbl.braces == nil or #tbl.braces == 2, "AVCmds.array `braces` should be of length 2.")
	AVCmds.assert((tbl.n == nil and tbl.min == nil and tbl.max == nil) or (tbl.n ~= nil and tbl.min == nil and tbl.max == nil) or (tbl.n == nil and (tbl.min ~= nil or tbl.max ~= nil)), "AVCmds.array `n` is not compatible with `min` and `max`")
	AVCmds.assert(tbl[1], "AVCmds.array requires at least 1 matcher.")
	local seperator = tbl.seperator or ","
	local pattern_seperator = " *[" .. escape_pattern(seperator) .. "%] ] *"
	local pattern_seperator_cap = " *([" .. escape_pattern(seperator) .. "%] ]) *"
	local braces = tbl.braces or "[]"
	local pattern_braces = "^%b" .. braces
	---@type AVMatcher
	return {
		usage=tbl.usage or "array",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local array_pos = pos
			local array_end = #raw
			if not tbl.loose then
				local match = raw:match(pattern_braces, pos)
				if match then
					array_pos = array_pos + 1
					array_end = pos + #match-1
				elseif tbl.strict then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_ARRAY,
						msg=("Expected array to be surrounded with %s"):format(braces),
					}
				end
			end

			---@type (AVMatchError|AVMatchValue)[]
			local results = {}
			---@type any[]
			local values = {}
			local iter = 0
			while array_pos < array_end do
				iter = iter + 1
				if iter > 20 then error("while loop ran too long.") end
				local matcher = tbl[(#values % #tbl) + 1]
				local result = matcher:match(ctx, raw, array_pos, pattern_seperator)
				table.insert(results, result)
				if result.err then
					break
				end
				table.insert(values, result.value)
				array_pos = result.finish
				local value_cut = result.cut:match(pattern_seperator_cap .. "$")
				if value_cut ~= seperator then
					if value_cut == "]" or value_cut == " " then
						array_pos = array_pos - #seperator
						break
					end
					---@type AVMatchError
					return {
						matcher=self, pos=result.finish, err=AVCmds.MATCH_ERRORS.BAD_ARRAY,
						msg="Excess value input.",
					}
				end
			end
			if tbl.min and #values < tbl.min then
				if #results > 0 and results[1].err then
					return results[1]
				end
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_ARRAY_COUNT,
					msg=("Too many array values, expected count %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
				}
			elseif tbl.max and #values > tbl.max then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_ARRAY_COUNT,
					msg=("Not enough array values, expected count %s."):format(AVCmds._bounds_err_msg(tbl.min, tbl.max)),
				}
			end
			array_pos = raw:match("%]?()", array_pos - (seperator == " " and 1 or 0))
			local cut_value, finish = raw:match(AVCmds._check_cut(cut, tbl.cut_pat, " ()"), array_pos)
			if cut_value == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=array_pos, err=AVCmds.MATCH_ERRORS.BAD_ARRAY,
					msg="Missing cut value.",
				}
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=finish, raw=raw, cut=cut_value, value=values}
		end,
	}
end

--- If key and value matchers are omitted, defaults to parsing a lua table format.  
--- NOTE: `{` and `}` are invalid charecters to type in chat.  
--- - `key` matcher to use for keys. (defaults to AVCmds.table_key)  
--- - `value` matcher to use for values. (defaults to AVCmds.value)  
--- - `braces` string of 2 charecters for opening and closing of a table, default "()".
---@param tbl {key:AVMatcher?,value:AVMatcher?,seperator:string?,braces:string?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.table(tbl)
	tbl = tbl or {}
	AVCmds.assert(tbl.braces == nil or #tbl.braces == 2, "AVCmds.table `braces` should be of length 2.")
	AVCmds.assert(tbl.key == nil, "AVCmds.table key matchers are not supported yet.")
	AVCmds.assert(tbl.value == nil, "AVCmds.table value matchers are not supported yet.")
	local seperator = tbl.seperator or ","
	local braces = tbl.braces or "()"
	local open = braces:sub(1, 1)
	local close = braces:sub(2, 2)
	local braces_pat = "^%b" .. open .. close
	local key_matcher = AVCmds.table_key{}
	local value_matcher
	---@type AVMatcher
	return {
		usage=tbl.usage or "table",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			value_matcher = value_matcher or AVCmds.value{__table_matcher=self}
			local match = raw:match(braces_pat, pos)
			if match == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_TABLE,
					msg=("Missing table brace pair '%s%s'."):format(open, close),
				}
			end
			local cut_value, finish = raw:match(AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos+#match)
			if cut_value == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos+#match, err=AVCmds.MATCH_ERRORS.BAD_TABLE_KEY,
					msg="Missing cut value.",
				}
			end

			local value = {}
			local mpos = pos+#open
			while true do
				mpos = raw:match("^ *()", mpos) or mpos
				if raw:sub(mpos, mpos) == ")" then
					break
				end
				local key_match = key_matcher:match(ctx, raw, mpos, " *= *")
				if not key_match.err then
					mpos = key_match.finish
					mpos = raw:match("^ *()", mpos) or mpos
				end
				local value_match = value_matcher:match(ctx, raw, mpos, " *[" .. escape_pattern(seperator) .. escape_pattern(close) .. "]")
				if value_match.err then
					return value_match
				end
				mpos = value_match.finish
				mpos = raw:match("^ *()", mpos) or mpos

				local key = key_match.value
				if key_match.err then
					key = #value+1
				end
				value[key] = value_match.value
				if raw:sub(value_match.finish-1, value_match.finish-1) == close then
					break
				end
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=finish, raw=raw, cut=cut_value, value=value}
		end,
	}
end

--- - `braces` - string of 2 charecters for opening and closing of a table key, default "[]"
--- - `strict` - disables simple string as a key
--- A handy matcher for table keys.  
--- Matches a simple string or a AVCmds.value wrapped in square braces.  
---@param tbl {braces:string?,strict:boolean?,cut_pat:string?,help:string?,usage:string?}?
function AVCmds.table_key(tbl)
	tbl = tbl or {}
	AVCmds.assert(tbl.braces == nil or #tbl.braces == 2, "AVCmds.table `braces` should be of length 2.")
	local braces = tbl.braces or "[]"
	local open = braces:sub(1, 1)
	local close = braces:sub(2, 2)
	local simple_matcher = AVCmds.string{simple=true}
	local value_matcher = AVCmds.or_{
		AVCmds.string{strict=true},
		AVCmds.number{allow_inf=true, allow_nan=true},
		AVCmds.boolean{strict=true},
	}
	local braces_pat = "^%b" .. open .. close
	---@type AVMatcher
	return {
		usage=tbl.usage or "table key",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			if tbl.strict ~= true then
				local result = simple_matcher:match(ctx, raw, pos, cut)
				if not result.err then
					return result
				end
			end
			local match = raw:match(braces_pat, pos)
			if match == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_TABLE_KEY,
					msg=("Missing table_key brace pair '%s%s'."):format(open, close),
				}
			end
			local cut_value, finish = raw:match(AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos+#match)
			if cut_value == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos+#match, err=AVCmds.MATCH_ERRORS.BAD_TABLE_KEY,
					msg="Missing cut value.",
				}
			end
			local inner_pos = raw:match("^ *()", pos+#open)
			local result = value_matcher:match(ctx, raw, inner_pos, " *"..escape_pattern(close))
			if result.err then
				---@type AVMatchError
				return {
					matcher=self, pos=result.pos, err=AVCmds.MATCH_ERRORS.BAD_TABLE_KEY,
					msg=("Invalid table_key value."):format(open),
				}
			end
			result.finish = finish
			return result
		end,
	}
end

---@alias AVIndexMatchValue string[]|{raw:string}
---@param tbl {[1]:string,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.index(tbl)
	tbl = tbl or {}
	local table_key_matcher = AVCmds.table_key{strict=true}
	---@type AVMatcher
	return {
		usage=tbl.usage or "lua index",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			---@type AVIndexMatchValue
			local path = {}
			local raw_parts = {}
			local ipos = pos
			while true do
				local cpos, char = raw:match("^ *%.? *()([%w_[])", ipos)
				if char == nil then
					break
				end
				ipos = cpos

				local value
				if char == "[" then
					local result = table_key_matcher:match(ctx, raw, ipos, "[.[ ]")
					if result.err then
						break
					end
					value = result.value
					ipos = result.finish-1
				else
					local match, finish = raw:match("^([%w_][%w_0-9]*)()", ipos)
					if match == nil then
						break
					end
					value = match
					ipos = finish
				end
				if type(value) == "string" and value:match("^[%w_][%w_0-9]*$") then
					if #raw_parts > 0 then
						table.insert(raw_parts, ".")
					end
					table.insert(raw_parts, value)
				else
					local s
					if type(value) == "string" then
						local q = value:find("\"") and "'" or "\""
						s = q..value..q
					else
						s = tostring(value)
					end
					table.insert(raw_parts, ("[%s]"):format(s))
				end
				table.insert(path, value)
			end
			path.raw = table.concat(raw_parts, "")
			if raw:sub(ipos-1, ipos-1) == " " then
				ipos = ipos - 1
			end
			local cut_value, finish = raw:match(AVCmds._check_cut(cut, tbl.cut_pat, " ()"), ipos)
			if cut_value == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_INDEX,
					msg="Missing cut value.",
				}
			end
			if #path <= 0 then
				---@type AVMatchError
				return {
					matcher=self, pos=finish, err=AVCmds.MATCH_ERRORS.BAD_INDEX,
					msg="Missing lua indexing.",
				}
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=finish, raw=raw, cut=cut_value, value=path}
		end,
	}
end

--- A handy shortcut for lua value matchers.  
--- This includes: numbers, strings, tables.  
---@param tbl {table_braces:string?,cut_pat:string?,help:string?,usage:string?,__table_matcher:AVMatcher?}?
function AVCmds.value(tbl)
	tbl = tbl or {}
	local value_matcher = AVCmds.or_{
		AVCmds.nil_{cut_pat=tbl.cut_pat},
		AVCmds.string{cut_pat=tbl.cut_pat, strict=true},
		AVCmds.boolean{cut_pat=tbl.cut_pat, strict=true},
		AVCmds.number{cut_pat=tbl.cut_pat, allow_inf=true, allow_nan=true},
		tbl.__table_matcher or AVCmds.table{cut_pat=tbl.cut_pat, braces=tbl.table_braces},
	}
	---@type AVMatcher
	return {
		usage=tbl.usage or "lua value",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local match = value_matcher:match(ctx, raw, pos, cut)
			if not match.err then
				return match
			end
			---@type AVMatchError
			return {
				matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_LUA_VALUE,
				msg="Invalid lua value.",
			}
		end,
	}
end

--- - [1] the flag, eg "f" or "flag"
--- - [2] value matcher, required for `--flag=value`, default boolean.
--- - [3] default value, default `false`, required when using value matcher.
---@param tbl {[1]:string,[2]:AVMatcher,[3]:any,cut_pat:string?,help:string?,usage:string?}
---@return AVMatcher
function AVCmds.flag(tbl)
	error("TODO")
	---@type AVMatcher
	return {
		usage=tbl.usage or "--flag",
		help=tbl.help,
		match=function(self, raw, pos, cut)
			error("TODO")
		end,
	}
end

---@param tbl {cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.player(tbl)
	tbl = tbl or {}
	local matcher = AVCmds.string{cut_pat=tbl.cut_pat,help=tbl.help,usage=tbl.usage}
	---@type AVMatcher
	return {
		usage=tbl.usage or "player",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local result = matcher:match(ctx, raw, pos, cut)
			if result.err then
				result.err = AVCmds.MATCH_ERRORS.BAD_PLAYER
				return result
			end
			local player
			if result.value:match("^%d+$") then
				player =
					---@diagnostic disable-next-line: param-type-mismatch
					AVCmds.get_player_from_id(tonumber(result.value)) or
					AVCmds.get_player_from_steamid(result.value)
			end
			player = player or AVCmds.get_player_from_name(result.value)
			if player == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_PLAYER,
					msg=("Can not find player \"%s\" by id, steamid or name."):format(result.value),
				}
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=result.finish, raw=raw, cut=result.cut, value=player}
		end,
	}
end

---@alias AVCoordinateRelativePosFunc fun(ctx:AVCommandContext):{[1]:number,[2]:number,[3]:number}|string
---@type AVCoordinateRelativePosFunc
AVCmds.coordinate_default_relative_pos = function(ctx)
	local player_matrix, found = server.getPlayerPos(ctx.player.id)
	if not found then
		return "Failed to get player position."
	end
	return {player_matrix[13], player_matrix[14], player_matrix[15]}
end
--- Coordinate matcher returns a table of 3 values, as look direction (`^`) can affect any axis.
---@param tbl {axis:"x"|"y"|"z",relative_pos:AVCoordinateRelativePosFunc?,cut_pat:string?,help:string?,usage:string?}
---@return AVMatcher.coordinate
function AVCmds.coordinate(tbl)
	AVCmds.assert(tbl.axis, "AVCmds.coordinate `axis` is required but missing.")
	tbl.relative_pos = tbl.relative_pos or AVCmds.coordinate_default_relative_pos
	local axis_i = (tbl.axis == "x" and 1) or (tbl.axis == "y" and 2) or 3
	local pattern_prefix = "^([~^]?)()"
	local number_matcher = AVCmds.number{cut_pat=tbl.cut_pat,help=tbl.help,usage=tbl.usage}
	---@class AVMatcher.coordinate : AVMatcher
	---@field match fun(self, ctx:AVCommandContext, raw:string, pos:integer, cut:string?):AVMatchError|(AVMatchValue|{prefix:string})
	return {
		usage=tbl.usage or "coordinate",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			local prefix_match, pos = raw:match(pattern_prefix, pos)
			local n_match = number_matcher:match(ctx, raw, pos, " *[ ,] *")
			local value, finish, cut_value
			if n_match.err then
				if #prefix_match > 0 then
					value = {0, 0, 0}
					cut_value, finish = raw:match(AVCmds._check_cut(cut, tbl.cut_pat, " ()"), pos)
					if cut_value == nil then
						---@type AVMatchError
						return {
							matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_COORDINATE,
							msg="Missing cut value.",
						}
					end
				else
					return n_match
				end
			else
				value = {
					tbl.axis == "x" and n_match.value or 0,
					tbl.axis == "y" and n_match.value or 0,
					tbl.axis == "z" and n_match.value or 0,
				}
				finish, cut_value = n_match.finish, n_match.cut
			end
			local rel_pos, offset
			if #prefix_match > 0 then
				rel_pos, offset = tbl.relative_pos(ctx)
			end
			if prefix_match == "^" then
				local dx, dy, dz, found = server.getPlayerLookDirection(ctx.player.id)
				if not found then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_COORDINATE,
						msg=("Failed to get player look direction."),
					}
				end

				local yaw = math.atan(dx, dz)
				local pitch = math.asin(-dy)
				local a, b, y = pitch, yaw, 0

				local rot_m = {
					math.cos(b)*math.cos(y), math.cos(b)*math.sin(y), -math.sin(b),
					math.sin(a)*math.sin(b)*math.cos(y)-math.cos(a)*math.sin(y), math.sin(a)*math.sin(b)*math.sin(y)+math.cos(a)*math.cos(y), math.sin(a)*math.cos(b),
					math.cos(a)*math.sin(b)*math.cos(y)+math.sin(a)*math.sin(y), math.cos(a)*math.sin(b)*math.sin(y)-math.sin(a)*math.cos(y), math.cos(a)*math.cos(b)
				}

				value = {
					(rot_m[1]*value[1]) + (rot_m[4]*value[2]) + (rot_m[7]*value[3]),
					(rot_m[2]*value[1]) + (rot_m[5]*value[2]) + (rot_m[8]*value[3]),
					(rot_m[3]*value[1]) + (rot_m[6]*value[2]) + (rot_m[9]*value[3])
				}
			end
			-- All prefixes set from player position
			if #prefix_match > 0 then
				if type(rel_pos) == "string" then
					---@type AVMatchError
					return {
						matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_COORDINATE,
						msg=rel_pos,
					}
				end
				value[axis_i] = value[axis_i] + rel_pos[axis_i]
			end
			---@type AVMatchValue|{prefix:string?}
			return {
				matcher=self, start=pos, finish=finish, raw=raw, cut=cut_value, value=value,
				prefix=#prefix_match > 0 and prefix_match or nil,  -- Custom info
			}
		end,
	}
end

---@alias AVPositionCarrotPosFunc fun(ctx:AVCommandContext):{[1]:number,[2]:number,[3]:number}|string
---@type AVPositionCarrotPosFunc
AVCmds.position_default_carrot_offset = function(ctx)
	return {0,0.6,0}
end
---@param tbl {relative_pos:AVCoordinateRelativePosFunc?,carrot_offset:AVPositionCarrotPosFunc?,cut_pat:string?,help:string?,usage:string?}?
---@return AVMatcher
function AVCmds.position(tbl)
	tbl = tbl or {}
	tbl.carrot_offset = tbl.carrot_offset or AVCmds.position_default_carrot_offset
	local player_matcher = AVCmds.player{cut_pat=tbl.cut_pat,help=tbl.help,usage=tbl.usage}
	local x_matcher = AVCmds.coordinate{axis="x", relative_pos=tbl.relative_pos, cut_pat=tbl.cut_pat,help=tbl.help,usage=tbl.usage}
	local y_matcher = AVCmds.coordinate{axis="y", relative_pos=tbl.relative_pos, cut_pat=tbl.cut_pat,help=tbl.help,usage=tbl.usage}
	local z_matcher = AVCmds.coordinate{axis="z", relative_pos=tbl.relative_pos, cut_pat=tbl.cut_pat,help=tbl.help,usage=tbl.usage}
	---@type AVMatcher
	return {
		usage=tbl.usage or "position",
		help=tbl.help,
		match=function(self, ctx, raw, pos, cut)
			---@type {[1]:number,[2]:number,[3]:number}
			local position
			---@type AVMatchValue
			local result

			if position == nil then
				local result_x = x_matcher:match(ctx, raw, pos, " *[ ,] *")
				local result_y = not result_x.err and y_matcher:match(ctx, raw, result_x.finish, " *[ ,] *")
				local result_z = result_y and not result_y.err and z_matcher:match(ctx, raw, result_y.finish, cut)
				if result_x.value and result_y and result_y.value and result_z and result_z.value then
					result = result_z
					position = {
						result_x.prefix == "^" and (result_x.value[1] + result_y.value[1] + result_z.value[1]) or result_x.value[1],
						result_y.prefix == "^" and (result_x.value[2] + result_y.value[2] + result_z.value[2]) or result_y.value[2],
						result_z.prefix == "^" and (result_x.value[3] + result_y.value[3] + result_z.value[3]) or result_z.value[3],
					}
					if tbl.carrot_offset and (result_x.prefix == "^" or result_y.prefix == "^" or result_z.prefix == "^") then
						local carrot_pos = tbl.carrot_offset(ctx)
						if carrot_pos then
							if result_x.prefix == "^" then
								position[1] = position[1] + carrot_pos[1]
							end
							if result_y.prefix == "^" then
								position[2] = position[2] + carrot_pos[2]
							end
							if result_z.prefix == "^" then
								position[3] = position[3] + carrot_pos[3]
							end
						end
					end
				end
			end
			-- Ensure that it's not gonna be a peer_id, but do allow steam id's (17 digits)
			if position == nil and (not raw:match("^%d", pos) or raw:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d", pos)) then
				local _result = player_matcher:match(ctx, raw, pos, cut)
				if not _result.err then
					local m = server.getPlayerPos(_result.value.id)
					---@cast _result -AVMatchError
					result = _result
					position = {m[13],m[14],m[15]}
				end
			end
			if position == nil then
				---@type AVMatchError
				return {
					matcher=self, pos=pos, err=AVCmds.MATCH_ERRORS.BAD_POSITION,
					msg=("Invalid position, spesify a x,y,z or player."),
				}
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=result.finish, raw=raw, cut=result.cut, value=position}
		end,
	}
end

---@param matcher AVMatcher
---@param default any|fun():any
---@return AVMatcher
function AVCmds.optional(matcher, default)
	AVCmds.assert(matcher, "AVCmds.optional requires a matcher.")
	if type(default) ~= "function" then
		local default_value = default
		default = function() return default_value end
	end
	---@type AVMatcher
	return {
		usage=matcher.usage,
		help=matcher.help,
		match=function(self, ctx, raw, pos, cut)
			local result = matcher:match(ctx, raw, pos, cut)
			if result.err then
				---@type AVMatchValue
				return {matcher=self, start=pos, finish=pos, raw=raw, cut="", value=default()}
			end
			return result
		end,
	}
end

---@param tbl {[integer]:AVMatcher,help:string?,usage:string?}
---@return AVMatcher
function AVCmds.or_(tbl)
	AVCmds.assert(#tbl >= 2, "AVCmds.or_ requires 2 or more matchers.")
	local usage_parts = {}
	local help_parts = {}
	for _, matcher in ipairs(tbl) do
		if matcher.usage then
			table.insert(usage_parts, matcher.usage)
		end
		if matcher.help then
			table.insert(help_parts, matcher.help)
		end
	end
	---@type AVMatcher
	return {
		usage=tbl.usage or ("(%s)"):format(table.concat(usage_parts, "|")),
		help=tbl.help or table.concat(help_parts, "\n\n"),
		match=function(self, ctx, raw, pos, cut)
			local msgs = {}
			local errs = {}
			local err_pos = pos
			for _, matcher in ipairs(tbl) do
				local result = matcher:match(ctx, raw, pos, cut)
				if not result.err then
					return result
				end
				if result.pos > err_pos then
					err_pos = result.pos
					msgs = {}
				end
				---@diagnostic disable-next-line: undefined-field
				table.insert(msgs, result.msg)
				table.insert(errs, result)
			end
			---@type AVMatchError
			return {
				matcher=self, pos=err_pos, err=AVCmds.MATCH_ERRORS.OR_FAILED,
				msg="& " .. table.concat(msgs, "\n& "),
				or_errs=errs,
			}
		end,
	}
end

--- Ensures all matchers are matched.
--- If first value is integer, that index is used as the argument value.
--- Otherwise, the argument value is an array of values for each matcher.
---@param tbl {[1]:integer|AVMatcher,[integer]:AVMatcher,help:string?,usage:string?}
---@return AVMatcher
function AVCmds.and_(tbl)
	AVCmds.assert(#tbl >= 2, "AVCmds.and_ requires 2 or more matchers.")
	local usage_parts = {}
	local help_parts = {}
	for _, matcher in ipairs(tbl) do
		if type(matcher) == "table" then
			if matcher.usage then
				table.insert(usage_parts, matcher.usage)
			end
			if matcher.help then
				table.insert(help_parts, matcher.help)
			end
		end
	end
	local result_index = type(tbl[1]) == "number" and tbl[1] or nil
	---@type AVMatcher
	return {
		usage=tbl.usage or ("(" .. ("%s"):format(table.concat(usage_parts, " ")) .. ")"),
		help=tbl.help or table.concat(help_parts, "\n\n"),
		match=function(self, ctx, raw, pos, cut)
			---@type AVMatcherResult[]
			local results = {}
			local values = {}
			local mpos = pos
			for _, matcher in ipairs(tbl) do
				if type(matcher) ~= "number" then
					local result = matcher:match(ctx, raw, raw:match("^ *()", mpos), cut)
					if result.err then
						return result
					end
					table.insert(results, result)
					table.insert(values, result.value)
					mpos = result.finish
				end
			end
			if result_index then
				return results[result_index]
			end
			---@type AVMatchValue
			return {matcher=self, start=pos, finish=results[#results].finish, raw=raw, cut=results[#results].cut, value=values}
		end,
	}
end

--- If the first matcher does not fail, use the 2nd matcher, otherwise the 3rd.
--- 3rd matcher is optional, in this case an empty result is returned.
---@param tbl {[1]:AVMatcher,[2]:AVMatcher,[3]:AVMatcher?,help:string?,usage:string?}
---@return AVMatcher
function AVCmds.if_(tbl)
	AVCmds.assert(#tbl == 2 or #tbl == 3, "AVCmds.if_ requires 2 or 3 matchers.")
	local usage_parts = {}
	local help_parts = {}
	for _, matcher in ipairs(tbl) do
		if type(matcher) == "table" then
			if matcher.usage then
				table.insert(usage_parts, matcher.usage)
			end
			if matcher.help then
				table.insert(help_parts, matcher.help)
			end
		end
	end
	---@type AVMatcher
	return {
		usage=tbl.usage or ("(" .. ("%s"):format(table.concat(usage_parts, " ")) .. ")"),
		help=tbl.help or table.concat(help_parts, "\n\n"),
		match=function(self, ctx, raw, pos, cut)
			local cond_result = tbl[1]:match(ctx, raw, pos, cut)
			if cond_result.err then
				if tbl[3] then
					return tbl[3]:match(ctx, raw, pos, cut)
				end
				---@type AVMatchValue
				return {matcher=self, start=pos, finish=pos, raw=raw, cut="", value=nil}
			end
			return tbl[2]:match(ctx, raw, raw:match("^ *()", cond_result.finish), cut)
		end,
	}
end


---@type AVCommand
AVCmds._root_command = AVCmds.createCommand {name="ROOT"}


-- Stuff for debugging.

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

--- Follows parents, using command name for the path.
---@param ctx AVCommandContext
---@param parts string[]?
---@return string[]
function AVCmds.toparts_context_path(ctx, parts)
	parts = parts or {}
	if ctx.parent then
		AVCmds.toparts_context_path(ctx.parent, parts)
	end
	-- Ignore context of onCustomCommand.
	if ctx.command ~= AVCmds._root_command or ctx.handler ~= nil then
		table.insert(parts, ctx.command.name)
	end
	if ctx.handler then
		table.insert(parts, ("[%.0f]"):format(ctx.command._handlers_indicies[ctx.handler]))
	end
	return parts
end

--- Goes all the way down until there is no parent anymore and returns that.
---@param ctx AVCommandContext
---@return AVCommandContext
function AVCmds.tocontext_bottom_parent(ctx)
	while true do
		if ctx.parent == nil then
			return ctx
		end
		ctx = ctx.parent
	end
end

--- Follows parents, using command name for the path.
--- Suggested to use `tocontext_bottom_parent`
---@param ctx AVCommandContext
---@param lines string[]?
---@param depth integer?
---@return string[]
function AVCmds.toparts_context_tree(ctx, lines, depth)
	lines = lines or {}
	depth = depth or 0
	local line = {}
	if depth > 0 then
		table.insert(line, string.rep("  ", depth))
	end
	table.insert(line, ("%s:%s:%s"):format(ctx.command.name, ctx.pos, ctx.finish))
	if ctx.handler then
		table.insert(line, ("[%s]"):format(ctx.command._handlers_indicies[ctx.handler]))
	end
	if ctx.args and #ctx.args > 0 then
		-- TODO: Handle non-positionals
		local args = {}
		for _, arg in ipairs(ctx.args) do
			table.insert(args, str_value(arg))
		end
		table.insert(line, ("(%s)"):format(table.concat(args, ", ")))
	end
	if ctx.err then
		table.insert(line, ("- %s: %s"):format(ctx.err.err, ctx.err.msg))
	end
	table.insert(line, ("  {%s}"):format(tostring(ctx)))
	table.insert(lines, table.concat(line, " "))
	for i, handler in ipairs(ctx.children_order) do
		local child_ctx = ctx.children[handler]
		AVCmds.toparts_context_tree(child_ctx, lines, depth+1)
	end
	return lines
end
