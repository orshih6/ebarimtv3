# ebarimtv3

A Docker image for **PosAPI 3.0.9**, the ITC service (the ebarimt 3.0 VAT system) that
a point-of-sale system uses to issue ebarimt receipts. Instead of installing the `.deb`
on a host and running it under systemd, you run it as a container.

## About the bundled files

`PosService_3.0.9.zip` and `ST_PosService_3.0.9.zip` are the unmodified PosAPI packages
published by ITC (Package maintainer: `itc.gov.mn`). They are **not** part of this
project and are not covered by any license this repo may carry. Their copyright belongs
to ITC. This repo only adds the `Dockerfile` and CI around them.

| File | Environment | `ebarimtUrl` | Auth |
|---|---|---|---|
| `ST_PosService_3.0.9.zip` | Staging / test (default) | `https://st-api.ebarimt.mn/` | `https://st.auth.itc.gov.mn/auth/` |
| `PosService_3.0.9.zip` | Production | `https://api.ebarimt.mn/` | `https://auth.itc.gov.mn/auth/` |

## Build

```bash
# Staging (ST) build — the default
docker build -t ebarimtv3:st .

# Production build
docker build --build-arg PROD=true -t ebarimtv3:prod .
```

## Run

```bash
docker run -d --name posapi -p 7080:7080 ebarimtv3:st
```

PosAPI then listens on `http://localhost:7080`.

- Config: `/etc/posapi/posapi.ini`. To override it, mount your own file:
  `-v $(pwd)/posapi.ini:/etc/posapi/posapi.ini:ro`
- Logs: `/var/log/ebarimt/posapi.log`
- Data: PosAPI keeps its SQLite database (`vatps.db`) in its working directory
  `/opt/posapi`, which is also where the binary lives. That database is lost if you
  delete the container. Plan how you persist it before you use the image in production.

## Prebuilt images

Every push to `main` builds the **staging** image, pushes it to
`ghcr.io/orshih6/ebarimtv3:<version>`, and adds a git tag for that version.
Pull requests only check that the image builds.

## Upgrading PosAPI

Download the new packages from ITC, replace the two zips, and update the file names in
the `Dockerfile`.
