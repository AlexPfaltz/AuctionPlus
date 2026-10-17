local ContextAuction = common.GetAddonMainForm("ContextAuction")
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

local PlaceholderOrange = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("PlaceholderOrange")
local UAMContainer = common.GetAddonMainForm("UserAddonManager"):GetChildChecked("List", true)
local btSettings = mainForm:GetChildChecked("Settings", false)
local btSettingsFound = false

TabAll:SetSmartPlacementPlain({alignX = WIDGET_ALIGN_LOW, posX = 30})
TabBids:SetSmartPlacementPlain({alignX = WIDGET_ALIGN_LOW, posX = 190})
TabOwner:SetSmartPlacementPlain({alignX = WIDGET_ALIGN_LOW, posX = 350})

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
function GetColorByQuality( quality )
	return CSSClassColor[ ItemQualityClass[ quality ] ]
end

function IsEmptyTable( tab )
	for id, value in pairs(tab) do
		return false
	end
	return true
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
		for coinId, ratio in pairs(conversion) do
			info[coinId] = math.floor(count / ratio)
			count = count - info[coinId] * ratio
		end
	else
		for coinId, ratio in pairs(conversion) do
			info[coinId] = 0
			info.zero = true
		end
	end
	return info
end

function Merge(info)
	local count = nil
	if not IsEmptyTable(info) then
		count = 0
		if not info.zero then
			for coinId, ratio in pairs(conversion) do	
				local sysId = sysCoinId[coinId]
				
				if info[ sysId ] then
					count = count + info[ sysId ] * ratio
				end
			end
		end
	end
	return count
end

function GetMoney(widget)
	--common.LogInfo("common", "type wt - ", tostring(type(widget)), ", name wt - ", tostring(widget:GetName()))

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
	--common.LogInfo("common", "type wt - ", tostring(type(widget)), ", name wt - ", tostring(widget:GetName()))

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
	for i = 0, table.getsize(roots)-1 do
  		local categoryInfo = itemLib.GetCategoryInfo(roots[i])
  		if categoryInfo then
    		local RootName = userMods.FromWString(categoryInfo.name)
			RootCategoryID[RootName] = roots[i]
			if categoryInfo.root == true then
  				local childs = itemLib.GetChildCategories(roots[i])
  				for j = 0, table.getsize(childs)-1 do
    				local categoryInfo = itemLib.GetCategoryInfo( childs[j] )
    				if categoryInfo then
      					local ChildName = userMods.FromWString(categoryInfo.name)
						ChildCategoryID[ChildName] = childs[j]
    				end
  				end
			end
		end
	end
end

function GetPage(CurPage)
	if not auction.IsSearchInProgress() then
		auction.Search(SearchFilter, AUCTION_ORDERFIELD_NONE, true, CurPage)
	end
end

function SlashCMD(params)
	local text = userMods.FromWString(params.text)
	if text == "/opl" then
		ShowOptionsPanel()
	end
end

function GetLastScan(table)
	local maxMS, date, values
	for k, v in pairs(table) do
		if not maxMS or maxMS < v.timeMS then
			maxMS = v.timeMS
		end
		if maxMS == v.timeMS then
			date = k
			values = v
		end
	end
	return date, values
end

function GetInfoForTooltip(itemInfo)
	local infoForTooltip = itemInfo

	infoForTooltip.quality = itemLib.GetQuality(itemInfo.id).quality

	local itemBinding = itemLib.GetBindingInfo(itemInfo.id)
	if itemBinding then
		infoForTooltip.isBound = itemBinding.isBound
		infoForTooltip.binding = itemBinding.binding
	end

	local itemClassId = itemLib.GetClass(itemInfo.id)
	local itemClassInfo = itemClassId and itemLib.GetClassInfo(itemClassId)
	local itemClassName = itemClassInfo and itemClassInfo.name
	infoForTooltip.class = itemClassName

	infoForTooltip.conditions = itemLib.GetDressConditions(itemInfo.id)

	infoForTooltip.bonus = itemLib.GetBonus(itemInfo.id)
	infoForTooltip.gearScore = itemLib.GetGearScore(itemInfo.id)

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
	local SumStats = power + stamina
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
	local TRANSPARENT_BLACK = { a = 0, r = 0, g = 0, b = 0 }
	local CURSED = { a = 1, r = 150/255, g = 0, b = 0 }
	local color = quality and quality > 2 and GetItemQualityCSSColor{ quality = quality, isCursed = isCursed } or TRANSPARENT_BLACK
	color.a = 0.5
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

function AddButtonSettings()
	if btSettingsFound then return end
	for i = 0, UAMContainer:GetElementCount()-1 do
		local LabelText =UAMContainer:At(i):GetChildChecked("Label", false)
		local name = userMods.FromWString(LabelText:GetWString())
		if string.find(name, GetLocalizedText("AddonName")) then
			UAMContainer:At(i):AddChild(btSettings)
			btSettings:Show(true)
			btSettingsFound = true
			break
		end
	end
end

function UamIsVisible(widget)
	if widget:IsVisibleEx() and btSettingsFound == false then
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
        return nil
    end
    local ok, auctions = pcall(auction.GetAuctions)
    if not ok or not auctions then
        return nil
    end
    return auctions
end

function Init()
	common.RegisterEventHandler(WIDGET_SHOW_CHANGED, "EVENT_WIDGET_SHOW_CHANGED")
	common.RegisterEventHandler(SlashCMD, "EVENT_UNKNOWN_SLASH_COMMAND")
	AuctionMainPanel:SetOnShowNotification(true)
	UAMContainer:SetOnShowNotification(true)
	LoadAddonFromUam()
end

Init()