#!/bin/sh
ENCLAVE_ID="wakurtosis"
PROMETHEUS_YML="prometheus.yml"

# TODO: Check if the enclave already exists 
kurtosis enclave stop $ENCLAVE_ID
kurtosis enclave rm $ENCLAVE_ID

# Start the Kurtosis enclave
kurtosis run ./main.star --enclave-id $ENCLAVE_ID

# Fetch the targets from the Kurtosis output
# TODO: Fetch the targets directly in the Starlark script
targets=$(kurtosis enclave inspect $ENCLAVE_ID | grep 'prometheus' | sed -e 's/^.*-> \([^ ]*\) .*$/\1/' | sed "s/.*/\"&\"/;H;1h;"'$!d;x;s/\n/, /g')

# Generate the targets file for Prometheus
echo "Building Prometheus targets  ..."
echo "[{\"labels\": {\"job\": \"wakurtosis\"}, \"targets\" : [$targets] } ]" | tee './targets.json' > /dev/null

# Start / Restart Prometheus on http://localhost:9090
echo "Start Prometheus with on http://localhost:9090 with: prometheus --config.file=./prometheus.yml &"

# Starting Grafana on http://localhost:3000 with: brew services restart grafana

