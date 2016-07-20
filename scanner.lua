local myname, ns = ...

-- Semlar sourced this

local InventorySlots = {
    ['INVTYPE_HEAD'] = 1,
    ['INVTYPE_NECK'] = 2,
    ['INVTYPE_SHOULDER'] = 3,
    ['INVTYPE_BODY'] = 4,
    ['INVTYPE_CHEST'] = 5,
    ['INVTYPE_ROBE'] = 5,
    ['INVTYPE_WAIST'] = 6,
    ['INVTYPE_LEGS'] = 7,
    ['INVTYPE_FEET'] = 8,
    ['INVTYPE_WRIST'] = 9,
    ['INVTYPE_HAND'] = 10,
    ['INVTYPE_CLOAK'] = 15,
    ['INVTYPE_WEAPON'] = 16,
    ['INVTYPE_SHIELD'] = 17,
    ['INVTYPE_2HWEAPON'] = 16,
    ['INVTYPE_WEAPONMAINHAND'] = 16,
    ['INVTYPE_RANGED'] = 16,
    ['INVTYPE_RANGEDRIGHT'] = 16,
    ['INVTYPE_WEAPONOFFHAND'] = 17,
    ['INVTYPE_HOLDABLE'] = 17,
    -- ['INVTYPE_TABARD'] = 19,
}

do
    local model = CreateFrame('DressUpModel')
    local sourceIDs = setmetatable({}, {__index = function(self, itemLink)
        local itemID, _, _, slotName = GetItemInfoInstant(itemLink)
        local slot = InventorySlots[slotName]
        if not slot or not IsDressableItem(itemID) then
            return
        end

        model:SetUnit('player')
        model:Undress()
        model:TryOn(itemLink, slot)
        local sourceID = model:GetSlotTransmogSources(slot)
        self[itemLink] = sourceID
        return sourceID
    end})
    function ns.GetItemAppearance(itemLink)
        local sourceID = sourceIDs[itemLink]
        if sourceID then
            local categoryID, appearanceID, canEnchant, texture, isCollected, itemLink = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
            return appearanceID, isCollected, sourceID
        end
    end
end

function ns.PlayerHasAppearance(appearanceID)
    local sources = C_TransmogCollection.GetAppearanceSources(appearanceID)
    if sources then
        for i, source in pairs(sources) do
            if source.isCollected then
                return true
            end
        end
    end
end

function ns.PlayerCanCollectAppearance(appearanceID)
    local sources = C_TransmogCollection.GetAppearanceSources(appearanceID)
    if sources then
        for i, source in pairs(sources) do
            if C_TransmogCollection.PlayerCanCollectSource(source.sourceID) then
                return true
            end
        end
    end
end

function ns.CanTransmogItem(itemLink)
    local itemID = GetItemInfoInstant(itemLink)
    if itemID then
        local canBeChanged, noChangeReason, canBeSource, noSourceReason = C_Transmog.GetItemInfo(itemID)
        return canBeSource, noSourceReason
    end
end
