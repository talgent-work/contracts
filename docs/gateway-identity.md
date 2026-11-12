# Trusted Identity Headers

The Workbench's services take a caller's identity from request headers, never from the request
body. Which headers they trust depends on how the request arrived: through the public gateway,
or from a trusted service inside the cluster.
Header names are case-insensitive.

## Admission

Every request speaks for exactly one Principal: a `user` (a signed-in person, by their Account),
an `agent` (a Work's Agent, by the Work's Agent Account) or an `application` (a third-party
program, by its Application, with a token from the [client credentials
grant](application-tokens.md)). Each public procedure declares the
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
| `x-talgent-principal` | Claim `principal`: `user`, `agent` or `application` |
| `x-talgent-subject` | Claim `sub`: the Account id of a `user`, the Work id of an `agent`, or the Application id of an `application`; a canonical lowercase UUID |

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

An `application` token carries no further claims.

A service admits such a request only when `x-talgent-authenticated-by` is `envoy`,
`x-talgent-principal` names a known Principal, `x-talgent-subject` is a canonical lowercase UUID,
and an `agent` carries its required claims; otherwise it answers `Unauthenticated`. Values are
trimmed of surrounding whitespace, and empty roles are dropped. Neither an `agent` nor an
`application` request ever speaks for a person: not even the one an Agent represents or the
person who owns the Application.

Before it routes a request, the gateway removes every identity header a client sent, once for the
whole gateway: `x-talgent-authenticated-by`, every claim header above, `x-talgent-service-id`,
`x-talgent-delegated-user-id`, `x-talgent-delegated-actor-id`, `x-talgent-reader-admission`
and the `x-talgent-runtime-*` headers. A client can therefore never
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
