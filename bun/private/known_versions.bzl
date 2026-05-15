"""SHA-256 pins for prebuilt Bun binaries.

Bumping a version requires adding an entry here. Compute with:

    curl -fsSL <url> | shasum -a 256

Unpinned versions download unverified (warning emitted). Always
prefer pinning.
"""

# Map: bun version (no `v` prefix) -> { platform -> sha256 hex }.
KNOWN_VERSIONS = {
    "1.3.14": {
        "darwin-aarch64": "d8b96221828ad6f97ac7ac0ab7e95872341af763001e8803e8267652c2652620",
        "darwin-x64": "4183df3374623e5bab315c547cfa0974533cd457d86b73b639f7a87974cd6633",
        "linux-aarch64": "a27ffb63a8310375836e0d6f668ae17fa8d8d18b88c37c821c65331973a19a3b",
        "linux-x64": "951ee2aee855f08595aeec6225226a298d3fea83a3dcd6465c09cbccdf7e848f",
    },
}

# Bun releases are tagged `bun-v<version>` (note the `bun-v` prefix,
# unlike most projects which just use `v<version>`).
URL_TEMPLATE = "https://github.com/oven-sh/bun/releases/download/bun-v{version}/bun-{platform}.zip"

DEFAULT_VERSION = "1.3.14"
