# Auditoría de seguridad — MackeUp AI

Tarea de Programación Móvil (UNICESAR): auditar la app con el **OWASP Mobile Top 10 (2024)**,
corregir al menos cinco hallazgos y demostrar el antes y el después. Entrega: **16 de noviembre de 2026**.

> **Reglas:** se prueba solo nuestra app y nuestro backend (proyecto Firebase `macke-up-ai`).
> Ningún secreto real ni dato personal en capturas, commits o documentos. Un secreto expuesto
> en la entrega resta 10 puntos.

## Estructura

| Archivo / carpeta | Fase | Para qué |
|---|---|---|
| [01_modelo_amenazas.md](01_modelo_amenazas.md) | 1 | Diagrama, datos sensibles y tres amenazas |
| [02_owasp_top10.md](02_owasp_top10.md) | 2 | M1–M10 marcados como Cumple / No cumple / No aplica |
| [03_hallazgos.md](03_hallazgos.md) | 2–3 | Registro H-01, H-02… con evidencia y corrección |
| [04_verificacion.md](04_verificacion.md) | 4 | Prueba repetida antes/después por hallazgo |
| `scripts/` | 2 y 4 | Una técnica por script; todos escriben en `evidencia/` |
| `evidencia/` | — | Salidas crudas. **Está en `.gitignore`**: puede contener secretos |
| `.gitleaks.toml` | 2 | Configuración del escaneo de secretos |

## Herramientas instaladas

| Técnica (PDF, Fase 2) | Herramienta | Script |
|---|---|---|
| Secretos en código e historial | gitleaks 8.30 | `scripts/escanear_secretos.ps1` |
| Dependencias | `flutter pub outdated`, `npm audit` (functions) | `scripts/revisar_dependencias.ps1` |
| Manifiesto y permisos | Lectura del `AndroidManifest.xml` fuente y del fusionado en release | `scripts/revisar_manifiesto.ps1` |
| Análisis del APK | MobSF (Docker) | `scripts/construir_apk.ps1`, `scripts/mobsf.ps1` y `scripts/mobsf_analizar.ps1` (API REST: sube, escanea y guarda reporte JSON, PDF y puntaje) |
| Logs en ejecución | `adb logcat` (Android SDK) | `scripts/logcat.ps1` |
| Tráfico de red | mitmproxy 12.3 (`mitmweb`) | `scripts/mitmproxy.ps1` |
| Pines del certificate pinning | openssl + .NET | `scripts/verificar_pines.ps1` (antes de renovar los pines) |
| Dispositivo de pruebas | Emulador `auditoria_api35` (Android 15, Google APIs, admite `adb root`) | `scripts/entorno.ps1 -Emulador` |

El PDF pide **al menos dos** técnicas; con las tres primeras (no necesitan dispositivo) ya se cumple.
Las demás suman evidencia más fuerte para la demostración.

## Uso rápido

Desde la raíz del repo, en PowerShell:

```powershell
# 1. Comprobar que todo está listo (y arrancar el emulador si se quiere)
.\auditoria\scripts\entorno.ps1
.\auditoria\scripts\entorno.ps1 -Emulador

# 2. Técnicas estáticas (no necesitan dispositivo)
.\auditoria\scripts\escanear_secretos.ps1
.\auditoria\scripts\revisar_dependencias.ps1
.\auditoria\scripts\revisar_manifiesto.ps1

# 3. Análisis del APK
.\auditoria\scripts\construir_apk.ps1
.\auditoria\scripts\mobsf.ps1          # levanta MobSF en http://localhost:8000 (mobsf / mobsf)
.\auditoria\scripts\mobsf_analizar.ps1 -Apk build\app\outputs\flutter-apk\app-release.apk -Etiqueta despues

# 4. Técnicas dinámicas (con el emulador encendido y la app instalada)
.\auditoria\scripts\logcat.ps1
.\auditoria\scripts\mitmproxy.ps1
```

