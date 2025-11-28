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
| `APPKEY` | Required    | Your Traffmonetizer token. Container exits if not provided. |
| `DEVNAME`| Required    | Device name. Container exits if not provided. |
| `PROXY`  | Optional    | External proxy endpoint in the form `host:port`. |

## Run
```bash
docker run -d \
  --name=traffmonetizer \
  --pull=always \
  --restart=always \
  --privileged \
  --log-driver=json-file \
  --log-opt max-size=5m \
  --log-opt max-file=3 \
  -e TOKEN=AbCdEfGhIjKLmNo \
  -e DEVNAME=C0MPUT3R-0001 \
  -e PROXY=123.456.789.012:34567 \
  techroy23/docker-traffmonetizer:latest
```

## Invite Link
### https://traffmonetizer.com/?aff=92836
