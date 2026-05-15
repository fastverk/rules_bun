"""SHA-256 pins for prebuilt Bun binaries.

Bumping a version requires adding an entry here. Compute with:

    curl -fsSL <url> | shasum -a 256

Unpinned versions download unverified (warning emitted). Always
prefer pinning.

Keys use the rules_github canonical platform names
(`darwin_aarch64`, `darwin_x86_64`, `linux_aarch64`, `linux_x86_64`).
The mapping to Bun's project-specific asset names
(`darwin-aarch64`, `darwin-x64`, …) lives in
`extensions.bzl`'s `_PLATFORM_ALIASES`.
"""

KNOWN_VERSIONS = {
    "1.3.14": {
        "darwin_aarch64": "d8b96221828ad6f97ac7ac0ab7e95872341af763001e8803e8267652c2652620",
        "darwin_x86_64": "4183df3374623e5bab315c547cfa0974533cd457d86b73b639f7a87974cd6633",
        "linux_aarch64": "a27ffb63a8310375836e0d6f668ae17fa8d8d18b88c37c821c65331973a19a3b",
        "linux_x86_64": "951ee2aee855f08595aeec6225226a298d3fea83a3dcd6465c09cbccdf7e848f",
    },
}

DEFAULT_VERSION = "1.3.14"
