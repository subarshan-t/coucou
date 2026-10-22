#!/usr/bin/env bash
# Builds Giraffy the way it runs every day (Release, signed) and makes it the only Giraffy:
# installed in /Applications, the copies left by earlier builds removed.
#
# Why: macOS gives its permissions (Accessibility, Screen Recording, microphone...) to one
# app signed one way. An unsigned Debug build looks like a new app after every build, and
# each copy of Giraffy.app is one more entry to allow. One signed app at one place keeps
# its permissions from one build to the next.
#
#   GIRAFFY_TEAM_ID=ABCDE12345 ./scripts/dev-install.sh
#
# GIRAFFY_TEAM_ID is your Apple Developer team ID (Xcode → Settings → Accounts). With it the
# app is signed with your Apple Development certificate and keeps its permissions across
# builds. Without it the app is signed to run locally (ad hoc), and macOS may ask for
# permissions again after each build.
#
# Use it instead of xcodebuild by hand or ▶ in Xcode (which leave copies in DerivedData).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="au.com.purplegiraffe.Giraffy"
DERIVED="${HOME}/Library/Developer/Xcode/DerivedData/GiraffyDev"
BUILT="${DERIVED}/Build/Products/Release/Giraffy.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

TARGET="/Applications/Giraffy.app"
if [ -d "${TARGET}" ]; then
  EXISTING=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${TARGET}/Contents/Info.plist" 2>/dev/null || echo "")
  if [ "${EXISTING}" != "${BUNDLE_ID}" ]; then
    mkdir -p "${HOME}/Applications"
    TARGET="${HOME}/Applications/Giraffy.app"
    echo "/Applications/Giraffy.app is another app (${EXISTING}): installing in ~/Applications instead."
  fi
fi

SIGNING=()
if [ -n "${GIRAFFY_TEAM_ID:-}" ]; then
  SIGNING=(DEVELOPMENT_TEAM="${GIRAFFY_TEAM_ID}" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" -allowProvisioningUpdates)
  echo "Building (Release, signed for team ${GIRAFFY_TEAM_ID})..."
else
  echo "Building (Release, signed to run locally; set GIRAFFY_TEAM_ID to keep permissions across builds)..."
fi
cd "${REPO_ROOT}/NotchBuddy"
xcodegen >/dev/null
xcodebuild -scheme NotchBuddy -configuration Release \
  -derivedDataPath "${DERIVED}" -quiet build ${SIGNING[@]+"${SIGNING[@]}"}

echo "Quitting Giraffy..."
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5; do pgrep -x Giraffy >/dev/null || break; sleep 1; done
pkill -x Giraffy 2>/dev/null || true

echo "Installing in ${TARGET}..."
rm -rf "${TARGET}"
ditto "${BUILT}" "${TARGET}"

# The build stays in DerivedData for the next (incremental) build, but macOS must not
# count it as another Giraffy. Copies from Xcode's own builds (▶, xcodebuild by hand) go.
"${LSREGISTER}" -u "${BUILT}" >/dev/null 2>&1 || true
for old in "${HOME}"/Library/Developer/Xcode/DerivedData/NotchBuddy-*/Build/Products/*/Giraffy.app; do
  [ -d "$old" ] || continue
  "${LSREGISTER}" -u "$old" >/dev/null 2>&1 || true
  rm -rf "$old"
  echo "Removed an old build: $old"
done
"${LSREGISTER}" -f "${TARGET}" >/dev/null 2>&1 || true

# Sounds: Coucou's, copied into Giraffy's custom sounds folder on this Mac only (personal
# use is allowed by LICENSE-ASSETS.md; they are never put in the app or the repo).
# GIRAFFY_SOUNDS=none skips this; an existing file in the folder is never overwritten.
if [ "${GIRAFFY_SOUNDS:-coucou}" = "coucou" ]; then
  SOUNDS="${HOME}/Library/Application Support/Giraffy/Sounds"
  REF="1e51809"   # the Coucou commit Giraffy was forked from
  cd "${REPO_ROOT}"
  git cat-file -e "${REF}^{commit}" 2>/dev/null || git fetch --quiet https://github.com/Louis-CFM/coucou.git main || true
  if git cat-file -e "${REF}^{commit}" 2>/dev/null; then
    mkdir -p "${SOUNDS}"
    added=0
    for path in $(git ls-tree --name-only "${REF}" NotchBuddy/Resources/sounds/); do
      out="${SOUNDS}/$(basename "${path}")"
      [ -e "${out}" ] && continue
      git show "${REF}:${path}" > "${out}"
      added=$((added + 1))
    done
    echo "Sounds: ${added} added to ${SOUNDS}."
  else
    echo "Sounds: couldn't get Coucou's sounds (no network?); Giraffy stays silent."
  fi
fi

open "${TARGET}"
echo "Giraffy is running from ${TARGET}."
