local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight

local setDefaults, db

local LAT = LibStub("LibArmorToken-1.0", true)
local LAI = LibStub("LibAppropriateItems-1.0")

-- minor compat:
local IsDressableItem = _G.IsDressableItem or C_Item.IsDressableItemByID
local issecretvalue = _G.issecretvalue or function() return false end
local isanyvaluesecret = function(...)
    for i=1, select("#", ...) do
        if issecretvalue((select(i, ...))) then
            return true
        end
    end
    return false
end
local issecretframe = function(frame, aspect)
    if frame.IsAnchoringSecret then
        if aspect then
            return frame:HasSecretAspect(aspect)
        end
        return frame:IsAnchoringSecret()
    end
    return false
end

local function PlayerHasTransmogByItemInfo(itemLinkOrID)
    -- Cata classic is specifically missing C_TransmogCollection.PlayerHasTransmogByItemInfo
    if C_TransmogCollection.PlayerHasTransmogByItemInfo then
        return C_TransmogCollection.PlayerHasTransmogByItemInfo(itemLinkOrID)
    end
    local itemID = C_Item.GetItemInfoInstant(itemLinkOrID)
    if itemID then
        -- this is a bit worse, because of items with varying appearances based on the link-details
        -- but because this path should only be hit in classic, we should be fine
        return C_TransmogCollection.PlayerHasTransmog(itemID)
    end
end

ns.CLASSIC = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE -- rolls forward
ns.CLASSICERA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC -- forever vanilla

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
        dressed_ensemble = false, -- as above, but specifically for ensembles
        uncover = true, -- remove clothing to expose the previewed item
        customModel = false, -- use a model other than your current class, and if so:
        modelRace = 7, -- raceid (1:human)
        modelGender = 1, -- 0:male, 1:female
        notifyKnown = true, -- show text explaining the transmog state of the item previewed
        currentClass = false, -- only show for items the current class can transmog
        anchor = "vertical", -- vertical / horizontal
        byComparison = true, -- whether to show by the comparison, or fall back to vertical if needed
        tokens = true, -- try to preview tokens?
        learnable = true, -- show for other learnable items (toys, mounts, pets)
        bags = true,
        bags_unbound = ns.CLASSIC,
        merchant = true,
        loot = true,
        encounterjournal = true,
        setjournal = true,
        alerts = true,
    })
    db = _G[myname.."DB"]
    ns.db = db

    -- Dressing up custom models is broken currently, so force-disable this. Test it occasionally to see if it gets fixed.
    db.customModel = false

    self:UnregisterEvent("ADDON_LOADED")
end

function tooltip:PLAYER_LOGIN()
    for _, model in pairs(tooltip.models) do
        if model.SetUnit then
            model:SetUnit("player")
        end
    end
    C_CVar.SetCVar("missingTransmogSourceInItemTooltips", "1")
end

local function scrollActiveModel(amount)
    if not (tooltip.activeModel and tooltip.activeModel:IsVisible()) then
        return
    end
    if tooltip.activeModel.GetActiveCamera then
        local camera = tooltip.activeModel:GetActiveCamera()
        local mode = ORBIT_CAMERA_MOUSE_MODE_YAW_ROTATION
        local snapToValue = false
        camera:HandleMouseMovement(mode, amount, snapToValue)
    else
        tooltip.activeModel:SetFacing(tooltip.activeModel:GetFacing() + amount)
    end
    return true
end

do
    local scrollup = CreateFrame("Button", "AppearanceTooltipScrollUpButton", tooltip)
    scrollup:SetScript("OnClick", function(self, button, down)
        scrollActiveModel(0.3)
    end)
    scrollup:RegisterForClicks("AnyDown", "AnyUp")
    local scrolldown = CreateFrame("Button", "AppearanceTooltipScrollDownButton", tooltip)
    scrolldown:SetScript("OnClick", function(self, button, down)
        scrollActiveModel(-0.3)
    end)

    local function ClearBindings()
        if InCombatLockdown() then return end
        ClearOverrideBindings(tooltip)
    end

    function tooltip:UpdateMouseBinding(event, unit)
        if InCombatLockdown() then return end
        if db.mousescroll and (event ~= "PLAYER_REGEN_DISABLED") and tooltip:IsVisible() then
            SetOverrideBindingClick(tooltip, true, "MOUSEWHEELUP", scrollup:GetName())
            SetOverrideBindingClick(tooltip, true, "MOUSEWHEELDOWN", scrolldown:GetName())
        else
            ClearOverrideBindings(tooltip)
        end
    end

    local frame = CreateFrame("Frame", nil, tooltip)
    frame:SetScript("OnShow", tooltip.UpdateMouseBinding)
    frame:SetScript("OnHide", ClearBindings)

    frame:SetScript("OnEvent", tooltip.UpdateMouseBinding)
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
end

