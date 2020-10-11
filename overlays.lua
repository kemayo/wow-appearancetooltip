local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local LAI = LibStub("LibAppropriateItems-1.0")

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if f[event] then return f[event](f, event, ...) end end)

local function PrepareItemButton(button)
    if button.appearancetooltipicon then
        return
    end

    local overlayFrame = CreateFrame("FRAME", nil, button)
    overlayFrame:SetFrameLevel(4) -- Azerite overlay must be overlaid itself...
    overlayFrame:SetAllPoints()

    button.appearancetooltipicon = overlayFrame:CreateTexture(nil, "OVERLAY")
    button.appearancetooltipicon:SetSize(16, 16)
    button.appearancetooltipicon:SetPoint('BOTTOMLEFT', 0, 0)
    -- MiniMap-PositionArrowUp?
    button.appearancetooltipicon:SetAtlas("transmog-icon-hidden")
    button.appearancetooltipicon:Hide()
end
local function UpdateOverlay(button, link)
    local hasAppearance, appearanceFromOtherItem = ns.PlayerHasAppearance(link)
    local appropriateItem = LAI:IsAppropriate(link)
    -- ns.Debug("Considering item", link, hasAppearance, appearanceFromOtherItem)
    if
        (not hasAppearance or appearanceFromOtherItem) and
        (not ns.db.currentClass or appropriateItem) and
        IsDressableItem(link) and
        ns.CanTransmogItem(link)
    then
        PrepareItemButton(button)
        if appropriateItem then
            if appearanceFromOtherItem then
                -- blue eye
                button.appearancetooltipicon:SetVertexColor(0, 1, 1)
            else
                -- regular purple trasmog-eye
                button.appearancetooltipicon:SetVertexColor(1, 1, 1)
            end
        else
            -- yellow eye
            button.appearancetooltipicon:SetVertexColor(1, 1, 0)
        end
        button.appearancetooltipicon:Show()
    end
end

local function UpdateContainerButton(button, bag)
    if button.appearancetooltipicon then button.appearancetooltipicon:Hide() end
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
            if frame.appearancetooltipicon then frame.appearancetooltipicon:Hide() end
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
    if button.appearancetooltipicon then button.appearancetooltipicon:Hide() end
    if not ns.db.loot then return end
    -- ns.Debug("LootFrame_UpdateButton", button:IsEnabled(), button.slot, button.slot and GetLootSlotLink(button.slot))
    if button:IsEnabled() and button.slot then
        local link = GetLootSlotLink(button.slot)
        if link then
            UpdateOverlay(button, link)
        end
    end
end)

-- Other addons:

-- Inventorian
local inv = LibStub("AceAddon-3.0"):GetAddon("Inventorian", true)
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
