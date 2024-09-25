local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight

local setDefaults, db

local LAT = LibStub("LibArmorToken-1.0", true)
local LAI = LibStub("LibAppropriateItems-1.0")

-- minor compat:
local IsDressableItem = _G.IsDressableItem or C_Item.IsDressableItemByID

local tooltip = CreateFrame("Frame", "AppearanceTooltipTooltip", UIParent, "TooltipBorderedFrameTemplate")
tooltip:SetClampedToScreen(true)
tooltip:SetFrameStrata("TOOLTIP")
tooltip:SetSize(280, 380)
tooltip:Hide()

tooltip:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)
tooltip:RegisterEvent("ADDON_LOADED")
tooltip:RegisterEvent("PLAYER_LOGIN")
tooltip:RegisterEvent("PLAYER_REGEN_DISABLED")
tooltip:RegisterEvent("PLAYER_REGEN_ENABLED")

function tooltip:ADDON_LOADED(addon)
    if addon ~= myname then return end

    _G[myname.."DB"] = setDefaults(_G[myname.."DB"] or {}, {
        modifier = "None", -- or "Alt", "Ctrl", "Shift"
        mousescroll = true, -- scrolling mouse rotates model
        rotate = true, -- turn the model slightly, so it's not face-on to the camera
        spin = false, -- constantly spin the model
        zoomWorn = true, -- zoom in on the item in question
        zoomHeld = true, -- zoom in on weapons
        zoomMasked = false, -- use the transmog mask while zoomed
        dressed = true, -- whether the model should be wearing your current outfit, or be naked
        uncover = true, -- remove clothing to expose the previewed item
        customModel = false, -- use a model other than your current class, and if so:
        modelRace = 7, -- raceid (1:human)
        modelGender = 1, -- 0:male, 1:female
        notifyKnown = true, -- show text explaining the transmog state of the item previewed
        currentClass = false, -- only show for items the current class can transmog
        anchor = "vertical", -- vertical / horizontal
        byComparison = true, -- whether to show by the comparison, or fall back to vertical if needed
        tokens = true, -- try to preview tokens?
        learnable = true, -- show for other learnable items (toys, mounts)
        bags = true,
        bags_unbound = true,
        merchant = true,
        loot = true,
        encounterjournal = true,
        setjournal = true,
        alerts = true,
        appearances_known = {},
    })
    db = _G[myname.."DB"]
    ns.db = db

    -- Dressing up custom models is broken currently, so force-disable this. Test it occasionally to see if it gets fixed.
    db.customModel = false

    self:UnregisterEvent("ADDON_LOADED")
end

function tooltip:PLAYER_LOGIN()
    tooltip.model:SetUnit("player")
    tooltip.modelZoomed:SetUnit("player")
    C_CVar.SetCVar("missingTransmogSourceInItemTooltips", "1")
end

function tooltip:PLAYER_REGEN_ENABLED()
    if self:IsShown() and db.mousescroll then
        SetOverrideBinding(tooltip, true, "MOUSEWHEELUP", "AppearanceKnown_TooltipScrollUp")
        SetOverrideBinding(tooltip, true, "MOUSEWHEELDOWN", "AppearanceKnown_TooltipScrollDown")
    end
end

function tooltip:PLAYER_REGEN_DISABLED()
    ClearOverrideBindings(tooltip)
end

tooltip:SetScript("OnShow", function(self)
    if db.mousescroll and not InCombatLockdown() then
        SetOverrideBinding(tooltip, true, "MOUSEWHEELUP", "AppearanceKnown_TooltipScrollUp")
        SetOverrideBinding(tooltip, true, "MOUSEWHEELDOWN", "AppearanceKnown_TooltipScrollDown")
    end
end);

tooltip:SetScript("OnHide",function(self)
    if not InCombatLockdown() then
        ClearOverrideBindings(tooltip);
    end
end)

