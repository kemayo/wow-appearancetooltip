local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local LAI = LibStub("LibAppropriateItems-1.0")

-- minor compat:
local IsDressableItem = _G.IsDressableItem or C_Item.IsDressableItemByID
local IsUsableItem = _G.IsUsableItem or C_Item.IsUsableItem

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if f[event] then return f[event](f, ...) end end)
local hooks = {}
function f:RegisterAddonHook(addon, callback)
    if C_AddOns.IsAddOnLoaded(addon) then
        xpcall(callback, geterrorhandler())
    else
        hooks[addon] = callback
    end
end
function f:ADDON_LOADED(addon)
    if hooks[addon] then
        xpcall(hooks[addon], geterrorhandler())
        hooks[addon] = nil
    end
end
f:RegisterEvent("ADDON_LOADED")

function ns:SetIconAppearance(icon, link, hasAppearance, appearanceFromOtherItem, probablyEnsemble)
    if LAI:IsAppropriate(link) or probablyEnsemble then
        -- this character can use it
        icon:SetSize(16, 16)
        icon:SetAtlas("transmog-icon-hidden")
        icon:SetRotation(0)

        icon.background:SetSize(12, 12)

        if appearanceFromOtherItem then
            -- blue eye
            icon:SetVertexColor(0, 1, 1)
        else
            -- regular purple trasmog-eye
            icon:SetVertexColor(1, 1, 1)
        end
    else
        -- mail icon
        icon:SetSize(14, 14)
        icon:SetAtlas("mailbox")
        icon:SetRotation(1.7 * math.pi)
        icon:SetVertexColor(1, 1, 1)
        -- icon:SetVertexColor(0, 1, 1)
    end
end

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

    local icon = overlayFrame:CreateTexture(nil, "OVERLAY", nil, sublevel + 1)
    icon:SetPoint(point or 'BOTTOMLEFT', offsetx or 0, offsety or 0)
    overlayFrame.icon = icon

    local background = overlayFrame:CreateTexture(nil, "OVERLAY", nil, sublevel)
    background:SetPoint("CENTER", icon, "CENTER")
    background:SetColorTexture(0, 0, 0, 0.4)

    local mask = overlayFrame:CreateMaskTexture()
    mask:SetAllPoints(background)
    mask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    background:AddMaskTexture(mask)

    icon.background = background

    overlayFrame:Hide()
end
ns.PrepareItemButton = PrepareItemButton

local function IsRelevantItem(link)
    if not link then return end
    if ns.db.learnable then
        local itemID, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
        if itemID then
            if C_ToyBox and C_ToyBox.GetToyInfo(itemID) then
                return true
            end
            if classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
                -- if C_MountJournal and C_MountJournal.GetMountFromItem(itemID) then
                return true
            end
            if classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
                -- local petID = C_PetJournal and C_PetJournal.GetPetInfoByItemID and select(13, C_PetJournal.GetPetInfoByItemID(itemID))
                -- if petID then
                return true
            end
            if _G.HOUSING_DECOR_OWNED_COUNT_FORMAT and classID == Enum.ItemClass.Housing and subclassID == Enum.ItemHousingSubclass.Decor then
                return true
            end
        end
    end
    return IsDressableItem(link)
end
local function OverlayShouldApplyToItem(link, hasAppearance, appearanceFromOtherItem, probablyEnsemble)
    local appropriateItem = LAI:IsAppropriate(link) or probablyEnsemble
    return (not hasAppearance or appearanceFromOtherItem) and
        (not ns.db.currentClass or appropriateItem) and
        IsRelevantItem(link) and
        (ns.CanTransmogItem(link) or probablyEnsemble)
end
-- Every button we've been asked about, with the last item we saw on it, so the
-- options can be re-applied without waiting for the host UI to redraw.
local overlayState = {}

