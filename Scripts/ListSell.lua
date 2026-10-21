Global("btTabSell", mainForm:GetChildChecked("TabSell", false))
local AuctionProperties = nil
local WaitingForEndSpliItem = false
local DescLine = nil
local CountAuctions = 0
local auctionsPage = 0
local auctionsPageCount = 0
local CurrentSelectedLine = nil
local txSortNone = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortNone")
local txSortUp = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortUp")
local txSortDown = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortDown")

local itemInfo = {}
local ListSell = {}
ListSell.widget = mainForm:GetChildChecked("ListSell", false)
ListSell.container = ListSell.widget:GetChildChecked("Container", false)
ListSell.slotId = nil
ListSell.pickSlotId = nil

local InfoBar = {}
InfoBar.widget = ListSell.widget:GetChildChecked("InfoBar", false)
InfoBar.UniSlot = {}
InfoBar.UniSlot.widget = InfoBar.widget:GetChildChecked("UniSlot", false)
InfoBar.UniSlot.Button = InfoBar.UniSlot.widget:GetChildChecked("Button", false)
InfoBar.UniSlot.Blink = InfoBar.UniSlot.widget:GetChildChecked("Blink", false)
InfoBar.Name = {}
InfoBar.Name.widget = InfoBar.widget:GetChildChecked("Name", false)
InfoBar.Name.text = InfoBar.Name.widget:GetChildChecked("Text", false)
InfoBar.Name.itemName = InfoBar.Name.widget:GetChildChecked("FormName", false):GetChildChecked("Text", false)
InfoBar.Quantity = {}
InfoBar.Quantity.widget = InfoBar.widget:GetChildChecked("Quantity", false)
InfoBar.Quantity.text = InfoBar.Quantity.widget:GetChildChecked("Text", false)
InfoBar.Quantity.edit = InfoBar.Quantity.widget:GetChildChecked("QuantityEdit", false)
InfoBar.StartPrice = {}
InfoBar.StartPrice.widget = InfoBar.widget:GetChildChecked("StartPrice", false)
InfoBar.StartPrice.text = InfoBar.StartPrice.widget:GetChildChecked("Text", false)
InfoBar.StartPrice.price = InfoBar.StartPrice.widget:GetChildChecked("PriceEdit", false)
InfoBar.BuyoutPrice = {}
InfoBar.BuyoutPrice.widget = InfoBar.widget:GetChildChecked("BuyoutPrice", false)
InfoBar.BuyoutPrice.text = InfoBar.BuyoutPrice.widget:GetChildChecked("Text", false)
InfoBar.BuyoutPrice.price = InfoBar.BuyoutPrice.widget:GetChildChecked("PriceEdit", false)
InfoBar.Duration = {}
InfoBar.Duration.widget = InfoBar.widget:GetChildChecked("Duration", false)
InfoBar.Duration.text = InfoBar.Duration.widget:GetChildChecked("Text", false)
InfoBar.Duration["12h"] = {}
InfoBar.Duration["12h"].wt = InfoBar.Duration.widget:GetChildChecked("12h", true)
InfoBar.Duration["12h"].text = InfoBar.Duration["12h"].wt:GetChildChecked("Text", false)
InfoBar.Duration["12h"].checkbox = InfoBar.Duration["12h"].wt:GetChildChecked("CheckBox", false)
InfoBar.Duration["24h"] = {}
InfoBar.Duration["24h"].wt = InfoBar.Duration.widget:GetChildChecked("24h", true)
InfoBar.Duration["24h"].text = InfoBar.Duration["24h"].wt:GetChildChecked("Text", false)
InfoBar.Duration["24h"].checkbox = InfoBar.Duration["24h"].wt:GetChildChecked("CheckBox", false)
InfoBar.Duration["36h"] = {}
InfoBar.Duration["36h"].wt = InfoBar.Duration.widget:GetChildChecked("36h", true)
InfoBar.Duration["36h"].text = InfoBar.Duration["36h"].wt:GetChildChecked("Text", false)
InfoBar.Duration["36h"].checkbox = InfoBar.Duration["36h"].wt:GetChildChecked("CheckBox", false)
InfoBar.Duration["48h"] = {}
InfoBar.Duration["48h"].wt = InfoBar.Duration.widget:GetChildChecked("48h", true)
InfoBar.Duration["48h"].text = InfoBar.Duration["48h"].wt:GetChildChecked("Text", false)
InfoBar.Duration["48h"].checkbox = InfoBar.Duration["48h"].wt:GetChildChecked("CheckBox", false)
InfoBar.Deposit = {}
InfoBar.Deposit.widget = InfoBar.widget:GetChildChecked("Deposit", false)
InfoBar.Deposit.text = InfoBar.Deposit.widget:GetChildChecked("Text", false)
InfoBar.Deposit.price = InfoBar.Deposit.widget:GetChildChecked("Price", false)
InfoBar.TotalPrice = {}
InfoBar.TotalPrice.widget = InfoBar.widget:GetChildChecked("TotalPrice", false)
InfoBar.TotalPrice.text = InfoBar.TotalPrice.widget:GetChildChecked("Text", false)
InfoBar.TotalPrice.price = InfoBar.TotalPrice.widget:GetChildChecked("Price", false)
InfoBar.btPost = InfoBar.widget:GetChildChecked("Post", false)