local function makeModel()
    local model = CreateFrame("DressUpModel", nil, tooltip)
    model:SetFrameLevel(1)
    model:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 5, -5)
    model:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -5, 5)
    model:SetKeepModelOnHide(true)
    model:SetScript("OnModelLoaded", function(self, ...)
        -- Makes sure the zoomed camera is correct, if the model isn't loaded right away
        if self.cameraID then
            Model_ApplyUICamera(self, self.cameraID)
        end
    end)
    -- Use the blacked-out model:
    -- model:SetUseTransmogSkin(true)
    -- Display in combat pose:
    -- model:FreezeAnimation(1)
    return model
end
tooltip.model = makeModel()
tooltip.modelZoomed = makeModel()
tooltip.modelWeapon = makeModel()

local known = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
known:SetWordWrap(true)
known:SetTextColor(0.5333, 0.6666, 0.9999, 0.9999)
known:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 6, 12)
known:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -6, 12)
known:Show()

local classwarning = tooltip:CreateFontString(nil, "OVERLAY", "GameFontRed")
classwarning:SetWordWrap(true)
classwarning:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 6, -12)
classwarning:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -6, -12)
-- ITEM_WRONG_CLASS = "That item can't be used by players of your class!"
-- STAT_USELESS_TOOLTIP = "|cff808080Provides no benefit for your class|r"
classwarning:SetText("Your class can't transmogrify this item")
classwarning:Show()

-- Ye showing:
do
    local function GetTooltipItem(tip)
        if _G.C_TooltipInfo then
            return TooltipUtil.GetDisplayedItem(tip)
        end
        return tip:GetItem()
    end
    local function OnTooltipSetItem(self)
        local name, link, id = GetTooltipItem(self)
        ns:ShowItem(link, self)
    end
    local function OnHide(self)
        ns:HideItem()
    end

    local tooltips = {}
    function ns.RegisterTooltip(tip)
        if (not tip) or tooltips[tip] then
            return
        end
        if not _G.C_TooltipInfo then
            tip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
        end
        tip:HookScript("OnHide", OnHide)
        tooltips[tip] = tip
    end

    if _G.C_TooltipInfo then
        -- Cata-classic has TooltipDataProcessor, but doesn't actually use the new tooltips
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(self, data)
            if tooltips[self] then
                OnTooltipSetItem(self)
            end
        end)
    end

    ns.RegisterTooltip(GameTooltip)
    if GameTooltip.ItemTooltip then
        ns.RegisterTooltip(GameTooltip.ItemTooltip.Tooltip)
    end
end

----

local positioner = CreateFrame("Frame")
positioner:Hide()
positioner:SetScript("OnShow", function(self)
    -- always run immediately
    self.elapsed = TOOLTIP_UPDATE_TIME
end)
positioner:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < TOOLTIP_UPDATE_TIME then
        return
    end
    self.elapsed = 0

    local owner, our_point, owner_point = ns:ComputeTooltipAnchors(tooltip.owner, db.anchor)
    if our_point and owner_point then
        tooltip:ClearAllPoints()
        tooltip:SetPoint(our_point, owner, owner_point)
    end
end)

