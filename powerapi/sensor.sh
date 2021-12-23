#!/bin/bash

set -x

echo "Starting hwpc-sensor........."
docker run --rm --net=host --privileged --pid=host \
-v /sys:/sys \
-v /var/lib/docker/containers:/var/lib/docker/containers:ro \
-v /tmp/powerapi-sensor-reporting:/reporting \
-v $(pwd):/srv \
-v $(pwd)/config_file_sensor.json:/config_file_sensor.json \
powerapi/hwpc-sensor \
--config-file /config_file_sensor.json


# Connect to mongoDB
# mongo 172.17.0.2:27017

# start InfluxDB
# docker run -d --name influx_rapl -p 8086:8086 influxdb:1.8