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

DB_VERSION=${1:-"1.0.0-SNAPSHOT"}
WF_VERSION=${2:-"0.0.1-SNAPSHOT"}
PT_VERSION=${3:-"0.0.1-SNAPSHOT"}

DB_IMAGE="nexus3.akraino.org:10003/akraino_schema_db:$DB_VERSION"
WF_IMAGE="nexus3.akraino.org:10003/akraino-camunda-workflow-engine:$WF_VERSION"
PT_IMAGE="nexus3.akraino.org:10003/akraino-portal:$PT_VERSION"
LD_IMAGE="openmicroscopy/apacheds"

NEXUS_URL="https://nexus.akraino.org"
PORTAL_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino&a=portal_user_interface&v=$PT_VERSION&e=war"
TEMPEST_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.test_automation&a=test_automation&v=1.0.0-SNAPSHOT&e=tgz"
YAML_BUILDS_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.yaml_builds&a=yaml_builds&v=1.0.0-SNAPSHOT&e=tgz"
ONAP_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.addon-onap&a=onap-amsterdam-regional-controller-master&v=1.0.0-SNAPSHOT&e=tgz"
SAMPLE_VNF_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.sample_vnf&a=sample_vnf&v=1.0.0-SNAPSHOT&e=tgz"
AIRSHIPINABOTTLE_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.airshipinabottle_deploy&a=airshipinabottle_deploy&v=1.0.0-SNAPSHOT&e=tgz"
REDFISH_URL="$NEXUS_URL/service/local/artifact/maven/redirect?r=snapshots&g=org.akraino.redfish&a=redfish&v=1.0.0-SNAPSHOT&e=tgz"

LDAP_FILE_HOME="/opt/akraino/ldap"
TEMPEST_HOME="/opt/akraino/tempest"
YAML_BUILDS_HOME="/opt/akraino/yaml_builds"
ONAP_HOME="/opt/akraino/onap"
SAMPLE_VNF_HOME="/opt/akraino/sample_vnf"
AIRSHIPINABOTTLE_HOME="/opt/akraino/airshipinabottle_deploy"
REDFISH_HOME="/opt/akraino/redfish"

# Find the primary ip address (the one used to access the default gateway)
# This ip will be used for communication between the containers
IP=$(ip route get 8.8.8.8 | grep -o "src .*$" | cut -f 2 -d ' ')

apt-get install unzip -y

# PostgreSQL
docker run \
        --detach \
        --publish 6432:5432 \
        --volume /var/lib/postgres:/var/lib/postgresql/data \
        --network=bridge \
        --name postgres \
        --env "POSTGRES_USER=admin" \
        --env "POSTGRES_PASSWORD=abc123" \
        $DB_IMAGE

# LDAP
echo "Download ldap ldif files"
rm -rf $LDAP_FILE_HOME
wget -q "$PORTAL_URL" -O /tmp/portal_user_interface.war
unzip -oj /tmp/portal_user_interface.war WEB-INF/classes/*.ldif -d $LDAP_FILE_HOME

docker run \
        --detach \
        --publish 10389:10389 \
        --volume $LDAP_FILE_HOME/config.ldif:/bootstrap/conf/config.ldif:ro \
        --volume $LDAP_FILE_HOME/akrainousers.ldif:/bootstrap/conf/akrainousers.ldif:ro \
        --name akraino-ldap \
        --env "APACHEDS_INSTANCE=akraino" \
        $LD_IMAGE
sleep 15
docker exec akraino-ldap /bin/bash -c "ldapadd -v -h $IP:10389 -c -x -D uid=admin,ou=system -w secret -f /bootstrap/conf/akrainousers.ldif"

# Intialize DB
sleep 30
docker exec postgres /bin/bash -c "cp -rf /akraino-j2templates/* /var/lib/postgresql/data/"
docker exec postgres /bin/bash -c "psql -h localhost -p 5432 -U postgres -f /akraino-db_0524.sql"

# Workflow
docker run \
        --detach \
        --publish 8073:8015 \
        --network=bridge \
        --name akraino-workflow \
        $WF_IMAGE

# Portal
docker run \
        --detach \
        --publish 8080:8080 \
        --network=bridge \
        --volume /opt/tomcat/logs:/usr/local/tomcat/logs \
        --volume /opt/aec_poc/aic-clcp-manifests/site/site80:/usr/local/site80 \
        --volume /opt/akraino/server-build:/opt/akraino/server-build \
        --name akraino-portal \
        $PT_IMAGE

# Portal configuration
echo "Updating portal configuration"
docker exec akraino-portal /bin/bash -c "sed -i -e \"s|localhost|$IP|g\" /usr/local/tomcat/webapps/AECPortalMgmt/App.Config.js"
docker exec akraino-portal /bin/bash -c "sed -i -e \"s|localhost|$IP|g\" /usr/local/tomcat/webapps/AECPortalMgmt/WEB-INF/classes/app.properties"


echo "Setting up tempest content/repositories"
rm -rf $TEMPEST_HOME
mkdir -p $TEMPEST_HOME
wget -q "$TEMPEST_URL" -O - | tar -xz -C $TEMPEST_HOME

echo "Setting up yaml builds content/repositories"
rm -rf $YAML_BUILDS_HOME
mkdir -p $YAML_BUILDS_HOME
wget -q "$YAML_BUILDS_URL" -O - | tar -xz -C $YAML_BUILDS_HOME

echo "Setting up ONAP content/repositories"
rm -rf $ONAP_HOME
mkdir -p $ONAP_HOME
wget -q "$ONAP_URL" -O - | tar -xz -C $ONAP_HOME

echo "Setting up sample vnf content/repositories"
rm -rf $SAMPLE_VNF_HOME
mkdir -p $SAMPLE_VNF_HOME
wget -q "$SAMPLE_VNF_URL" -O - | tar -xz -C $SAMPLE_VNF_HOME

echo "Setting up airshipinabottle content/repositories"
rm -rf $AIRSHIPINABOTTLE_HOME
mkdir -p $AIRSHIPINABOTTLE_HOME
wget -q "$AIRSHIPINABOTTLE_URL" -O - | tar -xz -C $AIRSHIPINABOTTLE_HOME

echo "Setting up sample vnf content/repositories"
rm -rf $REDFISH_HOME
mkdir -p $REDFISH_HOME
wget -q "$REDFISH_URL" -O - | tar -xz -C $REDFISH_HOME

echo "SUCCESS:  Portal install completed"

