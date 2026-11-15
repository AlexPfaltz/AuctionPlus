if AuctionPlusNoAuction then return end

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
local iconItemName = wtSortBar:GetChildUnchecked("IconItemName", false)
local txSortNone = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortNone")
local txSortUp = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortUp")
local txSortDown = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortDown")
--
local wtDescLine = nil
local CurrentSelectedLine = false
local Lines = {}

local LotForBuy = {}
local BuyoutSelected = false
local CountAuctions = 0
local auctionsPage = 0
local auctionsPageCount = 0
-- Поиск нажат повторно, пока шёл старый: новый фильтр собран в SearchFilter,
-- но auction.Search не принял его (старый поиск ещё не закончен). Пропускаем
-- одно пришедшее событие (это результат старого фильтра) и стартуем заново.
local RestartPending = false
-- Мы запросили страницу и ждём результата: только тогда пришедшее событие
-- поиска наше. Иначе это чужой запрос (скан, стоковый поиск) - обработав
-- его, мы продолжили бы чужой поиск с чужим фильтром.
local SearchRequested = false

btTabBuy:SetVal("button_label", userMods.ToWString(GetLocalizedText("btTabBuy")))
if AuctionMainPanel then
	AuctionMainPanel:AddChild(wtListBuy)
	AuctionMainPanel:AddChild(btTabBuy)
end

------------------------------------------------------------------------------
-- Сортировка: единая логика для всех колонок
------------------------------------------------------------------------------
-- Ключ для сортировки по имени: регистр не учитывается (cp1251: А-Я -> а-я, Ё -> е)
local function NameSortKey(name)
	name = string.lower(name or "")
	return (string.gsub(name, "[\168\184\192-\223]", function(c)
		local code = string.byte(c)
		if code == 168 or code == 184 then return string.char(229) end
		return string.char(code + 32)
	end))
end

-- Колонки сортировки: value(line) возвращает значение, по которому сравниваются строки.
-- icon у колонки имени может отсутствовать (если не установлен IconItemName.xdb).
local SortColumns = {
	lots   = { icon = iconNumLots,      value = function(line) return line.lotsValue end },
	name   = { icon = iconItemName,     value = function(line) return line.sortName end },
	unit   = { icon = iconPricePerUnit, value = function(line) return line.infoForBuy.priceperunit or 0 end },
	buyout = { icon = iconBuyOut,       value = function(line) return line.infoForBuy.buyoutprice or 0 end },
}
local SortColumn = false  -- ключ из SortColumns или false (порядок поступления)
local SortAscending = true

-- true, если строка a должна стоять выше строки b.
-- Порядок всегда полный: при равенстве значений выбранной колонки строки
-- сравниваются по имени, цене за единицу, цене выкупа и ключу. Направление
-- сортировки на эти критерии не влияет.
local function LessThan(a, b)
	if SortColumn then
		local value = SortColumns[SortColumn].value
		local va, vb = value(a), value(b)
		if va ~= vb then
			if SortAscending then return va < vb end
			return va > vb
		end
	end
	if a.sortName ~= b.sortName then return a.sortName < b.sortName end
	local ua, ub = a.infoForBuy.priceperunit or 0, b.infoForBuy.priceperunit or 0
	if ua ~= ub then return ua < ub end
	local pa, pb = a.infoForBuy.buyoutprice or 0, b.infoForBuy.buyoutprice or 0
	if pa ~= pb then return pa < pb end
	return tostring(a.infoForBuy.key) < tostring(b.infoForBuy.key)
end

local function UpdateSortIcons()
	for column, info in pairs(SortColumns) do
		if info.icon then
			local texture = txSortNone
			if column == SortColumn then
				texture = SortAscending and txSortDown or txSortUp
			end
			info.icon:SetBackgroundTexture(texture)
		end
	end
end

local function ResetSort()
	SortColumn = false
	SortAscending = true
	UpdateSortIcons()
end

