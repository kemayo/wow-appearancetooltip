local myname, ns = ...

local valid_classes = {
    ALL = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_GENERIC] = true,
            [LE_ITEM_WEAPON_FISHINGPOLE] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_GENERIC] = true, -- includes things like trinkets and rings
            [LE_ITEM_ARMOR_COSMETIC] = true,
        },
    },
    DEATHKNIGHT = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
            [LE_ITEM_WEAPON_AXE2H] = true,
            [LE_ITEM_WEAPON_MACE2H] = true,
            [LE_ITEM_WEAPON_SWORD2H] = true,
            [LE_ITEM_WEAPON_POLEARM] = true,
            -- [LE_ITEM_WEAPON_WARGLAIVE] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_PLATE] = true,
            [LE_ITEM_ARMOR_MAIL] = false,
            [LE_ITEM_ARMOR_LEATHER] = false,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    WARRIOR = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
            [LE_ITEM_WEAPON_AXE2H] = true,
            [LE_ITEM_WEAPON_MACE2H] = true,
            [LE_ITEM_WEAPON_SWORD2H] = true,
            [LE_ITEM_WEAPON_POLEARM] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
            [LE_ITEM_WEAPON_WARGLAIVE] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_SHIELD] = true,
            [LE_ITEM_ARMOR_PLATE] = true,
            [LE_ITEM_ARMOR_MAIL] = false,
            [LE_ITEM_ARMOR_LEATHER] = false,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    PALADIN = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
            [LE_ITEM_WEAPON_AXE2H] = true,
            [LE_ITEM_WEAPON_MACE2H] = true,
            [LE_ITEM_WEAPON_SWORD2H] = true,
            [LE_ITEM_WEAPON_POLEARM] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_SHIELD] = true,
            [LE_ITEM_ARMOR_PLATE] = true,
            [LE_ITEM_ARMOR_MAIL] = false,
            [LE_ITEM_ARMOR_LEATHER] = false,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    HUNTER = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_BOWS] = true,
            [LE_ITEM_WEAPON_CROSSBOW] = true,
            [LE_ITEM_WEAPON_GUNS] = true,
            -- verify the 2h below...
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
            [LE_ITEM_WEAPON_AXE2H] = true,
            [LE_ITEM_WEAPON_MACE2H] = true,
            [LE_ITEM_WEAPON_SWORD2H] = true,
            [LE_ITEM_WEAPON_POLEARM] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_MAIL] = true,
            [LE_ITEM_ARMOR_LEATHER] = false,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    SHAMAN = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
            [LE_ITEM_WEAPON_AXE2H] = true,
            [LE_ITEM_WEAPON_MACE2H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_SHIELD] = true,
            [LE_ITEM_ARMOR_MAIL] = true,
            [LE_ITEM_ARMOR_LEATHER] = false,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    DEMONHUNTER = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_WARGLAIVE] = true,
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_LEATHER] = true,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    ROGUE = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_LEATHER] = true,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    MONK = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_AXE1H] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
            [LE_ITEM_WEAPON_POLEARM] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_LEATHER] = true,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    DRUID = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_UNARMED] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
            [LE_ITEM_WEAPON_POLEARM] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
            [LE_ITEM_WEAPON_MACE2H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_LEATHER] = true,
            [LE_ITEM_ARMOR_CLOTH] = false,
        },
    },
    PRIEST = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_WAND] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
            [LE_ITEM_WEAPON_MACE1H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_CLOTH] = true,
        },
    },
    MAGE = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_WAND] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_CLOTH] = true,
        },
    },
    WARLOCK = {
        [LE_ITEM_CLASS_WEAPON] = {
            [LE_ITEM_WEAPON_DAGGER] = true,
            [LE_ITEM_WEAPON_WAND] = true,
            [LE_ITEM_WEAPON_STAFF] = true,
            [LE_ITEM_WEAPON_SWORD1H] = true,
        },
        [LE_ITEM_CLASS_ARMOR] = {
            [LE_ITEM_ARMOR_CLOTH] = true,
        },
    },

}
local _, class = UnitClass("player")

-- Can the player equip this at all?
function ns.PlayerCanEquipItem(item)
    return ns.ItemIsAppropriateForPlayer(item) ~= nil
end

-- Is the item "appropriate", per transmog rules -- i.e. is it equipable and of the primary armor-type
function ns.ItemIsAppropriateForPlayer(item)
    local slot, _, itemclass, itemsubclass = select(4, GetItemInfoInstant(item))
    if not (class and valid_classes[class] and itemclass and itemsubclass) then
        return
    end
    if valid_classes[class][itemclass] and valid_classes[class][itemclass][itemsubclass] then
        return valid_classes[class][itemclass][itemsubclass]
    end
    if valid_classes.ALL[itemclass] and valid_classes.ALL[itemclass][itemsubclass] then
        return valid_classes.ALL[itemclass][itemsubclass]
    end
    if slot == 'INVTYPE_CLOAK' then
        -- Cloaks are cloth, technically. But everyone can wear them.
        return true
    end
end
-- PlayerCanEquipItem = ns.PlayerCanEquipItem
