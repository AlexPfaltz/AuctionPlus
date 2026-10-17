local wtTooltip = mainForm:GetChildChecked("Tooltip", false)
local cTooltip = wtTooltip:GetChildChecked("Container", false)
local SmartLine = {}
local DoubleLine = {}
local DescSmartLine
local DescDoubleLine
local DescSeparator
local DescDescriptionLine

local sysItemBindingId = {
	[0] = "ITEM_BINDING_BIND_NONE",
	[1] = "ITEM_BINDING_BIND_ON_PICKUP",
	[2] = "ITEM_BINDING_BIND_ON_EQUIP",
	[3] = "ITEM_BINDING_BIND_ON_USE"
}
local strDressSlotId = {
	[0] = "DRESS_SLOT_HELM",
	[1] = "DRESS_SLOT_ARMOR",
	[2] = "DRESS_SLOT_PANTS",
	[3] = "DRESS_SLOT_BOOTS",
	[4] = "DRESS_SLOT_MANTLE",
	[5] = "DRESS_SLOT_GLOVES",
	[6] = "DRESS_SLOT_BRACERS",
	[7] = "DRESS_SLOT_BELT",
	[8] = "DRESS_SLOT_RING1",
	[9] = "DRESS_SLOT_RING2",
	[10] = "DRESS_SLOT_EARRING1",
	[11] = "DRESS_SLOT_NECKLACE",
	[12] = "DRESS_SLOT_CLOAK",
	[13] = "DRESS_SLOT_SHIRT",
	[14] = "DRESS_SLOT_MAINHAND",
	[15] = "DRESS_SLOT_OFFHAND",
	[16] = "DRESS_SLOT_RANGED",
	[17] = "DRESS_SLOT_AMMO",
	[18] = "DRESS_SLOT_TABARD",
	[19] = "DRESS_SLOT_TRINKET",
	[20] = "DRESS_SLOT_BAG",
	[21] = "DRESS_SLOT_DEATHINSURANCE",
	[22] = "DRESS_SLOT_LIFESTYLEHEAD",
	[23] = "DRESS_SLOT_LIFESTYLEBACK",
	[24] = "DRESS_SLOT_LIFESTYLESUIT",
	[25] = "DRESS_SLOT_LIFESTYLEUNDERWEAR",
	[26] = "DRESS_SLOT_LIFESTYLESHOULDER",
	[27] = "DRESS_SLOT_LIFESTYLEPET",
	[28] = "DRESS_SLOT_POWEREDLSWEAPON",
	[29] = "DRESS_SLOT_EARRING2",
	[30] = "DRESS_SLOT_DEPOSITBOX",
	[31] = "DRESS_SLOT_OFFENSIVERUNE1",
	[32] = "DRESS_SLOT_OFFENSIVERUNE2",
	[33] = "DRESS_SLOT_OFFENSIVERUNE3",
	[34] = "DRESS_SLOT_DEFENSIVERUNE1",
	[35] = "DRESS_SLOT_DEFENSIVERUNE2",
	[36] = "DRESS_SLOT_DEFENSIVERUNE3",
	[37] = "DRESS_SLOT_LIFESTYLESHOULDER",
	[38] = "DRESS_SLOT_POWEREDLSWEAPON",
	[39] = "DRESS_SLOT_HIDDENPOWER",
	[40] = "DRESS_SLOT_LIFESTYLEPET",
	[41] = "DRESS_SLOT_HAT",
	[42] = "DRESS_SLOT_UNDRESSABLE",
	[43] = "DRESS_SLOT_TWOHANDED",
	[44] = "DRESS_SLOT_DUALWIELD",
	[45] = "DRESS_SLOT_RING",
	[46] = "DRESS_SLOT_EARRINGS",
	[47] = "DRESS_SLOT_RUNE",
	[48] = "DRESS_SLOT_ARTIFACT",
	[49] = "DRESS_SLOT_ARTIFACT1",
	[50] = "DRESS_SLOT_ARTIFACT2",
	[51] = "DRESS_SLOT_ARTIFACT3",
	[52] = "DRESS_SLOT_NONPREVIEW"
}
local sysNameInnateStats = {
	["ENUM_InnateStats_Plain"] = "InnateStats_Plain",
	["ENUM_InnateStats_Rage"] = "InnateStats_Rage",
	["ENUM_InnateStats_Finisher"] = "InnateStats_Finisher",
	["ENUM_InnateStats_Lethality"] = "InnateStats_Lethality",
	["ENUM_InnateStats_Vitality"] = "InnateStats_Vitality",
	["ENUM_InnateStats_Endurance"] = "InnateStats_Endurance",
	["ENUM_InnateStats_Lifesteal"] = "InnateStats_Lifesteal",
	["ENUM_InnateStats_Will"] = "InnateStats_Will",
	["ENUM_InnateStats_CritChance"] = "InnateStats_CritChance"
}
local sysNameResistances = {
	["ENUM_EELEMENTAL"] = "Resistance_Elemental",
	["ENUM_EDIVINE"] = "Resistance_Edivine",
	["ENUM_ENATURE"] = "Resistance_Enature",
	["ENUM_EPHYSICAL"] = "Resistance_Ephysical"
}

