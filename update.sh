#!/bin/bash

FLOWREF="IT1,169_748_DF_DCSP_FOI1B2025_1,1.0"
KEY="M.IT.55.7.00ST"

URL="https://esploradati.istat.it/SDMXWS/rest/data/$FLOWREF/$KEY/ALL/?detail=dataonly&format=jsondata"
OUTPUT_FILE="data.json"

echo "Fetching data from ISTAT..."

DATA=$(curl -s -H "$HEADER" "$URL")

if echo "$DATA" | jq empty > /dev/null 2>&1; then
    echo "$DATA" | jq '.data as $d | $d.dataSets[0].series | to_entries[0].value.observations | to_entries | map({
        date: $d.structure.dimensions.observation[0].values[.key | tonumber].id,
        value: .value[0]
    }) | sort_by(.date) | reverse' > "$OUTPUT_FILE"
    echo "Successfully updated $OUTPUT_FILE" >&2
else
    echo "Error: Invalid JSON received from API" >&2
    exit 1
fi