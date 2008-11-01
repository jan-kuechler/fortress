--[[ @file-author@ @file-date-iso@ @file-abbreviated-hash@ ]]--
local LibStub = LibStub
local Fortress = LibStub("AceAddon-3.0"):NewAddon("Fortress", "AceConsole-3.0", "AceEvent-3.0")

local broker = LibStub("LibDataBroker-1.1")
local legos  = LibStub("LegoBlock-Beta1")

local db

local frames = {}
local dataObjects = {}
local strTable = {}

-- Change this line to
-- local TABLET20_FIX = false
-- to disable the fix for Tablet-2.0 tooltips,
-- that may prevent the tooltip to be shown for
-- certain plugins.
local TABLET20_FIX = true

--------
-- utility functions
--------
local function Debug(...)
--	ChatFrame1:AddMessage(strjoin(" ", "Fortess Debug:", tostringall(...)), 0, 1, 0)
end

local function GetPluginSetting(pluginName, setting)
	if db.pluginUseMaster[pluginName][setting] then
		return db.masterSettings[setting]
	else
		return db.pluginSettings[pluginName][setting]
	end
end

local function GetAnchors(frame)
	local x, y = frame:GetCenter()
	local leftRight
	if x < GetScreenWidth() / 2 then
		leftRight = "LEFT"
	else
		leftRight = "RIGHT"
	end
	if y < GetScreenHeight() / 2 then
		return "BOTTOM", "TOP"
	else
		return "TOP", "BOTTOM"
	end
end

local function RGBToHex(r, g, b)
	return ("%02x%02x%02x"):format(r*255, g*255, b*255)	
end

local function HideBlocks(block, name)
	if db.hideAllOnMouseOut then
		Fortress:HideAllObjects()
	elseif GetPluginSetting(name, "hideOnMouseOut") then
		block:SetAlpha(0)
	end
end

--------
-- Tooltip handling
--------
local GameTooltip = GameTooltip
local function GT_OnLeave(self)
	self:SetScript("OnLeave", self.fortressOnLeave)
	self:Hide()
	if self.fortressBlock then
		HideBlocks(self.fortressBlock, self.fortressName)
	end
	GameTooltip:EnableMouse(false)
end

local function PrepareTooltip(frame, anchorFrame)
	if frame == GameTooltip then
		frame.fortressOnLeave = frame:GetScript("OnLeave")
		frame.fortressBlock = anchorFrame
		frame.fortressName = anchorFrame.name
		
		frame:EnableMouse(true)
		frame:SetScript("OnLeave", GT_OnLeave)
	end
	frame:SetOwner(anchorFrame, "ANCHOR_NONE")
	frame:ClearAllPoints()
	local a1, a2 = GetAnchors(anchorFrame)
	frame:SetPoint(a1, anchorFrame, a2)	
end

local function Block_OnEnter(self)
	local obj  = self.obj
	local name = self.name
		
	if db.hideAllOnMouseOut then
		Fortress:ShowAllObjects()
	else
		self:SetAlpha(GetPluginSetting(name, "blockAlpha"))
	end
	
	if TABLET20_FIX and self:GetScript("OnEnter") ~= Block_OnEnter then
		self:SetScript("OnEnter", Block_OnEnter)
	end
	
	if GetPluginSetting(name, "disableTooltip") then
		return
	end
			
	if (not InCombatLockdown()) or (not GetPluginSetting(name, "hideTooltipInCombat")) then	
		if obj.tooltip then
			Debug("using obj.tooltip")
			PrepareTooltip(obj.tooltip, self)
			if obj.tooltiptext then
				obj.tooltip:SetText(obj.tooltiptext)
			end
			obj.tooltip:Show()
		
		elseif obj.OnTooltipShow then
			PrepareTooltip(GameTooltip, self)
			obj.OnTooltipShow(GameTooltip)
			GameTooltip:Show()
		
		elseif obj.tooltiptext then
			PrepareTooltip(GameTooltip, self)
			GameTooltip:SetText(obj.tooltiptext)
			GameTooltip:Show()		
		
		elseif obj.OnEnter then
			obj.OnEnter(self)
		end
	end
end

local function Block_OnLeave(self)
	local obj  = self.obj
	local name = self.name
	
	if obj.OnLeave then
		obj.OnLeave(self)
	end	
	
	if MouseIsOver(GameTooltip) and (obj.tooltiptext or obj.OnTooltipShow) then return end
	
	HideBlocks(self, name)

	if obj.tooltiptext or obj.OnTooltipShow then
		GT_OnLeave(GameTooltip)
	end
