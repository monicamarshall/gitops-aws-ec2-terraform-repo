#!/bin/bash
set -euo pipefail

# --- OS update & Docker ---
yum update -y
# Amazon Linux 2: Docker from extras
amazon-linux-extras install docker -y || yum install -y docker
systemctl enable docker
systemctl start docker

# --- Kernel / limits for embedded Elasticsearch ---
# SonarQube requires these on the host
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=65536
# make persistent
grep -q "vm.max_map_count" /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
grep -q "fs.file-max" /etc/sysctl.conf || echo "fs.file-max=65536" >> /etc/sysctl.conf

# --- Docker volumes (persist data across upgrades) ---
docker volume create sonarqube_data >/dev/null
docker volume create sonarqube_extensions >/dev/null
docker volume create sonarqube_logs >/dev/null

# --- Stop/remove old container if present ---
docker rm -f sonarqube 2>/dev/null || true

# --- Pull a supported Community Build image ---
# TIP: Pin a specific tag for repeatability.
# You can also use: sonarqube:community  (moving tag)
SONAR_TAG="sonarqube:25.9.0.112764-community"
docker pull "$SONAR_TAG"

# --- Run SonarQube ---
docker run -d --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  --ulimit nofile=65536:65536 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  "$SONAR_TAG"
