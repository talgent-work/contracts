# Application Tokens

An Application obtains its Identity Token from Account with the OAuth 2.0 client credentials
grant ([RFC 6749 §4.4](https://www.rfc-editor.org/rfc/rfc6749#section-4.4)) and calls the public
APIs with it as `Authorization: Bearer <token>`. Its client id is the Application id; its client
secret is a Client Secret its Application Owner received when it was issued.

## Client Secrets

An Application holds at most one current Client Secret and one being replaced. When its Application
Owner rotates the secret (`ApplicationService.RotateClientSecret`), the new secret is shown once and
the replaced one keeps matching for a bounded overlap (24 hours by default), so the Application can
switch without downtime; a secret already in an earlier overlap ends at once. A revoked secret
(`ApplicationService.RevokeClientSecret`) is refused from then on, while tokens it already obtained
stop at their short expiry.

Removing the Application (`ApplicationService.RemoveApplication`) revokes every Client Secret it
holds at once; it never returns, and its tokens likewise stop at their short expiry.

## Request

`POST <public origin>/auth/token`, `Content-Type: application/x-www-form-urlencoded`:

| Parameter | Value |
|---|---|
| `grant_type` | `client_credentials`; required |
| `scope` | Not supported; a request that names one is refused with `invalid_scope` |

The client authenticates with HTTP Basic (`client_id:client_secret`, each form-urlencoded first),
or with `client_id` and `client_secret` in the body; a request using both is refused.

## Response

`200` with `Cache-Control: no-store` and JSON:

| Field | Value |
|---|---|
| `access_token` | The Identity Token: `principal` is `application`, `sub` is the Application id |
| `token_type` | `Bearer` |
| `expires_in` | Seconds until the token expires; it is short-lived and never refreshed, so request a new one |

## Errors

JSON `{"error": "<code>", "error_description": "<text>"}`:

| Status | `error` | Cause |
|---|---|---|
| 400 | `invalid_request` | A missing or repeated parameter, two client authentication methods, or another content type |
| 400 | `unsupported_grant_type` | A `grant_type` other than `client_credentials` |
| 400 | `invalid_scope` | A `scope` was named |
| 401 | `invalid_client` | An unknown client id, or a secret that does not match a valid Client Secret; with `WWW-Authenticate: Basic` when the client used Basic |
| 503 | `temporarily_unavailable` | Account could not issue the token now; retry later |
