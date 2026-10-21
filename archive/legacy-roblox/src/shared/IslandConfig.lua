--!strict
-- Authored from the supplied island map. World origin is the existing pond.
return table.freeze({
 Seed = 731,
 MapScale = 5,
 PondMapX = 108,
 PondMapY = 170,
 Resolution = 4,
 ChunkSize = 64,
 MinX = -576, MaxX = 896,
 MinZ = -512, MaxZ = 448,
 Bottom = -72, Top = 160,
 WaterLevel = 0,
 ProtectedHalfSize = 52, -- Entire existing 100x100 simulation remains untouched.
 TreeBudget = 0,
 RockBudget = 180,
 PlantBudget = 240,
 -- Clockwise shoreline, including the western finger and eastern inlet.
 Outline = {
  {10,91},{25,83},{45,86},{62,99},{71,119},{87,144},
  {95,149},{93,124},{101,105},{116,94},{142,87},{173,83},
  {195,86},{197,98},{188,111},{192,132},{207,133},
  {201,145},{187,152},{187,166},{203,176},{222,177},
  {232,167},{249,170},{259,182},{260,200},{247,218},
  {226,229},{200,231},{177,224},{159,215},{142,208},
  {121,206},{98,199},{82,191},{66,180},{55,166},
  {51,148},{43,131},{35,115},{20,108},{12,102},
 },
})
