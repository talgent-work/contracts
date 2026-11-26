# Contracts Version Header

Every response of the Workbench's Connect services, the controlplane's and the stream
gateway's included, carries the version of this repository the Workbench was built with:

```http
talgent-contracts-version: v0.4.2
```

- The value is a release tag of this repository, `vMAJOR.MINOR.PATCH`, read from the build's
  module information. A build that does not name a release sends no header.
- It serves diagnosis: it tells an operator which contracts a running Workbench speaks.
  Compatibility is kept where a contract changes ([Compatibility](../README.md#compatibility)),
  so a consumer starts, serves and stays ready whatever the header says.
