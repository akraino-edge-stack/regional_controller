#!/bin/sh
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
# START LATEST VERSION OF CAMUNDA JAR BASED ON FILE NAME
#

CAMUNDA_HOME=/opt/akraino/workflow
CAMUNDA_JARFILE=$(ls -b ${CAMUNDA_HOME}/camunda_workflow-*jar | tail -n 1)
/usr/bin/java -jar ${CAMUNDA_JARFILE} --server.port=8073

