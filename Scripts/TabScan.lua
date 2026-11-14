--------------------------------------------------------------------------------
-- TabScan.lua: вкладка "Скан".
-- Два окна: ScanPanel - настройка и запуск (setup), ScanRun - отдельное окно
-- поверх неё с ходом скана (run) и отчётом по завершении (done).
-- Данные хода скана берёт из глобальной ScanInfo (ScanAuction.lua).
-- Режимы: 1 - весь аукцион, 2 - категория, 3 - из сумки, 4 - свой список.
-- Для режимов 3/4 задачи показываются встроенным списком (SearchList.lua).
--------------------------------------------------------------------------------
Global("TabScan", {})
Global("btTabScan", mainForm:GetChildChecked("TabScan", false))

local wtPanel = mainForm:GetChildChecked("ScanPanel", false)
local wtRunPanel = mainForm:GetChildChecked("ScanRun", false)
btTabScan:SetVal("button_label", userMods.ToWString(GetLocalizedText("btTabScan")))
-- без ContextAuction остальное всё равно должно выполниться:
-- ScanAuction вызывает TabScan.OnStopped при остановке скана
if AuctionMainPanel then
	AuctionMainPanel:AddChild(btTabScan)
	AuctionMainPanel:AddChild(wtPanel)
	AuctionMainPanel:AddChild(wtRunPanel)
end

local wtTitle = wtPanel:GetChildChecked("Title", false)
-- строки подсказки в окне настройки
local wtLine = {
	wtPanel:GetChildChecked("Line1", false),
	wtPanel:GetChildChecked("Line2", false),
}
local wtParamsInfo = wtPanel:GetChildChecked("ParamsInfo", false)
local wtFrameMode = wtPanel:GetChildChecked("FrameMode", false)
local wtFrameParams = wtPanel:GetChildChecked("FrameParams", false)
-- отдельное окно хода скана и отчёта
local wtRunTitle = wtRunPanel:GetChildChecked("Title", false)
-- строки отчёта по завершении
local wtRunLine = {
	wtRunPanel:GetChildChecked("Line3", false),
	wtRunPanel:GetChildChecked("Line4", false),
	wtRunPanel:GetChildChecked("Line5", false),
}
local wtFrameProgress = wtRunPanel:GetChildChecked("FrameProgress", false)
local wtProgressLabel = wtFrameProgress:GetChildChecked("Label", false)
local wtBarBack = wtFrameProgress:GetChildChecked("BarBack", false)
local wtBarFill = wtBarBack:GetChildChecked("BarFill", false)
local wtBarText = wtBarBack:GetChildChecked("BarText", false)
local wtItemLine = wtFrameProgress:GetChildChecked("ItemLine", false)
local btStart = wtPanel:GetChildChecked("Start", false)
local btResume = wtPanel:GetChildChecked("Resume", false)
local btStop = wtRunPanel:GetChildChecked("Stop", false)
local btClose = wtRunPanel:GetChildChecked("Close", false)
-- Кнопки способа сканирования: 1 - весь аукцион, 2 - категория, 3 - из сумки, 4 - свой список
local btMode = {}
for i, name in ipairs({ "ModeAll", "ModeCategory", "ModeBag", "ModeList" }) do
	btMode[i] = wtPanel:GetChildChecked(name, false)
end
-- Карточки статистики хода скана (в рамке прогресса)
local CARD_NAMES = { "CardPage", "CardLots", "CardElapsed", "CardRemaining", "CardSpeed", "CardRecorded" }
local wtCard = {}
for _, name in ipairs(CARD_NAMES) do
	wtCard[name] = wtFrameProgress:GetChildChecked(name, false)
