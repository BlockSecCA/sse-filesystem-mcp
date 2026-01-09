#!/bin/bash
# Check status of the MCP HTTP server

PID_FILE="/tmp/mcp_http.pid"
LOG_FILE="/tmp/mcp_http.log"

echo "=== MCP HTTP Server Status ==="
echo ""

# Check by PID file
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "✓ Server is RUNNING"
        echo "  PID: $PID"
        
        # Get process details
        echo "  Started: $(ps -p $PID -o lstart=)"
        echo "  CPU/Memory: $(ps -p $PID -o %cpu,%mem | tail -1)"
        
    else
        echo "✗ Server is NOT running (stale PID file)"
        echo "  PID file exists but process $PID is dead"
    fi
else
    # Check by process name
    PIDS=$(ps aux | grep "[p]ython3.*server_http.py" | awk '{print $2}')
    if [ -z "$PIDS" ]; then
        echo "✗ Server is NOT running"
    else
        echo "⚠ Server is running but no PID file"
        echo "  PIDs: $PIDS"
    fi
fi

echo ""
echo "=== Port Status ==="
if netstat -tuln 2>/dev/null | grep -q ":8765"; then
    echo "✓ Port 8765 is listening"
    netstat -tuln | grep ":8765"
else
    echo "✗ Port 8765 is NOT listening"
fi

echo ""
echo "=== Log File ==="
if [ -f "$LOG_FILE" ]; then
    echo "Location: $LOG_FILE"
    echo "Size: $(du -h $LOG_FILE | cut -f1)"
    echo ""
    echo "Recent entries (last 10 lines):"
    echo "---"
    tail -10 "$LOG_FILE"
else
    echo "Log file not found: $LOG_FILE"
fi
