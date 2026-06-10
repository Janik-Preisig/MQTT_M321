# Load-Balancing Abgabe

Die Load-Balancing-Demo liegt getrennt vom bestehenden MQTT-Projekt im Ordner:

```text
load-balancing/
```

Start:

```powershell
cd load-balancing
docker compose up -d --build
powershell -ExecutionPolicy Bypass -File scripts/request-loop.ps1 -Requests 30
```

Dokumentation:

- [Load-Balancing Demo](load-balancing/README.md)
- [Testplan](load-balancing/docs/testplan.md)

Der zentrale Access Point der Demo ist:

```text
http://localhost:8080/
```
