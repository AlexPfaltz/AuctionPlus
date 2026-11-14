--------------------------------------------------------------------------------
-- ScanAuction.lua: сканирование цен аукциона.
-- Режимы (Options.ScanBy): 1 - весь аукцион, 2 - категория, 3 - предметы из
-- сумки, 4 - свой список. Скан запускается из вкладки "Скан" (TabScan.lua).
-- Уход с вкладки ставит скан на паузу: продолжить можно только в течение
-- RESUME_TTL_MS, потом начинается заново.
--------------------------------------------------------------------------------
Global("StartFullScan", false)
Global("StartScanForList", false)
-- Состояние текущего скана (для вкладки "Скан")
Global("ScanInfo", { active = false })
Global("BagSearchList", {})

local CurItem = 1
local TaskNames = {}              -- имена для режимов "из сумки" и "свой список"
local ScanStockTab = nil          -- "родная" вкладка, выбранная в момент запуска
local PauseState = nil
local PendingLaunch = nil         -- "start"/"resume": скан ждёт окончания чужого поиска
local LastRequest = { page = 0, ms = 0, retries = 0 }
local WATCHDOG_MS = 15000         -- если страница не пришла за это время, запрашиваем её снова
local MAX_RETRIES = 3
local RESUME_TTL_MS = 10 * 60 * 1000  -- сколько времени после паузы можно продолжить скан
local ScanAuction = {}

local function NowMs()
	return common.GetLocalDateTimeMs()
end

local function NameToString(value)
	if value == nil then return "" end
	if type(value) == "string" then return value end
	if apitype(value) == "WString" then
		return userMods.FromWString(value)
	end
	return tostring(value)
end

