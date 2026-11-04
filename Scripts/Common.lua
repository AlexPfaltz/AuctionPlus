local ContextAuction = common.GetAddonMainForm("ContextAuction")
-- Если родное окно аукциона недоступно (аддон выгружен/не загружен), не
-- инициализируем обход стокового UI, но не мешаем остальным скриптам
-- (база цен, тултипы). ListBuy/ListSell/TabScan проверяют этот флаг.
Global("AuctionPlusNoAuction", ContextAuction == nil or ContextAuction == false)
if not AuctionPlusNoAuction then
Global("AuctionSearchSuccess", "ENUM_AuctionSearchResultMsgResult_SUCCESS")
Global("AuctionCreateSuccess", "ENUM_AuctionCreateResultMsgResult_SUCCESS")
Global("AuctionBidSuccess",    "ENUM_AuctionBidResultMsgResult_SUCCESS")
Global("AuctionMainPanel", ContextAuction:GetChildUnchecked("Main", false))
Global("TabAll", AuctionMainPanel:GetChildChecked("TabAll", false))
Global("TabBids", AuctionMainPanel:GetChildChecked("TabBids", false))
Global("TabOwner", AuctionMainPanel:GetChildChecked("TabOwner", false))
Global("SearchFilter" , {})
Global("RootCategoryID", {})
Global("ChildCategoryID", {})
Global("rarityList", {
	["Junk"] = "ITEM_QUALITY_JUNK",
	["Goods"] = "ITEM_QUALITY_GOODS",
	["Common"] = "ITEM_QUALITY_COMMON",
	["Uncommon"] = "ITEM_QUALITY_UNCOMMON",
	["Rare"] = "ITEM_QUALITY_RARE",
	["Epic"] = "ITEM_QUALITY_EPIC",
	["Legendary"] = "ITEM_QUALITY_LEGENDARY",
	["Relic"] = "ITEM_QUALITY_RELIC",
	["Dragon"] = "ITEM_QUALITY_DRAGON"
})
Global("conversion", {
	[1] = 10000,
	[2] = 100,
	[3] = 1
})
Global("sysCoinId", {
	[1] = "Gold",
	[2] = "Silver",
	[3] = "Copper"
})

Global("ItemQualityClass", {
	[ITEM_QUALITY_JUNK] = "Junk",
	[ITEM_QUALITY_GOODS] = "Goods",
	[ITEM_QUALITY_COMMON] = "Common",
	[ITEM_QUALITY_UNCOMMON] = "Uncommon",
	[ITEM_QUALITY_RARE] = "Rare",
	[ITEM_QUALITY_EPIC] = "Epic",
	[ITEM_QUALITY_LEGENDARY] = "Legendary",
	[ITEM_QUALITY_RELIC] = "Relic",
	[ITEM_QUALITY_DRAGON] = "Dragon"
})
Global("CSSClassColor", {
	["Junk"] = {a = 1, r = 0.6, g = 0.6, b = 0.6},
	["Goods"] = {a = 1, r = 0.863, g = 0.863, b = 0.863},
	["Common"] = {a = 1, r = 0, g = 0.898, b = 0.149},
	["Uncommon"] = {a = 1, r = 0.125, g = 0.502, b = 1},
	["Rare"] = {a = 1, r = 0.753, g = 0.251, b = 1},
	["Epic"] = {a = 1, r = 1, g = 0.502, b = 0},
	["Legendary"] = {a = 1, r = 0, g = 1, b = 0.588},
	["Relic"] = {a = 1, r = 0.878, g = 1, b = 0.251},
	["Dragon"] = {a = 1, r = 0.984, g = 0.369, b = 0.678}
})
CSSClassColor["JunkCursed"] = CSSClassColor["Junk"]
CSSClassColor["GoodsCursed"] = CSSClassColor["Goods"]
CSSClassColor["CommonCursed"] = CSSClassColor["Common"]
CSSClassColor["UncommonCursed"] = CSSClassColor["Uncommon"]
CSSClassColor["RareCursed"] = CSSClassColor["Rare"]
CSSClassColor["EpicCursed"] = CSSClassColor["Epic"]
CSSClassColor["LegendaryCursed"] = CSSClassColor["Legendary"]
CSSClassColor["RelicCursed"] = CSSClassColor["Relic"]

