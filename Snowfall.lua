-- Speedy Actions
-- 	author: Shadowed
local KeyDown = CreateFrame("Frame")
local buttonCache, cachedBindingButton, bindingsLoaded = {}, {}
local overriddenButtons = {}
local keyList = {}
local CREATED_BUTTONS = 0
local animationsCount, animations = 1, {}
local animationNum = 1
local frame, texture, animationGroup, alpha1, scale1, scale2, rotation2
local select, pairs, tonumber = select, pairs, tonumber
local hooksecurefunc = hooksecurefunc

for i = 1, animationsCount do
	frame = CreateFrame("Frame")

	texture = frame:CreateTexture()
	texture:SetTexture([[Interface\Cooldown\star4]])
	texture:SetAlpha(0)
	texture:SetAllPoints()
	texture:SetBlendMode("ADD")
	animationGroup = texture:CreateAnimationGroup()

	alpha1 = animationGroup:CreateAnimation("Alpha")
	alpha1:SetChange(1);
	alpha1:SetDuration(0);
	alpha1:SetOrder(1);

	scale1 = animationGroup:CreateAnimation("Scale")
	scale1:SetScale(1.0, 1.0)
	scale1:SetDuration(0)
	scale1:SetOrder(1)

	scale2 = animationGroup:CreateAnimation("Scale")
	scale2:SetScale(1.5, 1.5)
	scale2:SetDuration(0.2)
	scale2:SetOrder(2)

	rotation2 = animationGroup:CreateAnimation("Rotation")
	rotation2:SetDegrees(90)
	rotation2:SetDuration(0.2)
	rotation2:SetOrder(2)

	animations[i] = {frame = frame, animationGroup = animationGroup}
end

local animate = function(button)
	if not button:IsVisible() then
		return true
	end
	local animation = animations[animationNum]
	local frame = animation.frame
	local animationGroup = animation.animationGroup
	frame:SetFrameStrata(button:GetFrameStrata()) -- caused multiactionbars to show animation behind the bar instead of on top of it
	frame:SetFrameLevel(button:GetFrameLevel() + 10)
	frame:SetAllPoints(button)
	
	animationGroup:Stop()
	animationGroup:Play()
	animationNum = (animationNum % animationsCount) + 1
	
	return true
end

KeyDown:RegisterEvent("UPDATE_BINDINGS")

local function releaseButtons()
	for _, button in pairs(buttonCache) do
		if( button.active ) then
			button:SetAttribute("type", button.setKey)
			button:SetAttribute(button.setKey, nil)
			button.active = nil
			button.setKey = nil
		end
	end
end

local function setButtonsMouseDown(format)
	local id = 1
	while( true ) do
		local button = _G[format .. id]
		if( not button ) then return end

		button:RegisterForClicks("AnyDown")
		overriddenButtons[button] = true
		id = id + 1

		-- Find anything that binds directly to a Blizzard button, such as Dominos does
		KeyDown:RegisterOverrideKey(GetBindingKey(string.format("CLICK %s%d:LeftButton", format, id)))
		button.AnimateThis = animate
		SecureHandlerWrapScript(button, "OnClick", button, [[ control:CallMethod("AnimateThis", self) ]])
	end
end

function KeyDown:ForceDefaultClick()
	setButtonsMouseDown("MultiBarLeftButton")
	setButtonsMouseDown("MultiBarRightButton")
	setButtonsMouseDown("MultiBarBottomRightButton")
	setButtonsMouseDown("MultiBarBottomLeftButton")
	setButtonsMouseDown("MultiCastActionButton")
	setButtonsMouseDown("ShapeshiftButton")
	setButtonsMouseDown("PetActionButton")
	setButtonsMouseDown("BonusActionButton")
	setButtonsMouseDown("ActionButton")
	setButtonsMouseDown("VehicleMenuBarActionButton")

	MultiCastSummonSpellButton:RegisterForClicks("AnyDown")
	overriddenButtons[MultiCastSummonSpellButton] = true
	MultiCastRecallSpellButton:RegisterForClicks("AnyDown")
	overriddenButtons[MultiCastRecallSpellButton] = true
end

function KeyDown:RebindButton(button, key, mouseButton)
	-- The key is blacklisted, it should have the speedy portion disabled and not bound
	if( type(button) ~= "table" or not button.IsProtected or not button:IsProtected() ) then return end
	button:RegisterForClicks("AnyDown")
	overriddenButtons[button] = true

	SetOverrideBindingClick(KeyDown, true, key, button:GetName(), mouseButton)
