Global ("listCSS", common.GetCSSList())
local wtOptions = mainForm:GetChildChecked("Options", false)
local Container = wtOptions:GetChildChecked("Container", false)
local GroupMain = wtOptions:GetChildChecked("GroupMain", false)
local GroupBuy = wtOptions:GetChildChecked("GroupBuy", false)
local GroupToolTip = wtOptions:GetChildChecked("GroupToolTip", false)
local wtShowHeader = GroupToolTip:GetChildChecked("ShowHeader", true)
local CbShowHeader = wtShowHeader:GetChildChecked("CheckBox", false)
local wtShowDate = GroupToolTip:GetChildChecked("ShowDate", true)
local CbShowDate = wtShowDate:GetChildChecked("CheckBox", false)
-- Строки с чекбоксами цен тултипа (создаются из XDB; если файлов нет, строки просто пропускаются)
local wtShowMin = GroupToolTip:GetChildUnchecked("ShowMin", true)
local wtShowMarket = GroupToolTip:GetChildUnchecked("ShowMarket", true)
local wtShowMedian = GroupToolTip:GetChildUnchecked("ShowMedian", true)
local wtShowLots = GroupToolTip:GetChildUnchecked("ShowLots", true)
local wtShowHistory = GroupToolTip:GetChildUnchecked("ShowHistory", true)
local CbShowMin = wtShowMin and wtShowMin:GetChildUnchecked("CheckBox", false)
local CbShowMarket = wtShowMarket and wtShowMarket:GetChildUnchecked("CheckBox", false)
local CbShowMedian = wtShowMedian and wtShowMedian:GetChildUnchecked("CheckBox", false)
local CbShowLots = wtShowLots and wtShowLots:GetChildUnchecked("CheckBox", false)
local CbShowHistory = wtShowHistory and wtShowHistory:GetChildUnchecked("CheckBox", false)
local wtShowCoins = GroupToolTip:GetChildChecked("ShowCoins", true)
local ValueShowCoins = wtShowCoins:GetChildChecked("Value", false)
local wtHistoryCount = GroupToolTip:GetChildChecked("HistoryCount", true)
local ValueHistoryCount = wtHistoryCount:GetChildChecked("Value", false)
local wtHeaderStyle = GroupToolTip:GetChildChecked("HeaderStyle", true)
local ValueHeaderStyle = wtHeaderStyle:GetChildChecked("Value", false)
local wtDateStyle = GroupToolTip:GetChildChecked("DateStyle", true)
local ValueDateStyle = wtDateStyle:GetChildChecked("Value", false)
local wtShowDeals = GroupBuy:GetChildChecked("ShowDeals", true)
local CbShowDeals = wtShowDeals:GetChildChecked("CheckBox", false)
local wtDealBase = GroupBuy:GetChildChecked("DealBase", true)
local ValueDealBase = wtDealBase:GetChildChecked("Value", false)
local defaultOptions = {
    ["ShowHeader"] = true,
    ["ShowDate"] = false,
    ["ShowMin"] = true,
    ["ShowMarket"] = false,
    ["ShowMedian"] = true,
    ["ShowLots"] = false,
    ["ShowHistory"] = true,
    ["HistoryCount"] = 7,
    ["ShowCoins"] = 3,
    ["styleHeader"] = 81,
    ["styleDate"] = 240,
    -- режимы сканирования: 1 - весь аукцион, 2 - категория, 3 - сумка, 4 - свой список
    ["ScanBy"] = 1,
    ["ScanModesVer"] = 1,
    ["ScanRootCategory"] = 0,
    ["ScanChildCategory"] = 0,
    -- подсветка выгодных лотов во вкладке "Купить" и строка в тултипе
    ["ShowDeals"] = true,
    -- опорная цена выгоды: 1 - медиана, 2 - рыночная (нижняя четверть),
    -- 3 - только минимальная цена среди найденных лотов
    ["DealBase"] = 1
}

local function CopyDefaults()
    local copy = {}
    for key, value in pairs(defaultOptions) do
        copy[key] = value
    end
    return copy
end

Global ("Options", userMods.GetGlobalConfigSection("Options") or CopyDefaults())

