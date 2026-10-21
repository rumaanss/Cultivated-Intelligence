[1mdiff --git a/src/shared/DevelopmentConfig.lua b/src/shared/DevelopmentConfig.lua[m
[1mindex b582525..8ed5c27 100644[m
[1m--- a/src/shared/DevelopmentConfig.lua[m
[1m+++ b/src/shared/DevelopmentConfig.lua[m
[36m@@ -3,12 +3,12 @@[m
 local DevelopmentConfig = {[m
 	-- The spherical globe prototype is intentionally disabled.[m
 	-- The active Phase 2 world is CartesianResearchBasin.[m
[31m-	EnableGlobeProxy = false,[m
[32m+[m	[32mEnableGlobeProxy = true,[m
 [m
 	-- Disable temporary planet/basin debug geometry.[m
[31m-	EnableResearchBasinBounds = false,[m
[31m-	EnableDevelopmentMarkers = false,[m
[31m-	EnableDepthMarkers = false,[m
[32m+[m	[32mEnableResearchBasinBounds = true,[m
[32m+[m	[32mEnableDevelopmentMarkers = true,[m
[32m+[m	[32mEnableDepthMarkers = true,[m
 [m
 	-- Retained for future debug-mode reactivation.[m
 	GlobeProxyTransparency = 0.72,[m
