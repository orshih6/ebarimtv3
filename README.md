# ebarimtv3

A Docker image for **PosAPI 3.0.12**, the ITC service (the ebarimt 3.0 VAT system) that
a point-of-sale system uses to issue ebarimt receipts. Instead of installing the `.deb`
on a host and running it under systemd, you run it as a container.

## About the bundled files

`PosService_3.0.12-Prod.zip` and `ST_PosService_3.0.12-Staging.zip` are the unmodified PosAPI packages
published by ITC (Package maintainer: `itc.gov.mn`). They are **not** part of this
project and are not covered by its [MIT license](LICENSE). Their copyright belongs
to ITC. This repo only adds the `Dockerfile` and CI around them.

| File | Environment | `ebarimtUrl` | Auth |
|---|---|---|---|
| `ST_PosService_3.0.12-Staging.zip` | Staging / test (default) | `https://st-api.ebarimt.mn/` | `https://st.auth.itc.gov.mn/auth/` |
| `PosService_3.0.12-Prod.zip` | Production | `https://api.ebarimt.mn/` | `https://auth.itc.gov.mn/auth/` |

## Build

```bash
# Staging (ST) build — the default
docker build -t ebarimtv3:st .

# Production build
docker build --build-arg PROD=true -t ebarimtv3:prod .
```

## Run

The simplest way is Docker Compose with the included
[`docker-compose.yml`](docker-compose.yml), which keeps PosAPI's state on a named
volume so the POS registration survives restarts, recreation and image upgrades:

```bash
docker compose up -d                       # staging (default)
EBARIMT_ENV=prod docker compose up -d      # production
```

Staging and prod get separate volumes (`ebarimtv3-staging-data`,
`ebarimtv3-prod-data`), so a registration made against one environment is never
picked up by the other.

Or with plain `docker run`:

```bash
docker run -d --name posapi -p 127.0.0.1:7080:7080 \
  -v posapi-staging:/opt/posapi \
  ghcr.io/orshih6/ebarimtv3:3.0.12-staging
```

PosAPI then listens on `http://localhost:7080`. The `127.0.0.1:` prefix matters:
a plain `-p 7080:7080` publishes the port on every interface of the host, and
PosAPI has no authentication (see below).

- Data: `/opt/posapi` — the downloaded PosAPI, `vatps.db` and the registration.
  Mount a named volume or a host directory there. Without one, Docker creates an
  anonymous volume that is easy to lose when the container is removed.
- Config: `/etc/posapi/posapi.ini`. To override it, mount your own file:
  `-v $(pwd)/posapi.ini:/etc/posapi/posapi.ini:ro`
- Logs: `/var/log/ebarimt/posapi.log`
- Health: the image has a `HEALTHCHECK` on port 7080. `docker ps` shows
  `unhealthy` when PosAPI has stopped even though the container is still running.
  Docker does not restart an unhealthy container by itself.

## What the image actually runs

`PosService` is **not** the API server. It is a small launcher/updater. On start
it reads `posapi.ini`, asks `updaterUrl` for the current version, downloads and
unzips the real **PosAPI** binary into `workDir` (`/opt/posapi`), then starts and
supervises it. PosAPI is what listens on 7080, and it keeps its state in
`/opt/posapi/vatps.db` (SQLite): the merchant registration and the queue of
receipts not yet delivered to eBarimt.

What follows from that:

- **The PosAPI version is ITC's choice, not this image's.** `3.0.12` is the
  launcher version; the server it downloads is whatever ITC currently serves.
- **The container needs outbound HTTPS** to `*.ebarimt.mn` and `*.auth.itc.gov.mn`
  to start on an empty `/opt/posapi`.
- **`/opt/posapi` is state, not code.** Persist that directory to keep the
  registration. The image keeps its launcher in `/usr/local/lib/posapi` and copies
  it into `/opt/posapi` on every start, so any volume or host directory can be
  mounted there, including an empty one.
- **Run one container per registration**, never two against the same database.
- **A running container is not proof of a healthy service** — the launcher keeps
  running, and does not restart PosAPI, if PosAPI dies. Watch the health status.
- **PosAPI has no authentication.** Anything that can reach port 7080 can issue
  receipts under your registration. Never publish it to the internet; keep it on
  localhost or a private network that only your POS can reach.

## Prebuilt images

Every push to `main` builds **both** variants and pushes them to
`ghcr.io/orshih6/ebarimtv3`:

| Variant | Build arg | Tags |
|---|---|---|
| staging | `PROD=false` | `sha-<commit>-staging`, `<version>-staging`, `staging` |
| prod | `PROD=true` | `sha-<commit>-prod`, `<version>-prod`, `prod` |

```bash
docker pull ghcr.io/orshih6/ebarimtv3:3.0.12-prod
```

The images are **linux/amd64 only**, because ITC ships PosAPI for amd64 only. On an
arm64 host (e.g. Apple Silicon) add `--platform linux/amd64` to `docker pull` and
`docker run`; it then runs under emulation.

There is no `latest` tag on purpose: it could not say which eBarimt environment
the image talks to. `sha-<commit>-<variant>` is the only tag that never moves, so
deploy and roll back by it. `<version>` is read from the
`PosService_<version>-Prod.zip` file name.

Pull requests only check that both images build; nothing is pushed.

## License

The `Dockerfile`, CI workflow and docs are [MIT](LICENSE). The PosAPI packages are ITC's.

## Upgrading PosAPI

1. Download the new packages from ITC and put them in the repo root, keeping the
   `PosService_<version>-Prod.zip` / `ST_PosService_<version>-Staging.zip` names.
2. Update the two file names in the `Dockerfile`.
3. Delete the previous version's zips.
