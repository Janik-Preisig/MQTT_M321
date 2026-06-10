# Testplan und Testprotokoll

## Ziel der Tests

Die Tests prüfen, ob die Migration in Container vollständig funktioniert und ob alle Komponenten zusammenarbeiten:

- Mosquitto nimmt MQTT-Verbindungen an.
- Bash-Sensoren senden auf getrennte Topics.
- Java-Sensoren senden auf getrennte Topics.
- Java-Sensoren reagieren auf MQTT-Commands.
- Grafana ist erreichbar.
- Grafana hat die MQTT-Datenquelle und das Dashboard aus dem Repository provisioniert.

## Testumgebung

| Element | Wert |
| --- | --- |
| Datum | 10.06.2026 |
| Betriebssystem | Windows 11 mit Docker Desktop |
| Docker | 29.2.1 |
| Docker Compose | v5.1.0 |
| Java für Maven | 21.0.2 über Maven-Konfiguration |
| Maven | 3.9.10 |
| Grafana MQTT Plugin | 1.3.1, automatisch über `GF_INSTALL_PLUGINS` installiert |

## Testdaten

| Bereich | Topics / Werte |
| --- | --- |
| Bash | `bash/r1`, `bash/r2`, `bash/r3` |
| Java | `java/r1`, `java/r2`, `java/r3` |
| Java Commands | `java/commands` mit `status`, `pause`, `resume`, `stop` |
| MQTT Direkt | Topic `test/direct`, Nachricht `hello` |

## Testfälle

| ID | Bereich | Vorgehen | Erwartetes Ergebnis |
| --- | --- | --- | --- |
| T01 | Build | `docker compose build` ausführen | Images für Bash- und Java-Sensoren werden ohne Fehler gebaut. |
| T02 | Compose | `docker compose config` ausführen | Compose-Datei ist syntaktisch gültig. |
| T03 | Start | `docker compose up -d --build` ausführen | Alle vier Services starten. |
| T04 | Broker | `mosquitto_pub` im Broker-Container auf `test/direct` ausführen und mit `mosquitto_sub` empfangen | Nachricht `test/direct hello` wird empfangen. |
| T05 | Bash-Sensoren | Auf `bash/#` subscriben | Es kommen Nachrichten für `bash/r1`, `bash/r2` und `bash/r3`. |
| T06 | Java-Sensoren | Auf `java/#` subscriben | Es kommen Nachrichten für `java/r1`, `java/r2` und `java/r3`. |
| T07 | Java Subscriber | `status` auf `java/commands` publizieren | Java-Logs enthalten `Befehl=status`. |
| T08 | Grafana HTTP | `http://localhost:3001/api/health` abrufen | Grafana liefert HTTP 200 und Statusinformationen. |
| T09 | Grafana Datasource | `/api/datasources/uid/mqtt` abrufen | Datasource `grafana-mqtt-datasource` mit UID `mqtt` existiert. |
| T10 | Grafana Dashboard | Dashboard `Smart Home MQTT` öffnen | Es gibt ein Bash-Panel und ein Java-Panel mit getrennten MQTT-Topics. |
| T11 | Neustart | `docker compose restart` ausführen | Services starten wieder und Sensoren senden erneut. |

## Automatisierter Test

Der automatisierte Test deckt T03 bis T09 ab:

```bash
bash tests/test-mqtt-stack.sh
```

Auf Windows kann dieselbe Prüfung mit PowerShell ausgeführt werden:

```powershell
powershell -ExecutionPolicy Bypass -File tests/test-mqtt-stack.ps1
```

Der Test führt diese Schritte aus:

1. Stack mit Build starten.
2. Mosquitto-Erreichbarkeit prüfen.
3. MQTT Publish/Subscribe direkt prüfen.
4. Bash-Topics prüfen.
5. Java-Topics prüfen.
6. Java-Command `status` prüfen.
7. Grafana API prüfen.
8. Grafana MQTT-Datenquelle prüfen.

