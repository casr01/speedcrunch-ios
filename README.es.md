# SpeedCrunch para iOS (port personal)

Port de [SpeedCrunch](https://github.com/heldercorreia/speedcrunch) a iPhone y iPad.
El motor de cálculo es el de SpeedCrunch, sin cambios en su lógica; la interfaz es nueva, en SwiftUI.

## Cómo instalarla en tu iPhone

Requisitos: un Mac con Xcode instalado (desde el App Store) y un Apple ID.

```bash
cd ruta/a/speedcrunch-ios
scripts/setup-ios.sh
```

El script descarga Qt para iOS dentro de esta carpeta (`.tools/`, cerca de 1 GB la primera vez),
genera el proyecto de Xcode en `~/Library/Developer/SpeedCrunch-iOS/build` (fuera de Documentos, porque iCloud agrega metadatos que impiden firmar la app) y lo abre. Después, en Xcode:

1. Target **SpeedCrunch** → **Signing & Capabilities** → **Team**: tu Apple ID.
2. Conecta el iPhone, elígelo arriba y presiona **Run** (⌘R).
3. La primera vez, en el iPhone: *Ajustes → General → VPN y gestión de dispositivos* → confía en tu
   certificado. Si lo pide, activa *Ajustes → Privacidad y seguridad → Modo desarrollador*.

Con un Apple ID gratuito, la firma dura 7 días: pasado ese plazo, vuelve a presionar Run en Xcode.
Con la membresía pagada de Apple Developer la firma dura un año y puedes usar TestFlight.

Para solo verificar que todo compila, sin firmar ni abrir Xcode: `scripts/setup-ios.sh --check`.

## Qué incluye

- Cálculo con precisión arbitraria, historial, variables (`x = 5`), funciones de usuario
  (`f(a; b) = a*b`), unidades (`10[metre] → [foot]`), números complejos, bases (hex, octal,
  binario), fracciones y notación científica, igual que la versión de escritorio.
- Resultado en vivo mientras escribes.
- Teclado de calculadora (con tecla 2nd) o teclado de texto con barra de símbolos.
- Listas buscables de las 150+ funciones y de las constantes físicas (CODATA 2022).
- Ajustes: unidad de ángulo, formato y decimales del resultado, separador decimal, agrupación de miles.
- Colores de los temas Duskfox (oscuro) y Dawnfox (claro) de SpeedCrunch.
- El historial, las variables y las funciones se guardan entre sesiones.

## Estructura

| Carpeta | Contenido |
|---|---|
| `upstream/` | `math/` y `core/` de SpeedCrunch (commit en `upstream/UPSTREAM_COMMIT`), más 4 utilidades de formato de `gui/` que solo usan Qt Core |
| `engine/` | Biblioteca estática del motor + puente en C (`include/speedcrunch_bridge.h`) + `sc-cli` para pruebas |
| `ios/` | App SwiftUI, catálogo de recursos y el CMakeLists que genera el proyecto de Xcode |
| `scripts/setup-ios.sh` | Instala Qt para iOS y genera el proyecto |

### Cambios al código original

Uno solo: `upstream/core/settings.cpp` usa `QCoreApplication` en vez de `QApplication` y omite la
fuente por defecto (`QFont`) cuando se define `SPEEDCRUNCH_HEADLESS`. Con eso el motor depende
únicamente de Qt Core, que funciona en iOS. Ver el historial de git para el diff exacto.

## Probar el motor sin iPhone (Linux o macOS)

```bash
cmake -S engine -B build && cmake --build build
./build/sc-cli "sqrt(2)" "x = 5" "x^2"
python3 engine/tests/smoke_test.py build/sc-cli
```

## Actualizar a una versión nueva de SpeedCrunch

Copia `src/math` y `src/core` (y los 4 archivos de `upstream/gui/`) desde el repositorio original,
actualiza `upstream/UPSTREAM_COMMIT`, vuelve a aplicar el cambio de `settings.cpp` y corre las pruebas.

## Licencia

GNU General Public License v2 o posterior, igual que SpeedCrunch. Ver `LICENSE`.
Este port es para uso personal; publicarlo en la App Store entra en conflicto con la GPL.
