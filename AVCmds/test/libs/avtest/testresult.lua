local Config = require "avtest.config"


--- TODO: Typing for TestAssertion
---@alias TestCheck {name:string,line:integer,fail:boolean,msg:string?,value:any?}


---@class TestResult
---@field test Test
---@field out HookedStdout
---@field err string?
---@field checks TestCheck[]
local TestResult = {}
TestResult.__index = TestResult


---@param test Test
function TestResult.new(test)
	return setmetatable({
		test=test,
		checks={},
	}, TestResult)
end

---@param check TestCheck
function TestResult:addCheck(check)
	table.insert(self.checks, check)
	self.out:addSpecialData(check)
end

function TestResult:hasFailed()
	for _, check in ipairs(self.checks) do
		if check.fail then
			return true
		end
	end
	return self.err ~= nil
end

---@param prefix string?
function TestResult:print(prefix)
	prefix = (prefix or "/") .. self.test.name
	local checksSuffix = ""
	if #self.checks > 0 then
		local failedChecks = 0
		for _, check in ipairs(self.checks) do
			if check.fail then
				failedChecks = failedChecks + 1
			end
		end
		checksSuffix = (" - %s%s/%s%s"):format(failedChecks > 0 and Config.PREFIX_FAIL or Config.PREFIX_PASS, #self.checks-failedChecks, #self.checks, Config.RESET)
	end
	print(("%s[%s%s%s]%s - %s%s%s"):format(Config.PREFIX_TAG, Config.PREFIX_GROUP, prefix, Config.PREFIX_TAG, Config.RESET, self:hasFailed() and (Config.PREFIX_FAIL.."FAIL") or (Config.PREFIX_PASS.."PASS"), Config.RESET, checksSuffix))
	local parts = {}
	local function print_parts()
		if #parts <= 0 then return end
		local line_prefix = ("    %s[OUT]: "):format(Config.PREFIX_TAG)
		local line_nl = "\n" .. string.rep(" ", #Config.stripColors(line_prefix))
		print(("%s%s%s%s"):format(line_prefix, Config.PREFIX_TEXT, table.concat(parts, ""):gsub("\n+$", ""):gsub("\n", line_nl), Config.RESET))
		parts = {}
	end
	for _, data in ipairs(self.out.special) do
		if type(data) == "number" then
			---@cast data number
			table.insert(parts, self.out.strs[data])
		else
			---@cast data TestCheck
			print_parts()
			local check = data
			local line_prefix = ("    %s[CHECK]:%3s:%s%s: "):format(Config.PREFIX_TAG, check.line, (check.fail and Config.PREFIX_FAIL or Config.PREFIX_PASS) .. check.name, Config.PREFIX_TAG)
			local line_nl = "\n" .. string.rep(" ", #Config.stripColors(line_prefix))
			print(("%s%s%s%s"):format(line_prefix, Config.PREFIX_TEXT, (check.msg and check.msg:gsub("\n", line_nl) or ""), Config.RESET))
		end
	end
	print_parts()
	if self.err ~= nil then
		local line_prefix = ("    %s[%sERROR%s]: "):format(Config.PREFIX_TAG, Config.PREFIX_ERR, Config.PREFIX_TAG)
		local line_nl = "\n" .. string.rep(" ", #Config.stripColors(line_prefix))
		print(("%s%s%s%s"):format(line_prefix, Config.PREFIX_TEXT, tostring(self.err):gsub("\n", line_nl), Config.RESET))
	end
end


return TestResult
