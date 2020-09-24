local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local LAI = LibStub("LibAppropriateItems-1.0")

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
        local hasAppearance, appearanceFromOtherItem = ns.PlayerHasAppearance(link)
        local appropriateItem = LAI:IsAppropriate(link)
        -- ns.Debug("Considering item", link, hasAppearance, appearanceFromOtherItem)
        if
            IsDressableItem(link) and
            ns.CanTransmogItem(link) and
            (not ns.db.currentClass or appropriateItem) and
            (not hasAppearance or appearanceFromOtherItem)
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
                -- red eye
                button.appearancetooltipicon:SetVertexColor(1, 0, 0)
            end
            button.appearancetooltipicon:Show()
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
