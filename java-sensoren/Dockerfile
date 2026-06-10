FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /src

COPY pom.xml .
COPY src ./src

RUN mvn -B package

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

COPY --from=build /src/target/m321-sq3-1.0-SNAPSHOT-jar-with-dependencies.jar /app/smarthome-java-sensoren.jar

ENV MQTT_BROKER=tcp://mosquitto:1883

ENTRYPOINT ["java", "-jar", "/app/smarthome-java-sensoren.jar"]
