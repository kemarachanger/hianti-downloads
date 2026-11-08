# Antigo

One-command proxy setup and background repair for **Antigravity on Windows x64**,
plus a separate **macOS preview** for Apple Silicon and Intel.
Formerly Hianti. The `hianti` command remains a compatibility alias for `antigo`.

## Windows install

Start your local proxy client, open PowerShell, and paste:

```powershell
irm https://github.com/kemarachanger/hianti-downloads/releases/latest/download/install.ps1 | iex
```

You can use Windows PowerShell 5.1 or PowerShell 7. If an older installation reports
`Get-FileHash` is missing, run the same installer again to apply the launcher fix.

No GitHub account, token, Git, or GitHub CLI is required. The installer verifies the
signed package, installs both `antigo` and `hianti` for your Windows user, detects
Antigravity and a local SOCKS5 proxy, and enables background repair at Windows
sign-in. If Antigravity is open and needs a repair, save your work and close it once
to let setup finish.

Requirements: Windows 10/11 x64, Windows PowerShell 5.1, x64 Antigravity, and a
running local proxy with an unauthenticated SOCKS5 listener, such as Karing's mixed
port. No TUN mode or Windows system-proxy change is needed.

## Windows daily use

```text
antigo status           Check the app, proxy and background worker
antigo ipv6 block       Block native IPv6 in injected processes
antigo ipv6 proxy       Restore IPv6 routing through the proxy
antigo doctor           Diagnose the proxy route and recent errors
antigo doctor --offline Check local setup without external probes
antigo fix              Repair once
antigo update           Install the latest signed Antigo release
antigo watch off        Stop background maintenance and login startup
antigo restore          Restore the original application files
```

If several proxy ports are found, choose one with `antigo --port 3067` (use your
client's actual port). After an Antigravity update, background maintenance waits for
the app to exit before repairing files. `antigo fix` is available for manual repair.
Account identity is currently reported as **Unknown**.

IPv6 policy is saved for future repairs. Close Antigravity to apply a pending
change. Loopback and IPv4-mapped connections remain available. This controls
intercepted Windows processes, not system IPv6 or the remote proxy's exit family.
The default remains `proxy`.

Doctor checks exit IP metadata and Google HTTPS connectivity without credentials;
it summarizes recent log error categories without printing raw messages. IP lookup
routes may differ from Google routes. It does not claim that an IP is trusted by
Google or that Gemini model access works; verify with a request in Antigravity.

Existing Hianti users can run the same installation command again. It keeps the
app/proxy binding and migrates the old private publisher feed to public downloads.
Updates then work without GitHub authorization. Custom update feeds are preserved.

Alternatively, update an existing installation with:

```powershell
hianti update
hianti --help
antigo status
```

The second command creates the new alias after an older updater activates the
release. Both names use the same settings and background worker. Existing download
links and the `%LOCALAPPDATA%\Hianti` installation directory remain valid.

## macOS preview

Quit Antigravity and start your local proxy client. In Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash && export PATH="$HOME/.local/bin:$PATH"
```

The signed installer detects Apple Silicon/Intel and installs without sudo,
Homebrew or a GitHub account. Launch Antigravity through `antigo` on each use.
Both `antigo` and `hianti` work. With multiple SOCKS5 listeners, choose one using
`antigo --port 7890` with your actual port.

```sh
antigo status
antigo doctor --json
antigo update
antigo watch off
```

macOS includes connection-stage errors and a Google account-country check:

```sh
antigo doctor --guided
antigo doctor --account-region CN --compare-curl --json
antigo doctor --offline --observe 10
```

Use the country actually shown on Google's Terms page for the same account as
Antigravity. It is separate from the proxy exit IP. The answer is user-reported,
not saved or automatically queried. `--compare-curl` compares SOCKS5 and HTTP
CONNECT on the saved port without changing routing or disabling TLS verification.
Installation and bare `antigo` launch the app; `doctor`, `status` and background
maintenance do not. The installer accepts `--no-start` to skip its first launch.

Version 0.1.2 requests conservative Chromium QUIC, WebRTC and DNS settings,
explicitly scopes gRPC Core proxy variables, and observes app-descendant TCP/UDP
sockets. Quit the app and launch with `antigo` after updating. Socket observations
are diagnostic evidence; the preview still cannot enforce a native IPv6 block.

macOS 0.1.3 also adds an official GitHub asset API fallback for release download
outages, with the same signature and checksum verification. If an older updater
returns HTTP 504, rerun the installation command above to obtain this fix.

This preview uses Electron launch settings and proxy environment variables with
a local SOCKS5 bridge. It does not modify the app or change the system proxy.
It cannot yet block direct IPv6 or capture helpers that ignore proxy settings.
The public release signature verifies the publisher; the binary is not Apple
Developer ID notarized. macOS 15 runner tests cover both architectures;
real Antigravity/Gemini requests still need testing on your Mac.

`antigo watch off` stops the bridge; quit and reopen the original app normally to
remove its scoped launch settings. macOS updates use their own signed preview
feed. [macOS preview details](macos/README.md) describe coverage and recovery.

## Windows downloads

[Latest release](https://github.com/kemarachanger/hianti-downloads/releases/latest)
contains the ZIP, `install.ps1`, signed update feed, and checksums. A manual install
is also available: extract the ZIP and run
`powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Local.ps1 -Start`.

This repository hosts distribution files. The package includes Antigo's runtime
PowerShell scripts and Antigravity-Proxy 2.4-hianti.1 (with an IPv6 blocking fix)
with its license notices. Development
history and publisher credentials are kept separately. Package signatures use a
pinned publisher key; the private signing key is not distributed.

Local checks establish the SOCKS5 handshake and component status. They do not prove
that every application request is proxied, or guarantee compatibility with future
Antigravity builds. See the README inside the ZIP for full behavior and recovery.
