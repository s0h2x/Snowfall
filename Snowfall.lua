-- Snowfall Keypress for WoW 3.3.5
local animationsCount, animations = 5, {}
local animationNum = 1
local replace = string.gsub
local frame, texture, animationGroup, alpha1, scale1, scale2, rotation2

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
	scale2:SetDuration(0.3)
	scale2:SetOrder(2)

	rotation2 = animationGroup:CreateAnimation("Rotation")
	rotation2:SetDegrees(90)
	rotation2:SetDuration(0.3)
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
	frame:SetFrameStrata("HIGH")
	--frame:SetFrameStrata(button:GetFrameStrata()) -- caused multiactionbars to show animation behind the bar instead of on top of it
	frame:SetFrameLevel(button:GetFrameLevel() + 10)
	frame:SetAllPoints(button)
	animationGroup:Stop()
	animationGroup:Play()
	animationNum = (animationNum % animationsCount) + 1
	return true
end

-- 'ActionButton_UpdateHotkeys' didn't run on PLAYER_ENTERING_WORLD, replaced with 'ActionButton_Update'
hooksecurefunc('ActionButton_Update', function(button, buttonType)
	if InCombatLockdown() then return end -- no button flash while in CC, can be commented out, and animations will run while in CC
	if not button.hooked then
		local id, actionButtonType, key
		if not actionButtonType then
			-- button:GetAttribute('binding') is always nil, it's a waste to run, so it's short-circuited (start working in coming patches)
			actionButtonType =  string.upper(button:GetName()) or button:GetAttribute('binding')

			actionButtonType = replace(actionButtonType, 'BOTTOMLEFT', '1')
			actionButtonType = replace(actionButtonType, 'BOTTOMRIGHT', '2')
			actionButtonType = replace(actionButtonType, 'RIGHT', '3')
			actionButtonType = replace(actionButtonType, 'LEFT', '4')
			actionButtonType = replace(actionButtonType, 'MULTIBAR', 'MULTIACTIONBAR')
		end
		local key = GetBindingKey(actionButtonType)
		if key then
			button:RegisterForClicks("AnyDown")
			SetOverrideBinding(button, true, key, 'CLICK '..button:GetName()..':LeftButton')
		end
		button.AnimateThis = animate
		SecureHandlerWrapScript(button, "OnClick", button, [[ control:CallMethod("AnimateThis", self) ]])
		button.hooked = true	
	end
end)