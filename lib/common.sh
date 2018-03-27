#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------------

export DEFAULT_MAVEN_VERSION="3.3.9"
export BUILDPACK_STDLIB_URL="https://lang-common.s3.amazonaws.com/buildpack-stdlib/v7/stdlib.sh"

install_maven() {
  local installDir=$1
  local buildDir=$2
  mavenHome=$installDir/.maven

  definedMavenVersion=$(detect_maven_version $buildDir)

  mavenVersion=${definedMavenVersion:-$DEFAULT_MAVEN_VERSION}
  mcount "mvn.version.${mavenVersion}"

  status_pending "Installing Maven ${mavenVersion}"
  if is_supported_maven_version ${mavenVersion}; then
    mavenUrl="https://lang-jvm.s3.amazonaws.com/maven-${mavenVersion}.tar.gz"
    download_maven ${mavenUrl} ${installDir} ${mavenHome}
    status_done
  else
    error_return "Error, you have defined an unsupported Maven version in the system.properties file.
The default supported version is ${DEFAULT_MAVEN_VERSION}"
    return 1
  fi
}

download_maven() {
  local mavenUrl=$1
  local installDir=$2
  local mavenHome=$3
  rm -rf $mavenHome
  curl --retry 3 --silent --max-time 60 --location ${mavenUrl} | tar xzm -C $installDir
  chmod +x $mavenHome/bin/mvn
}

is_supported_maven_version() {
  local mavenVersion=${1}
  if [ "$mavenVersion" = "$DEFAULT_MAVEN_VERSION" ]; then
    return 0
  elif [ "$mavenVersion" = "3.2.5" ]; then
    return 0
  elif [ "$mavenVersion" = "3.2.3" ]; then
    return 0
  elif [ "$mavenVersion" = "3.1.1" ]; then
    return 0
  elif [ "$mavenVersion" = "3.0.5" ]; then
    return 0
  else
    return 1
  fi
}

detect_maven_version() {
  local baseDir=${1}
  if [ -f ${baseDir}/system.properties ]; then
    mavenVersion=$(get_app_system_value ${baseDir}/system.properties "maven.version")
    if [ -n "$mavenVersion" ]; then
      echo $mavenVersion
    else
      echo ""
    fi
  else
    echo ""
  fi
}

get_app_system_value() {
  local file=${1?"No file specified"}
  local key=${2?"No key specified"}

  # escape for regex
  local escaped_key=$(echo $key | sed "s/\./\\\./g")

  [ -f $file ] && \
  grep -E ^$escaped_key[[:space:]=]+ $file | \
  sed -E -e "s/$escaped_key([\ \t]*=[\ \t]*|[\ \t]+)([A-Za-z0-9\.-]*).*/\2/g"
}

cache_copy() {
  rel_dir=$1
  from_dir=$2
  to_dir=$3
  rm -rf "${to_dir:?}/${rel_dir:?}"
  if [ -d $from_dir/$rel_dir ]; then
    mkdir -p $to_dir/$rel_dir
    cp -pr $from_dir/$rel_dir/. $to_dir/$rel_dir
  fi
}

install_jdk() {
  local install_dir=${1}

  let start=$(nowms)
  JVM_COMMON_BUILDPACK=${JVM_COMMON_BUILDPACK:-https://codon-buildpacks.s3.amazonaws.com/buildpacks/heroku/jvm-common.tgz}
  mkdir -p /tmp/jvm-common
  curl --retry 3 --silent --location $JVM_COMMON_BUILDPACK | tar xzm -C /tmp/jvm-common --strip-components=1
  source /tmp/jvm-common/bin/util
  source /tmp/jvm-common/bin/java
  source /tmp/jvm-common/opt/jdbc.sh
  mtime "jvm-common.install.time" "${start}"

  let start=$(nowms)
  install_java_with_overlay ${install_dir}
  mtime "jvm.install.time" "${start}"
}
