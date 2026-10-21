Global("btTabBuy", mainForm:GetChildChecked("TabBuy", false))
local ListBuy = {}
local wtListBuy = mainForm:GetChildChecked("ListBuy", false)
local StatusBar = wtListBuy:GetChildChecked("StatusBar", false)
local btBuySelected = wtListBuy:GetChildChecked("BuySelected", false)
local btButtonSearch = wtListBuy:GetChildChecked("ButtonSearch", false)
local Container = wtListBuy:GetChildChecked("Container", false)
--InfoBar позиция под контейнером для выкупа выбранного лота
local wtInfoBar = wtListBuy:GetChildChecked("InfoBar", false)
local wtInfoBarLots =  wtInfoBar:GetChildChecked("Lots", false)
local wtInfoBarSlot = wtInfoBar:GetChildChecked("Slot", false)
local wtInfoBarName = wtInfoBar:GetChildChecked("Name", false)
local wtInfoBarPrice = wtInfoBar:GetChildChecked("Price", false)

local wtSortBar = wtListBuy:GetChildChecked("SortBar", false)
local btSortNumLots = wtSortBar:GetChildChecked("NumLots", false)
local btSortItemName = wtSortBar:GetChildChecked("ItemName", false)
local btSortPricePerUnit = wtSortBar:GetChildChecked("PricePerUnit", false)
local btSortPriceBuyOut = wtSortBar:GetChildChecked("PriceBuyOut", false)
local iconNumLots = wtSortBar:GetChildChecked("IconNumLots", false)
local iconPricePerUnit = wtSortBar:GetChildChecked("IconPricePerUnit", false)
local iconBuyOut = wtSortBar:GetChildChecked("IconBuyOut", false)
local txSortNone = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortNone")
local txSortUp = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortUp")
local txSortDown = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortDown")
--
local wtDescLine = nil
local CurrentSelectedLine = false
local SortBuyOutInAscendingOrder = false
local SortPricePerUnitInAscendingOrder = false
local SortNumLotsInAscendingOrder = false
local Lines = {}
local LotForBuy = {}
local BuyoutSelected = false
local CountAuctions = 0
local auctionsPage = 0
local auctionsPageCount = 0

btTabBuy:SetVal("button_label", userMods.ToWString(GetLocalizedText("btTabBuy")))
AuctionMainPanel:AddChild(wtListBuy)
AuctionMainPanel:AddChild(btTabBuy)

function GetMoneyFromSearchBar(self)
	local count = {}
	local sysCoinId = {
		[1] = "gold",
		[2] = "silver",
		[3] = "copper"
	}
	if self:GetName() == "BuyOutMin" then
		for coinId, sysId in pairs(sysCoinId) do
			count[sysId] = self:GetChildChecked("searchbar.buyoutMin."..sysId, false):GetText():ToInt()
		end
	end
	if self:GetName() == "BuyOutMax" then
		for coinId, sysId in pairs(sysCoinId) do
			count[sysId] = self:GetChildChecked("searchbar.buyoutMax."..sysId, false):GetText():ToInt()
		end
	end
	local c = Merge(count)
	return c
end

local function MakeWoDKey(itemName, GS, SumSpecStats, SumStats, buyoutPrice)
    return string.format("%s|%d|%d|%d|%d",
        itemName, GS or 0, SumSpecStats or 0, SumStats or 0, buyoutPrice or 0)
end