do
    local function makeModel(frameType, template)
        local model = CreateFrame(frameType, nil, tooltip, template)
        return model
    end
    local function makeDressUpModel()
        local model = makeModel("DressUpModel")
        model:SetKeepModelOnHide(true)
        model:SetScript("OnModelLoaded", function(self, ...)
            -- Makes sure the zoomed camera is correct, if the model isn't loaded right away
            if self.cameraID then
                Model_ApplyUICamera(self, self.cameraID)
            end
        end)
        return model
    end
    local function makeModelScene()
        return makeModel("ModelScene", "NoCameraControlModelSceneMixinTemplate")
    end
    tooltip.models = {
        FullBody = makeDressUpModel(),
        Zoomed = makeDressUpModel(),
        Weapon = makeDressUpModel(),
        Mount = makeModelScene(),
        Pet = makeModelScene(),
        Decor = makeModelScene(),
    }
end

local modelLabel = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
modelLabel:SetWordWrap(true)
modelLabel:SetTextColor(0.5333, 0.6666, 0.9999, 0.9999)
modelLabel:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 6, 12)
modelLabel:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -6, 12)
modelLabel:Show()

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
    local function OnTooltipSetItem(self)
        local name, link, id = self:GetItem()
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
                local link = data.guid and C_Item.GetItemLinkByGUID(data.guid) or data.hyperlink
                ns:ShowItem(link, self)
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

    local anchor, owner, our_point, owner_point = ns:ComputeTooltipAnchors(tooltip.owner, db.anchor)
    tooltip:ClearAllPoints()
    if our_point and owner_point then
        tooltip:SetPoint(our_point, owner, owner_point)
        --[[
        -- TODO: this scales the tooltip to match its owner, but the model scale gets weird when this happens...
        if anchor == "vertical" then
            local ownerWidth = owner:GetWidth()
            if not issecretvalue(ownerWidth) then
                tooltip:SetScale(ownerWidth / tooltip:GetWidth())
            end
        else
            local ownerHeight = owner:GetHeight()
            if not issecretvalue(ownerHeight) then
                tooltip:SetScale(ownerHeight / tooltip:GetHeight())
            end
        end
        --]]
    else
        -- TODO: could fall back somewhere instead?
        -- tooltip:SetPoint("CENTER", UIParent)
        tooltip:Hide()
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
    local safecenterscale = function(frame)
        local scale = frame:GetEffectiveScale()
        local x, y = frame:GetCenter()
        if isanyvaluesecret(x, y) then
            return
        end
        if issecretvalue(scale) then
            return x, y
        end
        return x * scale, y * scale
    end
    function ns:ComputeTooltipAnchors(owner, anchor)
        -- Because I always forget: x is left-right, y is bottom-top
        -- Logic here: our tooltip should trend towards the center of the screen, unless something is stopping it.
        -- If comparison tooltips are shown, we shouldn't overlap them
        local originalOwner = owner
        local x, y = owner:GetCenter()
        if not (x and y) or isanyvaluesecret(x, y) or issecretframe(owner) then
            return
        end
        local ownerScale = owner:GetEffectiveScale()
        if not issecretvalue(ownerScale) then
            x = x * ownerScale
        end
        -- the y comparison doesn't need this:
        -- y = y * owner:GetEffectiveScale()

        local biasLeft, biasDown
        -- we want to follow the direction the tooltip is going, relative to the cursor
        -- print("biasLeft check", x ,"<", GetCursorPosition())
        -- print("biasDown check", y, ">", GetScreenHeight() / 2)
        local cursorX = GetCursorPosition()
        local screenHeight = GetScreenHeight()
        if isanyvaluesecret(cursorX, screenHeight) then
            return
        end
        biasLeft = x < cursorX
        biasDown = y > screenHeight / 2

        local outermostComparisonShown
        if owner.shoppingTooltips then
            local comparisonTooltip1, comparisonTooltip2 = unpack( owner.shoppingTooltips )
            if comparisonTooltip1:IsShown() or comparisonTooltip2:IsShown() then
                if comparisonTooltip1:IsShown() and comparisonTooltip2:IsShown() then
                    local c1x, c2x = comparisonTooltip1:GetCenter(), comparisonTooltip2:GetCenter()
                    if isanyvaluesecret(c1x, c2x) then
                        outermostComparisonShown = nil
                    elseif c1x > c2x then
                        -- 1 is right of 2
                        outermostComparisonShown = biasLeft and comparisonTooltip2 or comparisonTooltip1
                    else
                        -- 1 is left of 2
                        outermostComparisonShown = biasLeft and comparisonTooltip1 or comparisonTooltip2
                    end
                else
                    outermostComparisonShown = comparisonTooltip1:IsShown() and comparisonTooltip1 or comparisonTooltip2
                end
                if outermostComparisonShown then
                    local outerx = safecenterscale(outermostComparisonShown)
                    local ownerx = safecenterscale(owner)
                    if not (outerx and ownerx) then
                        anchor = "vertical"
                    elseif
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
        if anchor ~= "vertical" then
            local ownerLeft, ownerRight = owner:GetLeft(), owner:GetRight()
            local tooltipWidth = tooltip:GetWidth()
            local screenWidth = GetScreenWidth()
            if not isanyvaluesecret(ownerLeft, ownerRight, tooltipWidth, screenWidth) then
                if
                    (primary == "left" and (ownerLeft - tooltipWidth) < 0)
                    or (primary == "right" and (ownerRight + tooltipWidth > screenWidth))
                then
                    return self:ComputeTooltipAnchors(originalOwner, "vertical")
                end
            end
        end
        -- ns.Debug("ComputeTooltipAnchors", owner:GetName(), primary, secondary)
        return anchor, owner, unpack(points[primary][secondary])
    end
