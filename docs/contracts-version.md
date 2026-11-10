# Contracts Version Header

Every response of the Workbench's Connect services, the controlplane's and the stream
gateway's included, carries the version of this repository the Workbench was built with:

```http
talgent-contracts-version: v0.4.2
```

- The value is a release tag of this repository, `vMAJOR.MINOR.PATCH`, read from the build's
  module information. A build that does not name a release sends no header.
- A consumer compares it with the contracts version it was built with. A value at least that
  version proves every stable stub the consumer uses exists in the Workbench, because stable
  packages only grow. It does not prove the Workbench implements them.
- A missing, unparsable or lower value means the Workbench is older than the consumer: the
  consumer treats it as incompatible rather than assuming compatibility.
