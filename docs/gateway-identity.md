# Trusted Identity Headers

The Workbench's services take a caller's identity from request headers, never from the request
body. Which headers they trust depends on how the request arrived: through the public gateway,
from a trusted service inside the cluster, or through the native API under a Work credential.
Header names are case-insensitive.

## Admission

Every request speaks for exactly one Principal: a `user` (a signed-in person, by their Account)
or an `agent` (a Work's Agent, by the Work's Agent Account). Each public procedure declares the
Principals it admits with the method option `admission.v1.admits`
([README](../README.md#admission)); a procedure declared `anonymous` admits a caller without
one. A service refuses a Principal its procedure does not declare, and every caller of a
procedure that declares nothing, with `PermissionDenied` before the handler runs.

## Public gateway: Identity Tokens

The public gateway validates the Identity Token Account issues (cookie `talgent-access`, or
`Authorization: Bearer <token>`; issuer `<public origin>/auth`, audience `talgent`) and forwards
its claims. A claim the token lacks writes no header.

| Header | Value |
|---|---|
| `x-talgent-authenticated-by` | Always `envoy`; set by the gateway on every route it authenticates |
| `x-talgent-issuer` | Claim `iss` |
| `x-talgent-principal` | Claim `principal`: `user` or `agent` |
| `x-talgent-subject` | Claim `sub`: the Account id of a `user`, or the Work id of an `agent`; a canonical lowercase UUID |

A `user` token's claims:

| Header | Value |
|---|---|
| `x-talgent-username` | Claim `preferred_username` |
| `x-talgent-email` | Claim `email` |
| `x-talgent-display-name` | Claim `name` |
| `x-talgent-avatar-url` | Claim `picture` |
| `x-talgent-roles` | Claim `roles`, comma-separated |

An `agent` token's claims, its Work's facts fixed when the Work was created:

| Header | Value |
|---|---|
| `x-talgent-project-id` | Claim `project_id`: the Work's Project |
| `x-talgent-agent-id` | Claim `agent_id`: the Work's AgentDefinition; required |
| `x-talgent-purpose` | Claim `purpose`: the AgentDefinition's purpose; required |
| `x-talgent-work-subject-kind` | Claim `work_subject_kind` |
| `x-talgent-work-subject-id` | Claim `work_subject_id` |
| `x-talgent-represented-user-id` | Claim `for`: the Account id of the person the Agent represents, a canonical lowercase UUID |

A service admits such a request only when `x-talgent-authenticated-by` is `envoy`,
`x-talgent-principal` names a known Principal, `x-talgent-subject` is a canonical lowercase UUID,
and an `agent` carries its required claims; otherwise it answers `Unauthenticated`. Values are
trimmed of surrounding whitespace, and empty roles are dropped. An `agent` request never speaks
for a person: not even the one its Agent represents.

Before it routes a request, the gateway removes every identity header a client sent, once for the
whole gateway: `x-talgent-authenticated-by`, every claim header above, `x-talgent-service-id`,
`x-talgent-delegated-user-id`, `x-talgent-delegated-actor-id`, `x-talgent-gateway-token`,
`x-talgent-reader-admission` and the `x-talgent-runtime-*` headers. A client can therefore never
present the headers below. A capability passes through untouched: `x-talgent-space-token`, the
Space Token of the Directory an Agent writes, which only the procedures that take it read.

An Agent reaches the platform through the same entry, under its agent Identity Token, which its
sandbox's Credential Proxy or Talgent Computer adds; the Harness never holds it.

## Trusted services: delegated calls

A service inside the cluster calls another on a person's behalf with both headers:

| Header | Value |
|---|---|
| `x-talgent-service-id` | The calling service's name |
| `x-talgent-delegated-user-id` | The Account id the call acts for |

Such a call speaks for that `user`. Both or neither: one without the other is `Unauthenticated`, as is a delegated user id that is
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

A request through the native API speaks for its Work's `agent`, and reaches only procedures
that admit one.

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