function CreateSmartLine()
	local widget = {}
	if not DescSmartLine then
		widget = wtTooltip:GetChildChecked("SmartLine", false)
		DescSmartLine = widget:GetWidgetDesc()
	else
		widget = mainForm:CreateWidgetByDesc(DescSmartLine)
	end
	return widget
end

function CreateDoubleLine()
	local widget = {}
	if not DescDoubleLine then
		widget = wtTooltip:GetChildChecked("DoubleLine", false)
		DescDoubleLine = widget:GetWidgetDesc()
	else
		widget = mainForm:CreateWidgetByDesc(DescDoubleLine)
	end
	return widget
end

function CreateSeparator()
	local widget = {}
	if not DescSeparator then
		widget = wtTooltip:GetChildChecked("Separator", false)
		DescSeparator = widget:GetWidgetDesc()
	else
		widget = mainForm:CreateWidgetByDesc(DescSeparator)
	end
	return widget
end

function CreateDescriptionLine()
	local widget = {}
	if not DescDescriptionLine then
		widget = wtTooltip:GetChildChecked("DescriptionLine", false)
		DescDescriptionLine = widget:GetWidgetDesc()
	else
		widget = mainForm:CreateWidgetByDesc(DescDescriptionLine)
	end
	return widget
end

function fillTooltip(content)
	--for k, v in pairs(content) do
	--	common.LogInfo("common", tostring(k), ", ", tostring(v))
	--end

	if not content or not content.name then return end

	--Itemname
	local itemaname = CreateSmartLine()
	itemaname:SetMultiline(true)
	itemaname:SetWrapText(true)
	itemaname:SetVal("value", content.name)
	itemaname:SetClassVal( "class", ItemQualityClass[content.quality])
	itemaname:SetClassVal( "size", "Size16")
	cTooltip:PushBack(itemaname)

	--Binding
	if content.binding > 0 then
		local Binding = CreateSmartLine()
		Binding:SetVal("value", GetLocalizedText(sysItemBindingId[content.binding]))
		Binding:SetClassVal( "class", "tip_golden")
		cTooltip:PushBack(Binding)
	end

	--GearScore
	if content.gearScore and content.gearScore > 0 then
		local gearScore = CreateSmartLine()
		gearScore:SetVal("value", GetLocalizedText("gearScore")..tostring(math.ceil(content.gearScore)))
		gearScore:SetClassVal( "class", "tip_white")
		cTooltip:PushBack(gearScore)
	end

	--DressSlot
	if content.dressSlot ~= 42 then
		local dressSlot = CreateDoubleLine()
		dressSlot:GetChildChecked("LineLeft", false):SetVal("value", GetLocalizedText(strDressSlotId[content.dressSlot]))
		dressSlot:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
		dressSlot:GetChildChecked("LineRight", false):SetVal("value", content.class)
		if content.conditions.sysFirstCondition ~= "ENUM_DressResult_Success"
		and ( content.conditions.failedConditions[ "ENUM_DressResult_WrongCharacterClass" ]
		or content.conditions.failedConditions[ "ENUM_DressResult_NotProficient" ] ) then
			dressSlot:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_red")
		else
			dressSlot:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_base")
		end
		cTooltip:PushBack(dressSlot)
	end

	--Уровень предмета и требуемый уровень
	local level = content.level
	local requiredLevel = content.requiredLevel
	if level > 1 and content.requiredLevel > 1 then
		local wtLevel = CreateDoubleLine()
		wtLevel:GetChildChecked("LineLeft", false):SetVal("value", GetLocalizedText("Level")..tostring(level))
		wtLevel:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
		wtLevel:GetChildChecked("LineRight", false):SetVal("value", GetLocalizedText("requiredLevel")..tostring(requiredLevel))
		if requiredLevel <= unit.GetLevel(avatar.GetId()) then
			wtLevel:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_base")
		else
			wtLevel:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_red")
		end
		cTooltip:PushBack(wtLevel)
	elseif level == 1 and content.requiredLevel > 1 then
		local wtLevel = CreateSmartLine()
		wtLevel:SetVal("value", GetLocalizedText("requiredLevel")..tostring(requiredLevel))
		if requiredLevel <= unit.GetLevel(avatar.GetId()) then
			wtLevel:SetClassVal( "class", "tip_base")
		else
			wtLevel:SetClassVal( "class", "tip_red")
		end
		cTooltip:PushBack(wtLevel)
	end

	local misc = content.bonus.miscStats

	--DamageMinMax
	if content.isWeapon then
		local DamageMinMax = CreateDoubleLine()
		local intMin = tostring(math.ceil(misc.minDamage.base))
		local intMax = tostring(math.ceil(misc.maxDamage.base))
		if misc.minDamage.base < misc.maxDamage.base then
			DamageMinMax:GetChildChecked("LineLeft", false):SetVal("value", GetLocalizedText("Damage") .. intMin .. " - " .. intMax)
			DamageMinMax:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
			--dps
			local dps = common.FormatFloat(((misc.minDamage.base + misc.maxDamage.base) / (2 * misc.weaponSpeed)), "%.2f" )
			DamageMinMax:GetChildChecked("LineRight", false):SetVal("value", GetLocalizedText("per sec")..userMods.FromWString(dps))
			DamageMinMax:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_base")
		else
			DamageMinMax:GetChildChecked("LineLeft", false):SetVal("value", GetLocalizedText("Damage") .. intMin)
			DamageMinMax:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
			--dps
			local dps = common.FormatFloat((misc.minDamage.base / (1+misc.weaponSpeed)), "%.2f" )
			DamageMinMax:GetChildChecked("LineRight", false):SetVal("value", GetLocalizedText("per sec")..userMods.FromWString(dps))
			DamageMinMax:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_base")
		end
		cTooltip:PushBack(DamageMinMax)
		
		--Время на атаку
		local speed = common.FormatFloat(misc.weaponSpeed, "%.1f")
		local wtSpeed = CreateSmartLine()
		wtSpeed:SetVal("value", GetLocalizedText("Time on atack")..userMods.FromWString(speed))
		wtSpeed:SetClassVal( "class", "tip_base")
		cTooltip:PushBack(wtSpeed)
	end

	--SpellPowerMinMax
	if misc.minSpellPower.base > 0 then
		local SpellPowerMinMax = CreateSmartLine()
		local spellMin = tostring(math.ceil(misc.minSpellPower.base))
		local spellMax = tostring(math.ceil(misc.maxSpellPower.base))
		if misc.minSpellPower.base < misc.maxSpellPower.base then
			SpellPowerMinMax:SetVal("value", GetLocalizedText("SpellPower") .. spellMin .. " - " .. spellMax)
			SpellPowerMinMax:SetClassVal( "class", "tip_base")
		else
			SpellPowerMinMax:SetVal("value", GetLocalizedText("SpellPower") .. spellMin)
			SpellPowerMinMax:SetClassVal( "class", "tip_base")
		end
		cTooltip:PushBack(SpellPowerMinMax)
	end

	--Separator1
	local separator1 = CreateSeparator()
	cTooltip:PushBack(separator1)
	local widgets_after_separator_1 = false

	--specStats

	if content.isWeapon or (content.dressSlot >=0 and content.dressSlot <=18) 
	or content.dressSlot ==29 or (content.dressSlot >=43 and content.dressSlot <=46) then
		local spec = content.bonus.specStats
		local sumSpecStats = 0
		local wtSpecStats = CreateDoubleLine()
		wtSpecStats:GetChildChecked("LineLeft", false):SetVal("value", GetLocalizedText("specStats"))
		wtSpecStats:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_white")
		wtSpecStats:GetChildChecked("LineRight", false):SetClassVal( "class", "StatPrimaryColor")
		wtSpecStats:GetChildChecked("LineRight", false):SetClassVal( "size", "Size17")
		cTooltip:PushBack(wtSpecStats)
		for i=1, #spec do
			local SpecStat = CreateDoubleLine()
			local value = common.FormatFloat(spec[i].value, "%.2f")
			SpecStat:GetChildChecked("LineLeft", false):SetVal("value", "+"..userMods.FromWString(value).." "..userMods.FromWString(spec[i].tooltipName))
			SpecStat:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
			--SpecStat:GetChildChecked("LineRight", false):SetVal("value", tostring(math.ceil()))
			--SpecStat:GetChildChecked("LineRight", false):SetClassVal( "class", "")
			--SpecStat:GetChildChecked("LineRight", false):SetClassVal( "size", "")
			cTooltip:PushBack(SpecStat)
			sumSpecStats = sumSpecStats + spec[i].value
		end
		wtSpecStats:GetChildChecked("LineRight", false):SetVal("value", tostring(math.ceil(sumSpecStats)))

	--miscStats
		local stats = CreateDoubleLine()
		stats:GetChildChecked("LineLeft", false):SetVal("value", GetLocalizedText("Stats"))
		stats:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_white")
		stats:GetChildChecked("LineRight", false):SetVal("value", tostring(math.ceil(misc.power.base + misc.stamina.base)))
		stats:GetChildChecked("LineRight", false):SetClassVal( "class", "StatPrimaryColor")
		stats:GetChildChecked("LineRight", false):SetClassVal( "size", "Size17")
		cTooltip:PushBack(stats)

		local statPower = CreateDoubleLine()
		local valuePower = common.FormatFloat(misc.power.base, "%.1f")
		statPower:GetChildChecked("LineLeft", false):SetVal("value", "+"..userMods.FromWString(valuePower)..GetLocalizedText("statPower"))
		statPower:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
		--statPower:GetChildChecked("LineRight", false):SetVal("value", tostring(math.ceil()))
		--statPower:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_base")
		cTooltip:PushBack(statPower)
		local statStamina = CreateDoubleLine()
		local valueStamina = common.FormatFloat(misc.stamina.base, "%.1f")
		statStamina:GetChildChecked("LineLeft", false):SetVal("value", "+"..userMods.FromWString(valueStamina)..GetLocalizedText("statStamina"))
		statStamina:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
		--statStamina:GetChildChecked("LineRight", false):SetVal("value", tostring(math.ceil()))
		--statStamina:GetChildChecked("LineRight", false):SetClassVal( "class", "tip_base")
		cTooltip:PushBack(statStamina)

		--InnateStats
		local InnateStats = content.bonus.innateStats
		for i=0, #InnateStats do
			if InnateStats[i].base > 0 then
				local InnateStat = CreateDoubleLine()
				local value = common.FormatFloat(InnateStats[i].base, "%.1f")
				InnateStat:GetChildChecked("LineLeft", false):SetVal("value", "+"..userMods.FromWString(value).." "..GetLocalizedText(sysNameInnateStats[InnateStats[i].sysName]))
				InnateStat:GetChildChecked("LineLeft", false):SetClassVal( "class", "tip_base")
				--InnateStat:GetChildChecked("LineRight", false):SetVal("value", tostring(math.ceil()))
				--InnateStat:GetChildChecked("LineRight", false):SetClassVal( "class", "")
				--InnateStat:GetChildChecked("LineRight", false):SetClassVal( "size", "")
				cTooltip:PushBack(InnateStat)
			end
		end

		--Сопротивление
		if (content.dressSlot >=0 and content.dressSlot <=13) 
		or content.dressSlot ==29 or (content.dressSlot >=45 and content.dressSlot <=46) then
			local wtResistance = CreateSmartLine()
			wtResistance:SetVal("value", GetLocalizedText("Resistance"))
			wtResistance:SetClassVal( "class", "tip_white")
			cTooltip:PushBack(wtResistance)

			local resistances = content.bonus.resistances
			for i=0, #resistances do
				if resistances[i].base > 0 then
					local Resistance = CreateSmartLine()
					local value = math.ceil(resistances[i].base)
					Resistance:SetVal("value", "+"..tostring(value)..GetLocalizedText(sysNameResistances[resistances[i].sysName]))
					Resistance:SetClassVal( "class", "tip_base")
					cTooltip:PushBack(Resistance)
				end
			end
		end

		widgets_after_separator_1 = true
	end

	if string.len(userMods.FromWString(content.description:ToWString())) > 0 then
	--Separator2
		if widgets_after_separator_1 then
			local separator2 = CreateSeparator()
			cTooltip:PushBack(separator2)
		end

	--Description
		local description = CreateDescriptionLine()
		description:SetVal("value", content.description)
		description:SetMultiline(true)
		description:SetWrapText(true)
		cTooltip:PushBack(description)
	end

	local permission = true
	return permission