end

local spinner = CreateFrame("Frame", nil, tooltip);
spinner:Hide()
spinner:SetScript("OnUpdate", function(self, elapsed)
    if not scrollActiveModel(elapsed) then
        self:Hide()
    end
end)

local hider = CreateFrame("Frame")
hider:Hide()
local shouldHide = function(owner)
    if not owner then return true end
    if not owner:IsShown() then return true end
    if _G.C_TooltipInfo then
        -- GetDisplayedItem compares this:
        local primaryInfo = owner:GetPrimaryTooltipInfo()
        if issecretvalue(primaryInfo and primaryInfo.tooltipData and primaryInfo.tooltipData.type) then
            return true
        end
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
    if issecretframe(for_tooltip) then
        ns.Debug("Suppressed display because of secret", link, for_tooltip:GetName())
        return
    end
    local id = tonumber(link:match("item:(%d+)"))
    if not id or id == 0 then return end
    local token = db.tokens and LAT and LAT:ItemIsToken(id)

    if token then
        -- It's a set token! Replace the id.
        -- Testing note: the absolute worst-case is Trophy of the Crusade (47242)
        local found
        local counts = {}
        local counts_known = {}
        for itemid, tclass, relevant, variants in LAT:IterateItemsForToken(link) do
            local itemLinkOrID = itemid
            for _, variant in ipairs(variants or {false}) do
                if variant then
                    itemLinkOrID = LAT:GetBareLinkForItem(itemid, variant)
                end
                found = found or itemLinkOrID
                if relevant then
                    found = itemLinkOrID -- make *sure* the item shown is a relevant one, if one exists

                    AddItemToTooltip(itemLinkOrID, for_tooltip, tclass == class and class_colored or tclass)
                else
                    counts[tclass] = (counts[tclass] or 0) + 1
                    counts_known[tclass] = (counts_known[tclass] or 0) + (ns.PlayerHasAppearance(itemLinkOrID) and 1 or 0)
                end
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

    if tooltip.item == id or (db.modifier and not self.modifiers[db.modifier]()) then
        return
    end
    local slot, _, _, classID, subclassID, _, _, setID = select(9, C_Item.GetItemInfo(id))
    tooltip.item = id

    local appropriateItem = LAI:IsAppropriate(id)

    for _, model in pairs(tooltip.models) do
        model:Hide()
    end

    if self.slot_facings[slot] and IsDressableItem(id) and (not db.currentClass or appropriateItem) then
        local model, cameraID
        local isHeld = self.slot_held[slot]
        local shouldZoom = (db.zoomWorn and not isHeld) or (db.zoomHeld and isHeld)
        local dressed = db.dressed
        if slot == "INVTYPE_NON_EQUIP_IGNORE" then
            dressed = db.dressed_ensemble
        end
        local appearanceID = ns.GetTransmogInfo(link)

        if shouldZoom then
            cameraID = appearanceID and C_TransmogCollection.GetAppearanceCameraID(appearanceID)
            -- Classic Era always returns 0, in which case a non-truthy value gets better results:
            if cameraID == 0 then cameraID = nil end
        end

        if cameraID then
            if isHeld then
                model = tooltip.models.Weapon
                self:ResetModel(model)
            else
                model = tooltip.models.Zoomed
                model:SetUseTransmogSkin(db.zoomMasked and slot ~= "INVTYPE_HEAD")
                self:ResetModel(model, dressed)
            end
            model.cameraID = cameraID
            Model_ApplyUICamera(model, cameraID)
            -- ApplyUICamera locks the animation, but...
            model:SetAnimation(0, 0)
        else
            model = tooltip.models.FullBody

            self:ResetModel(model, dressed)
        end
        tooltip.activeModel = model
        model:Show()

        if not cameraID then
            model:SetFacing(self.slot_facings[slot] - (db.rotate and 0.5 or 0))
        end

        self:ShowTooltip(for_tooltip)

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

        -- Finally set the item onto the model
        if isHeld and shouldZoom then
            if appearanceID then
                model:SetItemAppearance(appearanceID)
            else
                model:SetItem(id)
            end
        else
            model:TryOn(link)
        end
    elseif _G.HOUSING_DECOR_OWNED_COUNT_FORMAT and classID == Enum.ItemClass.Housing and subclassID == Enum.ItemHousingSubclass.Decor then
        -- see: Blizzard_HousingModelPreview
        local decorInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(id, true)
        if decorInfo and decorInfo.asset then
            local modelScene = tooltip.models.Decor
            self:ResetModelScene(modelScene)
            local modelSceneID = decorInfo.uiModelSceneID or Constants.HousingCatalogConsts.HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT
            local forceSceneChange = true
            modelScene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, forceSceneChange)
            local actor = modelScene:GetActorByTag("decor");
            if actor then
                actor:SetPreferModelCollisionBounds(true)
                actor:SetModelByFileID(decorInfo.asset)
            end
            modelScene:Show()

            tooltip.activeModel = modelScene

            self:ShowTooltip(for_tooltip)
        end
    elseif C_MountJournal and C_MountJournal.GetMountFromItem and classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
        -- see: DressUpFrames.lua
        local mountID = C_MountJournal.GetMountFromItem(id)
        if mountID then
            local creatureDisplayID, _, _, isSelfMount, _, modelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
            if creatureDisplayID then
                local modelScene = tooltip.models.Mount
                self:ResetModelScene(modelScene)
                modelScene:SetViewInsets(0, 0, 0, 0)
                local forceEvenIfSame = true
                modelScene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, forceEvenIfSame)

                local mountActor = modelScene:GetActorByTag("unwrapped")
                if mountActor then
                    mountActor:SetModelByCreatureDisplayID(creatureDisplayID)
                end
                if (isSelfMount) then
                    mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
                    mountActor:SetAnimation(618) -- MountSelfIdle
                else
                    mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.Anim)
                    mountActor:SetAnimation(0)
                end
                modelScene:AttachPlayerToMount(mountActor, animID, isSelfMount, disablePlayerMountPreview)
                modelScene:Show()

                tooltip.activeModel = modelScene

                self:ShowTooltip(for_tooltip)
            end
        end
    elseif C_PetJournal and C_PetJournal.GetPetInfoByItemID and classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
        -- see: DressUpFrames.lua
        local displayID, petID = select(12, C_PetJournal.GetPetInfoByItemID(id))
        if displayID and petID then
            local modelScene = tooltip.models.Pet
            local _, loadoutModelSceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(petID)
            self:ResetModelScene(modelScene)
            modelScene:SetViewInsets(0, 0, 50, 0)
            modelScene:TransitionToModelSceneID(loadoutModelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)

            local battlePetActor = modelScene:GetActorByTag("pet")
            if battlePetActor then
                battlePetActor:SetModelByCreatureDisplayID(displayID, true)
                battlePetActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
            end

            tooltip.activeModel = modelScene

            modelScene:Show()
            self:ShowTooltip(for_tooltip)
        end
    else
        tooltip:Hide()
    end

    classwarning:Hide()
    modelLabel:Hide()

    local label = {}
    if db.notifyKnown then
        local hasAppearance, appearanceFromOtherItem, probablyEnsemble = ns.PlayerHasAppearance(link)

        if not ns.CanTransmogItem(link) and not probablyEnsemble then
            table.insert(label, "|c00ffff00" .. TRANSMOGRIFY_INVALID_DESTINATION .. "|r")
        else
            if hasAppearance then
                if appearanceFromOtherItem then
                    table.insert(label, "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. (TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN):gsub(', ', ',\n'))
                else
                    table.insert(label, "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN)
                end
            else
                table.insert(label, "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t |cffff0000" .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN .. "|r")
            end
            classwarning:SetShown(not appropriateItem and not probablyEnsemble)
        end
    end
    if token then
        table.insert(label, (string.gsub(link, "[%[%]]", "")))
    end
    if setID then
        local setName = C_Item.GetItemSetInfo(setID)
        if setName then
            table.insert(label, ITEM_SET_BONUS:format(setName))
        end
    end
    if #label > 0 then
        modelLabel:SetText(string.join("\n", unpack(label)))
        modelLabel:Show()
    end
end
function ns:ShowTooltip(for_tooltip)
    tooltip:SetParent(for_tooltip)
    tooltip:Show()
    tooltip.owner = for_tooltip

    positioner:Show()
    spinner:SetShown(db.spin)
end

function ns:HideItem()
    hider:Show()
end

do
    local function ResetModelFrame(frame)
        -- This is mostly in service of avoiding secret-spread
        -- frame:SetToDefaults() -- this would be best, but is too destructive
        frame:SetParent(tooltip)
        frame:SetFrameLevel(tooltip:GetFrameLevel()) -- so the label overlays cover it
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 5, -5)
        frame:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -5, 5)
    end

    function ns:ResetModel(model, dressed)
        ResetModelFrame(model)
        -- Use the blacked-out model:
        -- model:SetUseTransmogSkin(true)
        -- Display in combat pose:
        -- model:FreezeAnimation(1)
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
        model[dressed and "Dress" or "Undress"](model)
    end

    function ns:ResetModelScene(modelScene)
        ResetModelFrame(modelScene)

        modelScene:ClearScene()
        modelScene:SetViewInsets(0, 0, 0, 0)
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
    INVTYPE_NON_EQUIP_IGNORE = {ns.SLOT_TABARD},
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