do
    local points = {
        -- key is the direction our tooltip should be biased, with the first component being the primary (i.e. "on the top side, to the left")
        -- these are [our point, owner point]
        top = {
            left = {"BOTTOMRIGHT", "TOPRIGHT"},
            right = {"BOTTOMLEFT", "TOPLEFT"},
        },
        bottom = {
            left = {"TOPRIGHT", "BOTTOMRIGHT"},
            right = {"TOPLEFT", "BOTTOMLEFT"},
        },
        left = {
            top = {"BOTTOMRIGHT", "BOTTOMLEFT"},
            bottom = {"TOPRIGHT", "TOPLEFT"},
        },
        right = {
            top = {"BOTTOMLEFT", "BOTTOMRIGHT"},
            bottom = {"TOPLEFT", "TOPRIGHT"},
        },
    }
    function ns:ComputeTooltipAnchors(owner, anchor)
        -- Because I always forget: x is left-right, y is bottom-top
        -- Logic here: our tooltip should trend towards the center of the screen, unless something is stopping it.
        -- If comparison tooltips are shown, we shouldn't overlap them
        local originalOwner = owner
        local x, y = owner:GetCenter()
        if not (x and y) then
            return
        end
        x = x * owner:GetEffectiveScale()
        -- the y comparison doesn't need this:
        -- y = y * owner:GetEffectiveScale()

        local biasLeft, biasDown
        -- we want to follow the direction the tooltip is going, relative to the cursor
        -- print("biasLeft check", x ,"<", GetCursorPosition())
        -- print("biasDown check", y, ">", GetScreenHeight() / 2)
        biasLeft = x < GetCursorPosition()
        biasDown = y > GetScreenHeight() / 2

        local outermostComparisonShown
        if owner.shoppingTooltips then
            local comparisonTooltip1, comparisonTooltip2 = unpack( owner.shoppingTooltips )
            if comparisonTooltip1:IsShown() or comparisonTooltip2:IsShown() then
                if comparisonTooltip1:IsShown() and comparisonTooltip2:IsShown() then
                    if comparisonTooltip1:GetCenter() > comparisonTooltip2:GetCenter() then
                        -- 1 is right of 2
                        outermostComparisonShown = biasLeft and comparisonTooltip2 or comparisonTooltip1
                    else
                        -- 1 is left of 2
                        outermostComparisonShown = biasLeft and comparisonTooltip1 or comparisonTooltip2
                    end
                else
                    outermostComparisonShown = comparisonTooltip1:IsShown() and comparisonTooltip1 or comparisonTooltip2
                end
                local outerx = outermostComparisonShown:GetCenter() * outermostComparisonShown:GetEffectiveScale()
                local ownerx = owner:GetCenter() * owner:GetEffectiveScale()
                if
                    -- outermost is right of owner while we're biasing left
                    (biasLeft and outerx > ownerx)
                    or
                    -- outermost is left of owner while we're biasing right
                    ((not biasLeft) and outerx < ownerx)
                then
                    -- the comparison won't be in the way, so ignore it
                    outermostComparisonShown = nil
                end
            end
        end

        -- print("ApTip bias", biasLeft and "left" or "right", biasDown and "down" or "up")

        local primary, secondary
        if anchor == "vertical" then
            -- attaching to the top/bottom of the tooltip
            -- only care about comparisons to avoid overlapping them
            primary = biasDown and "bottom" or "top"
            if outermostComparisonShown then
                secondary = biasLeft and "right" or "left"
            else
                secondary = biasLeft and "left" or "right"
            end
        else -- horizontal
            primary = biasLeft and "left" or "right"
            secondary = biasDown and "bottom" or "top"
            if outermostComparisonShown then
                if db.byComparison then
                    owner = outermostComparisonShown
                else
                    -- show on the opposite side of the bias, probably overlapping the cursor, since that's better than overlapping the comparison
                    primary = biasLeft and "right" or "left"
                end
            end
        end
        if
            -- would we be pushing against the edge of the screen?
            (primary == "left" and (owner:GetLeft() - tooltip:GetWidth()) < 0)
            or (primary == "right" and (owner:GetRight() + tooltip:GetWidth() > GetScreenWidth()))
        then
            return self:ComputeTooltipAnchors(originalOwner, "vertical")
        end
        -- ns.Debug("ComputeTooltipAnchors", owner:GetName(), primary, secondary)
        return owner, unpack(points[primary][secondary])
    end
end

local spinner = CreateFrame("Frame", nil, tooltip);
spinner:Hide()
spinner:SetScript("OnUpdate", function(self, elapsed)
    if not (tooltip.activeModel and tooltip.activeModel:IsVisible()) then
        return self:Hide()
    end
    tooltip.activeModel:SetFacing(tooltip.activeModel:GetFacing() + elapsed)
end)

