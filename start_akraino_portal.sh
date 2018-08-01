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
DB_IMAGE="nexus3.akraino.org:10003/akraino_schema_db:$1"
WF_IMAGE=nexus3.akraino.org:10003/akraino-camunda-workflow-engine:$2
PT_IMAGE=nexus3.akraino.org:10003/akraino-portal:$3
# Login if needed

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

#ldap
docker run --name akraino_ldap -d -p 10389:10389 -e APACHEDS_INSTANCE=akraion -v /root/AECPortalMgmt/WEB-INF/classes/config.ldif:/bootstrap/conf/config.ldif:ro  openmicroscopy/apacheds
docker cp /root/AECPortalMgmt/WEB-INF/classes/akrainousers.ldif akraino_ldap:/bootstrap/conf
sleep 15
docker exec akraino_ldap /bin/bash -c "ldapadd -v -h $4:10389 -c -x -D uid=admin,ou=system -w secret -f /bootstrap/conf/akrainousers.ldif"
#intialize DB
sleep 30
docker exec postgres /bin/bash -c "cp -rf /akraino-j2templates/* /var/lib/postgresql/data/"
docker exec postgres /bin/bash -c "psql -h localhost -p 5432 -U postgres -f /akraino-db_0524.sql"


### TODO - initialize filesystem

# Workflow
docker run \
	--detach \
	--publish 8070:8080 \
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
	--name akraino-portal \
	$PT_IMAGE

TEMPEST_HOME="/opt/akraino/tempest"
YAML_BUILDS_HOME="/opt/akraino/yaml_builds"
# To get latest artifacts from nexus
version=`curl -s https://nexus.akraino.org/content/repositories/snapshots/org/akraino/test_automation/test_automation/maven-metadata.xml | grep version | sed "s/.*<version>\([^<]*\)<\/version>.*/\1/" | head -4 | tail -1`
build=`curl -s  https://nexus.akraino.org/content/repositories/snapshots/org/akraino/test_automation/test_automation/$version/maven-metadata.xml | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/"`
tar=test_automation-$build.tgz
path="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/test_automation/test_automation/$version"
TEMPEST_URL="$path/$tar"
#TEMPEST_URL="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/tempest/tempest-master/0.0.1-SNAPSHOT/tempest-master-0.0.1-20180611.172116-1.tar"

echo "Setting up tempest content/repositories"
#checking if directory exist or not
if [ -d $TEMPEST_HOME ]; then
   rm -rf $TEMPEST_HOME
   mkdir -p $TEMPEST_HOME
else
   mkdir -p $TEMPEST_HOME
fi

wget -q $TEMPEST_URL -O /opt/akraino/test_automation.tgz
tar -xzf /opt/akraino/test_automation.tgz -C $TEMPEST_HOME
rm -rf /opt/akraino/test_automation.tgz

# To get latest artifacts from nexus
yaml_builds_version=`curl -s https://nexus.akraino.org/content/repositories/snapshots/org/akraino/yaml_builds/yaml_builds/maven-metadata.xml | grep version | sed "s/.*<version>\([^<]*\)<\/version>.*/\1/" | head -4 | tail -1`
yaml_builds_build=`curl -s  https://nexus.akraino.org/content/repositories/snapshots/org/akraino/yaml_builds/yaml_builds/$yaml_builds_version/maven-metadata.xml | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/"`
yaml_builds_tar=yaml_builds-$yaml_builds_build.tgz
yaml_builds_path="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/yaml_builds/yaml_builds/$yaml_builds_version"
YAML_BUILDS_URL="$yaml_builds_path/$yaml_builds_tar"

echo "Setting up yaml builds content/repositories"
#checking if directory exist or not
if [ -d $YAML_BUILDS_HOME ]; then
   rm -rf $YAML_BUILDS_HOME
   mkdir -p $YAML_BUILDS_HOME
else
   mkdir -p $YAML_BUILDS_HOME
fi

wget -q $YAML_BUILDS_URL -O /opt/akraino/yaml_builds.tgz
tar -xzf /opt/akraino/yaml_builds.tgz  -C $YAML_BUILDS_HOME
rm -rf /opt/akraino/yaml_builds.tgz


ONAP_HOME="/opt/akraino/onap"
onap_version=`curl -s https://nexus.akraino.org/content/repositories/snapshots/org/akraino/addon-onap/onap-amsterdam-regional-controller-master/maven-metadata.xml | grep version | sed "s/.*<version>\([^<]*\)<\/version>.*/\1/" | head -4 | tail -1`
onap_build=`curl -s  https://nexus.akraino.org/content/repositories/snapshots/org/akraino/addon-onap/onap-amsterdam-regional-controller-master/$onap_version/maven-metadata.xml | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/"`
onap_tar=onap-amsterdam-regional-controller-master-$onap_build.tgz
onap_path="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/addon-onap/onap-amsterdam-regional-controller-master/$onap_version"
ONAP_URL="$onap_path/$onap_tar"

