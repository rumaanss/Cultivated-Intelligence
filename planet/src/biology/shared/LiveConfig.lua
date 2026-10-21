--!strict
return table.freeze({
 Enabled = true, -- false restores recorded playback.
 ExchangeHz = 6, -- one combined upstream/downstream request; 360/min steady state.
 MaximumVisibleOrganisms = 384,
 ClientSnapshotHz = 12,
 StaleSeconds = 3,
 PlayerRadius = 2,
 PlayerSpeed = 18,
 AttackRange = 8,
 AttackDamage = 35,
 AttackCooldown = 0.3,
 AgentBiteDamage = 8,
 AgentBiteCooldown = 0.5,
 CorpseEnergy = 40, -- Explicit gameplay biomass units; not a calibrated human energy model.
})
