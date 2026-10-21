# Historical compatibility material

Nothing here is used by the default native application or the active Rojo project.

- `python-relay/`: previous file-based HTTP relay, its tests, and old production adapters. Retained as a protocol reference and rollback source; **do not run it beside the native service**.
- `legacy-roblox/`: earlier standalone island scripts and assets; active planetary scripts are in `planet/`.
- `legacy-main.cpp`: original combined Raylib application before extracting the shared application. The maintained research UI is in `applications/shared/application.cpp` and `simulation/src/brain/`.
- `docs/`: historical diagnostics and release instructions. These describe earlier deliveries and are superseded by root `START_HERE.md`.
- `run_planet.py`: retired Python launcher, preserved for reference, not supported in this layout.

Offline contract-generation tests still import the historical habitat validator; Python is not required to build or run the C++ application.
- `test_planet_live.py`: retired file-transport integration test; superseded by `tests/run_native_transport.py`.