ListBuy.CreateLine = function(auctionInfo, WoD)
    local line = {}
	if not wtDescLine then
		line.widget = wtListBuy:GetChildChecked("ItemLine", false)
		wtDescLine = line.widget:GetWidgetDesc()
	else
		line.widget = mainForm:CreateWidgetByDesc(wtDescLine)
		mainForm:AddChild(line.widget)
	end
	
	local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
	local itemQuality = itemLib.GetQuality(auctionInfo.itemId)
	local itemName = userMods.FromWString(itemInfo.name)
	local quality = itemQuality and itemQuality.quality
	local itemCount = itemLib.GetStackInfo(auctionInfo.itemId).count
	local PriceBuyOut = auctionInfo.buyoutPrice
	local PricePerUnit = PriceBuyOut / itemCount
	local SplitPriceBuyOut = Split(PriceBuyOut)
	local SplitPricePerUnit = Split(PricePerUnit)
	
	line.infoForTooltip = GetInfoForTooltip(itemInfo) --Инфа для тултипа

	--Закинем всю инфу в таблицу для дальнейшего использования, что бы не искать заного
	local infoForBuy = {}
	infoForBuy.name = itemInfo.name
	infoForBuy.icon = itemInfo.icon
	infoForBuy.quality = quality
	infoForBuy.count = itemCount
	infoForBuy.buyoutprice = PriceBuyOut
	infoForBuy.priceperunit = PricePerUnit
	line.infoForBuy = infoForBuy

	--Заполним позицию
	line.button = line.widget:GetChildChecked("Button", false)
	line.lots = line.widget:GetChildChecked("Lots", false)
	line.lotsValue = 1
	line.lots:SetVal("value", common.FormatInt(line.lotsValue, "%d"))
	local UniSlot = line.widget:GetChildChecked("ItemSlot", false)
	FillUniSlot(UniSlot, itemInfo.icon, quality, false, itemCount, nil)

	line.itemName = line.widget:GetChildChecked("ItemName", false)
	line.itemName:SetClassVal( "class", ItemQualityClass[quality])
	line.itemName:SetVal("itemname", itemInfo.name)
	
	--Заполняем виджет цены за штуку
	line.gold1 = line.widget:GetChildChecked("PricePerUnit", false):GetChildChecked("Gold", false)
	line.gold1:SetVal("value", common.FormatInt(SplitPricePerUnit[1], "%d", " "))
	line.silver1 = line.widget:GetChildChecked("PricePerUnit", false):GetChildChecked("Silver", false)
	line.silver1:SetVal("value", common.FormatInt(SplitPricePerUnit[2], "%d"))
	line.copper1 = line.widget:GetChildChecked("PricePerUnit", false):GetChildChecked("Copper", false)
	line.copper1:SetVal("value", common.FormatInt(SplitPricePerUnit[3], "%d"))
	line.icongold1 = line.widget:GetChildChecked("PricePerUnit", false):GetChildChecked("IconGold", false)
	line.icongold1:SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinGold"))
	line.iconsilver1 = line.widget:GetChildChecked("PricePerUnit", false):GetChildChecked("IconSilver", false)
	line.iconsilver1:SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinSilver"))
	line.iconcopper1 = line.widget:GetChildChecked("PricePerUnit", false):GetChildChecked("IconCopper", false)	
	line.iconcopper1:SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinCopper"))
	
	--Заполняем виджет цена выкупа
	line.gold2 = line.widget:GetChildChecked("PriceBuyOut", false):GetChildChecked("Gold", false)
	line.gold2:SetVal("value", common.FormatInt(SplitPriceBuyOut[1], "%d", " "))
	line.silver2 = line.widget:GetChildChecked("PriceBuyOut", false):GetChildChecked("Silver", false)
	line.silver2:SetVal("value", common.FormatInt(SplitPriceBuyOut[2], "%d"))
	line.copper2 = line.widget:GetChildChecked("PriceBuyOut", false):GetChildChecked("Copper", false)
	line.copper2:SetVal("value", common.FormatInt(SplitPriceBuyOut[3], "%d"))
	line.icongold2 = line.widget:GetChildChecked("PriceBuyOut", false):GetChildChecked("IconGold", false)
	line.icongold2:SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinGold"))
	line.iconsilver2 = line.widget:GetChildChecked("PriceBuyOut", false):GetChildChecked("IconSilver", false)
	line.iconsilver2:SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinSilver"))
	line.iconcopper2 = line.widget:GetChildChecked("PriceBuyOut", false):GetChildChecked("IconCopper", false)	
	line.iconcopper2:SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinCopper"))
	if not WoD then
		local name = itemName .. itemCount .. PricePerUnit
		line.button:SetName(name)
		line.widget:SetName(name)
		line.widget:GetChildChecked("ItemSlot", false):SetName(name)
		Lines[name] = line
		Container:PushBack(Lines[name].widget)
		Lines[name].widget:Show(true)
	else
    	local GS, SumSpecStats, SumStats = GetStatsFromID(itemInfo.id)
    	local name = MakeWoDKey(itemName, GS, SumSpecStats, SumStats, buyoutPrice)
    	line.button:SetName(name)
    	line.widget:SetName(name)
    	line.widget:GetChildChecked("ItemSlot", false):SetName(name)
   		Lines[name] = line
    	Container:PushBack(Lines[name].widget)
    	Lines[name].widget:Show(true)
	end
