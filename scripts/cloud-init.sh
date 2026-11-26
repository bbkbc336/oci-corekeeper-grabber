#!/bin/bash
# Runs once on first boot of the OCI VM: installs Docker and starts Core Keeper server.
set -eux
export DEBIAN_FRONTEND=noninteractive
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

mkdir -p /opt/corekeeper
cd /opt/corekeeper

cat > docker-compose.yml <<'EOF'
services:
  core-keeper:
    image: escaping/core-keeper-dedicated:latest
    container_name: core-keeper-dedicated
    restart: unless-stopped
    stop_grace_period: 2m
    volumes:
      - server-files:/home/steam/core-keeper-dedicated
      - server-data:/home/steam/core-keeper-data
    env_file:
      - core.env
volumes:
  server-files:
  server-data:
EOF

cat > core.env <<'EOF'
ARM64_DEVICE=adlink
WORLD_NAME=Core Keeper Server
MAX_PLAYERS=8
EOF

docker compose up -d