end

local function Block_OnClick(self, ...)
	local obj  = self.obj
	local name = self.name
	
	if obj.OnLeave then
		obj.OnLeave(self)
	elseif obj.tooltiptext or obj.OnTooltipShow then
		GT_OnLeave(GameTooltip)
	elseif obj.tooltip then
		obj.tooltip:Hide()
	end
	
	if obj.OnClick then
		obj.OnClick(self, ...)
	end
end

--------
-- block updaters
--------
local function TextUpdater(frame, value, name)
	local obj = dataObjects[name]
	local showLabel = GetPluginSetting(name, "showLabel")
	local showText  = GetPluginSetting(name, "showText")

	local clrDB = GetPluginSetting(name, "textColor")
	local textColor = RGBToHex(clrDB.r, clrDB.g, clrDB.b)
	
	local hasText = false
	
	if showLabel and obj.label then  -- try to show the label
		local clrDB = GetPluginSetting(name, "labelColor")
		local labelColor = RGBToHex(clrDB.r, clrDB.g, clrDB.b)

		if showText and obj.value then
			local clrDB = GetPluginSetting(name, "unitColor")
			local unitColor = RGBToHex(clrDB.r, clrDB.g, clrDB.b)

			frame.text:SetFormattedText("|cff%s%s:|r %s|cff%s%s|r", 
																	labelColor, obj.label, obj.value, unitColor, obj.suffix or "")

		elseif showText and obj.text and obj.text ~= obj.label then
			frame.text:SetFormattedText("|cff%s%s:|r |cff%s%s|r", labelColor, obj.label, textColor, obj.text)

		else	
			frame.text:SetFormattedText("|cff%s%s|r", labelColor, obj.label)
		end
		hasText = true
		
	elseif showLabel and obj.type == "launcher" then -- show the addonname for launchers if no label is set
		local clrDB = GetPluginSetting(name, "labelColor")
		local labelColor = RGBToHex(clrDB.r, clrDB.g, clrDB.b)
		local addonName, addonTitle = GetAddOnInfo(obj.tocname or name)
		frame.text:SetFormattedText("|cff%s%s|r", labelColor, addonTitle or addonName or name)
		hasText = true
		
	elseif showText and obj.text then
		if obj.value then
			local clrDB = GetPluginSetting(name, "unitColor")
			local unitColor = RGBToHex(clrDB.r, clrDB.g, clrDB.b)

			frame.text:SetFormattedText("|cff%s%s|cff%s%s|r", textColor, obj.value, unitColor, obj.suffix or "")
		else
			frame.text:SetFormattedText("|cff%s%s|r", textColor, obj.text)
		end
		hasText = true
		
	else
		frame:HideText()
	end
	
	if hasText then
		frame:ShowText()
		if GetPluginSetting(name, "fixedWidth") then
			frame.text:SetWidth(frame.text:GetStringWidth())
		end
	end
end

local uniqueUpdaters = {
	text = TextUpdater,
	
	icon = function(frame, value, name)
		if value and GetPluginSetting(name, "showIcon") then
			frame:SetIcon(value)
			frame:ShowIcon()
		else
			frame:HideIcon()
		end
	end,
	
	-- tooltiptext is no longer in the data spec, but 
	-- I'll continue to support it, as some plugins seem to use it
	tooltiptext = function(frame, value, name)
		local object = dataObjects[name]
		local tt = object.tooltip or GameTooltip
		if tt:GetOwner() == frame then
			tt:SetText(object.tooltiptext)
		end
	end,
	
--	OnClick = function(frame, value, name)
--		frame:SetScript("OnClick", value)
--	end,
}

local updaters = {
	label  = TextUpdater,
	value  = TextUpdater,
	suffix = TextUpdater,	
}
for k, v in pairs(uniqueUpdaters) do
	updaters[k] = v
end