local SortBar = {}
SortBar.widget = ListSell.widget:GetChildChecked("SortBar", false)
SortBar.Price = {}
SortBar.Price.widget = SortBar.widget:GetChildChecked("Price", false)
SortBar.Price.icon = SortBar.Price.widget:GetChildChecked("IconPrice", false)
SortBar.Available = {}
SortBar.Available.widget = SortBar.widget:GetChildChecked("Available", false)
SortBar.Available.icon = SortBar.Available.widget:GetChildChecked("IconAvailable", false)

local StatusBar = ListSell.widget:GetChildChecked("StatusBar", false)

local RegWIdgetsIDs = {
	[1] = {id = DnD.AllocateDnDID(ListSell.widget), widget = ListSell.widget},
	[2] = {id = DnD.AllocateDnDID(InfoBar.widget), widget = InfoBar.widget},
	[3] = {id = DnD.AllocateDnDID(InfoBar.UniSlot.widget), widget = InfoBar.UniSlot.widget},
	[4] = {id = DnD.AllocateDnDID(InfoBar.UniSlot.Button), widget = InfoBar.UniSlot.Button}
}

--Присваиваем локализуемый текст виджетам
btTabSell:SetVal("button_label", userMods.ToWString(GetLocalizedText("btTabSell")))
InfoBar.Name.text:SetVal("value", GetLocalizedText("Name"))
InfoBar.Quantity.text:SetVal("value", GetLocalizedText("Quantity"))
InfoBar.StartPrice.text:SetVal("value", GetLocalizedText("StartPrice"))
InfoBar.BuyoutPrice.text:SetVal("value", GetLocalizedText("BuyoutPrice"))
InfoBar.Duration["12h"].text:SetVal("value", GetLocalizedText("12h"))
InfoBar.Duration["24h"].text:SetVal("value", GetLocalizedText("24h"))
InfoBar.Duration["36h"].text:SetVal("value", GetLocalizedText("36h"))
InfoBar.Duration["48h"].text:SetVal("value", GetLocalizedText("48h"))
InfoBar.Duration.text:SetVal("value", GetLocalizedText("Duration"))
InfoBar.Deposit.text:SetVal("value", GetLocalizedText("Deposit"))
InfoBar.TotalPrice.text:SetVal("value", GetLocalizedText("TotalPrice"))
InfoBar.btPost:SetVal("button_label", userMods.ToWString(GetLocalizedText("Post")))
SortBar.Price.widget:SetVal("button_label", userMods.ToWString(GetLocalizedText("Price")))
SortBar.Price.icon:SetBackgroundTexture(txSortNone)
SortBar.Price.sorted = "none"
SortBar.Available.widget:SetVal("button_label", userMods.ToWString(GetLocalizedText("Available")))
SortBar.Available.icon:SetBackgroundTexture(txSortNone)
SortBar.Available.sorted = "none"

--Отдаём свои виджеты окну аукциона
AuctionMainPanel:AddChild(ListSell.widget)
AuctionMainPanel:AddChild(btTabSell)
--
ListSell.GetInfo = function(itemId)
	itemInfo = itemLib.GetItemInfo(itemId)
	itemInfo = GetInfoForTooltip(itemInfo)
	itemInfo.stackCount = itemLib.GetStackInfo(itemId).count
	itemInfo.prices = itemLib.GetPriceInfo(itemId)
end

