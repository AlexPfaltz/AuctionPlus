--------------------------------------------------------------------------------
-- PriceDBView.lua: окно просмотра базы цен.
-- Слева - список наименований текущего шарда, сгруппированный по первой букве
-- (раскрыта одна группа, крупные группы делятся по двум буквам) с живым
-- поиском по подстроке без учёта регистра (Esc очищает поиск), справа -
-- сводка текущих цен выбранного предмета (минимальная / рыночная / медиана
-- с иконками монет) и столбчатый график динамики медианы по дням.
-- Открывается командой /apdb и плавающей кнопкой на экране (перетаскивается,
-- положение хранится в конфиге). Скрипт самодостаточен: работает и без
-- родного окна аукциона (вспомогательные функции Common.lua тогда недоступны).
--------------------------------------------------------------------------------

local wtPanel = mainForm:GetChildChecked("PriceDBPanel", false)
local wtTitle = wtPanel:GetChildChecked("Header", false):GetChildChecked("Text", false)
local wtEditLine = wtPanel:GetChildChecked("EditLine", false)
local wtCountLabel = wtPanel:GetChildChecked("CountLabel", false)
local wtItems = wtPanel:GetChildChecked("ItemsList", false)
local wtDetails = wtPanel:GetChildChecked("Details", false)
local wtName = wtDetails:GetChildChecked("Name", false)
local wtLotsLine = wtDetails:GetChildChecked("LotsLine", false)
local wtDateLine = wtDetails:GetChildChecked("DateLine", false)
local wtChart = wtDetails:GetChildChecked("Chart", false)
local wtCaption = wtChart:GetChildChecked("Caption", false)
local wtNoData = wtChart:GetChildChecked("NoData", false)
-- Плавающая кнопка открытия базы: доступна всегда, не только в окне аукциона.
local wtFloatBtn = mainForm:GetChildChecked("PriceDBFloat", false)
local wtFloatIcon = wtFloatBtn:GetChildChecked("Icon", false)
local wtFloatGlow = wtFloatBtn:GetChildChecked("Glow", false)
local wtHelpTitle = wtDetails:GetChildChecked("HelpTitle", false)

-- Шаблоны для клонирования (оригиналы остаются скрытыми)
local DescRow = wtPanel:GetChildChecked("ItemRow", false):GetWidgetDesc()
local DescGroup = wtPanel:GetChildChecked("GroupRow", false):GetWidgetDesc()
local DescGroupOpen = wtPanel:GetChildChecked("GroupRowOpen", false):GetWidgetDesc()
local DescBody = wtPanel:GetChildChecked("GroupBody", false):GetWidgetDesc()
local DescPad = wtPanel:GetChildChecked("ListPad", false):GetWidgetDesc()
local DescBar = wtChart:GetChildChecked("Bar", false):GetWidgetDesc()
local DescLine = wtDetails:GetChildChecked("PriceLine", false):GetWidgetDesc()
local DescValue = wtDetails:GetChildChecked("Value", false):GetWidgetDesc()
local DescCoin = wtDetails:GetChildChecked("Coin", false):GetWidgetDesc()
local DescSpace = wtDetails:GetChildChecked("Space", false):GetWidgetDesc()
local DescHelp = wtDetails:GetChildChecked("HelpLine", false):GetWidgetDesc()
local DescYLabel = wtChart:GetChildChecked("YLabel", false):GetWidgetDesc()
local DescTick = wtChart:GetChildChecked("DateTick", false):GetWidgetDesc()

local CoinTex = {
	common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinGold"),
	common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinSilver"),
	common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinCopper"),
}

-- Размеры области графика: совпадают с раскладкой Details/Chart в XDB
-- (Details: 740-376-30 x 580-88-20, Chart: внутренние отступы 14 и 158/14).
-- Слева - полоса под подписи шкалы цен, снизу - риски и подписи дат.
local CHART_W = 306
local CHART_H = 280
local PLOT_LEFT = 92
local PLOT_RIGHT = 8
local PLOT_TOP = 46
local PLOT_BOTTOM = 28
local BAR_MAX_W = 26
local TICK_STEP_PX = 44         -- минимальный шаг между подписями дат
local MAX_ROWS = 300         -- предел строк в одной раскрытой группе (страховка)
local FLAT_LIMIT = 80        -- результатов поиска не больше - показываем без групп
local SPLIT_LIMIT = 120      -- группа крупнее делится на подгруппы по двум буквам
local BODY_PAD = 12          -- отступ строк от краёв бумаги
local ROW_INSET = 12         -- строки внутри бумаги
local LEVEL1_X = 12          -- отступ заголовков и бумаги от кожаной рамки
local LEVEL2_X = 22
local LIST_PAD = 12          -- пустое место сверху и снизу списка (внутри рамки)
local STATE_TTL_MS = 600000  -- сколько помним раскрытую группу после закрытия окна
local HELP_LINES = 5
local FLOAT_SIZE = 36
local FLOAT_SIZE_HOVER = 42
local BAR_COLOR = { a = 1, r = 0.9, g = 0.68, b = 0.22 }
local AXIS_COLOR = { a = 1, r = 0.45, g = 0.38, b = 0.28 }
local GRID_COLOR = { a = 0.35, r = 0.4, g = 0.35, b = 0.28 }

