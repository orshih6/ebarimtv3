# ebarimtv3

[English](README.md) · **Монгол**

ПОС систем ebarimt баримт хэвлэхэд ашигладаг ГТСМТТ-ийн (ITC) **PosAPI 3.0.12**
үйлчилгээг (ebarimt 3.0, НӨАТ-ын систем) Docker image болгон бэлдсэн төсөл. `.deb`
багцыг сервер дээр суулгаж systemd-ээр ажиллуулахын оронд контейнер хэлбэрээр
ажиллуулна.

## Хавсаргасан файлуудын тухай

`PosService_3.0.12-Prod.zip` болон `ST_PosService_3.0.12-Staging.zip` нь ITC-ийн
нийтэлсэн PosAPI-ийн өөрчлөгдөөгүй багцууд юм (багцын maintainer: `itc.gov.mn`).
Эдгээр нь энэ төслийн хэсэг **биш** бөгөөд [MIT лиценз](LICENSE)-д хамаарахгүй,
зохиогчийн эрх нь ITC-д хадгалагдана. Энэ repo зөвхөн `Dockerfile` болон CI-г
нэмсэн.

| Файл | Орчин | `ebarimtUrl` | Нэвтрэлт |
|---|---|---|---|
| `ST_PosService_3.0.12-Staging.zip` | Тестийн орчин (staging, анхдагч) | `https://st-api.ebarimt.mn/` | `https://st.auth.itc.gov.mn/auth/` |
| `PosService_3.0.12-Prod.zip` | Үндсэн орчин (prod) | `https://api.ebarimt.mn/` | `https://auth.itc.gov.mn/auth/` |

## Ажиллуулах

Хамгийн энгийн арга нь repo-д байгаа [`docker-compose.yml`](docker-compose.yml)-ийг
ашиглах. PosAPI-ийн өгөгдлийг нэрлэсэн volume дээр хадгалдаг тул контейнерыг
дахин эхлүүлэх, шинээр үүсгэх, image шинэчлэх үед ПОС-ын бүртгэл алга болохгүй:

```bash
docker compose up -d                       # тестийн орчин (анхдагч)
EBARIMT_ENV=prod docker compose up -d      # үндсэн орчин
```

Тестийн болон үндсэн орчин тус тусдаа volume-тай (`ebarimtv3-staging-data`,
`ebarimtv3-prod-data`) тул нэг орчинд хийсэн бүртгэл нөгөө орчинд хэзээ ч
андуурагдахгүй.

Эсвэл `docker run`-аар:

```bash
docker run -d --name posapi --restart unless-stopped \
  -p 127.0.0.1:7080:7080 \
  -v posapi-staging:/opt/posapi \
  ghcr.io/orshih6/ebarimtv3:3.0.12-staging
```

Ингэснээр PosAPI `http://localhost:7080` хаяг дээр ажиллана. `127.0.0.1:` угтвар
чухал: зүгээр `-p 7080:7080` гэвэл портыг серверийн бүх сүлжээнд нээнэ, харин
PosAPI-д нэвтрэлт огт байхгүй (доороос үзнэ үү).

- Өгөгдөл: `/opt/posapi` — татагдсан PosAPI, `vatps.db` болон бүртгэл. Энд
  нэрлэсэн volume эсвэл серверийн хавтас холбоно. Холбоогүй бол Docker нэргүй
  volume үүсгэх бөгөөд контейнерыг устгахад амархан алга болно.
- Тохиргоо: `/etc/posapi/posapi.ini`. Өөрийн файлаар солих бол:
  `-v $(pwd)/posapi.ini:/etc/posapi/posapi.ini:ro`
- Лог: `/var/log/ebarimt/posapi.log`
- Дахин асаалт: launcher нь PosAPI унтарвал дахин асаадаггүй. Тиймээс entrypoint
  нь PosAPI-г хянаж, 60 секунд ажиллахгүй байвал контейнерыг зогсооно. Restart
  policy-тай ажиллуулбал (compose файлд `restart: unless-stopped`, `docker run`-д
  `--restart unless-stopped`) өөрөө дахин асна. `POSAPI_DOWN_GRACE` (анхдагч `60`)
  болон `POSAPI_START_TIMEOUT` (анхдагч `300`, анх асахдаа PosAPI татах хугацаа)
  хувьсагчаар тохируулж болно.
- Эрүүл мэнд: image нь 7080 порт дээр `HEALTHCHECK`-тэй, `docker ps`-д харагдана.

## Image дотор юу ажилладаг вэ

`PosService` нь API сервер **биш**, жижиг launcher/шинэчлэгч юм. Асахдаа
`posapi.ini`-г уншиж, `updaterUrl`-аас одоогийн хувилбарыг асууж, жинхэнэ
**PosAPI**-г `workDir` (`/opt/posapi`) руу татаж задлаад, ажиллуулж хянана.
7080 порт дээр сонсож байгаа нь PosAPI бөгөөд өгөгдлөө `/opt/posapi/vatps.db`
(SQLite)-д хадгална: мерчантын бүртгэл болон eBarimt руу хараахан илгээгээгүй
баримтын дараалал.

