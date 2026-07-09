# warp-docker

Run the official [Cloudflare WARP](https://1.1.1.1/) client in Docker and forward Minecraft TCP traffic through it.

> [!NOTE]
> Cannot guarantee that the WARP client contained in the image is the latest version. If necessary, please [build your own image](#build).

## Usage

### Start the container

To run the WARP client in Docker, just write the following content to `docker-compose.yml` and run `docker-compose up -d`.

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
      # - WARP_ENABLE_NAT=1 # enable nat
    cap_add:
      # Docker already have them, these are for podman users
      - MKNOD
      - AUDIT_WRITE
      # additional required cap for warp, both for podman and docker
      - NET_ADMIN
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv4.conf.all.src_valid_mark=1
      # uncomment for nat
      # - net.ipv4.ip_forward=1
      # - net.ipv6.conf.all.forwarding=1
      # - net.ipv6.conf.all.accept_ra=2
    volumes:
      - ./data:/var/lib/cloudflare-warp
```

Try it out to see if it works:

```bash
nc -vz 127.0.0.1 8080
```

If the TCP connection succeeds, the container is listening and forwarding traffic to the configured Minecraft server through WARP.

### Configuration

You can configure the container through the following environment variables:

- `WARP_SLEEP`: The time to wait for the WARP daemon to start, in seconds. The default is 2 seconds. If the time is too short, it may cause the WARP daemon to not start before using the proxy, resulting in the proxy not working properly. If the time is too long, it may cause the container to take too long to start. If your server has poor performance, you can increase this value appropriately.
- `WARP_LICENSE_KEY`: The license key of the WARP client, which is optional. If you have subscribed to WARP+ service, you can fill in the key in this environment variable. If you have not subscribed to WARP+ service, you can ignore this environment variable.
- `MC_SERVER_HOST`: The Minecraft server hostname to forward to. The default is `mc.example.com`. The container listens on TCP port 8080 and forwards to `${MC_SERVER_HOST}:25565`.
- `REGISTER_WHEN_MDM_EXISTS`: If set, will register consumer account (WARP or WARP+, in contrast to Zero Trust) even when `mdm.xml` exists. You usually don't need this, as `mdm.xml` are usually used for Zero Trust. However, some users may want to adjust advanced settings in `mdm.xml` while still using consumer account.
- `BETA_FIX_HOST_CONNECTIVITY`: If set, will add checks for host connectivity into healthchecks and automatically fix it if necessary. See [host connectivity issue](docs/host-connectivity.md) for more information.
- `WARP_ENABLE_NAT`: If set, will work as warp mode and turn NAT on. You can route L3 traffic through `warp-docker` to Warp. See [nat gateway](docs/nat-gateway.md) for more information.

Data persistence: Use the host volume `./data` to persist the data of the WARP client. You can change the location of this directory or use other types of volumes. If you modify the `WARP_LICENSE_KEY`, please delete the `./data` directory so that the client can detect and register again.

For advanced usage or configurations, see [documentation](docs/README.md).

### Image

The image is published to GitHub Container Registry as `ghcr.io/<owner>/<repository>:latest`. Replace `owner` in the examples with your GitHub organization or username.

## Build

You can use Github Actions to build the image yourself.

1. Fork this repository.
2. Push to any branch to trigger the workflow.

This will build `linux/amd64` and `linux/arm64` images using `debian:bookworm-slim`, push architecture-specific tags to GitHub Container Registry, and publish a multi-arch `latest` manifest.

If you want to build the image locally, you can use [`.github/workflows/build-publish.yml`](.github/workflows/build-publish.yml) as a reference.

## Common problems

### How to connect from another container

You may want to use the forwarder from another container and find that you cannot connect to `127.0.0.1:8080` in that container. This is because the `docker-compose.yml` only maps the port to the host, not to other containers. To solve this problem, you can use the service name as the hostname, for example, `warp:8080`. You also need to put the two containers in the same docker network.

### "Operation not permitted" when open tun

Error like `{ err: Os { code: 1, kind: PermissionDenied, message: "Operation not permitted" }, context: "open tun" }` is caused by [a updated of containerd](https://github.com/containerd/containerd/releases/tag/v1.7.24). You need to pass the tun device to the container following the [instruction](docs/tun-not-permitted.md).

### NFT error on Synology or QNAP NAS

If you are using Synology or QNAP NAS, you may encounter an error like `Failed to run NFT command`. This is because both Synology and QNAP use old iptables, while WARP uses nftables. It can't be easily fixed since nftables need to be added when the kernel is compiled.

Possible solutions:
- If you don't need UDP support, use the WARP's proxy mode by following the instructions in the [documentation](docs/proxy-mode.md).
- If you need UDP support, run a fully virtualized Linux system (KVM) on your NAS or use another device to run the container.

References that might help:
- [Related issue](https://github.com/cmj2002/warp-docker/issues/16)
- [Request of supporting iptables in Cloudflare Community](https://community.cloudflare.com/t/legacy-support-for-docker-containers-running-on-synology-qnap/733983)

### Container runs well but cannot connect from host

This issue often arises when using Zero Trust. You may find that the Minecraft forwarder works inside the container, but cannot connect to `127.0.0.1:8080` outside the container (from host or another container). This is because Cloudflare WARP client is grabbing the traffic. See [host connectivity issue](docs/host-connectivity.md) for solutions.

### How to enable MASQUE / use with Zero Trust / set up WARP Connector / change health check parameters

See [documentation](docs/README.md).

### Permission issue when using Podman

See [documentation](docs/podman.md) for explaination and solution.

## Further reading

For how it works, read my [blog post](https://blog.caomingjun.com/run-cloudflare-warp-in-docker/en/#How-it-works).
