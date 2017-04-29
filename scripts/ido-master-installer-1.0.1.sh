#!/bin/bash

DOCKER_VERSION="1.8.3"
PKG="ido-master-1.0.1.tar.gz"
PKG_MD5="a073cbae4cae0ccfecb7e4fc2b32af42"
MASTER_HOME="/opt/ido/master"
DOCKER="/opt/ido/master/bin/docker"
PKG_URL_ROOT="http://index.idevopscloud.com/release-test-e9ee8bce-c006-11e6-b4a4-000c29275eb7"
PIP_PKG_LIST="dnspython==1.15.0 python-heatclient==0.3.0"
APT_PKG_LIST="linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates aufs-tools cgroup-lite git git-man liberror-perl python-dev"
PYPI_MIRROR="http://pypi.douban.com/simple"
DOCKER_REGISTRY_URL="index.idevopscloud.com:5000"
DOCKER_IMAGES="$DOCKER_REGISTRY_URL/idevops/paas-api:1.1.1 \
               $DOCKER_REGISTRY_URL/idevops/paas-controller:1.1 \
               $DOCKER_REGISTRY_URL/idevops/paas-agent:0.9.2 \
               $DOCKER_REGISTRY_URL/idevops/keystone:juno \
               $DOCKER_REGISTRY_URL/idevops/heat:kilo-k8s-1.2.3 \
               $DOCKER_REGISTRY_URL/idevops/mysql:5.5 \
               $DOCKER_REGISTRY_URL/idevops/rabbitmq:3.6.1"

apt_updated="false"

apt_get_update()
{
    if [ "$apt_updated" == "false" ]; then
        apt-get update
        apt_updated="true"
    fi
}

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
        apt_get_update
        apt-get install --force-yes -y docker-engine=1.8.3-0~trusty
    fi  
}

install_dependences()
{
    if !(which pip 1>/dev/null); then
        APT_PKG_LIST="$APT_PKG_LIST python-pip"
    fi

    apt_get_update
    apt-get install --force-yes -y $APT_PKG_LIST
    pip install -i ${PYPI_MIRROR} -U pip
    hash -r
    python -mpip install --no-cache-dir -i ${PYPI_MIRROR} --trusted-host pypi.douban.com -v $PIP_PKG_LIST
}

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
    if [ -d "$MASTER_HOME" ]; then
        echo 'The directory </opt/ido/master> already existed. Please remove that directory first'
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

    mkdir -p /etc/ido/ 2>/dev/null
    cp ${MASTER_HOME}/conf/master.json.template /etc/ido

    mkdir -p ~/.docker 2>/dev/null
    curl -s -o /tmp/docker-config-visitor.json ${PKG_URL_ROOT}/ido-cluster/docker-config-visitor.json
    cp -f /tmp/docker-config-visitor.json ~/.docker/config.json
}

echo "Installing ido-master-1.0.1"
install_tar
install_dependences && restart_docker
if !(pull_images); then
    echo "Failed to install ido-master"
    exit 1
fi
echo -e "\nido-master is installed successfully."
