local Gold = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinGold")
local Silver = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinSilver")
local Copper = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinCopper")
local wtPriceInTooltip = mainForm:GetChildChecked("PriceInTooltip", false)

-- Шаблоны строк берём из исходных виджетов при загрузке, пока их никто не
-- перекладывал. Каждая строка цен создаётся заново и уничтожается при
-- следующем показе тултипа.
local DescHeader = wtPriceInTooltip:GetChildChecked("Header", false):GetWidgetDesc()
local DescLabel = wtPriceInTooltip:GetChildChecked("StartingAt", false):GetWidgetDesc()
local DescDate = wtPriceInTooltip:GetChildChecked("Update", false):GetWidgetDesc()
local DescSeparator = wtPriceInTooltip:GetChildChecked("Separator", false):GetWidgetDesc()
local DescContainer = wtPriceInTooltip:GetChildChecked("ContainerPrice", false):GetWidgetDesc()
local DescPrices = wtPriceInTooltip:GetChildChecked("Prices", false):GetWidgetDesc()
local DynamicWidgets = {}

-- Виджеты создаются внутри скрытой панели PriceInTooltip: когда родной тултип
-- освобождает их из своего контейнера, они возвращаются в неё и не видны.
local function NewWidget(desc)
	local widget = mainForm:CreateWidgetByDesc(desc)
	wtPriceInTooltip:AddChild(widget)
	DynamicWidgets[#DynamicWidgets + 1] = widget
	return widget
end

-- Уничтожаем все созданные виджеты. Родитель уничтожает детей, поэтому
-- проверяем IsValid у каждого: после DestroyWidget другие методы нельзя
-- вызывать, а IsValid — можно.
local function DestroyDynamic()
	for i = #DynamicWidgets, 1, -1 do
		local widget = DynamicWidgets[i]
		if widget and widget:IsValid() then
			widget:DestroyWidget()
		end
	end
	DynamicWidgets = {}
end

-- Монеты с иконками в строку container. Количество показываемых монет
-- зависит от настройки Options.ShowCoins: 1 - все, 2 - золото и серебро, 3 - только золото.
local function AddCoins(container, panel, price)
	local SplitMoney = Split(math.floor(price))
	local gold = panel:GetChildChecked("ValueGold", false)
	local goldIcon = panel:GetChildChecked("IconGold", false)
	local silver = panel:GetChildChecked("ValueSilver", false)
	local silverIcon = panel:GetChildChecked("IconSilver", false)
	local copper = panel:GetChildChecked("ValueCopper", false)
	local copperIcon = panel:GetChildChecked("IconCopper", false)

	local function pushGold()
		gold:SetVal("gold", common.FormatInt(SplitMoney[1], "%d", " "))
		goldIcon:SetBackgroundTexture(Gold)
		container:PushBack(gold)
		container:PushBack(goldIcon)
	end
	local function pushSilver()
		silver:SetVal("silver", common.FormatInt(SplitMoney[2], "%d"))
		silverIcon:SetBackgroundTexture(Silver)
		container:PushBack(silver)
		container:PushBack(silverIcon)
	end
	local function pushCopper()
		copper:SetVal("copper", common.FormatInt(SplitMoney[3], "%d"))
		copperIcon:SetBackgroundTexture(Copper)
		container:PushBack(copper)
		container:PushBack(copperIcon)
	end

	if Options.ShowCoins == 1 then
		if SplitMoney[1] > 0 then pushGold() end
		if SplitMoney[2] > 0 then pushSilver() end
		if SplitMoney[3] > 0 then pushCopper() end
	elseif Options.ShowCoins == 2 then
		if SplitMoney[1] > 0 then pushGold() end
		if SplitMoney[2] > 0 then pushSilver() end
	else
		if SplitMoney[1] > 0 then
		pushGold()
		elseif SplitMoney[2] > 0 then
			pushSilver()
		else
			pushCopper()
		end
	end
end

-- CSS-класс из настроек с защитой от устаревшего/битого индекса.
local function StyleClass(key)
	local count = table.getn(listCSS)
	if count < 1 then return "" end
	local index = math.max(1, math.min(Options[key] or 1, count))
	return listCSS[index]
end

-- Строка тултипа: [дата] подпись [монеты]. Дата выводится в первой строке.
local function BuildRow(label, price, dateText)
	local container = NewWidget(DescContainer)

	if dateText then
		local dateWidget = NewWidget(DescDate)
		dateWidget:SetVal("date", userMods.ToWString(dateText))
		dateWidget:SetClassVal("class", userMods.FromWString(StyleClass("styleDate")))
		container:PushBack(dateWidget)
	end

	local labelWidget = NewWidget(DescLabel)
	labelWidget:SetVal("value", label)
	container:PushBack(labelWidget)

	if price then
		local panel = NewWidget(DescPrices)
		AddCoins(container, panel, price)
	end
	return container
end

local function FormatDate(ms)
	if not ms then return nil end
	local dt = common.GetDateTimeFromMs(ms)
	if not dt then return nil end
	return string.format("%02d.%02d.%04d", dt.d, dt.m, dt.y)
end

-- Заголовок раздела. Для истории используется отдельный заголовок, чтобы
-- визуально отделить её от текущих цен.
local function BuildHeader(text)
	local header = NewWidget(DescHeader)
	header:SetClassVal("class", userMods.FromWString(StyleClass("styleHeader")))
	header:SetVal("text", text)
	return header
end

-- Строки истории: последние дни, по одной точке на день.
local function BuildHistoryRows(Itemname, isCursed)
	if not Options.ShowHistory then return nil end
	local history = PriceDB.GetHistory(Itemname, isCursed, 7)
	if not history or #history < 2 then return nil end

	local rows = {}
	local separator = NewWidget(DescSeparator)
	rows[#rows + 1] = separator
	rows[#rows + 1] = BuildHeader(GetLocalizedText("PriceHistory"))
	for i = 1, #history do
		local point = history[i]
		local timeMs = point.t or (point.d and point.d * 86400000)
		rows[#rows + 1] = BuildRow(
			GetLocalizedText("PriceMedian"),
			point.med or point.min,
			FormatDate(timeMs))
	end
	return rows
end

-- Строки цен выбранных в настройках видов. nil, если показывать нечего.
local function FillRows(Itemname, isCursed)
	local entry = PriceDB.GetEntry(Itemname, isCursed)
	local cur = entry and entry.cur

	local rows = {}
	if cur then
	local specs = {}
	if Options.ShowMin and cur.min then
		specs[#specs + 1] = { label = GetLocalizedText("PriceMin"), price = cur.min }
	end
	if Options.ShowMarket and cur.q1 then
		specs[#specs + 1] = { label = GetLocalizedText("PriceMarket"), price = cur.q1 }
	end
	if Options.ShowMedian and cur.med then
		specs[#specs + 1] = { label = GetLocalizedText("PriceMedian"), price = cur.med }
	end
	if Options.ShowLots and cur.n then
		local text = GetLocalizedText("PriceLots") .. tostring(cur.n)
		if cur.u then text = text .. GetLocalizedText("PriceUnits") .. tostring(cur.u) end
		specs[#specs + 1] = { label = text }
	end
		if #specs > 0 then
			if Options.ShowHeader then
				rows[#rows + 1] = BuildHeader(GetLocalizedText("Auction price"))
			end
	local dateText = Options.ShowDate and FormatDate(cur.t) or nil
	for i = 1, #specs do
		rows[#rows + 1] = BuildRow(specs[i].label, specs[i].price, i == 1 and dateText or nil)
	end
		end
	end

	local historyRows = BuildHistoryRows(Itemname, isCursed)
	if historyRows then
		for i = 1, #historyRows do
			rows[#rows + 1] = historyRows[i]
		end
	end

	if #rows == 0 then return nil end
	return rows
end

-- Проклятость предмета определяется по строке родного тултипа: отдельного
-- признака в контейнере нет, а цена хранится отдельно для обычной и проклятой версии.
local function IsCursedTooltip(container)
	local cursedText = GetLocalizedText("Cursed")
	if cursedText == "" then return false end
	for i = 0, container:GetElementCount() - 1 do
		local widget = container:At(i)
		if widget and widget.GetWString then
			if userMods.FromWString(widget:GetWString()) == cursedText then
				return true
			end
		end
	end
	return false
end

function PushPriceInToolTip(container)
	local Name = container:At(0)
	if not Name or not Name.GetWString then return end
	local Itemname = userMods.FromWString(Name:GetWString())
	local isCursed = IsCursedTooltip(container)
	local rows = FillRows(Itemname, isCursed)
	if not rows then return end

	-- место вставки: перед иконкой-разделителем в конце родного тултипа
	local insertAt = nil
	local count = container:GetElementCount()
	if count > 3 then
		for i = count - 3, count - 1 do
			if container:At(i):GetName() == "IconSmartLine" then
				insertAt = i
				break
			end
		end
	end

	if insertAt then
		local index = insertAt
		for i = 1, #rows do
			container:Insert(index, rows[i])
			index = index + 1
		end
	else
		for i = 1, #rows do
			container:PushBack(rows[i])
		end
	end
	container:ForceReposition()
end

function SearchTooltip(params)
	if params.addonName ~= "ContextTooltip" then return end
	if not params.widget:IsVisibleEx() then
		DestroyDynamic()
		return
	end
	DestroyDynamic()
	local container = params.widget:GetChildUnchecked("Container", false)
	if container then
		PushPriceInToolTip(container)
	end
end

function PriceInTooltipInit()
	common.RegisterEventHandler(SearchTooltip, "EVENT_WIDGET_SHOW_CHANGED")
	common.GetAddonMainForm("ContextTooltip"):GetChildChecked("TooltipMain"):SetOnShowNotification(true)
end

PriceInTooltipInit()