function CheckSettings()
    local SavedOptions = userMods.GetGlobalConfigSection("Options") or {}
    -- миграция ShowPrices (1 - мин и макс, 2 - только мин, 3 - только макс)
    -- заменён отдельными чекбоксами; максимум заменяется медианой
    if SavedOptions.ShowPrices ~= nil then
        if SavedOptions.ShowMin == nil and SavedOptions.ShowMedian == nil then
            local variant = SavedOptions.ShowPrices
            SavedOptions.ShowMin = (variant == 1 or variant == 2)
            SavedOptions.ShowMedian = (variant == 1 or variant == 3)
        end
        SavedOptions.ShowPrices = nil
    end
    -- миграция режимов сканирования: добавился отдельный режим "по категории",
    -- старые значения сдвигаются (2 - сумка -> 3, 3 - список -> 4)
    if SavedOptions.ScanModesVer == nil and SavedOptions.ScanBy ~= nil then
        if SavedOptions.ScanBy == 2 then
            SavedOptions.ScanBy = 3
        elseif SavedOptions.ScanBy >= 3 then
            SavedOptions.ScanBy = 4
        end
    end
    -- значения по умолчанию подставляются только вместо отсутствующих (nil),
    -- иначе выключенные (false) флаги сбрасывались бы при каждой загрузке
    for key, value in pairs(defaultOptions) do
        if SavedOptions[key] == nil then
            SavedOptions[key] = value
        end
    end
    Options = SavedOptions
    userMods.SetGlobalConfigSection("Options", SavedOptions)
    return SavedOptions
end


function ClearBase()
	PriceDB.Clear()
end

local function SetRowText(row, key)
    if row then
        row:GetChildChecked("Text", false):SetVal("text", GetLocalizedText(key))
    end
end

function SetLocalizedText()
    wtOptions:GetChildChecked("Header", false):GetChildChecked("Text", false):SetVal("text", GetLocalizedText("AuctionPlus: Options"))
    wtOptions:GetChildChecked("DefaultOptions", false):SetVal("button_label", userMods.ToWString(GetLocalizedText("Default Options")))
    GroupMain:GetChildChecked("GroupLabel", false):SetVal("text", GetLocalizedText("Main"))
    GroupBuy:GetChildChecked("GroupLabel", false):SetVal("text", GetLocalizedText("Buy tab"))
    GroupToolTip:GetChildChecked("GroupLabel", false):SetVal("text", GetLocalizedText("Tooltip"))
    GroupMain:GetChildChecked("ClearBase", true):GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Clear base"))
    GroupMain:GetChildChecked("ClearBase", true):GetChildChecked("ClearButton", false):SetVal("button_label", userMods.ToWString(GetLocalizedText("Clear")))
    wtShowHeader:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show title"))
    wtShowDate:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show the date of the last scan"))
    SetRowText(wtShowMin, "Show min price")
    SetRowText(wtShowMarket, "Show market price")
    SetRowText(wtShowMedian, "Show median price")
    SetRowText(wtShowLots, "Show number of lots")
    SetRowText(wtShowHistory, "Show price history")
    wtShowCoins:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show coins"))
    wtHistoryCount:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("History items count"))
    wtHeaderStyle:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Style text - header"))
    wtDateStyle:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Style text - date"))
    SetRowText(wtShowDeals, "Show good deals")
    SetRowText(wtDealBase, "Deal base price")
end

local function SetCheckbox(checkbox, value)
    if checkbox then
        checkbox:SetVariant(value and 1 or 0)
    end
end

local function ApplyStyle(row, valueWidget, key, class)
    local count = table.getn(listCSS)
    if count < 1 then return end
    class = math.max(1, math.min(class, count))
    Options[key] = class
    valueWidget:SetVal("value", listCSS[class])
    valueWidget:SetClassVal("class", listCSS[class])
    row:GetChildChecked("BtnLeft", false):Enable(class > 1)
    row:GetChildChecked("BtnRight", false):Enable(class < count)
    userMods.SetGlobalConfigSection("Options", Options)
end

function FillValues()
    ApplyStyle(wtHeaderStyle, ValueHeaderStyle, "styleHeader", Options.styleHeader)
    ApplyStyle(wtDateStyle, ValueDateStyle, "styleDate", Options.styleDate)
    SetCheckbox(CbShowMin, Options.ShowMin)
    SetCheckbox(CbShowMarket, Options.ShowMarket)
    SetCheckbox(CbShowMedian, Options.ShowMedian)
    SetCheckbox(CbShowLots, Options.ShowLots)
    SetCheckbox(CbShowHistory, Options.ShowHistory)
    VariantShowCoins(Options.ShowCoins)
    VariantShowHeader(Options.ShowHeader)
    VariantShowDate(Options.ShowDate)
    VariantHistoryCount(Options.HistoryCount)
    SetCheckbox(CbShowDeals, Options.ShowDeals)
    VariantDealBase(Options.DealBase)
