-- Список задач сканирования (режимы "из сумки" и "свой список"),
-- встроенный в панель вкладки "Скан". Строки создаются из шаблона Line;
-- в режиме "свой список" у строк есть ластики удаления, под списком -
-- строка ввода для добавления нового имени.
if AuctionPlusNoAuction then return end
-- Панель ScanPanel при загрузке TabScan перемещена в окно аукциона
-- (AuctionMainPanel:AddChild), поэтому ищем TaskList оттуда, а не от mainForm
Global("SearchList", {})
local wtTaskList = AuctionMainPanel:GetChildChecked("ScanPanel", false):GetChildChecked("TaskList", false)
local wtTaskItems = wtTaskList:GetChildChecked("TaskItems", false)
local EditPanel = wtTaskList:GetChildChecked("EditPanel", false)
local EditLine = EditPanel:GetChildChecked("EditLine", false)
local StrikeOut = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("StrikeOut")
local DoubleStrikethrough = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("DoubleStrikethrough")
local TripleStrikeout = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("TripleStrikeout")
local ClearBlockFrame = common.GetAddonRelatedTextureGroup("Group01"):GetTexture("ClearBlockFrame")
local wtDescPlainLine = nil
local PlainLines = {}

function CreatePlainLine(i)
	local plainline = {}
	if not wtDescPlainLine then
		plainline.widget = wtTaskList:GetChildChecked("Line", false)
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

-- isYourList: строка своего списка - с ластиком удаления
function AddPlainLines(i, name, isYourList)
    CreatePlainLine(i)
    PlainLines[i].text:SetVal("text", name)
    PlainLines[i].text:SetClassVal("class", "OnPaper")
    if isYourList then
        PlainLines[i].eraser:Show(true)
    else
        PlainLines[i].eraser:Show(false)
    end
    wtTaskItems:PushBack(PlainLines[i].widget)
end

function FillYourSearchList()
	SearchList = userMods.GetGlobalConfigSection("SearchList") or {}
	local countSearchList = table.getn(SearchList)
	if countSearchList > 0 then
		for i = 1, countSearchList do
			AddPlainLines(i, SearchList[i], true)
		end
	end
end

function EditLineEnter()
	local i = table.getn(SearchList)+1
	local text = EditLine:GetText()
	if string.len(userMods.FromWString(text)) > 0 then
		AddPlainLines(i, text, true)
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

local function ValidPlainLine(i)
	-- строки уничтожаются только через ClearList/ClearBagList,
	-- которые сбрасывают PlainLines: запись в таблице = живая строка
	local line = PlainLines[i]
	return line and line.widget ~= nil and line.text ~= nil
end

function StrikeOutLine(i)
	if not ValidPlainLine(i) then return end
	local placeText = PlainLines[i].text:GetPlacementPlain()
	if placeText.sizeY <= 30 then
		PlainLines[i].text:SetBackgroundTexture(StrikeOut)
	elseif placeText.sizeY <= 50 then
		PlainLines[i].text:SetBackgroundTexture(DoubleStrikethrough)
	else
		PlainLines[i].text:SetBackgroundTexture(TripleStrikeout)
	end
end

function ClearStrikeOutLine()
	for i = 1, table.getn(PlainLines) do
		if ValidPlainLine(i) then
			PlainLines[i].text:SetBackgroundTexture(ClearBlockFrame)
			if Options.ScanBy == 4 then
				PlainLines[i].eraser:Show(true)
			end
		end
	end
end

function EnsureVisibleLine(i)
	if not ValidPlainLine(i) then return end
	if wtTaskItems:IsValid() then
		wtTaskItems:EnsureVisible(PlainLines[i].widget)
	end
end

function ClearList()
    DestroyWidgetsInContainer(wtTaskItems)
    PlainLines = {}
end

function ClearBagList()
	ClearList()
end

-- Показ встроенного списка. mode: 3 - предметы из сумки, 4 - свой список.
-- Содержимое пересоздаётся при каждом показе.
function ShowTaskList(mode)
	ClearList()
	if mode == 4 then
		FillYourSearchList()
		EditPanel:Show(true)
		EditLine:SetText(userMods.ToWString(GetLocalizedText("Add a name")))
		EditLine:SetFocus(false)
	else
		for i = 1, table.getn(BagSearchList) do
			AddPlainLines(i, BagSearchList[i], false)
		end
		EditPanel:Show(false)
	end
	wtTaskList:Show(true)
end

function HideTaskList()
	ClearList()
	wtTaskList:Show(false)
	EditPanel:Show(false)
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
		if ValidPlainLine(i) and PlainLines[i].eraser then
			PlainLines[i].eraser:Show(false)
		end
	end
end

function SearchListInit()
    common.RegisterReactionHandler(EditLineEnter, "EditLineEnter")
	common.RegisterReactionHandler(DeleteLine, "DeleteLine")
	common.RegisterReactionHandler(EditLineEsc, "EditLineEsc")
	common.RegisterReactionHandler(EditLineFocusChanged, "EditLineFocusChanged")
    common.RegisterReactionHandler(EditLineEnter, "AddLine")
	common.RegisterReactionHandler(EditLineEsc, "ClearLine")
end

SearchListInit()