ListSell.SplitItem = function(count)
	local freeSlotFound = false
	local tableFreeSlots = FindFreeSlots()
	if tableFreeSlots and #tableFreeSlots > 0 then
		for i = 1, #tableFreeSlots do
			if avatar.InventoryCanPlaceItemToSlot(itemInfo.id, tableFreeSlots[i]) then
				--common.LogInfo("common", "free slot found")
				freeSlotFound = true
				--avatar.InventorySplitItem(ListSell.slotId, tableFreeSlots[i], count)
				containerLib.MoveSlotItem( ITEM_CONT_INVENTORY, ListSell.pickSlotId, ITEM_CONT_INVENTORY, tableFreeSlots[i], count)
				return true
			end
		end
		if freeSlotFound == false then
			--common.LogInfo("common", "free slot Not found")
			StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("free slot Not found")))
			return false
		end
	else
		--common.LogInfo("common", "not table free slots or table size < 0")
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("free slot Not found")))
		return false
	end
end

ListSell.ValidateSlot = function()
	--common.LogInfo("common", "ValidateSlot")
	local itemId = nil
	if ListSell.slotId or ListSell.slotId ~= nil then
		itemId = containerLib.GetItem( ITEM_CONT_INVENTORY, ListSell.slotId )
	end
	if itemId == nil or itemId ~= itemInfo.id then
		ListSell.slotId = nil
		InfoBar.Clear()
		InfoBar.DIsable()
		DestroyWidgetsInContainer(ListSell.container)
		return false
	else
		return true
	end
end

ListSell.CreateLine = function(name)
	local line = {}
	if not DescLine then
		line.widget = ListSell.widget:GetChildChecked("Line", false)
		DescLine = line.widget:GetWidgetDesc()
	else
		line.widget = mainForm:CreateWidgetByDesc(DescLine)
		mainForm:AddChild(line.widget)
	end
	line.widget:SetName(name)
	line.price = line.widget:GetChildChecked("Price", false)
	line.available = line.widget:GetChildChecked("Available", false)
	return line
end

ListSell.FillNewLine = function(price, count)
	local line = ListSell.CreateLine(tostring(price))
	SetMoney(line.price, price)
	line.available:SetVal("value", common.FormatInt(count, "%d"))
	return line
end

ListSell.UpdateLine = function(line, count)
	local available = line:GetChildChecked("Available", false)
	local value = available:GetWString():ToInt()
	--common.LogInfo('common', "value - ", tostring(value))
	value = value + count
	available:SetVal("value", common.FormatInt(value, "%d"))
end

ListSell.FindLine = function(name)
	local foundLine = nil
	for i = 0, ListSell.container:GetElementCount() - 1 do
		local nameAt = ListSell.container:At(i):GetName()
		if nameAt == name then
			foundLine = ListSell.container:At(i)
		end
	end
	return foundLine
end

ListSell.AddLine = function(auctionInfo)
	local BuyoutPrice = auctionInfo.buyoutPrice
	if not BuyoutPrice or BuyoutPrice == nil or BuyoutPrice <= 0 then return end

	local itemCount = itemLib.GetStackInfo(auctionInfo.itemId).count
	local PricePerUnit = BuyoutPrice/itemCount
	local nameLine = tostring(PricePerUnit)
	local line = ListSell.FindLine(nameLine)
	if line and line ~= nil then
		ListSell.UpdateLine(line, itemCount)
	else
		line = ListSell.FillNewLine(PricePerUnit, itemCount)
		line.widget:Show(true)
		ListSell.container:PushBack(line.widget)
	end
end

ListSell.AuctionSearch = function(params)

	 if AuctionSearchSuccess ~= nil and params and params.sysResult ~= nil
       and params.sysResult ~= AuctionSearchSuccess then
        return
    end
	
	if btTabSell:GetVariant() == 1 and InfoBar.UniSlot.widget:IsEnabled() then
		auctionsPage = auction.GetAuctionsPage()
		auctionsPageCount = auction.GetAuctionsPageCount()
		local auctions = SafeGetAuctions()
		if table.getsize(auctions) > 0 then
			for _, auctionId in pairs(auctions) do
				local auctionInfo = auction.GetAuctionInfo(auctionId)
				if auctionInfo then
					ListSell.AddLine(auctionInfo)
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
	end
end

