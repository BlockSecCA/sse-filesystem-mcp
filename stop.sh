#!/bin/bash
# Stop the MCP HTTP server

PID_FILE="/tmp/mcp_http.pid"
LOG_FILE="/tmp/mcp_http.log"

if [ ! -f "$PID_FILE" ]; then
    echo "PID file not found. Checking for running server..."
    
    # Try to find by process name
    PIDS=$(ps aux | grep "[p]ython3.*server_http.py" | awk '{print $2}')
    
    if [ -z "$PIDS" ]; then
        echo "No server process found"
        exit 0
    else
        echo "Found server process(es): $PIDS"
        echo "Killing process(es)..."
        echo "$PIDS" | xargs kill -9 2>/dev/null
        echo "Server stopped"
        exit 0
    fi
fi

PID=$(cat "$PID_FILE")

# Check if process exists
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Server is not running (stale PID file)"
    rm "$PID_FILE"
    exit 0
fi

# Try graceful shutdown first
echo "Stopping MCP HTTP server (PID: $PID)..."
kill "$PID" 2>/dev/null

# Wait up to 5 seconds for graceful shutdown
for i in {1..5}; do
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo "Server stopped gracefully"
        rm "$PID_FILE"
        exit 0
    fi
    sleep 1
done

# Force kill if still running
echo "Server didn't stop gracefully, forcing..."
kill -9 "$PID" 2>/dev/null
sleep 1

if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "Server force stopped"
    rm "$PID_FILE"
else
    echo "Failed to stop server"
    exit 1
fi
