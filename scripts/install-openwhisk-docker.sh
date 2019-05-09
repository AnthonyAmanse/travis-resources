#!/bin/bash

DOCKER_COMPOSE="docker-compose"
DOCKER_COMPOSE_TMP="$DOCKER_COMPOSE.bin"

if [ -z "${DOCKER_COMPOSE_VERSION}" ]; then
    DOCKER_COMPOSE_VERSION="1.13.0"
fi

version_exists=$( (docker-compose --version | grep "${DOCKER_COMPOSE_VERSION}") || echo "false" )

# This script assumes Docker is already installed
# Trusty for Travis SHOULD include latest docker compose (e.g., 1.13.0)
if [ "${version_exists}" == "false" ]
then
    echo "Installing Docker Compose ${DOCKER_COMPOSE_VERSION}"
    if [ -f /usr/local/bin/$DOCKER_COMPOSE ]; then
        sudo rm /usr/local/bin/$DOCKER_COMPOSE
    fi
    curl -L https://github.com/docker/compose/releases/download/"${DOCKER_COMPOSE_VERSION}"/docker-compose-"$(uname -s)"-"$(uname -m)" > $DOCKER_COMPOSE_TMP
    chmod +x $DOCKER_COMPOSE_TMP
    sudo mv $DOCKER_COMPOSE_TMP /usr/local/bin/$DOCKER_COMPOSE
fi
echo "Docker Compose Version:" "$(docker-compose --version)"

git clone https://github.com/apache/incubator-openwhisk-devtools
# overwrite makefile
# Makefile is a modified makefile to silence zip commands
cp "$(dirname "$0")"/../Makefile-openwhisk incubator-openwhisk-devtools/docker-compose/Makefile
pushd incubator-openwhisk-devtools/docker-compose || exit 1

# checkout specific commit
git checkout 1f27b3b2c5ad5dec49591ed0d4edebfeb53653d4

make quick-start

# add system packages
make add-catalog create-provider-alarms create-provider-kafka create-provider-cloudant

# check providers health
echo "..."
echo "Waiting for alarm provider to be up"
until (curl --silent http://localhost:8081/health > /dev/null); do printf '.'; sleep 5; done
echo "Alarm package is up"
echo "Waiting for kafka provider to be up"
until (curl --silent http://localhost:8082/health > /dev/null); do printf '.'; sleep 5; done
echo "Kafka/messaging package is up"
echo "Waiting for cloudant provider to be up"
until (curl --silent http://localhost:5000/health > /dev/null); do printf '.'; sleep 5; done
echo "Cloudant package is up"

# move wskprops and wsk binary
mv "$(pwd)"/.wskprops "${HOME}"/.wskprops
sudo mv ./openwhisk-src/bin/wsk /usr/local/bin/wsk
popd || exit 1

wsk -i list
wsk -i package list /whisk.system
wsk -i action invoke /whisk.system/utils/echo --param message "Hello, World!" --result