ListSell.AssembleFilter = function()
	SearchFilter = {}
	if btTabSell:GetVariant() == 1 then
		SearchFilter.name = itemInfo.name
		--SearchFilter.rootCategory = itemLib.GetCategory(itemInfo.id)
		--SearchFilter.childCategory = 
		--SearchFilter.rarityMin = rarityList[GetLocalizedText(userMods.FromWString(SearchBar.rarityMin:GetWString()))] or nil
		--SearchFilter.rarityMax = rarityList[GetLocalizedText(userMods.FromWString(SearchBar.rarityMax:GetWString()))] or nil
		--SearchFilter.levelMin = SearchBar.levelMin:GetText():ToInt() or nil
		--SearchFilter.levelMax = SearchBar.levelMin:GetText():ToInt() or nil
		--SearchFilter.buyoutMin = GetMoneyFromSearchBar(SearchBar.buyoutMin)
		--SearchFilter.buyoutMax = GetMoneyFromSearchBar(SearchBar.buyoutMax)
	end
	return true
end

ListSell.StartSearch = function()
	SortBar.Reload()
	DestroyWidgetsInContainer(ListSell.container)
	auctionsPage = 0
	auctionsPageCount = 0
	if ListSell.AssembleFilter() then GetPage(1) end
end

ListSell.SortDown = function(param)
	for i = 0, ListSell.container:GetElementCount() - 1 do
		local value = nil
		local desiredvalue = nil
		local tempWt = nil
		local tempAt = nil

		for j = i, ListSell.container:GetElementCount() - 1 do
			if param == "Price" then
				desiredvalue = GetMoney(ListSell.container:At(j):GetChildChecked("Price", false))
			elseif param == "Available" then
				desiredvalue = ListSell.container:At(j):GetChildChecked("Available", false):GetWString():ToInt()
			end

			if value == nil or value > desiredvalue then
				value = desiredvalue
			end

			if value == desiredvalue then
				tempAt = j
				tempWt = ListSell.container:At(j)
			end
		end

		ListSell.container:RemoveAt(tempAt)
		ListSell.container:Insert(i, tempWt)
		ListSell.container:ForceReposition()
	end
	ListSell.container:EnsureVisible(ListSell.container:At(0))
end

ListSell.SortUp = function(param)
	for i = 0, ListSell.container:GetElementCount() - 1 do
		local value = nil
		local desiredvalue = nil
		local tempWt = nil
		local tempAt = nil

		for j = i, ListSell.container:GetElementCount() - 1 do
			if param == "Price" then
				desiredvalue = GetMoney(ListSell.container:At(j):GetChildChecked("Price", false))
			elseif param == "Available" then
				desiredvalue = ListSell.container:At(j):GetChildChecked("Available", false):GetWString():ToInt()
			end

			if value == nil or value < desiredvalue then
				value = desiredvalue
			end

			if value == desiredvalue then
				tempAt = j
				tempWt = ListSell.container:At(j)
			end
		end

		ListSell.container:RemoveAt(tempAt)
		ListSell.container:Insert(i, tempWt)
		ListSell.container:ForceReposition()
	end
	ListSell.container:EnsureVisible(ListSell.container:At(0))
end

ListSell.button_pressed = function(params)
	if btTabSell:GetVariant() == 0 then return end
	--common.LogInfo("common", "params.sender = ", tostring(params.sender))
	if params.sender == "Post" then
		local count = InfoBar.Quantity.edit:GetText():ToInt()
		itemInfo.stackCount = itemLib.GetStackInfo(itemInfo.id).count
		local startprice = GetMoney(InfoBar.StartPrice.price)
		local buyoutprice = GetMoney(InfoBar.BuyoutPrice.price)
		if startprice > buyoutprice then
			StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("startprice > buyoutprice")))
		else
			if count < itemInfo.stackCount then
				if ListSell.SplitItem(count) then
					WaitingForEndSpliItem = true
				end
			else
				local itemId = itemInfo.id
				startprice = startprice * count
				buyoutprice = buyoutprice * count
				local duration = CheckDuration()
				if not auction.IsCreationInProgress() then
					auction.CreateForItem(itemId, startprice, buyoutprice, duration)
				end
			end
			ListSell.ValidateSlot()
		end
	elseif params.sender == "Line" then
		local Parent = params.widget:GetParent()
		if CurrentSelectedLine ~= nil then
			CurrentSelectedLine:SetVariant(0)
		end
		if params.widget:GetVariant() == 1 then
			params.widget:SetVariant(0)
			CurrentSelectedLine = nil
		else
			params.widget:SetVariant(1)
			CurrentSelectedLine = params.widget
		end
		local money = tonumber(Parent:GetName())
		local quantity = InfoBar.Quantity.edit:GetText():ToInt() or 0
		SetMoney(InfoBar.BuyoutPrice.price, money)
		SetMoney(InfoBar.TotalPrice.price, money * quantity)
		InfoBar.CheckValidateValues()
	end
	