end

function tooltipPlace(icon)
	local placement = wtTooltip:GetPlacementPlain()
    local wtMain = icon:GetRealRect()
		
	local rect = wtTooltip:GetRealRect()
	rect.sizeX = rect.x2 - rect.x1
	rect.sizeY = rect.y2 - rect.y1
		
	local frameRect = mainForm:GetRealRect()
	frameRect.sizeX = frameRect.x2 - frameRect.x1
	frameRect.sizeY = frameRect.y2 - frameRect.y1
	
	local placeX = frameRect.x2 - wtMain.x2
	local placeY = frameRect.y2 - wtMain.y1
			
	placement.alignX = WIDGET_ALIGN_LOW_ABS
	placement.alignY = WIDGET_ALIGN_LOW_ABS
	
	if placeX > rect.sizeX then
		placement.posX = wtMain.x2
	else
		placement.posX = wtMain.x1 - rect.sizeX
	end
	
	if frameRect.y2 - wtMain.y1 > rect.sizeY then
		placement.posY = wtMain.y1
		
	elseif wtMain.y2 > rect.sizeY then
		placement.posY = wtMain.y2 - rect.sizeY
		
	else
		placement.posY = (frameRect.sizeY - rect.sizeY) / 2
	end
			
	wtTooltip:SetPlacementPlain(placement)
end

function CallTooltipItem(content, params)
	if fillTooltip(content) then
    	tooltipPlace(params)
		wtTooltip:Show(true)
		cTooltip:Show(true)
	end
end

function HideTooltip()
	DestroyWidgetsInContainer(cTooltip)
	wtTooltip:Show(false)
    cTooltip:Show(false)
end