end

ListBuy.AddLine = function(auctionInfo)
	local BuyoutPrice = auctionInfo.buyoutPrice
	if not BuyoutPrice or BuyoutPrice == nil or BuyoutPrice <= 0 then return end

	local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
	local itemName = userMods.FromWString(itemInfo.name)
	local itemCount = itemLib.GetStackInfo(auctionInfo.itemId).count
	local PricePerUnit = BuyoutPrice / itemCount

	if itemInfo.isWeapon or (itemInfo.dressSlot >= 0 and itemInfo.dressSlot <= 18) 
	or itemInfo.dressSlot == 29 or (itemInfo.dressSlot >= 43 and itemInfo.dressSlot <= 46) then
		local GS, SumSpecStats, SumStats = GetStatsFromID(itemInfo.id)
		local name = MakeWoDKey(itemName, GS, SumSpecStats, SumStats, BuyoutPrice)
		if Lines[name] then
			Lines[name].lotsValue = Lines[name].lotsValue + 1
			Lines[name].lots:SetVal("value", common.FormatInt(Lines[name].lotsValue, "%d"))
		else
			ListBuy.CreateLine(auctionInfo, true)
		end
	else
		local name = itemName .. itemCount .. PricePerUnit
		if Lines[name] then
			Lines[name].lotsValue = Lines[name].lotsValue + 1
			Lines[name].lots:SetVal("value", common.FormatInt(Lines[name].lotsValue, "%d"))
		else
			ListBuy.CreateLine(auctionInfo, false)
		end
	end
end

ListBuy.AssembleFilter = function()
	SearchFilter = {}
	if btTabBuy:GetVariant() == 1 then
		if BuyoutSelected then
			SearchFilter.name = userMods.ToWString(LotForBuy.name)
			SearchFilter.buyoutMin = tonumber(LotForBuy.buyoutprice)
			SearchFilter.buyoutMax = tonumber(LotForBuy.buyoutprice)
		else
			SearchFilter.name = SearchBar.name:GetText()
			if not auction.IsSearchNameValid(SearchFilter.name) then
    			StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("Invalid search name")))
    			return false
			end
			SearchFilter.rootCategory = RootCategoryID[userMods.FromWString(SearchBar.rootCategory:GetWString())] or nil
			SearchFilter.childCategory = ChildCategoryID[userMods.FromWString(SearchBar.childCategory:GetWString())] or nil
			SearchFilter.rarityMin = rarityList[GetLocalizedText(userMods.FromWString(SearchBar.rarityMin:GetWString()))] or nil
			SearchFilter.rarityMax = rarityList[GetLocalizedText(userMods.FromWString(SearchBar.rarityMax:GetWString()))] or nil
			SearchFilter.levelMin = SearchBar.levelMin:GetText():ToInt() or nil
			SearchFilter.levelMax = SearchBar.levelMax:GetText():ToInt() or nil
			SearchFilter.buyoutMin = GetMoneyFromSearchBar(SearchBar.buyoutMin)
			SearchFilter.buyoutMax = GetMoneyFromSearchBar(SearchBar.buyoutMax)
		end
	end
	return true
end

