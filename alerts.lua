local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

EventRegistry:RegisterFrameEventAndCallback("TRANSMOG_COLLECTION_SOURCE_ADDED", function(_, itemModifiedAppearanceID)
    if not ns.db.alerts then
        return
    end
    if PerksProgramFrame and PerksProgramFrame:IsShown() then
        -- Trading Post, and core UI handles showing this
        return
    end
    NewCosmeticAlertFrameSystem:AddAlert(itemModifiedAppearanceID)
end, myname)
