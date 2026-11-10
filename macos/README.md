# Antigo for macOS (Preview)

Native CLI companion for Antigravity on Apple Silicon (`arm64`) and Intel (`amd64`). `antigo` is the primary command; `hianti` is a supported alias.

Requires macOS 12 (Monterey) or later. Tested on macOS 15 for both architectures; other macOS versions and real model sessions need user validation. Releases carry a publisher signature, not Apple Developer ID notarization.

## Install & Launch

Open a local proxy client with an unauthenticated SOCKS5 or mixed port, quit Antigravity, and run in Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash && export PATH="$HOME/.local/bin:$PATH"
```

- Verifies the publisher RSA signature and SHA-256 checksum, installs into `~/Library/Application Support/Antigo`, links `antigo` and `hianti` into `~/.local/bin`, and launches Antigravity with scoped proxy settings.
- Adds `~/.local/bin` to your shell profile unless it is already on PATH. If another file is in the way or the profile is a link, the installer leaves it alone, prints the one step to take, and still completes.
- To install without launching the app: `curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash -s -- --no-start`.
- Installs for your macOS user account only and needs no administrator password. Each account on the Mac that uses Antigravity needs its own install.
- Open Antigravity the normal way (Dock, Finder, Spotlight) or with `antigo`. With auto repair on (the default), Antigo reopens an app opened the normal way through the proxy as it starts (seamless launch; `antigo seamless off` turns it off).

If GitHub cannot be reached without your proxy, install through it. Replace `7890` with your proxy app's SOCKS5 or mixed port:

```sh
curl -fsSL --proxy socks5h://127.0.0.1:7890 https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash -s -- --proxy 127.0.0.1:7890 && export PATH="$HOME/.local/bin:$PATH"
```

`--proxy` takes `HOST:PORT` or `socks5h://HOST:PORT`, and the proxy resolves the host names. If the proxy does not connect, the installer says so and downloads directly. The signature and checksum checks apply either way.

## Commands

```sh
antigo                         # Detect proxy and launch Antigravity; auto repair by default
antigo --port 7890             # Bind a specific local SOCKS5/mixed port
antigo fix                     # Save app/proxy binding without launching
antigo status                  # Show concise app, proxy, bridge and worker status
antigo status --verbose        # Show full paths, network flags, processes and details
antigo doctor                  # Show proxy health, exit IP, HTTPS checks and socket warnings
antigo doctor --verbose        # Include full local status, socket records and probe details
antigo doctor --offline        # Check local setup and sockets without external probes
antigo doctor --guided         # Prompt for the Google Terms account country
antigo doctor --compare-curl   # Compare SOCKS5 and HTTP CONNECT via macOS curl
antigo doctor --observe 10     # Sample app and child TCP/UDP sockets for 10s (1-30)
antigo update                  # Install the latest signed macOS preview (--check, --rollback)
antigo watch on                # Enable the bridge worker and login startup
antigo watch off               # Turn off auto repair and login startup; stays off
antigo seamless on|off         # Reopen Antigravity through Antigo when opened normally; on by default
antigo ipv6                    # Show whether IPv6 block is on
antigo ipv6 block              # Block IPv6 for traffic through Antigo
antigo ipv6 proxy              # Send IPv6 through the proxy (default)
antigo restore                 # Stop bridge and auto repair; reopen Antigravity normally
antigo uninstall               # Remove Antigo, its login startup and commands (--keep-settings)
```

`watch off` and `restore` stop the bridge used by the running app. Quit Antigravity and reopen it normally to clear the session's proxy settings.

Auto repair is on from the first run. `watch off`, `restore` and `antigo --no-watch` turn it off, and it stays off, with a session bridge for each launch, until `watch on`. `antigo fix` never changes it.

