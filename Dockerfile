FROM openjdk:7-jdk

ARG MAVEN_VERSION=3.0.5
ARG USER_HOME_DIR="/root"
ARG SHA=d98d766be9254222920c1d541efd466ae6502b82a39166c90d65ffd7ea357dd9
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN apt-get update \
  && apt-get -y install ant

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha256sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

# COPY mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
RUN echo '#! /bin/bash -eu \
 \n\ 
set -o pipefail \n\ 
 \n\ 
# Copy files from /usr/share/maven/ref into ${MAVEN_CONFIG} \n\ 
# So the initial ~/.m2 is set with expected content. \n\ 
# Don't override, as this is just a reference setup \n\ 
copy_reference_file() { \n\ 
  local root="${1}" \n\ 
  local f="${2%/}" \n\ 
  local logfile="${3}" \n\ 
  local rel="${f/${root}/}" # path relative to /usr/share/maven/ref/ \n\ 
  echo "$f" >> "$logfile" \n\ 
  echo " $f -> $rel" >> "$logfile" \n\ 
  if [[ ! -e ${MAVEN_CONFIG}/${rel} || $f = *.override ]] \n\ 
  then \n\ 
    echo "copy $rel to ${MAVEN_CONFIG}" >> "$logfile" \n\ 
    mkdir -p "${MAVEN_CONFIG}/$(dirname "${rel}")" \n\ 
    cp -r "${f}" "${MAVEN_CONFIG}/${rel}"; \n\ 
  fi; \n\ 
} \n\ 
 \n\ 
copy_reference_files() { \n\ 
  local log="$MAVEN_CONFIG/copy_reference_file.log" \n\ 
  touch "${log}" || (echo "Can not write to ${log}. Wrong volume permissions?" && exit 1) \n\ 
  echo "--- Copying files at $(date)" >> "$log" \n\ 
  find /usr/share/maven/ref/ -type f -exec bash -eu -c 'copy_reference_file /usr/share/maven/ref/ "$1" "$2"' _ {} "$log" \; \n\ 
} \n\ 
 \n\ 
export -f copy_reference_file \n\ 
copy_reference_files \n\ 
 \n\ 
exec "$@" \
' > /usr/local/bin/mvn-entrypoint.sh \
  && chmod 755 /usr/local/bin/mvn-entrypoint.sh \
  && cat /usr/local/bin/mvn-entrypoint.sh

# COPY settings-docker.xml /usr/share/maven/ref/
RUN echo '\
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" \n\
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \n\
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 \n\
                      https://maven.apache.org/xsd/settings-1.0.0.xsd"> \n\
  <localRepository>/usr/share/maven/ref/repository</localRepository> \n\
</settings> \
' > /usr/share/maven/ref/settings-docker.xml \
  && cat /usr/share/maven/ref/settings-docker.xml

VOLUME "$USER_HOME_DIR/.m2"

ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]