ListBuy.AuctionSearch = function(params)
	
	if AuctionSearchSuccess ~= nil and params and params.sysResult ~= nil
       and params.sysResult ~= AuctionSearchSuccess then
        return
    end

	if btTabBuy:GetVariant() == 1 then
		if BuyoutSelected == false then
			auctionsPage = auction.GetAuctionsPage()
            auctionsPageCount = params and params.totalPagesCount or auction.GetAuctionsPageCount()
			local auctions = SafeGetAuctions()
			if table.getsize(auctions) > 0 then
				--ListBuyFilled = true
				for _, auctionId in pairs(auctions) do
					local auctionInfo = auction.GetAuctionInfo(auctionId)
					if auctionInfo then
						ListBuy.AddLine(auctionInfo)
						CountAuctions = CountAuctions + 1
					end
				end
				if auctionsPage < auctionsPageCount then
					GetPage(auctionsPage+1)
					StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchInProgress")..tostring(auctionsPage)..GetLocalizedText("SeparatorSearchInProgress")..tostring(auctionsPageCount)))
				end	
				if auctionsPage == auctionsPageCount then
					StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchFinished")..tostring(CountAuctions)))
					CountAuctions = 0
				end
			end
		else
			if LotForBuy.name and LotForBuy.buyoutprice and LotForBuy.count and LotForBuy.countLots and LotForBuy.countLots > 0 then
				local auctionsCount = auction.GetAuctionsCount()
				auctionsPage = auction.GetAuctionsPage()
				auctionsPageCount = auction.GetAuctionsPageCount()
				local auctions = SafeGetAuctions()
				if table.getsize(auctions) > 0 then
					for _, auctionId in pairs(auctions) do
						local auctionInfo = auction.GetAuctionInfo(auctionId)
						local buyoutPrice = auctionInfo.buyoutPrice
						local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
						local itemName = userMods.FromWString(itemInfo.name)
						local seller = userMods.FromWString(auctionInfo.sellerName)
						local count = (itemLib.GetStackInfo(auctionInfo.itemId)).count
						if LotForBuy.countLots and LotForBuy.countLots > 0 then
							if itemName == LotForBuy.name and buyoutPrice == LotForBuy.buyoutprice and count == LotForBuy.count then
								auction.Buyout(auctionInfo.id)
								LotForBuy.countLots = LotForBuy.countLots - 1
							end
						else
							BuyoutSelected = false
							StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("BuyoutFinished")))
							ListBuy.StartSearch()
						end
					end
					if auctionsPage < auctionsPageCount then
						GetPage(auctionsPage+1)
						StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchSelectedForBuyOutInProgress")..tostring(auctionsPage)..GetLocalizedText("SeparatorSearchInProgress")..tostring(auctionsPageCount)))
					end
					if auctionsPage == auctionsPageCount then
						BuyoutSelected = false
						StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("BuyoutFinished")))
						ListBuy.StartSearch()
					end
				end
			else
				BuyoutSelected = false
				StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("BuyoutFinished")))
				ListBuy.StartSearch()
			end
		end
	end
end

function UpdPriceOnNumLots(price, numLots)
	local newPrice = numLots * price
	local SplitMoney = Split(newPrice)
	wtInfoBarPrice:GetChildChecked("Gold", false):SetVal("value", common.FormatInt(SplitMoney[1], "%d", " "))
	wtInfoBarPrice:GetChildChecked("Silver", false):SetVal("value", common.FormatInt(SplitMoney[2], "%d"))
	wtInfoBarPrice:GetChildChecked("Copper", false):SetVal("value", common.FormatInt(SplitMoney[3], "%d"))
end

ListBuy.FillSortBar = function()
	btSortNumLots:SetVal("button_label", userMods.ToWString(GetLocalizedText("NumLots")))
	btSortItemName:SetVal("button_label", userMods.ToWString(GetLocalizedText("ItemName")))
	btSortPricePerUnit:SetVal("button_label", userMods.ToWString(GetLocalizedText("PricePerUnit")))
	btSortPriceBuyOut:SetVal("button_label", userMods.ToWString(GetLocalizedText("PriceBuyOut")))
	iconNumLots:SetBackgroundTexture(txSortNone)
	iconPricePerUnit:SetBackgroundTexture(txSortNone)
	iconBuyOut:SetBackgroundTexture(txSortNone)