Global("SearchBar", {
    ["name"] = ContextAuction:GetChildChecked("searchbar.name.edit", true),
    ["rootCategory"] = ContextAuction:GetChildChecked("searchbar.rootCategory.text", true),
    ["childCategory"] = ContextAuction:GetChildChecked("searchbar.childCategory.text", true),
    ["rarityMin"] = ContextAuction:GetChildChecked("searchbar.rarityMin.text", true),
    ["rarityMax"] = ContextAuction:GetChildChecked("searchbar.rarityMax.text", true),
    ["levelMin"] = ContextAuction:GetChildChecked("searchbar.levelMin.edit", true),
    ["levelMax"] = ContextAuction:GetChildChecked("searchbar.levelMax.edit", true),
    ["buyoutMin"] = ContextAuction:GetChildChecked("BuyOutMin", true),
    ["buyoutMax"] = ContextAuction:GetChildChecked("BuyOutMax", true)
})
Global("AddonTab", false)

local wtTabOverlay = mainForm:GetChildChecked("TabOverlay", false)
local PlaceholderOrange = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("PlaceholderOrange")
local UAMContainer = common.GetAddonMainForm("UserAddonManager"):GetChildChecked("List", true)
local btSettings = mainForm:GetChildChecked("Settings", false)
local btSettingsDesc = btSettings:GetWidgetDesc()
local lastStockTab = nil

TabAll:SetSmartPlacementPlain({alignX = WIDGET_ALIGN_LOW, posX = 30})
TabBids:SetSmartPlacementPlain({alignX = WIDGET_ALIGN_LOW, posX = 190})
TabOwner:SetSmartPlacementPlain({alignX = WIDGET_ALIGN_LOW, posX = 350})
AuctionMainPanel:AddChild(wtTabOverlay)

function GetItemQualityCSSClass( itemId )
	local quality, isCursed
	
	if type( itemId ) == "number" then
		local itemQuality = itemLib.GetQuality( itemId )
		quality = itemQuality and itemQuality.quality
		isCursed = itemLib.IsCursed( itemId )
	--end
	elseif type( itemId ) == "table" then
		quality = itemId.quality
		isCursed = itemId.isCursed
	end
	
	local class = quality and ItemQualityClass[ quality ]
	
	if class and isCursed then
		class = string.format( "%sCursed", class )
	end
	return class
end
------------------------------------------------------------------------------
function GetItemQualityCSSColor( itemId )
	local class = GetItemQualityCSSClass( itemId )
	return class and CSSClassColor[ class ]
end
------------------------------------------------------------------------------
function IsEmptyTable( tab )
	for id, value in pairs(tab) do
		return false
	end
	return true
end

-- Количество элементов в таблице, включая таблицы с индексами от 0.
-- Не используем table.getsize: в официальной документации его нет.
function TableSize( tab )
	local count = 0
	if tab then
		for _ in pairs( tab ) do
			count = count + 1
		end
	end
	return count
end

function Round( number, limit )
	local multiplier = 10 ^ ( limit or 0 )
	return math.floor( number * multiplier + 0.5 ) / multiplier
end

function Clamp( number, min, max )
	if min and max then
		max = math.max ( min, max )
		min = math.min ( min, max )
	end
	return number and ( ( max and number > max and max ) or ( min and number < min and min ) ) or number
end

function Split(count)
	local info = {}
	if count > 0 then
		for coinId = 1, 3 do
			local ratio = conversion[coinId]
			info[coinId] = math.floor(count / ratio)
			count = count - info[coinId] * ratio
		end
	else
		for coinId = 1, 3 do
			info[coinId] = 0
		end
		info.zero = true
	end
	return info
end

function Merge(info)
	local count = nil
	if not IsEmptyTable(info) then
		count = 0
		if not info.zero then
			for coinId = 1, 3 do
				local sysId = sysCoinId[coinId]
				if info[ sysId ] then
					count = count + info[ sysId ] * conversion[coinId]
				end
			end
		end
	end
	return count
end

function GetMoney(widget)
	local count = {}
	for coinId, sysId in pairs(sysCoinId) do
		if widget:GetName() == "Price" then
			count[sysId] = widget:GetChildChecked(sysId, true):GetWString():ToInt()
		else
			count[sysId] = widget:GetChildChecked(sysId, true):GetText():ToInt()
		end
	end
	return Merge(count)
