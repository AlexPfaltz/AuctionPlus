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
local moneyPool       = { destroy = true }  -- строки с монетами не переиспользуются, а уничтожаются

-- Контейнер и панель с монетами берём у PriceInTooltip (те же виджеты, что и в
-- родном тултипе). Дескрипторы снимаем при загрузке, пока PriceInTooltip
-- ещё не переложил их детей в родной тултип.
local DescMoneyContainer, DescMoneyPanel
do
    local ok = pcall(function()
        local src = mainForm:GetChildChecked("PriceInTooltip", false)
        DescMoneyContainer = src:GetChildChecked("ContainerPrice", false):GetWidgetDesc()
        DescMoneyPanel = src:GetChildChecked("Prices", false):GetWidgetDesc()
    end)
    if not ok then
        DescMoneyContainer, DescMoneyPanel = nil, nil
    end
end

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

local function Track(w, pool, extra)
    activeWidgets[#activeWidgets + 1] = { widget = w, pool = pool, extra = extra }
end

-- Есть ли хоть одно ненулевое сопротивление
local function HasResistances(bonus)
    local resistances = bonus and bonus.resistances
    if not resistances then return false end
    for _, r in pairs(resistances) do
        if r and r.base and r.base > 0 then return true end
    end
    return false
end

-- Длительность в мс -> "1 ч. 2 м. 3 с."
local function FormatDuration(ms)
    local totalSec = math.floor((ms or 0) / 1000)
    local h = math.floor(totalSec / 3600)
    local m = math.floor((totalSec % 3600) / 60)
    local s = totalSec % 60
    local parts = {}
    if h > 0 then parts[#parts + 1] = tostring(h) .. L("cdHour") end
    if m > 0 then parts[#parts + 1] = tostring(m) .. L("cdMin") end
    if s > 0 or #parts == 0 then parts[#parts + 1] = tostring(s) .. L("cdSec") end
    return table.concat(parts, " ")
end

-- Медь -> "250 з. 12 с. 5 м."
local function FormatCoins(copper)
    local parts = Split(math.floor(copper))
    local out = {}
    if parts[1] > 0 then
        out[#out + 1] = userMods.FromWString(common.FormatInt(parts[1], "%d", " ")) .. L("coinGold")
    end
    if parts[2] > 0 then
        out[#out + 1] = tostring(parts[2]) .. L("coinSilver")
    end
    if parts[3] > 0 then
        out[#out + 1] = tostring(parts[3]) .. L("coinCopper")
    end
    return table.concat(out, " ")
end

-- Строка с монетами и иконками (как в PriceInTooltip). false, если не удалось.
local function PushCoinsLine(copper)
    if not (DescMoneyContainer and DescMoneyPanel) then return false end
    local container, panel
    local ok = pcall(function()
        local parts = Split(math.floor(copper))
        local group = common.GetAddonRelatedTextureGroup("Group01")
        container = mainForm:CreateWidgetByDesc(DescMoneyContainer)
        mainForm:AddChild(container)
        panel = mainForm:CreateWidgetByDesc(DescMoneyPanel)
        mainForm:AddChild(panel)
        -- ширину подгоняем под содержимое, а не под тултип с ценами
        local place = container:GetPlacementPlain()
        place.sizeX = 200
        container:SetPlacementPlain(place)

        local function addCoin(valueName, iconName, tag, amount, textureName, format)
            local v = panel:GetChildChecked(valueName, false)
            local icon = panel:GetChildChecked(iconName, false)
            if format then
                v:SetVal(tag, common.FormatInt(amount, "%d", format))
            else
                v:SetVal(tag, common.FormatInt(amount, "%d"))
            end
            icon:SetBackgroundTexture(group:GetTexture(textureName))
            container:PushBack(v)
            container:PushBack(icon)
        end
        if parts[1] > 0 then addCoin("ValueGold", "IconGold", "gold", parts[1], "CoinGold", " ") end
        if parts[2] > 0 then addCoin("ValueSilver", "IconSilver", "silver", parts[2], "CoinSilver") end
        if parts[3] > 0 then addCoin("ValueCopper", "IconCopper", "copper", parts[3], "CoinCopper") end
        cTooltip:PushBack(container)
        Track(container, moneyPool, panel)
    end)
    if not ok then
        pcall(function() if container then container:DestroyWidget() end end)
        pcall(function() if panel then panel:DestroyWidget() end end)
    end
    return ok
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
    local left = w:GetChildUnchecked("LineLeft", false)
    if left and left.ClearValues then
        pcall(function() left:ClearValues() end)
    end
    local right = w:GetChildUnchecked("LineRight", false)
    if right and right.ClearValues then
        pcall(function() right:ClearValues() end)
    end
end

local function RecycleAll()
    for i = #activeWidgets, 1, -1 do
        local item = activeWidgets[i]
        local w = item.widget
        pcall(function() cTooltip:Remove(w) end)
        if item.pool.destroy then
            pcall(function() w:DestroyWidget() end)
            if item.extra then
                pcall(function() item.extra:DestroyWidget() end)
            end
        else
            ResetWidget(w)
            table.insert(item.pool, w)
        end
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
    itemaname:SetClassVal("class", ItemQualityClass[content.quality] or "tip_base")
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

    -- Проклятый предмет, гильдейский, лимит владения, временный
    if content.isCursed then
        local cursed = AcquireSmartLine()
        SafeSetVal(cursed, "value", L("Cursed"))
        cursed:SetClassVal("class", "tip_red")
        cTooltip:PushBack(cursed)
        Track(cursed, smartLinePool)
    end
    if content.isGuildItem then
        local guild = AcquireSmartLine()
        SafeSetVal(guild, "value", L("GuildItem"))
        guild:SetClassVal("class", "tip_golden")
        cTooltip:PushBack(guild)
        Track(guild, smartLinePool)
    end
    if content.ownershipLimit and content.ownershipLimit > 0 then
        local limit = AcquireSmartLine()
        SafeSetVal(limit, "value", L("OwnershipLimit") .. tostring(content.ownershipLimit))
        limit:SetClassVal("class", "tip_base")
        cTooltip:PushBack(limit)
        Track(limit, smartLinePool)
    end
    if content.temporary then
        local ms = content.temporary.remainingMs
        if not ms or ms <= 0 then ms = content.temporary.durationMs or 0 end
        local hours = math.floor(ms / 3600000)
        local minutes = math.floor((ms % 3600000) / 60000)
        local temp = AcquireSmartLine()
        SafeSetVal(temp, "value", L("TemporaryItem") .. tostring(hours) .. L("hoursShort")
            .. tostring(minutes) .. L("minutesShort"))
        temp:SetClassVal("class", "tip_red")
        cTooltip:PushBack(temp)
        Track(temp, smartLinePool)
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
    if content.isWeapon and not misc.hideDPS
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
    elseif misc.spellPower and misc.spellPower.base and misc.spellPower.base > 0 then
        -- среднее значение силы заклинаний, если min/max не заданы
        local sp = AcquireSmartLine()
        SafeSetVal(sp, "value", L("SpellPower") .. tostring(math.ceil(misc.spellPower.base)))
        sp:SetClassVal("class", "tip_base")
        cTooltip:PushBack(sp)
        Track(sp, smartLinePool)
    end

    -- Применение предмета (зелья и т.п.)
    if content.useDescription then
        local ok, useText = pcall(function()
            return userMods.FromWString(content.useDescription:ToWString())
        end)
        if ok and useText and string.len(useText) > 0 then
            local use = AcquireSmartLine()
            use:SetMultiline(true)
            use:SetWrapText(true)
            SafeSetVal(use, "value", L("UseEffect") .. useText)
            use:SetClassVal("class", "Common")
            cTooltip:PushBack(use)
            Track(use, smartLinePool)
        end
    end
    if content.useCooldownMs and content.useCooldownMs > 0 then
        local cd = AcquireSmartLine()
        SafeSetVal(cd, "value", L("Cooldown") .. FormatDuration(content.useCooldownMs))
        cd:SetClassVal("class", "tip_blue")
        cTooltip:PushBack(cd)
        Track(cd, smartLinePool)
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
        local specToShow = {}
        for i = 1, #spec do
            local v = spec[i].value or 0
            if v ~= 0 then specToShow[#specToShow + 1] = spec[i] end
            sumSpecStats = sumSpecStats + v
        end

        if #specToShow > 0 then
            local wtSpecStats = AcquireDoubleLine()
            SafeSetVal(wtSpecStats:GetChildChecked("LineLeft", false), "value", L("specStats"))
            wtSpecStats:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_white")
            SafeSetVal(wtSpecStats:GetChildChecked("LineRight", false),
                "value", tostring(math.ceil(sumSpecStats)))
            wtSpecStats:GetChildChecked("LineRight", false):SetClassVal("class", "StatPrimaryColor")
            wtSpecStats:GetChildChecked("LineRight", false):SetClassVal("size", "Size17")
            cTooltip:PushBack(wtSpecStats)
            Track(wtSpecStats, doubleLinePool)

            for i = 1, #specToShow do
                local SpecStat = AcquireDoubleLine()
                local value = common.FormatFloat(specToShow[i].value or 0, "%.2f")
                local tooltipName = specToShow[i].tooltipName
                    and userMods.FromWString(specToShow[i].tooltipName) or ""
                SafeSetVal(SpecStat:GetChildChecked("LineLeft", false),
                    "value", "+" .. userMods.FromWString(value) .. " " .. tooltipName)
                SpecStat:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
                cTooltip:PushBack(SpecStat)
                Track(SpecStat, doubleLinePool)
            end
        end

        -- miscStats
        local power   = misc.power   and misc.power.base   or 0
        local stamina = misc.stamina and misc.stamina.base or 0
        local wisdom  = misc.wisdom  and misc.wisdom.base  or 0

        local sumStats = power + stamina + wisdom
        if sumStats > 0 then
            local stats = AcquireDoubleLine()
            SafeSetVal(stats:GetChildChecked("LineLeft", false), "value", L("Stats"))
            stats:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_white")
            SafeSetVal(stats:GetChildChecked("LineRight", false),
                "value", tostring(math.ceil(sumStats)))
            stats:GetChildChecked("LineRight", false):SetClassVal("class", "StatPrimaryColor")
            stats:GetChildChecked("LineRight", false):SetClassVal("size", "Size17")
            cTooltip:PushBack(stats)
            Track(stats, doubleLinePool)

            if power > 0 then
                local statPower = AcquireDoubleLine()
                SafeSetVal(statPower:GetChildChecked("LineLeft", false),
                    "value", "+" .. userMods.FromWString(common.FormatFloat(power, "%.1f"))
                        .. L("statPower"))
                statPower:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
                cTooltip:PushBack(statPower)
                Track(statPower, doubleLinePool)
            end

            if stamina > 0 then
                local statStamina = AcquireDoubleLine()
                SafeSetVal(statStamina:GetChildChecked("LineLeft", false),
                    "value", "+" .. userMods.FromWString(common.FormatFloat(stamina, "%.1f"))
                        .. L("statStamina"))
                statStamina:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
                cTooltip:PushBack(statStamina)
                Track(statStamina, doubleLinePool)
            end

            if wisdom > 0 then
                local statWisdom = AcquireDoubleLine()
                SafeSetVal(statWisdom:GetChildChecked("LineLeft", false),
                    "value", "+" .. userMods.FromWString(common.FormatFloat(wisdom, "%.1f"))
                        .. L("statWisdom"))
                statWisdom:GetChildChecked("LineLeft", false):SetClassVal("class", "tip_base")
                cTooltip:PushBack(statWisdom)
                Track(statWisdom, doubleLinePool)
            end
        end

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
        if IsResistanceSlot(content.dressSlot) and HasResistances(bonus) then
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

    -- Сетовый бонус, мета-улучшение, руна
    local extras = {}
    local sb = content.setBonus
    if sb and sb.hasSetBonus and sb.name then
        extras[#extras + 1] = { text = L("SetBonus") .. userMods.FromWString(sb.name), class = "tip_golden" }
        if sb.description then
            extras[#extras + 1] = { value = sb.description, multiline = true }
        end
    end
    local meta = content.meta
    if meta then
        if meta.isInactive then
            extras[#extras + 1] = { text = L("MetaInactive"), class = "tip_red" }
        elseif meta.hasMetaState and meta.improvement then
            extras[#extras + 1] = { text = L("MetaImprovement")
                .. userMods.FromWString(common.FormatFloat(meta.improvement, "%.1f")) .. "%", class = "tip_base" }
        end
    end
    local rune = content.rune
    if rune then
        if rune.level then
            extras[#extras + 1] = { text = L("RuneLevel") .. tostring(rune.level), class = "tip_base" }
        end
        if rune.offensiveBonus and rune.offensiveBonus > 0 then
            extras[#extras + 1] = { text = L("RuneOffense")
                .. userMods.FromWString(common.FormatFloat(rune.offensiveBonus, "%.1f")) .. "%", class = "tip_base" }
        end
        if rune.defensiveBonus and rune.defensiveBonus > 0 then
            extras[#extras + 1] = { text = L("RuneDefense")
                .. userMods.FromWString(common.FormatFloat(rune.defensiveBonus, "%.1f")) .. "%", class = "tip_base" }
        end
    end
    if #extras > 0 then
        if widgets_after_separator_1 then
            local sepE = AcquireSeparator()
            cTooltip:PushBack(sepE)
            Track(sepE, separatorPool)
        end
        for i = 1, #extras do
            local e = extras[i]
            if e.multiline then
                local w = AcquireDescriptionLine()
                SafeSetVal(w, "value", e.value)
                w:SetMultiline(true)
                w:SetWrapText(true)
                cTooltip:PushBack(w)
                Track(w, descriptionPool)
            else
                local w = AcquireSmartLine()
                SafeSetVal(w, "value", e.text)
                w:SetClassVal("class", e.class)
                cTooltip:PushBack(w)
                Track(w, smartLinePool)
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

    -- Количество в стопке и цена продажи торговцу
    local stackInfo = content.stackInfo
    if stackInfo and stackInfo.limit and stackInfo.limit > 1 then
        local st = AcquireSmartLine()
        SafeSetVal(st, "value", L("StackCount") .. tostring(stackInfo.count or 1)
            .. "/" .. tostring(stackInfo.limit))
        st:SetClassVal("class", "tip_white")
        cTooltip:PushBack(st)
        Track(st, smartLinePool)
    end
    local vendorPrice = content.vendorPrice
    if vendorPrice and vendorPrice.sellPrice and vendorPrice.sellPrice > 0 then
        if not PushCoinsLine(vendorPrice.sellPrice) then
            -- запасной вариант без иконок
            local pr = AcquireSmartLine()
            SafeSetVal(pr, "value", L("SellPrice") .. FormatCoins(vendorPrice.sellPrice))
            pr:SetClassVal("class", "tip_base")
            cTooltip:PushBack(pr)
            Track(pr, smartLinePool)
        end
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