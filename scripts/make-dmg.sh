#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_PATH="${APP_PATH:-$ROOT_DIR/UsualToneOfVoice.app}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/UsualToneOfVoice.dmg}"
VOLNAME="${VOLNAME:-UsualToneOfVoice}"
IDENTITY="${IDENTITY:-Developer ID Application: Masami Asai (4UHLVJTQU2)}"
PROFILE="${PROFILE:-AC_PROFILE}"
WINDOW_POS="${WINDOW_POS:-200 120}"
WINDOW_SIZE="${WINDOW_SIZE:-660 400}"
ICON_SIZE="${ICON_SIZE:-96}"
APP_ICON_POS="${APP_ICON_POS:-180 170}"
APPS_LINK_POS="${APPS_LINK_POS:-480 170}"
TEXT_SIZE="${TEXT_SIZE:-12}"
SKIP_FINDER_PRETTIFY="${SKIP_FINDER_PRETTIFY:-0}"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not found. Install with: brew install create-dmg" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

if [[ -z "$IDENTITY" ]]; then
  echo "IDENTITY is required (Developer ID Application: ...)." >&2
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  echo "PROFILE is required (notarytool keychain profile)." >&2
  exit 1
fi

STAGE_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

rm -f "$DMG_PATH"

cp -R "$APP_PATH" "$STAGE_DIR/"

APP_NAME="$(basename "$APP_PATH")"

CREATE_DMG_ARGS=(
  --volname "$VOLNAME" \
  --window-pos $WINDOW_POS \
  --window-size $WINDOW_SIZE \
  --icon-size "$ICON_SIZE" \
  --icon "$APP_NAME" $APP_ICON_POS \
  --hide-extension "$APP_NAME" \
  --app-drop-link $APPS_LINK_POS \
  --text-size "$TEXT_SIZE" \
)

if [[ "$SKIP_FINDER_PRETTIFY" == "1" ]]; then
  CREATE_DMG_ARGS+=(--skip-jenkins)
fi

create-dmg \
  "${CREATE_DMG_ARGS[@]}" \
  "$DMG_PATH" \
  "$STAGE_DIR"

codesign --sign "$IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

echo "Done: $DMG_PATH"
