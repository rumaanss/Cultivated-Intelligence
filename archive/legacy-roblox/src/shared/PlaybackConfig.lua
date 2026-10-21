--!strict
return table.freeze({
 Enabled = true,
 StartPaused = true, -- Inspect the first authoritative frame before pressing Play.
 TicksPerSecond = 30, -- Viewer speed only, NOT physical seconds per simulation tick.
 MaximumVisibleOrganisms = 1500,
 RenderUpdateHz = 30,
 SelectionUpdateHz = 4,
 DisplayRadiusStuds = 0.28, -- Research marker size; not an organism's physical radius.
})