**Seamless launch.** When Antigravity is opened the normal way, the background worker notices it as it starts and, within its first 10 seconds, asks it to quit and opens it again through Antigo, so its traffic uses the proxy, even while the proxy app is offline. There is no prompt or notification, and the app is never forced to quit. The worker leaves the app alone when it was opened with a file, a folder or any other command-line argument such as `--user-data-dir` (a reopen could not pass them on), has run for more than 10 seconds, or was restarted by Antigo in the last 2 minutes; `status` and `doctor` then report it. A file or folder opened from Finder or the Dock while the app starts reaches it in a way Antigo cannot see, so after the switch you may need to open it again; opening Antigravity first avoids this. Seamless launch needs auto repair, and `antigo seamless off` turns it off; `status --verbose` shows the choice.

**IPv6 block.** `antigo ipv6 block` blocks IPv6 for traffic through Antigo. Helpers that ignore proxy settings are reported, not blocked. Use it when your proxy's IPv6 route cannot reach the service. The bridge then refuses destinations given as IPv6 addresses (IPv4-mapped addresses count as IPv4) and never sends an IPv6 address to the proxy; host names still go to the proxy, which resolves them. The worker applies the change within a few seconds, without restarting Antigravity, and there is no password, firewall rule or system change. In this mode `status` and `doctor` report `FAIL` when an Antigravity process connects over IPv6 by itself. `antigo ipv6 proxy`, the default, never blocks; an IPv6 exit that the proxy does not offer is only listed under `Info`.

Running `antigo` while Antigravity runs without Antigo restarts it the same way. From Antigravity's own terminal, `antigo` hands the restart to the worker and says so, so the command is not ended with the app.

**Uninstall.** `antigo uninstall` removes Antigo without asking anything: it stops the background worker and removes login startup, the `antigo` and `hianti` links in `~/.local/bin` that point at this installation, the PATH line the installer added to your shell profile (kept while `~/.local/bin` holds other commands that may need it) and the Antigo folder, and lists what it removed. Antigravity itself is never changed; if it was opened through Antigo, quit and reopen it afterwards, as the command says. `--keep-settings` keeps `settings.json` for a later install. Only Antigo's own files go: a folder named with `--home` that holds no Antigo installation is left as it was, and other files in the Antigo folder stay. While another Antigo command runs, it exits `3` and removes nothing.

**Exit codes:** `0` success, `1` failure (including a `doctor` result of `FAIL`), `2` usage error, `3` busy, `4` waiting for app exit, `5` proxy unavailable (`75` internal worker restart). With `--json`, errors include `code` and `message`.

## How It Works & Coverage

