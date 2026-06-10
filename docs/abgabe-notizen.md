# Abgabe-Notizen

## Projekt

Containerisierte Smart-Home Umgebung mit MQTT, Bash-Sensoren, Java-Sensoren und Grafana.

## Personen

Erstellt von: Fionn Laesser  
Sparing-Partner: Janik Preisig

## Kurzbeschreibung

Der komplette Stack läuft über Docker Compose. Mosquitto stellt den MQTT-Broker bereit. Drei Bash-Sensoren senden Werte auf `bash/r1`, `bash/r2` und `bash/r3`. Drei Java-Sensoren senden Werte auf `java/r1`, `java/r2` und `java/r3`. Die Java-Anwendung subscribed zusätzlich auf `java/commands` und reagiert auf `status`, `pause`, `resume` und `stop`.

Grafana wird beim Start automatisch mit dem MQTT-Plugin, einer MQTT-Datenquelle und dem Dashboard `Smart Home MQTT` vorbereitet.

## Wichtigste Befehle

Stack starten:

```bash
docker compose up -d --build
```

Status anzeigen:

```bash
docker compose ps
```

Alle MQTT-Nachrichten anzeigen:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t '#' -v
```

Java-Subscriber testen:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m status
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m pause
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m resume
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m stop
```

Automatisierten Test ausführen:

```bash
bash tests/test-mqtt-stack.sh
```

Unter PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tests/test-mqtt-stack.ps1
```

Grafana öffnen:

```text
http://localhost:3001
```

## Demo-Ablauf

1. Repository zeigen: `docker-compose.yml`, Dockerfiles, Grafana-Provisioning.
2. Stack starten: `docker compose up -d --build`.
3. Container zeigen: `docker compose ps`.
4. MQTT-Direkttest zeigen.
5. Bash-Nachrichten auf `bash/#` zeigen.
6. Java-Nachrichten auf `java/#` zeigen.
7. Java-Command `status` oder `pause` über `java/commands` zeigen.
8. Grafana öffnen und Dashboard `Smart Home MQTT` zeigen.
9. Testplan und Testprotokoll in `docs/testplan.md` zeigen.

## Abgaberelevante Dateien

| Datei | Zweck |
| --- | --- |
| `docker-compose.yml` | Definiert Broker, Grafana, Bash-Sensoren und Java-Sensoren. |
| `bash-sensoren/Dockerfile` | Image für Bash-Sensoren mit Bash und Mosquitto-Clients. |
| `java-sensoren/Dockerfile` | Multi-Stage-Build für die Java-Sensoren. |
| `grafana/provisioning/datasources/mqtt.yml` | Automatische MQTT-Datenquelle. |
| `grafana/provisioning/dashboards/smarthome.yml` | Automatisches Dashboard-Provisioning. |
| `grafana/dashboards/smarthome-mqtt.json` | Dashboard mit Bash- und Java-Panel. |
| `docs/testplan.md` | Testplan und Testprotokoll. |
| `tests/test-mqtt-stack.sh` | Automatisierter Integrationstest für Bash/Ubuntu. |
| `tests/test-mqtt-stack.ps1` | Automatisierter Integrationstest für PowerShell. |
| `screenshots/` | Bildnachweise für die Abgabe. |
