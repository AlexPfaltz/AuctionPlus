--------------------------------------------------------------------------------
-- PriceDB.lua: база цен аукциона, версия 2
--
-- ItemsDB = {
--   v = 2,
--   shards = {
--     ["<имя шарда>"] = {
--       ["<ключ предмета>"] = {
--         cur = { t, n, u, min, q1, med },  -- последний полный снимок цен
--         tr  = true,                       -- предмет искали по имени: история хранится дольше
--         h   = { {d, t, min, q1, med, n}, ... } -- история, по одной точке на день
--       }
--     }
--   }
-- }
--
-- Ключ предмета - его имя, для проклятых лотов имя .. "|c".
-- t - время снимка (Unix, мс), d - номер дня (Unix time / сутки),
-- n - число лотов, u - число единиц, min - минимум, q1 - нижняя четверть
-- ("рыночная" цена), med - медиана. Все цены - за единицу, в медных монетах.
--
-- Снимок предмета формируется только при проходе по всему результату поиска,
-- отсортированному по имени: лоты одного предмета идут подряд, поэтому предмет
-- "закрывается" в момент смены имени и сразу попадает в базу. Прерванный скан
-- сохраняет все уже закрытые предметы, недописанный предмет отбрасывается.
--------------------------------------------------------------------------------
Global("ItemsDB", userMods.GetGlobalConfigSection("ItemsDB") or {})
Global("PriceDB", { stats = { committed = 0 } })

local DAY_MS = 86400000
local HISTORY_DAYS_TRACKED = 60   -- глубина истории предметов, которые искали по имени
local HISTORY_DAYS_OTHER = 14     -- остальные предметы хранят короткий хвост
local CHECKPOINT_MS = 300000      -- как часто сохранять базу во время скана

local dirty = false
local lastSaveMs = 0
local shardKey = nil
local run = nil

local function NowMs()
	return common.GetLocalDateTimeMs()
end

local function DayOf(ms)
	return math.floor(ms / DAY_MS)
end

local function RoundCopper(value)
	return math.floor(value + 0.5)
end

-- WString или строка -> строка
local function ToStr(value)
	if value == nil then return nil end
	if type(value) == "string" then return value end
	if apitype(value) == "WString" then
		return userMods.FromWString(value)
	end
	return tostring(value)
end

local function GetShardKey()
	if shardKey then return shardKey end
	local shardName = mission.GetShardName()
	if shardName then
		local name = userMods.FromWString(shardName)
		if type(name) == "string" and name ~= "" then
			shardKey = name
			return shardKey
		end
	end
	return "default"
end

-- Таблица предметов текущего шарда. Данные старой версии базы при первом
-- обращении переходят в тот шард, под которым аддон работает сейчас.
local function GetItems()
	local shards = ItemsDB.shards
	local key = GetShardKey()
	local items = shards[key]
	if not items then
		if shards.legacy then
			items = shards.legacy
			shards.legacy = nil
			dirty = true
		else
			items = {}
		end
		shards[key] = items
	end
	return items
end