Үүнээс үүдэх зүйлс:

- **PosAPI-ийн хувилбарыг энэ image биш, ITC шийднэ.** `3.0.12` нь launcher-ийн
  хувилбар; татаж авах сервер нь тухайн үед ITC-ийн түгээж буй хувилбар байна.
- **Контейнер гадагшаа HTTPS холболттой байх ёстой** — хоосон `/opt/posapi`-тай
  асахдаа `*.ebarimt.mn`, `*.auth.itc.gov.mn` руу хандана.
- **`/opt/posapi` бол код биш, өгөгдөл.** Бүртгэлээ хадгалахын тулд энэ хавтсыг
  заавал хадгална. Image нь launcher-ээ `/usr/local/lib/posapi`-д хадгалж, асах
  бүрдээ `/opt/posapi` руу хуулдаг тул ямар ч volume эсвэл хоосон хавтас холбож
  болно.
- **Нэг бүртгэлд нэг контейнер.** Нэг өгөгдлийн сан дээр хоёр контейнер хэзээ ч
  зэрэг бүү ажиллуул.
- **Launcher нь PosAPI унтарвал дахин асаадаггүй.** Энэ image-ийн entrypoint
  оронд нь контейнерыг зогсоодог тул restart policy ашиглана уу (дээрх
  "Ажиллуулах" хэсгийг үзнэ үү).
- **PosAPI-д нэвтрэлт байхгүй.** 7080 порт руу хандаж чадах хэн ч таны бүртгэлээр
  баримт хэвлэж чадна. Интернэтэд хэзээ ч бүү нээ; зөвхөн localhost эсвэл
  зөвхөн таны ПОС хандах дотоод сүлжээнд байлга.

## API ашиглах

