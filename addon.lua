local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local IsDressableItem = IsDressableItem

local setDefaults, db

local tooltip = CreateFrame("Frame", "AppearanceTooltipTooltip", UIParent, "TooltipBorderedFrameTemplate")
tooltip:SetClampedToScreen(true)
tooltip:SetFrameStrata("TOOLTIP")
tooltip:SetSize(300, 300)
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
        modifier = false, -- or "Alt", "Ctrl", "Shift"
        mousescroll = true,
        rotate = true,
        spin = false,
        -- zoom = false,
        dressed = false, -- whether the model should be wearing your current outfit, or be naked
        customModel = false,
        modelRace = 7, -- raceid (1:human)
        modelGender = 1, -- 0:male, 1:female
        notifyKnown = true,
    })
    db = _G[myname.."DB"]
    ns.db = db

    self:UnregisterEvent("ADDON_LOADED")
end

function tooltip:PLAYER_LOGIN()
    tooltip.model:SetUnit("player")
    C_TransmogCollection.SetShowMissingSourceInItemTooltips(true)
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

tooltip.model = CreateFrame("DressUpModel", nil, tooltip)
tooltip.model:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 5, -5)
tooltip.model:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -5, 5)

tooltip.model:SetScript("OnShow", function(self)
    ns:ResetModel(self)
end)

local known = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium");
known:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 6, 12)
known:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -6, 12)
known:Show()

-- Ye showing:
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    ns:ShowItem(select(2, self:GetItem()))
end)
GameTooltip:HookScript("OnHide", function()
    ns:HideItem()
end)

----

local hider = CreateFrame("Frame")
hider:Hide()
hider:SetScript("OnUpdate", function(self)
    if (tooltip.owner and not (tooltip.owner:IsShown() and tooltip.owner:GetItem())) or not tooltip.owner then
        tooltip:Hide()
        tooltip.item = nil
    end
    self:Hide()
end)

local positioner = CreateFrame("Frame")
positioner:Hide()
positioner:SetScript("OnUpdate", function(self)
    local x, y = tooltip.owner:GetCenter()
    if x and y then
        tooltip:ClearAllPoints()
        local our_point, owner_point
        if y / GetScreenHeight() > 0.5 then
            our_point = "TOP"
            owner_point = "BOTTOM"
        else
            our_point = "BOTTOM"
            owner_point = "TOP"
        end
        if x / GetScreenWidth() > 0.5 and not ShoppingTooltip1:IsVisible() then
            our_point = our_point.."LEFT"
            owner_point = owner_point.."LEFT"
        else
            our_point = our_point.."RIGHT"
            owner_point = owner_point.."RIGHT"
        end
        tooltip:SetPoint(our_point, tooltip.owner, owner_point)
        self:Hide()
    end
end)

local spinner = CreateFrame("Frame", nil, tooltip);
spinner:Hide()
spinner:SetScript("OnUpdate", function(self, elapsed)
    tooltip.model:SetFacing(tooltip.model:GetFacing() + elapsed)
end)

----

function ns:ShowItem(link)
    if not link then return end
    local id = tonumber(link:match("item:(%d+)"))
    if not id or id == 0 then return end

    local slot = select(9, GetItemInfo(id))
    if (not db.modifier or self.modifiers[db.modifier]()) and tooltip.item ~= id then
        tooltip.item = id
        -- TODO: preview from class-set tokens here? Would have to build a list...

        if self.slot_facings[slot] and IsDressableItem(id) then
            tooltip.model:SetFacing(self.slot_facings[slot] - (db.rotate and 0.5 or 0))

            -- TODO: zoom, which is tricky because it depends on race and gender
            -- tooltip.model:SetPosition(unpack(db.zoom and self.slot_positions[slot] or self.slot_positions[DEFAULT]))
            -- tooltip.model:SetModelScale(1)

            tooltip:Show()
            tooltip.owner = GameTooltip

            positioner:Show()
            spinner:SetShown(db.spin)

            self:ResetModel(tooltip.model)
            tooltip.model:TryOn(link)
        else
            tooltip:Hide()
        end

        if db.notifyKnown then
            local hasAppearance, appearanceFromOtherItem = ns.PlayerHasAppearance(link)

            if hasAppearance then
                if appearanceFromOtherItem then
                    known:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN)
                else
                    known:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN)
                end
            else
                known:SetText("|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t |cffff0000" .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN)
            end
            known:Show()
        else
            known:Hide()
        end
    end
end

function ns:HideItem()
    hider:Show()
end

function ns:ResetModel(model)
    if db.customModel then
        model:SetCustomRace(db.modelRace, db.modelGender)
        model:RefreshCamera()
    else
        model:Dress()
    end
    if not db.dressed then
        model:Undress()
    end
end

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
}

-- /script AppearanceTooltipTooltip.model:SetPosition(0,0,0)
-- x,y,z is effectively zoom, horizontal, vertical
ns.slot_positions = {
    INVTYPE_2HWEAPON = {0.8, -0.3, 0},
    INVTYPE_WEAPON = {0.8, -0.3, 0},
    INVTYPE_WEAPONMAINHAND = {0.8, -0.3, 0},
    INVTYPE_WEAPONOFFHAND = {0.8, 0.3, 0},
    INVTYPE_SHIELD = {0.8, 0, 0},
    INVTYPE_HOLDABLE = {0.8, 0.3, 0},
    INVTYPE_RANGED = {0.8, -0.3, 0},
    INVTYPE_RANGEDRIGHT = {0.8, 0.3, 0},
    INVTYPE_THROWN = {0.8, -0.3, 0},
    [DEFAULT] = {0, 0, 0},
}

ns.modifiers = {
    Shift = IsShiftKeyDown,
    Ctrl = IsControlKeyDown,
    Alt = IsAltKeyDown,
}

-- Utility fun

function ns.CanTransmogItem(itemLink)
    local itemID = GetItemInfoInstant(itemLink)
    if itemID then
        local canBeChanged, noChangeReason, canBeSource, noSourceReason = C_Transmog.GetItemInfo(itemID)
        return canBeSource, noSourceReason
    end
end

function ns.PlayerHasAppearance(item)
    if not ns.CanTransmogItem(item) then
        return
    end
    local state = ns.CheckTooltipFor(item, TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN, TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN)
    if state == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN then
        return
    end
    return true, state == TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN
end

do
    local tooltip
    function ns.CheckTooltipFor(link, ...)
        if not tooltip then
            tooltip = CreateFrame("GameTooltip", "AppearanceTooltipScanningTooltip", nil, "GameTooltipTemplate")
            tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        end
        tooltip:ClearLines()

        -- just showing tooltip for an itemid
        -- uses rather innocent checking so that slot can be a link or an itemid
        local link = tostring(link) -- so that ":match" is guaranteed to be okay
        if not link:match("item:") then
            link = "item:"..link
        end
        tooltip:SetHyperlink(link)

        for i=2, tooltip:NumLines() do
            local left = _G["AppearanceTooltipScanningTooltipTextLeft"..i]
            --local right = _G["AppearanceTooltipScanningTooltipTextRight"..i]
            if left and left:IsShown() then
                local text = left:GetText()
                for ii=1, select('#', ...) do
                    if string.match(text, (select(ii, ...))) then
                        return text
                    end
                end
            end
            --if right and right:IsShown() and string.match(right:GetText(), text) then return true end
        end
        return false
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
    return options
end
