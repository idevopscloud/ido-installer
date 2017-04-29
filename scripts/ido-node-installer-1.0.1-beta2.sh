#!/bin/bash

PKG="ido-node-1.0.1-beta2.tar.gz"
NODE_HOME="/opt/ido/node"

if [ -d "${NODE_HOME}" ]; then
    echo "The directory <${NODE_HOME}> already existed. Please remove that directory first"
    exit 1
fi

apt-get update
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual

rm -f /tmp/${PKG} 2>/dev/null
rm -f /tmp/docker-config-visitor.json 2>/dev/null

cd /tmp
curl -s -o docker-config-visitor.json http://index.idevopscloud.com/release/ido-cluster/docker-config-visitor.json
wget http://index.idevopscloud.com/release/ido-cluster/${PKG}
if [ $? != 0 ]; then
    echo "Failed to download package."
    exit 1
fi

mkdir -p /opt/ido 2>/dev/null
cp /tmp/${PKG} /opt/ido
cd /opt/ido
tar xzf ${PKG}
mkdir -p /etc/ido/ 2>/dev/null

mkdir -p ~/.docker 2>/dev/null
cp -f /tmp/docker-config-visitor.json ~/.docker/config.json

echo "ido-node is installed successfully."
