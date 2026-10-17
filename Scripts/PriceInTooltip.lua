local Gold = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinGold")
local Silver = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinSilver")
local Copper = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("CoinCopper")
local wtPriceInTooltip = mainForm:GetChildChecked("PriceInTooltip", false)
local txtHeader = wtPriceInTooltip:GetChildChecked("Header", false)
local widgetPanelDescPrice = nil
local MoneyString = {}
local DateString = wtPriceInTooltip:GetChildChecked("Update", false)
local txtStartingAt = wtPriceInTooltip:GetChildChecked("StartingAt", false)
local txtEndingAt = wtPriceInTooltip:GetChildChecked("EndingAt", false)
local ContainerPrice = wtPriceInTooltip:GetChildChecked("ContainerPrice", false)
local wtSeparator = wtPriceInTooltip:GetChildChecked("Separator", false)
local DescSeparator = nil

function CreateMoneyString()
	local mstring = {}
	if not widgetPanelDescPrice then
		mstring.widget = wtPriceInTooltip:GetChildChecked("Prices", false)
		widgetPanelDescPrice = mstring.widget:GetWidgetDesc()
	else
		mstring.widget = mainForm:CreateWidgetByDesc(widgetPanelDescPrice)
		wtPriceInTooltip:AddChild(mstring.widget)
	end
	mstring.gold = mstring.widget:GetChildChecked("ValueGold", false)
	mstring.goldIcon = mstring.widget:GetChildChecked("IconGold", false)
	mstring.silver = mstring.widget:GetChildChecked("ValueSilver", false)
	mstring.silverIcon = mstring.widget:GetChildChecked("IconSilver", false)
	mstring.copper = mstring.widget:GetChildChecked("ValueCopper", false)
	mstring.copperIcon = mstring.widget:GetChildChecked("IconCopper", false)
	mstring.widget:SetName("money")
	MoneyString = mstring
end

function PushPrice(price)
	local SplitMoney = Split(price)
	CreateMoneyString()
	if Options.ShowCoins == 1 then
		if SplitMoney[1] > 0 then
			MoneyString.gold:SetVal("gold", common.FormatInt(SplitMoney[1], "%d", " "))
			MoneyString.goldIcon:SetBackgroundTexture(Gold)
			ContainerPrice:PushBack(MoneyString.gold)
			ContainerPrice:PushBack(MoneyString.goldIcon)
		end
		if SplitMoney[2] > 0 then
			MoneyString.silver:SetVal("silver", common.FormatInt(SplitMoney[2], "%d"))
			MoneyString.silverIcon:SetBackgroundTexture(Silver)
			ContainerPrice:PushBack(MoneyString.silver)
			ContainerPrice:PushBack(MoneyString.silverIcon)
		end
		if SplitMoney[3] > 0 then
			MoneyString.copper:SetVal("copper", common.FormatInt(SplitMoney[3], "%d"))
			MoneyString.copperIcon:SetBackgroundTexture(Copper)
			ContainerPrice:PushBack(MoneyString.copper)
			ContainerPrice:PushBack(MoneyString.copperIcon)
		end
	elseif Options.ShowCoins == 2 then
		if SplitMoney[1] > 0 then
			MoneyString.gold:SetVal("gold", common.FormatInt(SplitMoney[1], "%d", " "))
			MoneyString.goldIcon:SetBackgroundTexture(Gold)
			ContainerPrice:PushBack(MoneyString.gold)
			ContainerPrice:PushBack(MoneyString.goldIcon)
		end
		if SplitMoney[2] > 0 then
			MoneyString.silver:SetVal("silver", common.FormatInt(SplitMoney[2], "%d"))
			MoneyString.silverIcon:SetBackgroundTexture(Silver)
			ContainerPrice:PushBack(MoneyString.silver)
			ContainerPrice:PushBack(MoneyString.silverIcon)
		end
	elseif Options.ShowCoins == 3 then
		MoneyString.gold:SetVal("gold", common.FormatInt(SplitMoney[1], "%d", " "))
		MoneyString.goldIcon:SetBackgroundTexture(Gold)
		ContainerPrice:PushBack(MoneyString.gold)
		ContainerPrice:PushBack(MoneyString.goldIcon)
	end
