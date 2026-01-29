local myname, ns = ...

local function checkboxGetValue(self) return ns.db[self.key] end
local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
local function checkboxSetValue(self, checked) ns.db[self.key] = checked end
local function checkboxOnClick(self)
    local checked = self:GetChecked()
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    self:SetValue(checked)
end
local function checkboxOnEnter(self)
    if ( self.tooltipText ) then
        GameTooltip:SetOwner(self, self.tooltipOwnerPoint or "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
    end
    if ( self.tooltipRequirement ) then
        GameTooltip:AddLine(self.tooltipRequirement, 1.0, 1.0, 1.0, true)
        GameTooltip:Show()
    end
end

local function newCheckbox(parent, key, label, description, getValue, setValue)
    local check = CreateFrame("CheckButton", "AppearanceTooltipOptionsCheck" .. key, parent, "OptionsBaseCheckButtonTemplate")

    check.key = key
    check.GetValue = getValue or checkboxGetValue
    check.SetValue = setValue or checkboxSetValue
    check:SetScript('OnShow', checkboxSetChecked)
    check:SetScript("OnClick", checkboxOnClick)
    check:SetScript("OnEnter", checkboxOnEnter)
    check:SetScript("OnLeave", GameTooltip_Hide)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
    check.tooltipText = label
    check.tooltipRequirement = description
    return check
end

local function newDropdown(parent, key, description, values)
    local dropdown = CreateFrame("Frame", "AppearanceTooltipOptions" .. key .. "Dropdown", parent, "UIDropDownMenuTemplate")
    dropdown.key = key
    dropdown:HookScript("OnShow", function()
        if not dropdown.initialize then
            UIDropDownMenu_Initialize(dropdown, function(frame)
                for k, v in pairs(values) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = v
                    info.value = k
                    info.func = function(self)
                        ns.db[key] = self.value
                        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            UIDropDownMenu_SetSelectedValue(dropdown, ns.db[key])
        end
    end)
    dropdown:HookScript("OnEnter", function(self)
        if not self.isDisabled then
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(description, nil, nil, nil, nil, true)
        end
    end)
    dropdown:HookScript("OnLeave", GameTooltip_Hide)
    return dropdown
end

local function newFontString(parent, text, template,  ...)
    local label = parent:CreateFontString(nil, nil, template or 'GameFontHighlight')
    label:SetPoint(...)
    label:SetText(text)

    return label
end

local function newBox(parent, title, height)
    local boxBackdrop = {
        bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = true, tileSize = 16,
        edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    }

    local box = CreateFrame('Frame', nil, parent, "BackdropTemplate")
    box:SetBackdrop(boxBackdrop)
    box:SetBackdropBorderColor(.3, .3, .3)
    box:SetBackdropColor(.1, .1, .1, .5)

    box:SetHeight(height)
    box:SetPoint('LEFT', 12, 0)
    box:SetPoint('RIGHT', -12, 0)

    if title then
        box.Title = newFontString(box, title, nil, 'BOTTOMLEFT', box, 'TOPLEFT', 6, 0)
    end

    return box
end

-- and the actual config now

local categoryID

do
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
    local dressed_ensemble = newCheckbox(panel, 'dressed_ensemble', 'Wear your clothes (ensembles)', "As above, but specifically for ensembles")
    local uncover = newCheckbox(panel, 'uncover', 'Uncover previewed item', "Remove clothes that would hide the item you're trying to preview")
    local mousescroll = newCheckbox(panel, 'mousescroll', 'Rotate with mousewheel', "Use the mousewheel to rotate the model in the tooltip")
    local spin = newCheckbox(panel, 'spin', 'Spin model', "Constantly spin the model while it's displayed")
    local notifyKnown = newCheckbox(panel, 'notifyKnown', 'Display transmog information', "Display a label showing whether you know the item appearance already")
    local currentClass = newCheckbox(panel, 'currentClass', 'Current character only', "Only show previews on items that the current character can collect")
    local byComparison = newCheckbox(panel, 'byComparison', 'Show by comparison tooltip', "If the comparison tooltip is shown where the preview would want to be, show next to it (this makes it *much* less likely you'll have the preview overlap your cursor)")
    local tokens = newCheckbox(panel, 'tokens', 'Previews for tokens', "Show previews for the items which various tokens can be turned in for when mousing over the token")
    local alerts = newCheckbox(panel, 'alerts', 'Alert when you learn a new appearance', "Show an alert popup for every new appearance that you learn (like the ones that otherwise only show when you buy something at the Trading Post)")

    local zoomWorn = newCheckbox(panel, 'zoomWorn', 'Zoom on worn items', "Zoom in on the part of your model which wears the item")
    local zoomHeld = newCheckbox(panel, 'zoomHeld', 'Zoom on held items', "Zoom in on the held item being previewed, without seeing your character")
    local zoomMasked = newCheckbox(panel, 'zoomMasked', 'Mask out model while zoomed', "Hide the details of your player model while you're zoomed (like the transmog wardrobe does)")

    if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        -- C_TransmogCollection.GetAppearanceCameraID doesn't return anything useful in Classic Era
        zoomWorn:SetEnabled(false)
        zoomMasked:SetEnabled(false)
    end

    local modifier = newDropdown(panel, 'modifier', "Show preview with modifier key", {
        Alt = "Alt",
        Ctrl = "Ctrl",
        Shift = "Shift",
        None = "None",
    })
    UIDropDownMenu_SetWidth(modifier, 100)

    local anchor = newDropdown(panel, 'anchor', "Side of the tooltip to attach to, depending on where on the screen it's showing", {
        vertical = "top / bottom",
        horizontal = "left / right",
    })
    UIDropDownMenu_SetWidth(anchor, 100)

    -- local modelBox = newBox(panel, "Custom player model", 48)
    -- local customModel = newCheckbox(modelBox, 'customModel', 'Use a different model', "Instead of your current character, use a specific race/gender")
    -- local customRaceDropdown = newDropdown(modelBox, 'modelRace', "Choose your custom race", {
    --     [1] = "Human",
    --     [3] = "Dwarf",
    --     [4] = "Night Elf",
    --     [11] = "Draenei",
    --     [22] = "Worgen",
    --     [7] = "Gnome",
    --     [24] = "Pandaren",
    --     [2] = "Orc",
    --     [5] = "Undead",
    --     [10] = "Blood Elf",
    --     [8] = "Troll",
    --     [6] = "Tauren",
    --     [9] = "Goblin",
    --     -- Allied!
    --     [27] = "Nightborne Elf",
    --     [28] = "Highmountain Tauren",
    --     [29] = "Void Elf",
    --     [30] = "Lightforged Draenei",
    --     [34] = "Dark Iron Dwarf",
    --     [35] = "Vulpera",
    --     [36] = "Mag'har Orc",
    --     [37] = "Mechagnome",

    -- })
    -- UIDropDownMenu_SetWidth(customRaceDropdown, 100)
    -- local customGenderDropdown = newDropdown(modelBox, 'modelGender', "Choose your custom gender", {
    --     [0] = "Male",
    --     [1] = "Female",
    -- })
    -- UIDropDownMenu_SetWidth(customGenderDropdown, 100)

    -- And put them together:

    zoomWorn:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
    zoomHeld:SetPoint("TOPLEFT", zoomWorn, "BOTTOMLEFT", 0, -4)
    zoomMasked:SetPoint("TOPLEFT", zoomHeld, "BOTTOMLEFT", 0, -4)

    dressed:SetPoint("TOPLEFT", zoomMasked, "BOTTOMLEFT", 0, -4)
    dressed_ensemble:SetPoint("TOPLEFT", dressed, "BOTTOMLEFT", 0, -4)
    uncover:SetPoint("TOPLEFT", dressed_ensemble, "BOTTOMLEFT", 0, -4)
    tokens:SetPoint("TOPLEFT", uncover, "BOTTOMLEFT", 0, -4)
    notifyKnown:SetPoint("TOPLEFT", tokens, "BOTTOMLEFT", 0, -4)
    alerts:SetPoint("TOPLEFT", notifyKnown, "BOTTOMLEFT", 0, -4)
    currentClass:SetPoint("TOPLEFT", alerts, "BOTTOMLEFT", 0, -4)
    mousescroll:SetPoint("TOPLEFT", currentClass, "BOTTOMLEFT", 0, -4)
    spin:SetPoint("TOPLEFT", mousescroll, "BOTTOMLEFT", 0, -4)

    local modifierLabel = newFontString(panel, "Show with modifier key:", nil, 'TOPLEFT', spin, 'BOTTOMLEFT', 0, -10)
    modifier:SetPoint("LEFT", modifierLabel, "RIGHT", 4, -2)

    local anchorLabel = newFontString(panel, "Attach to the:", nil, 'TOPLEFT', modifierLabel, 'BOTTOMLEFT', 0, -16)
    anchor:SetPoint("LEFT", anchorLabel, "RIGHT", 4, -2)

    byComparison:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -10)

    -- modelBox:SetPoint("TOP", byComparison, "BOTTOM", 0, -20)
    -- customModel:SetPoint("LEFT", modelBox, 12, 0)
    -- customRaceDropdown:SetPoint("LEFT", customModel.Text, "RIGHT", 12, -2)
    -- customGenderDropdown:SetPoint("TOPLEFT", customRaceDropdown, "TOPRIGHT", 4, 0)

    local category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    Settings.RegisterAddOnCategory(category)
    categoryID = category:GetID()
end

-- Overlay config

do
    local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    panel:Hide()
    panel:SetAllPoints()
    panel.name = "Overlays"
    panel.parent = categoryID

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
    subText:SetText("These options let you control how transmog availability is shown in various places in the UI")

    local bagicon = CreateAtlasMarkup("transmog-icon-hidden")
    local othercharicon = CreateAtlasMarkup("mailbox")

    local show = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    show:SetText(("Show %s icon for unknown items, and %s icon for unknown items you can't learn on this character:"):format(bagicon, othercharicon))

    local bags = newCheckbox(panel, 'bags', 'in bags', ("For items whose appearance you don't know, show the %s icon on the item in bags. Works with built-in bags, Baggins, Bagnon, and Inventorian."):format(bagicon))
    local bags_unbound = newCheckbox(panel, 'bags_unbound', '...for non-soulbound items only', "Soulbound items are either known already, or can't be sent to another character")
    local merchant = newCheckbox(panel, 'merchant', 'at merchants', ("For items whose appearance you don't know, show the %s icon on the item in the merchant frame."):format(bagicon))
    local loot = newCheckbox(panel, 'loot', 'in loot', ("For items whose appearance you don't know, show the %s icon on the item in the loot frame."):format(bagicon))
    local encounterjournal = newCheckbox(panel, 'encounterjournal', 'in Encounter Journal', ("For items whose appearance you don't know, show the %s icon on the item in the loot section of the Encounter Journal."):format(bagicon))
    local setjournal = newCheckbox(panel, 'setjournal', 'in Appearance Sets', ("Show a count of set items known / needed in the sets list"))

    show:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
    bags:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 0, -8)
    bags_unbound:SetPoint("TOPLEFT", bags, "BOTTOMLEFT", 8, -4)
    merchant:SetPoint("TOPLEFT", bags_unbound, "BOTTOMLEFT", -8, -4)
    loot:SetPoint("TOPLEFT", merchant, "BOTTOMLEFT", 0, -4)
    encounterjournal:SetPoint("TOPLEFT", loot, "BOTTOMLEFT", 0, -4)
    setjournal:SetPoint("TOPLEFT", encounterjournal, "BOTTOMLEFT", 0, -4)

    local category = Settings.GetCategory(panel.parent)
    local subcategory, layout = Settings.RegisterCanvasLayoutSubcategory(category, panel, panel.name)
end

-- Slash handler
SlashCmdList.APPEARANCETOOLTIP = function(msg)
    if categoryID then
        Settings.OpenToCategory(categoryID)
    end
end
SLASH_APPEARANCETOOLTIP1 = "/appearancetooltip"
SLASH_APPEARANCETOOLTIP2 = "/aptip"
