# Pinned native dependencies

`manifest.json` records exact header hashes, release versions, upstream links and licenses. These checked-in headers make the default headless build independent of dependency downloads.

- cpp-httplib 0.18.3, MIT: bounded local HTTP server; no OpenSSL, zlib or Brotli feature macros are enabled.
- nlohmann/json 3.11.3, MIT: protocol parsing/serialization.

Raylib remains optional. Its commit and archive SHA-256 are pinned in the root CMake file and fetched only with `CI_BUILD_RESEARCH=ON`. Its own source archive carries the Raylib license.