-- Полная пересортировка контейнера по текущему выбору
local function ApplySort()
	if not SortColumn then return end
	local count = Container:GetElementCount()
	if count <= 1 then return end
	local list = {}
	for i = 0, count - 1 do
		local widget = Container:At(i)
		local line = widget and Lines[widget:GetName()]
		if line then list[#list + 1] = line end
	end
	table.sort(list, LessThan)
	for i = 1, #list do
		Container:Remove(list[i].widget)
		Container:Insert(i - 1, list[i].widget)
	end
	Container:ForceReposition()
end

-- Вставка (или перестановка) одной строки в нужную позицию уже отсортированного
-- контейнера: так порядок сохраняется, пока поиск подгружает новые страницы
-- и когда у строки меняется число лотов.
ListBuy.PlaceLine = function(line, inContainer)
	if inContainer then Container:Remove(line.widget) end
	local low, high = 0, Container:GetElementCount()
	while low < high do
		local mid = math.floor((low + high) / 2)
		local widget = Container:At(mid)
		local other = widget and Lines[widget:GetName()]
		if other and LessThan(other, line) then low = mid + 1 else high = mid end
	end
	Container:Insert(low, line.widget)
end

-- Клик по заголовку колонки: новая колонка сортируется по возрастанию,
-- повторный клик меняет направление
ListBuy.SortBy = function(column)
	if not SortColumns[column] then return end
	if SortColumn == column then
		SortAscending = not SortAscending
	else
		SortColumn = column
		SortAscending = true
	end
	UpdateSortIcons()
	ApplySort()
	if Container:GetElementCount() > 0 then
		Container:EnsureVisible(Container:At(0))
	end
end

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

-- Порог выгодной покупки: цена за единицу ниже рыночной из базы цен
-- (PriceDB) минус DEAL_DISCOUNT
local DEAL_DISCOUNT = 0.15
-- Данные базы старше этого срока не считаются рыночными
local DEAL_MAX_AGE_MS = 7 * 86400000

-- Рыночная цена предмета по базе сканирования: нижняя четверть,
-- при её отсутствии - медиана или минимум (nil, если предмета нет в базе
-- или снимок устарел)
local function GetMarketPrice(name, isCursed)
	local entry = PriceDB.GetEntry(name, isCursed)
	local cur = entry and entry.cur
	if not cur or not cur.t or common.GetLocalDateTimeMs() - cur.t > DEAL_MAX_AGE_MS then
		return nil
	end
	return cur.q1 or cur.med or cur.min
end

-- Экипировка или оружие (такие лоты группируются по характеристикам)
local function IsGearItem(itemInfo)
	local slot = itemInfo.dressSlot
	if itemInfo.isWeapon then return true end
	if not slot then return false end
	return (slot >= 0 and slot <= 18) or slot == 29 or (slot >= 43 and slot <= 46)
end

-- Ключ группировки лота. Тот же ключ используется при выкупе, поэтому
-- в выкупаемую пачку попадают только лоты, идентичные выбранному.
-- Проклятые и обычные предметы - разные группы.
local function MakeLotKey(auctionInfo, itemInfo, itemCount)
	local itemName = userMods.FromWString(itemInfo.name)
	local cursed = IsItemCursed(auctionInfo.itemId) and 1 or 0
	local buyout = math.floor(auctionInfo.buyoutPrice or 0)
	if IsGearItem(itemInfo) then
		local GS, SumSpecStats, SumStats = GetStatsFromID(auctionInfo.itemId)
		return string.format("%s|G|%.2f|%.2f|%.2f|%d|%d",
			itemName, GS or 0, SumSpecStats or 0, SumStats or 0, buyout, cursed)
	end
	return string.format("%s|S|%d|%d|%d", itemName, itemCount, buyout, cursed)
end

ListBuy.CreateLine = function(auctionInfo, key)
	local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
	if not itemInfo then return end
	local stackInfo = itemLib.GetStackInfo(auctionInfo.itemId)
	if not stackInfo then return end
	local itemQuality = itemLib.GetQuality(auctionInfo.itemId)
	local itemName = userMods.FromWString(itemInfo.name)
	local quality = itemQuality and itemQuality.quality
	local itemCount = stackInfo.count
	local PriceBuyOut = auctionInfo.buyoutPrice
	if not PriceBuyOut or PriceBuyOut <= 0 or itemCount <= 0 then return end

    local line = {}
	if not wtDescLine then
		line.widget = wtListBuy:GetChildChecked("ItemLine", false)
		wtDescLine = line.widget:GetWidgetDesc()
	else
		line.widget = mainForm:CreateWidgetByDesc(wtDescLine)
		mainForm:AddChild(line.widget)
	end
	local PricePerUnit = PriceBuyOut / itemCount
	local SplitPriceBuyOut = Split(PriceBuyOut)
	local SplitPricePerUnit = Split(PricePerUnit)
	
	line.infoForTooltip = GetInfoForTooltip(itemInfo) --Инфа для тултипа
	local isCursed = line.infoForTooltip.isCursed

	--Закинем всю инфу в таблицу для дальнейшего использования, что бы не искать заного
	local infoForBuy = {}
	infoForBuy.itemId = auctionInfo.itemId
	infoForBuy.name = itemInfo.name
	infoForBuy.icon = itemInfo.icon
	infoForBuy.quality = quality
	infoForBuy.count = itemCount
	infoForBuy.buyoutprice = PriceBuyOut
	infoForBuy.key = key
	infoForBuy.isCursed = isCursed
	infoForBuy.priceperunit = PricePerUnit
	line.infoForBuy = infoForBuy

	--Заполним позицию
	line.button = line.widget:GetChildChecked("Button", false)
	line.lots = line.widget:GetChildChecked("Lots", false)
	line.lotsValue = 1
	line.lots:SetVal("value", common.FormatInt(line.lotsValue, "%d"))
	local UniSlot = line.widget:GetChildChecked("ItemSlot", false)
	FillUniSlot(UniSlot, itemInfo.icon, quality, isCursed, itemCount, nil)

	line.itemName = line.widget:GetChildChecked("ItemName", false)
	line.itemName:SetClassVal( "class", ItemQualityClass[quality] or "tip_base")
	line.itemName:SetVal("itemname", itemInfo.name)

	-- Подсветка выгодной покупки: цена за единицу заметно ниже рыночной
	-- по базе сканирования. Пока поиск идёт, база не меняется, поэтому
	-- флаг достаточно выставить при создании строки.
	line.dealHighlight = line.widget:GetChildChecked("DealHighlight", false)
	local marketPrice = GetMarketPrice(itemName, isCursed)
	line.isGoodDeal = marketPrice ~= nil and marketPrice > 0
		and PricePerUnit <= marketPrice * (1 - DEAL_DISCOUNT)
	line.dealHighlight:Show(line.isGoodDeal)
	
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
	line.button:SetName(key)
	line.widget:SetName(key)
	line.widget:GetChildChecked("ItemSlot", false):SetName(key)
	Lines[key] = line
	line.sortName = NameSortKey(userMods.FromWString(itemInfo.name))
	if SortColumn then
		ListBuy.PlaceLine(line, false)
	else
		Container:PushBack(line.widget)
	end
	line.widget:Show(true)
end

ListBuy.AddLine = function(auctionInfo)
	local BuyoutPrice = auctionInfo.buyoutPrice
	if not BuyoutPrice or BuyoutPrice <= 0 then return end

	local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
	if not itemInfo then return end
	local stackInfo = itemLib.GetStackInfo(auctionInfo.itemId)
	if not stackInfo then return end
	local itemCount = stackInfo.count

	local key = MakeLotKey(auctionInfo, itemInfo, itemCount)
	local line = Lines[key]
	if line then
		line.lotsValue = line.lotsValue + 1
		line.lots:SetVal("value", common.FormatInt(line.lotsValue, "%d"))
		if SortColumn == "lots" then ListBuy.PlaceLine(line, true) end
	else
		ListBuy.CreateLine(auctionInfo, key)
	end
end

ListBuy.AssembleFilter = function()
	SearchFilter = {}
	if AddonTab == "buy" then
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

	if AddonTab ~= "buy" then return end

	-- Проверяется до SearchRequested: при перезапуске StartSearch очищает
	-- вкладку (SearchRequested = false), и результат старого поиска -
	-- единственный сигнал, что аукцион освободился и можно стартовать
	-- с новым фильтром.
	if RestartPending then
		RestartPending = false
		SearchRequested = GetPage(1)
		return
	end

	-- результат чужого запроса (например, страница скана, поставленного
	-- на паузу при уходе с вкладки): не обрабатываем и не листаем дальше
	if not SearchRequested then return end

	if AuctionSearchSuccess ~= nil and params and params.sysResult ~= nil
       and params.sysResult ~= AuctionSearchSuccess then
		SearchRequested = false
        return
    end

	if not BuyoutSelected then
		auctionsPage = auction.GetAuctionsPage()
        auctionsPageCount = params and params.totalPagesCount or auction.GetAuctionsPageCount()
		local auctions = SafeGetAuctions()
		if TableSize(auctions) > 0 then
			for _, auctionId in pairs(auctions) do
				local auctionInfo = auction.GetAuctionInfo(auctionId)
				if auctionInfo then
					ListBuy.AddLine(auctionInfo)
					CountAuctions = CountAuctions + 1
				end
			end
		end
		if auctionsPage < auctionsPageCount then
			SearchRequested = GetPage(auctionsPage+1)
			StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchInProgress")..tostring(auctionsPage)..GetLocalizedText("SeparatorSearchInProgress")..tostring(auctionsPageCount)))
		else
			SearchRequested = false
			StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchFinished")..tostring(CountAuctions)))
			CountAuctions = 0
		end
		return
	end

	-- Выкуп выбранной группы лотов.
	if not (LotForBuy.name and LotForBuy.buyoutprice and LotForBuy.count
	        and LotForBuy.countLots and LotForBuy.countLots > 0) then
		BuyoutSelected = false
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("BuyoutFinished")))
		ListBuy.StartSearch()
		return
	end

	auctionsPage = auction.GetAuctionsPage()
	auctionsPageCount = auction.GetAuctionsPageCount()
	local auctions = SafeGetAuctions()

	for _, auctionId in pairs(auctions) do
		if LotForBuy.countLots <= 0 then break end
		local auctionInfo = auction.GetAuctionInfo(auctionId)
		if auctionInfo then
			local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
			local stackInfo = itemLib.GetStackInfo(auctionInfo.itemId)
			if itemInfo and stackInfo then
				local buyoutPrice = auctionInfo.buyoutPrice
				local itemName = userMods.FromWString(itemInfo.name)
				local count = stackInfo.count
				if itemName == LotForBuy.name and buyoutPrice == LotForBuy.buyoutprice
					and count == LotForBuy.count
					and MakeLotKey(auctionInfo, itemInfo, count) == LotForBuy.key then
						local state = auction.GetAuctionState(auctionInfo.id)
						if state and not state.bidInProgress then
							auction.Buyout(auctionInfo.id)
						end
						LotForBuy.countLots = LotForBuy.countLots - 1
				end
			end
		end
	end

	if LotForBuy.countLots and LotForBuy.countLots > 0 and auctionsPage < auctionsPageCount then
		SearchRequested = GetPage(auctionsPage+1)
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchSelectedForBuyOutInProgress")..tostring(auctionsPage)..GetLocalizedText("SeparatorSearchInProgress")..tostring(auctionsPageCount)))
		return
	end

	BuyoutSelected = false
	SearchRequested = false
	StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("BuyoutFinished")))
	ListBuy.StartSearch()
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
	ResetSort()