end

ListBuy.FillInfoBar = function(line)
	wtInfoBarLots:GetChildChecked("HeaderNumLots", false):SetVal("value", userMods.ToWString(GetLocalizedText("HeaderNumLots")))
	wtInfoBarLots:GetChildChecked("EditLine", false):SetText(userMods.ToWString(tostring(line.lotsValue)))
	FillUniSlot(wtInfoBarSlot, line.infoForBuy.icon, line.infoForBuy.quality, false, line.infoForBuy.count, nil)
	wtInfoBarSlot:SetName(CurrentSelectedLine)
	wtInfoBarName:SetVal("itemname", line.infoForBuy.name)
	wtInfoBarName:SetClassVal( "class", ItemQualityClass[line.infoForBuy.quality])
	wtInfoBarPrice:GetChildChecked("HeaderPrice", false):SetVal("value", userMods.ToWString(GetLocalizedText("TotalPrice")))
	wtInfoBarPrice:GetChildChecked("IconGold", false):SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinGold"))
	wtInfoBarPrice:GetChildChecked("IconSilver", false):SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinSilver"))
	wtInfoBarPrice:GetChildChecked("IconCopper", false):SetBackgroundTexture(common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinCopper"))
	UpdPriceOnNumLots(line.infoForBuy.buyoutprice, line.lotsValue)
	wtInfoBar:Show(true)
end

ListBuy.ClearInfoBar = function()
	wtInfoBar:Show(false)
	LotForBuy = {}
	wtListBuy:GetChildChecked("BuySelected", false):Enable(false)
	wtListBuy:GetChildChecked("BuySelected", false):Show(false)
end

function TheLastStageBeforeBuying(item, countLots)
	LotForBuy = {}
	LotForBuy.name = userMods.FromWString(item.infoForBuy.name)
	LotForBuy.buyoutprice = item.infoForBuy.buyoutprice
	LotForBuy.count = item.infoForBuy.count
	LotForBuy.countLots = countLots
	wtListBuy:GetChildChecked("BuySelected", false):Enable(true)
	wtListBuy:GetChildChecked("BuySelected", false):Show(true)
end

ListBuy.LinePressed = function(reaction)
	local index = reaction.sender

	if index == CurrentSelectedLine then
		Lines[CurrentSelectedLine].button:SetVariant(0)
		CurrentSelectedLine = false
		ListBuy.ClearInfoBar()
	else
		if CurrentSelectedLine == false then
			CurrentSelectedLine = index
			Lines[index].button:SetVariant(1)
		else
			Lines[CurrentSelectedLine].button:SetVariant(0)
			CurrentSelectedLine = index
			Lines[index].button:SetVariant(1)
		end
		ListBuy.FillInfoBar(Lines[index])
		TheLastStageBeforeBuying(Lines[index], Lines[index].lotsValue)
	end
end

ListBuy.reloadSortIcon = function()
	SortBuyOutInAscendingOrder = false
	SortPricePerUnitInAscendingOrder = false
	SortNumLotsInAscendingOrder = false
	iconNumLots:SetBackgroundTexture(txSortNone)
	iconBuyOut:SetBackgroundTexture(txSortNone)
	iconPricePerUnit:SetBackgroundTexture(txSortNone)
end

function ClearTabBuy()
    -- Уничтожаем виджеты из Lines (с защитой)
    for key, val in pairs(Lines) do
        if val and val.widget then
            pcall(function() val.widget:DestroyWidget() end)
        end
    end
    Lines = {}
    LotForBuy = {}
    CurrentSelectedLine = false
    -- Чистим контейнер (там могут быть виджеты, не попавшие в Lines)
    DestroyWidgetsInContainer(Container)
    ListBuy.ClearInfoBar()
    ListBuy.reloadSortIcon()
end

ListBuy.EditLineChanged = function()
	if btTabBuy:GetVariant() == 0 then return end
	local number = wtInfoBarLots:GetChildChecked("EditLine", false):GetText():ToInt()
	if number == nil or number == 0 then
		wtListBuy:GetChildChecked("BuySelected", false):Enable(false)
		UpdPriceOnNumLots(Lines[CurrentSelectedLine].infoForBuy.buyoutprice, 0)
	elseif number > Lines[CurrentSelectedLine].lotsValue then
		number = Lines[CurrentSelectedLine].lotsValue
		wtInfoBarLots:GetChildChecked("EditLine", false):SetText(common.FormatInt(number, "%d"))
		UpdPriceOnNumLots(Lines[CurrentSelectedLine].infoForBuy.buyoutprice, number)
		TheLastStageBeforeBuying(Lines[CurrentSelectedLine], number)
		wtListBuy:GetChildChecked("BuySelected", false):Enable(true)
	else
		UpdPriceOnNumLots(Lines[CurrentSelectedLine].infoForBuy.buyoutprice, number)
		TheLastStageBeforeBuying(Lines[CurrentSelectedLine], number)
		wtListBuy:GetChildChecked("BuySelected", false):Enable(true)
	end
end
ListBuy.EditLineFocusChanged = function()
	if btTabBuy:GetVariant() == 0 then return end
	local number = wtInfoBarLots:GetChildChecked("EditLine", false):GetText():ToInt()
	if not CurrentSelectedLine then return end
	if not number or number <= 1 then
		wtInfoBarLots:GetChildChecked("EditLine", false):SetText(common.FormatInt(1, "%d"))
		UpdPriceOnNumLots(Lines[CurrentSelectedLine].infoForBuy.buyoutprice, 1)
		TheLastStageBeforeBuying(Lines[CurrentSelectedLine], number)
		wtListBuy:GetChildChecked("BuySelected", false):Enable(true)
	end
end

ListBuy.GetMinValue = function(start, finish, valueForSort)
	local maxValue, Atfound, AtName, LineName
	for i = start, finish do
		LineName = Container:At(i):GetName()
		local linevalue
		if valueForSort == "priceperunit" then
			linevalue = Lines[LineName].infoForBuy.priceperunit
		elseif valueForSort == "buyoutprice" then
			linevalue = Lines[LineName].infoForBuy.buyoutprice
		elseif valueForSort == "lotsValue" then 
			linevalue = Lines[LineName].lotsValue
		end
		if not maxValue or maxValue > linevalue then
			maxValue = linevalue
		end
		if maxValue == linevalue then
			Atfound = i
			AtName = LineName
		end
	end
	return Atfound, AtName
end

ListBuy.GetMaxValue = function(start, finish, valueForSort)
	local maxValue, Atfound, AtName, LineName
	for i = start, finish do
		LineName = Container:At(i):GetName()
		local linevalue
		if valueForSort == "priceperunit" then
			linevalue = Lines[LineName].infoForBuy.priceperunit
		elseif valueForSort == "buyoutprice" then
			linevalue = Lines[LineName].infoForBuy.buyoutprice
		elseif valueForSort == "lotsValue" then 
			linevalue = Lines[LineName].lotsValue
		end
		if not maxValue or maxValue < linevalue then
			maxValue = linevalue
		end
		if maxValue == linevalue then
			Atfound = i
			AtName = LineName
		end
	end
	return Atfound, AtName
end

ListBuy.SortNumLots = function()
	if Container:GetElementCount() <=1 then return end
	SortBuyOutInAscendingOrder = false
	SortPricePerUnitInAscendingOrder = false
	iconBuyOut:SetBackgroundTexture(txSortNone)
	iconPricePerUnit:SetBackgroundTexture(txSortNone)
	if not SortNumLotsInAscendingOrder then
		SortNumLotsInAscendingOrder = true
		iconNumLots:SetBackgroundTexture(txSortDown)
	else
		SortNumLotsInAscendingOrder = false
		iconNumLots:SetBackgroundTexture(txSortUp)
	end
	local ElementCount = Container:GetElementCount() - 1
	for i = 0, ElementCount do
		local atMax, nameLines
		if SortNumLotsInAscendingOrder then
			atMax, nameLines = ListBuy.GetMinValue(i, ElementCount, "lotsValue")
		else
			atMax, nameLines = ListBuy.GetMaxValue(i, ElementCount, "lotsValue")
		end
		Container:RemoveAt(atMax)
		Container:Insert(i, Lines[nameLines].widget)
		Container:ForceReposition()
	end
	Container:EnsureVisible(Container:At(0))
end

ListBuy.SortPriceBuyOut = function()
	if Container:GetElementCount() <=1 then return end
	SortPricePerUnitInAscendingOrder = false
	SortNumLotsInAscendingOrder = false
	iconPricePerUnit:SetBackgroundTexture(txSortNone)
	iconNumLots:SetBackgroundTexture(txSortNone)
	if not SortBuyOutInAscendingOrder then
		SortBuyOutInAscendingOrder = true
		iconBuyOut:SetBackgroundTexture(txSortDown)
	else
		SortBuyOutInAscendingOrder = false
		iconBuyOut:SetBackgroundTexture(txSortUp)
	end
	local ElementCount = Container:GetElementCount() - 1
	for i = 0, ElementCount do
		local atMax, nameLines
		if SortBuyOutInAscendingOrder then
			atMax, nameLines = ListBuy.GetMinValue(i, ElementCount, "buyoutprice")
		else
			atMax, nameLines = ListBuy.GetMaxValue(i, ElementCount, "buyoutprice")
		end
		Container:RemoveAt(atMax)
		Container:Insert(i, Lines[nameLines].widget)
		Container:ForceReposition()
	end
	Container:EnsureVisible(Container:At(0))
end

ListBuy.SortPricePerUnit = function()
	if Container:GetElementCount() <=1 then return end
	SortBuyOutInAscendingOrder = false
	SortNumLotsInAscendingOrder = false
	iconBuyOut:SetBackgroundTexture(txSortNone)
	iconNumLots:SetBackgroundTexture(txSortNone)
	if not SortPricePerUnitInAscendingOrder then
		SortPricePerUnitInAscendingOrder = true
		iconPricePerUnit:SetBackgroundTexture(txSortDown)
	else
		SortPricePerUnitInAscendingOrder = false
		iconPricePerUnit:SetBackgroundTexture(txSortUp)
	end
	local ElementCount = Container:GetElementCount() - 1
	for i = 0, ElementCount do
		local atMax, nameLines
		if SortPricePerUnitInAscendingOrder then
			atMax, nameLines = ListBuy.GetMinValue(i, ElementCount, "priceperunit")
		else
			atMax, nameLines = ListBuy.GetMaxValue(i, ElementCount, "priceperunit")
		end
		Container:RemoveAt(atMax)
		Container:Insert(i, Lines[nameLines].widget)
		Container:ForceReposition()
	end
	Container:EnsureVisible(Container:At(0))
end

ListBuy.SortItemName = function()

end

ListBuy.slot_over = function(params)
	if btTabBuy:GetVariant() == 0 then return end
	local sender = params.sender
	local wtParent = params.widget:GetParent()
	local nameParent = wtParent:GetName()
	local content = Lines[nameParent].infoForTooltip or {}
	
	if params.active then
		CallTooltipItem(content, params.widget)
	else
		HideTooltip()
	end
end

ListBuy.BuySelected = function()
	BuyoutSelected = true
	if ListBuy.AssembleFilter() then GetPage(1) end
end

ListBuy.StartSearch = function()
	auctionsPage = 0
	auctionsPageCount = 0
	ClearTabBuy()
	if ListBuy.AssembleFilter() then GetPage(1) end
end

function OnAuctionBidResult(params)
    if not params or not params.sysResult then return end
    if params.sysResult == "ENUM_AuctionBidResultMsgResult_SUCCESS" then
        -- успех, можно обновить список
    elseif params.sysResult == "ENUM_AuctionBidResultMsgResult_OLDVERSION" then
        -- ждём EVENT_AUCTION_UPDATE_RESULT
    elseif params.sysResult == "ENUM_AuctionBidResultMsgResult_NOMONEY" then
        StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("Not enough money")))
    elseif params.sysResult == "ENUM_AuctionBidResultMsgResult_NOTFOUND" then
        StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("Lot not found")))
    elseif params.sysResult == "ENUM_AuctionBidResultMsgResult_SAMEUSER" then
        StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("Cannot buy from yourself")))
    end
