-- ============================================================
-- Tooltip.lua
-- Собственный тултип для вкладки "Купить" (ListBuy).
-- Использует пул виджетов, чтобы не создавать/уничтожать их
-- на каждое движение мыши. Защищён от nil в SetVal/GetLocalizedText.
-- ============================================================

local wtTooltip = mainForm:GetChildChecked("Tooltip", false)
local cTooltip  = wtTooltip:GetChildChecked("Container", false)

-- ============================================================
-- Безопасные хелперы
-- ============================================================

-- Возвращает локализованный текст или fallback, если ключ не найден.
local function L(key, fallback)
    if key == nil then return fallback or "" end
    local v = GetLocalizedText(key)
    if v == nil then return fallback or tostring(key) end
    return v
end

-- SetVal, не падающий на nil: подставляет пустую WString.
local function SafeSetVal(widget, tag, value)
    if value == nil then
        value = userMods.ToWString("")
    end
    widget:SetVal(tag, value)
end

-- ============================================================
-- Дескрипторы (получаем один раз)
-- ============================================================

local DescSmartLine
local DescDoubleLine
local DescSeparator
local DescDescriptionLine

-- ============================================================
-- Пулы виджетов
-- ============================================================

local smartLinePool   = {}
local doubleLinePool  = {}
local separatorPool   = {}
local descriptionPool = {}

-- Активные виджеты: { widget = w, pool = pool }
local activeWidgets = {}

local function AcquireSmartLine()
    local w = table.remove(smartLinePool)
    if w then return w end
    if not DescSmartLine then
        local src = wtTooltip:GetChildChecked("SmartLine", false)
        DescSmartLine = src:GetWidgetDesc()
    end
    w = mainForm:CreateWidgetByDesc(DescSmartLine)
    mainForm:AddChild(w)
    return w
end

local function AcquireDoubleLine()
    local w = table.remove(doubleLinePool)
    if w then return w end
    if not DescDoubleLine then
        local src = wtTooltip:GetChildChecked("DoubleLine", false)
        DescDoubleLine = src:GetWidgetDesc()
    end
    w = mainForm:CreateWidgetByDesc(DescDoubleLine)
    mainForm:AddChild(w)
    return w
end

local function AcquireSeparator()
    local w = table.remove(separatorPool)
    if w then return w end
    if not DescSeparator then
        local src = wtTooltip:GetChildChecked("Separator", false)
        DescSeparator = src:GetWidgetDesc()
    end
    w = mainForm:CreateWidgetByDesc(DescSeparator)
    mainForm:AddChild(w)
    return w
end

local function AcquireDescriptionLine()
    local w = table.remove(descriptionPool)
    if w then return w end
    if not DescDescriptionLine then
        local src = wtTooltip:GetChildChecked("DescriptionLine", false)
        DescDescriptionLine = src:GetWidgetDesc()
    end
    w = mainForm:CreateWidgetByDesc(DescDescriptionLine)
    mainForm:AddChild(w)
    return w
end