Доорх бүх хүсэлт `http://localhost:7080` руу явна. Албан ёсны лавлах нь ITC-ийн
[POS API 3.0.1 гарын авлага (PDF)](https://share.itc.gov.mn/share/developer/POS%20API%203.0.1.pdf);
энд түүний товч тоймыг launcher-ийн одоо татаж буй PosAPI 3.2.50 дээр шалгаж
бичсэн.

### 1. PosAPI идэвхжүүлэх, мерчант нэмэх

Шинэ PosAPI идэвхжих хүртлээ бүх хүсэлтэд `503 "PosAPI is not configured."` гэж
хариулна. Энэ нь нэг удаагийн гар ажиллагаа бөгөөд `/opt/posapi`-д хадгалагддаг —
тиймээс тэр хавтас volume байх ёстой.

1. `http://localhost:7080/web` хаягийг нээж, операторын эрхтэй иргэнээр нэвтэрч,
   энэ PosAPI-г аль операторын нэр дээр идэвхжүүлэхээ сонгоно.
2. Операторын удирдлагын самбар [operator.ebarimt.mn](https://operator.ebarimt.mn)
   дээр энэ PosAPI-г ПОС-ын дугаараар хайж олоод мерчантыг ТТД-аар нь нэмнэ.
   Ингэснээр мерчант руу хүсэлт илгээгдэнэ.
3. Мерчант өөрийн eBarimt систем дээр (Хүсэлт → Pos api хүсэлт) баталгаажуулна.
   Үүнээс хойш тухайн мерчантын нэрээр баримт хэвлэх боломжтой болно.

### 2. Төлөв шалгах

```bash
curl http://localhost:7080/rest/info
```

Оператор, `posNo`, `lastSentDate`, `leftLotteries` болон бүртгэлтэй `merchants`-ийг
буцаана. Идэвхжүүлэлт амжилттай болсон эсэхийг шалгах хамгийн хурдан арга.

### 3. Баримт хэвлэх

Борлуулалтын мэдээллийг `POST /rest/receipt`-ээр илгээнэ. Бүх дүн **бүх төрлийн
татвар шингэсэн** байна: үндсэн үнэ нь 1000, НХАТ тооцох бараа бол
`1000 + 100 НӨАТ + 10 НХАТ = 1110`. Бэлнээр төлсөн, НӨАТ тооцох нэг бараатай
B2C баримт:

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

Тэгүүдийг жинхэнэ утгаар солино: `districtCode` (4 оронтой орон нутгийн код),
`merchantTin` (11 эсвэл 14 оронтой ТТД), `classificationCode` (Бүтээгдэхүүн,
үйлчилгээний нэгдсэн ангиллын 7 оронтой код). Амжилттай бол хариуд
`"status": "SUCCESS"` болон `id` (33 оронтой ДДТД), `lottery`, `qrData`, `date`
ирнэ. `lottery` болон `qrData`-г баримтад хэвлэхээс өөр зорилгоор хадгалахыг ITC
хориглодог.

Гол утгууд:

| Талбар | Утга |
|---|---|
| `type` | `B2C_RECEIPT`, `B2B_RECEIPT`, `B2C_INVOICE`, `B2B_INVOICE` (нэхэмжлэхэд `bankAccountNo` заавал) |
| `taxType` | `VAT_ABLE`, `VAT_FREE`, `VAT_ZERO`, `NO_VAT` (татварын төрөл тус бүрээр дэд баримт) |
| `payments[].code` | `CASH`, `PAYMENT_CARD` |
| `payments[].status` | `PAID`, `PAY`, `REVERSED`, `ERROR` |
| `barCodeType` | `UNDEFINED`, `GS1`, `ISBN` |
| хариуны `status` | `SUCCESS`, `ERROR`, `PAYMENT` (төлбөрийн мэдээлэл дутуу) |

B2B баримтад `customerTin` нэмнэ. B2C баримтад `consumerNo`-д худалдан авагчийн
ebarimt-ийн дугаарыг (`11…`) өгвөл баримт шууд түүний бүртгэлд очно (хариуд
`"easy": true`). Баримт засах буюу хэсэгчлэн буцаах бол `inactiveId`-д солих
баримтын ДДТД-г өгч шинэ баримт хэвлэнэ.

### 4. Баримт буцаах

```bash
curl -X DELETE http://localhost:7080/rest/receipt \
  -H 'Content-Type: application/json' \
  -d '{"id": "<33 оронтой ДДТД>", "date": "2026-01-31 12:00:00"}'
```

`date` нь баримт хэвлэх үед хариуд ирсэн `date` утга.

### 5. Бусад хүсэлт

| Хүсэлт | Зориулалт |
|---|---|
| `GET /rest/sendData` | Хүлээгдэж буй баримтуудыг eBarimt руу яг одоо илгээх |
| `GET /rest/bankAccounts?tin=<ТТД>` | ТТД-д бүртгэлтэй банкны данс (нэхэмжлэхэд) |

PDF-д эхнийхийг `/rest/send` гэж бичсэн. Одоогийн PosAPI тэр замд `404`
буцаадаг; ажилладаг нь `/rest/sendData`.

**Энд юуг шалгасан бэ:** дээрх замууд идэвхжээгүй тестийн PosAPI дээр байгаа,
тайлбарласны дагуу хариулдаг. Баримтын хүсэлт нь ITC-ийн талбарын тайлбарыг
дагасан; жинхэнэ баримт хэвлэхэд идэвхжсэн PosAPI болон мерчант хэрэгтэй тул
энэ repo үүнийг таны өмнөөс шалгах боломжгүй. Эхлээд тестийн image дээр туршина уу.

## Бэлэн image-үүд

`main` руу push хийх бүрд **хоёр** хувилбарыг build хийж
`ghcr.io/orshih6/ebarimtv3` руу оруулна:

| Хувилбар | Build arg | Tag-ууд |
|---|---|---|
| staging | `PROD=false` | `sha-<commit>-staging`, `<version>-staging`, `staging` |
| prod | `PROD=true` | `sha-<commit>-prod`, `<version>-prod`, `prod` |

```bash
docker pull ghcr.io/orshih6/ebarimtv3:3.0.12-prod
```

Image-үүд **зөвхөн linux/amd64**, учир нь ITC PosAPI-г зөвхөн amd64-д гаргадаг.
arm64 машин дээр (жишээ нь Apple Silicon) `docker pull`, `docker run`-д
`--platform linux/amd64` нэмнэ; эмуляцаар ажиллана.

`latest` tag санаатайгаар байхгүй: аль eBarimt орчинтой холбогдохыг хэлж
чадахгүй. Хэзээ ч өөрчлөгддөггүй цорын ганц tag нь `sha-<commit>-<variant>` тул
deploy болон буцаалтыг үүгээр хийнэ. `<version>` нь `PosService_<version>-Prod.zip`
файлын нэрээс уншигдана.

ITC-ийн шинэ хувилбар орж ирэх бүрд [Releases](https://github.com/orshih6/ebarimtv3/releases)
хэсэгт шинэ release автоматаар үүснэ. Шинэчлэлийн мэдэгдэл авах бол repo-г
**Watch → Custom → Releases** гэж дагаарай.

Pull request нь хоёр image build болж буйг л шалгана; юу ч push хийхгүй.

## Өөрөө build хийх

```bash
# Тестийн орчин (staging) — анхдагч
docker build -t ebarimtv3:st .

# Үндсэн орчин (prod)
docker build --build-arg PROD=true -t ebarimtv3:prod .
```

## Лиценз

`Dockerfile`, CI болон баримт бичиг нь [MIT](LICENSE). PosAPI багцууд ITC-ийнх.

## PosAPI шинэчлэх

1. ITC-ээс шинэ багцуудыг татаж repo-ийн үндсэн хавтсанд
   `PosService_<version>-Prod.zip` / `ST_PosService_<version>-Staging.zip`
   нэрээр байрлуулна.
2. `Dockerfile` дахь хоёр файлын нэрийг шинэчилнэ.
3. Өмнөх хувилбарын zip-үүдийг устгана.

`main` руу push хийхэд CI шинэ image-үүдийг гаргаж, тухайн хувилбарын release-ийг
үүсгэнэ.