end

function OpenTabBuy()
	if StartFullScan or StartScanForList then
		StopScan()
	end
	ShowTabOverlay()
	if btTabSell:GetVariant() == 1 then CloseTabSell() end
	AuctionMainPanel:GetChildChecked("List", false):Show(false)
	AuctionMainPanel:GetChildChecked("Selection", false):Show(false)
	AuctionMainPanel:GetChildChecked("Search", true):GetChildChecked("ButtonSearch", false):Show(false)
	ListBuy.FillSortBar()
	StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("WaitingForSearch")))
	btBuySelected:SetVal("button_label", userMods.ToWString(GetLocalizedText("BuySelected")))
	btButtonSearch:SetVal("button_label", userMods.ToWString(GetLocalizedText("ButtonSearch")))
	btTabBuy:SetVariant(1)
	wtListBuy:Show(true)
end

function CloseTabBuy()
	wtListBuy:Show(false)
	btTabBuy:SetVariant(0)
	ClearTabBuy()
	AuctionMainPanel:GetChildChecked("List", false):Show(true)
	AuctionMainPanel:GetChildChecked("Selection", false):Show(true)
	AuctionMainPanel:GetChildChecked("Search", true):GetChildChecked("ButtonSearch", false):Show(true)
	HideTabOverlay()