end

ListSell.AuctionIsVisible = function(params)
	if params.addonName == "ContextAuction" and params.widget:GetName() == "Main" then
		if params.widget:IsVisible() then
			btTabSell:SetVariant(0)
		else
			if btTabSell:GetVariant() == 1 then
				CloseTabSell()
			end
			if WaitingForEndSpliItem then WaitingForEndSpliItem = false end
		end
	end		
end

InfoBar.Fill = function(itemId)
	AuctionProperties = auction.GetProperties()
	ListSell.GetInfo(itemId)
	FillUniSlot(InfoBar.UniSlot.widget, itemInfo.icon, itemInfo.quality, false, nil, nil)
	InfoBar.Name.itemName:SetVal("value", itemInfo.name)
	InfoBar.Name.itemName:SetClassVal("class", ItemQualityClass[itemInfo.quality])
	InfoBar.Quantity.edit:SetText(common.FormatInt(itemInfo.stackCount, "%d"))
	SetMoney(InfoBar.StartPrice.price, itemInfo.prices.auctionPrice)
	InfoBar.Duration["12h"].checkbox:SetVariant(1)
	SetMoney(InfoBar.Deposit.price, GetPercentDuration(CheckDuration()) * itemInfo.prices.auctionPrice * (InfoBar.Quantity.edit:GetText():ToInt()) / 100)
	InfoBar.CheckValidateValues()
	return true
end

InfoBar.Enable = function()
	InfoBar.UniSlot.widget:Enable(true)
	InfoBar.Quantity.widget:Enable(true)
	InfoBar.Quantity.widget:SetTransparentInput(false)
	InfoBar.StartPrice.widget:Enable(true)
	InfoBar.StartPrice.widget:SetTransparentInput(false)
	InfoBar.BuyoutPrice.widget:Enable(true)
	InfoBar.BuyoutPrice.widget:SetTransparentInput(false)
	InfoBar.Duration.widget:Enable(true)
	InfoBar.Duration.widget:SetTransparentInput(false)
	InfoBar.Deposit.widget:Enable(true)
	InfoBar.TotalPrice.widget:Enable(true)
end

InfoBar.DIsable = function()
	InfoBar.UniSlot.widget:Enable(false)
	InfoBar.Quantity.widget:Enable(false)
	InfoBar.Quantity.widget:SetTransparentInput(true)
	InfoBar.StartPrice.widget:Enable(false)
	InfoBar.StartPrice.widget:SetTransparentInput(true)
	InfoBar.BuyoutPrice.widget:Enable(false)
	InfoBar.BuyoutPrice.widget:SetTransparentInput(true)
	InfoBar.Duration.widget:Enable(false)
	InfoBar.Duration.widget:SetTransparentInput(true)
	InfoBar.Deposit.widget:Enable(false)
	InfoBar.TotalPrice.widget:Enable(false)
	InfoBar.btPost:Enable(false)
end

InfoBar.Clear = function()
	FillUniSlot(InfoBar.UniSlot.widget, nil, false, false, nil, nil)
	InfoBar.Name.itemName:SetVal("value", common.GetEmptyWString())
	InfoBar.Quantity.edit:SetText(common.GetEmptyWString())
	SetMoney(InfoBar.StartPrice.price)
	SetMoney(InfoBar.BuyoutPrice.price)
	InfoBar.Duration["12h"].checkbox:SetVariant(0)
	InfoBar.Duration["24h"].checkbox:SetVariant(0)
	InfoBar.Duration["36h"].checkbox:SetVariant(0)
	InfoBar.Duration["48h"].checkbox:SetVariant(0)
	SetMoney(InfoBar.Deposit.price)
	SetMoney(InfoBar.TotalPrice.price)
end

InfoBar.CheckValidateValues = function()
	local buyoutprice = GetMoney(InfoBar.BuyoutPrice.price)
	local startprice = GetMoney(InfoBar.StartPrice.price)
	local quantity = InfoBar.Quantity.edit:GetText():ToInt()
	if startprice ~= nil and startprice > 0 and buyoutprice ~= nil and buyoutprice > 0 and quantity ~= nil then
		InfoBar.btPost:Enable(true)
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("can Post")))
	else
		InfoBar.btPost:Enable(false)
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("values are not correctly")))
	end
