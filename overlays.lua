local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local LAI = LibStub("LibAppropriateItems-1.0")

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if f[event] then return f[event](f, ...) end end)

local function PrepareItemButton(button, point, offsetx, offsety)
    if button.appearancetooltipoverlay then
        return
    end

    local overlayFrame = CreateFrame("FRAME", nil, button)
    overlayFrame:SetFrameLevel(4) -- Azerite overlay must be overlaid itself...
    overlayFrame:SetAllPoints()
    button.appearancetooltipoverlay = overlayFrame

    -- need the sublevel to make sure we're above overlays for e.g. azerite gear
    local background = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    background:SetSize(12, 12)
    background:SetPoint(point or 'BOTTOMLEFT', offsetx or 0, offsety or 0)
    background:SetColorTexture(0, 0, 0, 0.4)

    button.appearancetooltipoverlay.icon = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    button.appearancetooltipoverlay.icon:SetSize(16, 16)
    button.appearancetooltipoverlay.icon:SetPoint("CENTER", background, "CENTER")
    button.appearancetooltipoverlay.icon:SetAtlas("transmog-icon-hidden")

    overlayFrame:Hide()
end
local function UpdateOverlay(button, link, ...)
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
        if appropriateItem then
            if appearanceFromOtherItem then
                -- blue eye
                button.appearancetooltipoverlay.icon:SetVertexColor(0, 1, 1)
            else
                -- regular purple trasmog-eye
                button.appearancetooltipoverlay.icon:SetVertexColor(1, 1, 1)
            end
        else
            -- yellow eye
            button.appearancetooltipoverlay.icon:SetVertexColor(1, 1, 0)
        end
        button.appearancetooltipoverlay:Show()
    end
end

local function UpdateContainerButton(button, bag)
    if button.appearancetooltipoverlay then button.appearancetooltipoverlay:Hide() end
    if not ns.db.bags then
        return
    end
    local slot = button:GetID()
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

hooksecurefunc("ContainerFrame_Update", function(container)
    local bag = container:GetID()
    local name = container:GetName()
    for i = 1, container.size, 1 do
        local button = _G[name .. "Item" .. i]
        UpdateContainerButton(button, bag)
    end
end)

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

-- Encounter Journal frame

local function HookEncounterJournal()
    hooksecurefunc("EncounterJournal_SetLootButton", function(item)
        if item.appearancetooltipoverlay then item.appearancetooltipoverlay:Hide() end
        if not ns.db.encounterjournal then return end
        if item.link then
            UpdateOverlay(item, item.link, "TOPLEFT", 4, -4)
        end
    end)
end
if IsAddOnLoaded("Blizzard_EncounterJournal") then
    HookEncounterJournal()
else
    function f:ADDON_LOADED(addon)
        if addon == "Blizzard_EncounterJournal" then
            HookEncounterJournal()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
    f:RegisterEvent("ADDON_LOADED")
end

-- Other addons:

-- Inventorian
local AA = LibStub("AceAddon-3.0", true)
local inv = AA and AA:GetAddon("Inventorian", true)
if inv then
    hooksecurefunc(inv.Item.prototype, "Update", function(self, ...)
        UpdateContainerButton(self, self.bag)
    end)
end

--Baggins:
if Baggins then
    hooksecurefunc(Baggins, "UpdateItemButton", function(baggins, bagframe, button, bag, slot)
        UpdateContainerButton(button, bag)
    end)
end

--Bagnon:
if Bagnon then
    hooksecurefunc(Bagnon.Item, "Update", function(frame)
        local bag = frame:GetBag()
        UpdateContainerButton(frame, bag)
    end)
end
