# Use the proxy mode of WARP

> [!NOTE]
> This article is based on the current WARP documentation, and the WARP commands may be changed by Cloudflare in the future. If you encounter any issues during following the instructions, please open an issue.

> [!WARNING]
> UDP support is not available in the proxy mode of WARP.

Use `docker exec -it warp bash` to get into the container and run the following commands:

```bash
warp-cli mode proxy
warp-cli proxy port 40000
```

Create a new healthcheck script `new-healthcheck.sh` with content:

```bash
#!/bin/bash

curl -fsS --socks5-hostname 127.0.0.1:40000 "https://cloudflare.com/cdn-cgi/trace" | grep -qE "warp=(plus|on)" || exit 1
exit 0
```

Update the `docker-compose.yml` file to mount new healthcheck to `/healthcheck/connected-to-warp.sh`:

For example, the default `docker-compose.yml` file will be changed to:

```yaml
version: "3"

services:
  warp:
    image: ghcr.io/owner/mc-warp-docker:latest
    container_name: warp
    restart: always
    # add removed rule back (https://github.com/opencontainers/runc/pull/3468)
    device_cgroup_rules:
      - 'c 10:200 rwm'
    ports:
      - "8080:8080"
    environment:
      - WARP_SLEEP=2
      - MC_SERVER_HOST=mc.example.com
      # - WARP_LICENSE_KEY= # optional
    cap_add:
      # Docker already have them, these are for podman users
      - MKNOD
      - AUDIT_WRITE
      # additional required cap for warp, both for podman and docker
      - NET_ADMIN
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv4.conf.all.src_valid_mark=1
    volumes:
      - ./data:/var/lib/cloudflare-warp
      - ./new-healthcheck.sh:/healthcheck/connected-to-warp.sh
```

After updating the `docker-compose.yml` file, run `docker-compose down && docker-compose up -d` to restart the container.