ns.slot_held = {
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_SHIELD = true,
}

ns.modifiers = {
    Shift = IsShiftKeyDown,
    Ctrl = IsControlKeyDown,
    Alt = IsAltKeyDown,
    None = function() return true end,
}

-- Utility fun

--/dump C_Transmog.CanTransmogItem(C_Item.GetItemInfoInstant(""))
--/dump C_TransmogCollection.GetSourceInfo(select(2, C_TransmogCollection.GetItemInfo("")))
function ns.CanTransmogItem(itemLink)
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID then
        if C_Transmog.CanTransmogItem then
            local canBeChanged, noChangeReason, canBeSource, noSourceReason = C_Transmog.CanTransmogItem(itemID)
            return canBeSource, noSourceReason
        else
            -- Midnight; it *seems* that anything which this function returns
            -- data for is usable as a transmog source now. Checked on
            -- Warglaive of Azzinoth (32837) which returns nil.
            -- 2026/1/23: Apart from Legion artifacts, but they've always been
            -- weird and might be bugged at the moment anyway.
            if ns.GetTransmogInfo(itemLink) then
                return true
            end
            -- sometimes this doesn't return info for valid items, but
            -- anything you have the transmog for *must* be transmoggable...
            if PlayerHasTransmogByItemInfo(itemLink) then
                return true
            end
        end
    end
    return nil, 'NO_ITEM'
