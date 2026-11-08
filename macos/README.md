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
antigo status              # Inspect essential app, proxy and bridge status
antigo status --verbose    # Include paths, settings, processes and coverage
antigo doctor              # Inspect proxy exits and HTTPS connectivity
antigo doctor --offline    # Local checks only
antigo doctor --guided     # Ask about the Google Terms account country
antigo doctor --compare-curl  # Compare native probes with macOS curl
antigo doctor --observe 10  # Sample app and descendant TCP/UDP sockets for 10s
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

The installer invokes `antigo start` once, so opening Antigravity during install
or when running bare `antigo` is expected. `status`, `doctor`, `fix` and the
background worker do not launch it. To install without that first app launch:

```sh
curl -fsSL https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/install.sh | bash -s -- --no-start
```

Open a new terminal afterward, or export the command path as in the main install
command. `--no-start` skips initial setup too; run `antigo fix` to save a binding
without launching, then `antigo` when ready to start the app.

## What the preview covers

Antigo sets Electron's HTTP proxy switch for the app's Chromium network stack
and HTTP/HTTPS/ALL_PROXY plus gRPC Core environment variables for proxy-aware helpers. A local
HTTP bridge forwards connections to the selected SOCKS5 endpoint. Hostnames are
sent to SOCKS5 for remote DNS. The bridge binds only to IPv4 loopback, validates
the SOCKS5 handshake, and has no direct fallback when its upstream fails.
Loopback OAuth callbacks and IPC remain available. Secure WebSockets use CONNECT;
plain `ws://` upgrades through the bridge are currently unsupported.

Starting with 0.1.2, managed launches also request Chromium to disable QUIC,
disable non-proxied WebRTC UDP, and reject external hostname resolution in its
local resolver. Loopback names/addresses remain available, and destinations
are resolved by the proxy. The app may override or ignore these switches;
they are requested launch settings, not verified socket enforcement. They can
affect features that depend on direct WebRTC connectivity. Quit Antigravity and
run `antigo` after updating to apply the new settings to a fresh process.

The scoped environment explicitly replaces inherited `grpc_proxy` and
`no_grpc_proxy`, and removes inherited gRPC address-proxy overrides. gRPC Core
checks its own proxy variables before ordinary HTTP variables. Its exclusion
list is restricted to loopback callbacks. Helpers using a different networking
stack or disabling proxy support within the app may still bypass this setting.

This is a different implementation from Windows socket injection. Helpers that
ignore environment proxies, direct sockets and UDP may bypass these settings.
The preview **cannot enforce an IPv6 block**. `antigo ipv6` reports this limit;
`antigo ipv6 block` returns an error. The remote proxy can still use IPv6 to reach
destinations. There is no TUN, system proxy edit, app-bundle modification,
re-signing or DYLD injection.

`doctor` checks the saved local endpoint, the bridge and visible TCP/UDP sockets
in bundle processes and their current descendants, including helpers outside
the app directory. Online mode performs four unauthenticated HTTPS
probes through SOCKS5: ipify IPv4/IPv6 exits, Google OAuth and the Antigravity
service endpoint. Certificates are validated, redirects are not followed and
there is no direct fallback. Observed sockets are a point-in-time clue, not proof
that all requests use the proxy. Connected UDP peers are reported; unconnected
UDP sockets are counted separately because lsof cannot show their per-packet
destinations. `doctor` does not read account
tokens, judge Google's trust in an IP, or claim that Gemini access works.

Use `antigo doctor --offline --observe 10` while performing an operation in the
app to sample local sockets for approximately 10 seconds (1–30 supported).
`possible_bypass` flags visible non-loopback peers, with protocol, process ID,
address family and at most 32 peer details. It includes TCP connection attempts,
not just established connections. This does not prove packets reached the wire
or bypassed a separately installed network extension. Inspection failures are
reported explicitly. Short-lived traffic, reparented helpers outside the bundle,
system-mediated traffic and unconnected UDP destinations can remain invisible.
Observing no external sockets never proves full coverage or IPv6 blocking.

Default `status` keeps the app/version, proxy reachability, bridge state, IPv6
support, maintenance and login startup. Errors and inactive bridges remain
visible. Use `status --verbose` for full paths, network settings, inspected
processes, bridge details and coverage. `doctor` includes this complete local
view alongside its diagnostic results. Both aliases accept the option, and
`--json` preserves the full existing fields regardless of verbosity.

For the first real-app test, launch with `antigo`, send a small Gemini request,
then run `antigo doctor --json`. The output includes paths and exit IPs; redact
those if sharing publicly. Account identity is reported as Unknown.

