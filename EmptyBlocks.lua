-- Empty blocks can be used to create spacer blocks for Fortress.
-- They are actually data objects of the type "FortressDummy", no other
-- display addon should show them (type attribute is set and neither 
-- "data source" nor "launcher").

local Fortress = LibStub("AceAddon-3.0"):GetAddon("Fortress")
local EB = Fortress:NewModule("EmptyBlocks")

-- TODO: localize me!

local broker = LibStub("LibDataBroker-1.1")

local DO_PREFIX = "FortressDummy"

local showNames = false
local objects = {}

local options = {
	name = "Empty Blocks",
	type = "group",
	childGroups = "select",
	args = {
		create = {
		  name = "Create empty block",
		  desc = "",
			type = "input",
			get  = nil,
			set  = function(info, value)
				EB:Create(value)
			end,
			validate = function(info, value)
				if db.emptyBlocks[value] then
					return ("There is allready a block named %s."):format(value)
				end
				return true
			end,
			order = 1,
		},
		showText = {
			name = "Show names",
			desc = "",
			type = "toggle",
			get  = function(info)
				return showNames -- not saved!
			end,
			set  = function(info, value)
				showNames = value
				EB:UpdateNames()
			end,
			order = 2,
		},
		note = {
			name = "Note: Disable an empty block to remove it on the next reload.",
			type = "description",
		},
	},
}

local adjustedDefaults = {
	showIcon    = false,
	fixedWidth  = true,
	textAlign   = "CENTER",
	textAlignTo = "CENTER",
	textColor   = {r = 1, g = 0, b = 0}, -- red text
}

local function Create(name, loading)
	local doname = DO_PREFIX..name

	if not loading then
		local settings = db.pluginSettings[doname]
		local useMaster = db.pluginUseMaster[doname]
		for k, v in pairs(adjustedDefaults) do
			settings[k] = v
			useMaster[k] = false
		end
	end
	
	objects[name] = broker:NewDataObject(doname, {
		type = Fortress.DummyType,
		name = name,
		enabled = true,
		configName = ("Empty Block: %s"):format(name),
	})	
end

function EB:OnInitialize()
	db = Fortress.db.profile

	Fortress.db.RegisterCallback(self, "OnDatabaseShutdown", "RemoveDisabled")

	for name in pairs(db.emptyBlocks) do
		Create(name, true)
	end
end

function EB:GetOptionsTable()
	return options
end

function EB:Create(name)
	if db.emptyBlocks[name] then	
		self:Print("There is allready a block named:", name)
		return
	end
	
	db.emptyBlocks[name] = true
	Create(name)
end

function EB:RemoveDisabled()
	for name, obj in pairs(objects) do
		local doname = DO_PREFIX..name
		if not db.pluginSettings[doname].enabled then
			db.emptyBlocks[name] = nil
			db.pluginSettings[doname] = nil
			db.blockDB[doname] = nil
		end
	end
end

function EB:UpdateNames()
	for name, obj in pairs(objects) do
		obj.text = showNames and name or ""
	end
end
