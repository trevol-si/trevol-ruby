# Código generado

**No edites `lib/trevol_generado/`**: `sdks/generar.sh` la borra y la vuelve a escribir entera. La capa propia (cliente,
reintentos, errores, paginación, webhooks) vive fuera de esa carpeta.

| | |
|---|---|
| Generador | OpenAPI Generator 7.26.0 (`ruby`) |
| Especificación | `especificacion/openapi.sdk.enums-abiertos.json` (variante 3.0.3 de `docs/api/openapi.json`, versión de la API 2026-11-28) |
| sha256 de la especificación | `119f5ee1ea2cd7877728025a3d635b3d412ac8b1e689754a82429cc9be2a7305` |
| Configuración | `openapi-generator.yaml` |

Regenerar (desde el monorepo de Trevol): `sdks/generar.sh ruby`. Comprobar que lo del repositorio es lo que sale de la
especificación: `sdks/generar.sh --comprobar ruby`.
