Global ("listCSS", common.GetCSSList())
local wtOptions = mainForm:GetChildChecked("Options", false)
local Container = wtOptions:GetChildChecked("Container", false)
local GroupMain = wtOptions:GetChildChecked("GroupMain", false)
local ScanBy = GroupMain:GetChildChecked("ScanBy", true)
local ValueScanBy = ScanBy:GetChildChecked("Value", false)
local wtShowSearchList = GroupMain:GetChildChecked("ShowSearchList", true)
local CbShowSearchList = wtShowSearchList:GetChildChecked("CheckBox", false)
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
local wtHeaderStyle = GroupToolTip:GetChildChecked("HeaderStyle", true)
local ValueHeaderStyle = wtHeaderStyle:GetChildChecked("Value", false)
local wtDateStyle = GroupToolTip:GetChildChecked("DateStyle", true)
local ValueDateStyle = wtDateStyle:GetChildChecked("Value", false)
local defaultOptions = {
    ["ShowHeader"] = true,
    ["ShowDate"] = false,
    ["ShowMin"] = true,
    ["ShowMarket"] = false,
    ["ShowMedian"] = true,
    ["ShowLots"] = false,
    ["ShowHistory"] = true,
    ["ShowCoins"] = 3,
    ["styleHeader"] = 81,
    ["styleDate"] = 240,
    ["ScanBy"] = 1,
    ["ScanRootCategory"] = 0,
    ["ScanChildCategory"] = 0,
    ["ShowSearchList"] = true
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
    -- миграция: ShowPrices (1 - мин и макс, 2 - только мин, 3 - только макс)
    -- заменён отдельными чекбоксами; максимум заменяется медианой
    if SavedOptions.ShowPrices ~= nil then
        if SavedOptions.ShowMin == nil and SavedOptions.ShowMedian == nil then
            local variant = SavedOptions.ShowPrices
            SavedOptions.ShowMin = (variant == 1 or variant == 2)
            SavedOptions.ShowMedian = (variant == 1 or variant == 3)
        end
        SavedOptions.ShowPrices = nil
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
    wtOptions:GetChildChecked("Header", false):GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Auction+: Options"))
    wtOptions:GetChildChecked("DefaultOptions", false):SetVal("button_label", userMods.ToWString(GetLocalizedText("Default Options")))
    GroupMain:GetChildChecked("GroupLabel", false):SetVal("text", GetLocalizedText("Main"))
    GroupToolTip:GetChildChecked("GroupLabel", false):SetVal("text", GetLocalizedText("Tooltip"))
    ScanBy:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Variant scan"))
    wtShowSearchList:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show the search list when scanning"))
    GroupMain:GetChildChecked("ShowSearchListNow", true):GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show the search list now"))
    GroupMain:GetChildChecked("ShowSearchListNow", true):GetChildChecked("Button", false):SetVal("button_label", userMods.ToWString(GetLocalizedText("Show")))
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
    wtHeaderStyle:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Style text - header"))
    wtDateStyle:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Style text - date"))
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
    VariantScanBy(Options.ScanBy)
    VariantShowSearchList(Options.ShowSearchList)
end

function VariantShowHeader(variant)
    if variant then
        CbShowHeader:SetVariant(1)
    else
        CbShowHeader:SetVariant(0)
    end
end

function VariantShowSearchList(variant)
    if variant then
        CbShowSearchList:SetVariant(1)
    else
        CbShowSearchList:SetVariant(0)
    end
end

function VariantShowDate(variant)
    if variant then
        CbShowDate:SetVariant(1)
    else
        CbShowDate:SetVariant(0)
    end
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
    local variant = Options.ShowCoins
    variant = variant + 1
    VariantShowCoins(variant)
    Options.ShowCoins = variant
    userMods.SetGlobalConfigSection("Options", Options)
end

function CoinsPrev(reaction)
    local variant = Options.ShowCoins
    variant = variant - 1
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

function VariantScanBy(variant)
    if variant == 1 then
        ValueScanBy:SetVal("value", GetLocalizedText("All auction"))
        ScanBy:GetChildChecked("BtnLeft", false):Enable(false)
        ScanBy:GetChildChecked("BtnRight", false):Enable(true)
        CbShowSearchList:Enable(false)
    elseif variant == 2 then
        ValueScanBy:SetVal("value", GetLocalizedText("Only by bag"))
        ScanBy:GetChildChecked("BtnLeft", false):Enable(true)
        ScanBy:GetChildChecked("BtnRight", false):Enable(true)
        CbShowSearchList:Enable(true)
    elseif variant == 3 then
        ValueScanBy:SetVal("value", GetLocalizedText("Your list"))
        ScanBy:GetChildChecked("BtnLeft", false):Enable(true)
        ScanBy:GetChildChecked("BtnRight", false):Enable(false)
        CbShowSearchList:Enable(true)
    end
end

local function RefreshScanMode()
    if not AuctionMainPanel or not AuctionMainPanel:IsVisible() then return end
    if Options.ScanBy == 2 then
        CheckBag()
        if Options.ShowSearchList then ShowSearchListForBag() end
    elseif Options.ScanBy == 3 and Options.ShowSearchList then
        ShowYourSearchList()
    end
end

function ScanNext(reaction)
    HideSearchList()
    local variant = Options.ScanBy
    variant = variant + 1
    VariantScanBy(variant)
    Options.ScanBy = variant
    userMods.SetGlobalConfigSection("Options", Options)
    RefreshScanMode()
end

function ScanPrev(reaction)
    HideSearchList()
    local variant = Options.ScanBy
    variant = variant - 1
    VariantScanBy(variant)
    Options.ScanBy = variant
    userMods.SetGlobalConfigSection("Options", Options)
    RefreshScanMode()
end

function DefaultOptions(reaction)
    Options = CopyDefaults()
    userMods.SetGlobalConfigSection("Options", Options)
    FillValues()
end

function ShowSearchList(reaction)
    if CbShowSearchList:GetVariant() == 0 then
        CbShowSearchList:SetVariant(1)
        Options.ShowSearchList = true
    else
        CbShowSearchList:SetVariant(0)
        Options.ShowSearchList = false
    end
    userMods.SetGlobalConfigSection("Options", Options)
end

function ShowSearchListNow()
    OpenSearchListFromOptions = not OpenSearchListFromOptions
    if OpenSearchListFromOptions then
        ClearList()
        ShowYourSearchList()
    else
        HideSearchList()
    end
end

function ShowOptionsPanel()
    wtOptions:Show(true)
    Container:PushBack(GroupMain)
    Container:PushBack(GroupToolTip)
    SetLocalizedText()
    FillValues()
end

function ClosePanel(reaction)
    wtOptions:Show(false)
    Container:RemoveItems()
end

function DisableButtonShowList()
    GroupMain:GetChildChecked("ShowSearchListNow", true):GetChildChecked("Button", false):Enable(false)
end

function EnableButtonShowList()
    GroupMain:GetChildChecked("ShowSearchListNow", true):GetChildChecked("Button", false):Enable(true)
end

function OptionsInit()
    common.RegisterReactionHandler(ClosePanel, "ClosePanel")
    common.RegisterReactionHandler(CoinsNext, "CoinsNext")
    common.RegisterReactionHandler(CoinsPrev, "CoinsPrev")
    common.RegisterReactionHandler(HeaderStyleNext, "HeaderStyleNext")
    common.RegisterReactionHandler(HeaderStylePrev, "HeaderStylePrev")
    common.RegisterReactionHandler(DateStyleNext, "DateStyleNext")
    common.RegisterReactionHandler(DateStylePrev, "DateStylePrev")
    common.RegisterReactionHandler(showHeader, "showHeader")
    common.RegisterReactionHandler(showDate, "showDate")
    common.RegisterReactionHandler(showMin, "showMin")
    common.RegisterReactionHandler(showMarket, "showMarket")
    common.RegisterReactionHandler(showMedian, "showMedian")
    common.RegisterReactionHandler(showLots, "showLots")
    common.RegisterReactionHandler(showHistory, "showHistory")
    common.RegisterReactionHandler(ScanNext, "ScanNext")
    common.RegisterReactionHandler(ScanPrev, "ScanPrev")
    common.RegisterReactionHandler(ClearBase, "ClearBase")
    common.RegisterReactionHandler(DefaultOptions, "DefaultOptions")
    common.RegisterReactionHandler(ShowSearchList, "ShowSearchList")
    common.RegisterReactionHandler(ShowSearchListNow, "ShowSearchListNow")
    common.RegisterReactionHandler(ShowOptionsPanel, "ShowOptionsPanel")
    CheckSettings()
    --DnD.Init(wtOptions, wtOptions, true, true)
end

OptionsInit()