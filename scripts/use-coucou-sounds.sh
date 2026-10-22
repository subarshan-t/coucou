#!/usr/bin/env bash
# Copies Coucou's sounds into YOUR Giraffy custom sounds folder, on this Mac only.
#
# The sounds belong to Coucou's author (LICENSE-ASSETS.md): fine to use yourself, but they
# must not be shipped inside Giraffy or handed to others without his written permission.
# That's why they are not in the app: Giraffy plays any file in its custom sounds folder.
#
#   ./scripts/use-coucou-sounds.sh
#
# Then in Giraffy: Settings → General → Sound → turn on "Enable sounds", then "Reload sounds".
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="${HOME}/Library/Application Support/Giraffy/Sounds"
REF="1e51809"   # the Coucou commit Giraffy was forked from (it still has the sounds)

if ! git cat-file -e "${REF}^{commit}" 2>/dev/null; then
  echo "Fetching the Coucou commit that has the sounds..."
  git fetch --quiet https://github.com/Louis-CFM/coucou.git main
fi

mkdir -p "${DEST}"
count=0
for path in $(git ls-tree --name-only "${REF}" NotchBuddy/Resources/sounds/); do
  git show "${REF}:${path}" > "${DEST}/$(basename "${path}")"
  count=$((count + 1))
done
echo "Copied ${count} sounds to ${DEST}"
echo "In Giraffy: Settings → General → Sound → Enable sounds, then Reload sounds."
