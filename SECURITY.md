# Security Policy

## Reporting a vulnerability

Please report security problems privately, through GitHub's private vulnerability reporting: open the [Security tab of kemarachanger/hianti-downloads](https://github.com/kemarachanger/hianti-downloads/security) and choose **Report a vulnerability**. If you cannot use it, open a [GitHub issue](https://github.com/kemarachanger/hianti-downloads/issues) that only says you have a security report, without any details, and wait for a private way to send them.

Include the Antigo version (`antigo --version`), Windows or macOS, and the steps that show the problem. There is no bug bounty.

## Scope

In scope:

- The one-line installers (`install.ps1` and `macos/install.sh`) and how they download and verify a release.
- The `antigo` and `hianti` commands, the background worker and updates, on Windows and on macOS.
- The signed update feeds and release files published here.
- How Antigo sends Antigravity's traffic to your proxy: the proxy module it configures on Windows and the local bridge on macOS.

Out of scope:

- Antigravity itself, Google services and accounts, and your proxy app or its servers. Report those to their makers.
- On macOS, helper processes that ignore proxy settings and connect directly. Antigo reports them but cannot block them (see the macOS guide).
- Attacks that already need administrator rights or control of your user account.

## How releases are signed and verified

- Every release is described by a signed feed: a small JSON file that names the version, the platform, the download address and the SHA-256 checksum of the package. On Windows it also lists every program file with its checksum.
- Feeds are signed with RSA keys of at least 3072 bits (PKCS#1 v1.5 with SHA-256). The public keys are pinned in the installers and in every installed copy of Antigo, and keys are compared by value.
- A second, backup key is pinned as well and kept offline, so updates can continue if the main key is lost.
- The installers and `antigo update` refuse a feed that no pinned key signed and a package whose checksum differs from the feed. This holds whether the download goes through your proxy or directly.
- Releases are signed on the publisher's computer, never in CI, and the private keys are in no repository. Before a release is published, the release scripts check that CI rebuilt the same files from the same source commit.
- Windows packages are not Authenticode-signed and the macOS binaries are not notarized by Apple; the signed feed is what proves where a release comes from.

## Supported versions

Only the latest release of each edition, Windows and the macOS preview, receives security fixes. On Windows the background worker installs new releases on its own. On macOS, run `antigo update`, or run the one-line installer again.
