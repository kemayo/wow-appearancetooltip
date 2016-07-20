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
        dressed = false, -- whether the model should be wearing your current outfit, or be naked
        customModel = false,
        modelRace = 1, -- raceid (1:human)
        modelGender = 1, -- 0:male, 1:female
    })
    db = _G[myname.."DB"]

    self:UnregisterEvent("ADDON_LOADED")
end

function tooltip:PLAYER_LOGIN()
    tooltip.model:SetUnit("player")
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
        if x / GetScreenWidth() > 0.5 then
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
        -- TODO: preview from class-set tokens here? Would have to build a list

        if self.slot_facings[slot] and IsDressableItem(id) then
            tooltip.model:SetFacing(self.slot_facings[slot] - (db.rotate and 0.5 or 0))

            tooltip:Show()
            tooltip.owner = GameTooltip

            positioner:Show()
            spinner:SetShown(db.spin)

            self:ResetModel(tooltip.model)
            tooltip.model:TryOn(link)
        else
            tooltip:Hide()
        end
    end

    if C_TransmogCollection.PlayerHasTransmog(id) then
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine("|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " .. TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN, 1, 1, 1)
    end
end

function ns:HideItem()
    hider:Show()
end

function ns:ResetModel(model)
    if db.customModel then
        model:SetCustomRace(db.modelRace, db.modelGender)
        -- hack for hidden helm and cloak showing on models
        local showingHelm, showingCloak = ShowingHelm(), ShowingCloak()
        local helm, cloak = GetInventoryItemID("player", INVSLOT_HEAD), GetInventoryItemID("player", INVSLOT_BACK)
        if not showingHelm and helm then
            model:TryOn(helm)
            model:UndressSlot(INVSLOT_HEAD)
        end
        if not showingCloak and cloak then
            model:TryOn(cloak)
            model:UndressSlot(INVSLOT_BACK)
        end
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
}

ns.modifiers = {
    Shift = IsShiftKeyDown,
    Ctrl = IsControlKeyDown,
    Alt = IsAltKeyDown,
}

-- Utility fun

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
