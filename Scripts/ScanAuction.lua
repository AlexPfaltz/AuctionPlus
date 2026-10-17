Global("ItemsDB", userMods.GetGlobalConfigSection("ItemsDB") or {})
Global("StartFullScan", false)
Global("StartScanForList", false)

local btTabScan = mainForm:GetChildChecked("TabScan", false)

local auctionsCount = nil
local auctionsPage = nil
local auctionsPageCount = nil
local ManualScan = false
local CurItem = 1
local ScanAuction = {}

btTabScan:SetVal("button_label", userMods.ToWString(GetLocalizedText("StartScan")))
AuctionMainPanel:AddChild(btTabScan)

function CheckBag()
	local AllBagSlot = containerLib.GetItems( ITEM_CONT_INVENTORY )
	SearchList = {}
	local i = 1
	for k, v in pairs(AllBagSlot) do
		if itemLib.CanCreateAuction(v) then
			SearchList[i] = itemLib.GetName(v)
			AddPlainLines(i, SearchList[i])
			i=i+1
		end
	end
end

ScanAuction.AssembleFilter = function()
	SearchFilter = {}
	if StartScanForList then
		SearchFilter.name = SearchList[CurItem]
		SearchBar.name:SetText(SearchFilter.name)
	end
	return true
end

function AddToItemsDB(auctionInfo)
	local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
	if not itemInfo.name then return end
	local buyoutPrice = math.max(0, auctionInfo.buyoutPrice)
	if buyoutPrice <= 0 then return end
	local itemStack = itemLib.GetStackInfo(auctionInfo.itemId)
	local name = userMods.FromWString(itemInfo.name)
	local count = math.max(1, itemStack.count)
	local perOne = buyoutPrice/count
	local ltime = common.GetLocalDateTime()
	local datescan = ItemsDB[name] or {}
	local date = (string.format("%02d", ltime.d) .. "." .. string.format("%02d", ltime.m) .. "." .. string.format("%04d", ltime.y))
	local prices = datescan[date] or {}
	if not prices.min or prices.min == 0 then
		prices.min = perOne
	end
	if prices.min > perOne then
		prices.min = perOne
	end
	if not prices.max or prices.max < perOne then
		prices.max = perOne
	end
	prices.timeMS = common.GetMsFromDateTime(common.GetLocalDateTime())
	datescan[date] = prices
	datescan.LastScan = date
	ItemsDB[name] = datescan
end

ScanAuction.AuctionSearch = function(params)

	if AuctionSearchSuccess ~= nil and params and params.sysResult ~= nil
       and params.sysResult ~= AuctionSearchSuccess then
        return
    end

	CheckTabVariant()
	if StartFullScan then
		auctionsPage = auction.GetAuctionsPage()
		auctionsPageCount = auction.GetAuctionsPageCount()
		local auctions = SafeGetAuctions()
		for _, auctionId in pairs(auctions) do
			local auction = auction.GetAuctionInfo(auctionId)	  
			AddToItemsDB(auction)
		end
		if auctionsPage < auctionsPageCount then
			GetPage(auctionsPage+1)
		end	
		if auctionsPage == auctionsPageCount then
			StartFullScan = false
			StopScan()
		end
	end
	if StartScanForList then
		auctionsCount = auction.GetAuctionsCount()
		auctionsPage = auction.GetAuctionsPage()
		auctionsPageCount = auction.GetAuctionsPageCount()
		local auctions = SafeGetAuctions()
		if table.getsize(auctions) > 0 then
			for _, auctionId in pairs(auctions) do
				local auction = auction.GetAuctionInfo(auctionId)
				AddToItemsDB(auction)
			end
		end
		if auctionsPage < auctionsPageCount then
			GetPage(auctionsPage+1)
		end
		if auctionsPage == auctionsPageCount then
			StrikeOutLine(CurItem)
			CurItem = CurItem + 1
			if CurItem > table.getn(SearchList) then
				StartScanForList = false
				StopScan()
			else
				if ScanAuction.AssembleFilter() then GetPage(1) end
				EnsureVisibleLine(CurItem)
			end
		end
	end
	if ManualScan then
		local auctions = SafeGetAuctions()
		if table.getsize(auctions) > 0 then
			for _, auctionId in pairs(auctions) do
				local auction = auction.GetAuctionInfo(auctionId)
				AddToItemsDB(auction)
			end
		end
	end
	
end

function StartScan()
	ManualScan = false
	btTabScan:SetVariant(1)
	btTabScan:SetVal("button_label", userMods.ToWString(GetLocalizedText("StopScan")))
	if btTabBuy:GetVariant() == 1 then
		CloseTabBuy()
	elseif btTabSell:GetVariant() == 1 then
		CloseTabSell()
	end
	if Options.ScanBy == 1 then
		StartFullScan = true
		if ScanAuction.AssembleFilter() then GetPage(1) end
	elseif Options.ScanBy == 2 or Options.ScanBy == 3 then
		CurItem = 1
		HideErasers()
		StartScanForList = true
		if ScanAuction.AssembleFilter() then GetPage(1) end
	end
end

function StopScan()
	StartFullScan = false
	StartScanForList = false
	ManualScan = true
	btTabScan:SetVariant(0)
	btTabScan:SetVal("button_label", userMods.ToWString(GetLocalizedText("StartScan")))
	userMods.SetGlobalConfigSection("ItemsDB", ItemsDB)
	ClearStrikeOutLine()
end

function StopManualScan()
	ManualScan = false
	userMods.SetGlobalConfigSection("ItemsDB", ItemsDB)
end

function CheckTabVariant()
	if not AuctionMainPanel or not AuctionMainPanel:IsVisible() then return end
	if TabAll:GetVariant() == 1 or TabBids:GetVariant() == 1 or TabOwner:GetVariant() == 1 then
		if btTabBuy:GetVariant() == 1 then
			CloseTabBuy()
		end
		if btTabSell:GetVariant() == 1 then
			CloseTabSell()
		end
	end
end

ScanAuction.AuctionIsVisible = function(params)
	if params.addonName == "ContextAuction" and params.widget:GetName() == "Main" then
		if params.widget:IsVisible() then
			ManualScan = true
			if OpenSearchListFromOptions then
				HideSearchList()
				OpenSearchListFromOptions = false
			end
			if Options.ScanBy == 2 then
				CheckBag()
				if Options.ShowSearchList then
					ShowSearchListForBag()
				end
			elseif Options.ScanBy == 3 and Options.ShowSearchList then
				ShowYourSearchList()
			end
			DisableButtonShowList()
		else
			if StartFullScan or StartScanForList or ManualScan then
				StopScan()
			end
			HideSearchList()
			EnableButtonShowList()
		end
	end
end

ScanAuction.Init = function()
	common.RegisterEventHandler(ScanAuction.AuctionIsVisible, "EVENT_WIDGET_SHOW_CHANGED")
	common.RegisterEventHandler(ScanAuction.AuctionSearch, "EVENT_AUCTION_SEARCH_RESULT")
	common.RegisterReactionHandler(StartScan, "StartScan")
	common.RegisterReactionHandler(StopScan, "StopScan")
end

ScanAuction.Init()