end

function KeyDown:UpdateKeys(self)
	if InCombatLockdown() then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	if not bindingsLoaded then
		bindingsLoaded = true
		KeyDown:ForceDefaultClick()
	end

	-- Release everything we already had bound
	ClearOverrideBindings(self)
	releaseButtons()

	-- This adds support for bindings set to Blizzards default stuff, anything else is not supported and requires a support module
	for i=1, GetNumBindings() do
		local action, bindingOne, bindingTwo = GetBinding(i)
		if( bindingOne ) then keyList[bindingOne] = true end
		if( bindingTwo ) then keyList[bindingTwo] = true end
	end

	-- Scan through all keys that were found using an action and override them
	for key in pairs(keyList) do
		self:OverrideKeybind(key, GetBindingAction(key, true))
	end
end

KeyDown:SetScript("OnEvent", function(self, event, ...)
	if event == "UPDATE_BINDINGS" then
		KeyDown:UpdateKeys(self)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		KeyDown:UpdateKeys(self)
	end
end)

local cachedBindingButton = {}
-- Retrieves a button out of the cache
local function retrieveButton(attributeKey, attributeValue)
	local button
		for _, cacheButton in pairs(buttonCache) do
			if( not cacheButton.active ) then
				button = cacheButton
			break
		end
	end

	if( not button ) then
		CREATED_BUTTONS = CREATED_BUTTONS + 1
		button = CreateFrame("Button", "KeyDownButton" .. CREATED_BUTTONS, nil, "SecureActionButtonTemplate")
		table.insert(buttonCache, button)
	end

	button.active = true
	button.setKey = attributeKey
	button:SetAttribute("type", attributeKey)
	button:SetAttribute(attributeKey, attributeValue)

	return button
end

