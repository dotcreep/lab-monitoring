mkdir -p prometheus-data grafana_data
chown -R 65534:65534 prometheus-data
chown -R 472:472 grafana_data
docker compose up -d