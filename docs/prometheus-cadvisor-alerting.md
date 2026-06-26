# Prometheus, CAdvisor und Alerting

## Ziel

Dieses Monitoring ergaenzt die MQTT-Smart-Home-Demo um Container-Metriken und Alerts. Prometheus sammelt Metriken, CAdvisor liefert Container-Statistiken, Alertmanager nimmt Prometheus-Alerts entgegen und Grafana kann Prometheus als Datenquelle verwenden.

## Zusammenspiel

```text
Docker Container
mosquitto, grafana, sensoren, prometheus, alertmanager
        |
        v
     CAdvisor
Container-CPU, Speicher, Netzwerk, Startzeit
        |
        v
    Prometheus
Scraping, Speicherung, Alert-Regeln
        |
        +--------------------+
        |                    |
        v                    v
  Alertmanager           Grafana
Alert-Status          Dashboards und Explore
```

## Installation und Konfiguration

Alle Monitoring-Komponenten werden ueber `docker-compose.yml` gestartet:

| Service | Port | Aufgabe |
| --- | --- | --- |
| `cadvisor` | `18080` auf dem Host, intern `8080` | Liest Docker-/Container-Metriken und stellt sie fuer Prometheus bereit. |
| `prometheus` | `9090` | Scraped CAdvisor, Demo-Exporter und sich selbst. Wertet Alert-Regeln aus. |
| `alertmanager` | `9093` | Empfaengt Alerts von Prometheus und zeigt ihren Status an. |
| `grafana` | `3001` | Visualisiert MQTT- und Prometheus-Daten. |

Wichtige Dateien:

| Datei | Zweck |
| --- | --- |
| `prom_conf/prometheus.yaml` | Scrape-Jobs, Alertmanager-Anbindung und Rule-Datei. |
| `prom_conf/alerts.yaml` | Alert-Regeln fuer CAdvisor, ausgefallene Targets und hohe CPU-Last. |
| `prom_conf/alertmanager.yaml` | Lokaler Demo-Receiver fuer Alerts. |
| `grafana/provisioning/datasources/prometheus.yml` | Automatische Grafana-Datenquelle `Prometheus`. |

Start:

```bash
docker compose up -d --build
```

Konfiguration pruefen:

```bash
docker compose config --quiet
docker compose ps
```

## Prometheus Targets pruefen

Prometheus im Browser oeffnen:

```text
http://localhost:9090/targets
```

Erwartung:

| Job | Erwartung |
| --- | --- |
| `prometheus` | `UP` |
| `cadvisor` | `UP` |
| `node-exporter-demo` | `demo1:9100` und `demo2:9100` sind `UP` |

Beispiel-Queries:

```promql
up
container_cpu_usage_seconds_total{job="cadvisor"}
rate(container_cpu_usage_seconds_total{job="cadvisor", id!="/"}[2m])
container_memory_usage_bytes{job="cadvisor"}
```

## Alerts

Die Alert-Regeln liegen in `prom_conf/alerts.yaml`.

| Alert | Ausloeser | Live-Test |
| --- | --- | --- |
| `NodeDown` | `up{job="node-exporter-demo"} == 0` fuer 1 Minute | `docker compose stop demo1` |
| `ContainerNotResponding` | `time() - container_last_seen{job="cadvisor", id!="/"} > 60` | indirekt ueber fehlende CAdvisor-Aktualisierung pruefbar |
| `CAdvisorTargetDown` | `up{job="cadvisor"} == 0` fuer 1 Minute | `docker compose stop cadvisor` |

Live-Abnahme fuer den geforderten Node-Alert:

```bash
docker compose stop demo1
```

Danach in Prometheus oeffnen:

```text
http://localhost:9090/alerts
```

Nach ca. 1 Minute muss `NodeDown` von `pending` auf `firing` wechseln. Im Alertmanager ist der Alert ebenfalls sichtbar:

```text
http://localhost:9093/#/alerts
```

Nachweis, dass sich der Alert wieder aufloest:

```bash
docker compose start demo1
```

Nach dem naechsten Scrape steht das Target wieder auf `UP`, und der Alert verschwindet nach kurzer Zeit aus der aktiven Liste.

## Grafana

Grafana wird automatisch mit zwei Datenquellen provisioniert:

| Datenquelle | Zweck |
| --- | --- |
| `MQTT` | Live-Werte der Bash- und Java-Sensoren. |
| `Prometheus` | Container-Metriken und Alert-nahe PromQL-Abfragen. |

Prometheus-Daten in Grafana pruefen:

1. `http://localhost:3001` oeffnen.
2. Mit `admin` / `admin` anmelden.
3. `Connections` -> `Data sources` -> `Prometheus` pruefen.
4. In `Explore` die Query `up` ausfuehren.

## Persoenliches Fazit

Durch Prometheus und CAdvisor wird sichtbar, ob die Container nicht nur starten, sondern auch im Betrieb gesund sind. Besonders hilfreich ist der einfache Alert-Test mit `docker compose stop demo1`, weil dadurch der Weg von einem technischen Problem ueber Prometheus bis in den Alertmanager nachvollziehbar demonstriert werden kann. Fuer Modul 321 zeigt das gut, dass Containerisierung nicht bei `docker compose up` endet, sondern auch Betrieb, Beobachtbarkeit und reproduzierbare Tests umfasst.
