local GroupResults = require "avtest.groupresults"
local StdHook = require "avtest.std_hook"

local TestEnv = require "avtest.test_env"


---@class Group
---@field name string
---@field tests Test[]
---@field groups Group[]
---@field out HookedStdout
---@field err string?
---@field _runningTestResult TestResult
local Group = {}
Group.__index = Group


---@param name string
function Group.new(name)
	local self = setmetatable({
		name=name,
		tests={},
		groups={},
	}, Group)
	return self
end

---@param group Group
---@return Group
function Group:addGroup(group)
	table.insert(self.groups, group)
	return group
end

--- Finds all lua files in given directory and runs TestGroup:loadFile on it.
--- If recursive, sub-dirs have their own test group created.
---@param path string
---@param recursive boolean
---@return Group[]
function Group:loadFolder(path, recursive)
	error("Not implemented: TestGroup:loadFolder")
end

---@param path string?
function Group:_createEnv(path)
	if self.env ~= nil then
		error("Attempt to create env when it's already created.")
	end

	local env = setmetatable({
		TEST=TestEnv.create({
			group=self,
			path=path,
		}),
	}, {__index=_G})
	self.env = env
end

--- Loads the lua file, creating a new test group for all tests added by that file.
---@param path string
---@return Group
function Group:loadFile(path)
	local group = Group.new(path:match("[^/]*$"))
	group:_createEnv(path)
	local f, err = loadfile(path, "bt", group.env)
	if f then
		group.out = StdHook.new()
		group.out:hook()
		local ok, err = xpcall(f, debug.traceback)
		group.out:unhook()
		if not ok then
			group.err = err
		end
	else
		group.err = err
	end
	self:addGroup(group)
	return group
end

---@param test Test
---@return Test
function Group:addTest(test)
	table.insert(self.tests, test)
	return test
end

---@param filter string[][]?
---@param depth integer?
function Group:runTests(filter, depth)
	depth = depth or 1
	local results = GroupResults.new(self)
	for _, test in ipairs(self.tests) do
		if filter then
			for _, path in ipairs(filter) do
				if path[depth] == test.name then
					goto run
				end
			end
			goto continue
		end
		::run::
		results:addTestResult(test:runTest())
		::continue::
	end
	for _, subgroup in ipairs(self.groups) do
		local pass_filters = true
		if filter then
			for _, path in ipairs(filter) do
				if path[depth] == subgroup.name then
					if #path == depth then
						pass_filters = false
					end
					goto run
				end
			end
			goto continue
		end
		::run::
		results:addGroupResults(subgroup:runTests(pass_filters and filter or nil, depth+1))
		::continue::
	end
	return results
end


return Group
