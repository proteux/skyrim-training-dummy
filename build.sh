#!/usr/bin/env bash
# Usage: build.sh [live|build|uninstall-live], default live
# Environment overrides: SKYRIM_DIR, PAPYRUS_COMPILER, PLUGINS_TXT, NUGET_PACKAGES, VCPKG_ROOT
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-live}"
if [[ -f "$HERE/build.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HERE/build.local.sh"
fi
ESP_BASE="PTX_TrainingDummy"
DLL_NAME="TrainingDummyUI"
SHIPPED=(
  PTX_TrainingDummyQuest
  PTX_TrainingDummyAlias
  PTX_TrainingDummySummon
  PTX_TrainingDummyDismiss
  TrainingDummyUI
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
SKSE="$HERE/skse"
LIVE_DLL="$DATA/SKSE/Plugins/$DLL_NAME.dll"
# Prefer the real user NuGet cache; the Cursor sandbox cache is often corrupt.
if [[ -z "${NUGET_PACKAGES:-}" || "$NUGET_PACKAGES" == *cursor-sandbox-cache* ]]; then
  export NUGET_PACKAGES="/c/Users/white/.nuget/packages"
fi
if [[ -z "${VCPKG_ROOT:-}" ]] && command -v vcpkg > /dev/null; then
  VCPKG_ROOT="$(dirname "$(command -v vcpkg)")"
fi
export VCPKG_ROOT="${VCPKG_ROOT:-}"

FACEGEOM_REL="meshes/actors/character/FaceGenData/FaceGeom/$ESP_BASE.esp"
FACETINT_REL="textures/actors/character/FaceGenData/FaceTint/$ESP_BASE.esp"

remove_from() {
  local root="$1" script
  rm -f "$root/$ESP_BASE.esp" "$root/Seq/$ESP_BASE.seq"
  rm -f "$root/SKSE/Plugins/$DLL_NAME.dll" "$root/SKSE/Plugins/$DLL_NAME.pdb"
  for script in "${SHIPPED[@]}" "${RETIRED[@]}"; do
    rm -f "$root/Scripts/$script.pex" "$root/Scripts/Source/$script.psc"
  done
  rm -rf "$root/$FACEGEOM_REL" "$root/$FACETINT_REL"
}

install_facegen() {
  local dest_root="$1"
  local src_geom="$HERE/Data/$FACEGEOM_REL"
  local src_tint="$HERE/Data/$FACETINT_REL"
  # Wipe dest first so dropped overrides (e.g. male default head) don't linger.
  rm -rf "$dest_root/$FACEGEOM_REL" "$dest_root/$FACETINT_REL"
  if [[ ! -d "$src_geom" && ! -d "$src_tint" ]]; then
    return
  fi
  if [[ -d "$src_geom" ]]; then
    mkdir -p "$dest_root/$FACEGEOM_REL"
    cp -f "$src_geom/"*.nif "$dest_root/$FACEGEOM_REL/" 2>/dev/null || true
  fi
  if [[ -d "$src_tint" ]]; then
    mkdir -p "$dest_root/$FACETINT_REL"
    cp -f "$src_tint/"*.dds "$dest_root/$FACETINT_REL/" 2>/dev/null || true
  fi
  echo "Installed FaceGen under $FACEGEOM_REL / $FACETINT_REL"
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

skyrim_holds_dll() {
  if MSYS_NO_PATHCONV=1 tasklist.exe /FI "IMAGENAME eq SkyrimSE.exe" /NH 2> /dev/null | grep -qi "SkyrimSE.exe"; then
    return 0
  fi
  [[ -f "$LIVE_DLL" ]] && ! (: >> "$LIVE_DLL") 2> /dev/null
}

case "$TARGET" in
  live|build) ;;
  uninstall-live)
    remove_from "$DATA"
    echo "Removed $ESP_BASE / $DLL_NAME from $DATA"
    echo "Settings in $DATA/SKSE/Plugins/TrainingDummyUI were kept."
    exit 0
    ;;
  *)
    echo "Unknown target '$TARGET'. Use live, build, or uninstall-live." >&2
    exit 1
    ;;
esac

VERSION="$(tr -d '[:space:]' < "$HERE/VERSION")"

if [[ "$TARGET" == "live" ]] && skyrim_holds_dll; then
  echo "Skyrim is running and has $DLL_NAME.dll locked. Quit Skyrim to desktop, then rerun." >&2
  exit 2
fi

if [[ ! -x "${VCPKG_ROOT}/vcpkg.exe" ]]; then
  echo "vcpkg not found. Set VCPKG_ROOT to your vcpkg folder, in the environment or in build.local.sh." >&2
  exit 1
fi

tool_dir() { dirname "$(cygpath -u "$("$VCPKG_ROOT/vcpkg.exe" fetch "$1" 2>/dev/null | tail -1)")"; }
command -v cmake > /dev/null || PATH="$(tool_dir cmake):$PATH"
command -v ninja > /dev/null || PATH="$(tool_dir ninja):$PATH"
export PATH

echo "=== building $DLL_NAME $VERSION ==="
export MSYS_NO_PATHCONV=1
MSVC="$SKSE/tools/msvc.cmd"
(
  cd "$SKSE"
  "$MSVC" cmake --preset release
  "$MSVC" cmake --build --preset release
)
unset MSYS_NO_PATHCONV

BUILD_DIR="${TDUI_BUILD_DIR:-/g/CursorBuilds/skyrim-training-dummy-ui/release}"
BUILD_DLL="$BUILD_DIR/$DLL_NAME.dll"
if [[ ! -f "$BUILD_DLL" ]]; then
  echo "CMake build produced no $DLL_NAME.dll at $BUILD_DLL" >&2
  exit 1
fi

echo "=== compiling $ESP_BASE scripts ==="
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
mkdir -p "$DIST/Scripts" "$DIST/SKSE/Plugins"
cp -f "$BUILD_DLL" "$DIST/SKSE/Plugins/"
if [[ -f "$BUILD_DIR/$DLL_NAME.pdb" ]]; then
  cp -f "$BUILD_DIR/$DLL_NAME.pdb" "$DIST/SKSE/Plugins/"
fi

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

echo "=== syncing FaceGen from CharGen ==="
python "$HERE/tools/sync_facegen.py" --skyrim-data "$DATA" --repo-data "$HERE/Data"

echo "=== generating $ESP_BASE.esp ==="
(
  export MSYS_NO_PATHCONV=1
  dotnet run --project "$(cygpath -w "$HERE/tools/PluginGen/PluginGen.csproj")" -- \
    --out "$(cygpath -w "$DIST/$ESP_BASE.esp")"
)

install_facegen "$DIST"

[[ "$TARGET" == build ]] && { echo "Built $DIST"; exit 0; }

mkdir -p "$DATA/Scripts/Source" "$DATA/Seq" "$DATA/SKSE/Plugins"
install_facegen "$DATA"
if ! cp -f "$DIST/$ESP_BASE.esp" "$DATA/"; then
  echo "Couldn't copy $ESP_BASE.esp into $DATA. Quit Skyrim and run this again." >&2
  echo "FaceGen (if any) was still installed; only the esp/scripts/DLL need a rerun." >&2
  exit 1
fi
cp -f "$DIST/Seq/$ESP_BASE.seq" "$DATA/Seq/"
cp -f "$DIST/SKSE/Plugins/$DLL_NAME.dll" "$DATA/SKSE/Plugins/"
if [[ -f "$DIST/SKSE/Plugins/$DLL_NAME.pdb" ]]; then
  cp -f "$DIST/SKSE/Plugins/$DLL_NAME.pdb" "$DATA/SKSE/Plugins/"
fi
for script in "${SHIPPED[@]}"; do
  cp -f "$DIST/Scripts/$script.pex" "$DATA/Scripts/"
  cp -f "$HERE/Scripts/Source/$script.psc" "$DATA/Scripts/Source/"
done
for script in "${RETIRED[@]}"; do
  rm -f "$DATA/Scripts/$script.pex" "$DATA/Scripts/Source/$script.psc"
done
echo "Copied $ESP_BASE / $DLL_NAME $VERSION into $DATA"
warn_if_not_enabled
echo "In game: Mod Control Panel → Training Dummy, or Summon Male/Female Training Dummy spells."
