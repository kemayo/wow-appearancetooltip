std = "lua51"
max_line_length = false
exclude_files = {
    "libs/",
    ".luacheckrc"
}

ignore = {
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "311", -- Value assigned to a local variable is unused
    "512", -- Loop can be executed at most once
    "542", -- empty if branch
}

globals = {
    "SlashCmdList",
    "StaticPopupDialogs",
    "UpdateContainerFrameAnchors",
    "SLASH_APPEARANCETOOLTIP1",
    "SLASH_APPEARANCETOOLTIP2",
}

read_globals = {
    "bit",
    "ceil", "floor",
    "mod",
    "max",
    "table", "tinsert", "wipe", "copy",
    "string", "tostringall", "strtrim", "strmatch",

    -- our own globals

    -- misc custom, third party libraries
    "Baggins", "Bagnon",
    "LibStub", "tekDebug",
    "GetAuctionBuyout",

    -- API functions
    "C_Item",
    "C_Transmog",
    "C_TransmogCollection",
    "hooksecurefunc",
    "BankButtonIDToInvSlotID",
    "ContainerIDToInventoryID",
    "ReagentBankButtonIDToInvSlotID",
    "ClearOverrideBindings",
    "CursorHasItem",
    "DeleteCursorItem",
    "GetAddOnMetadata",
    "GetAuctionItemSubClasses",
    "GetBuildInfo",
    "GetBackpackAutosortDisabled",
    "GetBagSlotFlag",
    "GetBankAutosortDisabled",
    "GetBankBagSlotFlag",
    "GetContainerNumFreeSlots",
    "GetContainerNumSlots",
    "GetContainerItemID",
    "GetContainerItemInfo",
    "GetContainerItemLink",
    "GetCurrentGuildBankTab",
    "GetCursorInfo",
    "GetCursorPosition",
    "GetGuildBankItemInfo",
    "GetGuildBankItemLink",
    "GetGuildBankTabInfo",
    "GetGuildBankNumSlots",
    "GetInventoryItemID",
    "GetInventoryItemLink",
    "GetInventoryItemQuality",
    "GetInventorySlotInfo",
    "GetItemClassInfo",
    "GetItemFamily",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetItemQualityColor",
    "GetScreenHeight",
    "GetScreenWidth",
    "GetTime",
    "HasAlternateForm",
    "InCombatLockdown",
    "IsAddOnLoaded",
    "IsAltKeyDown",
    "IsControlKeyDown",
    "IsDressableItem",
    "IsShiftKeyDown",
    "IsReagentBankUnlocked",
    "Item",
    "PickupContainerItem",
    "PickupGuildBankItem",
    "PlaySound",
    "QueryGuildBankTab",
    "SetOverrideBinding",
    "SplitContainerItem",
    "SplitGuildBankItem",
    "UnitClass",
    "UnitIsAFK",
    "UnitLevel",
    "UnitName",
    "UnitRace",
    "UnitSex",
    "UseContainerItem",

    -- FrameXML frames
    "BankFrame",
    "InspectFrame",
    "MerchantFrame",
    "GameTooltip",
    "UIParent",
    "WorldFrame",
    "DEFAULT_CHAT_FRAME",
    "GameFontHighlightSmall",
    "NumberFontNormal",
    "InterfaceOptionsFramePanelContainer",

    -- FrameXML API
    "CreateAtlasMarkup",
    "CreateFrame",
    "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptions_AddCategory",
    "ToggleDropDownMenu",
    "UIDropDownMenu_AddButton",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_SetSelectedValue",
    "UIDropDownMenu_SetWidth",
    "UISpecialFrames",
    "GameTooltip_Hide",
    "ScrollingEdit_OnCursorChanged",
    "ScrollingEdit_OnUpdate",
    "InspectPaperDollFrame_OnShow",
    "Model_ApplyUICamera",

    -- FrameXML Constants
    "BACKPACK_CONTAINER",
    "BACKPACK_TOOLTIP",
    "BAG_CLEANUP_BAGS",
    "BAG_FILTER_ICONS",
    "BAGSLOT",
    "BAGSLOTTEXT",
    "BANK",
    "BANK_BAG_PURCHASE",
    "BANK_CONTAINER",
    "CONFIRM_BUY_BANK_SLOT",
    "DEFAULT",
    "EQUIP_CONTAINER",
    "INSPECT",
    "INVSLOT_FIRST_EQUIPPED",
    "INVSLOT_LAST_EQUIPPED",
    "ITEM_BIND_QUEST",
    "ITEM_BNETACCOUNTBOUND",
    "ITEM_CONJURED",
    "ITEM_PURCHASED_COLON",
    "ITEM_SOULBOUND",
    "LE_BAG_FILTER_FLAG_EQUIPMENT",
    "LE_BAG_FILTER_FLAG_IGNORE_CLEANUP",
    "LE_ITEM_CLASS_WEAPON",
    "LE_ITEM_CLASS_ARMOR",
    "LE_ITEM_CLASS_CONTAINER",
    "LE_ITEM_CLASS_GEM",
    "LE_ITEM_CLASS_ITEM_ENHANCEMENT",
    "LE_ITEM_CLASS_CONSUMABLE",
    "LE_ITEM_CLASS_GLYPH",
    "LE_ITEM_CLASS_TRADEGOODS",
    "LE_ITEM_CLASS_RECIPE",
    "LE_ITEM_CLASS_BATTLEPET",
    "LE_ITEM_CLASS_QUESTITEM",
    "LE_ITEM_CLASS_MISCELLANEOUS",
    "LE_ITEM_GEM_ARTIFACTRELIC",
    "LE_ITEM_QUALITY_POOR",
    "LE_ITEM_QUALITY_UNCOMMON",
    "LE_ITEM_WEAPON_DAGGER",
    "LE_ITEM_WEAPON_UNARMED",
    "LE_ITEM_WEAPON_AXE1H",
    "LE_ITEM_WEAPON_MACE1H",
    "LE_ITEM_WEAPON_SWORD1H",
    "LE_ITEM_WEAPON_AXE2H",
    "LE_ITEM_WEAPON_MACE2H",
    "LE_ITEM_WEAPON_SWORD2H",
    "LE_ITEM_WEAPON_POLEARM",
    "LE_ITEM_WEAPON_STAFF",
    "LE_ITEM_WEAPON_WARGLAIVE",
    "LE_ITEM_WEAPON_BOWS",
    "LE_ITEM_WEAPON_CROSSBOW",
    "LE_ITEM_WEAPON_GUNS",
    "LE_ITEM_WEAPON_WAND",
    "LE_ITEM_WEAPON_FISHINGPOLE",
    "LE_ITEM_WEAPON_GENERIC",
    "MAX_CONTAINER_ITEMS",
    "MERCHANT_ITEMS_PER_PAGE",
    "NEW_ITEM_ATLAS_BY_QUALITY",
    "NO",
    "NUM_BAG_SLOTS",
    "NUM_BANKBAGSLOTS",
    "NUM_CONTAINER_FRAMES",
    "NUM_LE_BAG_FILTER_FLAGS",
    "ORDER_HALL_EQUIPMENT_SLOTS",
    "RAID_CLASS_COLORS",
    "REAGENT_BANK",
    "REAGENTBANK_CONTAINER",
    "REAGENTBANK_DEPOSIT",
    "REMOVE",
    "SHOW_ITEM_LEVEL",
    "SOUNDKIT",
    "STATICPOPUP_NUMDIALOGS",
    "TEXTURE_ITEM_QUEST_BANG",
    "TEXTURE_ITEM_QUEST_BORDER",
    "TOOLTIP_UPDATE_TIME",
    "TRANSMOGRIFY_INVALID_DESTINATION",
    "TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN",
    "TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN",
    "TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN",
    "UIDROPDOWNMENU_MENU_VALUE",
    "YES",
}
