------------------------------------------------------------------
--WeaponChargeAlert.lua
--Author: ingeniousclown
--v1.1.0
--[[
A mod that pops up a little alert window when you're low on weapon
charge for your main and off-hand weapons.
]]
------------------------------------------------------------------


WCASettings = nil
local MAIN_WINDOW = nil

local MAIN_WEAPON = nil
local OFF_WEAPON = nil

local OUTLINE_TEXTURE = "WeaponChargeAlert/assets/gridItem_outline.dds"

local Threshold = {
	NONE = 0,
	HALF = 1,
	LOW = 2,
	EMPTY =3
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

	if(chargeRatio == 0) then
		return Threshold.EMPTY
	elseif(WCASettings:IsLowAlert() and WCASettings:GetLowThreshold() >= chargeRatio) then
		return Threshold.LOW
	elseif(WCASettings:IsFirstAlert() and WCASettings:GetFirstThreshold() >= chargeRatio) then
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
	elseif(threshold == Threshold.HALF and WCASettings:IsFirstAlert()) then
		outline:SetColor(WCASettings:GetFirstColor())
		SetHiddenAll(control, false)
		control.shouldShow = true
		return
	elseif(threshold == Threshold.LOW and WCASettings:IsLowAlert()) then
		outline:SetColor(WCASettings:GetLowColor())
		SetHiddenAll(control, false)
		control.shouldShow = true
		return
	elseif(threshold == Threshold.EMPTY and WCASettings:IsEmptyAlert()) then
		outline:SetColor(WCASettings:GetEmptyColor())
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

	MAIN_WINDOW:SetHidden((not (MAIN_WEAPON.shouldShow or OFF_WEAPON.shouldShow)) and WCASettings:IsLocked())
end

function WeaponChargeAlert_UpdateAllAlerts()
	UpdateAllAlerts()
end

local function SetWeaponSlot(control, slotId)
	control.chargeable = IsItemChargeable(BAG_WORN, slotId)
	if (not control.chargeable or not slotId) then
		control:SetHidden(true)
		return
	end

	local icon, _, _, _, _, equipType, _, _ = GetItemInfo(BAG_WORN, slotId)
	local charges, maxCharges = GetChargeInfoForItem(BAG_WORN, slotId)

	control:GetNamedChild("_Icon"):SetTexture(icon)
	control.charges = charges
	control.maxCharges = maxCharges
	control.slotId = slotId

	UpdateAllAlerts()
end

local function ApplyWeaponSet(activeWeaponPair)
	if(activeWeaponPair == 1) then
		SetWeaponSlot(MAIN_WEAPON, EQUIP_SLOT_MAIN_HAND)
		SetWeaponSlot(OFF_WEAPON, EQUIP_SLOT_OFF_HAND)
	else
		SetWeaponSlot(MAIN_WEAPON, EQUIP_SLOT_BACKUP_MAIN)
		SetWeaponSlot(OFF_WEAPON, EQUIP_SLOT_BACKUP_OFF)
	end
end


---------------------------------------------------------------
--BUTTON HANDLER
---------------------------------------------------------------

local function ChargeWeapon(button)
	ZO_Dialogs_ShowDialog("CHARGE_ITEM", {bag = 0, index = button.slotId})
end


---------------------------------------------------------------
--EVENT HANDLERS
---------------------------------------------------------------

local function CombatStateChanged(eventCode, inCombat)
	if(not inCombat) then
		UpdateAllAlerts()
	end
end

local function WeaponSetChanged(eventCode, activeWeaponPair, locked)
	ApplyWeaponSet(activeWeaponPair)
end

local function WeaponChanged(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
	if(bagId ~= BAG_WORN) then return end

	if(GetActiveWeaponPairInfo() == 1) then
		if(slotId == EQUIP_SLOT_MAIN_HAND) then
			SetWeaponSlot(MAIN_WEAPON, slotId)
		elseif(slotId == EQUIP_SLOT_OFF_HAND) then
			SetWeaponSlot(OFF_WEAPON, slotId)
		end
	else
		if(slotId == EQUIP_SLOT_BACKUP_MAIN) then
			SetWeaponSlot(MAIN_WEAPON, slotId)
		elseif(slotId == EQUIP_SLOT_BACKUP_OFF) then
			SetWeaponSlot(OFF_WEAPON, slotId)
		end
	end
end

local function ToggleLock(locked)
	WCASettings:SetLocked(locked)
end

local function OnLoad(eventCode, addOnName)
	if(addOnName ~= "WeaponChargeAlert") then
        return
    end

    WCASettings = WeaponChargeAlertSettings:New()

	local iconSize = 64
	local iconSpacing = 10

	local windowPadding = 10

    local windowSizeX = iconSize * 2 + windowPadding * 2 + iconSpacing
    local windowSizeY = iconSize + windowPadding * 2

    MAIN_WINDOW = CHAIN(WINDOW_MANAGER:CreateTopLevelWindow("WeaponChargeAlert_Window"))
		:SetDimensions(windowSizeX, windowSizeY)
		:SetAnchor(CENTER, GuiRoot, TOPLEFT, WCASettings.GetOffsetX(), WCASettings:GetOffsetY())
		:SetClampedToScreen(true)
		:SetMouseEnabled(true)
		:SetMovable(WCASettings:IsLocked())
		:SetHidden(false)
		:SetAlpha(WCASettings:GetAlpha())
		:SetScale(WCASettings:GetScale())
		:SetHandler("OnMoveStop", function(self)
			local x, y = self:GetCenter()
			WCASettings:SetOffsetX(x)
			WCASettings:SetOffsetY(y)
		end )
	.__END

	WCASettings:SetMainWindow(MAIN_WINDOW)

	BD = CHAIN(WINDOW_MANAGER:CreateControl("Backdrop", MAIN_WINDOW, CT_TEXTURE))
		:SetDimensions(windowSizeX * 1.5, windowSizeY * 1.7)
		:SetAnchor(CENTER, MAIN_WINDOW, CENTER, 22, 7)
		:SetTexture([[/esoui/art/ava/ava_seigecontrols_bg.dds]])
	.__END

	MAIN_WEAPON = CHAIN(WINDOW_MANAGER:CreateControl("WeaponChargeAlert_Main_Weapon", MAIN_WINDOW, CT_BUTTON))
		:SetDimensions(iconSize, iconSize)
		:SetAnchor(TOPLEFT, MAIN_WINDOW, TOPLEFT, windowPadding, windowPadding)
		:SetHandler("OnClicked", ChargeWeapon)
		:SetHidden(true)
		:SetMovable(not WCASettings:IsLocked())
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
		:SetDimensions(iconSize, iconSize)
		:SetAnchor(TOPLEFT, MAIN_WINDOW, TOPLEFT, windowPadding + iconSize + iconSpacing, windowPadding)
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

	ApplyWeaponSet(GetActiveWeaponPairInfo())

	UpdateAllAlerts()
	ToggleLock(WCASettings:IsLocked())

	SLASH_COMMANDS["/weaponchargealert"] = function(input)
		local args = { string.match(input, "^(%S*)%s*(.-)$") }
		if(args[1] == "lock") then
			ToggleLock(true)
			d("locked")
		elseif(args[1] == "unlock") then
			ToggleLock(false)
			d("unlocked")
		else
			d('"/weaponchargealert" or "/wca"')
			d("lock - locks position and hides the window")
			d("unlock - unlocks position and shows the window")
		end
	end
	if(not SLASH_COMMANDS["/wca"]) then
		SLASH_COMMANDS["/wca"] = SLASH_COMMANDS["/weaponchargealert"]
	end
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_WpnSlotChanged", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WeaponChanged)
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_CombatStateChanged", EVENT_PLAYER_COMBAT_STATE, CombatStateChanged)
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_WeaponSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, WeaponSetChanged)
end

local function WeaponChargeAlert_Initialized(self)
	EVENT_MANAGER:RegisterForEvent("WeaponChargeAlert_OnLoad", EVENT_ADD_ON_LOADED, OnLoad)
end

function UnhideAllDur()
	SetHiddenAll(MAIN_WEAPON, false)
	SetHiddenAll(OFF_WEAPON, false)
end

WeaponChargeAlert_Initialized()