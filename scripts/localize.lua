local inFileName, appName, defaultL, warn = ...

local pattern = "(L%[.-%])"
local unLPattern = "[^%[](\".-\")[^%]]"
local strmatch = string.gmatch

local localeList = {}

local locales = {
 "enUS",
 "deDE",
 "frFR",
 "esES",
 "ruRU",
}

local function Warn(str, lineNum)
	print("Warning: Unlocalized string '"..str.."' in line " .. lineNum .. ".")
end

local function FindStrings(line, num)
	for l in strmatch(line, pattern) do
		localeList[l] = true		
	end
	if warnUnLocalized == "w" then
		for l in strmatch(line, unLPattern) do
			Warn(l, num)
		end
	end
end

local function PrintLocaleFile(fname, locale, default)
	local f = io.open(fname, "w")
	
	if default then
		f:write([[local L = LibStub("AceLocale-3.0"):NewLocale("]] .. appName .. [[", "]] .. locale .. [[", true)]] .. "\n\n")
	else
		f:write([[local L = LibStub("AceLocale-3.0"):NewLocale("]] .. appName .. [[", "]] .. locale .. [[")]] .. "\n\n" .. [[if not L then return end]].."\n\n")
	end
	
	for str in pairs(localeList) do
		f:write(str .. " = true\n")
	end
	
	f:close()
end

local function PrintXML()
	local f = io.open("Locales\\locales.xml", "w")
	
	f:write([[<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.blizzard.com/wow/ui/
..\FrameXML\UI.xsd">
]])
	for _, l in pairs(locales) do
		f:write("\t<Script file=\""..l..".lua\" />\n")
	end
	f:write("</Ui>\n")
end

local inF = io.open(inFileName, "r")
local n = 1

for line in inF:lines() do
	FindStrings(line, n)
	n = n + 1
end
for _, l in pairs(locales) do
	PrintLocaleFile("locales\\"..l..".lua", l, l == defaultL)
end
PrintXML()