end

local brokenItems = {
    -- itemid : {appearanceid, sourceid}
    [253520] = {21670, 298859}, -- Enclave Aspirant's Hatchet
    [153267] = {21670, 90806}, -- Enclave Aspirant's Hatchet
    [153268] = {25124, 90807}, -- Enclave Aspirant's Axe
    [153316] = {25123, 90885}, -- Praetor's Ornamental Edge
}
function ns.GetTransmogInfo(itemLinkOrID)
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLinkOrID)
    if appearanceID then
        return appearanceID, sourceID
    end
    local itemID = C_Item.GetItemInfoInstant(itemLinkOrID)
    if itemID then
        -- sometimes the link won't actually give us an appearance, but itemID will
        -- e.g. mythic Drape of Iron Sutures from Shadowmoon Burial Grounds
        appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID)
        if appearanceID then
            return appearanceID, sourceID
        end
        if brokenItems[itemID] then
            -- ...and there's a few that just need to be hardcoded
            return unpack(brokenItems[itemID])
        end
    end
end
-- /dump C_TransmogCollection.GetAppearanceSourceInfo(select(2, C_TransmogCollection.GetItemInfo("")))
-- /dump C_TransmogCollection.GetAppearanceInfoBySource(select(2, C_TransmogCollection.GetItemInfo("")))
function ns.PlayerHasAppearance(itemLinkOrID)
    -- hasAppearance, appearanceFromOtherItem
    local itemID, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLinkOrID)
    if not itemID then return end
    local probablyEnsemble = IsDressableItem(itemID) and not C_Item.IsEquippableItem(itemID)
    if probablyEnsemble then
        -- TODO: Enum.TooltipDataLineType.LearnTransmogSet  is Coming Soon ("with setID arg")
        -- *not* ERR_COSMETIC_KNOWN which is "Item Known"
        return ns.CheckTooltipFor(itemID, ITEM_SPELL_KNOWN), false, true
    end
    if db.learnable then
        if classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
            if ns.CLASSICERA then return GetItemCount(itemID, true) > 0 end
            local mountID = C_MountJournal and C_MountJournal.GetMountFromItem(itemID)
            return mountID and (select(11, C_MountJournal.GetMountInfoByID(mountID))), false, true
        end
        if C_ToyBox and C_ToyBox.GetToyInfo(itemID)  then
            return PlayerHasToy(itemID), false, true
        end
        if classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
            if ns.CLASSICERA then return GetItemCount(itemID, true) > 0 end
            local petID = C_PetJournal and select(13, C_PetJournal.GetPetInfoByItemID(itemID))
            return petID and C_PetJournal.GetNumCollectedInfo(petID) > 0, false, true
        end
        if _G.HOUSING_DECOR_OWNED_COUNT_FORMAT and classID == Enum.ItemClass.Housing and subclassID == Enum.ItemHousingSubclass.Decor then
            -- not that this should be possible, but:
            if ns.CLASSICERA then return GetItemCount(itemID, true) > 0 end
            local pattern = HOUSING_DECOR_OWNED_COUNT_FORMAT:gsub("([%(%)])", "%%%1"):gsub("%%d", "(%%d+)")
            local info = C_TooltipInfo.GetItemByID(itemID)
            if info then
                for _, line in ipairs(info.lines) do
                    if line.type == Enum.TooltipDataLineType.None and line.leftText and string.match(line.leftText, pattern) then
                        return true, false, true
                    end
                end
            end
            return false, false, true
        end
    end
    local appearanceID, sourceID = ns.GetTransmogInfo(itemLinkOrID)
    if not appearanceID then
        if PlayerHasTransmogByItemInfo(itemLinkOrID) then
            -- avoid more detailed checks if possible; we don't do
            -- this *first* because it sometimes gets it wrong with items
            -- that have variants based on link bonuses
            return true, false
        end
        return
    end
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