end

function SetMoney(widget, money)
	if money and money >= 0 then
		local SplitMoney = Split(money)
		for coinId, sysId in pairs(sysCoinId) do
			if widget:GetName() == "Price" then
				widget:GetChildChecked(sysId, true):SetVal("value", common.FormatInt(SplitMoney[coinId], "%d"))
			else
				widget:GetChildChecked(sysId, true):SetText(common.FormatInt(SplitMoney[coinId], "%d"))
			end
		end
	else
		for coinId, sysId in pairs(sysCoinId) do
			if widget:GetName() == "Price" then
				widget:GetChildChecked(sysId, true):SetVal("value", common.GetEmptyWString())
			else
				widget:GetChildChecked(sysId, true):SetText(common.GetEmptyWString())
			end
		end
	end
end

function FindCategoryId()
	RootCategoryID = {}
	ChildCategoryID = {}
	local roots = itemLib.GetRootCategories()
	for i = 0, TableSize(roots)-1 do
		-- таблицы идентификаторов приходят с дырами: защищаемся от nil
		local rootId = roots[i]
		if rootId then
			local categoryInfo = itemLib.GetCategoryInfo(rootId)
			if categoryInfo then
				local RootName = userMods.FromWString(categoryInfo.name)
				RootCategoryID[RootName] = rootId
				if categoryInfo.root == true then
					local childs = itemLib.GetChildCategories(rootId)
					for j = 0, TableSize(childs)-1 do
						local childId = childs[j]
						if childId then
							local childInfo = itemLib.GetCategoryInfo(childId)
							if childInfo then
								local ChildName = userMods.FromWString(childInfo.name)
								ChildCategoryID[ChildName] = childId
							end
						end
					end
				end
			end
		end
	end
end

-- Запрос страницы результатов. Порядок сортировки необязателен
-- (по умолчанию без сортировки). Возвращает true, если запрос отправлен.
function GetPage(CurPage, orderField, ascending)
	if not auction.IsSearchInProgress() then
		auction.Search(SearchFilter, orderField or AUCTION_ORDERFIELD_NONE, ascending ~= false, CurPage)
		return true
	end
	return false
end

function SlashCMD(params)
	local text = userMods.FromWString(params.text)
	if text == "/opl" then
		ShowOptionsPanel()
	end
end

-- Проклятый ли предмет (всегда boolean)
function IsItemCursed(itemId)
	if not itemId then
		return false
	end
	return itemLib.IsCursed(itemId) == true
end

function GetInfoForTooltip(itemInfo)
	local infoForTooltip = itemInfo
	local id = itemInfo.id

	local itemQuality = itemLib.GetQuality(id)
	infoForTooltip.quality = itemQuality and itemQuality.quality
	infoForTooltip.isCursed = IsItemCursed(id)

	local itemBinding = itemLib.GetBindingInfo(id)
	if itemBinding then
		infoForTooltip.isBound = itemBinding.isBound
		infoForTooltip.binding = itemBinding.binding
	end

	local itemClassId = itemLib.GetClass(id)
	local itemClassInfo = itemClassId and itemLib.GetClassInfo(itemClassId)
	local itemClassName = itemClassInfo and itemClassInfo.name
	infoForTooltip.class = itemClassName

	infoForTooltip.conditions = itemLib.GetDressConditions(id)

	infoForTooltip.bonus = itemLib.GetBonus(id)
	infoForTooltip.gearScore = itemLib.GetGearScore(id)

	-- Дополнительные данные для тултипа.
	-- Все функции по документации возвращают table или nil, исключений не ожидается.
	infoForTooltip.setBonus = itemLib.GetSetBonusInfo(id)
	infoForTooltip.meta = itemLib.GetMetaInfo(id)
	infoForTooltip.rune = itemLib.GetRuneInfo(id)
	infoForTooltip.temporary = itemLib.GetTemporaryInfo(id)
	infoForTooltip.ownershipLimit = itemLib.GetOwnershipLimit(id)
	infoForTooltip.stackInfo = itemLib.GetStackInfo(id)
	infoForTooltip.vendorPrice = itemLib.GetPriceInfo(id)

	-- Применение предмета (зелья и т.п.): описание и перезарядка спелла
	local spellId = itemLib.GetSpell(id)
	if spellId then
		local spellDesc = spellLib.GetDescription(spellId)
		local spellCd = spellLib.GetCooldown(spellId)
		infoForTooltip.useDescription = spellDesc and spellDesc.description
		infoForTooltip.useCooldownMs = spellCd and spellCd.durationMs
	end

	return infoForTooltip
