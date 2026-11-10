#!/bin/bash
set -euo pipefail

fail() { printf 'Antigo: %s\n' "$*" >&2; exit 1; }
say() { printf 'Antigo | %s\n' "$*"; }
# The SOCKS5 proxy for downloads, socks5h://HOST:PORT, from --proxy.
download_proxy=''
# The HTTP status of the last download, 000 when no server answered.
http_status=''
# curl_fetch URL OUTPUT MAX_BYTES ACCEPT [CURL_OPTION...] sets http_status. Top level so tests can replace it.
curl_fetch() { http_status=$(/usr/bin/curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 15 --max-time 120 --max-filesize "$3" -H "Accept: $4" --write-out '%{http_code}' "${@:5}" "$1" -o "$2"); }
# fetch URL OUTPUT MAX_BYTES [ACCEPT]. Top level so tests can replace it.
# With --proxy it downloads through that proxy, which resolves the host
# names. If the proxy cannot be reached or a download through it breaks off,
# this and later downloads go directly; the signature and checksum checks
# apply either way.
fetch() {
  local status=0
  if [ -n "$download_proxy" ]; then
    curl_fetch "$1" "$2" "$3" "${4:-application/octet-stream}" --proxy "$download_proxy" || status=$?
    # 22 is an HTTP error and 63 a file over the size limit: the server answered.
    case "$status" in 0|22|63) return "$status" ;; esac
    say "The proxy at ${download_proxy#socks5h://} did not connect; downloading directly"
    download_proxy=''
  fi
  curl_fetch "$1" "$2" "$3" "${4:-application/octet-stream}"
}
# proxy_url VALUE prints the curl proxy for --proxy HOST:PORT or
# socks5h://HOST:PORT; socks5h means that the proxy resolves host names.
proxy_url() {
  local address pattern='^([A-Za-z0-9.-]+|\[[0-9A-Fa-f:.]+\]):([0-9]{1,5})$'
  address=${1#socks5h://}
  address=${address#socks5://}
  if ! [[ "$address" =~ $pattern ]] || [ "${BASH_REMATCH[2]}" -lt 1 ] || [ "${BASH_REMATCH[2]}" -gt 65535 ]; then
    fail "Use --proxy HOST:PORT with your proxy app's SOCKS5 port, for example --proxy 127.0.0.1:7890."
  fi
  printf 'socks5h://%s\n' "$address"
}

asset_api_url() {
  local metadata version platform expected tag draft index name selected asset_id asset_size asset_state
  metadata=$1; version=$2; platform=$3
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Invalid release version.'
  case "$platform" in macos-arm64|macos-amd64) ;; *) fail 'Invalid asset platform.' ;; esac
  expected="antigo-$version-$platform"
  tag=$(/usr/bin/plutil -extract tag_name raw -o - "$metadata") || fail 'Invalid release metadata.'
  draft=$(/usr/bin/plutil -extract draft raw -o - "$metadata") || fail 'Invalid release metadata.'
  if ! { [ "$tag" = "macos-v$version" ] && [ "$draft" = false ]; }; then fail 'Unexpected GitHub release metadata.'; fi
  index=0; selected=''
  while name=$(/usr/bin/plutil -extract "assets.$index.name" raw -o - "$metadata" 2>/dev/null); do
    [ "$index" -lt 128 ] || fail 'Too many release assets.'
    if [ "$name" = "$expected" ]; then
      [ -z "$selected" ] || fail 'Duplicate release asset.'
      asset_id=$(/usr/bin/plutil -extract "assets.$index.id" raw -o - "$metadata")
      asset_size=$(/usr/bin/plutil -extract "assets.$index.size" raw -o - "$metadata")
      asset_state=$(/usr/bin/plutil -extract "assets.$index.state" raw -o - "$metadata")
      [[ "$asset_id" =~ ^[1-9][0-9]{0,17}$ ]] || fail 'Invalid asset ID.'
      [[ "$asset_size" =~ ^[1-9][0-9]{0,8}$ ]] || fail 'Invalid asset size.'
      if ! { [ "$asset_size" -le 33554432 ] && [ "$asset_state" = uploaded ]; }; then fail 'Invalid release asset.'; fi
      selected="https://api.github.com/repos/kemarachanger/hianti-downloads/releases/assets/$asset_id"
    fi
    index=$((index+1))
  done
  [ -n "$selected" ] || fail 'Signed package not found in the GitHub release.'
  printf '%s\n' "$selected"
}

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
      --home|--app|--port|--proxy)
        [ "$#" -ge 2 ] || fail "Missing value for $1"
        case "$1" in
          --home) home_path=$2 ;;
          --app) app_path=$2 ;;
          --port) port=$2 ;;
          --proxy) download_proxy=$(proxy_url "$2") || exit 1 ;;
        esac
        shift 2 ;;
      --help|-h)
        printf '%s\n' 'Antigo macOS preview installer' 'Options: --no-start --no-path --no-watch --home PATH --app PATH --port PORT --proxy HOST:PORT'
        return ;;
      *) fail "Unknown installer option: $1" ;;
    esac
  done
  [ -n "$home_path" ] || fail 'The installation directory cannot be empty.'
  work=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/antigo-install.XXXXXXXX")
  # Only this fresh, private temporary directory is removed on exit.
  trap 'if [ -n "${work:-}" ] && [ -d "$work" ]; then /bin/rm -rf -- "$work"; fi' EXIT
  /bin/chmod 700 "$work"
  local feed feed_schema status release_version release_platform checksum package_url actual_hash
  feed="https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/preview/feed-v2-$architecture.json"
  feed_schema=2
  if [ -n "$download_proxy" ]; then
    say "Downloading the latest signed macOS preview through the proxy at ${download_proxy#socks5h://}"
  else
    say 'Downloading the latest signed macOS preview'
  fi
  status=0
  fetch "$feed" "$work/feed.json" 131072 || status=$?
  if [ "$status" = 22 ] && [ "$http_status" = 404 ]; then
    # Before the first v2 release only the v1 feed exists. Any other error
    # stops here, so a passing server error never installs the frozen v1 release.
    feed="https://raw.githubusercontent.com/kemarachanger/hianti-downloads/main/macos/preview/feed-$architecture.json"
    feed_schema=1
    fetch "$feed" "$work/feed.json" 131072
  elif [ "$status" != 0 ]; then
    exit "$status"
  fi
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
  # The backup signing key, which can sign releases if the primary key is lost.
  /bin/cat > "$work/backup.pem" <<'ANTIGO_BACKUP_KEY'
