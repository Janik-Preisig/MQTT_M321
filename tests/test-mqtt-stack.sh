#!/usr/bin/env bash

set -euo pipefail

COMPOSE="${COMPOSE:-docker compose}"

echo "[test] Baue die Sensor-Images..."
$COMPOSE build

echo "[test] Starte den kompletten Stack..."
$COMPOSE up -d --remove-orphans

echo "[test] Warte auf Mosquitto..."
for i in $(seq 1 30); do
  if $COMPOSE exec -T mosquitto mosquitto_pub -h localhost -p 1883 -t test/health -m ok >/dev/null 2>&1; then
    break
  fi

  if [ "$i" -eq 30 ]; then
    echo "[test] Fehler: Mosquitto ist nicht erreichbar." >&2
    exit 1
  fi

  sleep 1
done

echo "[test] Prüfe direkten MQTT Publish/Subscribe..."
$COMPOSE exec -T mosquitto sh -c "mosquitto_sub -h localhost -p 1883 -t test/direct -C 1 -W 10 -v > /tmp/mqtt-test.out & sleep 1; mosquitto_pub -h localhost -p 1883 -t test/direct -m hello; wait"
DIRECT_MESSAGE="$($COMPOSE exec -T mosquitto cat /tmp/mqtt-test.out)"

if ! printf '%s\n' "$DIRECT_MESSAGE" | grep -q "test/direct hello"; then
  echo "[test] Fehler: Direktes MQTT Publish/Subscribe fehlgeschlagen." >&2
  printf '%s\n' "$DIRECT_MESSAGE" >&2
  exit 1
fi

echo "[test] Prüfe Bash-Sensor-Topics..."
BASH_MESSAGES="$($COMPOSE exec -T mosquitto mosquitto_sub -h localhost -p 1883 -t 'bash/#' -C 6 -W 20 -v)"
printf '%s\n' "$BASH_MESSAGES"

for topic in "bash/r1" "bash/r2" "bash/r3"; do
  if ! printf '%s\n' "$BASH_MESSAGES" | grep -q "$topic"; then
    echo "[test] Fehler: Keine Nachricht für $topic empfangen." >&2
    exit 1
  fi
done

echo "[test] Prüfe Java-Sensor-Topics..."
JAVA_MESSAGES="$($COMPOSE exec -T mosquitto mosquitto_sub -h localhost -p 1883 -t 'java/#' -C 6 -W 20 -v)"
printf '%s\n' "$JAVA_MESSAGES"

for topic in "java/r1" "java/r2" "java/r3"; do
  if ! printf '%s\n' "$JAVA_MESSAGES" | grep -q "$topic"; then
    echo "[test] Fehler: Keine Nachricht für $topic empfangen." >&2
    exit 1
  fi
done

echo "[test] Prüfe Java-Subscriber-Command..."
$COMPOSE exec -T mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m status
sleep 2

if ! $COMPOSE logs --tail=120 java-sensoren | grep -q "Befehl=status"; then
  echo "[test] Fehler: Java-Command status wurde nicht sichtbar verarbeitet." >&2
  exit 1
fi

echo "[test] Prüfe Grafana HTTP..."
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
for i in $(seq 1 60); do
  if curl -fsS "http://localhost:${GRAFANA_PORT}/api/health" >/dev/null; then
    break
  fi

  if [ "$i" -eq 60 ]; then
    echo "[test] Fehler: Grafana API ist nicht erreichbar." >&2
    exit 1
  fi

  sleep 1
done

echo "[test] Prüfe provisionierte Grafana-Datenquelle..."
DATASOURCE_JSON="$(curl -fsS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/datasources/uid/mqtt")"
if ! printf '%s\n' "$DATASOURCE_JSON" | grep -q "grafana-mqtt-datasource"; then
  echo "[test] Fehler: MQTT-Datenquelle wurde nicht gefunden." >&2
  printf '%s\n' "$DATASOURCE_JSON" >&2
  exit 1
fi

echo "[test] Alle Container-Migrationstests erfolgreich."
