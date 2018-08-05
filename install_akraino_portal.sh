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
source $BASEDIR/akrainorc

if ping -c 1 $TARGET_SERVER_IP &> /dev/null
then
    scp $BASEDIR/start_akraino_portal.sh root@$TARGET_SERVER_IP:/tmp/
    ssh root@$TARGET_SERVER_IP "bash /tmp/start_akraino_portal.sh $DB_SCHEMA_VERSION $CAMUNDA_WORKFLOW_VERSION $PORTAL_VERSION"
else
    echo "Unable to ping target server [$TARGET_SERVER_IP]"
fi