local hider = CreateFrame("Frame")
hider:Hide()
local shouldHide = function(owner)
    if not owner then return true end
    if not owner:IsShown() then return true end
    if _G.C_TooltipInfo then
        if not TooltipUtil.GetDisplayedItem(owner) then return true end
    else
        if not owner:GetItem() then return true end
    end
    return false
end
hider:SetScript("OnUpdate", function(self)
    if shouldHide(tooltip.owner) then
        spinner:Hide()
        positioner:Hide()
        tooltip:Hide()
        tooltip.item = nil
    end
    self:Hide()
end)

----

local _, class = UnitClass("player")
local class_colored = RAID_CLASS_COLORS[class]:WrapTextInColorCode(class)
local ATLAS_CHECK, ATLAS_CROSS = "common-icon-checkmark", "common-icon-redx"

local function AddItemToTooltip(itemInfo, for_tooltip, label)
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemInfo)
    if name then
        if ns.CanTransmogItem(link) then
            name = name .. CreateAtlasMarkup(ns.PlayerHasAppearance(link) and ATLAS_CHECK or ATLAS_CROSS)
        end
        for_tooltip:AddDoubleLine(
            label or ITEM_PURCHASED_COLON,
            "|T" .. icon .. ":0|t " .. name,
            1, 1, 0,
            C_Item.GetItemQualityColor(quality)
        )
    else
        for_tooltip:AddDoubleLine(ITEM_PURCHASED_COLON, SEARCH_LOADING_TEXT, 1, 1, 0, 0, 1, 1)
    end
