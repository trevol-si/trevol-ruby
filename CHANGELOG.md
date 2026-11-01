# Registro de cambios

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado, [SemVer](https://semver.org/lang/es/): antes
de la 1.0, un cambio incompatible sube el número menor.

## [0.1.0] — sin publicar

Primera versión (API `2026-10-22`).

- `Trevol::Client` con un recurso por etiqueta de la API (`invoices`, `credit_notes`, `debit_notes`, `support_documents`, `payrolls`,
  `radian_events`, `webhook_endpoints`, `events`, `requests`, `balance`, `general`…) y los modelos generados de la especificación
  (`TrevolGenerado::*`).
- `Idempotency-Key` automática (la misma en los reintentos), reintentos con espera creciente que respetan `Retry-After`, errores tipados por
  `code` (`Trevol::*Error`), entorno deducido del prefijo de la llave, `Trevol-Version` fijada.
- `paginate` (`Enumerator::Lazy`), descargas de PDF, XML y ZIP como `Tempfile`, `Trevol::Webhook#verify` y `#event_data` (Standard Webhooks).
