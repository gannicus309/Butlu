#!/bin/zsh
# Keeps Butlu alive on the family's iPhones despite free Apple ID signing,
# whose builds stop opening after 7 days.
#
# When the installed build has fewer than MIN_DAYS_LEFT days left, this
# throws away the old provisioning profile, rebuilds (Xcode makes a fresh
# 7-day profile), and reinstalls on every paired iPhone it can reach --
# over USB or the same Wi-Fi. Phones it can't reach are retried next run.
# Cheap when there's nothing to do, so it's fine to run often.
#
#   tool/resign.sh            re-sign only if needed
#   tool/resign.sh --force    re-sign now
#
# Installed as a login item by tool/install_resign_agent.sh.

set -u
REPO="${0:A:h:h}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
MIN_DAYS_LEFT="${MIN_DAYS_LEFT:-3}"
BUNDLE_ID="com.butlu.butlu"
STATE="$HOME/Library/Application Support/Butlu"
DD="$REPO/build/resign"
APP="$DD/Build/Products/Release-iphoneos/Runner.app"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

mkdir -p "$STATE"
LOG="$STATE/resign.log"
exec >>"$LOG" 2>&1
log() { print -r -- "$(date '+%F %T') $*"; }
notify() {
  osascript -e "display notification \"$2\" with title \"Butlu re-sign\" subtitle \"$1\"" >/dev/null 2>&1
}

# One run at a time (login and the timer can overlap).
LOCK="$STATE/resign.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  # A crashed run leaves the lock behind; ignore one older than 2 hours.
  if [[ -n "$(find "$LOCK" -maxdepth 0 -mmin +120 2>/dev/null)" ]]; then
    rmdir "$LOCK"; mkdir "$LOCK"
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# Seconds until a profile (or a built app's embedded one) expires.
seconds_left() {
  local exp
  exp=$(security cms -D -i "$1" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null) || return 1
  print $(( $(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$exp" +%s) - $(date +%s) ))
}
MIN_SECONDS=$(( MIN_DAYS_LEFT * 86400 ))

# Paired physical iPhones/iPads: "udid<TAB>name" per line.
devices() {
  local json="$STATE/devices.json"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || return
  /usr/bin/python3 -I - "$json" <<'EOF'
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    hw, cp = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("platform") == "iOS" \
            and cp.get("pairingState") == "paired":
        print(f'{hw["udid"]}\t{d.get("deviceProperties", {}).get("name", hw["udid"])}')
EOF
}

# Which devices need a fresh build? Tracked per device: the expiry of the
# build we last installed there.
typeset -a todo
while IFS=$'\t' read -r udid name; do
  [[ -z "$udid" ]] && continue
  stamp="$STATE/expires-$udid"
  left=0
  [[ -f "$stamp" ]] && left=$(( $(<"$stamp") - $(date +%s) ))
  if (( FORCE || left < MIN_SECONDS )); then
    todo+=("$udid"$'\t'"$name")
  fi
done < <(devices)

(( ${#todo} == 0 )) && exit 0
log "Needs re-signing: ${(j:, :)${todo[@]#*$'\t'}}"

# Reuse the last build if its profile is still fresh enough (e.g. a phone
# was off Wi-Fi last time); otherwise build again with a brand-new profile.
app_left=$(seconds_left "$APP/embedded.mobileprovision" 2>/dev/null || print 0)
if (( FORCE || app_left < MIN_SECONDS )); then
  # Without this, Xcode reuses the cached profile and its old expiry date.
  for p in "$PROFILES"/*.mobileprovision(N); do
    if security cms -D -i "$p" 2>/dev/null | grep -q "\.$BUNDLE_ID<"; then
      log "Removing old profile ${p:t}"
      rm -f "$p"
    fi
  done
  version="$(sed -n 's/^version: *//p' "$REPO/pubspec.yaml")"
  log "Building Butlu ${version%+*} (${version#*+})"
  cd "$REPO" || exit 1
  # Which code this is, for More → About ("+changes": not yet committed).
  commit="$(git rev-parse --short HEAD 2>/dev/null || print unknown)"
  [[ -n "$(git status --porcelain 2>/dev/null)" ]] && commit+="+changes"
  if ! flutter build ios --release --config-only --dart-define-from-file=dart_define.json \
      --dart-define=BUTLU_COMMIT="$commit" \
      --dart-define=BUTLU_BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      || ! (cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
          -configuration Release -destination 'generic/platform=iOS' \
          -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
          -derivedDataPath "$DD" FLUTTER_BUILD_MODE=release build -quiet); then
    log "Build failed"
    notify "Build failed" "See ~/Library/Application Support/Butlu/resign.log"
    exit 1
  fi
fi
expires=$(( $(date +%s) + $(seconds_left "$APP/embedded.mobileprovision") ))
until_text=$(date -r "$expires" '+%a %d %b %H:%M')

typeset -a ok failed
for entry in "${todo[@]}"; do
  udid="${entry%%$'\t'*}" name="${entry#*$'\t'}"
  if xcrun devicectl device install app --device "$udid" "$APP" >/dev/null 2>&1; then
    print "$expires" >"$STATE/expires-$udid"
    log "Installed on $name, good until $until_text"
    ok+=("$name")
  else
    # Forget its date so the next run tries this phone again.
    rm -f "$STATE/expires-$udid"
    log "Couldn't reach $name; will retry"
    failed+=("$name")
  fi
done

(( ${#ok} )) && notify "Re-signed on ${(j:, :)ok}" "Good until $until_text"
(( ${#failed} )) && notify "Couldn't reach ${(j:, :)failed}" \
  "Unlock it on the same Wi-Fi; will retry automatically"
exit 0
