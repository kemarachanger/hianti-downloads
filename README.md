# Antigo

One-command proxy setup and auto-repair for **Antigravity on Windows x64**, plus a **macOS preview** for Apple Silicon and Intel.
Formerly **Hianti** (`hianti` remains a supported compatibility alias for `antigo`).

## Windows Install

Start your local proxy client (with an unauthenticated SOCKS5 or mixed port, such as Karing or Clash), open PowerShell 5.1 or 7, and run:

```powershell
irm https://github.com/kemarachanger/hianti-downloads/releases/latest/download/install.ps1 | iex
```

No GitHub account, token, or Git is required. The installer verifies the signed release, installs `antigo` and `hianti`, binds Antigravity to your local SOCKS5 port, and enables background auto-repair at Windows sign-in.

## Windows Commands

```text
antigo status           Show concise app, proxy, module, IPv6 and worker status
antigo status --verbose Show full paths, policies, processes and history
antigo ipv6 block       Block native IPv6 in injected processes
antigo ipv6 proxy       Route IPv6 through the proxy (default)
antigo doctor           Show proxy health, exit IP, HTTPS checks and warnings
antigo doctor --verbose Show full paths, policies, processes and diagnostic history
antigo doctor --offline Check local setup and recent logs without network probes
antigo fix              Repair once (--restart to close, repair and relaunch)
antigo update           Install the latest signed release (--check, --rollback)
antigo watch off        Disable auto repair and login startup
antigo restore          Restore original application files
```

- **Select a specific proxy port:** `antigo --port 3067`. Antigo keeps using the port you chose. If that proxy is not running, Antigo stops with a message naming any other proxy it found; start your proxy app, or switch with `antigo --port PORT`.
- **Upgrade an older Hianti install:** rerun the one-line installer above, or run `hianti update`, then `hianti --help`.
- **Manual/offline install:** download the [latest release ZIP](https://github.com/kemarachanger/hianti-downloads/releases/latest), extract it, and run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Local.ps1 -Start`.

## macOS Preview

Quit Antigravity, start your local proxy client, and run in Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash && export PATH="$HOME/.local/bin:$PATH"
```

Launch Antigravity via `antigo` on each use (`antigo --port 7890` if multiple SOCKS5 ports are active).

```sh
antigo status
antigo status --verbose
antigo doctor --guided
antigo doctor --verbose
antigo doctor --account-region CN --compare-curl --json
antigo doctor --offline --observe 10
antigo update
antigo watch off
```

The macOS preview uses a local HTTP-to-SOCKS5 bridge and scoped Chromium/Electron and gRPC settings. It requests QUIC/WebRTC UDP restrictions and remote DNS; helpers that ignore these settings can still connect directly, including over IPv6. See the [macOS guide](macos/README.md) for details.
