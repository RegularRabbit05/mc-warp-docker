ARG BASE_IMAGE=debian:bookworm-slim

FROM ${BASE_IMAGE}

ARG WARP_VERSION
ARG COMMIT_SHA
ARG TARGETPLATFORM

LABEL org.opencontainers.image.authors="regularrabbit05"
LABEL org.opencontainers.image.url="https://github.com/RegularRabbit05/mc-warp-docker"
LABEL WARP_VERSION=${WARP_VERSION}
LABEL COMMIT_SHA=${COMMIT_SHA}

COPY entrypoint.sh /entrypoint.sh
COPY ./healthcheck /healthcheck

# install dependencies
RUN echo "Building for ${TARGETPLATFORM}" && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl gnupg lsb-release sudo jq ipcalc socat && \
    curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    apt-get clean && \
    apt-get autoremove -y && \
    chmod +x /entrypoint.sh && \
    chmod +x /healthcheck/index.sh && \
    useradd -m -s /bin/bash warp && \
    echo "warp ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/warp

USER warp

# Accept Cloudflare WARP TOS
RUN mkdir -p /home/warp/.local/share/warp && \
    echo -n 'yes' > /home/warp/.local/share/warp/accepted-tos.txt

ENV MC_SERVER_HOST=mc.example.com
ENV WARP_SLEEP=2
ENV REGISTER_WHEN_MDM_EXISTS=
ENV WARP_LICENSE_KEY=
ENV BETA_FIX_HOST_CONNECTIVITY=
ENV WARP_ENABLE_NAT=

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD /healthcheck/index.sh

ENTRYPOINT ["/entrypoint.sh"]