end
function ns:ShowItem(link, for_tooltip)
    if not link then return end
    for_tooltip = for_tooltip or GameTooltip
    local id = tonumber(link:match("item:(%d+)"))
    if not id or id == 0 then return end
    local token = db.tokens and LAT and LAT:ItemIsToken(id)

    if token then
        -- It's a set token! Replace the id.
        -- Testing note: the absolute worst-case is Trophy of the Crusade (47242)
        local found
        local counts = {}
        local counts_known = {}
        for itemid, tclass, relevant in LAT:IterateItemsForToken(id) do
            found = found or itemid
            if relevant then
                AddItemToTooltip(itemid, for_tooltip, tclass == class and class_colored or tclass)
            else
                counts[tclass] = (counts[tclass] or 0) + 1
                counts_known[tclass] = (counts_known[tclass] or 0) + (ns.PlayerHasAppearance(itemid) and 1 or 0)
            end
        end
        for tclass, count in pairs(counts) do
            -- ITEM_PET_KNOWN = "Collected (%d/%d)"
            local label = RAID_CLASS_COLORS[tclass] and RAID_CLASS_COLORS[tclass]:WrapTextInColorCode(tclass) or tclass
            local complete = counts_known[tclass] == counts[tclass]
            for_tooltip:AddDoubleLine(label, ITEM_PET_KNOWN:format(counts_known[tclass], counts[tclass]),
                1, 1, 1,
                complete and 0 or 1, complete and 1 or 0, 0
            )
        end
        if found then
            local _, maybelink = C_Item.GetItemInfo(found)
            if maybelink then
                link = maybelink
                id = found
            end
            for_tooltip:Show()
        end
    end

    local slot = select(9, C_Item.GetItemInfo(id))
    if (not db.modifier or self.modifiers[db.modifier]()) and tooltip.item ~= id then
        tooltip.item = id

        local appropriateItem = LAI:IsAppropriate(id)

        if self.slot_facings[slot] and IsDressableItem(id) and (not db.currentClass or appropriateItem) then
            local model
            local cameraID, itemCamera
            if db.zoomWorn or db.zoomHeld then
                cameraID, itemCamera = self:GetCameraID(id, db.customModel and db.modelRace, db.customModel and db.modelGender)
            end

            tooltip.model:Hide()
            tooltip.modelZoomed:Hide()
            tooltip.modelWeapon:Hide()

            local shouldZoom = (db.zoomHeld and cameraID and itemCamera) or (db.zoomWorn and cameraID and not itemCamera)

            if shouldZoom then
                if itemCamera then
                    model = tooltip.modelWeapon
                    local appearanceID = C_TransmogCollection.GetItemInfo(link)
                    if appearanceID then
                        model:SetItemAppearance(appearanceID)
                    else
                        model:SetItem(id)
                    end
                else
                    model = tooltip.modelZoomed
                    model:SetUseTransmogSkin(db.zoomMasked and slot ~= "INVTYPE_HEAD")
                    self:ResetModel(model)
                end
                model.cameraID = cameraID
                Model_ApplyUICamera(model, cameraID)
                -- ApplyUICamera locks the animation, but...
                model:SetAnimation(0, 0)
            else
                model = tooltip.model

                self:ResetModel(model)
            end
            tooltip.activeModel = model
            model:Show()

            if not cameraID then
                model:SetFacing(self.slot_facings[slot] - (db.rotate and 0.5 or 0))
            end

            tooltip:SetParent(for_tooltip)
            tooltip:Show()
            tooltip.owner = for_tooltip

            positioner:Show()
            spinner:SetShown(db.spin)

            if ns.slot_removals[slot] and (ns.always_remove[slot] or db.uncover) then
                -- 1. If this is a weapon, force-remove the item in the main-hand slot! Otherwise it'll get dressed into the
                --    off-hand, maybe, depending on things which are more hassle than it's worth to work out.
                -- 2. Other slots will be entirely covered, making for a useless preview. e.g. shirts.
                for _, slotid in ipairs(ns.slot_removals[slot]) do
                    if slotid == ns.SLOT_ROBE then
                        local chest_itemid = GetInventoryItemID("player", ns.SLOT_CHEST)
                        if chest_itemid and select(4, C_Item.GetItemInfoInstant(chest_itemid)) == 'INVTYPE_ROBE' then
                            slotid = ns.SLOT_CHEST
                        end
                    end
                    if slotid > 0 then
                        model:UndressSlot(slotid)
                    end
                end
            end
            C_Timer.After(0, function()
                model:TryOn(link)
            end)
        else
            tooltip:Hide()
        end

        classwarning:Hide()
        known:Hide()

        if db.notifyKnown then
            local hasAppearance, appearanceFromOtherItem, probablyEnsemble = ns.PlayerHasAppearance(link)

            local label
            if not ns.CanTransmogItem(link) and not probablyEnsemble then
                label = "|c00ffff00" .. TRANSMOGRIFY_INVALID_DESTINATION
            else
                if hasAppearance then
                    if appearanceFromOtherItem then
                        label = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. (TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN):gsub(', ', ',\n')
                    else
                        label = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN
                    end
                else
                    label = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t |cffff0000" .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN
                end
                classwarning:SetShown(not appropriateItem and not probablyEnsemble)
            end
            known:SetText(label)
            known:Show()
        end
    end
end

function ns:HideItem()
    hider:Show()
end

function ns:ResetModel(model)
    -- This sort of works, but with a custom model it keeps some items (shoulders, belt...)
    -- model:SetAutoDress(db.dressed)
    -- So instead, more complicated:
    if db.customModel then
        model:SetUnit("none")
        model:SetCustomRace(db.modelRace, db.modelGender)
    else
        model:SetUnit("player")
    end
    model:RefreshCamera()
    if db.dressed then
        model:Dress()
    else
        model:Undress()
    end
end

ns.SLOT_MAINHAND = GetInventorySlotInfo("MainHandSlot")
ns.SLOT_OFFHAND = GetInventorySlotInfo("SecondaryHandSlot")
ns.SLOT_TABARD = GetInventorySlotInfo("TabardSlot")
ns.SLOT_CHEST = GetInventorySlotInfo("ChestSlot")
ns.SLOT_SHIRT = GetInventorySlotInfo("ShirtSlot")
ns.SLOT_HANDS = GetInventorySlotInfo("HandsSlot")
ns.SLOT_WAIST = GetInventorySlotInfo("WaistSlot")
ns.SLOT_SHOULDER = GetInventorySlotInfo("ShoulderSlot")
ns.SLOT_FEET = GetInventorySlotInfo("FeetSlot")
ns.SLOT_ROBE = -99 -- Magic!

