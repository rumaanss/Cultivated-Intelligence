--!strict
-- Cosmetic rendering only. Never changes C++ biology, body radius or picking.
return table.freeze({
 Enabled=true,
 MaximumDetailedAgents=448,
 MaximumNativeParts=6272, -- All 384 visible agents plus the 64-agent birth margin.
 DetailDistance=120,
 ReleaseDistance=140, -- Hysteresis avoids repeated allocate/release at the boundary.
 SelectionHz=4,
 PoseHz=24,
 MinimumProjectedRadiusPixels=1,
 SpeciesDesigns={"Cyanobacteria","Bacterivore","BodoSaltans"},
 -- Scale is derived from the authoritative marker radius. No visual enlargement.
})