end

InfoBar.CheckQuantity = function()
	local Quantity = InfoBar.Quantity.edit:GetText():ToInt()
	itemInfo.stackCount = itemLib.GetStackInfo(itemInfo.id).count
	if Quantity > itemInfo.stackCount then
		InfoBar.Quantity.edit:SetText(common.FormatInt(itemInfo.stackCount, "%d"))
	end
	--common.LogInfo("common", "CheckQuantity")
end

InfoBar.slot_over = function(params)
	if btTabSell:GetVariant() == 0 or params.widget:IsEnabled() == false then return end
	if params.active then
		CallTooltipItem(itemInfo, params.widget)
	else
		HideTooltip()
	end
end

InfoBar.EditLineChanged = function(params)
	if btTabSell:GetVariant() == 0 then return end
	local nameParent = params.widget:GetParent():GetName()
	local nameParentParent = params.widget:GetParent():GetParent():GetName() --когда надоело придумывать названия переменным

	if nameParent == "Quantity" then
		local number = params.widget:GetText():ToInt()
		if number == nil then
			SetMoney(InfoBar.Deposit.price)
			SetMoney(InfoBar.TotalPrice.price)
		elseif number < 1 then
			params.widget:SetText(common.FormatInt(1, "%d"))
			SetMoney(InfoBar.Deposit.price, GetPercentDuration(CheckDuration()) * itemInfo.prices.auctionPrice * 1 / 100)
			SetMoney(InfoBar.TotalPrice.price, (GetMoney(InfoBar.BuyoutPrice.price) or 0))
		elseif number > itemInfo.stackCount then
			params.widget:SetText(common.FormatInt(itemInfo.stackCount, "%d"))
			SetMoney(InfoBar.Deposit.price, GetPercentDuration(CheckDuration()) * itemInfo.prices.auctionPrice * itemInfo.stackCount / 100)
			SetMoney(InfoBar.TotalPrice.price, (GetMoney(InfoBar.BuyoutPrice.price) or 0) * itemInfo.stackCount)
		else
			SetMoney(InfoBar.Deposit.price, GetPercentDuration(CheckDuration()) * itemInfo.prices.auctionPrice * number / 100)
			SetMoney(InfoBar.TotalPrice.price, (GetMoney(InfoBar.BuyoutPrice.price) or 0) * number)
		end
	end

	if nameParentParent == "BuyoutPrice" then
		local number = GetMoney(InfoBar.BuyoutPrice.price)
		if number == nil then
			SetMoney(InfoBar.TotalPrice.price)
		else
			local quantity = InfoBar.Quantity.edit:GetText():ToInt()
			if quantity ~= nil and quantity > 0 then
				SetMoney(InfoBar.TotalPrice.price, number * quantity)
			else
				SetMoney(InfoBar.TotalPrice.price)
			end
		end
	end

	InfoBar.CheckValidateValues()
end

InfoBar.checkbox_pressed = function(params)
	if btTabSell:GetVariant() == 0 then return end
	params.widget:SetVariant(1)
	local nameParent = params.widget:GetParent():GetName()
	for k, v in pairs(InfoBar.Duration) do
		if v.checkbox and v.checkbox ~= nil and k ~= nameParent then
			v.checkbox:SetVariant(0)
		end
	end
	SetMoney(InfoBar.Deposit.price, GetPercentDuration(CheckDuration()) * itemInfo.prices.auctionPrice * (InfoBar.Quantity.edit:GetText():ToInt()) / 100)
end

SortBar.sort_pressed = function(params)
	if btTabSell:GetVariant() == 0 then return end 
	if SortBar[params.sender].sorted == "none" or SortBar[params.sender].sorted == "up" then
		SortBar[params.sender].sorted = "down"
		SortBar[params.sender].icon:SetBackgroundTexture(txSortDown)
		ListSell.SortDown(params.sender)
	else
		SortBar[params.sender].sorted = "up"
		SortBar[params.sender].icon:SetBackgroundTexture(txSortUp)
		ListSell.SortUp(params.sender)
	end
	for k, v in pairs(SortBar) do
		if k ~= params.sender and type(v) ~= "function" and v.sorted and v.sorted ~= "none" then
			v.sorted = "none"
			v.icon:SetBackgroundTexture(txSortNone)
		end
	end
end