echo "Setting up ONAP content/repositories"
#checking if directory exist or not
if [ -d $ONAP_HOME ]; then
   rm -rf $ONAP_HOME
   mkdir -p $ONAP_HOME
else
   mkdir -p $ONAP_HOME
fi
wget -q $ONAP_URL -O /opt/akraino/onap.tgz
tar -xzf /opt/akraino/onap.tgz  -C $ONAP_HOME
rm -rf /opt/akraino/onap.tgz

SAMPLE_VNF="/opt/akraino/sample_vnf"
sample_vnf_version=`curl -s https://nexus.akraino.org/content/repositories/snapshots/org/akraino/sample_vnf/sample_vnf/maven-metadata.xml | grep version | sed "s/.*<version>\([^<]*\)<\/version>.*/\1/" | head -4 | tail -1`
sample_vnf_build=`curl -s  https://nexus.akraino.org/content/repositories/snapshots/org/akraino/sample_vnf/sample_vnf/$sample_vnf_version/maven-metadata.xml | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/"`
sample_vnf_tar=sample_vnf-$sample_vnf_build.tgz
sample_vnf_path="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/sample_vnf/sample_vnf/$sample_vnf_version"
SAMPLE_VNF_URL="$sample_vnf_path/$sample_vnf_tar"

echo "Setting up sample vnf content/repositories"
#checking if directory exist or not
if [ -d $SAMPLE_VNF ]; then
   rm -rf $SAMPLE_VNF
   mkdir -p $SAMPLE_VNF
else
   mkdir -p $SAMPLE_VNF
fi

wget -q $SAMPLE_VNF_URL -O /opt/akraino/sample_vnf.tgz
tar -xzf /opt/akraino/sample_vnf.tgz -C $SAMPLE_VNF
rm -rf /opt/akraino/sample_vnf.tgz

AIRSHIPINABOTTLE="/opt/akraino/airshipinabottle_deploy"
airshipinabottle_deploy_version=`curl -s https://nexus.akraino.org/content/repositories/snapshots/org/akraino/airshipinabottle_deploy/airshipinabottle_deploy/maven-metadata.xml | grep version | sed "s/.*<version>\([^<]*\)<\/version>.*/\1/" | head -4 | tail -1`
airshipinabottle_deploy_build=`curl -s  https://nexus.akraino.org/content/repositories/snapshots/org/akraino/airshipinabottle_deploy/airshipinabottle_deploy/$airshipinabottle_deploy_version/maven-metadata.xml | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/"`
airshipinabottle_deploy_tar=airshipinabottle_deploy-$airshipinabottle_deploy_build.tgz
airshipinabottle_deploy_path="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/airshipinabottle_deploy/airshipinabottle_deploy/$airshipinabottle_deploy_version"
AIRSHIPINABOTTLE_URL="$airshipinabottle_deploy_path/$airshipinabottle_deploy_tar"

echo "Setting up airshipinabottle content/repositories"
#checking if directory exist or not
if [ -d $AIRSHIPINABOTTLE ]; then
   rm -rf $AIRSHIPINABOTTLE
   mkdir -p $AIRSHIPINABOTTLE
else
   mkdir -p $AIRSHIPINABOTTLE
fi

wget -q $AIRSHIPINABOTTLE_URL -O /opt/akraino/airshipinabottle_deploy.tgz
tar -xzf /opt/akraino/airshipinabottle_deploy.tgz -C $AIRSHIPINABOTTLE
rm -rf /opt/akraino/airshipinabottle_deploy.tgz

REDFISH_HOME="/opt/akraino/redfish"
redfish_version=`curl -s https://nexus.akraino.org/content/repositories/snapshots/org/akraino/redfish/redfish/maven-metadata.xml | grep version | sed "s/.*<version>\([^<]*\)<\/version>.*/\1/" | head -4 | tail -1`
redfish_build=`curl -s  https://nexus.akraino.org/content/repositories/snapshots/org/akraino/redfish/redfish/$redfish_version/maven-metadata.xml | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/"`
redfish_tar=redfish-$redfish_build.tgz
redfish_path="https://nexus.akraino.org/content/repositories/snapshots/org/akraino/redfish/redfish/$redfish_version"
REDFISH_HOME_URL="$redfish_path/$redfish_tar"

echo "Setting up sample vnf content/repositories"
#checking if directory exist or not
if [ -d $REDFISH_HOME ]; then
   rm -rf $REDFISH_HOME
   mkdir -p $REDFISH_HOME
else
   mkdir -p $REDFISH_HOME
fi

wget -q $REDFISH_HOME_URL -O /opt/akraino/redfish.tgz
tar -xzf /opt/akraino/redfish.tgz -C $REDFISH_HOME
rm -rf /opt/akraino/redfish.tgz
echo "SUCCESS:  Portal install completed"
