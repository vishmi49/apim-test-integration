#!/bin/bash
#----------------------------------------------------------------------------
#  Copyright (c) 2020 WSO2, Inc. http://www.wso2.org
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#----------------------------------------------------------------------------
set -o xtrace

WORKING_DIR=$(pwd)

PRODUCT_REPOSITORY=$1
PRODUCT_REPOSITORY_BRANCH=$2
PRODUCT_NAME=$3
PRODUCT_VERSION=$4

PRODUCT_REPOSITORY_NAME=$(echo $PRODUCT_REPOSITORY | rev | cut -d'/' -f1 | rev | cut -d'.' -f1)
PRODUCT_REPOSITORY_PACK_DIR="$WORKING_DIR/$PRODUCT_REPOSITORY_NAME/modules/distribution/product/target"
INT_TEST_MODULE_DIR="$WORKING_DIR/$PRODUCT_REPOSITORY_NAME/modules/integration"

# cloud formation properties
CFN_PROP_FILE="${WORKING_DIR}/cfn-props.properties"
JDK_TYPE=$(grep -w "JDK_TYPE" ${CFN_PROP_FILE} | cut -d"=" -f2)
DB_TYPE=$(grep -w "DB_TYPE" ${CFN_PROP_FILE} | cut -d"=" -f2)
CF_DB_VERSION=$(grep -w "CF_DB_VERSION" ${CFN_PROP_FILE} | cut -d"=" -f2)
CF_DB_PASSWORD=$(grep -w "CF_DB_PASSWORD" ${CFN_PROP_FILE} | cut -d"=" -f2)
CF_DB_USERNAME=$(grep -w "CF_DB_USERNAME" ${CFN_PROP_FILE} | cut -d"=" -f2)
CF_DB_HOST=$(grep -w "CF_DB_HOST" ${CFN_PROP_FILE} | cut -d"=" -f2)
CF_DB_PORT=$(grep -w "CF_DB_PORT" ${CFN_PROP_FILE} | cut -d"=" -f2)


function log_info(){
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')]: $1"
}

function log_error(){
    echo "[ERROR][$(date '+%Y-%m-%d %H:%M:%S')]: $1"
    exit 1
}

function install_jdk(){
    jdk_name=$1
    jdk_file=$2
    mkdir -p /opt/${jdk_name}
    tar -xzf "$jdk_file.tar.gz" -C /opt/${jdk_name} --strip-component=1
}

log_info "Clone Product repository"
git clone $PRODUCT_REPOSITORY --branch $PRODUCT_REPOSITORY_BRANCH

mkdir -p $PRODUCT_REPOSITORY_PACK_DIR

log_info "Copying product pack to Repository"
mv $PRODUCT_NAME-$PRODUCT_VERSION-*.zip $PRODUCT_REPOSITORY_PACK_DIR/.

log_info "Downloading JDK"
case ${JDK_TYPE} in
    ADOPT_OPEN_JDK8)
        wget -q https://integration-testgrid-resources.s3.amazonaws.com/lib/jdk/OpenJDK8U-jdk_x64_linux_hotspot_8u252b09.tar.gz
        install_jdk ADOPT_OPEN_JDK8 "OpenJDK8U-jdk_x64_linux_hotspot_8u252b09"
        export JAVA_HOME=/opt/ADOPT_OPEN_JDK8
        echo $JAVA_HOME
        ;;
esac

case ${DB_TYPE} in
    mysql)
        wget -q https://integration-testgrid-resources.s3.amazonaws.com/lib/jdbc/mysql-connector-java-5.1.49.jar -P ${PRODUCT_NAME}-${PRODUCT_VERSION}-*/repository/components/lib
        
        export SHARED_DATABASE_DRIVER="com.mysql.jdbc.Driver"
        export SHARED_DATABASE_URL="jdbc:mysql://CF_DB_HOST:3306/WSO2AM_COMMON_DB?autoReconnect=true&amp;useSSL=false"
        export SHARED_DATABASE_USERNAME="${CF_DB_USERNAME}"
        export SHARED_DATABASE_PASSWORD="${CF_DB_PASSWORD}"
        export SHARED_DATABASE_VALIDATION_QUERY="SELECT 1"
        
        export API_MANAGER_DATABASE_DRIVER="com.mysql.jdbc.Driver"
        export API_MANAGER_DATABASE_URL="jdbc:mysql://CF_DB_HOST:3306/WSO2AM_APIMGT_DB?autoReconnect=true&amp;useSSL=false"
        export API_MANAGER_DATABASE_USERNAME="${CF_DB_USERNAME}"
        export API_MANAGER_DATABASE_PASSWORD="${CF_DB_PASSWORD}"
        export API_MANAGER_DATABASE_VALIDATION_QUERY="SELECT 1"
        ;;
esac

cd $INT_TEST_MODULE_DIR  && mvn clean install -fae -B -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn
