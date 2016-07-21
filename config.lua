local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local function checkboxGetValue(self) return ns.db[self.key] end
local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
local function checkboxSetValue(self, checked) ns.db[self.key] = checked end
local function checkboxOnClick(self)
    local checked = self:GetChecked()
    PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
    self:SetValue(checked)
end

local function newCheckbox(parent, key, label, description, getValue, setValue)
    local check = CreateFrame("CheckButton", "AppearanceTooltipOptionsCheck" .. label, parent, "InterfaceOptionsCheckButtonTemplate")

    check.key = key
    check.GetValue = getValue or checkboxGetValue
    check.SetValue = setValue or checkboxSetValue
    check:SetScript('OnShow', checkboxSetChecked)
    check:SetScript("OnClick", checkboxOnClick)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
    check.tooltipText = label
    check.tooltipRequirement = description
    return check
end

local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
panel:Hide()
panel:SetAllPoints()
panel.name = myname

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(panel.name)

local subText = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
subText:SetMaxLines(3)
subText:SetNonSpaceWrap(true)
subText:SetJustifyV('TOP')
subText:SetJustifyH('LEFT')
subText:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
subText:SetPoint('RIGHT', -32, 0)
subText:SetText("These options let you control how the appearance tooltip is shown")

local dressed = newCheckbox(panel, 'dressed', 'Wear your clothes', "Show the model wearing your current outfit, apart from the previewed item")
local uncover = newCheckbox(panel, 'uncover', 'Uncover previewed item', "Remove clothes that would hide the item you're trying to preview")
local mousescroll = newCheckbox(panel, 'mousescroll', 'Rotate with mousewheel', "Use the mousewheel to rotate the model in the tooltip")
local spin = newCheckbox(panel, 'spin', 'Spin model', "Constantly spin the model while it's displayed")
local notifyKnown = newCheckbox(panel, 'notifyKnown', 'Display known', "Display a label showing whether you know the item appearance already")
local currentClass = newCheckbox(panel, 'currentClass', 'Current character only', "Only show previews on items that the current character can collect")
-- local zoom = newCheckbox(panel, 'zoom', 'Zoom on item', "Zoom in on the item being previewed")
-- local  = newCheckbox(panel, 'customModel', 'Use custom model', "Choose a custom model to use instead of your current character")

dressed:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
uncover:SetPoint("TOPLEFT", dressed, "BOTTOMLEFT", 0, -4)
notifyKnown:SetPoint("TOPLEFT", uncover, "BOTTOMLEFT", 0, -4)
currentClass:SetPoint("TOPLEFT", notifyKnown, "BOTTOMLEFT", 0, -4)
mousescroll:SetPoint("TOPLEFT", currentClass, "BOTTOMLEFT", 0, -4)
spin:SetPoint("TOPLEFT", mousescroll, "BOTTOMLEFT", 0, -4)

InterfaceOptions_AddCategory(panel)

-- Slash handler
SlashCmdList.APPEARANCETOOLTIP = function(msg)
    InterfaceOptionsFrame_OpenToCategory(myname)
    InterfaceOptionsFrame_OpenToCategory(myname)
end
SLASH_APPEARANCETOOLTIP1 = "/appearancetooltip"
SLASH_APPEARANCETOOLTIP2 = "/aptip"