SortBar.Reload = function()
	SortBar.Price.icon:SetBackgroundTexture(txSortNone)
	SortBar.Price.sorted = "none"
	SortBar.Available.icon:SetBackgroundTexture(txSortNone)
	SortBar.Available.sorted = "none"
end

function OnAuctionProperties(params)
    if params and params.sysResult == "ENUM_AuctionGetParamsResultMsgStatus_SUCCESS" then
        AuctionProperties = auction.GetProperties()
        if AuctionProperties and InfoBar.UniSlot.widget:IsEnabled() then
            -- пересчитать залог
            SetMoney(InfoBar.Deposit.price,
                GetPercentDuration(CheckDuration()) * itemInfo.prices.auctionPrice
                * (InfoBar.Quantity.edit:GetText():ToInt()) / 100)
        end
    end
end

function CheckDuration()
	local variant = 1
	if InfoBar.Duration["12h"].checkbox:GetVariant() == 1 then
		variant = 0
	elseif InfoBar.Duration["24h"].checkbox:GetVariant() == 1 then
		variant = 1
	elseif InfoBar.Duration["36h"].checkbox:GetVariant() == 1 then
		variant = 2
	elseif InfoBar.Duration["48h"].checkbox:GetVariant() == 1 then
		variant = 3
	end
	return variant
end

function GetPercentDuration(variant)
	local percent = {
		[0] = AuctionProperties.pawnFactorPercent / 2,
		[1] = AuctionProperties.pawnFactorPercent,
		[2] = AuctionProperties.pawnFactorPercent * 1.5,
		[3] = AuctionProperties.pawnFactorPercent * 2
	}
	return percent[variant]
end

function ClearTabSell()
	DestroyWidgetsInContainer(ListSell.container)
	InfoBar.Clear()
	SortBar.Reload()
end

function OpenTabSell()
	if StartFullScan or StartScanForList then
		StopScan()
	end
	ShowTabOverlay()
	if btTabBuy:GetVariant() == 1 then CloseTabBuy() end
	AuctionMainPanel:GetChildChecked("List", false):Show(false)
	AuctionMainPanel:GetChildChecked("Selection", false):Show(false)
	AuctionMainPanel:GetChildChecked("Search", true):Show(false)
	AuctionMainPanel:GetChildChecked("Money", true):Show(false)
	StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("WaitingAddItemInSlot")))
	btTabSell:SetVariant(1)
	ListSell.widget:Show(true)
end

function CloseTabSell()
	ListSell.widget:Show(false)
	btTabSell:SetVariant(0)
	ClearTabSell()
	AuctionMainPanel:GetChildChecked("List", false):Show(true)
	AuctionMainPanel:GetChildChecked("Selection", false):Show(true)
	AuctionMainPanel:GetChildChecked("Search", true):Show(true)
	AuctionMainPanel:GetChildChecked("Money", true):Show(true)
	InfoBar.DIsable()
	StatusBar:SetVal("value", common.GetEmptyWString())
	HideTabOverlay()
end

function DropInAuction(params)
	--for k, v in pairs(params) do
	--	common.LogInfo("common", "k - ", tostring(k), ", v - ", tostring(v))
	--end

	local detected = false
	for i = 1, #RegWIdgetsIDs do
		if params.targetId == RegWIdgetsIDs[i].id then detected = true end
	end
	if detected then
		ListSell.slotId = ListSell.pickSlotId
		InfoBar.Clear()
		local itemId = containerLib.GetItem( ITEM_CONT_INVENTORY, ListSell.slotId )
		if itemId and itemLib.CanCreateAuction(itemId) then
			if InfoBar.Fill(itemId) then
				InfoBar.Enable()
				InfoBar.UniSlot.Blink:Show(true)
				InfoBar.UniSlot.Blink:FinishFadeEffect()
				InfoBar.UniSlot.Blink:PlayFadeEffect(0.0, 1.0, 620, EA_MONOTONOUS_INCREASE)
				InfoBar.UniSlot.Blink:PlayFadeEffect(1.0, 0.0, 620, EA_MONOTONOUS_INCREASE)
			end
			ListSell.StartSearch()
		else
			InfoBar.Clear()
			InfoBar.DIsable()
			SortBar.Reload()
			DestroyWidgetsInContainer(ListSell.container)
			StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("not CanCreateAuction")))
		end
		--mission.DNDConfirmDropAttempt()
	end
end