ns.slot_removals = {
    INVTYPE_WEAPON = {ns.SLOT_MAINHAND},
    INVTYPE_2HWEAPON = {ns.SLOT_MAINHAND},
    INVTYPE_BODY = {ns.SLOT_TABARD, ns.SLOT_CHEST, ns.SLOT_SHOULDER, ns.SLOT_OFFHAND, ns.SLOT_WAIST},
    INVTYPE_CHEST = {ns.SLOT_TABARD, ns.SLOT_OFFHAND, ns.SLOT_WAIST, ns.SLOT_SHIRT},
    INVTYPE_ROBE = {ns.SLOT_TABARD, ns.SLOT_WAIST, ns.SLOT_SHOULDER, ns.SLOT_OFFHAND},
    INVTYPE_LEGS = {ns.SLOT_TABARD, ns.SLOT_WAIST, ns.SLOT_FEET, ns.SLOT_ROBE, ns.SLOT_MAINHAND, ns.SLOT_OFFHAND},
    INVTYPE_WAIST = {ns.SLOT_MAINHAND, ns.SLOT_OFFHAND},
    INVTYPE_FEET = {ns.SLOT_ROBE},
    INVTYPE_WRIST = {ns.SLOT_HANDS, ns.SLOT_CHEST, ns.SLOT_ROBE, ns.SLOT_SHIRT, ns.SLOT_OFFHAND},
    INVTYPE_HAND = {ns.SLOT_OFFHAND},
    INVTYPE_TABARD = {ns.SLOT_WAIST, ns.SLOT_OFFHAND},
    INVTYPE_HEAD = {ns.SLOT_SHOULDER},
}
ns.always_remove = {
    INVTYPE_WEAPON = true,
    INVTYPE_2HWEAPON = true,
}

ns.slot_facings = {
    INVTYPE_HEAD = 0,
    INVTYPE_SHOULDER = 0,
    INVTYPE_CLOAK = 3.4,
    INVTYPE_CHEST = 0,
    INVTYPE_ROBE = 0,
    INVTYPE_WRIST = 0,
    INVTYPE_2HWEAPON = 1.6,
    INVTYPE_WEAPON = 1.6,
    INVTYPE_WEAPONMAINHAND = 1.6,
    INVTYPE_WEAPONOFFHAND = -0.7,
    INVTYPE_SHIELD = -0.7,
    INVTYPE_HOLDABLE = -0.7,
    INVTYPE_RANGED = 1.6,
    INVTYPE_RANGEDRIGHT = 1.6,
    INVTYPE_THROWN = 1.6,
    INVTYPE_HAND = 0,
    INVTYPE_WAIST = 0,
    INVTYPE_LEGS = 0,
    INVTYPE_FEET = 0,
    INVTYPE_TABARD = 0,
    INVTYPE_BODY = 0,
    -- for ensembles, which are dressable but non-equipable
    INVTYPE_NON_EQUIP_IGNORE = 0,
}

ns.modifiers = {
    Shift = IsShiftKeyDown,
    Ctrl = IsControlKeyDown,
    Alt = IsAltKeyDown,
    None = function() return true end,
}

-- Utility fun

--/dump C_Transmog.GetItemInfo(C_Item.GetItemInfoInstant(""))
function ns.CanTransmogItem(itemLink)
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID then
        local canBeChanged, noChangeReason, canBeSource, noSourceReason = C_Transmog.CanTransmogItem(itemID)
        return canBeSource, noSourceReason
    end
end

