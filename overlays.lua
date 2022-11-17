local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local LAI = LibStub("LibAppropriateItems-1.0")

-- minor compat:
local IsDressableItem = _G.IsDressableItem or C_Item.IsDressableItemByID

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if f[event] then return f[event](f, ...) end end)
local hooks = {}
function f:RegisterAddonHook(addon, callback)
    if IsAddOnLoaded(addon) then
        callback()
    else
        hooks[addon] = callback
    end
end
function f:ADDON_LOADED(addon)
    if hooks[addon] then
        hooks[addon]()
        hooks[addon] = nil
    end
end
f:RegisterEvent("ADDON_LOADED")

local function PrepareItemButton(button, point, offsetx, offsety)
    if button.appearancetooltipoverlay then
        return
    end

    local overlayFrame = CreateFrame("FRAME", nil, button)
    overlayFrame:SetAllPoints()
    button.appearancetooltipoverlay = overlayFrame

    -- need the sublevel to make sure we're above overlays for e.g. azerite gear
    local sublevel = 4
    if button.IconOverlay then
        sublevel = select(2, button.IconOverlay:GetDrawLayer())
    end

    local background = overlayFrame:CreateTexture(nil, "OVERLAY", nil, sublevel)
    background:SetSize(12, 12)
    background:SetPoint(point or 'BOTTOMLEFT', offsetx or 0, offsety or 0)
    background:SetColorTexture(0, 0, 0, 0.4)

    button.appearancetooltipoverlay.icon = overlayFrame:CreateTexture(nil, "OVERLAY", nil, sublevel + 1)
    button.appearancetooltipoverlay.icon:SetSize(16, 16)
    button.appearancetooltipoverlay.icon:SetPoint("CENTER", background, "CENTER")
    button.appearancetooltipoverlay.icon:SetAtlas("transmog-icon-hidden")

    button.appearancetooltipoverlay.iconInappropriate = overlayFrame:CreateTexture(nil, "OVERLAY", nil, sublevel + 1)
    button.appearancetooltipoverlay.iconInappropriate:SetSize(14, 14)
    button.appearancetooltipoverlay.iconInappropriate:SetPoint("CENTER", background, "CENTER")
    button.appearancetooltipoverlay.iconInappropriate:SetAtlas("mailbox")
    button.appearancetooltipoverlay.iconInappropriate:SetRotation(1.7 * math.pi)
    -- button.appearancetooltipoverlay.iconInappropriate:SetVertexColor(0, 1, 1)

    overlayFrame:Hide()
end
local function UpdateOverlay(button, link, ...)
    if not link then
        if button.appearancetooltipoverlay then
            button.appearancetooltipoverlay:Hide()
        end
        return
    end
    local hasAppearance, appearanceFromOtherItem = ns.PlayerHasAppearance(link)
    local appropriateItem = LAI:IsAppropriate(link)
    -- ns.Debug("Considering item", link, hasAppearance, appearanceFromOtherItem)
    if
        (not hasAppearance or appearanceFromOtherItem) and
        (not ns.db.currentClass or appropriateItem) and
        IsDressableItem(link) and
        ns.CanTransmogItem(link)
    then
        PrepareItemButton(button, ...)
        button.appearancetooltipoverlay.icon:Hide()
        button.appearancetooltipoverlay.iconInappropriate:Hide()
        if appropriateItem then
            button.appearancetooltipoverlay.icon:Show()
            if appearanceFromOtherItem then
                -- blue eye
                button.appearancetooltipoverlay.icon:SetVertexColor(0, 1, 1)
            else
                -- regular purple trasmog-eye
                button.appearancetooltipoverlay.icon:SetVertexColor(1, 1, 1)
            end
        else
            -- mail icon
            button.appearancetooltipoverlay.iconInappropriate:Show()
        end
        button.appearancetooltipoverlay:Show()
    elseif button.appearancetooltipoverlay then
        button.appearancetooltipoverlay:Hide()
    end
end

local function UpdateContainerButton(button, bag, slot)
    if button.appearancetooltipoverlay then button.appearancetooltipoverlay:Hide() end
    if not ns.db.bags then
        return
    end
    slot = slot or button:GetID()
    local item = Item:CreateFromBagAndSlot(bag, slot)
    if item:IsItemEmpty() then
        return
    end
    item:ContinueOnItemLoad(function()
        local link = item:GetItemLink()
        if not ns.db.bags_unbound or not C_Item.IsBound(item:GetItemLocation()) then
            UpdateOverlay(button, link)
        end
    end)
end

if _G.ContainerFrame_Update then
    hooksecurefunc("ContainerFrame_Update", function(container)
        local bag = container:GetID()
        local name = container:GetName()
        for i = 1, container.size, 1 do
            local button = _G[name .. "Item" .. i]
            UpdateContainerButton(button, bag)
        end
    end)