-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA4tGwwg3NIScQVp7YeD1g9HvJUjLalUGH
WmP+gXYNEVVEv2orIh+ykhr4smqHO4pfnXJEKqZ5Mm0TzPnYW2rzt11zKi+7poo+3m0C2slUroa4
9ss9AQFT9vX/jFJvXRec7IqhLY9rq6+ED30YwUxQPjZkIZ+wftMKlnGhmWOrBo2F4ld1D37dJcBJ
FiPTdYWLfEfGcwvHg9uLqOApYTYZdzfCGttO3f4vY769wldOjLXXGztVFQWqtUl6BNuFpOSax0jZ
CMbccJPnLktGljo/UzR41UP6tUXt3BXMXUDAPHWS+cvlQ8+nYS16A1UjJAfjSqInaM3GwIPtj9at
PWf1QGJ4mW4aXVwK/3vrcny3pF6jkc0II73JwFRiPuWatrG61FEZgsLLAWgDew4aHWHRRKF7m15G
1iKW1JKtPMinAUYIjxJIiSj1cEjoen0mnPShF2Duvi2S4nWmKex1tTAGrVI/5QkUPSGs+oMJvSQ8
m+SbwMlDV9YCTWKD+9p/SM7FAgMBAAE=
-----END PUBLIC KEY-----
ANTIGO_BACKUP_KEY
  /usr/bin/openssl base64 -d -A -in "$work/feed.json.sig" -out "$work/signature.bin"
  local key verified=0
  for key in "$work/public.pem" "$work/backup.pem"; do
    if /usr/bin/openssl dgst -sha256 -verify "$key" -signature "$work/signature.bin" "$work/feed.json" >/dev/null 2>&1; then
      verified=1
      break
    fi
  done
  [ "$verified" = 1 ] || fail 'Release signature verification failed.'
  field() { /usr/bin/plutil -extract "$1" raw -o - "$work/feed.json"; }
  # The v2 feed may gain fields; only these are read.
  [ "$(field schema)" = "$feed_schema" ] || fail 'Unsupported feed schema.'
  release_version=$(field version)
  release_platform=$(field platform)
  checksum=$(field sha256)
  package_url=$(field url)
  [[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Invalid release version.'
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail 'Invalid package checksum.'
  [ "$release_platform" = "macos-$architecture" ] || fail 'Release architecture mismatch.'
  [ "$package_url" = "https://github.com/kemarachanger/hianti-downloads/releases/download/macos-v$release_version/antigo-$release_version-macos-$architecture" ] || fail 'Unexpected package location.'
  if ! fetch "$package_url" "$work/antigo" 33554432; then
    say 'Release download unavailable; trying the official GitHub asset API'
    fetch "https://api.github.com/repos/kemarachanger/hianti-downloads/releases/tags/macos-v$release_version" "$work/release.json" 2097152 application/vnd.github+json
    local api_url
    api_url=$(asset_api_url "$work/release.json" "$release_version" "macos-$architecture")
    fetch "$api_url" "$work/antigo" 33554432 application/octet-stream
  fi
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
    say 'Detecting your local SOCKS5 proxy and launching Antigravity'
    if ! "$home_path/bin/antigo" "${start_args[@]}"; then
      say 'Installation is complete; setup needs attention. Resolve the message above, then run antigo.'
    fi
  fi
  say 'Ready. Use antigo status to inspect your setup; hianti also works.'
  # The hint applies only when ~/.local/bin/antigo is this installation's.
  if [ "$no_path" = 0 ] && [ "${HOME:-}/.local/bin/antigo" -ef "$home_path/bin/antigo" ]; then
    # The user runs this line, so $HOME stays literal.
    # shellcheck disable=SC2016
    printf '%s\n' 'For this terminal: export PATH="$HOME/.local/bin:$PATH"'
  else
    printf 'Command: %s/bin/antigo\n' "$home_path"
  fi
  # EXIT traps run after local variables leave scope on some shells.
  /bin/rm -rf -- "$work"
  trap - EXIT
}

if [[ "${BASH_SOURCE[0]:-$0}" = "$0" ]]; then main "$@"; fi
