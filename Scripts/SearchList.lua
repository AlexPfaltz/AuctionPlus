Global("OpenSearchListFromOptions", false)
Global("SearchList", {})
local wtSearchList = mainForm:GetChildChecked("SearchList", false)
local ContainerForBag = wtSearchList:GetChildChecked("ContainerForBag", false)
local ContainerYourList = wtSearchList:GetChildChecked("ContainerYourList", false)
local StrikeOut = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("StrikeOut")
local DoubleStrikethrough = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("DoubleStrikethrough")
local TripleStrikeout = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("TripleStrikeout")
local ClearBlockFrame = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("ClearBlockFrame")
local EditPanel = wtSearchList:GetChildChecked("EditPanel", false)
local EditLine = EditPanel:GetChildChecked("EditLine", false)
local wtDescPlainLine = nil
local PlainLines = {}

function CreatePlainLine(i)
	local plainline = {}
	if not wtDescPlainLine then
		plainline.widget = wtSearchList:GetChildChecked("Line", false)
		wtDescPlainLine = plainline.widget:GetWidgetDesc()
	else
		plainline.widget = mainForm:CreateWidgetByDesc(wtDescPlainLine)
		mainForm:AddChild(plainline.widget)
	end
	plainline.eraser = plainline.widget:GetChildChecked("Eraser", false)
	plainline.eraser:SetName("eraser: " .. i)
	plainline.text = plainline.widget:GetChildChecked("Text", false)
	plainline.text:SetName("text: " .. i)
	plainline.widget:SetName("plainline: " .. i)
	PlainLines[i] = plainline
end

function AddPlainLines(i, name)
    CreatePlainLine(i)
	if Options.ScanBy == 2 and not OpenSearchListFromOptions then
    	PlainLines[i].text:SetVal("text", name)
		PlainLines[i].text:SetClassVal("class", "OnPaper")
		PlainLines[i].eraser:Show(false)
		ContainerForBag:PushBack(PlainLines[i].widget)
	elseif Options.ScanBy == 3 and not OpenSearchListFromOptions then
		PlainLines[i].text:SetVal("text", name)
		PlainLines[i].text:SetClassVal("class", "OnPaper")
		PlainLines[i].eraser:Show(true)
		ContainerYourList:PushBack(PlainLines[i].widget)
	elseif OpenSearchListFromOptions then
		PlainLines[i].text:SetVal("text", name)
		PlainLines[i].text:SetClassVal("class", "OnPaper")
		PlainLines[i].eraser:Show(true)
		ContainerYourList:PushBack(PlainLines[i].widget)
	end
end

function FillYourSearchList()
	SearchList = userMods.GetGlobalConfigSection("SearchList") or {}
	local countSearchList = table.getn(SearchList)
	if countSearchList > 0 then
		for i = 1, countSearchList do
			AddPlainLines(i, SearchList[i])
		end
	end
end

function EditLineEnter()
	local i = table.getn(SearchList)+1
	local text = EditLine:GetText()
	if string.len(userMods.FromWString(text)) > 0 then
		AddPlainLines(i, text)
		table.insert(SearchList, text)
		userMods.SetGlobalConfigSection("SearchList", SearchList)
		EditLine:SetText(userMods.ToWString(""))
	end
end

function EditLineEsc()
	EditLine:SetFocus(false)
	local reaction = {active = false}
	EditLineFocusChanged(reaction)
end

function SaveSearchList()
	userMods.SetGlobalConfigSection("SearchList", SearchList)
end

function StrikeOutLine(i)
	local placeText = PlainLines[i].text:GetPlacementPlain()
	if placeText.sizeY < 30 then
		PlainLines[i].text:SetBackgroundTexture(StrikeOut)
	elseif placeText.sizeY > 30 and placeText.sizeY < 50 then
		PlainLines[i].text:SetBackgroundTexture(DoubleStrikethrough)
	elseif placeText.sizeY > 50 then
		PlainLines[i].text:SetBackgroundTexture(TripleStrikeout)
	end
end

function ClearStrikeOutLine()
	for i = 1, table.getn(PlainLines) do
		PlainLines[i].text:SetBackgroundTexture(ClearBlockFrame)
		if Options.ScanBy == 3 or OpenSearchListFromOptions then
			PlainLines[i].eraser:Show(true)
		end
	end
end

function EnsureVisibleLine(i)
	if Options.ScanBy == 2 then
		ContainerForBag:EnsureVisible(PlainLines[i].widget)
	elseif Options.ScanBy == 3 then
		ContainerYourList:EnsureVisible(PlainLines[i].widget)
	end
end

function ClearList()
	if Options.ScanBy == 2 and not OpenSearchListFromOptions then
		DestroyWidgetsInContainer(ContainerForBag)
	elseif Options.ScanBy == 3 and not OpenSearchListFromOptions then
		DestroyWidgetsInContainer(ContainerYourList)
	elseif OpenSearchListFromOptions then
		DestroyWidgetsInContainer(ContainerYourList)
	end
end

function ShowSearchListForBag()
	wtSearchList:Show(true)
	ContainerForBag:Show(true)
end

function ShowYourSearchList()
	FillYourSearchList()
	wtSearchList:Show(true)
	ContainerYourList:Show(true)
	EditPanel:Show(true)
	EditLine:SetText(userMods.ToWString(GetLocalizedText("Add a name")))
	EditLine:SetFocus(false)
end

function HideSearchList()
	ClearList()
    wtSearchList:Show(false)
	ContainerForBag:Show(false)
	ContainerYourList:Show(false)
	EditPanel:Show(false)
	OpenSearchListFromOptions = false
end

function DeleteLine(reaction)
    local index = tonumber(string.sub(reaction.sender, 9))
	table.remove(SearchList, index)
	SaveSearchList()
	ClearList()
	FillYourSearchList()
end

function EditLineFocusChanged(reaction)
	if reaction.active then
		EditLine:SetText(userMods.ToWString(""))
	else
		EditLine:SetText(userMods.ToWString(GetLocalizedText("Add a name")))
	end
end

function HideErasers()
	for i = 1, table.getn(PlainLines) do
		PlainLines[i].eraser:Show(false)
	end
end

function SearchListInit()
    common.RegisterReactionHandler(HideSearchList, "CloseList")
	common.RegisterReactionHandler(EditLineEnter, "EditLineEnter")
	common.RegisterReactionHandler(DeleteLine, "DeleteLine")
	common.RegisterReactionHandler(EditLineEsc, "EditLineEsc")
	common.RegisterReactionHandler(EditLineFocusChanged, "EditLineFocusChanged")
	common.RegisterReactionHandler(EditLineEnter, "AddLine")
	common.RegisterReactionHandler(EditLineEsc, "ClearLine")
    DnD.Init(wtSearchList, wtSearchList, true, true)
end

SearchListInit()