end

function GetStatsFromID(id)
	local gsInfo = itemLib.GetGearScore(id)
	local GS = 0
	if type(gsInfo) == "number" then
		GS = gsInfo
	elseif type(gsInfo) == "table" then
		GS = gsInfo.gearScore or gsInfo.value or 0
	end
	local bonus = itemLib.GetBonus(id) or {}
	local spec = bonus.specStats or {}
	local SumSpecStats = 0
	for i = 1, #spec do
		SumSpecStats = SumSpecStats + (spec[i].value or 0)
	end
	local misc = bonus.miscStats or {}
	local power = misc.power and misc.power.base or 0
	local stamina = misc.stamina and misc.stamina.base or 0
	local wisdom = misc.wisdom and misc.wisdom.base or 0
	local SumStats = power + stamina + wisdom
	return GS, SumSpecStats, SumStats
end

function FillUniSlot(widget, icon, quality, isCursed, stack, charges)
	local wtIcon = widget:GetChildChecked("Frame", false):GetChildChecked("Icon", false)
	if icon ~= nil then
		wtIcon:SetBackgroundTexture(icon)
	else
		wtIcon:SetBackgroundTexture(PlaceholderOrange)
	end
	--Quality
	local wtQuality = widget:GetChildChecked("Quality", false)
	local CURSED = { a = 1, r = 150/255, g = 0, b = 0 }
	-- копия цвета: правка alpha не должна затрагивать общую таблицу CSSClassColor
	local srcColor = quality and quality > 2 and GetItemQualityCSSColor{ quality = quality, isCursed = isCursed }
	local color = srcColor and { a = 0.5, r = srcColor.r, g = srcColor.g, b = srcColor.b }
		or { a = 0.5, r = 0, g = 0, b = 0 }
	wtQuality:SetForegroundColor( color )
	wtQuality:SetBackgroundColor( isCursed and CURSED or color )
	wtQuality:Show(true)

	--Count
	local wtCount = widget:GetChildChecked("Frame", false):GetChildChecked("Count", false)
	local countFormat = stack and charges and "SlotCountFormatExtended" or "SlotCountFormatNormal"
	local countStack = stack and stack > 1 and common.FormatInt( stack, "%dK5" ) or common.GetEmptyWString()
	local countCharges = charges and common.FormatInt( charges, "%dK5" ) or common.GetEmptyWString()
    local textValues = {
		format = common.GetAddonRelatedTextGroup( "UniSlotCountFormat"):GetText(countFormat),
		countStack = countStack,
		countCharges = countCharges
	}
	wtCount:SetTextValues( textValues )
	
	wtCount:Show( stack ~= nil or charges ~= nil )
end

function FindFreeSlots()
	local freeslots = {}
	local AllBagSlot = containerLib.GetItems( ITEM_CONT_INVENTORY )
	local size = containerLib.GetSize( ITEM_CONT_INVENTORY )
	local j = 1
	for i = 0, size - 1 do
		if AllBagSlot[i] == nil then
			freeslots[j] = i
			j = j + 1
		end
	end
	--for k, v in pairs(freeslots) do
	--	common.LogInfo("common", tostring(k), ", ", tostring(v))
	--end
	return freeslots
end

local function EnsureSettingsButton()
	if not btSettings or not btSettings:IsValid() then
		btSettings = mainForm:CreateWidgetByDesc(btSettingsDesc)
		mainForm:AddChild(btSettings)
	end
	return btSettings
end

local function RowName(row)
	local LabelText = row:GetChildUnchecked("Label", false) or row:GetChildUnchecked("Label", true)
	if not LabelText then return nil end
	return userMods.FromWString(LabelText:GetWString())
end

