FROM alpine:3.20

RUN apk add --no-cache bash mosquitto-clients

WORKDIR /app

COPY *.sh /app/bash-sensoren/

ENV BROKER_HOST=mosquitto
ENV BROKER_PORT=1883

ENTRYPOINT ["bash", "/app/bash-sensoren/start-all-sensors.sh"]