function CheckBag()
	local AllBagSlot = containerLib.GetItems( ITEM_CONT_INVENTORY )
	local names = {}
	for k, v in pairs(AllBagSlot) do
		if itemLib.CanCreateAuction(v) then
			names[#names + 1] = itemLib.GetName(v)
		end
	end
	-- порядок итерации по хэш-таблице не гарантирован: сортируем явно
	table.sort(names, function(a, b) return NameToString(a) < NameToString(b) end)
	BagSearchList = names
end

-- Имена предметов для режимов "из сумки" (список строится при открытии окна)
-- и "свой список" (читается из настроек)
local function CollectNames()
	local names = {}
	local source
	if Options.ScanBy == 4 then
		source = userMods.GetGlobalConfigSection("SearchList") or {}
	else
		source = BagSearchList
	end
	for i = 1, table.getn(source) do
		names[#names + 1] = source[i]
	end
	return names
end

-- Сколько задач (предметов) будет в скане по списку/сумке; для полных режимов - 1
function GetScanTaskCount()
	if Options.ScanBy == 1 or Options.ScanBy == 2 then return 1 end
	return table.getn(CollectNames())
end

-- Подпись набора задач: пауза действительна, только если набор не менялся
local function Signature()
	if Options.ScanBy == 1 or Options.ScanBy == 2 then
		return "all|" .. tostring(Options.ScanRootCategory or 0)
			.. "|" .. tostring(Options.ScanChildCategory or 0)
	end
	local parts = {}
	for i = 1, table.getn(TaskNames) do
		parts[#parts + 1] = NameToString(TaskNames[i])
	end
	return table.concat(parts, "|")
end

-- Время работы скана без пауз, мс
function ScanElapsedMs()
	local acc = ScanInfo.accMs or 0
	if ScanInfo.active and ScanInfo.segmentMs then
		return acc + NowMs() - ScanInfo.segmentMs
	end
	return acc
end

-- Запрос страницы результата, отсортированного по имени: лоты одного
-- предмета идут подряд, поэтому предмет можно закрыть при смене имени.
local function RequestPage(page, isRetry)
	LastRequest.page = page
	LastRequest.ms = NowMs()
	if not isRetry then LastRequest.retries = 0 end
	LastRequest.sent = GetPage(page, AUCTION_ORDERFIELD_NAME, true)
	return LastRequest.sent
end

-- Начало прохода: весь аукцион или один предмет из списка.
-- openName - имя предмета, открытого в момент паузы (при продолжении).
local function BeginRun(page, openName)
	SearchFilter = {}
	-- Фильтр по категориям имеет смысл только в режиме "категория":
	-- в режимах "из сумки" и "свой список" поиск идёт по точному имени предмета.
	if Options.ScanBy == 2 then
		local rootId = Options.ScanRootCategory
		if rootId and rootId ~= 0 and itemLib.GetCategoryInfo(rootId) then
			SearchFilter.rootCategory = rootId
			local childId = Options.ScanChildCategory
			if childId and childId ~= 0 and itemLib.GetCategoryInfo(childId) then
				SearchFilter.childCategory = childId
			end
		end
	end
	local requested = nil
	if StartScanForList then
		requested = TaskNames[CurItem]
		-- строки из конфига (cp1251) переводим в WString, WString пропускаем как есть
		local wsName = type(requested) == "string" and userMods.ToWString(requested) or requested
		SearchFilter.name = wsName
		SearchBar.name:SetText(wsName)
		ScanInfo.item = CurItem
		ScanInfo.items = table.getn(TaskNames)
		ScanInfo.itemName = NameToString(requested)
	end
	local resume = nil
	if page and page > 1 then resume = { openName = openName or "" } end
	PriceDB.BeginRun(requested, resume)
	RequestPage(page or 1)
end

local function Finish(completed)
	ScanInfo.accMs = ScanElapsedMs()
	StartFullScan = false
	StartScanForList = false
	ScanStockTab = nil
	ScanInfo.active = false
	ScanInfo.blocked = false
	ScanInfo.finishMs = NowMs()
	ScanInfo.committed = PriceDB.stats.committed
	-- недописанный предмет отбрасывается, закрытые остаются в базе
	PriceDB.AbortRun()
	PriceDB.Save()
	LastRequest.sent = false
	ClearStrikeOutLine()
end

-- Запомнить скорость страниц и объём полного скана для оценки времени в будущем
local function RememberMeta(completed)
	local pages = ScanInfo.pagesDone or 0
	if pages < 5 then return end
	local meta = PriceDB.GetMeta()
	local pageMs = ScanElapsedMs() / pages
	meta.pageMs = meta.pageMs and (meta.pageMs * 0.5 + pageMs * 0.5) or pageMs
	if completed and ScanInfo.mode == "full" then
		meta.fullPages = ScanInfo.pageCount
		meta.fullT = NowMs()
	end
	PriceDB.MarkDirty()
end

-- Запуск (или продолжение после паузы, если передан resume)
local function Launch(resume)
	ScanStockTab = GetCurrentStockTab()
	TaskNames = CollectNames()

	if Options.ScanBy >= 3 and table.getn(TaskNames) == 0 then
		return false
	end

	ScanInfo.blocked = false
	if resume then
		ScanInfo = resume.info
		ScanInfo.active = true
		ScanInfo.paused = false
		ScanInfo.completed = nil
	else
		PriceDB.stats.committed = 0
		ScanInfo = {
			active = true, accMs = 0, page = 0, pageCount = 0, total = 0,
			lots = 0, pagesDone = 0,
		}
	end
	ScanInfo.startMs = ScanInfo.startMs or NowMs()
	ScanInfo.segmentMs = NowMs()

	if Options.ScanBy == 1 or Options.ScanBy == 2 then
		ScanInfo.mode = "full"
		StartFullScan = true
		BeginRun(resume and resume.page or 1, resume and resume.openName)
	else
		ScanInfo.mode = "list"
		CurItem = resume and resume.item or 1
		HideErasers()
		StartScanForList = true
		BeginRun(1)
	end
	return true
end

-- Полная остановка (кнопка "Остановить", ошибка, завершение). Продолжить нельзя.
function StopScan()
	local wasActive = StartFullScan or StartScanForList
	PauseState = nil
	if wasActive then
		RememberMeta(ScanInfo.completed)
		Finish(ScanInfo.completed)
		TabScan.OnStopped(ScanInfo.completed)
	end
end

-- Пауза (уход с вкладки, закрытие окна): продолжить можно ограниченное время
function PauseScan()
	if not (StartFullScan or StartScanForList) then return end
	local point = PriceDB.GetResumePoint()
	PauseState = {
		t = NowMs(),
		mode = Options.ScanBy,
		signature = Signature(),
		item = CurItem,
		-- с запасом в одну страницу: страницы смещаются, пока скан стоит
		page = point and math.max(point.page - 1, 1) or math.max(ScanInfo.page, 1),
		openName = point and point.name or nil,
		info = ScanInfo,
	}
	RememberMeta(false)
	Finish(false)
	ScanInfo.paused = true
	TabScan.OnStopped(false)
end

-- Можно ли сейчас продолжить: сколько осталось, мс (nil - нельзя)
function GetResumeInfo()
	if not PauseState then return nil end
	local left = PauseState.t + RESUME_TTL_MS - NowMs()
	if left <= 0 or PauseState.mode ~= Options.ScanBy then
		PauseState = nil
		return nil
	end
	TaskNames = CollectNames()
	if PauseState.signature ~= Signature() then
		PauseState = nil
		return nil
	end
	return { leftMs = left, info = PauseState.info, item = PauseState.item }
end

-- Отложенный запуск: скан стартует, когда аукцион освободится от чужого
-- поиска (его результат пришёл или таймер подтвердил, что поиска нет)
local function TryLaunchPending()
	if not PendingLaunch then return end
	if auction.IsSearchInProgress() then return end
	local pending = PendingLaunch
	PendingLaunch = nil
	ScanInfo.blocked = false
	local started
	if pending == "resume" then
		started = ResumeScan()
	else
		started = StartScan()
	end
	if started then
		TabScan.OnStarted()
	end
end

-- Отмена отложенного запуска (уход со вкладки, закрытие окна аукциона)
function CancelPendingScan()
	PendingLaunch = nil
	ScanInfo.blocked = false
end

function StartScan()
	-- Не начинаем скан поверх чужого поиска: его результат придёт с другим
	-- фильтром и будет ошибочно обработан как страница скана. Скан
	-- откладывается и запустится, когда поиск завершится.
	if auction.IsSearchInProgress() then
		ScanInfo.blocked = true
		PendingLaunch = "start"
		return false
	end
	PauseState = nil
	return Launch(nil)
end

function ResumeScan()
	if auction.IsSearchInProgress() then
		ScanInfo.blocked = true
		PendingLaunch = "resume"
		return false
	end
	if not GetResumeInfo() then return false end
	local state = PauseState
	PauseState = nil
	return Launch(state)
end

ScanAuction.AuctionSearch = function(params)
	local scanning = StartFullScan or StartScanForList

	if AuctionSearchSuccess ~= nil and params and params.sysResult ~= nil
       and params.sysResult ~= AuctionSearchSuccess then
		-- неудачный поиск посреди скана: останавливаем, иначе скан зависнет
		if scanning then StopScan() end
		TryLaunchPending()
		return
	end

	CheckTabVariant()
	if not scanning then
		-- пришёл результат чужого поиска: аукцион освободился,
		-- запускаем отложенный скан, если он ждал
		TryLaunchPending()
		return
	end

	-- игрок переключил "родную" вкладку: пришедшие результаты не наши
	if ScanStockTab ~= GetCurrentStockTab() then
		PauseScan()
		return
	end

	-- Запрос ещё не отправлен (шёл чужой поиск): это не наша страница.
	if not LastRequest.sent then
		RequestPage(LastRequest.page)
		return
	end

	local page = auction.GetAuctionsPage()
	if page ~= 0 and page ~= LastRequest.page then
		-- Пришёл результат другого запроса; ждём свою страницу.
		return
	end

	LastRequest.retries = 0
	local pageCount = auction.GetAuctionsPageCount()
	ScanInfo.page = page
	ScanInfo.pageCount = pageCount
	ScanInfo.total = auction.GetAuctionsCount()
	ScanInfo.pagesDone = (ScanInfo.pagesDone or 0) + 1

	local auctions = SafeGetAuctions()
	if auctions then
		for _, auctionId in pairs(auctions) do
			local info = auction.GetAuctionInfo(auctionId)
			if info then
				PriceDB.AddLot(info, page)
				ScanInfo.lots = (ScanInfo.lots or 0) + 1
			end
		end
	end

	TabScan.OnPage()
	PriceDB.Checkpoint()

	if page < pageCount then
		RequestPage(page + 1)
		return
	end

	-- результат прочитан до конца
	PriceDB.EndRun()
	if StartFullScan then
		ScanInfo.completed = true
		StopScan()
	else
		StrikeOutLine(CurItem)
		CurItem = CurItem + 1
		if CurItem > table.getn(TaskNames) then
			ScanInfo.completed = true
			StopScan()
		else
			BeginRun(1)
			EnsureVisibleLine(CurItem)
		end
	end
end

-- Если запрос страницы потерялся (например, предыдущий поиск ещё шёл), повторяем его
ScanAuction.OnSecondTimer = function()
	-- подстраховка отложенного запуска: вдруг результат чужого поиска
	-- пришёл без события или событие обработалось раньше времени
	if PendingLaunch then
		TryLaunchPending()
	end
	if not (StartFullScan or StartScanForList) then return end
	if NowMs() - LastRequest.ms < WATCHDOG_MS then return end
	if LastRequest.retries >= MAX_RETRIES then
		StopScan()
		return
	end
	LastRequest.retries = LastRequest.retries + 1
	RequestPage(LastRequest.page, true)
end

function CheckTabVariant()
	if not AuctionMainPanel or not AuctionMainPanel:IsVisible() then return end
	SyncAddonTabs()
end

ScanAuction.AuctionIsVisible = function(params)
	if params.addonName == "ContextAuction" and params.widget:GetName() == "Main" then
		if params.widget:IsVisible() then
			-- сумка могла измениться, пока окно было закрыто
			if Options.ScanBy == 3 then
				CheckBag()
			end
		else
			-- окно закрыто: скан ставится на паузу
			CancelPendingScan()
			PauseScan()
			PriceDB.Save()
		end
	end
end

ScanAuction.Init = function()
	common.RegisterEventHandler(ScanAuction.AuctionIsVisible, "EVENT_WIDGET_SHOW_CHANGED")
	common.RegisterEventHandler(ScanAuction.AuctionSearch, "EVENT_AUCTION_SEARCH_RESULT")
	common.RegisterEventHandler(ScanAuction.OnSecondTimer, "EVENT_SECOND_TIMER")
end

ScanAuction.Init()
