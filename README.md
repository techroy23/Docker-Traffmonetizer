## Traffmonetizer Docker Image

A minimal Alpine based Docker image for running the **Traffmonetizer**.

## Links
| DockerHub | GitHub | Invite |
|----------|----------|----------|
| [![Docker Hub](https://img.shields.io/badge/ㅤ-View%20on%20Docker%20Hub-blue?logo=docker&style=for-the-badge)](https://hub.docker.com/r/techroy23/docker-traffmonetizer) | [![GitHub Repo](https://img.shields.io/badge/ㅤ-View%20on%20GitHub-black?logo=github&style=for-the-badge)](https://github.com/techroy23/Docker-Traffmonetizer) | [![Invite Link](https://img.shields.io/badge/ㅤ-Join%20TraffMonetizer%20Now-brightgreen?logo=linktree&style=for-the-badge)](https://traffmonetizer.com/?aff=92836) |

## Features
- Lightweight Alpine Linux base image.
- Configurable environment variable (`TOKEN`).
- Auto‑update support with `--pull=always`.
- Proxy support via Redsocks.
- Exit IP monitor via `https://ip.12388321.xyz/` (every 15 min, toggleable).

## Usage
- Before running the container, increase socket buffer sizes (required for high‑throughput streaming).
- To make these settings persistent across reboots, add them to /etc/sysctl.conf or a drop‑in file under /etc/sysctl.d/.

```bash
sudo sysctl -w net.core.rmem_max=8000000
sudo sysctl -w net.core.wmem_max=8000000
```

## Environment variables
| Variable | Requirement | Description |
|----------|-------------|-------------|
| `TOKEN`  | Required    | Your Traffmonetizer token. Container exits if not provided. |
| `DEVNAME`| Required    | Device name. Container exits if not provided. |
| `PROXY`  | Optional    | External proxy endpoint. Formats: `host:port` or `user:password@host:port`. |
| `ENABLE_EXIT_IP_MONITOR` | Optional | When `true` (default), curls `https://ip.12388321.xyz/` once after redsocks is up, then every 15 minutes. Set to `false` to disable. |
| `EXIT_IP_MONITOR_INTERVAL` | Optional | Seconds between exit-IP checks (default `900` = 15 minutes). |

## Run
```bash
docker run -d \
  --name=traffmonetizer \
  --cpus=0.25 --pull=always --restart=always \
  --log-driver=json-file --log-opt max-size=1m --log-opt max-file=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e TOKEN=AbCdEfGhIjKLmNo \
  -e DEVNAME=C0MPUT3R-0001 \
  -e PROXY=123.456.789.012:34567 \
  techroy23/docker-traffmonetizer:latest
```

The exit IP monitor is on by default. To disable it, add `-e ENABLE_EXIT_IP_MONITOR=false`; to change the cadence, `-e EXIT_IP_MONITOR_INTERVAL=1800` (seconds).

## Authenticated proxy example
If your SOCKS5 proxy requires credentials, include them in `PROXY` in the form `user:password@host:port`:

```bash
docker run -d \
  --name=traffmonetizer \
  --cpus=0.25 --pull=always --restart=always \
  --log-driver=json-file --log-opt max-size=1m --log-opt max-file=1 \
  --cap-add=NET_ADMIN --cap-add=NET_RAW --sysctl net.ipv4.ip_forward=1 \
  -e TOKEN=AbCdEfGhIjKLmNo \
  -e DEVNAME=C0MPUT3R-0001 \
  -e PROXY=myuser:mypassword@123.456.789.012:34567 \
  techroy23/docker-traffmonetizer:latest
```

## Exit IP monitor
The container checks its public exit IP against `https://ip.12388321.xyz/` once shortly after startup (right after redsocks is configured), then repeats every 15 minutes. Because outbound traffic is transparently routed through the proxy, the reported IP confirms the proxy route is live. Output is pretty-printed JSON via `jq`. Set `ENABLE_EXIT_IP_MONITOR=false` to disable, or `EXIT_IP_MONITOR_INTERVAL` to change the cadence (seconds).

```json
{
  "ip": "198.51.100.23",
  "country_code": "PH",
  "country_name": "Philippines",
  "asn": "AS4775",
  "as_org": "Globe Telecoms"
}
```

## Invite Link
### https://traffmonetizer.com/?aff=92836