--------------------------------------------------------------------------------
-- Миграция с версии 1: ItemsDB[имя] = { LastScan = дата, [дата] = {min, max, timeMS} }
--------------------------------------------------------------------------------
local function MigrateV1()
	local old = ItemsDB
	local items = {}
	local today = DayOf(NowMs())
	for name, rec in pairs(old) do
		if type(name) == "string" and type(rec) == "table" then
			local e = {}
			local h = {}
			local latest = -1
			for _, v in pairs(rec) do
				if type(v) == "table" and type(v.min) == "number" then
					local t = v.timeMS or 0
					if t > latest then
						latest = t
						e.cur = { t = t, min = RoundCopper(v.min) }
					end
					local d = DayOf(t)
					if d >= today - HISTORY_DAYS_OTHER then
						h[#h + 1] = { d = d, min = RoundCopper(v.min), max = v.max and RoundCopper(v.max) or nil }
					end
				end
			end
			if e.cur then
				if #h > 0 then
					table.sort(h, function(a, b) return a.d < b.d end)
					e.h = h
				end
				items[name] = e
			end
		end
	end
	return { v = 2, shards = { legacy = items } }
end

--------------------------------------------------------------------------------
-- Сохранение
--------------------------------------------------------------------------------
function PriceDB.Save()
	if not dirty then return end
	userMods.SetGlobalConfigSection("ItemsDB", ItemsDB)
	dirty = false
	lastSaveMs = NowMs()
end

-- Контрольная точка во время долгого скана
function PriceDB.Checkpoint()
	if dirty and NowMs() - lastSaveMs >= CHECKPOINT_MS then
		PriceDB.Save()
	end
end

function PriceDB.Clear()
	ItemsDB = { v = 2, shards = {} }
	run = nil
	dirty = true
	PriceDB.Save()
end

-- Запись предмета (nil, если цен нет).
-- Проклятые лоты хранятся под ключом name .. "|c"; при отсутствии точного
-- ключа используем вторую форму, чтобы тултип не оставался пустым.
function PriceDB.GetEntry(name, isCursed)
	if not name then return nil end
	local items = GetItems()
	local cursedKey = name .. "|c"
	if isCursed then
		return items[cursedKey] or items[name]
	end
	return items[name] or items[cursedKey]
end

-- История цен: до limit последних дневных точек, от старых к новым.
function PriceDB.GetHistory(name, isCursed, limit)
	local entry = PriceDB.GetEntry(name, isCursed)
	if not entry or type(entry.h) ~= "table" then return nil end
	local history = entry.h
	if #history == 0 then return nil end
	local first = math.max(1, #history - (limit or 7) + 1)
	local result = {}
	for i = first, #history do
		result[#result + 1] = history[i]
	end
	return result
end

-- Все предметы текущего шарда (для окна просмотра базы, PriceDBView.lua)
function PriceDB.GetShardItems()
	return GetItems()
end

--------------------------------------------------------------------------------
-- Статистика по массиву цен за единицу
--------------------------------------------------------------------------------
local function CalcStats(prices, units)
	table.sort(prices)
	local n = #prices
	local median
	if n % 2 == 1 then
		median = prices[(n + 1) / 2]
	else
		median = (prices[n / 2] + prices[n / 2 + 1]) / 2
	end
	local q1 = prices[math.max(1, math.ceil(n * 0.25))]
	return {
		n = n,
		u = units,
		min = RoundCopper(prices[1]),
		q1 = RoundCopper(q1),
		med = RoundCopper(median),
	}
end

PriceDB.CalcStats = CalcStats

local function CommitItem(key, stats, tracked)
	local items = GetItems()
	local e = items[key] or {}
	local now = NowMs()
	local today = DayOf(now)

	e.cur = { t = now, n = stats.n, u = stats.u, min = stats.min, q1 = stats.q1, med = stats.med }
	if tracked then e.tr = true end

	-- История ведётся для всех предметов: иначе график цен появится только
	-- у тех, что когда-либо искали по имени.
	local h = e.h
	if type(h) ~= "table" then h = {} end
	local point = { d = today, t = now, min = stats.min, q1 = stats.q1, med = stats.med, n = stats.n }
		local last = h[#h]
		if last and last.d == today then
			h[#h] = point
		else
			h[#h + 1] = point
		end
		local keepDays = e.tr and HISTORY_DAYS_TRACKED or HISTORY_DAYS_OTHER
		local fresh = {}
		for i = 1, #h do
			if h[i].d >= today - keepDays then fresh[#fresh + 1] = h[i] end
		end
		e.h = #fresh > 0 and fresh or nil

	items[key] = e
	dirty = true
end

--------------------------------------------------------------------------------
-- Проход по результату поиска, отсортированному по имени
--------------------------------------------------------------------------------
-- requestedName: точное имя предмета, если искали конкретный предмет
-- (такие предметы становятся отслеживаемыми), иначе nil.
-- resume: { openName = имя } при продолжении прерванного скана с середины
-- результата: первая группа лотов может оказаться неполной (начало было на
-- предыдущей странице), поэтому её пропускаем, если это не тот предмет,
-- который был открыт в момент паузы.
function PriceDB.BeginRun(requestedName, resume)
	run = {
		requested = ToStr(requestedName),
		block = {},      -- ключ -> { prices = {}, units = n } для текущего имени
		blockName = nil,
		blockPage = nil, -- страница, на которой началась текущая группа
		done = {},       -- имена, закрытые в этом проходе
		pendingFirst = resume ~= nil,
		openName = resume and ToStr(resume.openName) or nil,
		skipName = nil,
	}
end

local function FinalizeBlock()
	if not run or not run.blockName then return end
	local tracked = run.requested ~= nil and run.blockName == run.requested
	for key, b in pairs(run.block) do
		if #b.prices > 0 then
			CommitItem(key, CalcStats(b.prices, b.units), tracked)
			PriceDB.stats.committed = PriceDB.stats.committed + 1
		end
	end
	run.done[run.blockName] = true
	run.block = {}
	run.blockName = nil
end

-- Добавить лот страницы page
function PriceDB.AddLot(auctionInfo, page)
	if not run then return end
	local buyout = auctionInfo.buyoutPrice or 0
	if buyout <= 0 then return end

	local itemInfo = itemLib.GetItemInfo(auctionInfo.itemId)
	if not itemInfo or not itemInfo.name then return end
	local name = userMods.FromWString(itemInfo.name)

	if run.pendingFirst then
		run.pendingFirst = false
		if name ~= run.openName then run.skipName = name end
	end
	if name == run.skipName then return end

	if run.blockName ~= name then
		FinalizeBlock()
		-- имя уже было закрыто раньше (порядок нарушен): лот не учитываем,
		-- чтобы неполный набор не затёр готовый снимок
		if run.done[name] then return end
		run.blockName = name
		run.blockPage = page
	end

	local stack = itemLib.GetStackInfo(auctionInfo.itemId)
	local count = math.max(1, stack and stack.count or 1)

	local key = name
	if IsItemCursed(auctionInfo.itemId) then key = name .. "|c" end

	local b = run.block[key]
	if not b then
		b = { prices = {}, units = 0 }
		run.block[key] = b
	end
	b.prices[#b.prices + 1] = buyout / count
	b.units = b.units + count
end

-- Результат прочитан до конца: закрываем последний предмет
function PriceDB.EndRun()
	FinalizeBlock()
	run = nil
end

-- Скан прерван: недописанный предмет отбрасываем, закрытые остаются в базе
function PriceDB.AbortRun()
	run = nil
end

-- Где продолжать прерванный скан: имя открытого предмета и страница, на которой
-- он начался (nil, если открытой группы нет)
function PriceDB.GetResumePoint()
	if run and run.blockName and run.blockPage then
		return { name = run.blockName, page = run.blockPage }
	end
	return nil
end

-- Служебные данные (объём последнего полного скана, скорость страниц)
function PriceDB.GetMeta()
	if type(ItemsDB.meta) ~= "table" then ItemsDB.meta = {} end
	return ItemsDB.meta
end

function PriceDB.MarkDirty()
	dirty = true
end

--------------------------------------------------------------------------------
-- Инициализация
--------------------------------------------------------------------------------
if type(ItemsDB) ~= "table" then
	ItemsDB = {}
end
if not (type(ItemsDB.v) == "number" and ItemsDB.v >= 2 and type(ItemsDB.shards) == "table") then
	local migrated = MigrateV1()
	if migrated then
		ItemsDB = migrated
	else
		ItemsDB = { v = 2, shards = {} }
	end
	dirty = true
	PriceDB.Save()
end
