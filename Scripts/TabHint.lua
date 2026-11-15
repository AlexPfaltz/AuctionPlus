-- Всплывающие подсказки для вкладок аддона (Купить/Продать/Скан),
-- аналог подсказок стоковых вкладок аукциона. Панель лежит в форме
-- аддона поверх всех окон, поэтому позиционируется в координатах
-- экрана (правый нижний угол вкладки), а не относительно окна аукциона.
if AuctionPlusNoAuction then return end

local wtTabHint = mainForm:GetChildChecked("TabHint", false)
local wtHintTitle = wtTabHint:GetChildChecked("Title", false)
local wtHintText = wtTabHint:GetChildChecked("Description", false)

-- Имя виджета вкладки -> ключи локализации заголовка и описания
local HINTS = {
	TabBuy = { title = "btTabBuy", text = "TabBuyHint" },
	TabSell = { title = "btTabSell", text = "TabSellHint" },
	TabScan = { title = "btTabScan", text = "TabScanHint" },
}

local function TabHintOver(params)
	local widget = params.widget
	local hint = widget and HINTS[widget:GetName()]
	if not (params.active and hint) then
		wtTabHint:Show(false)
		return
	end
	wtHintTitle:SetVal("text", userMods.ToWString(GetLocalizedText(hint.title)))
	wtHintText:SetVal("text", userMods.ToWString(GetLocalizedText(hint.text)))

	-- реальный прямоугольник вкладки на экране -> виртуальные координаты
	local screen = common.GetPosConverterParams()
	local rect = widget:GetRealRect()
	local scaleX = screen.fullVirtualSizeX / screen.realSizeX
	local scaleY = screen.fullVirtualSizeY / screen.realSizeY
	local place = wtTabHint:GetPlacementPlain()
	-- правый край подсказки по правому краю вкладки, в пределах экрана
	local posX = rect.x2 * scaleX - place.sizeX
	place.posX = math.max(4, math.min(posX, screen.fullVirtualSizeX - place.sizeX - 4))
	-- под вкладкой; если внизу нет места - над ней
	local posY = rect.y2 * scaleY + 2
	if posY + place.sizeY > screen.fullVirtualSizeY - 4 then
		posY = rect.y1 * scaleY - place.sizeY - 2
	end
	place.posY = math.max(4, posY)
	wtTabHint:SetPlacementPlain(place)
	wtTabHint:Show(true)
end

common.RegisterReactionHandler(TabHintOver, "TabHintOver")
