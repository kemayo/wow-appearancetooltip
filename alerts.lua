local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")


EventRegistry:RegisterFrameEventAndCallback("TRANSMOG_COLLECTION_SOURCE_ADDED", function(_, itemModifiedAppearanceID)
    if not _G.NewCosmeticAlertFrameSystem then
        return
    end
    -- print("TRANSMOG_COLLECTION_SOURCE_ADDED", itemModifiedAppearanceID, C_ContentTracking.IsTracking(Enum.ContentTrackingType.Appearance, itemModifiedAppearanceID))
    if not ns.db.alerts then
        return
    end
    if PerksProgramFrame and PerksProgramFrame:IsShown() then
        -- Trading Post, and core UI handles showing this
        return
    end
    if C_ContentTracking and C_ContentTracking.IsTracking(Enum.ContentTrackingType.Appearance, itemModifiedAppearanceID) then
        -- Boss loot, generally
        -- print("Blocked toast: contenttracking")
        return
    end
    NewCosmeticAlertFrameSystem:AddAlert(itemModifiedAppearanceID)
end, myname)

-- EventRegistry:RegisterFrameEventAndCallback("TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED", function(_, itemModifiedAppearanceID)
--     print("TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED", itemModifiedAppearanceID)
-- end, myname)
