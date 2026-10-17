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
local wtShowPrices = GroupToolTip:GetChildChecked("ShowPrices", true)
local ValueShowPrices = wtShowPrices:GetChildChecked("Value", false)
local wtShowCoins = GroupToolTip:GetChildChecked("ShowCoins", true)
local ValueShowCoins = wtShowCoins:GetChildChecked("Value", false)
local wtHeaderStyle = GroupToolTip:GetChildChecked("HeaderStyle", true)
local ValueHeaderStyle = wtHeaderStyle:GetChildChecked("Value", false)
local wtDateStyle = GroupToolTip:GetChildChecked("DateStyle", true)
local ValueDateStyle = wtDateStyle:GetChildChecked("Value", false)
local defaultOptions = {
    ["ShowHeader"] = true,
    ["ShowDate"] = false,
    ["ShowPrices"] = 1,
    ["ShowCoins"] = 3,
    ["styleHeader"] = 81,
    ["styleDate"] = 240,
    ["ScanBy"] = 1,
    ["ShowSearchList"] = true
}
Global ("Options", userMods.GetGlobalConfigSection("Options") or defaultOptions)

function CheckSettings()
    local SavedOptions = userMods.GetGlobalConfigSection("Options") or {}
    if not SavedOptions.ScanBy then
        SavedOptions.ScanBy = defaultOptions.ScanBy
    end
    if not SavedOptions.styleDate then
        SavedOptions.styleDate = defaultOptions.styleDate
    end
    if not SavedOptions.styleHeader then
        SavedOptions.styleHeader = defaultOptions.styleHeader
    end
    if not SavedOptions.ShowCoins then
        SavedOptions.ShowCoins = defaultOptions.ShowCoins
    end
    if not SavedOptions.ShowPrices then
        SavedOptions.ShowPrices = defaultOptions.ShowPrices
    end
    if not SavedOptions.ShowHeader then
        SavedOptions.ShowHeader = defaultOptions.ShowHeader
    end
    if not SavedOptions.ShowDate then
        SavedOptions.ShowDate = defaultOptions.ShowDate
    end
    if not SavedOptions.ShowSearchList then
        SavedOptions.ShowSearchList = defaultOptions.ShowSearchList
    end
    Options = SavedOptions
    userMods.SetGlobalConfigSection("Options", SavedOptions)
    return SavedOptions
end


function ClearBase()
	ItemsDB = {}
	userMods.SetGlobalConfigSection("ItemsDB", ItemsDB)
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
    wtShowPrices:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show min/max prices"))
    wtShowCoins:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Show coins"))
    wtHeaderStyle:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Style text - header"))
    wtDateStyle:GetChildChecked("Text", false):SetVal("text", GetLocalizedText("Style text - date"))
end

function FillValues()
    ValueHeaderStyle:SetVal("value", listCSS[Options.styleHeader])
    ValueHeaderStyle:SetClassVal("class", userMods.FromWString(listCSS[Options.styleHeader]))
    ValueDateStyle:SetVal("value", listCSS[Options.styleDate])
    ValueDateStyle:SetClassVal("class", userMods.FromWString(listCSS[Options.styleDate]))
    VariantShowPrices(Options.ShowPrices)
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

function VariantShowPrices(variant)
    if variant == 1 then
        ValueShowPrices:SetVal("value", GetLocalizedText("Min and max"))
        wtShowPrices:GetChildChecked("BtnLeft", false):Enable(false)
        wtShowPrices:GetChildChecked("BtnRight", false):Enable(true)
    elseif variant == 2 then
        ValueShowPrices:SetVal("value", GetLocalizedText("Only min"))
        wtShowPrices:GetChildChecked("BtnLeft", false):Enable(true)
        wtShowPrices:GetChildChecked("BtnRight", false):Enable(true)
    elseif variant == 3 then
        ValueShowPrices:SetVal("value", GetLocalizedText("Only max"))
        wtShowPrices:GetChildChecked("BtnLeft", false):Enable(true)
        wtShowPrices:GetChildChecked("BtnRight", false):Enable(false)
    end
