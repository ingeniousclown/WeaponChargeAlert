------------------------------------------------------------------
--WeaponChargeAlert.lua
--Author: ingeniousclown
--v0.2.3
--[[
A mod that pops up a little alert window when you're low on weapon
charge for your main and off-hand weapons.
]]
------------------------------------------------------------------


local settings = nil
local MAIN_WINDOW = nil

local MAIN_WEAPON = nil
local OFF_WEAPON = nil

-- local FADE_TIMELINE = nil
-- local FADE_ANIMATION = nil
-- local FADE_TIME = 300

local OUTLINE_TEXTURE = "WeaponChargeAlert/assets/gridItem_outline.dds"

local Threshold = {
	NONE = 0,
	HALF = 1,
	LOW = 2,
	EMPTY =3
}

local defaults = {
	offsetX = 0.625,
	offsetY = 0.125,

	halfAlert = false,
	lowAlert = true,
	emptyAlert = true,

	lowThreshold = 0.2,

	iconSize = 64,
	iconSpacing = 10,

	windowPadding = 10,

	locked = true,
}

---------------------------------------------------------------
--CHAIN
---------------------------------------------------------------

local function CHAIN( object )
	-- Setup the metatable
	local T = {}
	setmetatable( T, { __index = function( self, func )
		
		-- Know when to stop chaining
		if func == "__END" then	return object end
		
		-- Otherwise, add the method to the parent object
		return function( self, ... )
			assert( object[func], func .. " missing in object" )
			object[func]( object, ... )
			return self
		end
	end })
	
	-- Return the metatable
	return T
end



---------------------------------------------------------------
--STUFF
---------------------------------------------------------------

local function SetHiddenAll(control, shouldHide)
	control:SetHidden(shouldHide)
	control:GetNamedChild("_Icon"):SetHidden(shouldHide)
	control:GetNamedChild("_Outline"):SetHidden(shouldHide)
end


local function GetChargeThreshold(control)
	local chargeRatio = control.charges / control.maxCharges
	-- d("chargeRatio = " .. chargeRatio)

	if(chargeRatio == 0) then
		return Threshold.EMPTY
	elseif(settings.lowAlert and settings.lowThreshold >= chargeRatio and chargeRatio > 0) then
		return Threshold.LOW
	elseif(settings.halfAlert and 0.5 >= chargeRatio and chargeRatio > settings.lowThreshold) then
		return Threshold.HALF
	else
		return Threshold.NONE
	end
end

local function SetAlert(control, threshold)
	local outline = control:GetNamedChild("_Outline")
	control.shouldShow = false
	if(threshold == Threshold.NONE) then
		outline:SetColor(0, 0, 0, 0)
		SetHiddenAll(control, true)
		return 
	elseif(threshold == Threshold.HALF and settings.halfAlert) then
		outline:SetColor(1, 1, 0, 1)
		SetHiddenAll(control, false)
		control.shouldShow = true
		return
	elseif(threshold == Threshold.LOW and settings.lowAlert) then
		outline:SetColor(1, .784, 0, 1)
		SetHiddenAll(control, false)
		control.shouldShow = true
		return
	elseif(threshold == Threshold.EMPTY) then
		outline:SetColor(1, 0, 0, 1)
		SetHiddenAll(control, false)
		control.shouldShow = true
		return
	end
end

local function UpdateAlert(control)
	if(control and control.chargeable) then
		SetAlert(control, GetChargeThreshold(control))
	else
		control.shouldShow = false
	end
end

local function UpdateAllAlerts()
	UpdateAlert(MAIN_WEAPON)
	UpdateAlert(OFF_WEAPON)

	MAIN_WINDOW:SetHidden((not (MAIN_WEAPON.shouldShow or OFF_WEAPON.shouldShow)) and settings.locked)
end

local function SetWeaponSlot(control, slotId)
	control.chargeable = IsItemChargeable(BAG_WORN, slotId)
	if (not control.chargeable or not slotId) then
		control:SetHidden(true)
		return
	end

	local icon, _, _, _, _, equipType, _, _ = GetItemInfo(BAG_WORN, slotId)
	local texture, weaponTexture = GetSlotTexture(BAG_WORN, slotId)	--what is this?!
	local charges, maxCharges = GetChargeInfoForItem(BAG_WORN, slotId)

	control:GetNamedChild("_Icon"):SetTexture(icon)
	control.charges = charges
	control.maxCharges = maxCharges
	control.slotId = slotId

	UpdateAllAlerts()
end


---------------------------------------------------------------
--BUTTON HANDLER
---------------------------------------------------------------

--call charge with lowest-tier soul gem in inventory... eventually
local function ChargeWeapon(button)
	ZO_Dialogs_ShowDialog("CHARGE_ITEM", {bag = 0, index = button.slotId})
	-- UpdateAllAlerts()
end


---------------------------------------------------------------
--EVENT HANDLERS
---------------------------------------------------------------

--hide in combat (maybe remove the hiding??)
local function CombatStateChanged(eventCode, inCombat)
	if(not inCombat) then
		UpdateAllAlerts()
	end
end

