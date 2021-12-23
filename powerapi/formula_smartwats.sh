#!/bin/bash

set -x

echo "Starting smartwatts formula........."
docker run --rm --net=host \
-v $(pwd)/config_file_smartwats.json:/config_file_smartwats.json \
powerapi/smartwatts-formula \
--config-file /config_file_smartwats.json