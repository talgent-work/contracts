# Content Path

`/v1/storage/content` is where Storage serves its Access Links. Storage RPCs return an Access
Link as a complete URL: the deployment's public base for Storage (`/api` by default), this path
and a `grant` query parameter that carries the link's signed authority. The link needs no
signed-in session.

## Who serves it

| Server | Path | Caller |
|---|---|---|
| Public gateway | `<public base>/v1/storage/content` | Anyone holding the link, such as a browser |
| Controlplane | `/v1/storage/content` | The gateway, and trusted services inside the cluster |
| Native API | `/v1/storage/content` | A current Work only, under its Work credential ([Native API](gateway-identity.md#native-api-agents-under-a-work-credential)) |

A platform Connector that serves its Works' downloads serves `GET /v1/storage/content` on its
own origin and forwards the request to the native API's same path with the Work's credential,
keeping the query string byte for byte. The query is opaque: callers never parse or rebuild it.

## Request and response

`GET /v1/storage/content?grant=<grant>`. Range requests are honored.

A successful response streams the file:

- `Content-Type`: the file's media type.
- `Content-Disposition`: `inline` or `attachment`, as the link was issued, with the file's name.
- `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`.
- Inline content also carries
  `Content-Security-Policy: sandbox; default-src 'none'; img-src data: blob:; style-src 'unsafe-inline'`,
  so shown content never runs script in the platform's origin.

A failure is JSON, `{"error": {"code": "<code>", "message": "<text>"}}`:

| Status | Code | Meaning |
|---|---|---|
| 401 | `invalid_link` | The grant is malformed, forged or expired |
| 404 | `not_found` | The file no longer exists |
| 409 | `content_changed` | A preview link's file was replaced after its preview was decided |
| 500 | `storage_unavailable` | Storage could not serve the file |
