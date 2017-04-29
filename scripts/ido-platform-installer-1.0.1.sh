#!/bin/bash

PKG="ido-platform-1.0.1.tar.gz"
PKG_URL_ROOT="http://index.idevopscloud.com/release-test-e9ee8bce-c006-11e6-b4a4-000c29275eb7"
PKG_MD5="c00cf477005fbd8f8679c14425fbc27e"
PLATFORM_HOME="/opt/ido/platform"
APT_PKG_LIST="linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates aufs-tools cgroup-lite git git-man liberror-perl python-pip libmysqlclient-dev python-dev"
PIP_PKG_LIST="MySQL-python==1.2.5"
PIP_MIRROR="http://pypi.douban.com/simple"
DOCKER="/opt/ido/platform/bin/docker"
DOCKER_REGISTRY_URL="index.idevopscloud.com:5000"
DOCKER_IMAGES="$DOCKER_REGISTRY_URL/idevops/redis:2.8 \
               $DOCKER_REGISTRY_URL/idevops/registry:2.5.1 \
               $DOCKER_REGISTRY_URL/idevops/account_management:1.0.1 \
               $DOCKER_REGISTRY_URL/idevops/application_management:1.0.1 \
               $DOCKER_REGISTRY_URL/idevops/platform_core:1.0.1 \
               $DOCKER_REGISTRY_URL/idevops/platform_frontend:1.0.1.1 \
               $DOCKER_REGISTRY_URL/idevops/platform_registry:1.0.1 \
               $DOCKER_REGISTRY_URL/idevops/platform-jenkins:1.0.1 \
               $DOCKER_REGISTRY_URL/idevops/cd-api:1.0.1"
apt_updated="false"

if [ -d "${PLATFORM_HOME}" ]; then
    echo "The directory <${PLATFORM_HOME}> already existed. Please remove that directory first"
    exit 1
fi

kill_docker()
{
    service docker stop >/dev/null 2>&1
    killall docker >/dev/null 2>&1
}

restart_docker()
{
    kill_docker >/dev/null 2>&1
    $DOCKER -d --storage-driver=aufs --insecure-registry $DOCKER_REGISTRY_URL -l error > /dev/null 2>&1 &
}

apt_get_update()
{
    if [ "$apt_updated" == "false" ]; then
        apt-get update
        apt_updated="true"
    fi
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

install_tar()
{
    if [ -d "$PLATFORM_HOME" ]; then
        echo "The directory <$PLATFORM_HOME> already existed. Please remove that directory first"
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
    cp ${PLATFORM_HOME}/conf/platform.json.template /etc/ido

    mkdir -p ~/.docker >/dev/null 2>&1
    curl -s -o /tmp/docker-config-visitor.json ${PKG_URL_ROOT}/ido-cluster/docker-config-visitor.json
    cp -f /tmp/docker-config-visitor.json ~/.docker/config.json

    cp $PLATFORM_HOME/conf/platform.json.template /etc/ido/
    cp $PLATFORM_HOME/bin/docker /usr/bin
    mkdir -p /var/log/ido >/dev/null 2>&1

    rm -f /usr/local/bin/platformctl 2>&1 >/dev/null
    ln -s $PLATFORM_HOME/bin/platformctl /usr/local/bin
}

pull_images()
{
    for image in $DOCKER_IMAGES
    do
        fail=true
        for ((i=0;i<3;i++))
        do
            $DOCKER pull $image
            if [ $? == 0 ];then
                fail=false
                break
            fi
        done
        if [ $fail == true ]; then
            echo "Failed to pull image $image"
            return 1
        fi
    done
}

echo "ido-platform installing started"
install_tar
install_dependences && restart_docker
if !(pull_images); then
    echo "Failed to install ido-platform"
    exit 1
fi
install_dependences && echo -e "\nido-platform is installed successfully."