-- context is the db key gating this part of the UI ("bags", "loot", ...), or
-- nil for callers that are always shown. Pass link as nil for an empty slot;
-- the state is recorded either way so a refresh can bring the overlay back.
local function UpdateOverlay(button, link, context, ...)
    local state = overlayState[button]
    if not state then
        state = {}
        overlayState[button] = state
    end
    state.link, state.context = link, context
    state.point, state.offsetx, state.offsety = ...

    if (not link) or (context and not ns.db[context]) then
        if button.appearancetooltipoverlay then
            button.appearancetooltipoverlay:Hide()
        end
        return false
    end
    local hasAppearance, appearanceFromOtherItem, probablyEnsemble = ns.PlayerHasAppearance(link)
    -- ns.Debug("Considering item", link, hasAppearance, appearanceFromOtherItem, appropriateItem, probablyEnsemble)
    if OverlayShouldApplyToItem(link, hasAppearance, appearanceFromOtherItem, probablyEnsemble) then
        PrepareItemButton(button, state.point, state.offsetx, state.offsety)
        ns:SetIconAppearance(button.appearancetooltipoverlay.icon, link, hasAppearance, appearanceFromOtherItem, probablyEnsemble)
        button.appearancetooltipoverlay:Show()
        return true
    elseif button.appearancetooltipoverlay then
        button.appearancetooltipoverlay:Hide()
    end
    return false
end

function ns.RefreshOverlayFrames()
    for button, state in pairs(overlayState) do
        UpdateOverlay(button, state.link, state.context, state.point, state.offsetx, state.offsety)
    end
end

local function UpdateButtonFromItem(button, item)
    if (not item) or item:IsItemEmpty() then
        UpdateOverlay(button, nil, "bags")
        return
    end
    item:ContinueOnItemLoad(function()
        local link = item:GetItemLink()
        local isBound = item:IsItemInPlayersControl() and C_Item.IsBound(item:GetItemLocation())
        if ns.db.bags_unbound and isBound then
            -- bags_unbound is applied here rather than in UpdateOverlay because
            -- it needs the item location, so toggling it only takes effect as
            -- the bags redraw
            link = nil
        end
        UpdateOverlay(button, link, "bags")
    end)
end
ns.UpdateButtonFromItem = UpdateButtonFromItem

local function UpdateContainerButton(button, bag, slot)
    local item = Item:CreateFromBagAndSlot(bag, slot or button:GetID())
    UpdateButtonFromItem(button, item)
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
    for _, frame in ipairs((ContainerFrameContainer or UIParent).ContainerFrames) do
        hooksecurefunc(frame, "UpdateItems", update)
    end
end

-- Main bank frame, bankbags are covered by containerframe above
if _G.BankFrameItemButton_Update then
    -- pre-11.2.0 bank
    hooksecurefunc("BankFrameItemButton_Update", function(button)
        if not button.isBag then
            UpdateContainerButton(button, -1)
        end
    end)
end

do
    local function hookBankPanel(panel)
        if not panel then return end
        local update = function(frame)
            for itemButton in frame:EnumerateValidItems() do
                UpdateContainerButton(itemButton, itemButton:GetBankTabID(), itemButton:GetContainerSlotID())
            end
        end
        -- Initial load and switching tabs
        hooksecurefunc(panel, "GenerateItemSlotsForSelectedTab", update)
        -- Moving items
        hooksecurefunc(panel, "RefreshAllItemsForSelectedTab", update)
    end
    hookBankPanel(_G.BankPanel) -- added in 11.2.0
    hookBankPanel(_G.AccountBankPanel) -- removed in 11.2.0
end

-- Merchant frame

hooksecurefunc("MerchantFrame_Update", function()
    local limit, infoFunc
    if MerchantFrame.selectedTab == 1 then
        limit = MERCHANT_ITEMS_PER_PAGE
        infoFunc = GetMerchantItemLink
    else
        limit = BUYBACK_ITEMS_PER_PAGE
        infoFunc = GetBuybackItemLink
    end
    for i = 1, limit do
        local frame = _G["MerchantItem"..i.."ItemButton"]
        if frame then
            UpdateOverlay(frame, infoFunc(frame:GetID()), "merchant")
        end
    end
end)