1. **Loopback Bridge (`127.0.0.1`):** Forwards HTTP and HTTPS `CONNECT` traffic to your local SOCKS5 port with remote DNS resolution and no direct fallback.
2. **Scoped App Launch:** Passes Electron/Chromium flags (`--proxy-server`, `--disable-quic`, `--force-webrtc-ip-handling-policy=disable_non_proxied_udp`, and local external DNS suppression) plus `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, and scoped `grpc_proxy` / `no_grpc_proxy` environment variables.
3. **Boundaries:** Does not modify `Antigravity.app`, edit the macOS system proxy, or install a kernel/system extension. Because it uses launch flags rather than socket injection, it **cannot forcibly block native IPv6 or direct sockets** from helpers that ignore proxy settings.

Auto repair keeps the bridge available at sign-in, tracks the app version and, with seamless launch, reopens an app opened the normal way through Antigo, including after an app update.

## Diagnostics (`antigo doctor`)

The default view is a compact summary. Use `--verbose` for full details or `--json` for the complete structured report; both work with `--offline`. Account-country guidance appears when requested with `--guided` or `--account-region`.

**Headline.** `status` and `doctor` start with one line, such as `Antigo status | OK`:

- `FAIL`: Antigravity's traffic does not go through the proxy, or cannot. Antigo is not set up, the app cannot be found, the proxy or the bridge is down, the app was opened without Antigo, an app process connected over IPv6 by itself while IPv6 block is on, or, for `doctor`, no check reached the internet through the proxy or HTTPS works through the proxy but not through the bridge.
- `ATTENTION`: it works, but something needs action, such as a failed service check, connections that bypass the proxy or app processes that cannot be checked.
- `OK`: none of the above.

Each problem has an `Attention` row, and `ATTENTION` or `FAIL` ends with one `Next step` row: the one thing to do. A failed IPv4 or IPv6 exit check is listed under `Info` and never changes the headline, since the app does not depend on it. JSON has the same `result` and `next_step` (`null` when `OK`); for `OK`, `doctor --json` reports `CHECKED`, as on Windows.

- **App launch:** Checks that each running Antigravity main process was launched to use the bridge. An app opened the normal way does not use the proxy, so `status` and `doctor` say so and report `FAIL`. With seamless launch, the worker reopens it through Antigo as it starts; otherwise, run `antigo` to restart it.
- **Bridge probe:** Requests the Antigravity service through the bridge with HTTP `CONNECT`, the path the app uses, in addition to the direct SOCKS5 probes.
- **Stage-aware HTTPS probes:** Reports failures by stage (`local_connect`, `socks_handshake`, `socks_connect` with SOCKS5 reply code, `tls_handshake`, `http_response`). Reports `FAIL` when every check except the IPv6 exit fails.
- **Socket sampling (`--observe 1..30`):** Inspects the app and its current descendants via `ps` and `lsof`, flagging non-loopback TCP/UDP peers in `possible_bypass`. Brief connections and reparented helpers may be missed; unconnected UDP sockets are counted separately.
- **Protocol comparison (`--compare-curl`):** Runs explicit `socks5h` and `http` CONNECT probes via `/usr/bin/curl` against the same local port and Google OAuth endpoint.
- **Account country check (`--guided` / `--account-region REGION`):** Guides you to verify the account-associated country on [Google Terms of Service](https://policies.google.com/terms) against the [Antigravity availability list](https://antigravity.google/docs/faq#what-is-google-antigravitys-geographical-availability) (and provides the [country correction form](https://policies.google.com/country-association-form) if needed). User-reported only; no cookies or tokens are read or saved.

Successful probes confirm HTTPS reachability. Verify Gemini/Opus access with a request inside Antigravity.

The background worker logs its errors, the app starting and quitting, and each seamless launch decision in `worker.log` in the Antigo folder (`~/Library/Application Support/Antigo`), keeping at most two files of 256 KB. `antigo status --verbose` shows its last error.

## Updates & Development

- Uses an independent signed preview feed (`macos/preview/feed-v2-{arm64,amd64}.json`) and tags (`macos-vVERSION`). Versions before 0.2.0 read `macos/preview/feed-{arm64,amd64}.json`, which stays at 0.2.0, so they update to a version that reads the new feed. Includes an automatic GitHub Release Asset API fallback for transient download errors while enforcing RSA signature and SHA-256 verification. Antigo and the installer accept a release signed by the publisher key or by a backup key that is built in, so updates continue if one key is lost. A new version must start before Antigo switches to it, and reinstalling repairs a damaged copy. Antigo keeps the current and previous versions (for `update --rollback`) and removes older ones.
- `antigo update` downloads through the SOCKS5 proxy Antigo is set up with while it answers, and directly otherwise or when a download through it cannot connect. The signature and checksum checks decide what is installed either way. This fallback is for Antigo's own downloads only; the bridge never sends Antigravity's traffic directly.
- Built with Go 1.26.10 standard library only: `go test -race ./...`. `ANTIGO_RELEASE_CHECK=1 go test -run TestShippedTrustedKeys .` checks that the built-in keys are ready for a release of this version; from 0.2.0 a release needs the backup key in `macos/trust-backup.pem`. `scripts/coverage.sh` reports coverage including the CLI processes the tests start. Release instructions are in the [private source repository](https://github.com/kemarachanger/hianti/blob/main/docs/PUBLISHING.md).
