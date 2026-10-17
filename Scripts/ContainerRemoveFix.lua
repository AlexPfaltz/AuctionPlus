function DestroyWidgetsInContainer(container)
    if not container then return end
    local cached_widgets = {}
    local items_count = container:GetElementCount()
    if items_count > 0 then
        for i = 0, items_count - 1 do
            local w = container:At(i)
            if w then
                -- IsValid может упасть на InvalidWidgetSafe — оборачиваем в pcall
                local ok, valid = pcall(function() return w:IsValid() end)
                if ok and valid then
                    cached_widgets[#cached_widgets + 1] = w
                end
            end
        end
    end

    container:RemoveItems()

    for i = 1, #cached_widgets do
        local w = cached_widgets[i]
        pcall(function() w:DestroyWidget() end)
    end
end