local function Track(w, pool)
    activeWidgets[#activeWidgets + 1] = { widget = w, pool = pool }
end

local function ResetWidget(w)
    -- Очищаем все подстановочные значения (текст) у самого виджета
    if w.ClearValues then
        pcall(function() w:ClearValues() end)
    end
    
    -- Сбрасываем многострочность и перенос (чтобы тексты не раздувались)
    if w.SetMultiline then
        pcall(function() w:SetMultiline(false) end)
    end
    if w.SetWrapText then
        pcall(function() w:SetWrapText(false) end)
    end

    -- Для DoubleLine и других составных виджетов очищаем детей
    local left = w:GetChildChecked("LineLeft", false)
    if left and left.ClearValues then
        pcall(function() left:ClearValues() end)
    end
    local right = w:GetChildChecked("LineRight", false)
    if right and right.ClearValues then
        pcall(function() right:ClearValues() end)
    end
end

local function RecycleAll()
    for i = #activeWidgets, 1, -1 do
        local item = activeWidgets[i]
        local w = item.widget
        pcall(function() cTooltip:Remove(w) end)
        ResetWidget(w)
        table.insert(item.pool, w)
        activeWidgets[i] = nil
    end
end

-- ============================================================
-- Локализованные таблицы
-- ============================================================

local sysItemBindingId = {
    [0] = "ITEM_BINDING_BIND_NONE",
    [1] = "ITEM_BINDING_BIND_ON_PICKUP",
    [2] = "ITEM_BINDING_BIND_ON_EQUIP",
    [3] = "ITEM_BINDING_BIND_ON_USE"
}

local strDressSlotId = {
    [0]  = "DRESS_SLOT_HELM",
    [1]  = "DRESS_SLOT_ARMOR",
    [2]  = "DRESS_SLOT_PANTS",
    [3]  = "DRESS_SLOT_BOOTS",
    [4]  = "DRESS_SLOT_MANTLE",
    [5]  = "DRESS_SLOT_GLOVES",
    [6]  = "DRESS_SLOT_BRACERS",
    [7]  = "DRESS_SLOT_BELT",
    [8]  = "DRESS_SLOT_RING1",
    [9]  = "DRESS_SLOT_RING2",
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
    ["ENUM_InnateStats_Plain"]      = "InnateStats_Plain",
    ["ENUM_InnateStats_Rage"]       = "InnateStats_Rage",
    ["ENUM_InnateStats_Finisher"]   = "InnateStats_Finisher",
    ["ENUM_InnateStats_Lethality"]  = "InnateStats_Lethality",
    ["ENUM_InnateStats_Vitality"]   = "InnateStats_Vitality",
    ["ENUM_InnateStats_Endurance"]  = "InnateStats_Endurance",
    ["ENUM_InnateStats_Lifesteal"]  = "InnateStats_Lifesteal",
    ["ENUM_InnateStats_Will"]       = "InnateStats_Will",
    ["ENUM_InnateStats_CritChance"] = "InnateStats_CritChance"
}

local sysNameResistances = {
    ["ENUM_EELEMENTAL"] = "Resistance_Elemental",
    ["ENUM_EDIVINE"]    = "Resistance_Edivine",
    ["ENUM_ENATURE"]    = "Resistance_Enature",
    ["ENUM_EPHYSICAL"]  = "Resistance_Ephysical"
}

-- ============================================================
-- Вспомогательные проверки
-- ============================================================

local function IsWeaponLike(dressSlot)
    if not dressSlot then return false end
    return dressSlot >= 0 and dressSlot <= 18
        or dressSlot == 29
        or (dressSlot >= 43 and dressSlot <= 46)
end

local function IsResistanceSlot(dressSlot)
    if not dressSlot then return false end
    return (dressSlot >= 0 and dressSlot <= 13)
        or dressSlot == 29
        or (dressSlot >= 45 and dressSlot <= 46)
end

-- ============================================================
-- Сборка содержимого тултипа
-- ============================================================

local function fillTooltip(content)
    if not content or not content.name then return false end

    -- Itemname
    local itemaname = AcquireSmartLine()
    itemaname:SetMultiline(true)
    itemaname:SetWrapText(true)
    SafeSetVal(itemaname, "value", content.name)
    itemaname:SetClassVal("class", ItemQualityClass[content.quality])
    itemaname:SetClassVal("size", "Size16")
    cTooltip:PushBack(itemaname)
    Track(itemaname, smartLinePool)

    -- Binding
    if content.binding and content.binding > 0 then
        local Binding = AcquireSmartLine()
        SafeSetVal(Binding, "value", L(sysItemBindingId[content.binding], "?"))
        Binding:SetClassVal("class", "tip_golden")
        cTooltip:PushBack(Binding)
        Track(Binding, smartLinePool)
    end

    -- GearScore
    if content.gearScore and content.gearScore > 0 then
        local gs = AcquireSmartLine()
        SafeSetVal(gs, "value", L("gearScore") .. tostring(math.ceil(content.gearScore)))
        gs:SetClassVal("class", "tip_white")
        cTooltip:PushBack(gs)
        Track(gs, smartLinePool)
    end

    -- DressSlot
    if content.dressSlot ~= 42 and content.dressSlot ~= nil then
        local dressSlot = AcquireDoubleLine()
        SafeSetVal(dressSlot:GetChildChecked("LineLeft", false),
            "value", L(strDressSlotId[content.dressSlot], "?"))
        dressSlot:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")

        SafeSetVal(dressSlot:GetChildChecked("LineRight", false),
            "value", content.class or userMods.ToWString(""))

        if content.conditions
           and content.conditions.sysFirstCondition ~= "ENUM_DressResult_Success"
           and content.conditions.failedConditions
           and (content.conditions.failedConditions["ENUM_DressResult_WrongCharacterClass"]
             or content.conditions.failedConditions["ENUM_DressResult_NotProficient"]) then
            dressSlot:GetChildChecked("LineRight", false):SetClassVal("class", "tip_red")
        else
            dressSlot:GetChildChecked("LineRight", false):SetClassVal("class", "tip_base")
        end
        cTooltip:PushBack(dressSlot)
        Track(dressSlot, doubleLinePool)
    end

    -- Level / requiredLevel
    local level = content.level or 0
    local requiredLevel = content.requiredLevel or 0
    local playerLevel = unit.GetLevel(avatar.GetId())
    if level > 1 and requiredLevel > 1 then
        local wtLevel = AcquireDoubleLine()
        SafeSetVal(wtLevel:GetChildChecked("LineLeft", false),
            "value", L("Level") .. tostring(level))
        wtLevel:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
        SafeSetVal(wtLevel:GetChildChecked("LineRight", false),
            "value", L("requiredLevel") .. tostring(requiredLevel))
        if requiredLevel <= playerLevel then
            wtLevel:GetChildChecked("LineRight", false):SetClassVal("class", "tip_base")
        else
            wtLevel:GetChildChecked("LineRight", false):SetClassVal("class", "tip_red")
        end
        cTooltip:PushBack(wtLevel)
        Track(wtLevel, doubleLinePool)
    elseif level == 1 and requiredLevel > 1 then
        local wtLevel = AcquireSmartLine()
        SafeSetVal(wtLevel, "value", L("requiredLevel") .. tostring(requiredLevel))
        if requiredLevel <= playerLevel then
            wtLevel:SetClassVal("class", "tip_base")
        else
            wtLevel:SetClassVal("class", "tip_red")
        end
        cTooltip:PushBack(wtLevel)
        Track(wtLevel, smartLinePool)
    end

    local bonus = content.bonus or {}
    local misc  = bonus.miscStats or {}

    -- Damage (weapon)
    if content.isWeapon
       and misc.minDamage and misc.maxDamage and misc.weaponSpeed then
        local DamageMinMax = AcquireDoubleLine()
        local intMin = tostring(math.ceil(misc.minDamage.base))
        local intMax = tostring(math.ceil(misc.maxDamage.base))
        if misc.minDamage.base < misc.maxDamage.base then
            SafeSetVal(DamageMinMax:GetChildChecked("LineLeft", false),
                "value", L("Damage") .. intMin .. " - " .. intMax)
            DamageMinMax:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
            local dps = common.FormatFloat(((misc.minDamage.base + misc.maxDamage.base)
                / (2 * misc.weaponSpeed)), "%.2f")
            SafeSetVal(DamageMinMax:GetChildChecked("LineRight", false),
                "value", L("per sec") .. userMods.FromWString(dps))
            DamageMinMax:GetChildChecked("LineRight", false):SetClassVal("class", "tip_base")
        else
            SafeSetVal(DamageMinMax:GetChildChecked("LineLeft", false),
                "value", L("Damage") .. intMin)
            DamageMinMax:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
            local dps = common.FormatFloat((misc.minDamage.base / (1 + misc.weaponSpeed)), "%.2f")
            SafeSetVal(DamageMinMax:GetChildChecked("LineRight", false),
                "value", L("per sec") .. userMods.FromWString(dps))
            DamageMinMax:GetChildChecked("LineRight", false):SetClassVal("class", "tip_base")
        end
        cTooltip:PushBack(DamageMinMax)
        Track(DamageMinMax, doubleLinePool)

        local speed = common.FormatFloat(misc.weaponSpeed, "%.1f")
        local wtSpeed = AcquireSmartLine()
        SafeSetVal(wtSpeed, "value", L("Time on atack") .. userMods.FromWString(speed))
        wtSpeed:SetClassVal("class", "tip_base")
        cTooltip:PushBack(wtSpeed)
        Track(wtSpeed, smartLinePool)
    end

    -- SpellPower
    if misc.minSpellPower and misc.maxSpellPower and misc.minSpellPower.base > 0 then
        local sp = AcquireSmartLine()
        local spellMin = tostring(math.ceil(misc.minSpellPower.base))
        local spellMax = tostring(math.ceil(misc.maxSpellPower.base))
        if misc.minSpellPower.base < misc.maxSpellPower.base then
            SafeSetVal(sp, "value", L("SpellPower") .. spellMin .. " - " .. spellMax)
        else
            SafeSetVal(sp, "value", L("SpellPower") .. spellMin)
        end
        sp:SetClassVal("class", "tip_base")
        cTooltip:PushBack(sp)
        Track(sp, smartLinePool)
    end

    -- Separator
    local sep1 = AcquireSeparator()
    cTooltip:PushBack(sep1)
    Track(sep1, separatorPool)
    local widgets_after_separator_1 = false

    -- Equipment block (specStats / miscStats / innateStats / resistances)
    if content.isWeapon or IsWeaponLike(content.dressSlot) then
        local spec = bonus.specStats or {}
        local sumSpecStats = 0
        local wtSpecStats = AcquireDoubleLine()
        SafeSetVal(wtSpecStats:GetChildChecked("LineLeft", false), "value", L("specStats"))
        wtSpecStats:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_white")
        wtSpecStats:GetChildChecked("LineRight", false):SetClassVal("class", "StatPrimaryColor")
        wtSpecStats:GetChildChecked("LineRight", false):SetClassVal("size", "Size17")
        cTooltip:PushBack(wtSpecStats)
        Track(wtSpecStats, doubleLinePool)

        for i = 1, #spec do
            local SpecStat = AcquireDoubleLine()
            local value = common.FormatFloat(spec[i].value or 0, "%.2f")
            local tooltipName = spec[i].tooltipName
                and userMods.FromWString(spec[i].tooltipName) or ""
            SafeSetVal(SpecStat:GetChildChecked("LineLeft", false),
                "value", "+" .. userMods.FromWString(value) .. " " .. tooltipName)
            SpecStat:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
            cTooltip:PushBack(SpecStat)
            Track(SpecStat, doubleLinePool)
            sumSpecStats = sumSpecStats + (spec[i].value or 0)
        end
        SafeSetVal(wtSpecStats:GetChildChecked("LineRight", false),
            "value", tostring(math.ceil(sumSpecStats)))

        -- miscStats
        local power   = misc.power   and misc.power.base   or 0
        local stamina = misc.stamina and misc.stamina.base or 0

        local stats = AcquireDoubleLine()
        SafeSetVal(stats:GetChildChecked("LineLeft", false), "value", L("Stats"))
        stats:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_white")
        SafeSetVal(stats:GetChildChecked("LineRight", false),
            "value", tostring(math.ceil(power + stamina)))
        stats:GetChildChecked("LineRight", false):SetClassVal("class", "StatPrimaryColor")
        stats:GetChildChecked("LineRight", false):SetClassVal("size", "Size17")
        cTooltip:PushBack(stats)
        Track(stats, doubleLinePool)

        local statPower = AcquireDoubleLine()
        SafeSetVal(statPower:GetChildChecked("LineLeft", false),
            "value", "+" .. userMods.FromWString(common.FormatFloat(power, "%.1f"))
                .. L("statPower"))
        statPower:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
        cTooltip:PushBack(statPower)
        Track(statPower, doubleLinePool)

        local statStamina = AcquireDoubleLine()
        SafeSetVal(statStamina:GetChildChecked("LineLeft", false),
            "value", "+" .. userMods.FromWString(common.FormatFloat(stamina, "%.1f"))
                .. L("statStamina"))
        statStamina:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
        cTooltip:PushBack(statStamina)
        Track(statStamina, doubleLinePool)

        -- innateStats
        local InnateStats = bonus.innateStats or {}
        for i = 0, #InnateStats do
            local st = InnateStats[i]
            if st and st.base and st.base > 0 then
                local InnateStat = AcquireDoubleLine()
                local value = common.FormatFloat(st.base, "%.1f")
                SafeSetVal(InnateStat:GetChildChecked("LineLeft", false),
                    "value", "+" .. userMods.FromWString(value) .. " "
                        .. L(sysNameInnateStats[st.sysName], ""))
                InnateStat:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
                cTooltip:PushBack(InnateStat)
                Track(InnateStat, doubleLinePool)
            end
        end

        -- resistances
        if IsResistanceSlot(content.dressSlot) then
            local wtResistance = AcquireSmartLine()
            SafeSetVal(wtResistance, "value", L("Resistance"))
            wtResistance:SetClassVal("class", "tip_white")
            cTooltip:PushBack(wtResistance)
            Track(wtResistance, smartLinePool)

            local resistances = bonus.resistances or {}
            for i = 0, #resistances do
                local r = resistances[i]
                if r and r.base and r.base > 0 then
                    local Resistance = AcquireSmartLine()
                    SafeSetVal(Resistance, "value",
                        "+" .. tostring(math.ceil(r.base))
                            .. L(sysNameResistances[r.sysName], ""))
                    Resistance:SetClassVal("class", "tip_base")
                    cTooltip:PushBack(Resistance)
                    Track(Resistance, smartLinePool)
                end
            end
        end

        widgets_after_separator_1 = true
    end

    -- Description
    local hasDescription = false
    if content.description then
        local ok, len = pcall(function()
            return string.len(userMods.FromWString(content.description:ToWString()))
        end)
        hasDescription = ok and len and len > 0
    end
    if hasDescription then
        if widgets_after_separator_1 then
            local sep2 = AcquireSeparator()
            cTooltip:PushBack(sep2)
            Track(sep2, separatorPool)
        end
        local description = AcquireDescriptionLine()
        SafeSetVal(description, "value", content.description)
        description:SetMultiline(true)
        description:SetWrapText(true)
        cTooltip:PushBack(description)
        Track(description, descriptionPool)
    end

    return true
end

-- ============================================================
-- Позиционирование и публичный API
-- ============================================================

local function tooltipPlace(icon)
    local placement = wtTooltip:GetPlacementPlain()
    local wtMain = icon:GetRealRect()

    local rect = wtTooltip:GetRealRect()
    rect.sizeX = rect.x2 - rect.x1
    rect.sizeY = rect.y2 - rect.y1

    local frameRect = mainForm:GetRealRect()
    frameRect.sizeX = frameRect.x2 - frameRect.x1
    frameRect.sizeY = frameRect.y2 - frameRect.y1

    local placeX = frameRect.x2 - wtMain.x2

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

function CallTooltipItem(content, icon)
    if not content or not icon then return end
    RecycleAll()
    if fillTooltip(content) then
        tooltipPlace(icon)
        wtTooltip:Show(true)
        cTooltip:Show(true)
    end
end

function HideTooltip()
    RecycleAll()
    wtTooltip:Show(false)
    cTooltip:Show(false)
end