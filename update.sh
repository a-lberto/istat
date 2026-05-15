#!/bin/bash

# Shared configuration
HEADER="Accept: application/vnd.sdmx.data+json;version=1.0"

# Dataset configuration: "FILENAME|ENDPOINT"
DATASETS=(
    "foi_monthly_percent_2025.json|https://esploradati.istat.it/SDMXWS/rest/data/IT1,169_748_DF_DCSP_FOI1B2025_1,1.0/M.IT..7.00ST/ALL/?detail=dataonly"
    "foi_monthly_percent_2015.json|https://esploradati.istat.it/SDMXWS/rest/data/IT1,169_745_DF_DCSP_FOI1B2015_1,1.0/M.IT..7.00ST/ALL/?detail=dataonly"
)

# Enable pipefail to catch errors in the curl | jq pipeline
set -o pipefail

update_dataset() {
    local output_file=$1
    local endpoint=$2
    local temp_file

    temp_file=$(mktemp)

    echo "Fetching data for $output_file..."

    if ! curl -s -f -H "$HEADER" "$endpoint" | jq '
        .data as $d 
        | {
            metadata: {
                source: "ISTAT",
                prepared: .meta.prepared,
                last_update: ($d.structure.annotations | .[] | select(.id == "LAST_UPDATE") | .title),
                description: $d.structure.dimensions.series[2].values[0].name,
                measure: $d.structure.dimensions.series[3].values[0].name,
                frequency: $d.structure.dimensions.series[0].values[0].name,
                area: $d.structure.dimensions.series[1].values[0].name,
                category: $d.structure.dimensions.series[4].values[0].name
            },
            data: [
                $d.dataSets[0].series 
                | to_entries[0].value.observations 
                | to_entries[] 
                | {
                    date: $d.structure.dimensions.observation[0].values[.key | tonumber].id,
                    value: (.value[0] | tonumber)
                  }
            ]
        }
        ' > "$temp_file"; then
        echo "Error: Failed to fetch or process data for $output_file"
        rm -f "$temp_file"
        return 1
    fi

    # Timestamp comparison
    local new_update
    local old_update
    new_update=$(jq -r '.metadata.last_update' "$temp_file")
    
    if [ -f "$output_file" ]; then
        old_update=$(jq -r '.metadata.last_update' "$output_file")
    else
        old_update="0"
    fi

    # ISO 8601 strings compare correctly lexicographically
    if [[ "$new_update" > "$old_update" ]]; then
        mv "$temp_file" "$output_file"
        echo "Successfully updated $output_file (Newer data: $new_update > $old_update)"
    else
        echo "No update needed for $output_file (Data is current: $old_update)"
        rm -f "$temp_file"
    fi
}

# Process each dataset
FAILED=0
for ds in "${DATASETS[@]}"; do
    IFS="|" read -r filename url <<< "$ds"
    update_dataset "$filename" "$url" || FAILED=1
done

# Clean up old non-descriptive file if it exists
if [ -f "data.json" ]; then
    rm "data.json"
fi

if [ $FAILED -eq 0 ]; then
    echo "Update check completed."
else
    echo "Some datasets failed to process."
    exit 1
fi
