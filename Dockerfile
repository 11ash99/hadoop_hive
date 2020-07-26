FROM debian:9

MAINTAINER Ivan Ermilov <ivan.s.ermilov@gmail.com>
MAINTAINER Giannis Mouchakis <gmouchakis@iit.demokritos.gr>

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openjdk-8-jdk \
      net-tools \
      curl \
      netcat \
      gnupg \
      libsnappy-dev \
    && rm -rf /var/lib/apt/lists/*
      
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/

RUN curl -O https://dist.apache.org/repos/dist/release/hadoop/common/KEYS

RUN gpg --import KEYS

ENV HADOOP_VERSION 3.2.1
ENV HADOOP_URL https://www.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz

RUN set -x \
    && curl -fSL "$HADOOP_URL" -o /tmp/hadoop.tar.gz \
    && curl -fSL "$HADOOP_URL.asc" -o /tmp/hadoop.tar.gz.asc \
    && gpg --verify /tmp/hadoop.tar.gz.asc \
    && tar -xvf /tmp/hadoop.tar.gz -C /opt/ \
    && rm /tmp/hadoop.tar.gz*

RUN ln -s /opt/hadoop-$HADOOP_VERSION/etc/hadoop /etc/hadoop

RUN mkdir /opt/hadoop-$HADOOP_VERSION/logs

RUN mkdir /hadoop-data

ENV HADOOP_HOME=/opt/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=/etc/hadoop
ENV MULTIHOMED_NETWORK=1
ENV USER=root
ENV PATH $HADOOP_HOME/bin/:$PATH


# Allow buildtime config of HIVE_VERSION
ARG HIVE_VERSION
# Set HIVE_VERSION from arg if provided at build, env if provided at run, or default
# https://docs.docker.com/engine/reference/builder/#using-arg-variables
# https://docs.docker.com/engine/reference/builder/#environment-replacement
ENV HIVE_VERSION=${HIVE_VERSION:-2.3.2}

ENV HIVE_HOME /opt/hive
ENV PATH $HIVE_HOME/bin:$PATH
ENV HADOOP_HOME /opt/hadoop-$HADOOP_VERSION

WORKDIR /opt

#Install Hive and PostgreSQL JDBC
RUN apt-get update && apt-get install -y wget procps && \
	wget https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz && \
	tar -xzvf apache-hive-$HIVE_VERSION-bin.tar.gz && \
	mv apache-hive-$HIVE_VERSION-bin hive && \
	wget https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar -O $HIVE_HOME/lib/postgresql-jdbc.jar && \
	rm apache-hive-$HIVE_VERSION-bin.tar.gz && \
	apt-get --purge remove -y wget && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*


#Spark should be compiled with Hive to be able to use it
#hive-site.xml should be copied to $SPARK_HOME/conf folder

#Custom configuration goes here
ADD conf/hive-site.xml $HIVE_HOME/conf
ADD conf/beeline-log4j2.properties $HIVE_HOME/conf
ADD conf/hive-env.sh $HIVE_HOME/conf
ADD conf/hive-exec-log4j2.properties $HIVE_HOME/conf
ADD conf/hive-log4j2.properties $HIVE_HOME/conf
ADD conf/ivysettings.xml $HIVE_HOME/conf
ADD conf/llap-daemon-log4j2.properties $HIVE_HOME/conf

COPY startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh

# COPY entrypoint.sh /usr/local/bin/
# RUN chmod +x /usr/local/bin/entrypoint.sh
ADD entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh

EXPOSE 10000
EXPOSE 10002



ENTRYPOINT ["/entrypoint.sh"]
CMD startup.sh