else
    local update = function(frame)
        for _, itemButton in frame:EnumerateValidItems() do
            UpdateContainerButton(itemButton, itemButton:GetBagID(), itemButton:GetID())
        end
    end
    -- can't use ContainerFrameUtil_EnumerateContainerFrames because it depends on the combined bags setting
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", update)
    for _, frame in ipairs(UIParent.ContainerFrames) do
        hooksecurefunc(frame, "UpdateItems", update)
    end
end

hooksecurefunc("BankFrameItemButton_Update", function(button)
    if not button.isBag then
        UpdateContainerButton(button, -1)
    end
end)

-- Merchant frame

hooksecurefunc("MerchantFrame_Update", function()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local frame = _G["MerchantItem"..i.."ItemButton"]
        if frame then
            if frame.appearancetooltipoverlay then frame.appearancetooltipoverlay:Hide() end
            if not ns.db.merchant then
                return
            end
            if frame.link then
                UpdateOverlay(frame, frame.link)
            end
        end
    end
end)

-- Loot frame

if _G.LootFrame_UpdateButton then
    hooksecurefunc("LootFrame_UpdateButton", function(index)
        local button = _G["LootButton"..index]
        if not button then return end
        if button.appearancetooltipoverlay then button.appearancetooltipoverlay:Hide() end
        if not ns.db.loot then return end
        -- ns.Debug("LootFrame_UpdateButton", button:IsEnabled(), button.slot, button.slot and GetLootSlotLink(button.slot))
        if button:IsEnabled() and button.slot then
            local link = GetLootSlotLink(button.slot)
            if link then
                UpdateOverlay(button, link)
            end
        end
    end)
else
    local function handleSlot(frame)
        if not frame.Item then return end
        if frame.Item.appearancetooltipoverlay then frame.Item.appearancetooltipoverlay:Hide() end
        if not ns.db.loot then return end
        local data = frame:GetElementData()
        if not (data and data.slotIndex) then return end
        local link = GetLootSlotLink(data.slotIndex)
        if link then
            UpdateOverlay(frame.Item, link)
        end
    end
    LootFrame.ScrollBox:RegisterCallback("OnUpdate", function(...)
        LootFrame.ScrollBox:ForEachFrame(handleSlot)
    end)
end

-- Encounter Journal frame

f:RegisterAddonHook("Blizzard_EncounterJournal", function()
    hooksecurefunc("EncounterJournal_LootCallback", function(itemID)
        local scrollBox = EncounterJournal.encounter.info.LootContainer.ScrollBox
        local button = scrollBox:FindFrameByPredicate(function(button)
            return button.itemID == itemID
        end);
        if button then
            UpdateOverlay(button, button.link, "TOPLEFT", 5, -4)
        end
    end)
end)

-- Sets list