function AddButtonSettings()
	local localizedName = GetLocalizedText("AddonName")
	for i = 0, UAMContainer:GetElementCount()-1 do
		local row = UAMContainer:At(i)
		local name = row and RowName(row)
		if name and (string.find(name, localizedName, 1, true)
			or string.find(name, "AuctionPlus", 1, true)
			or string.find(name, "Auction+", 1, true)) then
			local button = EnsureSettingsButton()
			if button:GetParent() ~= row then
				row:AddChild(button)
			end
			button:Show(true)
			return
		end
	end
end

function UamIsVisible(widget)
	if widget:IsVisibleEx() then
		AddButtonSettings()
	end
end

function LoadAddonFromUam()
	if UAMContainer:IsVisibleEx() then
		AddButtonSettings()
	end
end

function WIDGET_SHOW_CHANGED(params)
	if params.addonName == "UserAddonManager" and params.widget:GetName() == "List" then
		UamIsVisible(params.widget)
	end
end

function SafeGetAuctions()
    if not AuctionMainPanel or not AuctionMainPanel:IsVisible() then
        return {}
    end
    return auction.GetAuctions()
end

function DestroyWidgetsInContainer(container)
    if not container then return end
    -- Виджет уничтожается только после отсоединения от контейнера:
    -- DestroyWidget по виджету внутри контейнера оставляет в нём
    -- InvalidWidgetSafe, и любое следующее обращение к элементам
    -- контейнера (включая IsValid) падает.
    while container:GetElementCount() > 0 do
        local w = container:At(0)
        container:RemoveAt(0)
        if w then
            w:DestroyWidget()
        end
    end
end

-- Выбранная сейчас "родная" вкладка (Все аукционы / Участник / Владелец)
local function GetActiveStockTab()
    for _, tab in ipairs({ TabAll, TabBids, TabOwner }) do
        if tab:GetVariant() == 1 then return tab end
    end
end

-- Выбранная сейчас "родная" вкладка (nil, если выбрана вкладка аддона)
function GetCurrentStockTab()
    return GetActiveStockTab()
end

-- Открытие вкладки аддона: запоминаем выбранную "родную" вкладку,
-- гасим её подсветку и кладём поверх оверлей (клик по нему возвращает назад).
function ShowTabOverlay()
    local active = GetActiveStockTab()
    if active then lastStockTab = active end
    if not lastStockTab then return end
    wtTabOverlay:SetPlacementPlain(lastStockTab:GetPlacementPlain())
    wtTabOverlay:Show(true)
    lastStockTab:SetVariant(0)
end

-- Закрытие вкладки аддона: убираем оверлей и возвращаем подсветку "родной"
-- вкладке, но только если движок не выбрал за это время другую
-- (иначе подсвечены окажутся сразу две).
function HideTabOverlay()
    wtTabOverlay:Show(false)
    if lastStockTab and not GetActiveStockTab() then
        lastStockTab:SetVariant(1)
    end
end

function CloseAddonTabs()
    if AddonTab == "buy" then
        CloseTabBuy()
    elseif AddonTab == "sell" then
        CloseTabSell()
    elseif AddonTab == "scan" then
        CloseTabScan()
    else
        HideTabOverlay()
    end
end

-- Пока открыта вкладка аддона, ни одна "родная" не должна быть выбрана.
-- Если выбрана - игрок кликнул по другой родной вкладке, закрываем свою.
function SyncAddonTabs()
    if AddonTab and GetActiveStockTab() then
        CloseAddonTabs()
    end
end

function TabOverlayPressed()
    CloseAddonTabs()
end

function OnSecondTimer()
    if AddonTab and AuctionMainPanel:IsVisible() then
        SyncAddonTabs()
    end
end

function Init()
	common.RegisterReactionHandler(TabOverlayPressed, "TabOverlayPressed")
	common.RegisterEventHandler(OnSecondTimer, "EVENT_SECOND_TIMER")
	common.RegisterEventHandler(WIDGET_SHOW_CHANGED, "EVENT_WIDGET_SHOW_CHANGED")
	common.RegisterEventHandler(SlashCMD, "EVENT_UNKNOWN_SLASH_COMMAND")
	AuctionMainPanel:SetOnShowNotification(true)
	UAMContainer:SetOnShowNotification(true)
	LoadAddonFromUam()
end

Init()

end