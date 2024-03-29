#!/bin/bash
#
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# start_akraino_portal.sh - start the Akraino portal on the regional controller
#

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Loading values from $BASEDIR/akrainorc"
source $BASEDIR/akrainorc

DATABASE_VERSION=${DATABASE_VERSION:-"1.0.1-SNAPSHOT"}
WORKFLOW_VERSION=${WORKFLOW_VERSION:-"1.0.1-SNAPSHOT"}
PORTAL_VERSION=${PORTAL_VERSION:-"1.0.1-SNAPSHOT"}

DB_IMAGE=${DB_IMAGE:-"nexus3.akraino.org:10003/akraino_schema_db:$DATABASE_VERSION"}
WF_IMAGE=${WF_IMAGE:-"nexus3.akraino.org:10003/akraino-camunda-workflow-engine:$WORKFLOW_VERSION"}
PT_IMAGE=${PT_IMAGE:-"nexus3.akraino.org:10003/akraino-portal:$PORTAL_VERSION"}
LD_IMAGE=${LD_IMAGE:-"openmicroscopy/apacheds"}

NEXUS_URL=${NEXUS_URL:-"https://nexus.akraino.org"}
PORTAL_URL=${PORTAL_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino&a=portal_user_interface&v=$PORTAL_VERSION&e=war"}
TEMPEST_URL=${TEMPEST_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.test_automation&a=test_automation&v=1.0.1-SNAPSHOT&e=tgz"}
YAML_BUILDS_URL=${YAML_BUILDS_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.yaml_builds&a=yaml_builds&v=1.0.1-SNAPSHOT&e=tgz"}
ONAP_URL=${ONAP_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.addon-onap&a=onap-amsterdam-regional-controller-master&v=1.0.1-SNAPSHOT&e=tgz"}
SAMPLE_VNF_URL=${SAMPLE_VNF_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.sample_vnf&a=sample_vnf&v=1.0.1-SNAPSHOT&e=tgz"}
AIRSHIPINABOTTLE_URL=${AIRSHIPINABOTTLE_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.airshipinabottle_deploy&a=airshipinabottle_deploy&v=1.0.1-SNAPSHOT&e=tgz"}
REDFISH_URL=${REDFISH_URL:-"$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.redfish&a=redfish&v=1.0.1-SNAPSHOT&e=tgz"}

LDAP_FILE_HOME="/opt/akraino/ldap"
TEMPEST_HOME="/opt/akraino/tempest"
YAML_BUILDS_HOME="/opt/akraino/yaml_builds"
ONAP_HOME="/opt/akraino/onap"
SAMPLE_VNF_HOME="/opt/akraino/sample_vnf"
AIRSHIPINABOTTLE_HOME="/opt/akraino/airshipinabottle_deploy"
REDFISH_HOME="/opt/akraino/redfish"
LOG_HOME="/var/log/akraino"

echo "Installing regional controller software using the following artifact references:"
echo ""
echo "DB_IMAGE=$DB_IMAGE"
echo "WF_IMAGE=$WF_IMAGE"
echo "PT_IMAGE=$PT_IMAGE"
echo "LD_IMAGE=$LD_IMAGE"
echo ""
echo "NEXUS_URL=$NEXUS_URL"
echo "PORTAL_URL=$PORTAL_URL"
echo "TEMPEST_URL=$TEMPEST_URL"
echo "YAML_BUILDS_URL=$YAML_BUILDS_URL"
echo "ONAP_URL=$ONAP_URL"
echo "SAMPLE_VNF_URL=$SAMPLE_VNF_URL"
echo "AIRSHIPINABOTTLE_URL=$AIRSHIPINABOTTLE_URL"
echo "REDFISH_URL=$REDFISH_URL"
echo ""

# Find the primary ip address (the one used to access the default gateway)
# This ip will be used for communication between the containers
IP=$(ip route get 8.8.8.8 | grep -o "src .*$" | cut -f 2 -d ' ')
HOSTNAME=$(hostname -s)
if ! grep "$HOSTNAME" /etc/hosts; then
    echo "$IP $HOSTNAME" >> /etc/hosts
fi

echo "Installing required software packages"
apt-get -q update
apt-get install -y apt-transport-https sshpass python python-pip python-requests python-yaml python-jinja2 python-netaddr xorriso unzip 2>&1

## CREATE SSH KEYS IF THEY DO NOT EXIST
echo "Setting up ssh keys for user [$USER] with home [$HOME]"
if ! [ -f $HOME/.ssh/id_rsa ]; then
    echo "  Creating rsa key [$HOME/.ssh/id_rsa]"
    ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -P ""
fi

echo "Checking that docker is running"
if ! docker ps; then
    echo "Docker is not running.  Installing docker..."
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list
    apt-get update -q
    apt-get install -y docker.io aufs-tools  2>&1
fi

# Create log directory
mkdir -p $LOG_HOME

# PostgreSQL
echo "Download DB files"
docker stop akraino-postgres &> /dev/null
docker rm akraino-postgres &> /dev/null
docker image rm $DB_IMAGE &> /dev/null
docker run \
        --detach \
        --restart=unless-stopped \
        --publish 6432:5432 \
        --volume /var/lib/postgres:/var/lib/postgresql/data \
        --network=bridge \
        --name akraino-postgres \
        --env "POSTGRES_USER=admin" \
        --env "POSTGRES_PASSWORD=abc123" \
        $DB_IMAGE

# LDAP
echo "Download ldap files"
rm -rf $LDAP_FILE_HOME
mkdir -p $LDAP_FILE_HOME
wget -q "$PORTAL_URL" -O /tmp/portal_user_interface.war
unzip -oj /tmp/portal_user_interface.war WEB-INF/classes/*.ldif -d $LDAP_FILE_HOME
rm -f /tmp/portal_user_interface.war

docker stop akraino-ldap &> /dev/null
docker rm akraino-ldap &> /dev/null
docker image rm $LD_IMAGE &> /dev/null
docker run \
        --detach \
        --restart=unless-stopped \
        --publish 10389:10389 \
        --volume $LDAP_FILE_HOME/config.ldif:/bootstrap/conf/config.ldif:ro \
        --volume $LDAP_FILE_HOME/akrainousers.ldif:/bootstrap/conf/akrainousers.ldif:ro \
        --name akraino-ldap \
        --env "APACHEDS_INSTANCE=akraino" \
        $LD_IMAGE

# Initialize ldap
echo "Initialize ldap"
sleep 15
docker exec akraino-ldap /bin/bash -c "ldapadd -v -h $IP:10389 -c -x -D uid=admin,ou=system -w secret -f /bootstrap/conf/akrainousers.ldif"

# Intialize DB
echo "Initialize DB"
sleep 30
docker exec akraino-postgres /bin/bash -c "psql -h localhost -p 5432 -U postgres -f /akraino-db_0524.sql"


#yaml builds
echo "Setting up yaml builds content/repositories"
rm -rf $YAML_BUILDS_HOME
mkdir -p $YAML_BUILDS_HOME
chmod 700 $YAML_BUILDS_HOME
wget -q "$YAML_BUILDS_URL" -O - | tar -xoz -C $YAML_BUILDS_HOME

# Portal
docker stop akraino-portal &> /dev/null
docker rm akraino-portal &> /dev/null
docker image rm $PT_IMAGE &> /dev/null
mkdir -p /opt/akraino/server-build
docker run \
        --detach \
        --restart=unless-stopped \
        --publish 8080:8080 \
        --network=bridge \
        --volume /opt/akraino/tomcat/logs:/usr/local/tomcat/logs \
        --volume /opt/akraino/yaml_builds:/opt/akraino/yaml_builds \
        --volume /opt/akraino/server-build:/opt/akraino/server-build \
        --volume /opt/akraino/onap:/opt/akraino/onap \
        --name akraino-portal \
        $PT_IMAGE


# Portal configuration
echo "Updating portal configuration"
sleep 10
docker exec akraino-portal /bin/bash -c "sed -i -e \"s|[^':]*:8080|$IP:8080|g\" /usr/local/tomcat/webapps/AECPortalMgmt/App.Config.js"
docker exec akraino-portal /bin/bash -c "sed -i -e \"s|[^':]*:8073|$IP:8073|g\" /usr/local/tomcat/webapps/AECPortalMgmt/App.Config.js"
docker exec akraino-portal /bin/bash -c "sed -i -e \"s|://[^:]*:|://$IP:|g\" /usr/local/tomcat/webapps/AECPortalMgmt/WEB-INF/classes/app.properties"

docker stop akraino-portal &> /dev/null
docker start akraino-portal &> /dev/null

echo "Final portal configuration"
sleep 10
docker exec akraino-portal /bin/bash -c "cat /usr/local/tomcat/webapps/AECPortalMgmt/App.Config.js"
docker exec akraino-portal /bin/bash -c "cat /usr/local/tomcat/webapps/AECPortalMgmt/WEB-INF/classes/app.properties"

# Workflow
systemctl stop akraino-workflow &> /dev/null
docker stop akraino-workflow &> /dev/null
docker rm akraino-workflow &> /dev/null
docker image rm $WF_IMAGE &> /dev/null
docker run \
        --detach \
        --network=bridge \
        --name akraino-workflow \
        $WF_IMAGE

docker exec akraino-workflow /bin/bash -c "sed -i -e \"s|[^//:]*:8080|$IP:8080|g\"  /config/application.yaml"
CAMUNDA_HOME=/opt/akraino/workflow
mkdir -p $CAMUNDA_HOME
if (! apt list openjdk-11-jdk | grep "\[installed\]"); then
    echo "Installing java 11..."
    sudo add-apt-repository -y ppa:openjdk-r/ppa
    sudo apt-get -qq update
    sudo apt-get install -y openjdk-11-jre --no-install-recommends
    java -version
fi
docker cp  akraino-workflow:/config $CAMUNDA_HOME
jar_name=$(docker exec akraino-workflow /bin/bash -c "ls -b camunda_workflow-*jar")
docker cp  akraino-workflow:/$jar_name $CAMUNDA_HOME/$jar_name
docker stop akraino-workflow &> /dev/null
docker rm akraino-workflow &> /dev/null
cp -f /opt/akraino/region/akraino-workflow.service /etc/systemd/system/
cp -f /opt/akraino/region/akraino-workflow.sh $CAMUNDA_HOME
systemctl daemon-reload
systemctl enable akraino-workflow
systemctl start akraino-workflow
systemctl is-active --quiet akraino-workflow && echo "akraino-workflow service started!"
sleep 5
journalctl -u akraino-workflow --since "1 min ago" --no-pager

echo "Setting up tempest content/repositories"
rm -rf $TEMPEST_HOME
mkdir -p $TEMPEST_HOME
wget -q "$TEMPEST_URL" -O - | tar -xoz -C $TEMPEST_HOME

echo "Setting up ONAP content/repositories"
#rm -rf $ONAP_HOME - DO NOT REMOVE DIRECTORY - BREAKS PORTAL CONTAINER MOUNT
mkdir -p $ONAP_HOME
wget -q "$ONAP_URL" -O - | tar -xoz -C $ONAP_HOME

echo "Setting up sample vnf content/repositories"
rm -rf $SAMPLE_VNF_HOME
mkdir -p $SAMPLE_VNF_HOME
wget -q "$SAMPLE_VNF_URL" -O - | tar -xoz -C $SAMPLE_VNF_HOME

echo "Setting up airshipinabottle content/repositories"
rm -rf $AIRSHIPINABOTTLE_HOME
mkdir -p $AIRSHIPINABOTTLE_HOME
wget -q "$AIRSHIPINABOTTLE_URL" -O - | tar -xoz -C $AIRSHIPINABOTTLE_HOME

echo "Setting up redfish tools content/repositories"
rm -rf $REDFISH_HOME
mkdir -p $REDFISH_HOME
wget -q "$REDFISH_URL" -O - | tar -xoz -C $REDFISH_HOME

echo "SUCCESS:  Portal can be accessed at http://$IP:8080/AECPortalMgmt/"
echo "SUCCESS:  Portal install completed"

