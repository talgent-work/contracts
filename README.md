# Talgent Contracts

The contracts of the Talgent Workbench: its public, private and integration contracts as
protobuf sources with their generated Go, and the contracts no proto expresses. Talgent
Workbench and the products that extend it each depend on one version of this module.

## Layout

| Path | Holds |
|---|---|
| `proto/<context>/public/v1` | Externally supported RPC contracts |
| `proto/<context>/private/v1` | Deployment-private RPC contracts between trusted services |
| `proto/<context>/integration/v1` | Integration Messages a context publishes |
| `gen/<context>/<surface>/v1` | Generated Go and Connect code; never edited by hand |
| `docs/` | Contracts no proto expresses |

## Naming

- A proto package is `<context>.<surface>.v1`, such as `storage.private.v1`.
- Its Go package is `github.com/talgent-work/contracts/gen/<context>/<surface>/v1`, named
  `<context><surface>v1`; Connect stubs are in its `<context><surface>v1connect` subpackage,
  generated for `connectrpc.com/connect/v2`.
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

Go:

```sh
go get github.com/talgent-work/contracts@v0.1.0
```

The module carries the protos too, so one version in `go.mod` pins both. A consumer's Buf
configuration reads them from the module cache:

```sh
go list -m -f '{{.Dir}}' github.com/talgent-work/contracts   # protos are under proto/
```

No npm package is published; each web app generates its own TypeScript from the protos.

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
buf generate                          # generators run from go.mod's tool directives
bash scripts/ci/check-generated.sh    # gen/ is exactly what proto/ generates
bash test/release-version-test.sh
bash test/check-generated-test.sh
```

## License

Apache-2.0
