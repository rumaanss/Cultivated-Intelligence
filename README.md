# Cultivated Intelligence — native planetary lake

Start with **[START_HERE.md](START_HERE.md)**. This is a complete source root; extract it separately from your previous project.

The default application is headless C++20. It owns organism neural computation, biology, chemistry, movement, checkpoints, and the authenticated local HTTP service. Live exchange uses bounded in-memory state. Python is not required to build or run it. Roblox continues to own presentation, player interaction and the research GUI.

| Directory | Responsibility |
| --- | --- |
| `applications/headless` | Default executable entry point |
| `applications/research` | Optional Raylib/OpenGL research entry point |
| `applications/shared` | Shared simulation loop and preserved research panels |
| `simulation/include`, `simulation/src` | C++ neural, ecological, physical and plant models |
| `transport` | Native HTTP, observer selection, protocol, plant paging and profiling |
| `planet` | Active Rojo source; existing planetary terrain is retained |
| `contracts` | Matching lake survey, surface and generated identity |
| `scripts` | PowerShell build, import/resume and diagnostics |
| `tests`, `simulation/tests`, `planet/tests` | Integration and regression checks |
| `third_party` | Pinned native HTTP/JSON headers and licenses |
| `tools` | Optional offline conversion/validation utilities |
| `worlds` | Existing place identity; not a replacement `.rbxl` |
| `archive` | Retired Python relay, older island source and historical reports |
| `docs` | Current architecture, migration and validation records |

Builds, runtime biology, credentials, recordings and PGO results are excluded from source control. Do not copy old build directories into this root. The maintained research UI shares the same biological engine and transport as headless mode.
