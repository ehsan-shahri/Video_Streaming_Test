#!/bin/bash

# Define the Wi-Fi interface to capture from
WIFI_INTERFACE="enx9cebe8d3c584"

# Define the starting port number for monitoring
START_PORT=1230  # First port to monitor

# Number of `tshark` instances to run (Change this to increase/decrease)
NUM_TSHARK=50  # Modify this to control the number of instances

# Temporary file to hold bytes received on each port
TEMP_FILE="/tmp/port_bytes.txt"
echo "" > $TEMP_FILE  # Clear the file content


# Function to run tshark and capture bytes received
function capture_packets {
    local port=$1
    echo "Setting up capture on port $port..."
    # Capture for 60 seconds and summarize the bytes
    total_bytes=$(timeout 120 tshark -i $WIFI_INTERFACE -Y "udp && ip.src == 10.255.34.93 && udp.port == $port" \
        -T fields -e frame.len 2>/dev/null | awk '{sum += $1-28} END {print sum}')
    echo "Total bytes received on port $port: $total_bytes"
    echo $total_bytes >> $TEMP_FILE  # Append result to temp file
}


# Run each tshark instance in the background and direct output to main terminal
for ((i=0; i<$NUM_TSHARK; i++)); do
    PORT=$((START_PORT + i))
    capture_packets $PORT &
done

# Wait for all background jobs to complete
wait

# Calculate and print total bytes received across all ports
total_bytes_received=0
while read bytes; do
    total_bytes_received=$((total_bytes_received + bytes))
done < $TEMP_FILE
echo "Total bytes received on $NUM_TSHARK ports: $total_bytes_received"

echo "All captures complete."