local function WeaponChanged(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
	-- d("slotId = " .. slotId)
	if(bagId ~= BAG_WORN) then return end

	if(slotId == EQUIP_SLOT_MAIN_HAND) then
		SetWeaponSlot(MAIN_WEAPON, slotId)
	-- elseif(slotId == EQUIP_SLOT_RANGED) then
	-- 	SetWeaponSlot(MAIN_WEAPON, slotId)
	elseif(slotId == EQUIP_SLOT_OFF_HAND) then
		SetWeaponSlot(OFF_WEAPON, slotId)
	end
end

local function ToggleLock(locked)
	settings.locked = locked
	MAIN_WINDOW:SetMovable(not locked)
	UpdateAllAlerts()
end

local function OnLoad(eventCode, addOnName)
	if(addOnName ~= "WeaponChargeAlert") then
        return
    end

    settings = ZO_SavedVars:New("WeaponChargeAlert_Settings", 1, nil, defaults)

    local windowSizeX = settings.iconSize * 2 + settings.windowPadding * 2 + settings.iconSpacing
    local windowSizeY = settings.iconSize + settings.windowPadding * 2

    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()

    MAIN_WINDOW = CHAIN(WINDOW_MANAGER:CreateTopLevelWindow("WeaponChargeAlert_Window"))
		:SetDimensions(windowSizeX, windowSizeY)
		:SetAnchor(CENTER, GuiRoot, TOPLEFT, screenWidth * settings.offsetX, screenHeight * settings.offsetY)
		:SetClampedToScreen(true)
		:SetMouseEnabled(true)
		:SetMovable(settings.locked)
		:SetHidden(false)
		:SetHandler("OnMoveStop", function(self)
			local x, y = self:GetCenter()
			settings.offsetX = x / screenWidth
			settings.offsetY = y / screenHeight
		end )
	.__END

	BD = CHAIN(WINDOW_MANAGER:CreateControl("Backdrop", MAIN_WINDOW, CT_TEXTURE))
		:SetDimensions(windowSizeX * 1.5, windowSizeY * 1.7)
		:SetAnchor(CENTER, MAIN_WINDOW, CENTER, 22, 7)
		:SetTexture([[/esoui/art/ava/ava_seigecontrols_bg.dds]])
	.__END

	MAIN_WEAPON = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Main_Weapon", MAIN_WINDOW, CT_BUTTON))
		:SetDimensions(settings.iconSize, settings.iconSize)
		:SetAnchor(TOPLEFT, MAIN_WINDOW, TOPLEFT, settings.windowPadding, settings.windowPadding)
		:SetHandler("OnClicked", ChargeWeapon)
		:SetHidden(true)
		:SetMovable(not settings.locked)
	.__END

	local MAIN_OUTLINE = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Main_Weapon_Outline", MAIN_WEAPON, CT_TEXTURE))
		:SetAnchor(TOPLEFT, MAIN_WEAPON, TOPLEFT)
		:SetAnchorFill(MAIN_WEAPON)
		:SetTexture(OUTLINE_TEXTURE)
		:SetHidden(true)
	.__END

	local MAIN_ICON = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Main_Weapon_Icon", MAIN_WEAPON, CT_TEXTURE))
		:SetAnchor(TOPLEFT, MAIN_WEAPON, TOPLEFT)
		:SetAnchorFill(MAIN_WEAPON)
		:SetTexture([[/esoui/art/lorelibrary/lorelibrary_unreadbook_highlight.dds]])
		:SetColor(1, 1, 1, 1)
		:SetHidden(true)
	.__END

	OFF_WEAPON = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Off_Weapon", MAIN_WINDOW, CT_BUTTON))
		:SetDimensions(settings.iconSize, settings.iconSize)
		:SetAnchor(TOPLEFT, MAIN_WINDOW, TOPLEFT, settings.windowPadding + settings.iconSize + settings.iconSpacing, settings.windowPadding)
		:SetHandler("OnClicked", ChargeWeapon)
		:SetHidden(true)
	.__END

	local OFF_OUTLINE = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Off_Weapon_Outline", OFF_WEAPON, CT_TEXTURE))
		:SetAnchor(TOPLEFT, OFF_WEAPON, TOPLEFT)
		:SetAnchorFill(OFF_WEAPON)
		:SetTexture(OUTLINE_TEXTURE)
		:SetHidden(true)
	.__END

	local OFF_ICON = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Off_Weapon_Icon", OFF_WEAPON, CT_TEXTURE))
		:SetAnchor(TOPLEFT, OFF_WEAPON, TOPLEFT)
		:SetAnchorFill(OFF_WEAPON)
		:SetTexture([[/esoui/art/lorelibrary/lorelibrary_unreadbook_highlight.dds]])
		:SetColor(1, 1, 1, 1)
		:SetHidden(true)
	.__END

	MAIN_WEAPON.shouldShow = false
	OFF_WEAPON.shouldShow = false

	SetWeaponSlot(MAIN_WEAPON, EQUIP_SLOT_MAIN_HAND)
	SetWeaponSlot(OFF_WEAPON, EQUIP_SLOT_OFF_HAND)

	-- FADE_ANIMATION, FADE_TIMELINE = CreateSimpleAnimation(ANIMATION_ALPHA, MAIN_WINDOW)
	UpdateAllAlerts()

	--i'm assuming this works the way i think it does
	SLASH_COMMANDS["/weaponchargealert"] = function(arg)
		local mainArg = arg
		if(zo_strlower(mainArg) == "lock") then
			ToggleLock(true)
			d("locked")
		elseif(zo_strlower(mainArg) == "unlock") then
			ToggleLock(false)
			d("unlocked")
		end
	end
	SLASH_COMMANDS["/wca"] = SLASH_COMMANDS["/weaponchargealert"]
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_WpnSlotChanged", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WeaponChanged)
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_CombatStateChanged", EVENT_PLAYER_COMBAT_STATE, CombatStateChanged)
end

local function WeaponChargeAlert_Initialized(self)
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_OnLoad", EVENT_ADD_ON_LOADED, OnLoad)
end

-- EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_Initialized", EVENT_ADD_ON_INITIALIZED, WeaponChargeAlert_Initialized)
WeaponChargeAlert_Initialized()

-- function UnhideAllDur()
-- 	SetHiddenAll(MAIN_WEAPON, false)
-- 	SetHiddenAll(OFF_WEAPON, false)
-- end