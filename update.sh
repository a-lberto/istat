#!/bin/bash

# Configuration
ENDPOINT="https://esploradati.istat.it/SDMXWS/rest/data/IT1,169_748_DF_DCSP_FOI1B2025_1,1.0/M.IT..7.00ST/ALL/?detail=dataonly"
HEADER="Accept: application/vnd.sdmx.data+json;version=1.0"
OUTPUT_FILE="data.json"


echo "Fetching data from ISTAT..."

DATA=$(curl -s -H "$HEADER" "$ENDPOINT")

if echo "$DATA" | jq empty > /dev/null 2>&1; then
    echo "$DATA" | jq '
        .data as $d 
        | $d.dataSets[0].series 
        | to_entries[0].value.observations | to_entries[] 
        | "\($d.structure.dimensions.observation[0].values[.key | tonumber].id): \(.value[0])"
        ' > "$OUTPUT_FILE"
    echo "Successfully updated $OUTPUT_FILE"
else
    echo "Error: Invalid JSON received from API"
    exit 1
fi