end

ListBuy.FillInfoBar = function(line)
	wtInfoBarLots:GetChildChecked("HeaderNumLots", false):SetVal("value", userMods.ToWString(GetLocalizedText("HeaderNumLots")))
	wtInfoBarLots:GetChildChecked("EditLine", false):SetText(userMods.ToWString(tostring(line.lotsValue)))
	FillUniSlot(wtInfoBarSlot, line.infoForBuy.icon, line.infoForBuy.quality, line.infoForBuy.isCursed, line.infoForBuy.count, nil)
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
	LotForBuy.key = item.infoForBuy.key
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
	UpdateSortIcons()
end

function ClearTabBuy()
    -- Все строки лежат в Container; DestroyWidgetsInContainer сначала
    -- отсоединяет виджеты от контейнера, потом уничтожает — прямой
    -- DestroyWidget по виджету в контейнере оставляет в нём InvalidWidgetSafe.
    DestroyWidgetsInContainer(Container)
    Lines = {}
    CountAuctions = 0
    auctionsPage = 0
    auctionsPageCount = 0
    LotForBuy = {}
    CurrentSelectedLine = false
    RestartPending = false
    SearchRequested = false
    ListBuy.ClearInfoBar()
    ListBuy.reloadSortIcon()
end

ListBuy.EditLineChanged = function()
	if AddonTab ~= "buy" then return end
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
	if AddonTab ~= "buy" then return end
	local number = wtInfoBarLots:GetChildChecked("EditLine", false):GetText():ToInt()
	if not CurrentSelectedLine then return end
	if not number or number <= 1 then
		wtInfoBarLots:GetChildChecked("EditLine", false):SetText(common.FormatInt(1, "%d"))
		UpdPriceOnNumLots(Lines[CurrentSelectedLine].infoForBuy.buyoutprice, 1)
		TheLastStageBeforeBuying(Lines[CurrentSelectedLine], number)
		wtListBuy:GetChildChecked("BuySelected", false):Enable(true)
	end
