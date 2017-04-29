#!/bin/bash

PKG="ido-node-1.0.1.tar.gz"
NODE_HOME="/opt/ido/node"
PKG_MD5="5d862d9b04e7e166629d717e7b0b5943"
PKG_URL_ROOT="http://index.idevopscloud.com/release-test-e9ee8bce-c006-11e6-b4a4-000c29275eb7"
PIP_PKG_LIST="dnspython==1.15.0"
PIP_MIRROR="http://pypi.douban.com/simple"
APT_PKG_LIST="linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates aufs-tools cgroup-lite"

apt_updated="false"

if [ -d "${NODE_HOME}" ]; then
    echo "The directory <${NODE_HOME}> already existed. Please remove that directory first"
    exit 1
fi

apt_get_update()
{
    if [ "$apt_updated" == "false" ]; then
        apt-get update
        apt_updated="true"
    fi
}

install_dependences()
{
    if !(which pip 1>/dev/null); then
        APT_PKG_LIST="$APT_PKG_LIST python-pip"
    fi

    apt_get_update
    apt-get install --force-yes -y $APT_PKG_LIST
    pip install -i ${PIP_MIRROR} -U pip
    hash -r
    python -mpip install --no-cache-dir -i ${PIP_MIRROR} --trusted-host pypi.douban.com -v $PIP_PKG_LIST
}

download_tar()
{
    echo "Downloading packages ..."
    mkdir -p /opt/ido >/dev/null 2>&1
    rm -f /opt/ido/$PKG 2>/dev/null
    curl -s -o /opt/ido/$PKG ${PKG_URL_ROOT}/ido-cluster/${PKG}
    if [ $? != 0 ]; then
        echo "Failed to download package."
        exit 1
    fi
}

install_tar()
{
    if [ -d "$NODE_HOME" ]; then
        echo "The directory <$NODE_HOME> already existed. Please remove that directory first"
        exit 1
    fi

    local_pkg="/opt/ido/${PKG}"
    if [ -e "$local_pkg" ]; then
        if (which md5sum >/dev/null 2>&1); then
            local_md5=$(md5sum $local_pkg | awk '{print $1}')
            if [ "$PKG_MD5" != "$local_md5" ]; then
                download_tar
            fi
        else
            download_tar
        fi
    else
        download_tar
    fi

    cd /opt/ido
    tar xzf ${PKG}

    mkdir -p /etc/ido/ >/dev/null 2>&1
    mkdir -p ~/.docker >/dev/null 2>&1

    curl -s -o /tmp/docker-config-visitor.json ${PKG_URL_ROOT}/ido-cluster/docker-config-visitor.json
    cp -f /tmp/docker-config-visitor.json ~/.docker/config.json
    rm -f /tmp/docker-config-visitor.json 2>/dev/null
}

install_tar
install_dependences && echo "ido-node is installed successfully."