-- Loot frame

if _G.LootFrame_UpdateButton then
    hooksecurefunc("LootFrame_UpdateButton", function(index)
        local button = _G["LootButton"..index]
        if not button then return end
        -- ns.Debug("LootFrame_UpdateButton", button:IsEnabled(), button.slot, button.slot and GetLootSlotLink(button.slot))
        local link
        if button:IsEnabled() and button.slot then
            link = GetLootSlotLink(button.slot)
        end
        UpdateOverlay(button, link, "loot")
    end)
else
    local function handleSlot(frame)
        if not frame.Item then return end
        local data = frame:GetElementData()
        local link = data and data.slotIndex and GetLootSlotLink(data.slotIndex)
        UpdateOverlay(frame.Item, link or nil, "loot")
    end
    LootFrame.ScrollBox:RegisterCallback("OnUpdate", function(...)
        LootFrame.ScrollBox:ForEachFrame(handleSlot)
    end)
end

-- Encounter Journal frame

f:RegisterAddonHook("Blizzard_EncounterJournal", function()
    local function handleSlot(frame)
        local link
        if frame:IsShown() then
            local data = frame:GetElementData()
            local itemInfo = data.index and C_EncounterJournal.GetLootInfoByIndex(data.index)
            -- DevTools_Dump(itemInfo)
            link = itemInfo and itemInfo.link
        end
        UpdateOverlay(frame, link, "encounterjournal", "TOPLEFT", 5, -4)
    end
    EncounterJournal.encounter.info.LootContainer.ScrollBox:RegisterCallback("OnUpdate", function(...)
        EncounterJournal.encounter.info.LootContainer.ScrollBox:ForEachFrame(handleSlot)
    end)
    -- initial load:
    hooksecurefunc("EncounterJournal_LootCallback", function(itemID)
        local scrollBox = EncounterJournal.encounter.info.LootContainer.ScrollBox
        local button = scrollBox:FindFrameByPredicate(function(button)
            return button.itemID == itemID
        end);
        if button then
            handleSlot(button)
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
            -- a set with no primary appearances has no completion to show, and
            -- the 0/0 would divide out to a nan that errors in ColorGradient
            if need > 0 then
                text = text .. ns.ColorTextByCompletion((GENERIC_FRACTION_STRING):format(have, need), have / need) .. separator
            end
        end
        return string.sub(text, 1, -#separator - 1)
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
        -- pre-dragonflight
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
                frame.appearancetooltipoverlay.text:SetText(buildSetText(setID, " "))
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
    hooksecurefunc(Bagnon.Item, "Update", function(button)
        local bag = button:GetBag()
        if type(bag) ~= "number" or button:GetClassName() ~= "BagnonContainerItem" then
            local info = button:GetInfo()
            UpdateButtonFromItem(button, info and info.hyperlink and Item:CreateFromItemLink(info.hyperlink))
            return
        end
        UpdateContainerButton(button, bag)
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
                if slot then
                    UpdateOverlay(slot, GetLootSlotLink(i), "loot", "RIGHT", -6)
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

-- Baganator
f:RegisterAddonHook("Baganator", function()
    Baganator.API.RegisterCornerWidget(myfullname, "appearancetooltip",
        -- onUpdate
        function(cornerFrame, details)
            -- todo: a puchased ensemble will be bound and so won't show here...
            local link = details.itemLink
            if ns.db.bags_unbound and details.isBound then
                link = nil
            end
            return UpdateOverlay(cornerFrame, link, "bags")
        end,
        -- onInit
        function(itemButton)
            local frame = CreateFrame("Frame", nil, itemButton)
            frame:SetSize(12, 12)
            PrepareItemButton(frame, "CENTER", 0, 0)
            return frame
        end,
        {default_position = "bottom_left", priority = 1}
    )
end)
