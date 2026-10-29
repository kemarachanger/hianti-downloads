# Hianti

One-command proxy setup and background repair for **Antigravity on Windows x64**.

## Install

Start your local proxy client, open PowerShell, and paste:

```powershell
irm https://github.com/kemarachanger/hianti-downloads/releases/latest/download/install.ps1 | iex
```

You can use Windows PowerShell 5.1 or PowerShell 7. If an older installation reports
`Get-FileHash` is missing, run the same installer again to apply the launcher fix.

No GitHub account, token, Git, or GitHub CLI is required. The installer verifies the
signed package, installs `hianti` for your Windows user, detects Antigravity and a
local SOCKS5 proxy, and enables background repair at Windows sign-in. If Antigravity
is open and needs a repair, save your work and close it once to let setup finish.

Requirements: Windows 10/11 x64, Windows PowerShell 5.1, x64 Antigravity, and a
running local proxy with an unauthenticated SOCKS5 listener, such as Karing's mixed
port. No TUN mode or Windows system-proxy change is needed.

## Daily use

```text
hianti status           Check the app, proxy and background worker
hianti fix              Repair once
hianti update           Install the latest signed Hianti release
hianti watch off        Stop background maintenance and login startup
hianti restore          Restore the original application files
```

If several proxy ports are found, choose one with `hianti --port 3067` (use your
client's actual port). After an Antigravity update, background maintenance waits for
the app to exit before repairing files. `hianti fix` is available for manual repair.
Account identity is currently reported as **Unknown**.

Existing Hianti users can run the same installation command again. It keeps the
app/proxy binding and migrates the old private publisher feed to public downloads.
Updates then work without GitHub authorization. Custom update feeds are preserved.

## Downloads

[Latest release](https://github.com/kemarachanger/hianti-downloads/releases/latest)
contains the ZIP, `install.ps1`, signed update feed, and checksums. A manual install
is also available: extract the ZIP and run
`powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Local.ps1 -Start`.

This repository hosts distribution files. The package includes Hianti's runtime
PowerShell scripts and Antigravity-Proxy v2.4 with its license notices. Development
history and publisher credentials are kept separately. Package signatures use a
pinned publisher key; the private signing key is not distributed.

Local checks establish the SOCKS5 handshake and component status. They do not prove
that every application request is proxied, or guarantee compatibility with future
Antigravity builds. See the README inside the ZIP for full behavior and recovery.