end

ListBuy.SortNumLots = function() ListBuy.SortBy("lots") end
ListBuy.SortItemName = function() ListBuy.SortBy("name") end
ListBuy.SortPricePerUnit = function() ListBuy.SortBy("unit") end
ListBuy.SortPriceBuyOut = function() ListBuy.SortBy("buyout") end

ListBuy.slot_over = function(params)
    if AddonTab ~= "buy" then return end
    local wtParent = params.widget:GetParent()
    local nameParent = wtParent:GetName()
    local line = Lines[nameParent]
    if not line then return end
    local content = line.infoForTooltip or {}
    content.isGoodDeal = line.isGoodDeal

    if params.active then
        CallTooltipItem(content, params.widget)
    else
        HideTooltip()
    end
end

ListBuy.BuySelected = function()
	BuyoutSelected = true
	if not ListBuy.AssembleFilter() then
		BuyoutSelected = false
		return
	end
	SearchRequested = GetPage(1)
	if not SearchRequested then
		BuyoutSelected = false
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchAlreadyInProgress")))
	end
end

ListBuy.StartSearch = function()
	-- повторный поиск отменяет выкуп выбранных лотов
	BuyoutSelected = false
	if not ListBuy.AssembleFilter() then
		return
	end
	ClearTabBuy()
	if auction.IsSearchInProgress() then
		-- старый поиск ещё не ответил: API не примет новый запрос.
		-- Результат старого поиска будет пропущен (RestartPending), и с ним
		-- же стартует поиск по уже собранному новому фильтру.
		RestartPending = true
		StatusBar:SetVal("value", userMods.ToWString(GetLocalizedText("SearchRestarting")))
		return
	end
	RestartPending = false
	SearchRequested = GetPage(1)
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
	SyncAddonTabs()
	if AddonTab == "buy" then
		btTabBuy:SetVariant(1)
		return
	end
	if AddonTab == "scan" then CloseTabScan() end
	if AddonTab == "sell" then CloseTabSell() end
	ShowTabOverlay()
	AddonTab = "buy"
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
	if AddonTab == "buy" then AddonTab = false end
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
			if AddonTab == "buy" then
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