Si PowerShell bloquea los scripts: `Set-ExecutionPolicy -Scope Process Bypass` (solo para esa ventana).

## Informe en PDF (dos versiones)

El contenido se edita solo en `informe/informe_seguridad.html`; de ahí salen las dos versiones:

| Versión | Archivo | Comando |
|---|---|---|
| APA 7 (Times 12, interlineado doble, carta) | `informe/Informe_Seguridad_MackeUpAI.pdf` | `.\auditoria\scripts\generar_informe.ps1` |
| Diseño de la guía UNICESAR (logo, colores de la guía, A4) | `informe/Informe_Seguridad_MackeUpAI_UNICESAR.pdf` | `.\auditoria\scripts\generar_informe.ps1 -Version unicesar` |

La versión UNICESAR toma su estilo de `informe/unicesar/estilo.css` y su portada de `informe/unicesar/portada.html`.

## Compilar el release (después de las correcciones)

1. Una sola vez por equipo: crear la llave de publicación y registrar sus huellas SHA en
   Firebase (H-01). `android/key.properties` y el `.jks` no se suben; guarden una copia segura.
   ```powershell
   .\auditoria\scripts\crear_llave_release.ps1
   ```
2. Compilar siempre ofuscado (H-04); los símbolos sirven para leer los stack traces:
   ```powershell
   flutter build apk --release --obfuscate --split-debug-info=..\simbolos-mackeupai
   ```
   o `.\auditoria\scripts\construir_apk.ps1`, que además analiza el APK.

## Flujo de trabajo en Git

- Todo el trabajo va en la rama `feature/seguridad`.
- **Cada corrección en su propio commit** que nombre el ID del hallazgo, por ejemplo
  `fix(seguridad): H-03 mover token a flutter_secure_storage`.
- Para la verificación, correr el mismo script antes y después; los dos reportes quedan en
  `evidencia/` con fecha y hora en el nombre.
- Las capturas para el informe PDF se recortan o tachan antes de pegarlas: nada de llaves,
  tokens, correos ni fotos reales.

## Si Docker Desktop no arranca ("dockerInference … cannot be accessed")

Pasa cuando Docker se cierra mal: quedan sockets dañados que no se pueden borrar, en
`%LOCALAPPDATA%\Docker\run` o en `%LOCALAPPDATA%\docker-secrets-engine` (el error dice cuál).
Solución: cerrar Docker Desktop por completo, renombrar la carpeta que nombra el error y abrirlo otra vez.

```powershell
Get-Process 'Docker Desktop','com.docker.backend' -ErrorAction SilentlyContinue | Stop-Process -Force
$f = Get-Date -Format yyyyMMddHHmm
Rename-Item "$env:LOCALAPPDATA\Docker\run" "run_danado_$f"
Rename-Item "$env:LOCALAPPDATA\docker-secrets-engine" "docker-secrets-engine_danado_$f"
docker desktop start
```

## Notas sobre mitmproxy con Flutter y Firebase

- Desde Android 7 las apps no confían en certificados instalados por el usuario. Por eso el
  emulador usa una imagen **Google APIs** (sin Play Store): con `adb root` el script instala el
  certificado de mitmproxy como certificado de sistema.
- El código Dart (`HttpClient`) ignora el proxy del sistema; los SDK nativos de Firebase sí lo
  respetan en su mayoría, pero Firestore usa gRPC y puede no verse en el proxy. Si una petición
  no aparece, anotarlo como limitación de la prueba, no como "cumple".
- Para M5 basta con mostrar que todo el tráfico visible va por HTTPS y que, **sin** el certificado
  de mitmproxy instalado, la app rechaza la conexión interceptada.

## Referencias

- OWASP Mobile Top 10: <https://owasp.org/www-project-mobile-top-10/>
- OWASP MASVS: <https://mas.owasp.org/MASVS/>
- OWASP MASTG: <https://mas.owasp.org/MASTG/>
- MobSF: <https://github.com/MobSF/Mobile-Security-Framework-MobSF>
