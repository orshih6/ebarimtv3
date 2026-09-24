# The platform is pinned to amd64 on purpose: ITC ships PosAPI.deb as amd64 only,
# so building on an arm64 host (e.g. Apple Silicon) would otherwise produce an
# image whose PosService cannot start.

# Stage 1: unpack the vendor package. Nothing from this stage ships except the
# files copied out of /out below, so the zips and unpacking tools stay out of
# the final image.
FROM --platform=linux/amd64 ubuntu:24.04 AS unpack

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    binutils \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Build argument to switch between production and non-production versions
ARG PROD=false

COPY *.zip ./

RUN if [ "$PROD" = "true" ]; then \
        FILE="PosService_3.0.12-Prod.zip"; \
    else \
        FILE="ST_PosService_3.0.12-Staging.zip"; \
    fi && \
    unzip -q $FILE && \
    ar --output ./Package/linux/ -x ./Package/linux/PosAPI.deb && \
    tar -xf ./Package/linux/data.tar.xz -C ./Package/linux/ && \
    mkdir -p /out/usr/lib /out/opt/posapi /out/etc/posapi && \
    chmod 644 ./Package/linux/usr/lib/* && \
    cp -a ./Package/linux/usr/lib/. /out/usr/lib/ && \
    cp -a ./Package/linux/opt/posapi/PosService /out/opt/posapi/PosService && \
    cp -a ./Package/linux/etc/posapi/posapi.ini /out/etc/posapi/posapi.ini

# Stage 2: the runtime image.
FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# PosService downloads PosAPI over HTTPS on start, so it needs the CA bundle.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=unpack /out/ /

RUN mkdir -p /var/log/ebarimt && touch /var/log/ebarimt/posapi.log

EXPOSE 7080

# The launcher (PID 1) outlives PosAPI, so a running container proves nothing.
# Check that something actually listens on 7080. TCP rather than HTTP because
# PosAPI answers 503 until the POS is registered, and the image has no curl.
# The start period covers the PosAPI download on first start.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/7080"]

WORKDIR /opt/posapi

CMD ["./PosService"]
