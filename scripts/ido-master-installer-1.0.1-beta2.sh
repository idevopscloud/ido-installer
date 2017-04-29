#!/bin/bash

DOCKER_VERSION="1.8.3"
PKG="ido-master-1.0.1-beta2.tar.gz"
MASTER_HOME="/opt/ido/master"
PIP_PKG_LIST="dnspython==1.15.0"
APT_PKG_LIST="linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates aufs-tools cgroup-lite git git-man liberror-perl"

install_docker()
{
    if [[ $(which docker) ]]; then
        if [[ $(docker --version | grep $DOCKER_VERSION) ]]; then
            log "docker $DOCKER_VERSION already installed"
        else
            log "The installed docker is $(docker version | grep "Client version" | cut -d ' ' -f 3)"
            log "Please uninstall the docker and run this script again"
            log "Stopped"
            exit 1
        fi  
    else
        apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
        echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install --force-yes -y docker-engine=1.8.3-0~trusty
    fi  
}

install_dependences()
{
    if !(which pip 1>/dev/null); then
        apt-get install -y python-pip
    fi

    apt-get update
    pip install -v $PIP_PKG_LIST
    apt-get install -y $APT_PKG_LIST
}

if [ -d "/opt/ido/master" ]; then
    echo 'The directory </opt/ido/master> already existed. Please remove that directory first'
    exit 1
fi

cd /tmp
rm -f /tmp/${PKG} 2>/dev/null
rm -f /tmp/docker-config-visitor.json 2>/dev/null
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
cp ${MASTER_HOME}/conf/master.json.template /etc/ido

mkdir -p ~/.docker 2>/dev/null
cp -f /tmp/docker-config-visitor.json ~/.docker/config.json

install_dependences
#install_docker

echo "ido-master is installed successfully."

