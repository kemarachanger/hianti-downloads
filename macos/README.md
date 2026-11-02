# Antigo for macOS — preview

A native command-line companion for Antigravity, available for Apple Silicon and
Intel x64. All commands and messages are English. `hianti` remains an alias.

## Install and launch

Install Antigravity and open a local proxy client with an unauthenticated SOCKS5
or mixed port. Quit Antigravity before the first managed launch. In Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash && export PATH="$HOME/.local/bin:$PATH"
```

The installer selects the native architecture, verifies the publisher's RSA
signature and binary checksum, installs into
`~/Library/Application Support/Antigo`, adds `antigo` and `hianti` under
`~/.local/bin`, and launches the first setup. No sudo, Homebrew, Python or GitHub
account is required. Open a new terminal if the command is not on PATH.

This preview is tested on macOS 15 runners for both architectures. Other macOS
versions and real Antigravity model sessions still need user validation. The
binary has a publisher release signature; it is not Apple Developer ID notarized.
Do not disable Gatekeeper or SIP to use this preview.

```sh
antigo                     # Detect, enable maintenance, launch Antigravity
antigo --port 7890          # Choose a local SOCKS5/mixed port
antigo status              # Inspect app path/version, port and worker
antigo doctor              # Inspect proxy exits and HTTPS connectivity
antigo doctor --offline    # Local checks only
antigo fix                 # Save binding without launching
antigo update              # Install the latest signed macOS preview
antigo update --check      # Check for an update
antigo update --rollback   # Activate the previous verified package
antigo watch off           # Stop the bridge and its login startup
antigo restore             # Stop maintenance, then reopen the original app normally
```

Launch through `antigo` on subsequent uses. Opening the original app icon does
not apply this preview's scoped proxy settings. If the app is already running,
Antigo asks you to quit it; it never force-kills your work. Use
`antigo --app /path/to/Antigravity.app` for a nonstandard installation.
If several SOCKS5 listeners respond, choose one with `--port`; an existing saved
port is kept when temporarily unavailable.

`antigo --no-watch` uses a session bridge without login startup. The session
bridge exits after the app has been absent for 90 seconds. By default a user
LaunchAgent keeps the bridge available and observes app versions; if the GUI
launchd domain is unavailable, Antigo reports a session-worker fallback.
An app update does not require reinjecting files: quit the app and run `antigo`
again. The worker does not force an updated app to restart.

## What the preview covers

Antigo sets Electron's HTTP proxy switch for the app's Chromium network stack
and HTTP/HTTPS/ALL_PROXY environment variables for proxy-aware helpers. A local
HTTP bridge forwards connections to the selected SOCKS5 endpoint. Hostnames are
sent to SOCKS5 for remote DNS. The bridge binds only to IPv4 loopback, validates
the SOCKS5 handshake, and has no direct fallback when its upstream fails.
Loopback OAuth callbacks and IPC remain available. Secure WebSockets use CONNECT;
plain `ws://` upgrades through the bridge are currently unsupported.

This is a different implementation from Windows socket injection. Helpers that
ignore environment proxies, direct sockets and UDP may bypass these settings.
The preview **cannot enforce an IPv6 block**. `antigo ipv6` reports this limit;
`antigo ipv6 block` returns an error. The remote proxy can still use IPv6 to reach
destinations. There is no TUN, system proxy edit, app-bundle modification,
re-signing or DYLD injection.

`doctor` checks the saved local endpoint, the bridge and observed non-loopback
TCP sockets in app processes. Online mode performs four unauthenticated HTTPS
probes through SOCKS5: ipify IPv4/IPv6 exits, Google OAuth and the Antigravity
service endpoint. Certificates are validated, redirects are not followed and
there is no direct fallback. Observed sockets are a point-in-time clue, not proof
that all requests use the proxy. UDP is not audited. `doctor` does not read account
tokens, judge Google's trust in an IP, or claim that Gemini access works.

For the first real-app test, launch with `antigo`, send a small Gemini request,
then run `antigo doctor --json`. The output includes paths and exit IPs; redact
those if sharing publicly. Account identity is reported as Unknown.

## Distribution and development

macOS uses independent version numbers and a signed preview feed under
`macos/preview/` in the public downloads repository. Releases use tags such as
`macos-v0.1.0` and never replace Windows' latest stable release. Updates preserve
the proxy binding and switch between immutable per-version directories; rollback
re-verifies the saved package before activation. Update operations can briefly
interrupt the local bridge. Antigo updates are manual in this preview.

To install without starting the app or editing shell startup files:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh -o /tmp/antigo-install.sh
bash /tmp/antigo-install.sh --no-start --no-path --home "$HOME/Antigo-test"
"$HOME/Antigo-test/bin/antigo" --help
```

Go 1.26.4 is used for builds; only the standard library is needed.
`go test -race ./...` on macOS exercises remote-DNS forwarding, buffered CONNECT,
no direct fallback, credential stripping, manifest authentication, update
activation and an isolated fixture `.app`. That fixture validates flags,
environment, both aliases, version observation and worker shutdown; it is not a
real Google sign-in or Gemini test. The optional CI dispatch also verifies the
published bootstrap and binary on both macOS architectures.

The publisher runs `scripts/Build-Mac.ps1` with the locally held signing key, then
`scripts/Publish-Mac.ps1`. The key is never uploaded to CI. See
`docs/PUBLISHING.md` for the release procedure.

Network-setting references: [Electron switches](https://www.electronjs.org/docs/latest/api/command-line-switches).
