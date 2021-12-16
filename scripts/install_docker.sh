#!/bin/bash
# Usage: ./install_docker.sh <USERNAME>

# Install Docker
apt update
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release build-essential git
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Add user to Docker group if supplied as input
[ -n "$1" ] && usermod -g docker $1

# Add metrics collection to Docker daemon
echo '{
  "metrics-addr" : "127.0.0.1:9323",
  "experimental" : true,
  "storage-driver": "overlay2"
}' > /etc/docker/daemon.json

# Restart Docker host
systemctl restart docker

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
