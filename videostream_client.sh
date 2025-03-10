""" 
Author: Ehsan Shahri
Email: ehsan.shahri@ua.pt
Date: 2025-01-08
Version: 2.07
Description: This script evaluates the performance of Wi-Fi 7 networks. This code runs on a client to captuter and send mulitiple instanse of a video stream to a server.
"""


#!/bin/bash

# Define the Wi-Fi interface to capture from
WIFI_INTERFACE="wlP2p33s0f0"

# Define CSV output file
CSV_FILE="path to CSV file/file.csv"

# Define a log file for capturing outputs
LOG_FILE="stream_outputs.log"
TOTAL_BYTES_FILE="total_bytes.log"  # File to store bytes for each stream
echo "" > $LOG_FILE  # Clear the log file content
echo "" > $TOTAL_BYTES_FILE  # Clear the total bytes file content

# Write CSV Header (only if file doesn't exist)
if [ ! -f "$CSV_FILE" ]; then
    echo "No.,Time,Source,Destination,Protocol,Length,Info" > "$CSV_FILE"
fi

# Number of FFmpeg streams to run
NUM_STREAMS=50

# Starting port for FFmpeg streams
START_PORT=1230
END_PORT=$((START_PORT + NUM_STREAMS - 1))

# Create a new tmux session named 'streams' and start in detached mode
tmux new-session -d -s streams

# Create enough panes
for ((i=0; i<$NUM_STREAMS - 1; i++)); do
    tmux split-window -h -t streams
    tmux select-layout -t streams tiled
done

# Start capturing packets
sudo tcpdump -i $WIFI_INTERFACE portrange $START_PORT-$END_PORT -w ~/capture.pcap &
TCPDUMP_PID=$!

# Start FFmpeg streams in separate panes
for ((i=0; i<$NUM_STREAMS; i++)); do
    PORT=$((START_PORT + i))

    # Command to capture specific packet size information and log it
    COMMAND="ffmpeg -t 120 -i rtsp://CAMERA_IP:554/stream1 \
    -c:v copy -f mpegts udp://SERVER_IP:$PORT -loglevel debug 2>&1 | \
    grep 'bytes) muxed' | tee >(awk -F'(' '{print \$2}' | awk -F' ' '{print \$1}' >> $TOTAL_BYTES_FILE) | \
    tee -a $LOG_FILE; \
    echo \"Port $PORT: Finished capturing, waiting 10 seconds before closing...\" >> $LOG_FILE; sleep 10; tmux kill-session -t streams"

    # Send FFmpeg command to each tmux pane
    tmux send-keys -t streams.$i "$COMMAND" C-m
done

# Wait for all streams to complete
sleep 140  # Adjust time as needed if it is different from the ffmpeg capture duration

# Stop the tcpdump process after the streams have completed
kill $TCPDUMP_PID
wait $TCPDUMP_PID 2>/dev/null

# Process the captured data
# tshark -r /tmp/capture.pcap -T fields -e frame.number -e frame.time -e ip.src -e ip.dst -e _ws.col.Protocol -e frame.len -e _ws.col.Info -E header=y -E separator=, -E quote=d > "$CSV_FILE"

# Process the captured data and write to a temporary file
tshark -r /tmp/capture.pcap -T fields -e frame.number -e frame.time -e ip.src -e ip.dst -e _ws.col.Protocol -e frame.len -e _ws.col.Info -E separator=, -E quote=d -E header=n > /tmp/temp_capture_data.csv

# Prepend headers to the CSV file
echo "No.,Time,Source,Destination,Protocol,Length,Info" > "$CSV_FILE"
cat /tmp/temp_capture_data.csv >> "$CSV_FILE"

# Clean up the temporary file
rm /tmp/temp_capture_data.csv

# Attach to the tmux session so the user can see the output
tmux attach-session -t streams

# Calculate the total bytes
total_bytes=0
while read bytes; do
    total_bytes=$((total_bytes + bytes))
done < $TOTAL_BYTES_FILE

# Print total bytes muxed on all ports
echo "Total bytes sent (on muxed) on $NUM_STREAMS ports: $total_bytes"

# Display the detailed log file contents in the main terminal
echo "Output from all streams:"
cat $LOG_FILE