--------
-- Ace3 callbacks
--------
function Fortress:OnInitialize()
	self.defaults  = {
		profile = {
			blockDB = {
				['*'] = {},
			},
			pluginSettings = {
				['*'] = {
					enabled = true,
				},
			},
			masterSettings = {
				showText  = true,
				showIcon  = true,
				showLabel = true,

				borderColor = {r = 0, g = 0, b = 0, a = 0.7},
				frameColor  = {r = 0, g = 0, b = 0, a = 0.3},
				labelColor  = {r = 1, g = 1, b = 1},
				textColor   = {r = 1, g = 1, b = 1},
				unitColor   = {r = 1, g = 1, b = 1},			

				fontSize    = 12,
				blockScale  = 1,
				blockAlpha  = 1,
				blockLocked = false,
				
				showBorder  = true,
				
				fixedWidth = false,
				blockWidth = 100,
				
				hideInCombat        = false,
				disableTooltip      = false,
				hideTooltipInCombat = false,
				hideOnMouseOut      = false,	
			},
			pluginUseMaster = {
				['*'] = {}
			},
			frameLinks = {			
			},
			enabled = true,
			hideAllOnMouseOut = false,
			ignoreLaunchers = false,
		},
	}
	local defaults = self.defaults
	for setting, value in pairs(defaults.profile.masterSettings) do
		defaults.profile.pluginSettings['*'][setting] = value
		defaults.profile.pluginUseMaster['*'][setting] = true
	end
	
	self.db = LibStub("AceDB-3.0"):New("FortressDB", defaults, "Default")
	db = self.db.profile
	
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	
	self:SetEnabledState(db.enabled)
	self:RegisterOptions()
end

function Fortress:OnEnable()
	for name, obj in broker:DataObjectIterator() do
		self:LibDataBroker_DataObjectCreated(nil, name, obj)
	end
	broker.RegisterCallback(self, "LibDataBroker_DataObjectCreated")
	
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Fortress:OnDisable()
	broker.UnregisterAllCallbacks(self)
	for _, f in pairs(frames) do
		f:Hide()
	end
end

local function ClearFortressRefs(tbl, newTab)
	for frame in pairs(tbl) do
		local name = frame:GetName()
		if name and name:find("Fortress") then
			tbl[frame] = newTab and {} or nil
		end
	end
end

local function ClearLegoData()
	ClearFortressRefs(legos.frameLinks, true)
	ClearFortressRefs(legos.stickiedFrames)
end

function Fortress:Refresh()
	--FT_PROFILE_DEBUG = true
	db = self.db.profile
	self:UpdateOptionsDbRef()	
	Debug("DB refs updated")
	
	ClearLegoData()
	
	--self:LoadFramePositions()
	--self:LoadFrameLinks()
		
	self:UpdateAllObjects()
	Debug("Objects updated")
		
	--FT_PROFILE_DEBUG = nil
end

--------
-- LDB callbacks
--------
function Fortress:LibDataBroker_DataObjectCreated(event, name, obj)
	Debug("Dataobject Registered:", name)
	
	local t = obj.type
	if t == "launcher" and db.ignoreLaunchers then
		return
	end	
	-- support data objects without type set, allthough that's not correct
	if t and (t ~= "data source" and t ~= "launcher") then
		Debug("Unknown type", t, name)
		return
	end
	
	if not dataObjects[name] then
		dataObjects[name] = obj
	end		
	if db.pluginSettings[name].enabled then
		self:EnableDataObject(name)
	end
	self:AddObjectOptions(name)
end

function Fortress:AttributeChanged(event, name, key, value)
	if not db.pluginSettings[name].enabled then return end
	local f = frames[name]
	local obj = dataObjects[name]
	
	local update = updaters[key]
	if update then
		update(f, value, name)
	end
end

local newFrameOffset = -50
function Fortress:EnableDataObject(name)
	local obj = dataObjects[name]
	db.pluginSettings[name].enabled = true
	-- create frame for object
	local frame = frames[name] or legos:New("Fortress"..name, nil, nil, db.blockDB[name])
	frames[name] = frame
	frame.name = name
	frame.obj  = obj
	frame.db   = db.pluginSettings[name]
		
	frame:SetScript("OnClick", Block_OnClick)
	frame:SetScript("OnEnter", Block_OnEnter)
	frame:SetScript("OnLeave", Block_OnLeave)
	frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
		
	-- cascade new frames (very basic way)
	local blockDB = db.blockDB[name]
	if not (blockDB.x or blockDB.stickPoint) then
		blockDB.x, blockDB.y = 0, newFrameOffset
		blockDB.anchor = "TOP"
		
		newFrameOffset = newFrameOffset - 2*frame:GetHeight()
	end

	self:UpdateObject(name, obj)	
	frame:Show()
	
	broker.RegisterCallback(self, "LibDataBroker_AttributeChanged_"..name, "AttributeChanged")
