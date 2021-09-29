#!/bin/bash
# Usage: ./install_docker.sh <USERNAME>

# Install Docker
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Install fuse-overlayfs
wget https://github.com/containers/fuse-overlayfs/releases/download/v1.7.1/fuse-overlayfs-x86_64
chmod +x fuse-overlayfs-x86_64
sudo mv fuse-overlayfs-x86_64 /usr/local/bin/fuse-overlayfs

# Modify Docker storage driver
echo '{ "storage-driver": "overlay" }' | sudo tee /etc/docker/daemon.json > /dev/null

# Restart Docker host
sudo systemctl restart docker

# Add user to Docker group if supplied as input
if [ -z "$1" ]
then
    echo "No user supplied. Will not add user to Docker group."
else
    sudo usermod -g docker $1
fi

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