end

function FillContainerPrice(Itemname)
	if not ItemsDB[Itemname] then return false end
	local ItemDB = ItemsDB[Itemname]
	ContainerPrice:RemoveItems()
	txtStartingAt:SetVal("value", GetLocalizedText("StartingAt"))
	txtEndingAt:SetVal("value", GetLocalizedText("EndingAt"))
	if Options.ShowHeader then
		txtHeader:SetClassVal("class", userMods.FromWString(listCSS[Options.styleHeader]))
		txtHeader:SetVal("text", GetLocalizedText("Auction price"))
	end
	local date, values
	if ItemDB.LastScan then
		date, values = ItemDB.LastScan, ItemDB[ItemDB.LastScan]
	else
		date, values = GetLastScan(ItemDB)
	end
	if Options.ShowDate then
		DateString:SetVal("date", userMods.ToWString(date))
		DateString:SetClassVal("class", userMods.FromWString(listCSS[Options.styleDate]))
		ContainerPrice:PushBack(DateString)
	end
	if Options.ShowPrices == 1 then
		ContainerPrice:PushBack(txtStartingAt)
		PushPrice(values.min)
		local Space =  mainForm:GetChildChecked("Space", true)
		ContainerPrice:PushBack(Space)
		ContainerPrice:PushBack(txtEndingAt)
		PushPrice(values.max)
	elseif Options.ShowPrices == 2 then
		ContainerPrice:PushBack(txtStartingAt)
		PushPrice(values.min)
	elseif Options.ShowPrices == 3 then
		ContainerPrice:PushBack(txtEndingAt)
		PushPrice(values.max)
	end

	return true
end

function PushPriceInToolTip(container)
	local Name = container:At(0)
	if (common.GetApiType(Name) ~= "Widget_TextViewSafe") then return end
	local Itemname = userMods.FromWString(Name:GetWString())
	if FillContainerPrice(Itemname) then
		local IconSmartLineFound = false
		if container:GetElementCount() > 3 then
			for i = container:GetElementCount()-3, container:GetElementCount()-1 do
				if container:At(i):GetName() == "IconSmartLine" then
					IconSmartLineFound = true
					if Options.ShowHeader then
						container:Insert(i, txtHeader)
						container:Insert(i+1, ContainerPrice)
						container:Insert(i+2, wtSeparator)
						container:ForceReposition()
					else
						container:Insert(i, ContainerPrice)
						container:Insert(i+1, wtSeparator)
						container:ForceReposition()
					end
				end
			end
		end
		if IconSmartLineFound == false then
			container:PushBack(wtSeparator)
			if Options.ShowHeader then
				container:PushBack(txtHeader)
			end
			container:PushBack(ContainerPrice)
			container:ForceReposition()
		end
	end
end

function checkAtTooltip(params)
	for i = 0, params:GetElementCount()-1 do
		local name = params:At(i):GetName()
		common.LogInfo("common", "At - ", tostring(i), ", name - ", tostring(name))
	end
end

function SearchTooltip(params)
	if (params.addonName ~= "ContextTooltip") then return end
	if not params.widget:IsVisibleEx() then return end
	--checkAtTooltip(params.widget)
	PushPriceInToolTip(params.widget:GetChildChecked("Container"))
end

function PriceInTooltipInit()
	common.RegisterEventHandler(SearchTooltip, "EVENT_WIDGET_SHOW_CHANGED")
	common.GetAddonMainForm("ContextTooltip"):GetChildChecked("TooltipMain"):SetOnShowNotification(true)
end

PriceInTooltipInit()