--------------------------------------------------------------------------------
-- TabScan.lua: вкладка "Скан".
-- Три вида одной панели: setup (выбор режима и запуск), run (ход скана),
-- done (итог). Данные хода скана берёт из глобальной ScanInfo (ScanAuction.lua).
-- Режимы: 1 - весь аукцион, 2 - категория, 3 - из сумки, 4 - свой список.
-- Для режимов 3/4 задачи показываются встроенным списком (SearchList.lua).
--------------------------------------------------------------------------------
Global("TabScan", {})
Global("btTabScan", mainForm:GetChildChecked("TabScan", false))

local wtPanel = mainForm:GetChildChecked("ScanPanel", false)
btTabScan:SetVal("button_label", userMods.ToWString(GetLocalizedText("btTabScan")))
-- без ContextAuction остальное всё равно должно выполниться:
-- ScanAuction вызывает TabScan.OnStopped при остановке скана
if AuctionMainPanel then
	AuctionMainPanel:AddChild(btTabScan)
	AuctionMainPanel:AddChild(wtPanel)
end

local wtTitle = wtPanel:GetChildChecked("Title", false)
local wtLine = {}
for i = 1, 5 do
	wtLine[i] = wtPanel:GetChildChecked("Line" .. i, false)
end
local wtBarBack = wtPanel:GetChildChecked("BarBack", false)
local wtBarFill = wtBarBack:GetChildChecked("BarFill", false)
local btStart = wtPanel:GetChildChecked("Start", false)
local btResume = wtPanel:GetChildChecked("Resume", false)
local btStop = wtPanel:GetChildChecked("Stop", false)
local btClose = wtPanel:GetChildChecked("Close", false)
-- Селекторы способа сканирования и фильтра по категориям.
local modePanel = wtPanel:GetChildChecked("ScanMode", false)
local modeValue = modePanel:GetChildChecked("Value", false)
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

local function SetLines(...)
	local texts = { ... }
	for i = 1, 5 do
		SetText(wtLine[i], texts[i] or "")
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
	modePanel:GetChildChecked("Text", false):SetVal("text", L("ScanModeLabel"))
	categoryPanel:GetChildChecked("Text", false):SetVal("text", L("ScanCategoryLabel"))
	subcategoryPanel:GetChildChecked("Text", false):SetVal("text", L("ScanSubcategoryLabel"))

	local modeKeys = { "ScanModeAll", "ScanModeCategory", "ScanModeBag", "ScanModeList" }
	modeValue:SetVal("value", L(modeKeys[Options.ScanBy] or "ScanModeAll"))

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
local DROP_TOP = { category = 342, subcategory = 377 }  -- верхний край списка (под строкой селектора)
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

local function CycleMode(delta)
	local mode = Options.ScanBy + delta
	if mode < 1 then mode = 4 elseif mode > 4 then mode = 1 end
	SetMode(mode)
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
	if width < 1 then
		wtBarFill:Show(false)
		return
	end
	local place = wtBarFill:GetPlacementPlain()
	place.sizeX = width
	wtBarFill:SetPlacementPlain(place)
	wtBarFill:Show(true)
end

local function RefreshRun()
	local fraction = Fraction()
	SetBar(fraction)

	local remaining = Remaining(fraction)
	local timeText = L("ScanElapsed") .. FormatClock(ScanElapsedMs()) .. "   "
	if remaining then
		timeText = timeText .. L("ScanRemaining") .. FormatDuration(remaining)
	else
		timeText = timeText .. L("ScanCalculating")
	end

	local speed = PagesPerMinute()
	local speedText = ""
	if speed then
		speedText = L("ScanSpeed") .. string.format("%.1f", speed) .. L("ScanPagesPerMin")
	end

	local taskText
	if ScanInfo.mode == "list" then
		taskText = L("ScanItem") .. tostring(ScanInfo.item or 0) .. L("ScanOf")
			.. tostring(ScanInfo.items or 0) .. ": " .. tostring(ScanInfo.itemName or "")
	else
		taskText = L("ScanModeAll")
	end

	if ScanInfo.mode == "list" then
		-- в режиме списка показан встроенный список задач: оставляем две
		-- строки над ним, остальные закрыты списком
		SetLines(
			taskText,
			L("ScanPage") .. tostring(ScanInfo.page or 0) .. L("ScanOf")
				.. tostring(ScanInfo.pageCount or 0) .. L("ScanLots") .. tostring(ScanInfo.lots or 0)
				.. "   " .. timeText)
		return
	end

	SetLines(
		L("ScanPage") .. tostring(ScanInfo.page or 0) .. L("ScanOf")
			.. tostring(ScanInfo.pageCount or 0) .. L("ScanLots") .. tostring(ScanInfo.lots or 0),
		timeText,
		speedText,
		L("ScanRecorded") .. tostring(PriceDB.stats.committed or 0),
		taskText)
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