### Troubleshooting HTTPS failures and account country

The local SOCKS5 greeting only proves that a compatible listener exists. It does
not prove the proxy can connect to a destination. Version 0.1.1 reports failures
as `local_connect`, `socks_handshake`, `socks_connect`, `tls_handshake` or
`http_response`, with bounded error details and SOCKS5 reply codes when supplied.
All native HTTPS probes failing now produces `FAIL`, even if the bridge and
SOCKS5 greeting are healthy. `ATTENTION` still reflects the preview's coverage
limits; HTTP 401/403/404 are HTTP responses, not evidence of authenticated model
access. Zero observed external sockets is not proof that no traffic bypassed the
proxy, especially when no app process was found.

For a mixed listener such as a FlClash configuration, compare the same Google
OAuth endpoint and port:

```sh
antigo doctor --compare-curl --json
```

This adds two bounded requests using macOS curl: explicit SOCKS5 with remote DNS
and HTTP CONNECT. HTTP CONNECT requires a mixed or HTTP listener. `.curlrc` and
inherited no-proxy bypasses are ignored. There is no direct retry, certificate
bypass or proxy reconfiguration. Differing results help narrow down TLS client,
inbound protocol, process-rule or network differences; they do not identify a
single cause by themselves. Maximum probe time is about 60 seconds plus local
inspection. The original four native probes remain the basis of the connectivity
summary; successful curl comparisons are reported separately.

Google's [Antigravity FAQ](https://antigravity.google/docs/faq#what-is-google-antigravitys-geographical-availability)
directs users to check the account-associated country on the
[Terms of Service page](https://policies.google.com/terms). Use the same Google
account as Antigravity and do not manually override the page's country selector.
Account association differs from the current proxy exit IP, physical location
and payment-profile country. Changing a node does not confirm an account-country
change. If the association is incorrect, Google's
[correction form](https://policies.google.com/country-association-form) handles
the request; submission alone does not establish that a correction is effective.

Every doctor report includes this manual check. For an optional English prompt:

```sh
antigo doctor --guided
```

Or provide what the page actually shows, for this report only:

```sh
antigo doctor --account-region CN --compare-curl --json
```

No account cookies, browser profiles or tokens are read, and the answer is not
saved. Empty answers remain Unknown. A reported mainland China association is
flagged against the official list reviewed on 2026-11-08, with a link to recheck
the current policy. Other names are not automatically labeled eligible. The
unauthenticated HTTPS probes cannot diagnose account-country eligibility, and
an account-country finding does not explain their transport failures.

## Distribution and development

macOS uses independent version numbers and a signed preview feed under
`macos/preview/` in the public downloads repository. Releases use tags such as
`macos-v0.1.0` and never replace Windows' latest stable release. Updates preserve
the proxy binding and switch between immutable per-version directories; rollback
re-verifies the saved package before activation. Update operations can briefly
interrupt the local bridge. Antigo updates are manual in this preview.

Version 0.1.3 adds a public GitHub asset API fallback for release-download outages.
The installer retries a failed binary download through that API; the updater uses
it for temporary HTTP errors or timeouts. Both keep the same signed version,
architecture and SHA-256 checks. No GitHub token is required; public API rate
limits still apply. If an older `antigo update` fails with HTTP 504, rerun the
one-line installer above to obtain the download fix and preserve your binding.

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

### Enforcing process-level network policy on macOS

A stronger edition needs a signed Network Extension, for example a transparent
app proxy with explicit handling for TCP and UDP and application identity checks.
This is separate from the current publisher-signed CLI. Apple requires the
appropriate Network Extension entitlement and provisioning, Developer ID signing
for direct distribution, and system-extension activation/approval. The extension
must also handle helper identity, proxy outages, DNS, IPv6 and UDP policy before
claiming enforcement. A simple environment variable, DYLD injection into a
hardened third-party app, or an unscoped system firewall rule is not a substitute.
No such extension is installed or advertised as active by this preview.

Network references: [Electron switches](https://www.electronjs.org/docs/latest/api/command-line-switches),
[gRPC Core proxy mapping](https://grpc.github.io/grpc/core/md_doc_core_default_http_proxy_mapper.html),
[Chromium QUIC switch](https://chromium.googlesource.com/chromium/src/+/main/components/network_session_configurator/common/network_switch_list.h),
[Chromium WebRTC switch](https://chromium.googlesource.com/chromium/src/+/main/content/public/common/content_switches.cc),
and [Apple Network Extension deployment](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment).