local allRows = {}           -- { key, name, cursed, lower, cur, entry }
local filtered = {}          -- подмножество allRows после поиска
local rowSelects = {}        -- кнопки выбора видимых строк по номеру в filtered
local groups = {}            -- { key, label, rows, subs } по алфавиту
local headerByName = {}      -- виджеты заголовков групп по имени кнопки
local openGroup = nil        -- ключ раскрытой группы (nil - всё свёрнуто)
local openSub = nil          -- то же для подгруппы
local savedGroup, savedSub   -- состояние до начала поиска
local closedAtMs = nil       -- когда окно закрыли (для срока хранения состояния)
local leafTruncated = false
local bars = {}
local decor = {}             -- сетка, подписи шкалы и дат текущего графика
local helpLines = {}
local axes = {}              -- статичные оси графика (скрываются без данных)
local priceLines = {}
local coinRows = {}          -- контейнеры Coins строк "Минимальная/Рыночная/Медиана"
local selectedKey = nil
local searchText = ""
local lastCommitted = 0

local function L(key)
	return GetLocalizedText(key)
end

-- Строки Lua в игре - в кодировке cp1251 (так же, как Localization.lua), поэтому
-- кириллица однобайтовая: А-Я = 0xC0-0xDF, а-я = 0xE0-0xFF, Ё = 0xA8, ё = 0xB8.
-- string.lower их не складывает, поэтому нижний регистр считаем сами.
local function LowerAnsi(s)
	return (string.gsub(s, "[A-Z\192-\223\168]", function(c)
		local b = string.byte(c)
		if b == 0xA8 then return string.char(0xB8) end
		return string.char(b + 0x20)
	end))
end