function KeyDown:OverrideKeybind(key, action)
	if( not action or action == "" ) then return end

	-- SetBindingClick, BUTTON# pretty commonly seems to be used by fishing addons along with CLICK actions so simply block any buttons from click actions from being sped up
	local buttonName, mouseButton = string.match(action, "^CLICK (.+):(.+)")
	if( buttonName ) then
		local button = _G[buttonName]
		if( not string.match(key, "^BUTTON(%d+)") and button and ( cachedBindingButton[buttonName] or button:GetAttribute("type") and button:GetAttribute("type") ~= "click" ) ) then
			self:RebindButton(button, key, mouseButton)
		end
		return
	end

	-- SetBindingSpell
	local spell = string.match(action, "^SPELL (.+)")
	if( spell ) then
		self:RebindButton(retrieveButton("spell", spell), key)
		return
	end

	-- SetBindingItem
	local item = string.match(action, "^ITEM (.+)")
	if( item ) then
		self:RebindButton(retrieveButton("item", item), key)
		return
	end

	-- SetBindingMacro
	local macro = string.match(action, "^MACRO (.+)")
	if( macro ) then
		self:RebindButton(retrieveButton("macro", macro), key)
		return
	end

	-- SetBinding, but it's a multicast so it needs special handling
	local multiID = string.match(action, "MULTICASTSUMMONBUTTON(%d+)")
	if( multiID ) then
		self:RebindButton(retrieveButton("spell", TOTEM_MULTI_CAST_SUMMON_SPELLS[tonumber(multiID)]), key)
		return
	end

	-- SetBinding, for a totem recall
	local recallID = string.match(action, "MULTICASTRECALLBUTTON(%d+)")
	if( recallID ) then
		self:RebindButton(retrieveButton("spell", TOTEM_MULTI_CAST_RECALL_SPELLS[tonumber(recallID)]), key)
		return
	end

	-- SetBinding, the action buttons 1 - 12 need special handling, because they can also be vehicle buttons or stance buttons
	local actionID = string.match(action, "^ActionButton(%d+)")
	if( actionID ) then
		actionID = tonumber(actionID)
		local button = _G["KeyDownBarButton" .. actionID]
		if( not button ) then
			button = CreateFrame("Button", "KeyDownBarButton" .. actionID, nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
			button.actionButton = _G["ActionButton" .. actionID]
			button.bonusButton = _G["BonusActionButton" .. actionID]
			button.vehicleButton = _G["VehicleMenuBarActionButton" .. actionID]
			button.actionID = actionID
			button:SetAttribute("type", "macro")
			button:SetFrameRef("bonusFrame", BonusActionBarFrame)
			button:SetFrameRef("vehicleFrame", VehicleMenuBar)
			button:SetScript("OnMouseDown", fakeActionDown)
			button:SetScript("OnMouseUp", fakeActionUp)

			-- Fun little restriction, when in combat IsProtected() returns nil, nil for vehicle/bonus frames
			-- unless they are actively being used by something, such as the default UI. IsProtected() check will stop any error
			if( button.vehicleButton ) then
				button:WrapScript(button, "OnClick", string.format([[
					if( self:GetFrameRef("vehicleFrame"):IsProtected() and self:GetFrameRef("vehicleFrame"):IsVisible() ) then
						self:SetAttribute("macrotext", "/click VehicleMenuBarActionButton%d")
					elseif( self:GetFrameRef("bonusFrame"):IsProtected() and self:GetFrameRef("bonusFrame"):IsVisible() ) then
						self:SetAttribute("macrotext", "/click BonusActionButton%d")
					else
						self:SetAttribute("macrotext", "/click ActionButton%d")
					end
				]], actionID, actionID, actionID))
			else
				button:WrapScript(button, "OnClick", string.format([[
					if( self:GetFrameRef("bonusFrame"):IsProtected() and self:GetFrameRef("bonusFrame"):IsVisible() ) then
						self:SetAttribute("macrotext", "/click BonusActionButton%d")
					else
						self:SetAttribute("macrotext", "/click ActionButton%d")
					end
				]], actionID, actionID))
			end
		end

		-- Annnnd bind us off	
		self:RebindButton(button, key)
		return
	end

	-- None of those, it should be a default Blizzard one then, because Blizzard does not use the same casing
	-- as the frames name, the mass gsub to turn it into the buttons real name is necessary
	-- it's cached so it doesn't have to do this every time at least 
	local buttonName = cachedBindingButton[action]
	if( not buttonName ) then
		buttonName = string.gsub(action, "MULTIACTIONBAR4BUTTON", "MultiBarLeftButton")
		buttonName = string.gsub(buttonName, "MULTIACTIONBAR3BUTTON", "MultiBarRightButton")
		buttonName = string.gsub(buttonName, "MULTIACTIONBAR2BUTTON", "MultiBarBottomRightButton")
		buttonName = string.gsub(buttonName, "MULTIACTIONBAR1BUTTON", "MultiBarBottomLeftButton")
		buttonName = string.gsub(buttonName, "MULTICASTACTIONBUTTON", "MultiCastActionButton")
		buttonName = string.gsub(buttonName, "SHAPESHIFTBUTTON", "ShapeshiftButton")
		buttonName = string.gsub(buttonName, "BONUSACTIONBUTTON", "PetActionButton")
		buttonName = string.gsub(buttonName, "ACTIONBUTTON", "ActionButton")

		cachedBindingButton[action] = buttonName
	end
	self:RebindButton(_G[buttonName], key)
end

function KeyDown:RegisterOverrideKey(...)
	for i=1, select("#", ...) do
		local key = select(i, ...)
		if( not keyList[key] ) then self.foundNewKey = true end
		keyList[key] = true
	end
end

local function overrideBinding(owner, isPriority, key)
	if( not InCombatLockdown() and owner ~= KeyDown ) then
		SetOverrideBinding(KeyDown, nil, key) 
		KeyDown:OverrideKeybind(key, GetBindingAction(key, true))
		KeyDown:RegisterOverrideKey(key)
	end
end

local function normalBinding(key)
	if( not InCombatLockdown() ) then
		SetOverrideBinding(KeyDown, nil, key) 
		KeyDown:OverrideKeybind(key, GetBindingAction(key, true))
		KeyDown:RegisterOverrideKey(key)
	end
end

hooksecurefunc("SetBindingClick", normalBinding)
hooksecurefunc("SetBindingItem", normalBinding)
hooksecurefunc("SetBindingMacro", normalBinding)
hooksecurefunc("SetBindingSpell", normalBinding)
hooksecurefunc("SetOverrideBindingSpell", overrideBinding)
hooksecurefunc("SetOverrideBindingMacro", overrideBinding)
hooksecurefunc("SetOverrideBindingItem", overrideBinding)
hooksecurefunc("SetOverrideBindingClick", overrideBinding)
hooksecurefunc("SetOverrideBinding", overrideBinding)
