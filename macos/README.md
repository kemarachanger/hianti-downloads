# Antigo for macOS (Preview)

Native CLI companion for Antigravity on Apple Silicon (`arm64`) and Intel (`amd64`). `antigo` is the primary command; `hianti` is a supported alias.

Tested on macOS 15 for both architectures; other macOS versions and real model sessions need user validation. Releases carry a publisher signature, not Apple Developer ID notarization.

## Install & Launch

Open a local proxy client with an unauthenticated SOCKS5 or mixed port, quit Antigravity, and run in Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash && export PATH="$HOME/.local/bin:$PATH"
```

- Verifies the publisher RSA signature and SHA-256 checksum, installs into `~/Library/Application Support/Antigo`, links `antigo` and `hianti` into `~/.local/bin`, and launches Antigravity with scoped proxy settings.
- To install without launching the app: `curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash -s -- --no-start`.
- Always launch Antigravity through `antigo` so scoped proxy settings are applied.

## Commands

```sh
antigo                         # Detect proxy, enable auto repair and launch Antigravity
antigo --port 7890             # Bind a specific local SOCKS5/mixed port
antigo fix                     # Save app/proxy binding without launching
antigo status                  # Show concise app, proxy, bridge and worker status
antigo status --verbose        # Show full paths, network flags, processes and details
antigo doctor                  # Check proxy exits, HTTPS reachability and app sockets
antigo doctor --offline        # Check local setup and sockets without external probes
antigo doctor --guided         # Prompt for the Google Terms account country
antigo doctor --compare-curl   # Compare SOCKS5 and HTTP CONNECT via macOS curl
antigo doctor --observe 10     # Sample app and child TCP/UDP sockets for 10s (1-30)
antigo update                  # Install the latest signed macOS preview (--check, --rollback)
antigo watch on                # Enable the bridge worker and login startup
antigo watch off               # Stop the bridge worker and remove login startup
antigo restore                 # Stop bridge and auto repair; reopen Antigravity normally
```

`watch off` and `restore` stop the bridge used by the running app. Quit Antigravity and reopen it normally to clear the session's proxy settings.

## How It Works & Coverage

1. **Loopback Bridge (`127.0.0.1`):** Forwards HTTP and HTTPS `CONNECT` traffic to your local SOCKS5 port with remote DNS resolution and no direct fallback.
2. **Scoped App Launch:** Passes Electron/Chromium flags (`--proxy-server`, `--disable-quic`, `--force-webrtc-ip-handling-policy=disable_non_proxied_udp`, and local external DNS suppression) plus `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, and scoped `grpc_proxy` / `no_grpc_proxy` environment variables.
3. **Boundaries:** Does not modify `Antigravity.app`, edit the macOS system proxy, or install a kernel/system extension. Because it uses launch flags rather than socket injection, it **cannot forcibly block native IPv6 or direct sockets** from helpers that ignore proxy settings.

Auto repair keeps the bridge available at sign-in and tracks the app version. Launch through `antigo` after app updates to apply the scoped settings again.

## Diagnostics (`antigo doctor`)

- **Stage-aware HTTPS probes:** Reports failures by stage (`local_connect`, `socks_handshake`, `socks_connect` with SOCKS5 reply code, `tls_handshake`, `http_response`). Returns `FAIL` if all native HTTPS probes fail.
- **Socket sampling (`--observe 1..30`):** Inspects the app and its current descendants via `ps` and `lsof`, flagging non-loopback TCP/UDP peers in `possible_bypass`. Brief connections and reparented helpers may be missed; unconnected UDP sockets are counted separately.
- **Protocol comparison (`--compare-curl`):** Runs explicit `socks5h` and `http` CONNECT probes via `/usr/bin/curl` against the same local port and Google OAuth endpoint.
- **Account country check (`--guided` / `--account-region REGION`):** Guides you to verify the account-associated country on [Google Terms of Service](https://policies.google.com/terms) against the [Antigravity availability list](https://antigravity.google/docs/faq#what-is-google-antigravitys-geographical-availability) (and provides the [country correction form](https://policies.google.com/country-association-form) if needed). User-reported only; no cookies or tokens are read or saved.

Successful probes confirm HTTPS reachability. Verify Gemini/Opus access with a request inside Antigravity.

## Updates & Development

- Uses an independent signed preview feed (`macos/preview/feed-{arm64,amd64}.json`) and tags (`macos-vVERSION`). Includes an automatic GitHub Release Asset API fallback for transient download errors while enforcing RSA signature and SHA-256 verification.
- Built with Go 1.26.4 standard library only: `go test -race ./...`. Release instructions are in the [private source repository](https://github.com/kemarachanger/hianti/blob/main/docs/PUBLISHING.md).