function PickItem(params)
	--for k, v in pairs(params) do
	--	common.LogInfo("common", "k - ", tostring(k), ", v - ", tostring(v))
	--end
	local namewt = params.srcWidget:GetName()
	local wtParent = params.srcWidget:GetParent()
	local nameParent = wtParent:GetName()
	if AuctionMainPanel:IsVisible() and btTabSell:GetVariant() == 1 and namewt == "Button" and string.find(nameParent, "Item") then
		local slotId = math.modf(params.srcId / 1000)
		ListSell.pickSlotId = slotId
	end
	--mission.DNDConfirmPickAttempt()
end

function EVENT_INVENTORY_SLOT_CHANGED(params)
	--common.LogInfo("common", "EVENT_INVENTORY_SLOT_CHANGED")
	--for k, v in pairs(params) do
	--	common.LogInfo("common", tostring(k), ", ", tostring(v))
	--end

	if WaitingForEndSpliItem then
		--common.LogInfo("common", "EVENT_2")
		local info = itemLib.GetItemInfo(params.itemId)
		info.stackCount = itemLib.GetStackInfo(params.itemId).count
		local count = InfoBar.Quantity.edit:GetText():ToInt()
		if info.name == itemInfo.name and info.stackCount == count and itemLib.CanCreateAuction(params.itemId) then
			local startprice = GetMoney(InfoBar.StartPrice.price) * count
			local buyoutprice = GetMoney(InfoBar.BuyoutPrice.price) * count
			local duration = CheckDuration()
			if not auction.IsCreationInProgress() then
				auction.CreateForItem(params.itemId, startprice, buyoutprice, duration)
			end
			WaitingForEndSpliItem = false
		end
	end

	if not WaitingForEndSpliItem and AuctionMainPanel:IsVisible() and btTabSell:GetVariant() == 1 and InfoBar.UniSlot.widget:IsEnabled() then
		--common.LogInfo("common", "EVENT_1")
		if ListSell.ValidateSlot() then InfoBar.CheckQuantity() end
	end
end

function EVENT_AUCTION_CREATION_RESULT(params)
	if not WaitingForEndSpliItem and AuctionMainPanel:IsVisible() and btTabSell:GetVariant() == 1 and InfoBar.UniSlot.widget:IsEnabled() then
		--common.LogInfo("common", "EVENT_0")
		if ListSell.ValidateSlot() then InfoBar.CheckQuantity() end
	end
end

ListSell.RegWIdgetsIDs = function()
	for i = 1, #RegWIdgetsIDs do
		--common.LogInfo("common", "widget - ", tostring(RegWIdgetsIDs[i].widget), ", id - ", tostring(RegWIdgetsIDs[i].id))
		RegWIdgetsIDs[i].widget:DNDRegister(RegWIdgetsIDs[i].id, true)
	end
end

ListSell.Init = function()
	common.RegisterEventHandler(ListSell.AuctionIsVisible, "EVENT_WIDGET_SHOW_CHANGED") --какойто виджет изменил видимость
	common.RegisterEventHandler(ListSell.AuctionSearch, "EVENT_AUCTION_SEARCH_RESULT") --пришел результат поиска
	common.RegisterEventHandler(DropInAuction, "EVENT_DND_DROP_ATTEMPT") --закончилось перемещение(днд)
	common.RegisterEventHandler(PickItem, "EVENT_DND_PICK_ATTEMPT") --началось перемещение(днд)
	common.RegisterEventHandler(EVENT_INVENTORY_SLOT_CHANGED,"EVENT_INVENTORY_SLOT_CHANGED") --изменилось содержимое слота
	common.RegisterEventHandler(EVENT_AUCTION_CREATION_RESULT,"EVENT_AUCTION_CREATION_RESULT") --результат попытки создать аукцион
	common.RegisterEventHandler(OnAuctionProperties, "EVENT_AUCTION_PROPERTIES")
	common.RegisterReactionHandler(InfoBar.EditLineChanged, "EditLineChanged")
	common.RegisterReactionHandler(InfoBar.slot_over, "slot_over")
	common.RegisterReactionHandler(InfoBar.checkbox_pressed, "checkbox_pressed")
	common.RegisterReactionHandler(ListSell.button_pressed, "button_pressed")
	common.RegisterReactionHandler(SortBar.sort_pressed, "sort_pressed")
	common.RegisterReactionHandler(OpenTabSell, "OpenTabSell")
	--common.RegisterReactionHandler(CloseTabSell, "CloseTabSell")
	ListSell.RegWIdgetsIDs()
end

ListSell.Init()