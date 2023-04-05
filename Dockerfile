# Build image
FROM eclipse-temurin:17 as build

LABEL Anthony Charrier

ARG version=1.19

# Create a custom Java runtime
RUN $JAVA_HOME/bin/jlink \
    --add-modules \
java.base,\
java.compiler,\
java.desktop,\
java.logging,\
java.management,\
java.naming,\
java.rmi,\
java.scripting,\
java.sql,\
java.xml,\
jdk.sctp,\
jdk.security.auth,\
jdk.unsupported,\
java.instrument,\
jdk.zipfs \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=2 \
    --output /javaruntime

RUN apt-get update && apt-get install python3-pip -y
RUN pip3 install requests

COPY ./utils/paper.py /paper.py
RUN python3 paper.py -v ${version}

# Runtime image
FROM debian:buster-slim

RUN useradd -rm --home-dir /server --shell /bin/bash minecraft
USER minecraft

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH "${JAVA_HOME}/bin:${PATH}"
COPY --from=build /javaruntime $JAVA_HOME

WORKDIR /server
COPY --from=build /paper.jar /server/paper.jar

VOLUME ["/data"]

EXPOSE 25565/tcp
EXPOSE 25565/udp

# Set memory size
ENV MEMORYSIZE=1G
ENV JAVAFLAGS="-XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true\
    -Dcom.mojang.eula.agree=true"

WORKDIR /data

ENTRYPOINT java -jar -Xms$MEMORYSIZE -Xmx$MEMORYSIZE $JAVAFLAGS /server/paper.jar nogui
