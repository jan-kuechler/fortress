--[[ @file-author@ @file-date-iso@ @file-abbreviated-hash@ ]]--
local LibStub = LibStub
local Fortress = LibStub("AceAddon-3.0"):NewAddon("Fortress", "AceConsole-3.0", "AceEvent-3.0")

local broker = LibStub("LibDataBroker-1.1")
local legos  = LibStub("LegoBlock-Beta1")
local media  = LibStub("LibSharedMedia-3.0")

local db

local frames      = {}
local dataObjects = {}
local strTable    = {}
local backdrops   = {}
local insets      = {}

--------
-- utility functions
--------
local function Debug(...)
--	ChatFrame1:AddMessage(strjoin(" ", "Fortess Debug:", tostringall(...)), 0, 1, 0)
end
Fortress.Debug = Debug

local function GetPluginSetting(pluginName, setting)
	if db.pluginUseMaster[pluginName][setting] then
		return db.masterSettings[setting]
	else
		return db.pluginSettings[pluginName][setting]
	end
end
Fortress.GetPluginSetting = GetPluginSetting

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

local function ShowBlocks(block, name)
	if db.hideAllOnMouseOut then
		Fortress:ShowAllObjects()
	elseif db.showLinked then
		Fortress:ShowLinked(block)
	else
		block:SetAlpha(GetPluginSetting(name, "blockAlpha"))
	end
end

local function HideBlocks(block, name)
	if db.hideAllOnMouseOut then
		Fortress:HideAllObjects()
	elseif db.showLinked then
		Fortress:HideLinked(block)
	elseif GetPluginSetting(name, "hideOnMouseOut") then
		block:SetAlpha(0)
	end
end

local SetNewBlockPosition
do
	local newFrameOffset = -50
	
	function SetNewBlockPosition(frame, db)
		db.x, db.y = 0, newFrameOffset
		db.anchor  = "TOP"
		
		newFrameOffset = newFrameOffset - 2*frame:GetHeight()	
	end
end

--------
-- LegoBlock hacks )-:
--------
local function ClearFortressRefs(tbl, newTab)
	for frame in pairs(tbl) do
		local name = frame:GetName()
		if name and name:find("Fortress") then
			tbl[frame] = newTab and {} or nil
		end
	end
end

-- used in Fortress:Refresh()
local function ClearLegoData()
	ClearFortressRefs(legos.frameLinks, true)
	ClearFortressRefs(legos.stickiedFrames)
end

local function BlockIsLinked(block, other)
	local head1, head2 = block.headLB, other.headLB
	
	if not head1 and not head2 then
		return false
	elseif head1 == head2 then
		return true
	elseif head1 == other then
		return true
	elseif head2 == block then
		return true
	else
		return false
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
		
	ShowBlocks(self, name)
	
	if GetPluginSetting(name, "disableTooltip") then
		return
	end
			
	if (not InCombatLockdown()) or (not GetPluginSetting(name, "hideTooltipInCombat")) then	
		if obj.tooltip then
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
			Debug("Deprecated .tooltiptext found")
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
	
	if GetPluginSetting(name, "hideTooltipOnClick") then
		if obj.OnLeave then
			obj.OnLeave(self)
		elseif obj.tooltiptext or obj.OnTooltipShow then
			GT_OnLeave(GameTooltip)
		elseif obj.tooltip then
			obj.tooltip:Hide()
		end
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
	
	-- Support texcoord, though it's not in the spec yet.
	texcoord = function(frame, value, name)
		local object = dataObjects[name]
		if object.texcoord then
			frame.icon:SetTexCoord(unpack(object.texcoord))
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
				blockHeight = 24,
				blockAlpha  = 1,
				blockLocked = false,
				
				fixedWidth = false,
				blockWidth = 100,
				
				hideInCombat        = false,
				disableTooltip      = false,
				hideTooltipInCombat = false,
				hideOnMouseOut      = false,	
				
				hideTooltipOnClick = false,
				
				font       = "Friz Quadrata TT",
				background = "Blizzard Tooltip",
				border     = "Blizzard Tooltip",
				
				bgTiled    = true,
				bgTileSize = 16,
				edgeSize   = 16,
				insets     =  5,
			},
			pluginUseMaster = {
				['*'] = {}
			},
			enabled = true,
			hideAllOnMouseOut = false,
			ignoreLaunchers = false,
			showLinked = false,
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

function Fortress:Refresh()
	db = self.db.profile
	self:UpdateOptionsDbRef()	
	Debug("DB refs updated")
	
	ClearLegoData()
			
	self:UpdateAllObjects()
	Debug("Objects updated")
end

--------
-- LDB callbacks
--------
function Fortress:LibDataBroker_DataObjectCreated(event, name, obj)
	Debug("Dataobject Registered:", name)
	
	local t = obj.type
	if t == nil then
		print("Fortress: The data object", name, "has no type attribute set. Please report this to the author of the plugin.")
	end
	-- support data objects without type set, allthough that's not correct
	if t and (t ~= "data source" and t ~= "launcher") then
		return
	end

	self:CreateDataObject(name, obj)
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

--------
-- Event handling
--------
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

--------
-- Object handling 
--------
function Fortress:CreateDataObject(name, obj)
	if dataObjects[name] then return end
	
	dataObjects[name] = obj
	self:AddObjectOptions(name)
	if db.pluginSettings[name].enabled then
		self:EnableDataObject(name)
	end
end