local brokenItems = {
    -- itemid : {appearanceid, sourceid}
    [153268] = {25124, 90807}, -- Enclave Aspirant's Axe
    [153316] = {25123, 90885}, -- Praetor's Ornamental Edge
}
-- /dump C_TransmogCollection.GetAppearanceSourceInfo(select(2, C_TransmogCollection.GetItemInfo("")))
-- /dump C_TransmogCollection.GetAppearanceInfoBySource(select(2, C_TransmogCollection.GetItemInfo("")))
function ns.PlayerHasAppearance(itemLinkOrID)
    -- hasAppearance, appearanceFromOtherItem
    local itemID, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLinkOrID)
    if not itemID then return end
    local probablyEnsemble = IsDressableItem(itemID) and not C_Item.IsEquippableItem(itemID)
    if probablyEnsemble then
        -- *not* ERR_COSMETIC_KNOWN which is "Item Known"
        return ns.CheckTooltipFor(itemID, ITEM_SPELL_KNOWN), false, true
    end
    if db.learnable then
        if C_MountJournal and classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
            local mountID = C_MountJournal.GetMountFromItem(itemID)
            return mountID and (select(11, C_MountJournal.GetMountInfoByID(mountID))), false, true
        end
        if C_ToyBox and C_ToyBox.GetToyInfo(itemID)  then
            return PlayerHasToy(itemID), false, true
        end
    end
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLinkOrID)
    if not appearanceID then
        -- sometimes the link won't actually give us an appearance, but itemID will
        -- e.g. mythic Drape of Iron Sutures from Shadowmoon Burial Grounds
        appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    end
    if not appearanceID and brokenItems[itemID] then
        -- ...and there's a few that just need to be hardcoded
        appearanceID, sourceID = unpack(brokenItems[itemID])
    end
    if not appearanceID then return end
    -- /dump C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(C_TransmogCollection.GetItemInfo(""))
    local fromCurrentItem = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID)
    if fromCurrentItem then
        -- It might *also* be from another item, but we don't care or need to find out
        return true, false
    end
    -- The current item isn't known, but do we know the appearance in general?
    -- We can't use the direct functions for this, because they don't work
    -- for cross-class items, so we just check all the possible sources. This
    -- used to not work because you couldn't request the sources, but since
    -- Warbands were added in 11.0.0 this is now possible.
    local sources = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
    if sources then
        local known_any = false
        for _, sourceID2 in pairs(sources) do
            if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID2) then
                -- We know it, and it must be from a different source because of the above check
                return true, true
            end
        end
    end
    -- We don't know the appearance from any source
    return false, false
end

function ns.CheckTooltipFor(itemInfo, text)
    if not _G.C_TooltipInfo then return false end
    local info = C_TooltipInfo[ type(itemInfo) == "number" and "GetItemByID" or "GetHyperlink" ](itemInfo)
    if not info then return false end
    for _, line in ipairs(info.lines) do
        -- print("line", line, line.leftText, line.rightText)
        if line.leftText and string.match(line.leftText, text) then
            return true
        end
    end
    return false
end

do
    local function ColorGradient(perc, ...)
        if perc >= 1 then
            local r, g, b = select(select("#", ...) - 2, ...)
            return r, g, b
        elseif perc <= 0 then
            local r, g, b = ...
            return r, g, b
        end

        local num = select("#", ...) / 3

        local segment, relperc = math.modf(perc*(num-1))
        local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

        return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
    end
    local function rgb2hex(r, g, b)
        if type(r) == "table" then
            g = r.g
            b = r.b
            r = r.r
        end
        return ("%02x%02x%02x"):format(r*255, g*255, b*255)
    end
    function ns.ColorTextByCompletion(text, perc)
        return ("|cff%s%s|r"):format(rgb2hex(ColorGradient(perc, 1,0,0, 1,1,0, 0,1,0)), text)
    end
end

function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

local debugf = tekDebug and tekDebug:GetFrame(myname)
function ns.Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

function setDefaults(options, defaults)
    setmetatable(options, { __index = function(t, k)
        if type(defaults[k]) == "table" then
            t[k] = setDefaults({}, defaults[k])
            return t[k]
        end
        return defaults[k]
    end, })
    -- and add defaults to existing tables
    for k, v in pairs(options) do
        if defaults[k] and type(v) == "table" then
            setDefaults(v, defaults[k])
        end
    end
    return options
end
