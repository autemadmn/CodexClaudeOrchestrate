#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIRECTORY/../.." && pwd)"
PROJECT_PATH="$REPOSITORY_ROOT/EuroGas/EuroGas.xcodeproj"
DERIVED_DATA="$REPOSITORY_ROOT/build/ios/DerivedData"
ARTIFACT_DIRECTORY="$REPOSITORY_ROOT/build/ios/ipa"
APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/EuroGas.app"
IPA_PATH="$ARTIFACT_DIRECTORY/EuroGas-free-sideload-unsigned.ipa"
BUILD_INFORMATION="$ARTIFACT_DIRECTORY/EuroGas-free-sideload-build.txt"
STAGING_DIRECTORY="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGING_DIRECTORY"
}
trap cleanup EXIT

mkdir -p "$DERIVED_DATA" "$ARTIFACT_DIRECTORY" "$STAGING_DIRECTORY/Payload"

xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme EuroGas \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM=""

if [[ ! -d "$APP_PATH" || ! -f "$APP_PATH/EuroGas" ]]; then
  echo "No se encontró EuroGas.app o su ejecutable después de compilar." >&2
  exit 1
fi

/usr/bin/plutil -lint "$APP_PATH/Info.plist"

# La variante gratuita omite la extensión de Live Activity y sus App Groups.
# Esas capacidades no son necesarias para el recorrido básico y complican la
# firma de una cuenta Apple gratuita. El código fuente completo no se altera.
/usr/bin/ditto "$APP_PATH" "$STAGING_DIRECTORY/Payload/EuroGas.app"
rm -rf "$STAGING_DIRECTORY/Payload/EuroGas.app/PlugIns"
/usr/libexec/PlistBuddy -c "Set :NSSupportsLiveActivities false" \
  "$STAGING_DIRECTORY/Payload/EuroGas.app/Info.plist"

if find "$STAGING_DIRECTORY/Payload" -name embedded.mobileprovision -print -quit | grep -q .; then
  echo "El paquete contiene un perfil de aprovisionamiento inesperado." >&2
  exit 1
fi

if find "$STAGING_DIRECTORY/Payload" -name _CodeSignature -print -quit | grep -q .; then
  echo "El paquete contiene una firma inesperada." >&2
  exit 1
fi

(
  cd "$STAGING_DIRECTORY"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

if [[ ! -s "$IPA_PATH" ]]; then
  echo "El IPA no se creó o está vacío." >&2
  exit 1
fi

{
  echo "Artifact: $(basename "$IPA_PATH")"
  echo "Git commit: $(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
  echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
  echo "SDK: $(xcrun --sdk iphoneos --show-sdk-version)"
  echo "Bundle ID before local re-signing: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$STAGING_DIRECTORY/Payload/EuroGas.app/Info.plist")"
  echo "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGING_DIRECTORY/Payload/EuroGas.app/Info.plist")"
  echo "Build: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$STAGING_DIRECTORY/Payload/EuroGas.app/Info.plist")"
  echo "Live Activity extension: omitted for free sideloading"
  echo "Code signing: intentionally absent; AltServer/AltStore must sign locally"
  shasum -a 256 "$IPA_PATH"
} > "$BUILD_INFORMATION"

unzip -t "$IPA_PATH"
cat "$BUILD_INFORMATION"