end

function Fortress:DisableDataObject(name)
	db.pluginSettings[name].enabled = false
	broker.UnregisterCallback(self, "LibDataBroker_AttributeChanged_"..name)
	if frames[name] then
		frames[name]:Hide()
	end
end

function Fortress:PLAYER_REGEN_DISABLED()
	for name, frame in pairs(frames) do
		if GetPluginSetting(name, "hideInCombat") then
			frame:Hide()
		end
	end
end

function Fortress:PLAYER_REGEN_ENABLED()
	for _, f in pairs(frames) do
		if f.db.enabled then
			f:Show()
		end
	end
end

function Fortress:HideAllObjects()
	for _, frame in pairs(frames) do
		frame:SetAlpha(0)
	end
end

function Fortress:ShowAllObjects(force)
	for name, frame in pairs(frames) do
		local alpha = force and 1 or GetPluginSetting(name, "blockAlpha")
		frame:SetAlpha(alpha)
	end
end

function Fortress:UpdateAllObjects()
	for name, obj in pairs(dataObjects) do
		if FT_PROFILE_DEBUG then
			Debug("Updating", name)
		end
		self:UpdateObject(name, obj)
	end
end

function Fortress:UpdateObject(name, obj)
	local frame = frames[name]
	if frame then
		obj = obj or dataObjects[name]
		for key, func in pairs(uniqueUpdaters) do
			func(frame, obj[key], name) 
		end	
		
		if not MouseIsOver(frame) and (db.hideAllOnMouseOut or GetPluginSetting(name, "hideOnMouseOut")) then
			frame:SetAlpha(0)
		else
			frame:SetAlpha(GetPluginSetting(name, "blockAlpha"))
		end
		
		db.blockDB[name].locked = GetPluginSetting(name, "blockLocked")

		self:UpdateBorder(name)
		self:UpdateColor(name)
		self:UpdateFontAndSize(name)
	end
end

function Fortress:UpdateColor(name)
	local frame = frames[name]
	local obj   = dataObjects[name]
	local borderColor = GetPluginSetting(name, "borderColor")
	local frameColor = GetPluginSetting(name, "frameColor") 
	
	frame:SetBackdropBorderColor(borderColor.r,borderColor.g,borderColor.b,borderColor.a)
	frame:SetBackdropColor(frameColor.r,frameColor.g,frameColor.b,frameColor.a)
	
	updaters.text(frame, obj.text, name)
end

function Fortress:UpdateFontAndSize(name)
	local frame = frames[name]
	local fontName = frame.text:GetFont()
	local fontSize = GetPluginSetting(name, "fontSize")
	local scale    = GetPluginSetting(name, "blockScale")
	
	frame.text:SetFont(fontName, fontSize)
	frame:SetScale(scale)
	db.blockDB[name].scale = scale -- let LegoBlock use this scale on next login
	
	if GetPluginSetting(name, "fixedWidth") then
		db.blockDB[name].noResize = true
		local w = GetPluginSetting(name, "blockWidth")
		db.blockDB[name].width = w
		frame:SetWidth(w)
	else
		db.blockDB[name].noResize =  false
		db.blockDB[name].width = nil
		frame:SetDB(db.blockDB[name]) -- update the width
	end
end

local	backdropBorder = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 16,
	insets = {left = 5, right = 5, top = 5, bottom = 5},
	tile = true, tileSize = 16,
}
local	backdropNoBorder = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	insets = {left = 0, right = 0, top = 0, bottom = 0},
	tile = true, tileSize = 16,
}

function Fortress:UpdateBorder(name)
	local frame = frames[name]
	
	if GetPluginSetting(name, "showBorder") then
		frame:SetBackdrop(backdropBorder)
		frame.optionsTbl.width = 8
		frame.icon:SetPoint("LEFT", 8, 0)
	else
		frame:SetBackdrop(backdropNoBorder)
		frame.optionsTbl.width = 0
		frame.icon:SetPoint("LEFT", 4, 0)	
	end
end

function Fortress:ToggleLaunchers()
	local ignore = db.ignoreLaunchers
	if ignore then
		for name, obj in pairs(dataObjects) do
			if obj.type == "launcher" then
				self:DisableDataObject(name)
			end
		end
	else
		for name, obj in broker:DataObjectIterator() do
			if obj.type == "launcher" then
				self:LibDataBroker_DataObjectCreated(nil, name, obj)
			end
		end
	end
end