end

function VariantShowHeader(variant)
    if variant then
        CbShowHeader:SetVariant(1)
    else
        CbShowHeader:SetVariant(0)
    end
end

function VariantShowDate(variant)
    if variant then
        CbShowDate:SetVariant(1)
    else
        CbShowDate:SetVariant(0)
    end
end

-- Сколько последних дневных точек показывать в истории цен (1..7)
function VariantHistoryCount(count)
    count = math.max(1, math.min(7, count or 7))
    Options.HistoryCount = count
    ValueHistoryCount:SetVal("value", userMods.ToWString(tostring(count)))
    wtHistoryCount:GetChildChecked("BtnLeft", false):Enable(count > 1)
    wtHistoryCount:GetChildChecked("BtnRight", false):Enable(count < 7)
end

function HistoryCountNext(reaction)
    VariantHistoryCount((Options.HistoryCount or 7) + 1)
    userMods.SetGlobalConfigSection("Options", Options)
end

function HistoryCountPrev(reaction)
    VariantHistoryCount((Options.HistoryCount or 7) - 1)
    userMods.SetGlobalConfigSection("Options", Options)
end

function VariantShowCoins(variant)
    if variant == 1 then
        ValueShowCoins:SetVal("value", GetLocalizedText("All coins"))
        wtShowCoins:GetChildChecked("BtnLeft", false):Enable(false)
        wtShowCoins:GetChildChecked("BtnRight", false):Enable(true)
    elseif variant == 2 then
        ValueShowCoins:SetVal("value", GetLocalizedText("Gold and silver"))
        wtShowCoins:GetChildChecked("BtnLeft", false):Enable(true)
        wtShowCoins:GetChildChecked("BtnRight", false):Enable(true)
    elseif variant == 3 then
        ValueShowCoins:SetVal("value", GetLocalizedText("Only gold"))
        wtShowCoins:GetChildChecked("BtnLeft", false):Enable(true)
        wtShowCoins:GetChildChecked("BtnRight", false):Enable(false)
    end
end

function CoinsNext(reaction)
    local variant = Options.ShowCoins + 1
    if variant > 3 then variant = 1 end
    VariantShowCoins(variant)
    Options.ShowCoins = variant
    userMods.SetGlobalConfigSection("Options", Options)
end

function CoinsPrev(reaction)
    local variant = Options.ShowCoins - 1
    if variant < 1 then variant = 3 end
    VariantShowCoins(variant)
    Options.ShowCoins = variant
    userMods.SetGlobalConfigSection("Options", Options)
end

function HeaderStyleNext(reaction)
    ApplyStyle(wtHeaderStyle, ValueHeaderStyle, "styleHeader", Options.styleHeader + 1)
end

function HeaderStylePrev(reaction)
    ApplyStyle(wtHeaderStyle, ValueHeaderStyle, "styleHeader", Options.styleHeader - 1)
end

function DateStyleNext(reaction)
    ApplyStyle(wtDateStyle, ValueDateStyle, "styleDate", Options.styleDate + 1)
end

function DateStylePrev(reaction)
    ApplyStyle(wtDateStyle, ValueDateStyle, "styleDate", Options.styleDate - 1)
end

function showHeader(reaction)
    if CbShowHeader:GetVariant() == 0 then
        CbShowHeader:SetVariant(1)
        Options.ShowHeader = true
    else
        CbShowHeader:SetVariant(0)
        Options.ShowHeader = false
    end
    userMods.SetGlobalConfigSection("Options", Options)
end

function showDate(reaction)
    if CbShowDate:GetVariant() == 0 then
        CbShowDate:SetVariant(1)
        Options.ShowDate = true
    else
        CbShowDate:SetVariant(0)
        Options.ShowDate = false
    end
    userMods.SetGlobalConfigSection("Options", Options)
end

local function ToggleOption(name, checkbox)
    Options[name] = not Options[name]
    SetCheckbox(checkbox, Options[name])
    userMods.SetGlobalConfigSection("Options", Options)
end

function showMin(reaction)
    ToggleOption("ShowMin", CbShowMin)
end

function showMarket(reaction)
    ToggleOption("ShowMarket", CbShowMarket)
end

function showMedian(reaction)
    ToggleOption("ShowMedian", CbShowMedian)
end

