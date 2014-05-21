
WeaponChargeAlertSettings = ZO_Object:Subclass()

local LAM = LibStub("LibAddonMenu-1.0")
local settings = nil

-----------------------------
--UTIL FUNCTIONS
-----------------------------

local function RGBAToHex( r, g, b, a )
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x%02x", r * 255, g * 255, b * 255, a * 255)
end

local function HexToRGBA( hex )
    local rhex, ghex, bhex, ahex = string.sub(hex, 1, 2), string.sub(hex, 3, 4), string.sub(hex, 5, 6), string.sub(hex, 7, 8)
    return tonumber(rhex, 16)/255, tonumber(ghex, 16)/255, tonumber(bhex, 16)/255
end

------------------------------
--OBJECT FUNCTIONS
------------------------------

function WeaponChargeAlertSettings:New()
	local obj = ZO_Object.New(self)
	obj:Initialize()
	return obj
end

function WeaponChargeAlertSettings:Initialize()
	local defaults = {
		offsetX = 0.625,
		offsetY = 0.125,

		firstAlert = false,
		lowAlert = true,
		emptyAlert = true,

		firstThreshold = 0.5,
		lowThreshold = 0.2,

		firstColor = "ffff00ff",
		lowColor = "ff4000ff",
		emptyColor = "ff0000ff",

		locked = true,
		alpha = 0.9,
		scale = 1
	}

	settings = ZO_SavedVars:NewAccountWide("WeaponChargeAlert_Settings", 1, nil, defaults)

	self.WCAControl = nil
    self:CreateOptionsMenu()
end

function WeaponChargeAlertSettings:SetMainWindow(window)
	self.WCAControl = window
end

function WeaponChargeAlertSettings:GetOffsetX()
	return GuiRoot:GetWidth() * settings.offsetX
end

function WeaponChargeAlertSettings:SetOffsetX( offsetX )
	settings.offsetX = offsetX / GuiRoot:GetWidth()
end

function WeaponChargeAlertSettings:GetOffsetY()
	return GuiRoot:GetHeight() * settings.offsetY
end

function WeaponChargeAlertSettings:SetOffsetY( offsetY )
	settings.offsetY = offsetY / GuiRoot:GetHeight()
end

function WeaponChargeAlertSettings:IsFirstAlert()
	return settings.firstAlert
end

function WeaponChargeAlertSettings:IsLowAlert()
	return settings.lowAlert
end

function WeaponChargeAlertSettings:IsEmptyAlert()
	return settings.emptyAlert
end

function WeaponChargeAlertSettings:GetFirstThreshold()
	return settings.firstThreshold
end

function WeaponChargeAlertSettings:GetLowThreshold()
	return settings.lowThreshold
end

function WeaponChargeAlertSettings:GetFirstColor()
	return HexToRGBA(settings.firstColor)
end

function WeaponChargeAlertSettings:GetLowColor()
	return HexToRGBA(settings.lowColor)
end

function WeaponChargeAlertSettings:GetEmptyColor()
	return HexToRGBA(settings.emptyColor)
end

function WeaponChargeAlertSettings:IsLocked()
	return settings.locked
end

function WeaponChargeAlertSettings:SetLocked( isLocked )
	settings.locked = isLocked
	if(self.WCAControl) then
		self.WCAControl:SetMovable(not isLocked)
		self.WCAControl:SetHidden(isLocked)
	end
	WeaponChargeAlert_UpdateAllAlerts()
end

function WeaponChargeAlertSettings:GetAlpha()
	return settings.alpha
end

function WeaponChargeAlertSettings:GetScale()
	return settings.scale
end