end

function PricesNext(reaction)
    local variant = Options.ShowPrices
    variant = variant + 1
    VariantShowPrices(variant)
    Options.ShowPrices = variant
    userMods.SetGlobalConfigSection("Options", Options)
end

function PricesPrev(reaction)
    local variant = Options.ShowPrices
    variant = variant - 1
    VariantShowPrices(variant)
    Options.ShowPrices = variant
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
    local class = Options.styleHeader
    class = class + 1
    wtHeaderStyle:GetChildChecked("BtnLeft", false):Enable(true)
    if class == table.getn(listCSS) then
        wtHeaderStyle:GetChildChecked("BtnRight", false):Enable(false)
    end
    ValueHeaderStyle:SetVal("value", listCSS[class])
    ValueHeaderStyle:SetClassVal("class", listCSS[class])
    Options.styleHeader = class
    userMods.SetGlobalConfigSection("Options", Options)
end

function HeaderStylePrev(reaction)
    local class = Options.styleHeader
    class = class - 1
    wtHeaderStyle:GetChildChecked("BtnRight", false):Enable(true)
    if class == 0 then
        wtHeaderStyle:GetChildChecked("BtnLeft", false):Enable(false)
    end
    ValueHeaderStyle:SetVal("value", listCSS[class])
    ValueHeaderStyle:SetClassVal("class", listCSS[class])
    Options.styleHeader = class
    userMods.SetGlobalConfigSection("Options", Options)
end

function DateStyleNext(reaction)
    local class = Options.styleDate
    class = class + 1
    wtDateStyle:GetChildChecked("BtnLeft", false):Enable(true)
    if class == table.getn(listCSS) then
        wtDateStyle:GetChildChecked("BtnRight", false):Enable(false)
    end
    ValueDateStyle:SetVal("value", listCSS[class])
    ValueDateStyle:SetClassVal("class", listCSS[class])
    Options.styleDate = class
    userMods.SetGlobalConfigSection("Options", Options)
end

function DateStylePrev(reaction)
    local class = Options.styleDate
    class = class - 1
    wtDateStyle:GetChildChecked("BtnRight", false):Enable(true)
    if class == 0 then
        wtDateStyle:GetChildChecked("BtnLeft", false):Enable(false)
    end
    ValueDateStyle:SetVal("value", listCSS[class])
    ValueDateStyle:SetClassVal("class", listCSS[class])
    Options.styleDate = class
    userMods.SetGlobalConfigSection("Options", Options)
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

function ScanNext(reaction)
    local variant = Options.ScanBy
    variant = variant + 1
    VariantScanBy(variant)
    Options.ScanBy = variant
    userMods.SetGlobalConfigSection("Options", Options)
end

function ScanPrev(reaction)
    local variant = Options.ScanBy
    variant = variant - 1
    VariantScanBy(variant)
    Options.ScanBy = variant
    userMods.SetGlobalConfigSection("Options", Options)
end

function DefaultOptions(reaction)
    Options = {}
    userMods.SetGlobalConfigSection("Options", Options)
    Options = defaultOptions
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
    common.RegisterReactionHandler(PricesNext, "PricesNext")
    common.RegisterReactionHandler(PricesPrev, "PricesPrev")
    common.RegisterReactionHandler(CoinsNext, "CoinsNext")
    common.RegisterReactionHandler(CoinsPrev, "CoinsPrev")
    common.RegisterReactionHandler(HeaderStyleNext, "HeaderStyleNext")
    common.RegisterReactionHandler(HeaderStylePrev, "HeaderStylePrev")
    common.RegisterReactionHandler(DateStyleNext, "DateStyleNext")
    common.RegisterReactionHandler(DateStylePrev, "DateStylePrev")
    common.RegisterReactionHandler(showHeader, "showHeader")
    common.RegisterReactionHandler(showDate, "showDate")
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