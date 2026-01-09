#!/bin/bash
# Start the MCP HTTP server

SERVER_DIR="$HOME/code/sse-filesystem-mcp"
LOG_FILE="/tmp/mcp_http.log"
PID_FILE="/tmp/mcp_http.pid"

cd "$SERVER_DIR" || exit 1

# Check if already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Server is already running (PID: $PID)"
        exit 0
    else
        echo "Stale PID file found, removing..."
        rm "$PID_FILE"
    fi
fi

# Start the server
echo "Starting MCP HTTP server..."
nohup python3 -u server_http.py > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Save PID
echo $SERVER_PID > "$PID_FILE"

# Wait a moment and check if it started
sleep 2
if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "Server started successfully (PID: $SERVER_PID)"
    echo "Log file: $LOG_FILE"
    echo "Listening on: https://0.0.0.0:8765"
    
    # Show last few log lines
    echo ""
    echo "=== Recent log entries ==="
    tail -5 "$LOG_FILE"
else
    echo "Failed to start server"
    echo "Check log file: $LOG_FILE"
    rm "$PID_FILE"
    exit 1
fi
