# Trusted Identity Headers

The Workbench's services take a caller's identity from request headers, never from the request
body. Which headers they trust depends on how the request arrived: through the public gateway,
from a trusted service inside the cluster, or through the native API under a Work credential.
Header names are case-insensitive.

## Public gateway: signed-in people

The public gateway validates the Identity Token Account issues (cookie `talgent-access`, or
`Authorization: Bearer <token>`; issuer `<public origin>/auth`, audience `talgent`) and forwards
its claims:

| Header | Value |
|---|---|
| `x-talgent-authenticated-by` | Always `envoy`; set by the gateway on every route it authenticates |
| `x-talgent-issuer` | Claim `iss` |
| `x-talgent-subject` | Claim `sub`: the Account id, a canonical lowercase UUID |
| `x-talgent-username` | Claim `preferred_username` |
| `x-talgent-email` | Claim `email` |
| `x-talgent-display-name` | Claim `name` |
| `x-talgent-avatar-url` | Claim `picture` |
| `x-talgent-roles` | Claim `roles`, comma-separated |

A service admits such a request only when `x-talgent-authenticated-by` is `envoy` and
`x-talgent-subject` is a canonical lowercase UUID; otherwise it answers `Unauthenticated`. Values
are trimmed of surrounding whitespace, and empty roles are dropped.

On every public route the gateway removes the trust headers a client sent before it sets its
own: `x-talgent-authenticated-by`, the claim headers it replaces, `x-talgent-service-id`,
`x-talgent-delegated-user-id`, `x-talgent-delegated-actor-id`, `x-talgent-gateway-token` and
`x-talgent-reader-admission`. A client can therefore never present the headers below.

## Trusted services: delegated calls

A service inside the cluster calls another on a person's behalf with both headers:

| Header | Value |
|---|---|
| `x-talgent-service-id` | The calling service's name |
| `x-talgent-delegated-user-id` | The Account id the call acts for |

Both or neither: one without the other is `Unauthenticated`, as is a delegated user id that is
empty, starts with `oidc:` or contains `#`. A delegated call carries no claims besides the user
id. The cluster network is the trust boundary: these headers reach a service only from inside
it, because the gateway strips them.

A delegated call may add one statement the callee cannot know itself:

| Header | Value |
|---|---|
| `x-talgent-reader-admission` | `<reference>=<value>`, such as `project=<project id>`: the delegated user is a member of what the reference names |

It is honored only together with both delegation headers; on any other request it is ignored.

## Native API: Agents under a Work credential

Processes that serve an Agent's calls run a native API on a separate port. It serves an exact
list of procedures, each as a Connect unary `POST`, plus `GET /v1/storage/content`
([Content path](storage-content.md)). An Agent reaches it directly over HTTP, or the platform
Connector (the Talgent MCP Gateway) calls it on the Agent's behalf.

| Header | Value |
|---|---|
| `X-Talgent-Work-Id` | The Work the caller acts for |
| `X-Talgent-Work-Credential` | The Work credential issued to the Work's current live sandbox; it is revoked with that sandbox |
| `X-Talgent-Space-Token` | The Work Agent's Space Token, sent beside the credential on the Artifact commands that take it |
| `X-Talgent-Gateway-Token` | The deployment's secret that proves the request comes from the platform Connector |

Rules every native API applies, in this order:

1. An unknown path, a percent-escaped path, or a query string on anything but the content path
   is `404 Not Found`. A method other than `POST` (or `GET` on the content path) is
   `PermissionDenied`.
2. When the deployment configures a gateway token, every request presents
   `X-Talgent-Gateway-Token` exactly once with that value, or it is `PermissionDenied`: only the
   Connector reaches the API and sandboxes never hold the token. Without a configured token, any
   caller with a current Work credential reaches the API, and a presented gateway token is
   dropped unread. The token never reaches the procedure.
3. Without a gateway token, `X-Talgent-Space-Token` is dropped from every procedure that does not
   take it.
4. `x-envoy-*` headers are dropped. Any other `x-talgent-*` header, `Authorization` or `Cookie`
   is `Unauthenticated`: the Work credential is the only identity accepted.
5. `X-Talgent-Work-Id` and `X-Talgent-Work-Credential` each appear exactly once and non-empty,
   and the credential is current for that Work; otherwise `Unauthenticated`.

Errors are Connect errors. A service that hosts procedures on its own native API verifies the
Work credential with Agent's `VerifyWorkCredential` and applies the same rules.

### Identity

`POST /talgent.native.v1.NativeService/Identity` answers which live Work a credential belongs
to, as soon as its sandbox is live and before the Work's first turn. It takes no body and
returns JSON:

```json
{"work_id": "…", "project_id": "…", "subject_kind": "…", "subject_id": "…", "purpose": "…"}
```

`project_id`, `subject_kind` and `subject_id` are empty for a Work without a Project or
Subject. The path is a fixed name, not a proto package of this repository.
