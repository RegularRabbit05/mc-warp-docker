# Solution to open tun operation not permitted

You are seeing this page because you encounter `{ err: Os { code: 1, kind: PermissionDenied, message: "Operation not permitted" }, context: "open tun" }` or `CRITIC: /dev/net/tun not pass`.

If you get `CRITIC: /dev/net/tun not pass`, update the image to the latest version. It's caused by a [previous (later reverted) fix](#previous-solution) that requires `/dev/net/tun` to be passed to the container. The latest image has removed this requirement. If you still get `{ err: Os { code: 1, kind: PermissionDenied, message: "Operation not permitted" }, context: "open tun" }` after updating the image, please follow the instructions below.

## Problem

On Nov 21, 2024, [containerd](https://github.com/containerd/containerd) released version [1.7.24](https://github.com/containerd/containerd/releases/tag/v1.7.24) which updated [runc](https://github.com/opencontainers/runc) to 1.2.2 and introduced [a breaking change that remove tun/tap from the default device rules](https://github.com/opencontainers/runc/pull/3468).

**This cause `/dev/net/tun` cannot be accessed by the container if the device is not explicitly passed, even if the container has created `/dev/net/tun` by itself.**

Thanks [@hugoghx](https://github.com/hugoghx) for [reporting this issue](https://github.com/cmj2002/warp-docker/issues/41).

## Solution

To solve this issue, you need to add the removed rule back to the container. For example:

```yaml
version: "3"

services:
  warp:
    image: ghcr.io/owner/mc-warp-docker:latest
    container_name: warp
    restart: always
    # ===== Add the following 2 lines =====
    device_cgroup_rules:
      - 'c 10:200 rwm'
    # ================ End ================
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
```

## Previous Solution

> [!NOTE]
> This is a previous (later reverted) solution. Although it solved the problem on most devices, it caused issues on some devices. We have reverted this change.

> [!WARNING]
> This section is only for recording the solution for possible future needs; please **do NOT follow this solution**!

To solve this issue, you need to pass the `/dev/net/tun` device to the container. We also recommend you to update the image to the latest version to avoid any other issues.

To pass the device to the container, you need to add `devices` to service level. For example:

```yaml
version: "3"

services:
  warp:
    image: ghcr.io/owner/mc-warp-docker:latest
    container_name: warp
    restart: always
    # ===== Add the following 2 lines =====
    devices:
      - /dev/net/tun:/dev/net/tun
    # ================ End ================
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
```