local function Trim(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- Разряды числа через пробел: 1234567 -> "1 234 567" (своя реализация:
-- common.FormatInt возвращает WString, а не строку)
local function GroupDigits(n)
	local s = tostring(math.floor(n))
	local parts = {}
	local first = #s % 3
	if first > 0 then
		parts[#parts + 1] = string.sub(s, 1, first)
	end
	for i = first + 1, #s, 3 do
		parts[#parts + 1] = string.sub(s, i, i + 2)
	end
	return table.concat(parts, " ")
end

local function FormatDate(ms)
	if not ms then return "-" end
	local dt = common.GetDateTimeFromMs(ms)
	if not dt then return "-" end
	return string.format("%02d.%02d.%04d", dt.d, dt.m, dt.y)
end

-- Уничтожение содержимого контейнера: виджет сначала отсоединяем, иначе
-- DestroyWidget оставляет в контейнере битую ссылку (см. Common.lua)
local function ClearContainer(container)
	while container:GetElementCount() > 0 do
		local widget = container:At(0)
		container:RemoveAt(0)
		if widget then
			widget:DestroyWidget()
		end
	end
end

local function ClearItems()
	ClearContainer(wtItems)
	rowSelects = {}
	headerByName = {}
end

--------------------------------------------------------------------------------
-- Список
--------------------------------------------------------------------------------
local function RebuildCache()
	allRows = {}
	local items = PriceDB.GetShardItems()
	if not items then return end
	for key, entry in pairs(items) do
		if type(entry) == "table" and type(entry.cur) == "table" then
			local name = key
			local cursed = false
			if string.sub(key, -2) == "|c" then
				name = string.sub(key, 1, -3)
				cursed = true
			end
			allRows[#allRows + 1] = {
				key = key, name = name, cursed = cursed,
				lower = LowerAnsi(name), cur = entry.cur, entry = entry,
			}
			allRows[#allRows].sk = string.gsub(allRows[#allRows].lower, "\184", "\229")
		end
	end
	table.sort(allRows, function(a, b) return a.sk < b.sk end)
end

local function ApplyFilter()
	local needle = searchText ~= "" and LowerAnsi(searchText) or nil
	filtered = {}
	for i = 1, #allRows do
		local row = allRows[i]
		if not needle or string.find(row.lower, needle, 1, true) then
			filtered[#filtered + 1] = row
			row.fi = #filtered
		end
	end
end

--------------------------------------------------------------------------------
-- Группировка по первой букве названия
--------------------------------------------------------------------------------
-- Ранг группы (1 - кириллица, 2 - латиница, 3 - цифры) и код строчной буквы
-- по однобайтовому коду cp1251. "Ё" приравнивается к "Е", прочие символы
-- (кавычки, скобки, пробелы) пропускаются.
local function Classify(b)
	if b >= 0x61 and b <= 0x7A then return 2, b end
	if b >= 0x41 and b <= 0x5A then return 2, b + 32 end
	if b >= 0x30 and b <= 0x39 then return 3, 0x30 end
	if b == 0xB8 or b == 0xA8 then return 1, 0xE5 end
	if b >= 0xE0 then return 1, b end
	if b >= 0xC0 then return 1, b + 32 end
	return nil
end

-- Первые две значащие буквы названия (в нижнем регистре)
local function LeadingLetters(lower)
	local found = {}
	for i = 1, string.len(lower) do
		local rank, code = Classify(string.byte(lower, i))
		if rank then
			found[#found + 1] = { rank = rank, code = code }
			if #found == 2 then break end
		end
	end
	return found
end

local function BuildGroups()
	groups = {}
	local byKey = {}
	for i = 1, #filtered do
		local row = filtered[i]
		local lead = LeadingLetters(row.lower)
		local first, second = lead[1], lead[2]
		local key = first and (first.rank * 1000000 + first.code) or 4000000
		local group = byKey[key]
		if not group then
			local label = "#"
			local splittable = false
			if first and first.rank == 3 then
				label = "0-9"
			elseif first then
				label = string.char(first.code - 32)
				splittable = true
			end
			group = { key = key, label = label, rows = {}, splittable = splittable }
			byKey[key] = group
			groups[#groups + 1] = group
		end
		group.rows[#group.rows + 1] = row
		row.subKey = second and (second.rank * 1000000 + second.code) or 0
		row.subCode = second and second.code or nil
	end
	table.sort(groups, function(a, b) return a.key < b.key end)

	-- крупные группы делим по второй букве: "С" -> "Св", "Се", "Си"...
	for g = 1, #groups do
		local group = groups[g]
		if group.splittable and #group.rows > SPLIT_LIMIT then
			local subBy = {}
			group.subs = {}
			for i = 1, #group.rows do
				local row = group.rows[i]
				local sub = subBy[row.subKey]
				if not sub then
					sub = {
						key = row.subKey,
						label = group.label .. (row.subCode and string.char(row.subCode) or ""),
						rows = {},
					}
					subBy[row.subKey] = sub
					group.subs[#group.subs + 1] = sub
				end
				sub.rows[#sub.rows + 1] = row
			end
			table.sort(group.subs, function(a, b) return a.key < b.key end)
		end
	end

	-- раскрытая группа могла исчезнуть после поиска или обновления базы
	if openGroup then
		local exists = false
		for g = 1, #groups do
			if groups[g].key == openGroup then exists = true end
		end
		if not exists then openGroup = nil end
	end
end

local function UpdateCountLabel()
	local text
	if searchText ~= "" then
		text = L("PriceDBFound") .. tostring(#filtered) .. L("PriceDBOf") .. tostring(#allRows)
	else
		text = L("PriceDBCount") .. tostring(#allRows)
	end
	if leafTruncated then
		text = text .. " " .. L("PriceDBLimit")
	end
	wtCountLabel:SetVal("value", userMods.ToWString(text))
end

-- Высота строки списка: длинные названия переносятся на 2-3 строки
-- (оценка по числу символов: ширина текста заранее неизвестна)
local CHARS_PER_LINE = 30
local function RowHeight(name)
	local chars = select(2, name:gsub("[^\128-\191]", ""))
	local lines = math.max(1, math.min(3, math.ceil(chars / CHARS_PER_LINE)))
	return lines == 1 and 24 or (6 + 17 * lines)
end

-- Пергаментная подложка: строки группы лежат внутри неё (как в "Достижениях")
local function CreateBody()
	local body = mainForm:CreateWidgetByDesc(DescBody)
	mainForm:AddChild(body)
	return body
end

local function FinishBody(body, bottomY, posX)
	local place = body:GetPlacementPlain()
	place.posX = posX
	place.sizeY = bottomY + BODY_PAD
	body:SetPlacementPlain(place)
	body:Show(true)
	wtItems:PushBack(body)
end

-- Строка внутри подложки; возвращает высоту строки
local function AddRowTo(body, y, row, text)
	local widget = mainForm:CreateWidgetByDesc(DescRow)
	body:AddChild(widget)
	local name = text or (row.name .. (row.cursed and L("PriceDBCursedMark") or ""))
	widget:GetChildChecked("Text", false):SetVal("text", userMods.ToWString(name))
	local height = RowHeight(name)
	local place = widget:GetPlacementPlain()
	place.posX = ROW_INSET
	place.highPosX = ROW_INSET
	place.posY = y
	place.sizeY = height
	widget:SetPlacementPlain(place)
	local select = widget:GetChildChecked("Select", false)
	if row then
		select:SetName("sel: " .. row.fi)
		select:SetVariant(row.key == selectedKey and 1 or 0)
		rowSelects[row.fi] = select
	else
		select:Enable(false)
	end
	widget:Show(true)
	return height
end

-- Строки предметов на одной подложке; posX - отступ подложки слева
local function AddRows(rows, posX)
	local count = math.min(#rows, MAX_ROWS)
	if #rows > MAX_ROWS then leafTruncated = true end
	local body = CreateBody()
	local y = BODY_PAD
	for i = 1, count do
		y = y + AddRowTo(body, y, rows[i])
	end
	FinishBody(body, y, posX)
end

-- Заголовок группы: буква, число записей; знак "+"/"-" - в самой кнопке
local function AddHeader(label, count, open, buttonName, level)
	local widget = mainForm:CreateWidgetByDesc(open and DescGroupOpen or DescGroup)
	mainForm:AddChild(widget)
	widget:GetChildChecked("Text", false):SetVal("text", userMods.ToWString(label))
	widget:GetChildChecked("Sign", false):SetVal("text", userMods.ToWString("(" .. tostring(count) .. ")"))
	local place = widget:GetPlacementPlain()
	place.posX = level == 1 and LEVEL1_X or LEVEL2_X
	widget:SetPlacementPlain(place)
	widget:GetChildChecked("Toggle", false):SetName(buttonName)
	widget:Show(true)
	wtItems:PushBack(widget)
	headerByName[buttonName] = widget
end

-- Прозрачная распорка высотой LIST_PAD: отступ от рамки подложки
local function AddPad()
	local pad = mainForm:CreateWidgetByDesc(DescPad)
	mainForm:AddChild(pad)
	local place = pad:GetPlacementPlain()
	place.sizeY = LIST_PAD
	pad:SetPlacementPlain(place)
	pad:Show(true)
	wtItems:PushBack(pad)
end

local function RenderList()
	ClearItems()
	leafTruncated = false
	AddPad()
	if #filtered == 0 then
		-- пустая база или пустой результат поиска - строка-подсказка
		local body = CreateBody()
		local height = AddRowTo(body, BODY_PAD, nil, L("PriceDBEmpty"))
		FinishBody(body, BODY_PAD + height, LEVEL1_X)
		AddPad()
		UpdateCountLabel()
		return
	end

	-- небольшой результат поиска показываем плоским списком, без групп
	if searchText ~= "" and #filtered <= FLAT_LIMIT then
		AddRows(filtered, LEVEL1_X)
		AddPad()
		UpdateCountLabel()
		return
	end

	for g = 1, #groups do
		local group = groups[g]
		local isOpen = group.key == openGroup
		AddHeader(group.label, #group.rows, isOpen, "grp: " .. g, 1)
		if isOpen then
			if group.subs then
				for s = 1, #group.subs do
					local sub = group.subs[s]
					local subOpen = sub.key == openSub
					AddHeader(sub.label, #sub.rows, subOpen, "sub: " .. g .. ":" .. s, 2)
					if subOpen then
						AddRows(sub.rows, LEVEL2_X)
					end
				end
			else
				AddRows(group.rows, LEVEL1_X)
			end
		end
	end
	AddPad()
	UpdateCountLabel()
end

--------------------------------------------------------------------------------
-- Цена с иконками монет: значение + монета для каждого ненулевого разряда
--------------------------------------------------------------------------------
local function FillCoins(container, copper, maxParts)
	ClearContainer(container)
	copper = math.floor((copper or 0) + 0.5)
	local money = {
		math.floor(copper / 10000),
		math.floor((copper % 10000) / 100),
		copper % 100,
	}
	local first = true
	local parts = 0
	for i = 1, 3 do
		if (money[i] > 0 or copper == 0 and i == 3) and (not maxParts or parts < maxParts) then
			parts = parts + 1
			if not first then
				local space = mainForm:CreateWidgetByDesc(DescSpace)
				mainForm:AddChild(space)
				space:Show(true)
				container:PushBack(space)
			end
			local value = mainForm:CreateWidgetByDesc(DescValue)
			mainForm:AddChild(value)
			value:SetVal("value", userMods.ToWString(i == 1 and GroupDigits(money[i]) or tostring(money[i])))
			value:Show(true)
			local icon = mainForm:CreateWidgetByDesc(DescCoin)
			mainForm:AddChild(icon)
			icon:SetBackgroundTexture(CoinTex[i])
			icon:Show(true)
			container:PushBack(value)
			container:PushBack(icon)
			first = false
		end
	end
end

--------------------------------------------------------------------------------
-- Детали и график
--------------------------------------------------------------------------------
local function ClearChart()
	for i = 1, #bars do
		bars[i]:DestroyWidget()
	end
	bars = {}
	for i = 1, #decor do
		local item = decor[i]
		if item.container then
			ClearContainer(item.widget)
		end
		item.widget:DestroyWidget()
	end
	decor = {}
end

local function ShowChartLabels(show)
	wtCaption:Show(show)
	for i = 1, #axes do
		axes[i]:Show(show)
	end
end

local function ShortDate(ms, withYear)
	local dt = ms and common.GetDateTimeFromMs(ms)
	if not dt then return "-" end
	if withYear then
		return string.format("%02d.%02d.%02d", dt.d, dt.m, dt.y % 100)
	end
	return string.format("%02d.%02d", dt.d, dt.m)
end

local function EntryTime(e)
	return e.t or (e.d and e.d * 86400000) or nil
end

-- Примерная ширина цены в монетах (для размещения подписи у края графика)
local function EstimateCoinsWidth(copper, maxParts)
	local money = { math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }
	local width, parts = 0, 0
	for i = 1, 3 do
		if money[i] > 0 and parts < maxParts then
			parts = parts + 1
			local n = #tostring(money[i])
			width = width + n * 8 + math.floor((n - 1) / 3) * 4 + 22
		end
	end
	return math.max(width, 28)
end

-- Прямоугольник в координатах графика: X слева, Y от нижнего края
local function AddRect(posX, sizeX, highPosY, sizeY, color)
	local rect = mainForm:CreateWidgetByDesc(DescBar)
	wtChart:AddChild(rect)
	local place = rect:GetPlacementPlain()
	place.posX = posX
	place.sizeX = sizeX
	place.highPosY = highPosY
	place.sizeY = sizeY
	rect:SetPlacementPlain(place)
	rect:SetBackgroundColor(color)
	rect:Show(true)
	return rect
end

-- "Красивый" шаг шкалы (1, 2, 5 x 10^k меди), чтобы подписи были круглыми
local function NiceStep(range, wanted)
	local rough = math.max(1, range / wanted)
	local mag = 10 ^ math.floor(math.log10(rough))
	local norm = rough / mag
	local nice = norm <= 1 and 1 or norm <= 2 and 2 or norm <= 5 and 5 or 10
	return math.max(1, nice * mag)
end

-- Столбчатый график медианы по дням: слева шкала цен с линиями сетки,
-- снизу даты (при большом числе дней - только равномерно выбранные).
local function RenderChart(entry)
	ClearChart()
	local history = type(entry) == "table" and entry.h or nil
	local show = type(history) == "table" and #history >= 2
	ShowChartLabels(show)
	if not show then
		wtNoData:SetVal("value", userMods.ToWString(L("PriceDBNoData")))
		wtNoData:Show(true)
		return
	end
	wtNoData:Show(false)
	wtCaption:SetVal("value", userMods.ToWString(L("PriceDBChartCaption")))

	local count = #history
	local minV, maxV
	local values = {}
	for i = 1, count do
		local value = history[i].med or history[i].min or 0
		values[i] = value
		if not minV or value < minV then minV = value end
		if not maxV or value > maxV then maxV = value end
	end

	-- шкала цен: границы и шаг кратны "круглому" числу
	local step = NiceStep(maxV - minV, 4)
	local lower = math.floor(minV / step) * step
	local upper = math.ceil(maxV / step) * step
	if upper <= lower then upper = lower + step end
	while (upper - lower) / step > 6 do
		step = step * 2
		lower = math.floor(minV / step) * step
		upper = math.ceil(maxV / step) * step
	end
	local span = upper - lower

	local baseY = PLOT_BOTTOM + 2
	local plotX = PLOT_LEFT + 2
	local plotW = CHART_W - PLOT_LEFT - 2 - PLOT_RIGHT
	local plotH = CHART_H - PLOT_TOP - PLOT_BOTTOM - 2

	-- линии сетки и подписи цен слева от оси
	local value = lower
	while value <= upper do
		local y = baseY + math.floor((value - lower) / span * plotH + 0.5)
		if value > lower then
			decor[#decor + 1] = { widget = AddRect(plotX, plotW, y, 1, GRID_COLOR) }
		end
		local label = mainForm:CreateWidgetByDesc(DescYLabel)
		wtChart:AddChild(label)
		local place = label:GetPlacementPlain()
		place.posY = math.max(0, CHART_H - y - 9)
		label:SetPlacementPlain(place)
		local gold = math.floor(value / 10000)
		FillCoins(label, value, gold >= 1000 and 1 or 2)
		label:Show(true)
		decor[#decor + 1] = { widget = label, container = true }
		value = value + step
	end

	-- столбики: в центре своей ячейки
	local cell = plotW / count
	local gap = cell >= 4 and 2 or (cell >= 3 and 1 or 0)
	local barW = math.min(BAR_MAX_W, math.max(2, math.floor(cell) - gap))
	local centers = {}
	for i = 1, count do
		local height = math.max(2, math.floor((values[i] - lower) / span * plotH + 0.5))
		local left = plotX + math.floor((i - 1) * cell + (cell - barW) / 2)
		centers[i] = left + barW / 2
		bars[i] = AddRect(left, barW, baseY, height, BAR_COLOR)
	end

	-- точные цены над столбиками (не чаще, чем позволяет ширина) 
	local valueLabels = math.max(1, math.min(count, math.floor(plotW / 100)))
	for k = 0, valueLabels - 1 do
		local idx = valueLabels == 1 and count or 1 + math.floor((count - 1) * k / (valueLabels - 1) + 0.5)
		local label = mainForm:CreateWidgetByDesc(DescYLabel)
		wtChart:AddChild(label)
		local place = label:GetPlacementPlain()
		local top = baseY + math.max(2, math.floor((values[idx] - lower) / span * plotH + 0.5))
		local parts = EstimateCoinsWidth(values[idx], 3) <= 100 and 3 or 2
		local width = EstimateCoinsWidth(values[idx], parts)
		place.sizeX = width + 8
		place.posX = math.max(plotX, math.min(math.floor(centers[idx] - width / 2), CHART_W - width - 8))
		place.posY = math.max(22, CHART_H - top - 20)
		label:SetPlacementPlain(place)
		FillCoins(label, values[idx], parts)
		label:Show(true)
		decor[#decor + 1] = { widget = label, container = true }
	end

	-- риски и подписи дат
	local firstT, lastT = EntryTime(history[1]), EntryTime(history[count])
	local fdt = firstT and common.GetDateTimeFromMs(firstT)
	local ldt = lastT and common.GetDateTimeFromMs(lastT)
	local withYear = fdt and ldt and fdt.y ~= ldt.y
	local tickPx = withYear and TICK_STEP_PX + 14 or TICK_STEP_PX
	local ticks = math.max(2, math.min(count, math.floor(plotW / tickPx)))
	if count <= ticks + 1 then ticks = count end
	local labelW = 56
	for k = 0, ticks - 1 do
		local idx = 1 + math.floor((count - 1) * k / (ticks - 1) + 0.5)
		decor[#decor + 1] = { widget = AddRect(math.floor(centers[idx]), 1, PLOT_BOTTOM - 4, 4, AXIS_COLOR) }
		local tick = mainForm:CreateWidgetByDesc(DescTick)
		wtChart:AddChild(tick)
		local place = tick:GetPlacementPlain()
		place.posX = math.max(PLOT_LEFT - 8, math.min(math.floor(centers[idx] - labelW / 2), CHART_W - labelW))
		tick:SetPlacementPlain(place)
		tick:SetVal("value", userMods.ToWString(ShortDate(EntryTime(history[idx]), withYear)))
		tick:Show(true)
		decor[#decor + 1] = { widget = tick }
	end
end

-- Высота абзаца подсказки: число строк оценивается по символам с переносом по словам
local HELP_CHARS_PER_LINE = 34
local HELP_LINE_H = 17
local function HelpLineCount(text)
	local lines, cur = 1, 0
	for word in string.gmatch(text, "%S+") do
		local len = string.len(word)
		if cur > 0 and cur + 1 + len > HELP_CHARS_PER_LINE then
			lines = lines + 1
			cur = len
		else
			cur = cur + (cur > 0 and 1 or 0) + len
		end
	end
	return lines
end

-- Страница подсказок: пока предмет не выбран (и после сброса)
local function ShowHelpBody()
	wtName:SetVal("text", userMods.ToWString(""))
	wtLotsLine:SetVal("value", userMods.ToWString(""))
	wtDateLine:SetVal("value", userMods.ToWString(""))
	for i = 1, #priceLines do
		priceLines[i]:Show(false)
		ClearContainer(coinRows[i])
	end
	ClearChart()
	ShowChartLabels(false)
	wtNoData:Show(false)
	wtChart:Show(false)
	wtHelpTitle:SetVal("value", userMods.ToWString(L("PriceDBHelpTitle")))
	wtHelpTitle:Show(true)
	local y = 56
	for i = 1, #helpLines do
		local text = L("PriceDBHelp" .. i)
		local height = HelpLineCount(text) * HELP_LINE_H + 4
		helpLines[i]:SetVal("value", userMods.ToWString(text))
		local place = helpLines[i]:GetPlacementPlain()
		place.posY = y
		place.sizeY = height
		helpLines[i]:SetPlacementPlain(place)
		helpLines[i]:Show(true)
		y = y + height + 12
	end
end

local function HideHelp()
	wtHelpTitle:Show(false)
	for i = 1, #helpLines do
		helpLines[i]:Show(false)
	end
	for i = 1, #priceLines do
		priceLines[i]:Show(true)
	end
	wtChart:Show(true)
end

local function ShowDetails(row)
	HideHelp()
	local name = row.name .. (row.cursed and L("PriceDBCursedMark") or "")
	wtName:SetVal("text", userMods.ToWString(name))
	local cur = row.cur
	FillCoins(coinRows[1], cur.min)
	FillCoins(coinRows[2], cur.q1)
	FillCoins(coinRows[3], cur.med)
	local lots = L("PriceLots") .. tostring(cur.n or 0)
	if cur.u then
		lots = lots .. L("PriceUnits") .. tostring(cur.u)
	end
	wtLotsLine:SetVal("value", userMods.ToWString(lots))
	wtDateLine:SetVal("value", userMods.ToWString(L("PriceDBScanDate") .. FormatDate(cur.t)))
	RenderChart(row.entry)
end

-- Повторная подсветка выбранной строки после перестроения списка
local function ReselectDetails()
	if not selectedKey then
		ShowHelpBody()
		return
	end
	for i = 1, #allRows do
		if allRows[i].key == selectedKey then
			ShowDetails(allRows[i])
			return
		end
	end
	selectedKey = nil
	ShowHelpBody()
end

--------------------------------------------------------------------------------
-- Открытие и закрытие
--------------------------------------------------------------------------------
local function RefreshPanel()
	RebuildCache()
	ApplyFilter()
	BuildGroups()
	RenderList()
	ReselectDetails()
	lastCommitted = PriceDB.stats.committed or 0
end

local function Open()
	selectedKey = nil
	-- раскрытую группу помним STATE_TTL_MS после закрытия окна
	if closedAtMs and common.GetLocalDateTimeMs() - closedAtMs > STATE_TTL_MS then
		openGroup, openSub, savedGroup, savedSub = nil, nil, nil, nil
	end
	closedAtMs = nil
	RefreshPanel()
	wtPanel:Show(true)
end

function PriceDBOpen()
	Open()
end

function PriceDBClose()
	if wtPanel:IsVisible() then
		closedAtMs = common.GetLocalDateTimeMs()
	end
	wtPanel:Show(false)
end

-- Окончание перетаскивания кнопки не должно считаться кликом
function PriceDBToggle()
	if DnD.IsDragging and DnD.IsDragging() then return end
	if wtPanel:IsVisible() then
		PriceDBClose()
	else
		Open()
	end
end

--------------------------------------------------------------------------------
-- Поиск
--------------------------------------------------------------------------------
-- Текст поля ввода без подсказки и пробелов по краям
local function EffectiveSearchText()
	local text = userMods.FromWString(wtEditLine:GetText())
	if text == L("PriceDBSearchHint") then return "" end
	return Trim(text)
end

local function ApplySearch()
	local newText = EffectiveSearchText()
	if searchText == "" and newText ~= "" then
		savedGroup, savedSub = openGroup, openSub
	end
	searchText = newText
	if newText == "" then
		openGroup, openSub = savedGroup, savedSub
	else
		openGroup, openSub = nil, nil
	end
	ApplyFilter()
	BuildGroups()
	-- единственная группа в результатах поиска раскрывается сама
	if newText ~= "" and #groups == 1 then
		openGroup = groups[1].key
		if groups[1].subs and #groups[1].subs == 1 then
			openSub = groups[1].subs[1].key
		end
	end
	RenderList()
end

function PriceDBSearchEnter()
	ApplySearch()
	wtEditLine:SetFocus(false)
end

function PriceDBSearchPressed()
	ApplySearch()
end

-- Esc: снимает фокус и очищает поиск (вместо прежней кнопки "Сброс")
function PriceDBSearchEsc()
	wtEditLine:SetFocus(false)
	if searchText ~= "" or EffectiveSearchText() ~= "" then
		wtEditLine:SetText(userMods.ToWString(L("PriceDBSearchHint")))
		ApplySearch()
	else
		wtEditLine:SetText(userMods.ToWString(L("PriceDBSearchHint")))
	end
end

-- Подсказка в поле поиска: прячем при фокусе, возвращаем на пустой текст
function PriceDBSearchFocus(reaction)
	if reaction.active then
		if userMods.FromWString(wtEditLine:GetText()) == L("PriceDBSearchHint") then
			wtEditLine:SetText(userMods.ToWString(""))
		end
	elseif userMods.FromWString(wtEditLine:GetText()) == "" then
		wtEditLine:SetText(userMods.ToWString(L("PriceDBSearchHint")))
	end
end

--------------------------------------------------------------------------------
-- Выбор строки
--------------------------------------------------------------------------------
function PriceDBSelectItem(reaction)
	local index = tonumber(string.sub(reaction.sender, 6))
	local row = index and filtered[index]
	if not row then return end
	selectedKey = row.key
	for i, button in pairs(rowSelects) do
		button:SetVariant(i == index and 1 or 0)
	end
	ShowDetails(row)
end

-- Заголовок группы: раскрывает её (предыдущая сворачивается) или сворачивает
function PriceDBToggleGroup(reaction)
	local kind, g, s = string.match(reaction.sender, "^(%a+): (%d+):?(%d*)$")
	local group = g and groups[tonumber(g)]
	if not group then return end
	if kind == "grp" then
		if openGroup == group.key then
			openGroup = nil
		else
			openGroup = group.key
		end
		openSub = nil
	elseif kind == "sub" then
		local sub = group.subs and group.subs[tonumber(s)]
		if not sub then return end
		if openSub == sub.key then
			openSub = nil
		else
			openSub = sub.key
		end
	else
		return
	end
	RenderList()
	local header = headerByName[reaction.sender]
	if header and wtItems:IsContain(header) then
		wtItems:EnsureVisible(header)
	end
end

--------------------------------------------------------------------------------
-- Плавающая кнопка: как у родных кнопок - значок плавно увеличивается, в
-- центре появляется свечение, рядом всплывает подсказка (TabHint.lua)
--------------------------------------------------------------------------------
function PriceDBFloatOver(params)
	local active = params.active and true or false
	local size = active and FLOAT_SIZE_HOVER or FLOAT_SIZE
	wtFloatIcon:PlayResizeEffect(nil, { sizeX = size, sizeY = size }, 140, EA_MONOTONOUS_INCREASE)
	wtFloatGlow:PlayFadeEffect(nil, active and 1 or 0, active and 140 or 220, EA_MONOTONOUS_INCREASE)
	if ShowAuctionPlusHint then
		ShowAuctionPlusHint(params)
	end
end

--------------------------------------------------------------------------------
-- Команда чата, живой поиск и обновление базы во время скана
--------------------------------------------------------------------------------
local function OnSlashCommand(params)
	if userMods.FromWString(params.text) == "/apdb" then
		PriceDBToggle()
	end
end

local function OnSecondTimer()
	if not wtPanel:IsVisible() then return end
	-- живой поиск: применяем текст поля без ожидания Enter
	if EffectiveSearchText() ~= searchText then
		ApplySearch()
	end
	if (PriceDB.stats.committed or 0) ~= lastCommitted then
		RefreshPanel()
	end
end

common.RegisterReactionHandler(PriceDBOpen, "PriceDBOpen")
common.RegisterReactionHandler(PriceDBClose, "PriceDBClose")
common.RegisterReactionHandler(PriceDBToggle, "PriceDBToggle")
common.RegisterReactionHandler(PriceDBSearchEnter, "PriceDBSearchEnter")
common.RegisterReactionHandler(PriceDBSearchPressed, "PriceDBSearchPressed")
common.RegisterReactionHandler(PriceDBSearchEsc, "PriceDBSearchEsc")
common.RegisterReactionHandler(PriceDBSearchFocus, "PriceDBSearchFocus")
common.RegisterReactionHandler(PriceDBSelectItem, "PriceDBSelectItem")
common.RegisterReactionHandler(PriceDBToggleGroup, "PriceDBToggleGroup")
common.RegisterReactionHandler(PriceDBFloatOver, "PriceDBFloatOver")
common.RegisterEventHandler(OnSlashCommand, "EVENT_UNKNOWN_SLASH_COMMAND")
common.RegisterEventHandler(OnSecondTimer, "EVENT_SECOND_TIMER")

-- Строки цен деталей: клонируем скрытый шаблон PriceLine трижды
local priceLineKeys = { "PriceMinFull", "PriceMarket", "PriceMedian" }
for i = 1, 3 do
	local line = mainForm:CreateWidgetByDesc(DescLine)
	wtDetails:AddChild(line)
	line:SetName("PriceLine" .. i)
	local place = line:GetPlacementPlain()
	place.posY = 60 + (i - 1) * 24
	line:SetPlacementPlain(place)
	line:GetChildChecked("Label", false):SetVal("text", userMods.ToWString(L(priceLineKeys[i])))
	line:Show(true)
	coinRows[i] = line:GetChildChecked("Coins", false)
	priceLines[i] = line
end

-- Страница подсказок: строки клонируются из скрытого шаблона HelpLine
for i = 1, HELP_LINES do
	local line = mainForm:CreateWidgetByDesc(DescHelp)
	wtDetails:AddChild(line)
	line:SetName("HelpLine" .. i)
	local place = line:GetPlacementPlain()
	place.posY = 56 + (i - 1) * 76
	line:SetPlacementPlain(place)
	helpLines[i] = line
end

-- Оси графика: создаются один раз из шаблона столбика (сетка, подписи цен
-- и дат строятся при каждой отрисовке в RenderChart)
local function MakeChartLine(posX, sizeX, highPosY, sizeY, color)
	local line = mainForm:CreateWidgetByDesc(DescBar)
	wtChart:AddChild(line)
	local place = line:GetPlacementPlain()
	place.posX = posX
	place.sizeX = sizeX
	place.highPosY = highPosY
	place.sizeY = sizeY
	line:SetPlacementPlain(place)
	line:SetBackgroundColor(color)
	line:Show(true)
	axes[#axes + 1] = line
end

local axisW = CHART_W - PLOT_LEFT - PLOT_RIGHT
local axisH = CHART_H - PLOT_TOP - PLOT_BOTTOM
MakeChartLine(PLOT_LEFT, 2, PLOT_BOTTOM, axisH, AXIS_COLOR)
MakeChartLine(PLOT_LEFT, axisW, PLOT_BOTTOM, 2, AXIS_COLOR)

wtTitle:SetVal("text", userMods.ToWString(L("PriceDBTitle")))
wtEditLine:SetText(userMods.ToWString(L("PriceDBSearchHint")))
-- Инициализация DnD для плавающей кнопки
DnD.Init(wtFloatBtn, wtFloatBtn, true, true)
-- Инициализация DnD для самого окна (для перетаскивания по заголовку)
DnD.Init(wtPanel, wtTitle, true, true)
ShowHelpBody()
