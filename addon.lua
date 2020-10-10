local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local IsDressableItem = IsDressableItem

local setDefaults, db

local LAT = LibStub("LibArmorToken-1.0")
local LAI = LibStub("LibAppropriateItems-1.0")

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
        bags = true,
        bags_unbound = true,
        merchant = true,
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
    C_TransmogCollection.SetShowMissingSourceInItemTooltips(true)

    ns.UpdateSources()
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

tooltip.model:SetScript("OnShow", function(self)
    -- Initial display will be off-center without this
    ns:ResetModel(self)
end)

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
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    ns:ShowItem(select(2, self:GetItem()))
end)
GameTooltip:HookScript("OnHide", function()
    ns:HideItem()
end)

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
                if
                    -- outermost is right of owner while we're biasing left
                    (biasLeft and outermostComparisonShown:GetCenter() > owner:GetCenter())
                    or
                    -- outermost is left of owner while we're biasing right
                    ((not biasLeft) and outermostComparisonShown:GetCenter() < owner:GetCenter())
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
hider:SetScript("OnUpdate", function(self)
    if (tooltip.owner and not (tooltip.owner:IsShown() and tooltip.owner:GetItem())) or not tooltip.owner then
        spinner:Hide()
        positioner:Hide()
        tooltip:Hide()
        tooltip.item = nil
    end
    self:Hide()
end)

----

local _, class = UnitClass("player")

function ns:ShowItem(link)
    if not link then return end
    local id = tonumber(link:match("item:(%d+)"))
    if not id or id == 0 then return end
    local token = db.tokens and LAT:ItemIsToken(id)
    local maybelink, _

    if token then
        -- It's a set token! Replace the id.
        local found
        for _, itemid in LAT:IterateItemsForTokenAndClass(id, class) do
            _, maybelink = GetItemInfo(itemid)
            if maybelink then
                id = itemid
                link = maybelink
                found = true
                break
            end
        end
        if not found then
            for _, tokenclass in LAT:IterateClassesForToken(id) do
                for _, itemid in LAT:IterateItemsForTokenAndClass(id, tokenclass) do
                    _, maybelink = GetItemInfo(itemid)
                    if maybelink then
                        id = itemid
                        link = maybelink
                        found = true
                        break
                    end
                end
                break
            end
        end
        if found then
            GameTooltip:AddDoubleLine(ITEM_PURCHASED_COLON, link)
            GameTooltip:Show()
        end
    end

    local slot = select(9, GetItemInfo(id))
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

            tooltip:Show()
            tooltip.owner = GameTooltip

            positioner:Show()
            spinner:SetShown(db.spin)

            if ns.slot_removals[slot] and (ns.always_remove[slot] or db.uncover) then
                -- 1. If this is a weapon, force-remove the item in the main-hand slot! Otherwise it'll get dressed into the
                --    off-hand, maybe, depending on things which are more hassle than it's worth to work out.
                -- 2. Other slots will be entirely covered, making for a useless preview. e.g. shirts.
                for _, slotid in ipairs(ns.slot_removals[slot]) do
                    if slotid == ns.SLOT_ROBE then
                        local chest_itemid = GetInventoryItemID("player", ns.SLOT_CHEST)
                        if chest_itemid and select(4, GetItemInfoInstant(chest_itemid)) == 'INVTYPE_ROBE' then
                            slotid = ns.SLOT_CHEST
                        end
                    end
                    if slotid > 0 then
                        model:UndressSlot(slotid)
                    end
                end
            end
            model:TryOn(link)
        else
            tooltip:Hide()
        end

        classwarning:Hide()
        known:Hide()

        if db.notifyKnown then
            local hasAppearance, appearanceFromOtherItem = ns.PlayerHasAppearance(link)

            local label
            if not ns.CanTransmogItem(link) then
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
                classwarning:SetShown(not appropriateItem)
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
        model:Dress()
    end
    model:RefreshCamera()
    if not db.dressed then
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
}

ns.modifiers = {
    Shift = IsShiftKeyDown,
    Ctrl = IsControlKeyDown,
    Alt = IsAltKeyDown,
    None = function() return true end,
}

---

do
    local scanned
    function ns.UpdateSources()
        if scanned then return end
        for categoryID = 1, 28 do
            local categoryAppearances = C_TransmogCollection.GetCategoryAppearances(categoryID)
            for _, categoryAppearance in pairs(categoryAppearances) do
                local appearanceSources = C_TransmogCollection.GetAppearanceSources(categoryAppearance.visualID)
                local known_any
                for _, source in pairs(appearanceSources) do
                    if source.isCollected then
                        -- it's only worth saving if we know the source
                        known_any = true
                    end
                end
                if known_any then
                    ns.db.appearances_known[categoryAppearance.visualID] = true
                else
                    -- cleaning up after unlearned appearances:
                    ns.db.appearances_known[categoryAppearance.visualID] = nil
                end
            end
        end
        scanned = true
    end
end

-- Utility fun

--/dump C_Transmog.GetItemInfo(GetItemInfoInstant(""))
function ns.CanTransmogItem(itemLink)
    local itemID = GetItemInfoInstant(itemLink)
    if itemID then
        local canBeChanged, noChangeReason, canBeSource, noSourceReason = C_Transmog.GetItemInfo(itemID)
        return canBeSource, noSourceReason
    end
end

-- /dump C_TransmogCollection.GetAppearanceSourceInfo(select(2, C_TransmogCollection.GetItemInfo("")))
function ns.PlayerHasAppearance(itemLinkOrID)
    -- hasAppearance, appearanceFromOtherItem
    local itemID = GetItemInfoInstant(itemLinkOrID)
    if not itemID then return end
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLinkOrID)
    if not appearanceID then return end
    if sourceID and ns.db.appearances_known[appearanceID] then
        local _, _, _, _, sourceKnown = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
        return true, not sourceKnown
    end
    -- Everything after this is a fallback. All know appearances *should* be in that table... but we run
    -- this in case, we only know about unequippable items after you've logged in as a class which can use
    -- them. (Also in case the scanning messed up somehow, I guess?)
    if not LAI:IsAppropriate(itemID) then
        -- This is a non-class item, so GetAppearanceSources won't work on it
        -- We can tell whether the specific source is collected, but not the overall appearance
        -- Fallback if you've not logged in to a class that can use this item in a while
        local _, _, _, _, sourceKnown = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
        return sourceKnown, false
    end
    local sources = C_TransmogCollection.GetAppearanceSources(appearanceID)
    if sources then
        local known_any = false
        for _, source in pairs(sources) do
            if source.isCollected == true then
                known_any = true
                if itemID == source.itemID then
                    return true, false
                end
            end
        end
        return known_any, false
    end
    return false
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
    return options
end
