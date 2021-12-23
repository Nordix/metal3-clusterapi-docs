#!/bin/bash

set -x

echo "Starting RAPL formula........."
docker run --rm --net=host \
-v $(pwd)/config_file_rapl.json:/config_file_rapl.json \
powerapi/rapl-formula \
--config-file /config_file_rapl.json