#!/bin/bash
set -euo pipefail

fail() { printf 'Antigo: %s\n' "$*" >&2; exit 1; }
say() { printf 'Antigo | %s\n' "$*"; }

main() {
  [ "$(uname -s)" = Darwin ] || fail 'This installer requires macOS.'
  [ "$(id -u)" != 0 ] || fail 'Run as your normal Mac user, without sudo.'
  local architecture home_path no_start no_path no_watch app_path port work
  architecture=$(uname -m)
  case "$architecture" in
    arm64) architecture=arm64 ;;
    x86_64)
      if [ "$(/usr/sbin/sysctl -in hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
        architecture=arm64
      else
        architecture=amd64
      fi ;;
    *) fail 'Supported architectures: Apple Silicon and Intel x64.' ;;
  esac
  home_path=${ANTIGO_HOME:-${HIANTI_HOME:-"$HOME/Library/Application Support/Antigo"}}
  no_start=0; no_path=0; no_watch=0; app_path=''; port=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-start) no_start=1; shift ;;
      --no-path) no_path=1; shift ;;
      --no-watch) no_watch=1; shift ;;
      --home|--app|--port)
        [ "$#" -ge 2 ] || fail "Missing value for $1"
        case "$1" in --home) home_path=$2 ;; --app) app_path=$2 ;; --port) port=$2 ;; esac
        shift 2 ;;
      --help|-h)
        printf '%s\n' 'Antigo macOS preview installer' 'Options: --no-start --no-path --no-watch --home PATH --app PATH --port PORT'
        return ;;
      *) fail "Unknown installer option: $1" ;;
    esac
  done
  [ -n "$home_path" ] || fail 'The installation directory cannot be empty.'
  work=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/antigo-install.XXXXXXXX")
  # Only this fresh, private temporary directory is removed on exit.
  trap 'if [ -n "${work:-}" ] && [ -d "$work" ]; then /bin/rm -rf -- "$work"; fi' EXIT
  /bin/chmod 700 "$work"
  local feed release_version release_platform checksum package_url actual_hash
  feed="https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/preview/feed-$architecture.json"
  fetch() { /usr/bin/curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 15 --max-time 120 --max-filesize "$3" "$1" -o "$2"; }
  say 'Downloading the latest signed macOS preview'
  fetch "$feed" "$work/feed.json" 131072
  fetch "$feed.sig" "$work/feed.json.sig" 8192
  /bin/cat > "$work/public.pem" <<'ANTIGO_PUBLIC_KEY'
-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAmtCzXlSbGt6rwUAUYvZikJlQm1jROklh
WBT9fcUAA0dsN4DKJtw7H3QZf5yKSYIDGpGswOGITruCSFfP4msIJA5RVVMA8/Blp7dQW1E75jDU
xGDKSmYYkIkUl4didn16BKzPwZ9ybBNz421HtUw9lZ6YhN2bREX2DCpluaP+o9KYnjpH6i6lRO2t
zoJoYjfcfbTIkncILTjMYtu9Hleojg6qA2VAo9ZUibjrbftisPcMr0JcrSyTKZNd0To6UmzNYTWI
uU6TRYkr3dA3iasIGhWEXAVldbhFLqW+3vVOTF7T1bdlCWP5HYWbkEQZb2KJbAABJcl2ibaaItDP
kWwdPHQRaPmiDawFht26bOheFpbXjC7arDVL1+IaFbkDZc+uYNa2vcBNg9Txbt+en71nbWUs3Qqg
cDt2Am7ayJ1Ya6m4kxdBPWa+vEJE93onOK69WLAL+ytqF5LTi9eEKR8lqtK3wKOrdDvOHChlZI50
S1y+URvFM1XjnNEsoChy5jcFAgMBAAE=
-----END PUBLIC KEY-----
ANTIGO_PUBLIC_KEY
  /usr/bin/openssl base64 -d -A -in "$work/feed.json.sig" -out "$work/signature.bin"
  /usr/bin/openssl dgst -sha256 -verify "$work/public.pem" -signature "$work/signature.bin" "$work/feed.json" >/dev/null 2>&1 || fail 'Release signature verification failed.'
  field() { /usr/bin/plutil -extract "$1" raw -o - "$work/feed.json"; }
  [ "$(field schema)" = 1 ] || fail 'Unsupported feed schema.'
  release_version=$(field version)
  release_platform=$(field platform)
  checksum=$(field sha256)
  package_url=$(field url)
  [[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Invalid release version.'
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail 'Invalid package checksum.'
  [ "$release_platform" = "macos-$architecture" ] || fail 'Release architecture mismatch.'
  [ "$package_url" = "https://github.com/kemarachanger/hianti-downloads/releases/download/macos-v$release_version/antigo-$release_version-macos-$architecture" ] || fail 'Unexpected package location.'
  fetch "$package_url" "$work/antigo" 33554432
  actual_hash=$(/usr/bin/shasum -a 256 "$work/antigo")
  actual_hash=${actual_hash%% *}
  [ "$actual_hash" = "$checksum" ] || fail 'Package checksum verification failed.'
  /bin/chmod 700 "$work/antigo"
  say 'Signature and package verified'
  local install_args start_args
  install_args=(install --home "$home_path" --manifest "$work/feed.json" --signature "$work/feed.json.sig")
  [ "$no_path" = 0 ] || install_args+=(--no-path)
  "$work/antigo" "${install_args[@]}"
  if [ "$no_start" = 0 ]; then
    start_args=(start)
    [ "$no_watch" = 0 ] || start_args+=(--no-watch)
    [ -z "$app_path" ] || start_args+=(--app "$app_path")
    [ -z "$port" ] || start_args+=(--port "$port")
    say 'Detecting Antigravity and your local SOCKS5 proxy'
    if ! "$home_path/bin/antigo" "${start_args[@]}"; then
      say 'Installation is complete; setup needs attention. Resolve the message above, then run antigo.'
    fi
  fi
  say 'Ready. Use antigo status to inspect your setup; hianti also works.'
  if [ "$no_path" = 0 ]; then
    printf '%s\n' 'For this terminal: export PATH="$HOME/.local/bin:$PATH"'
  else
    printf 'Command: %s/bin/antigo\n' "$home_path"
  fi
  # EXIT traps run after local variables leave scope on some shells.
  /bin/rm -rf -- "$work"
  trap - EXIT
}

main "$@"
