#!/bin/zsh
# Builds the current code and installs it on every paired iPhone in reach,
# with a fresh 7-day signature, then says which version went out.
# Phones out of reach get it automatically on the next re-sign run.
#
# Bump `version:` in pubspec.yaml first (x.y.z+build; build always goes up).
#
#   tool/deploy.sh

set -u
REPO="${0:A:h:h}"
LOG="$HOME/Library/Application Support/Butlu/resign.log"
version="$(sed -n 's/^version: *//p' "$REPO/pubspec.yaml")"
mark=$(wc -l <"$LOG" 2>/dev/null || print 0)

"$REPO/tool/resign.sh" --force
code=$?
tail -n +$((mark + 1)) "$LOG" | grep -v -E '^\s*$|warning:|note:|^\[#|^ *[0-9]+ \||^ *\|' | grep -E '^20[0-9]{2}-[0-9-]+ [0-9:]+ [A-Z]'
commit="$(git -C "$REPO" rev-parse --short HEAD)"
[[ -n "$(git -C "$REPO" status --porcelain)" ]] && commit+="+changes"
print "Butlu ${version%+*} (build ${version#*+}), commit $commit"
exit $code
