# Grafana

Dieser Ordner enthält die Grafana-Konfiguration für die containerisierte Smart-Home-Demo.

## Zweck

Grafana wird über Docker Compose gestartet und beim Start automatisch vorbereitet:

- MQTT-Datenquelle `MQTT`
- Broker-URI `tcp://mosquitto:1883`
- Dashboard `Smart Home MQTT`
- Panel für Bash-Sensoren
- Panel für Java-Sensoren

Dadurch muss die Datenquelle nicht manuell in der Grafana-Oberfläche erstellt werden.

## Struktur

```text
grafana/
+-- README.md
+-- dashboards/
|   +-- smarthome-mqtt.json
+-- provisioning/
    +-- datasources/
    |   +-- mqtt.yml
    +-- dashboards/
    |   +-- smarthome.yml
    +-- alerting/
    |   +-- .gitkeep
    +-- plugins/
        +-- .gitkeep
```

## Dateien

| Datei | Aufgabe |
| --- | --- |
| `provisioning/datasources/mqtt.yml` | Legt die MQTT-Datenquelle mit UID `mqtt` an. |
| `provisioning/dashboards/smarthome.yml` | Sagt Grafana, wo Dashboard-JSON-Dateien liegen. |
| `dashboards/smarthome-mqtt.json` | Enthält das Dashboard mit getrennten Bash- und Java-Panels. |
| `provisioning/alerting/.gitkeep` | Hält den leeren Alerting-Ordner im Repository. |
| `provisioning/plugins/.gitkeep` | Hält den leeren Plugin-Provisioning-Ordner im Repository. |

## Zugriff

Grafana läuft im Compose-Stack standardmässig auf:

```text
http://localhost:3001
```

Login:

```text
Benutzername: admin
Passwort: admin
```

## Prüfung

Datasource per API prüfen:

```bash
curl -u admin:admin http://localhost:3001/api/datasources/uid/mqtt
```

Dashboard per API suchen:

```bash
curl -u admin:admin "http://localhost:3001/api/search?query=Smart%20Home%20MQTT"
```

Erwartung:

- Die Datenquelle hat den Typ `grafana-mqtt-datasource`.
- Die URI lautet `tcp://mosquitto:1883`.
- Das Dashboard `Smart Home MQTT` ist vorhanden.
