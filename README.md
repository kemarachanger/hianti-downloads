# Antigo

One-command proxy setup and auto-repair for **Antigravity on Windows x64**, plus a **macOS preview** for Apple Silicon and Intel.
Formerly **Hianti** (`hianti` remains a supported compatibility alias for `antigo`).

## Windows Install

Start your local proxy client (with an unauthenticated SOCKS5 or mixed port, such as Karing or Clash), open PowerShell 5.1 or 7, and run:

```powershell
irm https://github.com/kemarachanger/hianti-downloads/releases/latest/download/install.ps1 | iex
```

No GitHub account, token, or Git is required. The installer verifies the signed release, installs `antigo` and `hianti`, binds Antigravity to your local SOCKS5 port, and enables background auto-repair at Windows sign-in.

If GitHub cannot be reached without your proxy, install through it. Replace `7890` with the mixed (HTTP and SOCKS5) port of your proxy app:

```powershell
& ([scriptblock]::Create((irm -Proxy http://127.0.0.1:7890 https://github.com/kemarachanger/hianti-downloads/releases/latest/download/install.ps1))) -Proxy 127.0.0.1:7890
```

`irm -Proxy` fetches the installer through the proxy, and `-Proxy` sends the installer's own downloads through it. `-Proxy` takes `HOST:PORT` or `socks5h://HOST:PORT` for a SOCKS5 or mixed port (the proxy resolves host names), or `http://HOST:PORT` for an HTTP port. If the proxy does not connect, the installer says so and downloads directly. The signature and checksum checks apply either way. With a SOCKS5-only port, fetch the installer with `curl.exe -fsSL --socks5-hostname 127.0.0.1:7890 -o install.ps1 https://github.com/kemarachanger/hianti-downloads/releases/latest/download/install.ps1` and run `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Proxy 127.0.0.1:7890`.

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
antigo seamless off     Do not reopen Antigravity when it starts without the proxy
antigo restore          Restore original application files
antigo uninstall        Remove Antigo and restore the app files (--keep-settings)
```

- **Open Antigravity the normal way:** the proxy module loads however Antigravity starts. If an Antigravity update removed it, Antigo puts it back in the background, and an Antigravity that started without it is reopened through Antigo within its first seconds, with no prompt. `antigo seamless off` turns the reopening off.
- **Select a specific proxy port:** `antigo --port 3067`. Antigo keeps using the port you chose. If that proxy is not running, Antigo stops with a message naming any other proxy it found; start your proxy app, or switch with `antigo --port PORT`.
- **Upgrade an older Hianti install:** rerun the one-line installer above, or run `hianti update`, then `hianti --help`.
- **Manual/offline install:** download the [latest release ZIP](https://github.com/kemarachanger/hianti-downloads/releases/latest), extract it, and run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Local.ps1 -Start`.
- **Uninstall:** `antigo uninstall` removes Antigo, its login startup, its PATH entry and its commands without asking, and brings back Antigravity's original files. It never closes Antigravity; what Antigravity still uses is removed once it closes. `--keep-settings` keeps `settings.json`.

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

## Security

To report a vulnerability, follow [SECURITY.md](SECURITY.md); it also explains how releases are signed and verified.
