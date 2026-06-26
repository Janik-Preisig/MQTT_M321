# Abgabe-Notizen

## Projekt

Containerisierte Smart-Home Umgebung mit MQTT, Bash-Sensoren, Java-Sensoren und Grafana.

## Personen

Erstellt von: Fionn Laesser  
Sparing-Partner: Janik Preisig

## Kurzbeschreibung

Der komplette Stack läuft über Docker Compose. Mosquitto stellt den MQTT-Broker bereit. Drei Bash-Sensoren senden Werte auf `bash/r1`, `bash/r2` und `bash/r3`. Drei Java-Sensoren senden Werte auf `java/r1`, `java/r2` und `java/r3`. Die Java-Anwendung subscribed zusätzlich auf `java/commands` und reagiert auf `status`, `pause`, `resume` und `stop`.

Grafana wird beim Start automatisch mit dem MQTT-Plugin, einer MQTT-Datenquelle und dem Dashboard `Smart Home MQTT` vorbereitet.

Prometheus, CAdvisor und Alertmanager ergaenzen die Demo um Container-Monitoring und Alerting. Prometheus scrapt CAdvisor und Demo-Targets, wertet Alert-Regeln aus und leitet aktive Alerts an Alertmanager weiter.

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

Prometheus-Targets öffnen:

```text
http://localhost:9090/targets
```

Node-Alert live auslösen:

```bash
docker compose stop demo1
```

Alert prüfen:

```text
http://localhost:9090/alerts
http://localhost:9093/#/alerts
```

Node wieder starten:

```bash
docker compose start demo1
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
9. Prometheus Targets unter `http://localhost:9090/targets` zeigen.
10. CAdvisor-Metriken mit PromQL `container_cpu_usage_seconds_total{job="cadvisor"}` zeigen.
11. Alert `NodeDown` mit `docker compose stop demo1` auslösen.
12. Alert in Prometheus und Alertmanager zeigen.
13. Node mit `docker compose start demo1` wieder starten.
14. Testplan und Testprotokoll in `docs/testplan.md` zeigen.
15. Persönliches Fazit in `docs/prometheus-cadvisor-alerting.md` zeigen.

## Abgaberelevante Dateien

| Datei | Zweck |
| --- | --- |
| `docker-compose.yml` | Definiert Broker, Grafana, Bash-Sensoren und Java-Sensoren. |
| `bash-sensoren/Dockerfile` | Image für Bash-Sensoren mit Bash und Mosquitto-Clients. |
| `java-sensoren/Dockerfile` | Multi-Stage-Build für die Java-Sensoren. |
| `grafana/provisioning/datasources/mqtt.yml` | Automatische MQTT-Datenquelle. |
| `grafana/provisioning/datasources/prometheus.yml` | Automatische Prometheus-Datenquelle. |
| `grafana/provisioning/dashboards/smarthome.yml` | Automatisches Dashboard-Provisioning. |
| `grafana/dashboards/smarthome-mqtt.json` | Dashboard mit Bash- und Java-Panel. |
| `prom_conf/prometheus.yaml` | Prometheus Scrape-Jobs, Alert-Regeln und Alertmanager-Anbindung. |
| `prom_conf/alerts.yaml` | Prometheus-Alerts für CAdvisor, Targets und CPU-Last. |
| `prom_conf/alertmanager.yaml` | Alertmanager-Konfiguration für lokale Live-Abnahme. |
| `docs/prometheus-cadvisor-alerting.md` | Vorgehensweise, Zusammenspiel, Alerting-Demo und persönliches Fazit. |
| `docs/testplan.md` | Testplan und Testprotokoll. |
| `tests/test-mqtt-stack.sh` | Automatisierter Integrationstest für Bash/Ubuntu. |
| `tests/test-mqtt-stack.ps1` | Automatisierter Integrationstest für PowerShell. |
| `screenshots/` | Bildnachweise für die Abgabe. |

## Kriterien-Abgleich

| Kriterium | Nachweis |
| --- | --- |
| Vorgehensweise Prometheus inkl. Alerts und CAdvisor Installation & Konfiguration | `docs/prometheus-cadvisor-alerting.md`, `docker-compose.yml`, `prom_conf/` |
| Zusammenspiel CAdvisor, Prometheus inkl. Alerts und Grafana erklärt und illustriert | Architekturdiagramm in `docs/prometheus-cadvisor-alerting.md` |
| Container-Monitoring funktioniert in Cloud/Live-Abnahme | `docker compose up -d --build`, `http://localhost:9090/targets`, PromQL `container_cpu_usage_seconds_total{job="cadvisor"}` |
| Prometheus-Alerts funktionieren | Live-Test `docker compose stop demo1`, Alert `NodeDown`; Container-Alert `ContainerNotResponding` in `prom_conf/alerts.yaml` |
| Aussagekräftiger Testplan und Testprotokoll für Alerting | T12 bis T16 in `docs/testplan.md` |
| Konstruktives persönliches Fazit | Abschnitt `Persoenliches Fazit` in `docs/prometheus-cadvisor-alerting.md` |
