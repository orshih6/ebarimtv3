# Use the official Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set environment variables to make apt non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    binutils \
    tar \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Create required directories
RUN mkdir -p /opt/posapi /etc/posapi /var/log/ebarimt

# Set the working directory
WORKDIR /tmp

# Build argument to switch between production and non-production versions
ARG PROD=false

# Copy the PosAPI package to the container
COPY . .

# Download and install PosAPI
RUN if [ "$PROD" = "true" ]; then \
        FILE="PosService_3.0.9.zip"; \
    else \
        FILE="ST_PosService_3.0.9.zip"; \
    fi && \
    unzip $FILE && \
    ar --output ./Package/linux/ -vx ./Package/linux/PosAPI.deb && \
    tar -xf ./Package/linux/data.tar.xz -C ./Package/linux/ && \
    chmod 644 ./Package/linux/usr/lib/* && \
    cp -f ./Package/linux/usr/lib/* /usr/lib/ && \
    cp -f ./Package/linux/opt/posapi/PosService /opt/posapi/PosService && \
    cp -f ./Package/linux/etc/posapi/posapi.ini /etc/posapi/posapi.ini && \
    rm -rf ./Package

# Set permissions
RUN touch /var/log/ebarimt/posapi.log

# Expose the port used by PosAPI (adjust if necessary)
EXPOSE 7080

# Set the working directory to where PosService is located
WORKDIR /opt/posapi

# Run the PosService when the container starts
CMD ["./PosService"]
