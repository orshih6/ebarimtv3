# ebarimtv3

**English** · [Монгол](README.mn.md)

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
docker run -d --name posapi --restart unless-stopped \
  -p 127.0.0.1:7080:7080 \
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
- Restarts: the launcher does not restart PosAPI when it dies, so the entrypoint
  watches it and exits the container once PosAPI has been gone for 60 s. Run with
  a restart policy (`restart: unless-stopped` in the compose file,
  `--restart unless-stopped` with `docker run`) and it comes back by itself.
  Tunable with `POSAPI_DOWN_GRACE` (default `60`) and `POSAPI_START_TIMEOUT`
  (default `300`, how long the first start may take to download PosAPI).
- Health: the image also has a `HEALTHCHECK` on port 7080, shown in `docker ps`.

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
- **The launcher does not restart PosAPI if it dies.** This image's entrypoint
  makes the container exit instead, so use a restart policy (see Run above).
- **PosAPI has no authentication.** Anything that can reach port 7080 can issue
  receipts under your registration. Never publish it to the internet; keep it on
  localhost or a private network that only your POS can reach.

## Using the API

Everything below goes to `http://localhost:7080`. The authoritative reference is
ITC's [POS API 3.0.1 guide (PDF, Mongolian)](https://share.itc.gov.mn/share/developer/POS%20API%203.0.1.pdf);
this is a short tour of it, checked against the PosAPI 3.2.50 that the launcher
currently downloads.

### 1. Activate PosAPI and add a merchant

A fresh PosAPI answers every call with `503 "PosAPI is not configured."` until it
is activated. This is a one-time manual step, and it is stored in `/opt/posapi`,
which is why that directory must be a volume.

1. Open `http://localhost:7080/web` and sign in as a citizen who holds operator
   rights, then pick the operator to activate this PosAPI under.
2. In the operator dashboard, [operator.ebarimt.mn](https://operator.ebarimt.mn),
   find this PosAPI by its POS number and add the merchant by TIN. That sends a
   request to the merchant.
3. The merchant approves it in their own eBarimt system (Хүсэлт → Pos api хүсэлт).
   From then on receipts can be issued for that merchant.

### 2. Check the status

```bash
curl http://localhost:7080/rest/info
```

Returns the operator, `posNo`, `lastSentDate`, `leftLotteries` and the registered
`merchants`. It is the quickest way to see whether activation worked.

### 3. Issue a receipt

`POST /rest/receipt` with the sale. All amounts **include** every tax: an item
with a base price of 1000 and city tax comes to `1000 + 100 VAT + 10 city tax = 1110`.
A B2C receipt for one VAT-able item paid in cash:

```bash
curl -X POST http://localhost:7080/rest/receipt \
  -H 'Content-Type: application/json' \
  -d '{
    "totalAmount": 11000,
    "totalVAT": 1000,
    "totalCityTax": 0,
    "districtCode": "0000",
    "merchantTin": "00000000000",
    "posNo": "001",
    "type": "B2C_RECEIPT",
    "receipts": [{
      "totalAmount": 11000,
      "totalVAT": 1000,
      "totalCityTax": 0,
      "taxType": "VAT_ABLE",
      "merchantTin": "00000000000",
      "items": [{
        "name": "Example item",
        "barCodeType": "UNDEFINED",
        "classificationCode": "0000000",
        "measureUnit": "ш",
        "qty": 1,
        "unitPrice": 11000,
        "totalVAT": 1000,
        "totalCityTax": 0,
        "totalAmount": 11000
      }]
    }],
    "payments": [{
      "code": "CASH",
      "status": "PAID",
      "paidAmount": 11000
    }]
  }'
```

Replace the zeros with real values: `districtCode` (4 digits), `merchantTin`
(11 or 14 digits), and `classificationCode` (7 digits, from the national
product classification). A successful response has `"status": "SUCCESS"` plus
`id` (the 33-digit receipt number), `lottery`, `qrData` and `date`. ITC forbids
storing `lottery` and `qrData` for anything other than printing them on the receipt.

The main values:

| Field | Values |
|---|---|
| `type` | `B2C_RECEIPT`, `B2B_RECEIPT`, `B2C_INVOICE`, `B2B_INVOICE` (invoices need `bankAccountNo`) |
| `taxType` | `VAT_ABLE`, `VAT_FREE`, `VAT_ZERO`, `NO_VAT` (one sub-receipt per tax type) |
| `payments[].code` | `CASH`, `PAYMENT_CARD` |
| `payments[].status` | `PAID`, `PAY`, `REVERSED`, `ERROR` |
| `barCodeType` | `UNDEFINED`, `GS1`, `ISBN` |
| response `status` | `SUCCESS`, `ERROR`, `PAYMENT` (payment details missing) |

For a B2B receipt add `customerTin`. For a B2C receipt, `consumerNo` set to the
buyer's ebarimt number (`11…`) sends it straight to their account (`"easy": true`
in the response). To correct or partly refund a receipt, issue a new one with
`inactiveId` set to the receipt it replaces.

### 4. Cancel a receipt

```bash
curl -X DELETE http://localhost:7080/rest/receipt \
  -H 'Content-Type: application/json' \
  -d '{"id": "<33-digit receipt id>", "date": "2026-01-31 12:00:00"}'
```

`date` is the receipt's own `date` from the issue response.

### 5. Other calls

| Call | Purpose |
|---|---|
| `GET /rest/sendData` | Send pending receipts to eBarimt now instead of waiting |
| `GET /rest/bankAccounts?tin=<TIN>` | Bank accounts registered for a TIN (for invoices) |

The PDF calls the first one `/rest/send`. The current PosAPI answers that path
with `404`; `/rest/sendData` is the one that exists.

**What was verified here:** the routes above exist and answer as described on an
unactivated staging PosAPI. The receipt request follows ITC's field reference;
issuing a real receipt needs an activated PosAPI and a merchant, which this repo
cannot test for you. Try it against the staging image first.

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

A [release](https://github.com/orshih6/ebarimtv3/releases) is created automatically
whenever a new ITC version lands. To be told about updates, watch the repo with
**Watch → Custom → Releases**.

Pull requests only check that both images build; nothing is pushed.

## License

The `Dockerfile`, CI workflow and docs are [MIT](LICENSE). The PosAPI packages are ITC's.

## Upgrading PosAPI

1. Download the new packages from ITC and put them in the repo root, keeping the
   `PosService_<version>-Prod.zip` / `ST_PosService_<version>-Staging.zip` names.
2. Update the two file names in the `Dockerfile`.
3. Delete the previous version's zips.

On push to `main`, CI publishes the new images and creates the release for that
version.
