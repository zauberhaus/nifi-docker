FROM openjdk:11-jre as builder

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends wget apt-utils gettext

ARG NIFI_VERSION=1.15.0

ENV NIFI_BASE_DIR /opt/nifi
ENV NIFI_HOME ${NIFI_BASE_DIR}/nifi-current

RUN mkdir -p ${NIFI_BASE_DIR}

RUN cd ${NIFI_BASE_DIR} \
    && wget -q https://dlcdn.apache.org/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.tar.gz \
    && tar xvzf ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.tar.gz \
    && rm ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.tar.gz \
    && mv ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION} ${NIFI_HOME} \
    && ln -s ${NIFI_HOME} ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}

WORKDIR /src

RUN wget -q https://dlcdn.apache.org/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-source-release.zip \
    && unzip nifi-${NIFI_VERSION}-source-release.zip \
    && rm nifi-${NIFI_VERSION}-source-release.zip 


RUN mkdir -p ${NIFI_BASE_DIR}/scripts/ \
    && cp ./nifi-${NIFI_VERSION}/nifi-docker/dockermaven/sh/* ${NIFI_BASE_DIR}/scripts/ \
    && rm -rf ./nifi-${NIFI_VERSION} \
    && chmod +x ${NIFI_BASE_DIR}/scripts/*

FROM openjdk:11-jre

ARG UID=1000
ARG GID=1000

ENV NIFI_BASE_DIR /opt/nifi
ENV NIFI_HOME ${NIFI_BASE_DIR}/nifi-current
ENV NIFI_TOOLKIT_HOME ${NIFI_BASE_DIR}/nifi-toolkit-current
ENV NIFI_PID_DIR=${NIFI_HOME}/run
ENV NIFI_LOG_DIR=${NIFI_HOME}/logs

COPY --from=builder /usr/bin/envsubst /usr/bin/envsubst
COPY --chown=${UID}:${GID} --from=builder $NIFI_BASE_DIR $NIFI_BASE_DIR

RUN groupadd -g ${GID} nifi || groupmod -n nifi `getent group ${GID} | cut -d: -f1` \
    && useradd --shell /bin/bash -u ${UID} -g ${GID} -m nifi \
    && apt-get update \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends jq xmlstarlet procps libsnappy-jni \
    && rm -rf /var/lib/apt/lists/*

USER nifi

RUN echo "#!/bin/sh\n" > $NIFI_HOME/bin/nifi-env.sh

EXPOSE 8080 8443 10000 8000

WORKDIR ${NIFI_HOME}

ENTRYPOINT ["../scripts/start.sh"]