end
-- Селекторы фильтра по категориям
local categoryPanel = wtPanel:GetChildChecked("ScanCategory", false)
local categoryBtn = categoryPanel:GetChildChecked("DropBtn", false)
local subcategoryPanel = wtPanel:GetChildChecked("ScanSubcategory", false)
local subcategoryBtn = subcategoryPanel:GetChildChecked("DropBtn", false)
-- Встроенный список задач для режимов "из сумки" и "свой список"
local wtTaskList = wtPanel:GetChildChecked("TaskList", false)
-- Выпадающий список: одна панель на оба селектора, строки создаются по шаблону
local wtDropList = wtPanel:GetChildChecked("DropList", false)
local wtDropItems = wtDropList:GetChildChecked("DropItems", false)
local DescDropItem = wtDropList:GetChildChecked("DropItem", false):GetWidgetDesc()
-- стрелки на кнопках выбора
local arrowTexture = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("AuctionButtonSortDown")
categoryPanel:GetChildChecked("DropArrow", false):SetBackgroundTexture(arrowTexture)
subcategoryPanel:GetChildChecked("DropArrow", false):SetBackgroundTexture(arrowTexture)

local PAGE_TIMES = 20          -- по скольким последним страницам считается скорость
local MIN_SAMPLES = 5          -- сколько страниц нужно, чтобы показать оценку времени
local BAR_PADDING = 12         -- суммарный отступ заливки внутри полосы

local view = "setup"           -- setup | run | done
local pageTimes = {}

local function NowMs()
	return common.GetLocalDateTimeMs()
end

local function L(key)
	return GetLocalizedText(key)
end

local function SetText(widget, text)
	widget:SetVal("value", text)
end

local function SetLines(lines, ...)
	local texts = { ... }
	for i = 1, table.getn(lines) do
		SetText(lines[i], texts[i] or "")
	end
end

local function SetButtonLabel(button, key)
	button:SetVal("button_label", userMods.ToWString(L(key)))
end

-- Forward declarations: селекторы вызывают эти функции.
local RefreshSetup
local SetMode

-- Режимы со встроенным списком задач
local function IsTaskMode(mode)
	return mode == 3 or mode == 4
end

-- Заполнить и показать встроенный список задач для текущего режима
local function RefreshTaskList()
	if not IsTaskMode(Options.ScanBy) then
		HideTaskList()
		return
	end
	ShowTaskList(Options.ScanBy)
end