f:RegisterAddonHook("Blizzard_Collections", function()
    local function setCompletion(setID)
        local have, need = 0, 0
        for _, appearance in pairs(C_TransmogSets.GetSetPrimaryAppearances(setID)) do
            need = need + 1
            if appearance.collected then
                have = have + 1
            end
        end
        return have, need
    end
    local function setSort(a, b)
        return a.uiOrder < b.uiOrder
    end
    local function buildSetText(setID, separator)
        separator = separator or "\n"
        local variants = C_TransmogSets.GetVariantSets(setID)
        if type(variants) ~= "table" then return "" end
        table.insert(variants, C_TransmogSets.GetSetInfo(setID))
        table.sort(variants, setSort)
        -- local text = setID -- debug
        local text = ""
        for _, set in ipairs(variants) do
            local have, need = setCompletion(set.setID)
            text = text .. ns.ColorTextByCompletion((GENERIC_FRACTION_STRING):format(have, need), have / need) .. separator
        end
        return string.sub(text, 1, -#separator)
    end
    local function makeOverlay(parent)
       local overlay = CreateFrame("Frame", nil, parent)
       overlay.text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
       overlay:SetAllPoints()
       -- overlay.text:SetPoint("TOPRIGHT", -2, -2)
       overlay.text:SetPoint("BOTTOMRIGHT", -2, 2)
       overlay:Show()
       return overlay
    end
    if WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame then
        local function update(self)
            local offset = HybridScrollFrame_GetOffset(self)
            local buttons = self.buttons
            for i = 1, #buttons do
                local button = buttons[i]
                if button.appearancetooltipoverlay then button.appearancetooltipoverlay.text:SetText("") end
                if ns.db.setjournal and button:IsShown() then
                    local setID = button.setID
                    if not button.appearancetooltipoverlay then
                        button.appearancetooltipoverlay = makeOverlay(button)
                    end
                    button.appearancetooltipoverlay.text:SetText(buildSetText(setID))
                end
            end
        end
        hooksecurefunc(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame, "Update", update)
        hooksecurefunc(WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame, "update", update)
    else
        local function handleSlot(frame)
            if frame.appearancetooltipoverlay then frame.appearancetooltipoverlay.text:SetText("") end
            if ns.db.setjournal and frame:IsShown() then
                local data = frame:GetElementData()
                local setID = data.setID
                if not frame.appearancetooltipoverlay then
                    frame.appearancetooltipoverlay = makeOverlay(frame)
                end
                frame.appearancetooltipoverlay.text:SetText(buildSetText(setID))
            end
        end
        WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox:RegisterCallback("OnUpdate", function(...)
            WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox:ForEachFrame(handleSlot)
        end)
    end
end)

-- Other addons:

-- Inventorian
f:RegisterAddonHook("Inventorian", function()
    local AA = LibStub("AceAddon-3.0", true)
    local inv = AA and AA:GetAddon("Inventorian", true)
    if inv then
        local function ToIndex(bag, slot) -- copied from inside Inventorian
            return (bag < 0 and bag * 100 - slot) or (bag * 100 + slot)
        end
        local function invContainerUpdateSlot(self, bag, slot)
            if not self.items[ToIndex(bag, slot)] then return end
            UpdateContainerButton(self.items[ToIndex(bag, slot)], bag, slot)
        end
        local function hookInventorian()
            hooksecurefunc(inv.bag.itemContainer, "UpdateSlot", invContainerUpdateSlot)
            hooksecurefunc(inv.bank.itemContainer, "UpdateSlot", invContainerUpdateSlot)
        end
        if inv.bag then
            hookInventorian()
        else
            hooksecurefunc(inv, "OnEnable", function()
                hookInventorian()
            end)
        end
    end
end)

--Baggins:
f:RegisterAddonHook("Baggins", function()
    hooksecurefunc(Baggins, "UpdateItemButton", function(baggins, bagframe, button, bag, slot)
        UpdateContainerButton(button, bag)
    end)
end)

--Bagnon:
f:RegisterAddonHook("Bagnon", function()
    hooksecurefunc(Bagnon.Item, "Update", function(frame)
        local bag = frame:GetBag()
        UpdateContainerButton(frame, bag)
    end)
end)

-- Butsu
f:RegisterAddonHook("Butsu", function()
    hooksecurefunc(Butsu, "LOOT_OPENED", function(self, event, autoloot)
        if not self:IsShown() then return end
        local items = GetNumLootItems()
        if items > 0 then
            for i=1, items do
                local slot = _G["ButsuSlot" .. i]
                if slot and slot.appearancetooltipoverlay then slot.appearancetooltipoverlay:Hide() end
                if ns.db.loot then
                    local link = GetLootSlotLink(i)
                    if slot and link then
                        UpdateOverlay(slot, link, "RIGHT", -6)
                    end
                end
            end
        end
    end)
end)

-- Adibags
f:RegisterAddonHook("AdiBags", function()
    local AA = LibStub("AceAddon-3.0", true)
    local AdiBags = AA and AA:GetAddon("AdiBags", true)
    if not AdiBags then return end
    local filter = AdiBags:RegisterFilter("Appearance Unknown", 86, "ABEvent-1.0")
    filter.uiName = "Unknown appearance"
    filter.uiDesc = TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN

    function filter:OnInitialize()
        self.db = AdiBags.db:RegisterNamespace(myname, {
            profile = {
                other = true,
            }
        })
    end
    function filter:Update() self:SendMessage("AdiBags_FiltersChanged") end
    function filter:OnEnable()
        self:RegisterMessage("AdiBags_UpdateButton", "UpdateButton")
        self:SendMessage("AdiBags_UpdateAllButtons")
        AdiBags:UpdateFilters()
    end
    function filter:OnDisable() AdiBags:UpdateFilters() end
    function filter:Filter(slotData)
        local hasAppearance, appearanceFromOtherItem = ns.PlayerHasAppearance(slotData.link)
        local appropriateItem = LAI:IsAppropriate(slotData.link)
        if
            (not hasAppearance or appearanceFromOtherItem) and
            (self.db.profile.other or appropriateItem) and
            IsDressableItem(slotData.link) and
            ns.CanTransmogItem(slotData.link)
        then
            return appropriateItem and "Appearance Unknown" or "Appearance Unknown (other class)"
        end
    end
    function filter:GetOptions()
        return {
            other = {
                name = "Unlearnable items",
                desc = "Include items that the current character can't learn",
                type = "toggle",
                order = 60,
            },
        }, AdiBags:GetOptionHandler(self, true, function() return self:Update() end)
    end
    function filter:UpdateButton(event, button)
        UpdateContainerButton(button, button.bag, button.slot)
    end
end)

-- SilverDragon
f:RegisterAddonHook("SilverDragon", function()
    if not (SilverDragon and SilverDragon.RegisterCallback) then
        -- Geniunely unsure what'd cause this, but see #11 on github
        return
    end
    SilverDragon.RegisterCallback("AppearanceTooltip", "LootWindowOpened", function(_, window)
        ns.RegisterTooltip(_G["SilverDragonLootTooltip"])
        if window and window.buttons and #window.buttons then
            for i, button in ipairs(window.buttons) do
                UpdateOverlay(button, button:GetItem())
            end
        end
    end)
end)