RefreshSetup = function()
	SetText(wtTitle, L("ScanPanelTitle"))
	RefreshScanSelectors()
	modePanel:Show(true)
	local category = Options.ScanBy == 2
	categoryPanel:Show(category)
	subcategoryPanel:Show(category)
	if not category then CloseDrop() end

	local taskMode = IsTaskMode(Options.ScanBy)
	wtTaskList:Show(taskMode)
	-- строки 3-5 закрыты списком задач
	for i = 3, 5 do wtLine[i]:Show(not taskMode) end

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
		first = ModeInfoText()
	end
	SetLines(first, resumeText)
end

local function RefreshDone()
	SetText(wtTitle, L("ScanTitleDone"))
	SetBar(1)
	SetLines(
		L("ScanUpdated") .. tostring(ScanInfo.committed or 0),
		L("ScanTime") .. FormatClock(ScanInfo.accMs or 0),
		L("ScanLotsRead") .. tostring(ScanInfo.lots or 0))
end

local function ShowView(name)
	CloseDrop()
	view = name
	local setup, run, done = name == "setup", name == "run", name == "done"
	modePanel:Show(setup)
	local category = setup and Options.ScanBy == 2
	categoryPanel:Show(category)
	subcategoryPanel:Show(category)
	-- список задач виден в настройке режимов 3/4 и во время скана по списку
	local taskList = (setup and IsTaskMode(Options.ScanBy))
		or (run and ScanInfo.mode == "list")
	wtTaskList:Show(taskList)
	for i = 3, 5 do wtLine[i]:Show(not taskList) end
	btStart:Show(setup)
	btResume:Show(false)
	btStop:Show(run)
	btClose:Show(done)
	wtBarBack:Show(run or done)
	if name == "setup" then
		RefreshSetup()
	elseif name == "run" then
		SetText(wtTitle, L(ScanInfo.mode == "list" and "ScanTitleList" or "ScanTitleFull"))
		wtBarFill:Show(false)
		RefreshRun()
	else
		RefreshDone()
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
	ShowView(completed and "done" or "setup")
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
	-- идущий скан ставится на паузу: продолжить можно ограниченное время
	PauseScan()
	if AddonTab == "scan" then AddonTab = false end
	CloseDrop()
	wtPanel:Show(false)
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

function ScanModePrev() CycleMode(-1) end
function ScanModeNext() CycleMode(1) end
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
common.RegisterReactionHandler(ScanModePrev, "ScanModePrev")
common.RegisterReactionHandler(ScanModeNext, "ScanModeNext")
common.RegisterReactionHandler(ScanCategoryDrop, "ScanCategoryDrop")
common.RegisterReactionHandler(ScanSubcategoryDrop, "ScanSubcategoryDrop")
common.RegisterReactionHandler(ScanDropItem, "ScanDropItem")
common.RegisterReactionHandler(ScanStartPressed, "ScanStartPressed")
common.RegisterReactionHandler(ScanResumePressed, "ScanResumePressed")
common.RegisterReactionHandler(ScanStopPressed, "ScanStopPressed")
common.RegisterReactionHandler(ScanClosePressed, "ScanClosePressed")
common.RegisterEventHandler(OnAuctionVisible, "EVENT_WIDGET_SHOW_CHANGED")
common.RegisterEventHandler(OnSecondTimer, "EVENT_SECOND_TIMER")

-- подписи кнопок
SetButtonLabel(btStart, "ScanStart")
SetButtonLabel(btResume, "ScanResume")
SetButtonLabel(btStop, "ScanStop")
SetButtonLabel(btClose, "ScanClose")