## Manuelle Zusatztests

### T10 Dashboard prüfen

1. Browser öffnen: `http://localhost:3001`
2. Dashboard `Smart Home MQTT` öffnen.
3. Prüfen, ob das Panel `Bash Sensoren Timeline` Daten aus `bash/r1`, `bash/r2`, `bash/r3` zeigt.
4. Prüfen, ob das Panel `Java Sensoren Timeline` Daten aus `java/r1`, `java/r2`, `java/r3` zeigt.

Erwartung: Beide Panels zeigen neue Daten, sobald die Sensor-Container laufen.

### T11 Neustart prüfen

```bash
docker compose restart
docker compose ps
docker compose exec mosquitto mosquitto_sub -h localhost -p 1883 -t '#' -C 10 -W 20 -v
```

Erwartung: Nach dem Neustart sind alle Services wieder aktiv und MQTT-Nachrichten erscheinen erneut.

## Testprotokoll

| ID | Ergebnis | Nachweis |
| --- | --- | --- |
| T01 | bestanden | `docker compose build` baut `mqtt-bash-sensoren` und `mqtt-java-sensoren`. Der Java-Build führt 2 Unit-Tests aus: 0 Fehler. |
| T02 | bestanden | `docker compose config --quiet` beendet ohne Fehler. |
| T03 | bestanden | `docker compose ps` zeigt `mosquitto`, `bash-sensoren`, `java-sensoren` und `grafana` als `Up`; Mosquitto ist `healthy`. |
| T04 | bestanden | Direkter MQTT-Test empfängt `test/direct hello`. |
| T05 | bestanden | Subscribe auf `bash/#` empfängt unter anderem `bash/r1 23`, `bash/r2 30`, `bash/r3 13`. |
| T06 | bestanden | Subscribe auf `java/#` empfängt unter anderem `java/r1 23.60`, `java/r2 506.26`, `java/r3 682.04`. |
| T07 | bestanden | Nach Publish auf `java/commands` mit `status` enthalten die Java-Logs `Befehl=status PublishingAktiv=true` für alle drei Sensoren. |
| T08 | bestanden | `http://localhost:3001/api/health` ist erreichbar. |
| T09 | bestanden | `/api/datasources/uid/mqtt` liefert Typ `grafana-mqtt-datasource` und URI `tcp://mosquitto:1883`. |
| T10 | bestanden | `/api/search?query=Smart%20Home%20MQTT` findet Dashboard `Smart Home MQTT`; Screenshot `screenshots/grafana-dashboard-bash-java.png` dokumentiert die Ansicht. |
| T11 | bestanden | Nach `docker compose restart` sind alle vier Services wieder `Up`; Subscribe auf `#` empfängt wieder Bash- und Java-Werte. |

## Auszug aus dem automatisierten Testlauf

```text
[test] Prüfe Bash-Sensor-Topics...
bash/r1 23
bash/r2 30
bash/r3 13

[test] Prüfe Java-Sensor-Topics...
java/r3 682.04
java/r2 506.26
java/r1 23.60

[test] Prüfe provisionierte Grafana-Datenquelle...
[test] Alle Container-Migrationstests erfolgreich.
```

## Auszug aus dem Neustart-Test

```text
NAME            STATUS
mosquitto       Up, healthy
bash-sensoren   Up
java-sensoren   Up
grafana         Up

bash/r2 61
bash/r1 26
bash/r3 85
java/r1 19.95
java/r3 510.55
java/r2 397.00
```

## Bewertung der Migration

Die Container-Migration ist erfolgreich, wenn alle automatisierten Tests bestehen und im Dashboard beide Sensorgruppen getrennt sichtbar sind. Fehler in einem Teilbereich werden über Container-Logs, MQTT-Subscribe und Grafana API einzeln eingegrenzt.