--------------------------------------------------------------------------------
-- Категории аукциона для ограничения полного скана
--------------------------------------------------------------------------------
local RootCategories = nil
local function EnsureCategories()
	if RootCategories then return end
	RootCategories = {}
	local roots = itemLib.GetRootCategories()
	for i = 0, TableSize(roots) - 1 do
		-- таблицы идентификаторов приходят с дырами: плотный обход
		-- 0..size-1 отдаёт nil, и GetChildCategories падает
		local rootId = roots[i]
		if rootId then
			local info = itemLib.GetCategoryInfo(rootId)
			-- GetRootCategories возвращает и дочерние категории, а
			-- GetChildCategories принимает только корневые (info.root == true)
			if info and info.root == true then
				local children = {}
				local childs = itemLib.GetChildCategories(rootId)
				for j = 0, TableSize(childs) - 1 do
					local childId = childs[j]
					if childId then
						local childInfo = itemLib.GetCategoryInfo(childId)
						if childInfo then
							children[#children + 1] = { id = childId, name = childInfo.name }
						end
					end
				end
				RootCategories[#RootCategories + 1] = {
					id = rootId, name = info.name, children = children,
				}
			end
		end
	end
end

local function RootIndex(id)
	EnsureCategories()
	if not id or id == 0 then return nil end
	for i = 1, #RootCategories do
		if RootCategories[i].id == id then return i end
	end
end

local function ChildIndex(root, id)
	if not root or not id or id == 0 then return nil end
	for i = 1, #root.children do
		if root.children[i].id == id then return i end
	end
end

local function RootNode()
	local index = RootIndex(Options.ScanRootCategory)
	return index and RootCategories[index] or nil
end

local function CategoryLabel(value, fallbackKey)
	if not value or not value.name then return L(fallbackKey or "AllCategories") end
	return userMods.FromWString(value.name)
end

local function SaveOptions()
	userMods.SetGlobalConfigSection("Options", Options)
end

local function RefreshScanSelectors()
	EnsureCategories()
	categoryPanel:GetChildChecked("Text", false):SetVal("text", L("ScanCategoryLabel"))
	subcategoryPanel:GetChildChecked("Text", false):SetVal("text", L("ScanSubcategoryLabel"))

	for i = 1, 4 do
		btMode[i]:SetVariant(Options.ScanBy == i and 1 or 0)
	end

	local root = RootNode()
	categoryBtn:SetVal("button_label", root and root.name or userMods.ToWString(L("AllCategories")))
	local childIndex = root and ChildIndex(root, Options.ScanChildCategory) or nil
	subcategoryBtn:SetVal("button_label",
		childIndex and root.children[childIndex].name or userMods.ToWString(L("AllSubcategories")))
	subcategoryBtn:Enable(root ~= nil)
	categoryBtn:Enable(true)
end

--------------------------------------------------------------------------------
-- Выпадающие списки категорий и подкатегорий
--------------------------------------------------------------------------------
local DROP_ROW_HEIGHT = 28                              -- высота строки списка с промежутком
local DROP_MAX_ROWS = 10                                -- сколько строк видно без прокрутки
local DROP_TOP = { category = 226, subcategory = 262 }  -- верхний край списка (под строкой селектора)
local dropKind = nil                                    -- "category" | "subcategory" | nil
local dropEntries = {}                                  -- { text = WString, id = число }

local function CloseDrop()
	dropKind = nil
	dropEntries = {}
	wtDropList:Show(false)
	DestroyWidgetsInContainer(wtDropItems)
end

local function BuildDropEntries(kind)
	EnsureCategories()
	local entries = {}
	if kind == "category" then
		entries[1] = { text = userMods.ToWString(L("AllCategories")), id = 0 }
		for i = 1, #RootCategories do
			entries[#entries + 1] = { text = RootCategories[i].name, id = RootCategories[i].id }
		end
	else
		local root = RootNode()
		if not root then return nil end
		entries[1] = { text = userMods.ToWString(L("AllSubcategories")), id = 0 }
		for i = 1, #root.children do
			entries[#entries + 1] = { text = root.children[i].name, id = root.children[i].id }
		end
	end
	return entries
end

local function OpenDrop(kind)
	if dropKind == kind then
		CloseDrop()
		return
	end
	local entries = BuildDropEntries(kind)
	if not entries then return end
	CloseDrop()
	dropEntries = entries
	local current = (kind == "category") and (Options.ScanRootCategory or 0) or (Options.ScanChildCategory or 0)
	local currentRow = nil
	for i = 1, #entries do
		local row = mainForm:CreateWidgetByDesc(DescDropItem)
		mainForm:AddChild(row)
		row:SetName("dd" .. i)
		row:Show(true)
		row:SetVal("button_label", entries[i].text)
		wtDropItems:PushBack(row)
		if entries[i].id == current then currentRow = row end
	end
	local place = wtDropList:GetPlacementPlain()
	place.posY = DROP_TOP[kind]
	place.sizeY = math.min(#entries, DROP_MAX_ROWS) * DROP_ROW_HEIGHT + 8
	wtDropList:SetPlacementPlain(place)
	wtDropList:Show(true)
	if currentRow then wtDropItems:EnsureVisible(currentRow) end
	dropKind = kind
end

local function SelectDrop(index)
	local entry = dropEntries[index]
	if not entry then return end
	if dropKind == "category" then
		Options.ScanRootCategory = entry.id
		Options.ScanChildCategory = 0
	else
		Options.ScanChildCategory = entry.id
	end
	SaveOptions()
	CloseDrop()
	RefreshSetup()
end

-- 1:05 для длительностей в мс
local function FormatClock(ms)
	local total = math.floor(ms / 1000)
	return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

-- "9 мин" / "40 с"
local function FormatDuration(ms)
	local seconds = math.floor(ms / 1000 + 0.5)
	if seconds >= 90 then
		return tostring(math.floor(seconds / 60 + 0.5)) .. L("ScanMin")
	end
	return tostring(math.max(seconds, 1)) .. L("ScanSec")
end

--------------------------------------------------------------------------------
-- Ход скана
--------------------------------------------------------------------------------
-- Доля выполненной работы, 0..1
local function Fraction()
	local pageCount = math.max(ScanInfo.pageCount or 0, 1)
	local pageFraction = math.min((ScanInfo.page or 0) / pageCount, 1)
	if ScanInfo.mode == "list" then
		local items = math.max(ScanInfo.items or 1, 1)
		return math.min(((ScanInfo.item or 1) - 1 + pageFraction) / items, 1)
	end
	return pageFraction
end

-- Оставшееся время в мс или nil, если данных пока мало
local function Remaining(fraction)
	if ScanInfo.mode == "full" then
		if #pageTimes >= MIN_SAMPLES then
			local perPage = (pageTimes[#pageTimes] - pageTimes[1]) / (#pageTimes - 1)
			local left = math.max((ScanInfo.pageCount or 0) - (ScanInfo.page or 0), 0)
			return perPage * left
		end
		return nil
	end
	-- по списку: пропорционально выполненной доле
	if fraction > 0.02 then
		return ScanElapsedMs() * (1 - fraction) / fraction
	end
	return nil
end

-- Страниц в минуту по последним страницам или nil
local function PagesPerMinute()
	if #pageTimes >= 2 then
		local span = (pageTimes[#pageTimes] - pageTimes[1]) / 60000
		if span > 0 then return (#pageTimes - 1) / span end
	end
	return nil
end

-- Ширина полосы в виртуальных единицах (как в LibDnD)
local function BarInnerWidth()
	local rect = wtBarBack:GetRealRect()
	local screen = common.GetPosConverterParams()
	local width = (rect.x2 - rect.x1) * screen.fullVirtualSizeX / screen.realSizeX
	return math.max(width - BAR_PADDING, 0)
end

local function SetBar(fraction)
	local width = math.floor(BarInnerWidth() * fraction)
	SetText(wtBarText, tostring(math.floor(fraction * 100 + 0.5)) .. "%")
	if width < 1 then
		wtBarFill:Show(false)
		return
	end
	local place = wtBarFill:GetPlacementPlain()
	place.sizeX = width
	wtBarFill:SetPlacementPlain(place)
	wtBarFill:Show(true)
end

local function SetCard(name, value)
	SetText(wtCard[name]:GetChildChecked("Value", false), value)
end

local function RefreshRun()
	local fraction = Fraction()
	SetBar(fraction)

	local remaining = Remaining(fraction)
	local speed = PagesPerMinute()

	SetCard("CardPage", tostring(ScanInfo.page or 0) .. L("ScanOf") .. tostring(ScanInfo.pageCount or 0))
	SetCard("CardLots", tostring(ScanInfo.lots or 0))
	SetCard("CardElapsed", FormatClock(ScanElapsedMs()))
	SetCard("CardRemaining", remaining and ("~" .. FormatDuration(remaining)) or "...")
	SetCard("CardSpeed", speed and (string.format("%.1f", speed) .. L("ScanPagesPerMin")) or "-")
	SetCard("CardRecorded", tostring(PriceDB.stats.committed or 0))

	if ScanInfo.mode == "list" then
		-- в режиме списка над карточками показан текущий предмет
		SetText(wtItemLine, L("ScanItem") .. tostring(ScanInfo.item or 0) .. L("ScanOf")
			.. tostring(ScanInfo.items or 0) .. ": " .. tostring(ScanInfo.itemName or ""))
	end
end

--------------------------------------------------------------------------------
-- Настройка перед запуском
--------------------------------------------------------------------------------
local function ModeInfoText()
	if Options.ScanBy == 1 then
		local meta = PriceDB.GetMeta()
		if meta.fullPages and meta.pageMs then
			return L("ScanInfoAll") .. ": " .. L("ScanApprox") .. tostring(meta.fullPages)
				.. L("ScanPagesShort") .. FormatDuration(meta.fullPages * meta.pageMs) .. L("ScanByLast")
		end
		return L("ScanInfoAll") .. ": " .. L("ScanNoEstimate")
	elseif Options.ScanBy == 2 then
		return L("ScanInfoCategory")
	end
	return L(Options.ScanBy == 3 and "ScanInfoBag" or "ScanInfoList") .. tostring(GetScanTaskCount())
end

-- Раскладка окна настройки зависит от режима: рамка параметров подгоняется
-- под содержимое, а в режимах со списком список растягивается до кнопок.
local layoutMode = nil
local function ApplyLayout(mode)
	if layoutMode == mode then return end
	layoutMode = mode
	local taskMode = IsTaskMode(mode)

	local place = wtFrameParams:GetPlacementPlain()
	place.posY = 142
	if taskMode then
		place.alignY = WIDGET_ALIGN_BOTH
		place.sizeY = 0
		place.highPosY = 140
	else
		place.alignY = WIDGET_ALIGN_LOW
		place.sizeY = mode == 2 and 140 or 64
		place.highPosY = 0
	end
	wtFrameParams:SetPlacementPlain(place)

	place = wtTaskList:GetPlacementPlain()
	place.posY = 194
	if taskMode then
		place.alignY = WIDGET_ALIGN_BOTH
		place.sizeY = 0
		place.highPosY = 152
	else
		place.alignY = WIDGET_ALIGN_LOW
		place.sizeY = 150
		place.highPosY = 0
	end
	wtTaskList:SetPlacementPlain(place)

	-- подсказки: в компактных режимах - сразу под рамкой, в режимах со
	-- списком - внизу окна над кнопками запуска
	local topY = nil
	if not taskMode then
		topY = mode == 2 and 296 or 220
	end
	for i = 1, 2 do
		place = wtLine[i]:GetPlacementPlain()
		if topY then
			place.alignY = WIDGET_ALIGN_LOW
			place.posY = topY + (i - 1) * 26
			place.highPosY = 0
		else
			place.alignY = WIDGET_ALIGN_HIGH
			place.posY = 0
			place.highPosY = 96 - (i - 1) * 24
		end
		wtLine[i]:SetPlacementPlain(place)
	end
end

RefreshSetup = function()
	SetText(wtTitle, L("ScanPanelTitle"))
	ApplyLayout(Options.ScanBy)
	RefreshScanSelectors()
	local category = Options.ScanBy == 2
	categoryPanel:Show(category)
	subcategoryPanel:Show(category)
	if not category then CloseDrop() end

	local taskMode = IsTaskMode(Options.ScanBy)
	wtTaskList:Show(taskMode)

	local busy = auction.IsSearchInProgress()
	local empty = taskMode and GetScanTaskCount() == 0
	btStart:Enable(not empty and not busy)

	local resume = GetResumeInfo()
	local resumeText = ""
	if resume then
		resumeText = L("ScanPaused") .. FormatDuration(resume.leftMs)
	end
	btResume:Show(resume ~= nil)

	local first
	if busy then
		first = L("ScanBusy")
	elseif empty then
		first = L(Options.ScanBy == 3 and "ScanBagEmpty" or "ScanListEmpty")
	else
		first = L("ScanHintStart")
	end
	SetText(wtParamsInfo, ModeInfoText())
	SetLines(wtLine, first, resumeText)
end

local function RefreshDone(completed)
	SetText(wtRunTitle, L(completed and "ScanTitleDone" or "ScanTitleStopped"))
	SetBar(completed and 1 or Fraction())
	SetLines(wtRunLine,
		L("ScanUpdated") .. tostring(ScanInfo.committed or 0),
		L("ScanTime") .. FormatClock(ScanInfo.accMs or 0),
		L("ScanLotsRead") .. tostring(ScanInfo.lots or 0))
end

local function ShowView(name)
	CloseDrop()
	view = name
	local setup, run, done = name == "setup", name == "run", name == "done"
	-- настройка и ход скана - два отдельных окна
	wtPanel:Show(setup)
	wtRunPanel:Show(run or done)
	if setup then
		for i = 1, 4 do
			btMode[i]:Enable(true)
		end
		wtParamsInfo:Show(true)
		local category = Options.ScanBy == 2
		categoryPanel:Show(category)
		subcategoryPanel:Show(category)
		wtTaskList:Show(IsTaskMode(Options.ScanBy))
		RefreshSetup()
		return
	end
	-- окно прогресса: во время скана - карточки, по завершении - строки отчёта
	for _, cardName in ipairs(CARD_NAMES) do
		wtCard[cardName]:Show(run)
	end
	for i = 1, 3 do
		wtRunLine[i]:Show(done)
	end
	wtItemLine:Show(run and ScanInfo.mode == "list")
	btStop:Show(run)
	btClose:Show(done)
	wtProgressLabel:SetVal("text", userMods.ToWString(L(run and "ScanProgressLabel" or "ScanDoneLabel")))
	if run then
		SetText(wtRunTitle, L(ScanInfo.mode == "list" and "ScanTitleList" or "ScanTitleFull"))
		wtBarFill:Show(false)
		RefreshRun()
	else
		RefreshDone(ScanInfo.completed)
	end
end

--------------------------------------------------------------------------------
-- Вызовы из ScanAuction
--------------------------------------------------------------------------------
function TabScan.OnPage()
	pageTimes[#pageTimes + 1] = NowMs()
	if #pageTimes > PAGE_TIMES then
		table.remove(pageTimes, 1)
	end
	if view == "run" then RefreshRun() end
end

-- Скан остановлен: завершён (completed), прерван или поставлен на паузу
function TabScan.OnStopped(completed)
	if AddonTab ~= "scan" then
		view = "setup"
		return
	end
	-- пауза (уход со вкладки) возвращает к настройке, а завершение и
	-- ручная остановка показывают отчёт
	if completed or not ScanInfo.paused then
		ShowView("done")
	else
		ShowView("setup")
	end
end

-- Скан запустился (в том числе отложенный запуск после чужого поиска)
function TabScan.OnStarted()
	if AddonTab == "scan" then
		ShowView("run")
	end
end

--------------------------------------------------------------------------------
-- Открытие и закрытие вкладки
--------------------------------------------------------------------------------
function OpenTabScan()
	SyncAddonTabs()
	if AddonTab == "scan" then
		btTabScan:SetVariant(1)
		return
	end
	if AddonTab == "buy" then CloseTabBuy() end
	if AddonTab == "sell" then CloseTabSell() end
	ShowTabOverlay()
	AddonTab = "scan"
	btTabScan:SetVariant(1)
	wtPanel:Show(true)
	-- сумка могла измениться, пока вкладка была закрыта
	if Options.ScanBy == 3 then
		CheckBag()
	end
	if ScanInfo.active then
		ShowView("run")
	else
		if IsTaskMode(Options.ScanBy) then
			RefreshTaskList()
		end
		ShowView("setup")
	end
end

function CloseTabScan()
	-- отложенный запуск отменяется, идущий скан ставится на паузу:
	-- продолжить можно ограниченное время
	CancelPendingScan()
	PauseScan()
	if AddonTab == "scan" then AddonTab = false end
	CloseDrop()
	wtPanel:Show(false)
	wtRunPanel:Show(false)
	btTabScan:SetVariant(0)
	view = "setup"
	HideTabOverlay()
end

local function OnAuctionVisible(params)
	if params.addonName == "ContextAuction" and params.widget:GetName() == "Main" then
		if params.widget:IsVisible() then
			btTabScan:SetVariant(0)
		elseif AddonTab == "scan" then
			CloseTabScan()
		end
	end
end

--------------------------------------------------------------------------------
-- Кнопки и таймер
--------------------------------------------------------------------------------
SetMode = function(mode)
	if Options.ScanBy == mode then
		RefreshSetup()
		return
	end
	CloseDrop()
	Options.ScanBy = mode
	userMods.SetGlobalConfigSection("Options", Options)
	if mode == 3 then
		CheckBag()
	end
	RefreshTaskList()
	RefreshSetup()
end

function ScanModeAll() SetMode(1) end
function ScanModeCategory() SetMode(2) end
function ScanModeBag() SetMode(3) end
function ScanModeList() SetMode(4) end
function ScanCategoryDrop() OpenDrop("category") end
function ScanSubcategoryDrop() OpenDrop("subcategory") end
function ScanDropItem(reaction)
	SelectDrop(tonumber(string.sub(reaction.sender, 3)))
end

function ScanStartPressed()
	pageTimes = {}
	if StartScan() then
		ShowView("run")
	else
		RefreshSetup()
	end
end

function ScanResumePressed()
	pageTimes = {}
	if ResumeScan() then
		ShowView("run")
	else
		RefreshSetup()
	end
end

function ScanStopPressed()
	StopScan()
end

function ScanClosePressed()
	ShowView("setup")
end

local function OnSecondTimer()
	if AddonTab ~= "scan" then return end
	if view == "run" then
		RefreshRun()
	elseif view == "setup" then
		RefreshSetup()
	end
end

common.RegisterReactionHandler(OpenTabScan, "OpenTabScan")
common.RegisterReactionHandler(ScanModeAll, "ScanModeAll")
common.RegisterReactionHandler(ScanModeCategory, "ScanModeCategory")
common.RegisterReactionHandler(ScanModeBag, "ScanModeBag")
common.RegisterReactionHandler(ScanModeList, "ScanModeList")
common.RegisterReactionHandler(ScanCategoryDrop, "ScanCategoryDrop")
common.RegisterReactionHandler(ScanSubcategoryDrop, "ScanSubcategoryDrop")
common.RegisterReactionHandler(ScanDropItem, "ScanDropItem")
common.RegisterReactionHandler(ScanStartPressed, "ScanStartPressed")
common.RegisterReactionHandler(ScanResumePressed, "ScanResumePressed")
common.RegisterReactionHandler(ScanStopPressed, "ScanStopPressed")
common.RegisterReactionHandler(ScanClosePressed, "ScanClosePressed")
common.RegisterEventHandler(OnAuctionVisible, "EVENT_WIDGET_SHOW_CHANGED")
common.RegisterEventHandler(OnSecondTimer, "EVENT_SECOND_TIMER")

-- подписи рамок блоков
wtFrameMode:GetChildChecked("Label", false):SetVal("text", userMods.ToWString(GetLocalizedText("ScanModeLabel")))
wtFrameParams:GetChildChecked("Label", false):SetVal("text", userMods.ToWString(GetLocalizedText("ScanParamsLabel")))
wtFrameProgress:GetChildChecked("Label", false):SetVal("text", userMods.ToWString(GetLocalizedText("ScanProgressLabel")))
-- подписи карточек статистики
local cardCaptionKeys = {
	CardPage = "ScanCardPage", CardLots = "ScanCardLots", CardElapsed = "ScanCardElapsed",
	CardRemaining = "ScanCardRemaining", CardSpeed = "ScanCardSpeed", CardRecorded = "ScanCardRecorded",
}
for _, name in ipairs(CARD_NAMES) do
	wtCard[name]:GetChildChecked("Caption", false):SetVal("text",
		userMods.ToWString(GetLocalizedText(cardCaptionKeys[name])))
end
-- подписи кнопок режимов
local modeKeys = { "ScanModeAll", "ScanModeCategory", "ScanModeBag", "ScanModeList" }
for i = 1, 4 do
	btMode[i]:SetVal("button_label", userMods.ToWString(GetLocalizedText(modeKeys[i])))
end
-- подписи кнопок
SetButtonLabel(btStart, "ScanStart")
SetButtonLabel(btResume, "ScanResume")
SetButtonLabel(btStop, "ScanStop")
SetButtonLabel(btClose, "ScanClose")
