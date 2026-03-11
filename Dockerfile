# Build stage
FROM debian:trixie-slim AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN make clean all

# Runtime stage
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy executables
COPY --from=builder /build/packet_forwarder/lora_pkt_fwd .
COPY --from=builder /build/util_chip_id/chip_id .
COPY --from=builder /build/util_boot/boot .
COPY --from=builder /build/util_spectral_scan/spectral_scan .

# Copy reset script and configs
COPY --from=builder /build/tools/reset_lgw.sh .
COPY --from=builder /build/packet_forwarder/global_conf.json.* .

# Create a wrapper script
RUN echo '#!/bin/sh\n\
./reset_lgw.sh stop\n\
./reset_lgw.sh start\n\
\n\
# Use GLOBAL_CONF environment variable or default to EU868\n\
CONF_FILE=${GLOBAL_CONF:-global_conf.json.sx1250.EU868}\n\
\n\
if [ ! -f "$CONF_FILE" ]; then\n\
    echo "Configuration file $CONF_FILE not found!"\n\
    exit 1\n\
fi\n\
\n\
echo "Starting packet forwarder with $CONF_FILE"\n\
exec ./lora_pkt_fwd -c "$CONF_FILE"\n\
' > /app/start.sh && chmod +x /app/start.sh

ENTRYPOINT ["/app/start.sh"]
