-- Feel free to simply copy this file and use it to run your own tests.
-- This file will run all tests located in "./tests/" by default.
-- You can provide arguments for tests to be run, they can be a path to a: folder, file or test name
-- If the path leads to a test, it runs that test.
-- If the path leads to a lua file, it runs all tests in that file.
-- If the path leads to a folder, all lua files, recursively are loaded as tests.

local args = {...}

package.path = package.path .. "libs/?.lua;libs/?/init.lua;test/libs/?.lua;test/libs/?/init.lua;"


local lfs = require "lfs"

local AvTest = require "avtest.init"


local main_group = AvTest.TestGroup.new("")
local filtered_tests = {}

if #args <= 0 then
	table.insert(args, "./tests")
end

for _, path in ipairs(args) do
	path = path:match("^%.%/(.*)$") or path
	local file_path, test_path = path:match("^(.-%.lua)[/\\](.*)$")
	file_path = file_path or path
	test_path = test_path or nil
	local attributes = lfs.attributes(file_path)
	if attributes == nil then
		error(("Invalid test file path \"%s\""):format(file_path))
	end
	local groups = {}
	if attributes.mode == "directory" then
		groups = main_group:loadFolder(file_path, true)
		for _, group in ipairs(groups) do
			group.name = ("%s/%s"):format(file_path, group.name)
		end
	elseif attributes.mode == "file" then
		groups = {main_group:loadFile(file_path)}
		for _, group in ipairs(groups) do
			group.name = file_path
		end
	else
		error(("Invalid file type \"%s\""):format(attributes.mode))
	end
	for _, group in ipairs(groups) do
		local filter_path = {group.name}
		if test_path ~= nil and #test_path > 0 then
			---@type Group|Test
			local tmp = group
			for start, name, finish in string.gmatch(test_path, "()([^/\\]+)()[/\\]*") do
				-- If not a group, it's a test, which is bad.
				if tmp.groups == nil then
					local test_part = test_path:sub(start)
					error(("Expected a group but found a test at \"%s%s%s\""):format(file_path, #test_part > 0 and "/" or "", test_part))
				end
				for _, sub_group in pairs(tmp.groups) do
					if sub_group.name == name then
						tmp = sub_group
						table.insert(filter_path, sub_group.name)
						goto continue
					end
				end
				for _, test in pairs(tmp.tests) do
					if test.name == name then
						tmp = test
						table.insert(filter_path, test.name)
						goto continue
					end
				end
				local test_part = test_path:sub(finish)
				error(("Test \"%s\" does not exist in \"%s%s%s\""):format(name, file_path, #test_part > 0 and "/" or "", test_part))
				::continue::
			end
		end
		table.insert(filtered_tests, filter_path)
	end
end

local results = main_group:runTests(filtered_tests)
results:print()

local total = 0
local fails = 0
---@param groupResults GroupResults
local function recurCountResults(groupResults)
	for _, testResult in ipairs(groupResults.tests) do
		if #testResult.checks > 0 then
			for _, check in ipairs(testResult.checks) do
				total = total + 1
				if check.fail then
					fails = fails + 1
				end
			end
		else
			total = total + 1
			if testResult:hasFailed() then
				fails = fails + 1
			end
		end
	end
	for _, subGroupResults in ipairs(groupResults.groups) do
		recurCountResults(subGroupResults)
	end
end
recurCountResults(results)

print()
print(("%sTotal:  %s%s"):format(AvTest.Config.PREFIX_TAG, total, AvTest.Config.RESET))
print(("%sPassed: %s%s%s"):format(AvTest.Config.PREFIX_TAG, results.fails > 0 and AvTest.Config.PREFIX_FAIL or AvTest.Config.PREFIX_PASS, total-fails, AvTest.Config.RESET))
print(("%sFailed: %s%s%s"):format(AvTest.Config.PREFIX_TAG, results.fails > 0 and AvTest.Config.PREFIX_FAIL or AvTest.Config.PREFIX_PASS, fails, AvTest.Config.RESET))
