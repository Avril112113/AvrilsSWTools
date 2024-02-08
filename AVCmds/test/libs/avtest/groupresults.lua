local Config = require "avtest.config"


---@class GroupResults
---@field group Group
---@field out HookedStdout
---@field err string?
---@field tests TestResult[]
---@field groups GroupResults[]
---@field fails integer
local GroupResults = {}
GroupResults.__index = GroupResults


---@param group Group
function GroupResults.new(group)
	return setmetatable({
		group=group,
		out=group.out,
		err=group.err,
		tests={},
		groups={},
		fails=0,
	}, GroupResults)
end

---@param testResult TestResult
function GroupResults:addTestResult(testResult)
	table.insert(self.tests, testResult)
	if testResult:hasFailed() then
		self.fails = self.fails + 1
	end
end

---@param groupResults GroupResults
function GroupResults:addGroupResults(groupResults)
	table.insert(self.groups, groupResults)
	if groupResults:hasFailed() then
		self.fails = self.fails + 1
	end
end

function GroupResults:hasFailed()
	return self.fails > 0 or self.err
end


---@param prefix string?
function GroupResults:print(prefix)
	prefix = (prefix or "") .. self.group.name .. "/"
	local total = #self.tests + #self.groups
	print(("%s[%s%s%s]%s - %s%s/%s%s"):format(Config.PREFIX_TAG, Config.PREFIX_GROUP, prefix, Config.PREFIX_TAG, Config.RESET, (self.err or self.fails > 0) and Config.PREFIX_FAIL or Config.PREFIX_PASS, total-self.fails, total, Config.RESET))
	if self.out ~= nil and #self.out.strs > 0 then
		local line_prefix = ("    %s[OUT]: "):format(Config.PREFIX_TAG)
		local line_nl = "\n" .. string.rep(" ", #Config.stripColors(line_prefix))
		print(("%s%s%s%s"):format(line_prefix, Config.PREFIX_TEXT, table.concat(self.out.strs, ""):gsub("\n+$", ""):gsub("\n", line_nl), Config.RESET))
	end
	if self.err ~= nil then
		local line_prefix = ("    %s[%sERROR%s]: "):format(Config.PREFIX_TAG, Config.PREFIX_ERR, Config.PREFIX_TAG)
		local line_nl = "\n" .. string.rep(" ", #Config.stripColors(line_prefix))
		print(("%s%s%s%s"):format(line_prefix, Config.PREFIX_TEXT, self.err:gsub("\n", line_nl), Config.RESET))
	end
	if #self.tests <= 0 and #self.groups <= 0 then
		print(("    %sNo tests or groups...%s"):format(Config.PREFIX_TAG, Config.RESET))
	end
	for _, test in ipairs(self.tests) do
		test:print(prefix)
	end
	for _, subgroup in ipairs(self.groups) do
		subgroup:print(prefix)
	end
end


return GroupResults
