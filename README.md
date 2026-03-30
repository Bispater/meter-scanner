# HydroScan Cam 💧📸

Aplicación Flutter MVP para lectura de medidores de agua manuales y digitales mediante escaneo QR + captura con cámara + OCR.

## Arquitectura (Clean Architecture)

```
lib/
├── main.dart                          # Entry point, ProviderScope, tema oscuro
├── domain/                            # Capa de dominio (modelos, contratos)
│   ├── models/
│   │   ├── water_measurement.dart     # Modelo principal de medición
│   │   └── qr_scan_data.dart          # Datos parseados del QR
│   ├── repositories/
│   │   └── measurement_repository.dart # Interfaz del repositorio
│   └── services/
│       └── ocr_service.dart           # Contrato del servicio OCR
├── data/                              # Capa de datos (implementaciones)
│   ├── repositories/
│   │   └── measurement_repository_impl.dart  # API REST (simulada para MVP)
│   └── services/
│       └── ocr_service_impl.dart      # Google ML Kit Text Recognition
└── presentation/                      # Capa de presentación (UI)
    ├── providers/
    │   └── app_providers.dart         # Riverpod providers
    ├── theme/
    │   └── app_theme.dart             # Material 3, alto contraste, tema oscuro
    ├── screens/
    │   ├── home_screen.dart           # Pantalla de inicio + botón Escanear QR
    │   ├── qr_scanner_screen.dart     # Escáner QR (mobile_scanner)
    │   ├── prepare_measurement_screen.dart  # Datos del depto + botón Capturar
    │   ├── camera_capture_screen.dart # Cámara con overlay de guía circular
    │   └── confirmation_screen.dart   # Validación OCR + envío
    └── widgets/
        └── meter_overlay_painter.dart # CustomPainter: silueta circular de guía
```

## Stack Técnico

| Componente | Paquete |
|---|---|
| Estado | `flutter_riverpod` |
| Cámara | `camera` |
| Escáner QR | `mobile_scanner` |
| OCR | `google_mlkit_text_recognition` |
| Diseño | Material 3 (tema oscuro, alto contraste) |
| HTTP | `http` |
| Almacenamiento | `path_provider` |

## Flujo de Usuario

1. **Inicio** → Botón "Escanear QR" (o ingreso manual)
2. **QR Scanner** → Lee QR con `meter_id` y `apartment_info` (JSON o `id|info`)
3. **Preparar Medición** → Muestra datos del departamento + botón "Capturar Medidor"
4. **Captura** → Cámara con overlay circular (silueta de guía) + flash toggle
5. **Confirmación** → Imagen capturada + valor OCR editable + botón "Enviar Medición"

## Formato QR Soportado

```json
{"meter_id": "MED-001", "apartment_info": "4B - Piso 2"}
```
O texto plano: `MED-001|4B - Piso 2`

## Inicio Rápido

```bash
flutter pub get
flutter run
```

## Permisos Configurados

- **iOS**: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
- **Android**: `CAMERA`, `INTERNET`, `FLASHLIGHT` (minSdk 21)

## Tests

```bash
flutter test       # 4 tests unitarios (modelos)
flutter analyze    # 0 issues
```