end

ListBuy.AuctionIsVisible = function(params)
	if params.addonName == "ContextAuction" and params.widget:GetName() == "Main" then
		if params.widget:IsVisible() then
			btTabBuy:SetVariant(0)
		else
			if btTabBuy:GetVariant() == 1 then
				CloseTabBuy()
			end
		end
	end		
end

ListBuy.Init = function()
	common.RegisterEventHandler(ListBuy.AuctionIsVisible, "EVENT_WIDGET_SHOW_CHANGED")
	common.RegisterEventHandler(ListBuy.AuctionSearch, "EVENT_AUCTION_SEARCH_RESULT")
	common.RegisterEventHandler(OnAuctionBidResult, "EVENT_AUCTION_BID_RESULT")
	common.RegisterReactionHandler(ListBuy.LinePressed, "LinePressed")
	common.RegisterReactionHandler(ListBuy.EditLineChanged, "EditLineChanged")
	common.RegisterReactionHandler(ListBuy.EditLineFocusChanged, "EditLineFocusChanged")
	common.RegisterReactionHandler(ListBuy.SortNumLots, "SortNumLots")
	common.RegisterReactionHandler(ListBuy.SortPriceBuyOut, "SortPriceBuyOut")
	common.RegisterReactionHandler(ListBuy.SortPricePerUnit, "SortPricePerUnit")
	common.RegisterReactionHandler(ListBuy.SortItemName, "SortItemName")
	common.RegisterReactionHandler(ListBuy.slot_over, "slot_over")
	common.RegisterReactionHandler(ListBuy.BuySelected, "BuySelected")
	common.RegisterReactionHandler(ListBuy.StartSearch, "StartSearch")
	common.RegisterReactionHandler(OpenTabBuy, "OpenTabBuy")
	--common.RegisterReactionHandler(CloseTabBuy, "CloseTabBuy")
	FindCategoryId()
end

ListBuy.Init()