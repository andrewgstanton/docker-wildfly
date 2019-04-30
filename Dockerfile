# # Use latest jboss/base-jdk:8 image as the base
FROM jboss/base-jdk:8

USER root

# install git

RUN yum install -y git

# MAVEN SETUP

ARG MAVEN_VERSION=3.5.4
ARG USER_HOME_DIR="/root"
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

# COPY mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
# COPY settings-docker.xml /usr/share/maven/ref/

# WILDFLY setup

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 10.1.0.Final
ENV JBOSS_HOME /opt/jboss/wildfly

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN cd $HOME \
    && curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && rm wildfly-$WILDFLY_VERSION.tar.gz \
    && chown -R jboss:0 ${JBOSS_HOME} \
    && chmod -R g+rw ${JBOSS_HOME}

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

# create tmp area for loading in config settings for wildfly and postgres db connection

# copy the standalone.xml and add data source  to the $HOME/tmp/config directory
# standalone is the current standalone.xml configuration we want to use for this environment

# add the current repository files (monitor-enterprise) -- this includes the data source command which will add the postgres driver to wildfly

RUN mkdir -p /tmp/config
RUN mkdir -p /tmp/src/monitor-enterprise

# COPY standalone.xml /tmp/config/standalone.xml

# clone the github repo use the username and password passed during build
# ARG gitUser
# ARG gitPassword

# RUN git clone -b docker https://${gitUser}:${gitPassword}@github.com/RevereHQ/monitor-enterprise /tmp/src/monitor-enterprise

RUN git clone -b docker git@github.com:RevereHQ/monitor-enterprise.git /tmp/src/monitor-enterprise


RUN cd $HOME \ 
    && chown -R jboss:0 /tmp/config \
    && chmod -R g+rw /tmp/config \
    && chown -R jboss:0 /tmp/src/monitor-enterprise \
    && chmod -R g+rw /tmp/src/monitor-enterprise

USER jboss

# build the mvn project

WORKDIR /tmp/src/monitor-enterprise
RUN mvn package

# Expose the ports we're interested in
EXPOSE 8080 9990 8787 5432

# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interface

CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]

