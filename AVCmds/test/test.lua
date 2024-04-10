--[[
	Example usage:
		lua test.lua
		lua test.lua tests/avmath
]]


local args = {...}

package.path = package.path .. "libs/?.lua;libs/?/init.lua;test/libs/?.lua;test/libs/?/init.lua;"


local AvTest = require "avtest.init"


AvTest.Runner.new()
	:setOutputFileEnabled(false)
	:setOutputFilePerTest(false)
	:setErroredAlwaysToConsole(true)
	:setOutputFileStripColors(false)
	:addWhitelist(args[1])
	:addDir("./tests")
	:runTests()