function showLots(reaction)
    ToggleOption("ShowLots", CbShowLots)
end

function showHistory(reaction)
    ToggleOption("ShowHistory", CbShowHistory)
end

-- Опорная цена для подсветки выгодных лотов: 1 - медиана, 2 - рыночная,
-- 3 - только минимум среди найденных. Стрелки листают значения по кругу.
local DealBaseLabels = { "PriceMedian", "PriceMarket", "DealBaseMin" }

-- Строка выбора опорной цены активна, только когда включена сама
-- подсветка выгодных лотов: без неё выбор не имеет смысла
local function UpdateDealBaseState()
    local enabled = Options.ShowDeals ~= false
    wtDealBase:GetChildChecked("BtnLeft", false):Enable(enabled)
    wtDealBase:GetChildChecked("BtnRight", false):Enable(enabled)
end

function VariantDealBase(variant)
    if type(variant) ~= "number" or variant < 1 or variant > 3 then variant = 1 end
    Options.DealBase = variant
    ValueDealBase:SetVal("value", GetLocalizedText(DealBaseLabels[variant]))
    UpdateDealBaseState()
end

local function DealBaseStep(step)
    local variant = (Options.DealBase or 1) + step
    if variant > 3 then variant = 1 end
    if variant < 1 then variant = 3 end
    VariantDealBase(variant)
    userMods.SetGlobalConfigSection("Options", Options)
    -- функция из ListBuy: отсутствует, если вкладки аукциона не загружены
    if RefreshDealHighlights then RefreshDealHighlights() end
end

function DealBaseNext(reaction)
    DealBaseStep(1)
end

function DealBasePrev(reaction)
    DealBaseStep(-1)
end

function showDeals(reaction)
    ToggleOption("ShowDeals", CbShowDeals)
    UpdateDealBaseState()
    if RefreshDealHighlights then RefreshDealHighlights() end
end

function DefaultOptions(reaction)
    Options = CopyDefaults()
    userMods.SetGlobalConfigSection("Options", Options)
    FillValues()
end

function ShowOptionsPanel()
    wtOptions:Show(true)
    -- PushBack виджета, уже находящегося в контейнере, бросает ошибку:
    -- панель могла остаться в контейнере после прошлого показа
    if not Container:IsContain(GroupMain) then
        Container:PushBack(GroupMain)
    end
    if not Container:IsContain(GroupBuy) then
        Container:PushBack(GroupBuy)
    end
    if not Container:IsContain(GroupToolTip) then
        Container:PushBack(GroupToolTip)
    end
    SetLocalizedText()
    FillValues()
end

function ClosePanel(reaction)
    wtOptions:Show(false)
    Container:RemoveItems()
end

function OptionsInit()
    common.RegisterReactionHandler(ClosePanel, "ClosePanel")
    common.RegisterReactionHandler(CoinsNext, "CoinsNext")
    common.RegisterReactionHandler(CoinsPrev, "CoinsPrev")
    common.RegisterReactionHandler(HeaderStyleNext, "HeaderStyleNext")
    common.RegisterReactionHandler(HeaderStylePrev, "HeaderStylePrev")
    common.RegisterReactionHandler(DateStyleNext, "DateStyleNext")
    common.RegisterReactionHandler(DateStylePrev, "DateStylePrev")
    common.RegisterReactionHandler(HistoryCountNext, "HistoryCountNext")
    common.RegisterReactionHandler(HistoryCountPrev, "HistoryCountPrev")
    common.RegisterReactionHandler(showHeader, "showHeader")
    common.RegisterReactionHandler(showDate, "showDate")
    common.RegisterReactionHandler(showMin, "showMin")
    common.RegisterReactionHandler(showMarket, "showMarket")
    common.RegisterReactionHandler(showMedian, "showMedian")
    common.RegisterReactionHandler(showLots, "showLots")
    common.RegisterReactionHandler(showHistory, "showHistory")
    common.RegisterReactionHandler(showDeals, "showDeals")
    common.RegisterReactionHandler(DealBaseNext, "DealBaseNext")
    common.RegisterReactionHandler(DealBasePrev, "DealBasePrev")
    common.RegisterReactionHandler(ClearBase, "ClearBase")
    common.RegisterReactionHandler(DefaultOptions, "DefaultOptions")
    common.RegisterReactionHandler(ShowOptionsPanel, "ShowOptionsPanel")
    CheckSettings()
    --DnD.Init(wtOptions, wtOptions, true, true)
end

OptionsInit()