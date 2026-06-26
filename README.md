# Modul 321 - MQTT Smart Home Container-Demo

## Personen

Erstellt von: Fionn Laesser  
Sparing-Partner: Janik Preisig

## Ziel

Dieses Repository enthält eine lauffähige, containerisierte Smart-Home-Demo. Mehrere Bash-basierte Sensoren und mehrere Java-basierte Sensoren senden Messwerte an einen Mosquitto MQTT-Broker. Grafana visualisiert die Daten über eine selbst konfigurierte MQTT-Datenquelle in zwei getrennten Panels.

Zusätzlich enthält der Stack ein Container-Monitoring mit Prometheus, CAdvisor und Alertmanager. Damit sind Container-Metriken, Prometheus-Targets und Prometheus-Alerts direkt in der Live-Abnahme prüfbar.

Die Lösung ist ab GitHub-Repo reproduzierbar:

```bash
docker compose up -d --build
```

## Architektur

```text
Bash-Sensoren                Java-Sensoren
bash/r1                     java/r1
bash/r2                     java/r2
bash/r3                     java/r3
     \                         /
      \                       /
       +--> Mosquitto MQTT <--+
                |
                v
       Grafana MQTT Datasource
                |
                v
   Dashboard: Bash Panel + Java Panel
```

## Services

| Service | Image / Build | Aufgabe | Port |
| --- | --- | --- | --- |
| `mosquitto` | `eclipse-mosquitto:2.0` | MQTT-Broker | `1883`, `9001` |
| `bash-sensoren` | eigenes Image aus `bash-sensoren/Dockerfile` | Drei Bash-Sensoren | kein Host-Port |
| `java-sensoren` | eigenes Image aus `java-sensoren/Dockerfile` | Drei Java-Sensoren mit Subscriber | kein Host-Port |
| `grafana` | `grafana/grafana:11.5.2` | Visualisierung | `3001` auf dem Host |
| `prometheus` | `prom/prometheus` | Metriken sammeln und Alerts auswerten | `9090` |
| `alertmanager` | `prom/alertmanager` | Prometheus-Alerts anzeigen | `9093` |
| `cadvisor` | `gcr.io/cadvisor/cadvisor` | Container-Metriken bereitstellen | `18080` auf dem Host, intern `8080` |
| `demo1`, `demo2` | `prom/node-exporter` | Demo-Targets für Prometheus | kein Host-Port |

Der Grafana-Port kann bei Bedarf geändert werden:

```bash
GRAFANA_PORT=3000 docker compose up -d --build
```

## MQTT-Topics

| Sensor | Topic | Daten |
| --- | --- | --- |
| Bash Wohnzimmer Temperatur | `bash/r1` | Zufallswert 18 bis 30 |
| Bash Bad Luftfeuchtigkeit | `bash/r2` | Zufallswert 30 bis 80 |
| Bash Flur Helligkeit | `bash/r3` | Zufallswert 0 bis 100 |
| Java Wohnzimmer Temperatur | `java/r1` | simulierte Kurve |
| Java Küche Energie | `java/r2` | simulierte Kurve |
| Java Keller Luftqualität | `java/r3` | simulierte Kurve |
| Java Commands | `java/commands` | `status`, `pause`, `resume`, `stop` |

## Sensoren steuern und stoppen

Ja, die Sensoren können über Kommandos gesteuert oder ausgeschaltet werden. Es gibt zwei Arten:

- Java-Sensoren werden über MQTT-Commands gesteuert.
- Bash-Sensoren werden über Docker-Compose-Service-Kommandos gestoppt oder gestartet.

### Java-Sensoren per MQTT steuern

Die Java-Sensoren hören auf das Topic:

```text
java/commands
```

Status abfragen:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m status
docker compose logs --tail=60 java-sensoren
```

Java-Publishing pausieren:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m pause
```

Die Java-Container bleiben dabei verbunden, senden aber keine neuen Werte mehr.

Java-Publishing wieder aktivieren:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m resume
```

Java-Sensorprogramm sauber beenden:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m stop
```

Wichtig: Der Compose-Service `java-sensoren` hat `restart: unless-stopped`. Nach dem MQTT-Command `stop` beendet sich das Java-Programm sauber, Docker startet den Container aber wieder neu. Wenn die Java-Sensoren wirklich ausgeschaltet bleiben sollen, stoppe zusätzlich den Service:

```bash
docker compose stop java-sensoren
```

Java-Sensoren wieder einschalten:

```bash
docker compose start java-sensoren
```

### Bash-Sensoren stoppen und starten

Die Bash-Sensoren haben keinen eigenen MQTT-Command-Subscriber. Sie laufen als eigener Compose-Service und werden deshalb über Docker Compose gesteuert.

Bash-Sensoren ausschalten:

```bash
docker compose stop bash-sensoren
```

Bash-Sensoren wieder einschalten:

```bash
docker compose start bash-sensoren
```

Bash-Sensoren neu starten:

```bash
docker compose restart bash-sensoren
```

### Ganzen Stack ausschalten

Alle Container stoppen, aber Volumes behalten:

```bash
docker compose stop
```

Alle Container wieder starten:

```bash
docker compose start
```

Alle Container entfernen, Daten-Volumes aber behalten:

```bash
docker compose down
```

Komplett neu starten:

```bash
docker compose up -d --build
```

## Start

Im Repository:

```bash
docker compose up -d --build
docker compose ps
```

Logs prüfen:

