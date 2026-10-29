#!/bin/bash
# setup-ios.sh — prepara el proyecto de SpeedCrunch para iOS en un Mac.
#
#   1. Verifica que Xcode esté instalado.
#   2. Instala, solo dentro de esta carpeta (.tools/), herramientas de Python y Qt para iOS.
#   3. Genera el proyecto de Xcode en build-ios/ y lo abre.
#
# Uso:
#   scripts/setup-ios.sh            # prepara todo y abre Xcode
#   scripts/setup-ios.sh --check    # además compila para iPhone sin firmar (verificación)
#
# Variables de entorno opcionales:
#   TEAM_ID=ABCDE12345   ID de equipo de Apple, para no elegirlo a mano en Xcode
#   BUNDLE_ID=...        Identificador de la app (por defecto com.example.speedcrunch)
#   QT_VERSION=6.8.3     Versión de Qt a instalar
# También se pueden guardar en scripts/local.env (no se sube al repositorio).
#
# Herramientas en .tools/ (esta carpeta); proyecto de Xcode en
# ~/Library/Developer/SpeedCrunch-iOS/build. Para deshacer, borra ambas.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Ajustes personales (por ejemplo TEAM_ID) que no van al repositorio.
# shellcheck source=/dev/null
[[ -f "$ROOT/scripts/local.env" ]] && source "$ROOT/scripts/local.env"
TOOLS="$ROOT/.tools"
QT_VERSION="${QT_VERSION:-6.8.3}"
QT_ROOT="$TOOLS/Qt"
QT_IOS="$QT_ROOT/$QT_VERSION/ios"
QT_HOST="$QT_ROOT/$QT_VERSION/macos"   # Qt para Mac: sus herramientas generan código para iOS
# El proyecto de Xcode y la app compilada van fuera de Documentos/Escritorio:
# si esas carpetas se sincronizan con iCloud, macOS les agrega metadatos que
# hacen fallar la firma ("resource fork, Finder information... not allowed").
BUILD="${BUILD_DIR:-$HOME/Library/Developer/SpeedCrunch-iOS/build}"
BUNDLE_ID="${BUNDLE_ID:-com.example.speedcrunch}"
TEAM_ID="${TEAM_ID:-}"
CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "Este script se ejecuta en macOS."

step "Verificando Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
    fail "Xcode no está instalado o no está seleccionado.
  1) Instala Xcode desde el App Store.
  2) Ábrelo una vez y acepta la licencia.
  3) Ejecuta: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi
xcodebuild -version | head -1
if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    fail "Falta el SDK de iOS. Abre Xcode > Settings > Components e instala iOS."
fi

step "Preparando herramientas locales en .tools/ (Python, aqtinstall, CMake)"
mkdir -p "$TOOLS"
if [[ ! -x "$TOOLS/venv/bin/python" ]]; then
    python3 -m venv "$TOOLS/venv"
fi
"$TOOLS/venv/bin/python" -m pip install --quiet --upgrade pip
"$TOOLS/venv/bin/python" -m pip install --quiet --upgrade "aqtinstall>=3.1" "cmake>=3.27,<4"
export PATH="$TOOLS/venv/bin:$PATH"
cmake --version | head -1

if [[ ! -x "$QT_IOS/bin/qt-cmake" ]]; then
    step "Descargando Qt $QT_VERSION para iOS (cerca de 1 GB, solo la primera vez)"
    aqt install-qt mac ios "$QT_VERSION" ios --autodesktop --outputdir "$QT_ROOT"
else
    step "Qt $QT_VERSION para iOS ya está instalado"
fi
[[ -x "$QT_IOS/bin/qt-cmake" ]] || fail "Qt para iOS no se instaló correctamente ($QT_IOS)."
[[ -d "$QT_HOST/lib/cmake/Qt6" ]] || fail "Falta Qt para Mac ($QT_HOST), que Qt para iOS necesita. Borra .tools/Qt y vuelve a ejecutar."

step "Generando el proyecto de Xcode en $BUILD"
mkdir -p "$BUILD"
"$QT_IOS/bin/qt-cmake" -S "$ROOT/ios" -B "$BUILD" -G Xcode \
    -DQT_HOST_PATH="$QT_HOST" \
    -DSC_BUNDLE_ID="$BUNDLE_ID" \
    -DSC_TEAM_ID="$TEAM_ID"

PROJECT="$BUILD/SpeedCrunchiOS.xcodeproj"
[[ -d "$PROJECT" ]] || fail "No se generó el proyecto de Xcode."

if [[ $CHECK -eq 1 ]]; then
    step "Compilando para iPhone sin firmar (solo verificación)"
    xcodebuild -project "$PROJECT" -scheme SpeedCrunch -configuration Debug \
        -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build \
        | tee "$BUILD/check.log" | grep -E "error:|warning: .*Swift|BUILD (SUCCEEDED|FAILED)" || true
    if grep -q "BUILD SUCCEEDED" "$BUILD/check.log"; then
        printf '\n\033[1;32mCompilación exitosa.\033[0m Registro completo: %s\n' "$BUILD/check.log"
    else
        fail "La compilación falló. Registro completo: $BUILD/check.log"
    fi
fi

step "Listo"
cat <<EOF
Próximos pasos en Xcode:
  1. Selecciona el target "SpeedCrunch" > Signing & Capabilities > Team: tu Apple ID.
  2. Conecta tu iPhone, elígelo arriba en la ventana y presiona Run (⌘R).
  3. En el iPhone, la primera vez: Ajustes > General > VPN y gestión de dispositivos >
     confía en tu certificado de desarrollador. Activa el Modo desarrollador si lo pide.

Con un Apple ID gratuito hay que reinstalar la app desde Xcode cada 7 días.
EOF

if [[ $CHECK -eq 0 ]]; then
    open "$PROJECT"
fi