function Fortress:EnableDataObject(name)
	local obj = dataObjects[name]
	if obj.type == "launcher" and db.ignoreLaunchers then
		return
	end
	
	db.pluginSettings[name].enabled = true
	
	if obj.secureTemplates then
		db.blockDB[name].appendString = obj.secureTemplate
	end
	
	-- create frame for object
	local frame  = frames[name] or legos:New("Fortress"..name, nil, nil, db.blockDB[name])
	frames[name] = frame
	frame.name = name
	frame.obj  = obj
	frame.db   = db.pluginSettings[name]
		
	frame:SetScript("OnClick", Block_OnClick)
	frame:SetScript("OnEnter", Block_OnEnter)
	frame:SetScript("OnLeave", Block_OnLeave)
	frame:RegisterForClicks("AnyUp")
		
	-- cascade new frames (very basic way)
	local blockDB = db.blockDB[name]
	if not (blockDB.x or blockDB.stickPoint) then
		SetNewBlockPosition(frame, blockDB)
	end

	self:UpdateObject(name, obj)	
	frame:Show()
	
	broker.RegisterCallback(self, "LibDataBroker_AttributeChanged_"..name, "AttributeChanged")
	
	if obj.OnCreate then
		obj.OnCreate(obj, frame)
	end
end

function Fortress:DisableDataObject(name)
	db.pluginSettings[name].enabled = false
	broker.UnregisterCallback(self, "LibDataBroker_AttributeChanged_"..name)
	if frames[name] then
		frames[name]:Hide()
	end
end

--------
-- Show/Hide
--------
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

local linkedBlocks = {}
function Fortress:ShowLinked(block, force)
	local i = 1
	for name, frame in pairs(frames) do
		if frame == block or BlockIsLinked(block, frame) then
			local alpha = force and 1 or GetPluginSetting(name, "blockAlpha")
			frame:SetAlpha(alpha)
			linkedBlocks[i] = frame
			i = i + 1
		end
	end
	local num = #linkedBlocks
	while i <= num do
		linkedBlocks[i] = nil
		i = i + 1
	end
end

function Fortress:HideLinked(block)
	if #linkedBlocks then
		for i, frame in ipairs(linkedBlocks) do
			frame:SetAlpha(0)
			linkedBlocks[i] = nil
		end
	else
		for name, frame in pairs(frames) do
			if frame == block or BlockIsLinked(block, frame) then
				frame:SetAlpha(0)
			end		
		end
	end
end

--------
-- Update
--------
function Fortress:UpdateAllObjects()
	for name, obj in pairs(dataObjects) do
		self:UpdateObject(name, obj)
	end
end

function Fortress:UpdateObject(name, obj)
	if not db.pluginSettings[name].enabled then return end
	local frame = frames[name]
	if frame then
		obj = obj or dataObjects[name]
		for key, func in pairs(uniqueUpdaters) do
			func(frame, obj[key], name) 
		end	
		
		if not MouseIsOver(frame) and (db.hideAllOnMouseOut or db.showLinked or GetPluginSetting(name, "hideOnMouseOut")) then
			frame:SetAlpha(0)
		else
			frame:SetAlpha(GetPluginSetting(name, "blockAlpha"))
		end
		
		db.blockDB[name].locked = GetPluginSetting(name, "blockLocked")

		self:UpdateBackdrop(name)
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
	local fontName = GetPluginSetting(name, "font")
	local fontSize = GetPluginSetting(name, "fontSize")
	local scale    = GetPluginSetting(name, "blockScale")
	local height   = GetPluginSetting(name, "blockHeight")
	
	local font = media:Fetch(media.MediaType.FONT, fontName)
	
	frame.text:SetFont(font, fontSize)
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
	
	frame:SetHeight(height)
	frame.optionsTbl.height = height
end

local insets_default = {left = 0, right = 0, top = 0, bottom = 0}

function Fortress:UpdateBackdrop(name)
	local frame = frames[name]
	local backdrop = backdrops[name]
	
	if not backdrop then
		backdrops[name] = {}
		backdrop = backdrops[name]
	end
	
	local background = GetPluginSetting(name, "background")
	local border     = GetPluginSetting(name, "border")
		
	backdrop.bgFile   = media:Fetch(media.MediaType.BACKGROUND, background)
	backdrop.tile     = GetPluginSetting(name, "bgTiled")
	backdrop.tileSize = GetPluginSetting(name, "bgTileSize")
	
	if border == "None" then
		backdrop.insets   = insets_default
		backdrop.edgeFile = nil
		backdrop.edgeSize = nil
		
		frame.icon:SetPoint("LEFT", 4, 0)
		frame.optionsTbl.width = 0
	else
		local insetSize = GetPluginSetting(name, "insets")
		local i = insets[insetSize]
		
		if not i then
			i = {left = insetSize, right = insetSize, top = insetSize, bottom = insetSize}
			insets[insetSize] = i
		end
		
		backdrop.insets   = i
		backdrop.edgeFile = media:Fetch(media.MediaType.BORDER, border)
		backdrop.edgeSize = GetPluginSetting(name, "edgeSize")
		
		frame.optionsTbl.width = 8
		frame.icon:SetPoint("LEFT", 8, 0)
	end
	
	frame:SetBackdrop(backdrop)
end

function Fortress:IsLauncher(name)
	return dataObjects[name] and dataObjects[name].type == "launcher"
end

function Fortress:ToggleLaunchers()	
	local func = db.ignoreLaunchers and self.DisableDataObject or self.EnableDataObject
	for name, obj in pairs(dataObjects) do
		if obj.type == "launcher" then
			func(self, name)
		end
	end
end
