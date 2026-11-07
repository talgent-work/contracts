# Talgent Contracts

The contracts of the Talgent Workbench: its public, private and integration contracts as
protobuf sources with the code every language generates from them, and the contracts no proto
expresses. Talgent Workbench and the products that extend it each depend on one version of this
repository.

## Layout

| Path | Holds |
|---|---|
| `proto/<context>/public/v1` | Externally supported RPC contracts |
| `proto/<context>/private/v1` | Deployment-private RPC contracts between trusted services |
| `proto/<context>/integration/v1` | Integration Messages a context publishes |
| `gen/go/<context>/<surface>/v1` | Generated Go and Connect code |
| `gen/ts` | The TypeScript package `@talgent/contracts`; its generated code is in `gen/ts/dist` |
| `docs/` | Contracts no proto expresses |

Each language has its own tree under `gen/`, and a new language adds `gen/<language>`. Generated
code is never edited by hand; only a package's own files, such as `gen/ts/package.json`, are.

## Naming

- A proto package is `<context>.<surface>.v1`, such as `storage.private.v1`.
- Its Go package is `github.com/talgent-work/contracts/gen/go/<context>/<surface>/v1`, named
  `<context><surface>v1`; Connect stubs are in its `<context><surface>v1connect` subpackage,
  generated for `connectrpc.com/connect/v2`.
- Its TypeScript module is `@talgent/contracts/<context>/<surface>/v1/<file>_pb`, generated
  for protobuf-es v2; its services serve Connect-ES 2 clients directly.
- An Integration Message is named `<Fact>V1`. Its message kind, and the topic it is published
  on, is its full name, such as `storage.integration.v1.FileChangedV1`.

## Compatibility

A package version is a wire promise. Within `vN` a contract only grows: new fields, RPCs and
enum values, with removed field numbers reserved. A breaking change opens `vN+1` beside it until
`vN` retires. The release version and the package version are independent; consumers ignore
fields they do not know.

## Releases

Every push to `master` is a release. CI lints, checks every stable package for breaking changes
against the previous release, checks the generated code is current, then tags the next patch.
A minor version is tagged by hand; the patch count continues from it.

## Using the contracts

A product pins one release: its Go module and its web apps name the same tag.

### Go

```sh
go get github.com/talgent-work/contracts@v0.2.0
```

```go
import storageprivatev1 "github.com/talgent-work/contracts/gen/go/storage/private/v1"
```

The module carries the protos too, so one version in `go.mod` pins both. A consumer's Buf
configuration reads them from the module cache:

```sh
go list -m -f '{{.Dir}}' github.com/talgent-work/contracts   # protos are under proto/
```

### TypeScript

`@talgent/contracts` is never published to a registry. A web app takes it as a pnpm git
dependency on a release tag, selecting the package's subdirectory with `path:`
([pnpm: Git repositories](https://pnpm.io/package-sources)):

```json
{
  "dependencies": {
    "@bufbuild/protobuf": "^2.11.0",
    "@connectrpc/connect": "^2.1.1",
    "@talgent/contracts": "github:talgent-work/contracts#v0.2.0&path:/gen/ts"
  }
}
```

```ts
import { AgentWorkService } from "@talgent/contracts/agent/public/v1/work_pb";
```

The package is generated JavaScript with its declarations, so Vite and `tsc` consume it as it is
and installing it builds nothing. `@bufbuild/protobuf` is a peer dependency, so an app holds one
protobuf runtime; a library built on the contracts, such as `workbench-ui`, declares
`@talgent/contracts` a peer dependency too, so each contract type exists once per app.

## Contracts beyond the protos

- [Trusted identity headers](docs/gateway-identity.md), including the native API's Work
  credential headers and gateway token
- [Content path](docs/storage-content.md): `/v1/storage/content`
- [Originals mount](docs/originals-mount.md): layout, extended attributes and guarantees of the
  read-only mount of every File Space, and the claim a reader references
- [Contracts version header](docs/contracts-version.md): `talgent-contracts-version`

## Development

```sh
buf lint
buf generate                          # Go from go.mod's tool directives, TypeScript from buf.build
bash scripts/ci/check-generated.sh    # every language under gen/ is exactly what proto/ generates
bash test/release-version-test.sh
bash test/check-generated-test.sh
```

## License

Apache-2.0