```bash
docker compose logs -f mosquitto
docker compose logs -f bash-sensoren
docker compose logs -f java-sensoren
docker compose logs -f grafana
```

Grafana öffnen:

```text
http://localhost:3001
```

Login:

```text
Benutzername: admin
Passwort: admin
```

Wichtig: Melde dich wirklich mit `admin` / `admin` an. Nur als Admin siehst du links `Connections` und darunter `Data sources`. Wenn du nur `Home`, `Starred`, `Dashboards` und `Alerting` siehst, bist du nicht als Admin angemeldet.

Direkter Login-Link:

```text
http://localhost:3001/login
```

## Grafana-Provisioning

Grafana wird beim Start automatisch vorbereitet:

- MQTT-Datenquelle `MQTT` mit UID `mqtt`
- Prometheus-Datenquelle `Prometheus` mit UID `prometheus`
- Broker-URI `tcp://mosquitto:1883`
- Dashboard `Smart Home MQTT`
- Panel `Bash Sensoren Timeline` für `bash/r1`, `bash/r2`, `bash/r3`
- Panel `Java Sensoren Timeline` für `java/r1`, `java/r2`, `java/r3`

Die Dateien liegen hier:

```text
grafana/provisioning/datasources/mqtt.yml
grafana/provisioning/datasources/prometheus.yml
grafana/provisioning/dashboards/smarthome.yml
grafana/dashboards/smarthome-mqtt.json
```

Datasource in Grafana ansehen:

```text
Connections
Data sources
MQTT
```

Die Datasource muss diese URI enthalten:

```text
tcp://mosquitto:1883
```

## Prometheus, CAdvisor und Alerting

Die Monitoring-Dokumentation mit Vorgehensweise, Zusammenspiel, Alert-Regeln, Testplan und Fazit liegt in [docs/prometheus-cadvisor-alerting.md](docs/prometheus-cadvisor-alerting.md).

Wichtige Oberflächen:

```text
Prometheus Targets: http://localhost:9090/targets
Prometheus Alerts:  http://localhost:9090/alerts
Alertmanager:       http://localhost:9093/#/alerts
CAdvisor:           http://localhost:18080
```

Prometheus scrapt diese Jobs:

| Job | Targets |
| --- | --- |
| `prometheus` | `prometheus:9090` |
| `cadvisor` | `cadvisor:8080` |
| `node-exporter-demo` | `demo1:9100`, `demo2:9100` |

Live-Test für den geforderten Node-Alert:

```bash
docker compose stop demo1
```

Nach ca. 1 Minute muss in `http://localhost:9090/alerts` der Alert `NodeDown` als `firing` sichtbar sein. Danach den Node wieder starten:

```bash
docker compose start demo1
```

## MQTT manuell testen

Direkter Publish/Subscribe-Test:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t test -v
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t test -m "hello mqtt"
```

Bash-Daten anzeigen:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t 'bash/#' -v
```

Java-Daten anzeigen:

```bash
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t 'java/#' -v
```

Java-Subscriber testen:

```bash
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m status
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m pause
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m resume
docker compose exec mosquitto mosquitto_pub -h localhost -p 1883 -t java/commands -m stop
```

Erwartung:

| Befehl | Verhalten |
| --- | --- |
| `status` | Java-Logs zeigen den aktuellen Publishing-Status. |
| `pause` | Java-Sensoren bleiben verbunden, senden aber keine neuen Werte. |
| `resume` | Java-Sensoren senden wieder Werte. |
| `stop` | Java-Sensoren beenden sich sauber und der Container startet wegen `restart: unless-stopped` neu. |

## Testplan

Der vollständige Testplan und das Testprotokoll liegen in [docs/testplan.md](docs/testplan.md).

Automatischer Integrationstest:

```bash
bash tests/test-mqtt-stack.sh
```

Unter PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tests/test-mqtt-stack.ps1
```

Der Test baut den Stack, prüft MQTT direkt, prüft Bash-Topics, prüft Java-Topics, sendet ein Java-Command und kontrolliert die provisionierte Grafana-Datenquelle.

## Abgabe-Checkliste

- Containerisierung ist vollständig in `docker-compose.yml` dokumentiert.
- Bash-Sensoren laufen in einem eigenen Image.
- Java-Sensoren laufen in einem eigenen Multi-Stage-Image.
- Mosquitto ist über `1883` und `9001` erreichbar.
- Grafana installiert das MQTT-Plugin automatisch.
- Grafana provisioniert Datenquelle und Dashboard automatisch.
- Prometheus, CAdvisor und Alertmanager sind in `docker-compose.yml` integriert.
- Prometheus scrapt CAdvisor und Demo-Targets.
- Prometheus-Alerts sind in `prom_conf/alerts.yaml` definiert.
- Der Alert `NodeDown` kann live mit `docker compose stop demo1` ausgelöst werden.
- Der Alert `ContainerNotResponding` prüft über `container_last_seen`, ob Container/CGroups länger als 1 Minute nicht reagiert haben.
- Bash-Daten werden in einem eigenen Timeline-Panel angezeigt.
- Java-Daten werden in einem zweiten Timeline-Panel angezeigt.
- Testplan und Testprotokoll liegen in `docs/testplan.md`.
- Monitoring-Doku und persönliches Fazit liegen in `docs/prometheus-cadvisor-alerting.md`.
- Screenshots für die Abgabe liegen in `screenshots/`.
# MQTT_M321
