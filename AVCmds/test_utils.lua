local TEST


local Utils = {}


---@param TEST_ TestEnv
function Utils.setup(TEST_)
	TEST = TEST_

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
end


function Utils.str_value(value)
	if type(value) == "table" then
		local parts = {"{"}
		for i, v in ipairs(value) do
			table.insert(parts, ("%s,"):format(Utils.str_value(v)))
		end
		for i, v in pairs(value) do
			if type(i) ~= "number" or i > #parts then
				if type(i) == "string" and i:match("^[a-z]%w*$") then
					table.insert(parts, ("%s=%s,"):format(i, Utils.str_value(v)))
				else
					table.insert(parts, ("[%s]=%s,"):format(Utils.str_value(i), Utils.str_value(v)))
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
function Utils.cmd_expect(expect, handled, ctx)
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
	return cmd_str, true, Utils.str_value(expect) .. "\n" .. table.concat(AVCmds.toparts_context_tree(ctx), "\n")
end


return Utils