function WeaponChargeAlertSettings:CreateOptionsMenu()
	local str = WeaponChargeAlert_Strings[self:GetLanguage()]

	local lowMin = .01
	local lowMax = .60
	local firstMin = .02
	local firstMax = .90

	local panel = LAM:CreateControlPanel("WeaponChargeAlertSettingsPanel", "Weapon Charge Alert")
	LAM:AddHeader(panel, "WeaponChargeAlert_Header", "General Options")

	LAM:AddCheckbox(panel, "WeaponChargeAlert_Lock_Toggle", str.LOCK_LABEL, str.LOCK_TOOLTIP,
					function() return settings.locked end,
					function(value)
						self:SetLocked(value)
					end)
	LAM:AddSlider(panel, "WeaponChargeAlert_Alpha_Slider", str.ALPHA_LABEL, str.ALPHA_TOOLTIP,
					5, 100, 1,
					function() return settings.alpha * 100 end,
					function(value)
						settings.alpha = value / 100
						self.WCAControl:SetAlpha(value / 100)
					end)
	LAM:AddSlider(panel, "WeaponChargeAlert_Scale_Slider", str.SCALE_LABEL, str.SCALE_TOOLTIP,
					25, 200, 5,
					function() return settings.scale * 100 end,
					function(value)
						settings.scale = value / 100
						self.WCAControl:SetScale(value / 100)
					end)

	local firstSlider = nil
	local lowSlider = nil

	LAM:AddHeader(panel, "WeaponChargeAlert_Alerts_Header", "Alert Options")
	LAM:AddCheckbox(panel, "WeaponChargeAlert_First_Toggle", str.FIRST_TOGGLE_LABEL, str.FIRST_TOGGLE_TOOLTIP,
					function() return settings.firstAlert end,
					function(value)
						settings.firstAlert = value
						WeaponChargeAlert_UpdateAllAlerts()
					end)
	firstSlider = LAM:AddSlider(panel, "WeaponChargeAlert_First_Slider", str.FIRST_SLIDER_LABEL, str.FIRST_SLIDER_TOOLTIP,
					firstMin * 100, firstMax * 100, 1,
					function() return settings.firstThreshold * 100 end,
					function(value)
						settings.firstThreshold = value / 100
						WeaponChargeAlert_UpdateAllAlerts()
						if(settings.lowThreshold >= settings.firstThreshold) then
							settings.lowThreshold = settings.firstThreshold - 0.01
							local ls = lowSlider:GetNamedChild("Slider")
							ls:SetValue((settings.lowThreshold - lowMin) / (lowMax - lowMin))
						end
					end)
	LAM:AddColorPicker(panel, "WeaponChargeAlert_First_Color_Picker", str.FIRST_COLOR_LABEL, str.FIRST_COLOR_TOOLTIP,
					function()
						local r, g, b, a = HexToRGBA(settings.firstColor)
						return r, g, b
					end,
					function(r, g, b)
						settings.firstColor = RGBAToHex(r, g, b, 1)
						WeaponChargeAlert_UpdateAllAlerts()
					end)

	LAM:AddCheckbox(panel, "WeaponChargeAlert_Low_Toggle", str.LOW_TOGGLE_LABEL, str.LOW_TOGGLE_TOOLTIP,
					function() return settings.lowAlert end,
					function(value)
						settings.lowAlert = value
						WeaponChargeAlert_UpdateAllAlerts()
					end)
	lowSlider = LAM:AddSlider(panel, "WeaponChargeAlert_Low_Slider", str.LOW_SLIDER_LABEL, str.LOW_SLIDER_TOOLTIP,
					lowMin * 100, lowMax * 100, 1,
					function() return settings.lowThreshold * 100 end,
					function(value)
						settings.lowThreshold = value / 100
						WeaponChargeAlert_UpdateAllAlerts()
						if(settings.lowThreshold >= settings.firstThreshold) then
							settings.firstThreshold = settings.lowThreshold + 0.01
							local fs = firstSlider:GetNamedChild("Slider")
							fs:SetValue((settings.firstThreshold - firstMin) / (firstMax - firstMin))
						end
					end)
	LAM:AddColorPicker(panel, "WeaponChargeAlert_Low_Color_Picker", str.LOW_COLOR_LABEL, str.LOW_COLOR_TOOLTIP,
					function()
						local r, g, b, a = HexToRGBA(settings.lowColor)
						return r, g, b
					end,
					function(r, g, b)
						settings.lowColor = RGBAToHex(r, g, b, 1)
						WeaponChargeAlert_UpdateAllAlerts()
					end)

	LAM:AddCheckbox(panel, "WeaponChargeAlert_Empty_Toggle", str.EMPTY_TOGGLE_LABEL, str.EMPTY_TOGGLE_TOOLTIP,
					function() return settings.emptyAlert end,
					function(value)
						settings.emptyAlert = value
						WeaponChargeAlert_UpdateAllAlerts()
					end)
	LAM:AddColorPicker(panel, "WeaponChargeAlert_Empty_Color_Picker", str.EMPTY_COLOR_LABEL, str.EMPTY_COLOR_TOOLTIP,
					function()
						local r, g, b, a = HexToRGBA(settings.emptyColor)
						return r, g, b
					end,
					function(r, g, b)
						settings.emptyColor = RGBAToHex(r, g, b, 1)
						WeaponChargeAlert_UpdateAllAlerts()
					end)
end

function WeaponChargeAlertSettings:GetLanguage()
	local lang = GetCVar("language.2")

	--check for supported languages
	if(lang == "en") then return lang end

	--return english if not supported
	return "en"
end