#!/usr/bin/env bash
# Usage: build.sh [live|build|uninstall-live], default live
# Environment overrides: SKYRIM_DIR, PAPYRUS_COMPILER, PLUGINS_TXT, NUGET_PACKAGES
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-live}"
ESP_BASE="PTX_TrainingDummy"
SHIPPED=(
  PTX_TrainingDummyQuest
  PTX_TrainingDummyAlias
  PTX_TrainingDummySummon
  PTX_TrainingDummyDismiss
)
# Removed in earlier versions; delete leftovers from older installs.
RETIRED=(
  PTX_TrainingDummyBook
  PTX_TrainingDummyMarker
)
GAME="${SKYRIM_DIR:-/c/Program Files (x86)/Steam/steamapps/common/Skyrim Special Edition}"
DATA="$GAME/Data"
PLUGINS_TXT="${PLUGINS_TXT:-$(cygpath -u "${LOCALAPPDATA:-C:\\Users\\white\\AppData\\Local}")/Skyrim Special Edition/plugins.txt}"
DIST="$HERE/dist"
# Prefer the real user NuGet cache; the Cursor sandbox cache is often corrupt.
if [[ -z "${NUGET_PACKAGES:-}" || "$NUGET_PACKAGES" == *cursor-sandbox-cache* ]]; then
  export NUGET_PACKAGES="/c/Users/white/.nuget/packages"
fi

remove_from() {
  local root="$1" script
  rm -f "$root/$ESP_BASE.esp" "$root/Seq/$ESP_BASE.seq"
  for script in "${SHIPPED[@]}" "${RETIRED[@]}"; do
    rm -f "$root/Scripts/$script.pex" "$root/Scripts/Source/$script.psc"
  done
}

warn_if_not_enabled() {
  local esp="$ESP_BASE.esp" lines
  if [[ ! -f "$PLUGINS_TXT" ]]; then
    echo "Warning: couldn't find $PLUGINS_TXT to check whether $esp is enabled." >&2
    return
  fi
  lines="$(tr -d '\r' < "$PLUGINS_TXT")"
  if grep -qixF "*$esp" <<< "$lines"; then
    echo "$esp is enabled in the load order."
  else
    echo "Warning: $esp is not enabled yet. Enable it in Vortex's Plugins tab (F5 if it isn't listed), then start Skyrim." >&2
  fi
}

case "$TARGET" in
  live|build) ;;
  uninstall-live)
    remove_from "$DATA"
    echo "Removed $ESP_BASE from $DATA"
    exit 0
    ;;
  *)
    echo "Unknown target '$TARGET'. Use live, build, or uninstall-live." >&2
    exit 1
    ;;
esac

VERSION="$(tr -d '[:space:]' < "$HERE/VERSION")"

echo "=== compiling $ESP_BASE $VERSION ==="
COMPILER="$(cygpath -w "${PAPYRUS_COMPILER:-$DATA/Nemesis_Engine/Papyrus Compiler/PapyrusCompiler.exe}")"
FLAGS=""
for flg in "$DATA/Source/Scripts/TESV_Papyrus_Flags.flg" "$DATA/Scripts/Source/TESV_Papyrus_Flags.flg"; do
  if [[ -f "$flg" ]]; then
    FLAGS="$(cygpath -w "$flg")"
    break
  fi
done
if [[ -z "$FLAGS" ]]; then
  echo "TESV_Papyrus_Flags.flg not found in $DATA/Source/Scripts or $DATA/Scripts/Source" >&2
  exit 1
fi

IMPORTS="$(cygpath -w "$HERE/Scripts/Source")"
IMPORTS="$IMPORTS;$(cygpath -w "$HERE/Scripts/CompileStubs")"
for dir in "$DATA/Source/Scripts" "$DATA/Scripts/Source"; do
  if [[ -d "$dir" ]]; then
    IMPORTS="$IMPORTS;$(cygpath -w "$dir")"
  fi
done

rm -rf "$DIST"
mkdir -p "$DIST/Scripts"
(
  cd "$HERE/Scripts/Source"
  export MSYS_NO_PATHCONV=1
  for script in "${SHIPPED[@]}"; do
    "$COMPILER" "$script.psc" -f="$FLAGS" -i="$IMPORTS" -o="$(cygpath -w "$DIST/Scripts")" -op
  done
)
for script in "${SHIPPED[@]}"; do
  if [[ ! -f "$DIST/Scripts/$script.pex" ]]; then
    echo "Compile produced no $script.pex" >&2
    exit 1
  fi
done
for pex in "$DIST/Scripts/"*.pex; do
  name="$(basename "$pex" .pex)"
  if [[ " ${SHIPPED[*]} " != *" $name "* ]]; then
    echo "Removing $name.pex from dist (stub leak)."
    rm -f "$pex"
  fi
done

echo "=== generating $ESP_BASE.esp ==="
(
  export MSYS_NO_PATHCONV=1
  dotnet run --project "$(cygpath -w "$HERE/tools/PluginGen/PluginGen.csproj")" -- \
    --out "$(cygpath -w "$DIST/$ESP_BASE.esp")"
)

[[ "$TARGET" == build ]] && { echo "Built $DIST"; exit 0; }

mkdir -p "$DATA/Scripts/Source" "$DATA/Seq"
if ! cp -f "$DIST/$ESP_BASE.esp" "$DATA/"; then
  echo "Couldn't copy $ESP_BASE.esp into $DATA. Quit Skyrim and run this again." >&2
  exit 1
fi
cp -f "$DIST/Seq/$ESP_BASE.seq" "$DATA/Seq/"
for script in "${SHIPPED[@]}"; do
  cp -f "$DIST/Scripts/$script.pex" "$DATA/Scripts/"
  cp -f "$HERE/Scripts/Source/$script.psc" "$DATA/Scripts/Source/"
done
for script in "${RETIRED[@]}"; do
  rm -f "$DATA/Scripts/$script.pex" "$DATA/Scripts/Source/$script.psc"
done
echo "Copied $ESP_BASE $VERSION into $DATA"
warn_if_not_enabled
echo "In game: Summon Male/Female Training Dummy; Dismiss Training Dummy clears it."
