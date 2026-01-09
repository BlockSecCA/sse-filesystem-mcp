# Python HTTP MCP Server - Working Example

This is a minimal, working example of an MCP (Model Context Protocol) server written in Python using HTTPS/HTTP transport. It demonstrates how to create a remote MCP server that Claude Desktop can connect to via `mcp-remote`.

## What This Does

- Exposes a simple `read_file` tool that reads files from the Ubuntu server
- Uses HTTPS with self-signed certificates (mkcert)  
- Runs on a remote Ubuntu machine (192.168.1.70)
- Connects to Claude Desktop on Windows via `mcp-remote` proxy
- **Proper TLS certificate validation** (not bypassed!)

## Quick Start

If you want the full story on certificates and why certain things work, see [Certificate Configuration Details](README_CERT_UPDATE.md).

### On Ubuntu

```bash
# 1. Install mkcert and generate certificates
cd ~/code/sse-filesystem-mcp
sudo apt install libnss3-tools
wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
chmod +x mkcert-v1.4.4-linux-amd64
sudo mv mkcert-v1.4.4-linux-amd64 /usr/local/bin/mkcert
mkcert -install
mkcert 192.168.1.70 localhost 127.0.0.1

# 2. Copy rootCA.pem to Windows (at C:\certs\mkcert-rootCA.pem)
mkcert -CAROOT  # Shows: /home/carlos/.local/share/mkcert
# Copy rootCA.pem from that directory to Windows

# 3. Start the server
./start.sh
```

### On Windows

**1. Create directory and copy certificate:**
```powershell
New-Item -ItemType Directory -Force -Path C:\certs
# Copy rootCA.pem from Ubuntu to C:\certs\mkcert-rootCA.pem
```

**2. Configure Claude Desktop:**

Edit: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "PythonFS": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://192.168.1.70:8765",
        "--http"
      ],
      "env": {
        "NODE_EXTRA_CA_CERTS": "C:\\certs\\mkcert-rootCA.pem"
      }
    }
  }
}
```

**3. Restart Claude Desktop**

## Important: Certificate Configuration

⚠️ **Critical:** Node.js does NOT use the Windows Certificate Store!

You MUST use `NODE_EXTRA_CA_CERTS` to point to your root CA file.

See [README_CERT_UPDATE.md](README_CERT_UPDATE.md) for complete details on:
- Why Windows Certificate Store doesn't work
- How Node.js certificate validation works  
- Proper vs insecure configuration
- Troubleshooting certificate issues
- Corporate proxy configuration

   - Right-click `rootCA.pem` → Install Certificate
   - Store Location: **Local Machine** (requires admin)
   - Place in: **Trusted Root Certification Authorities**
   - Set Friendly Name: `mkcert-ubuntu-192.168.1.70` (makes it easy to find later)

2. **Verify certificate installed**
```powershell
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Issuer -like "*mkcert*" }
```

## Running the Server

### Start the MCP Server on Ubuntu

```bash
cd ~/code/sse-filesystem-mcp
python3 server_http.py > /tmp/mcp_http.log 2>&1 &
```

### Verify it's running
```bash
# Check the process
ps aux | grep "python3.*server_http"

# Check it's listening
netstat -tuln | grep 8765

# Test from Windows
Test-NetConnection -ComputerName 192.168.1.70 -Port 8765
```

## Configure Claude Desktop

### Edit Configuration File

**Location:** `%APPDATA%\Claude\claude_desktop_config.json`

**Full path:** `C:\Users\YourUsername\AppData\Roaming\Claude\claude_desktop_config.json`

**Content:**
```json
{
  "mcpServers": {
    "PythonFS": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://192.168.1.70:8765",
        "--http"
      ],
      "env": {
      }
    }
  }
}
```

**Important notes:**
- The URL comes **before** the `--http` flag
- For production, use proper certificates instead

### Restart Claude Desktop

Completely quit and restart Claude Desktop for changes to take effect.

## Verification

1. **Check Claude Desktop Settings**
   - Go to Settings → Developer
   - You should see "PythonFS (LOCAL DEV)" with a "Configure" button
   - Status should show as connected

2. **Check Logs**
   - Windows: `%APPDATA%\Claude\logs\mcp-server-PythonFS.log`
   - Ubuntu: `/tmp/mcp_http.log`

3. **Test the Tool**
   In a Claude conversation, try:
   ```
   Use the read_file tool to read /etc/hostname
   ```

## Troubleshooting

### Connection Timeout
- Verify server is running: `netstat -tuln | grep 8765`
- Test connectivity from Windows: `Test-NetConnection -ComputerName 192.168.1.70 -Port 8765`
- Check Ubuntu firewall: `sudo ufw status`

### Certificate Errors
- Verify Root CA is installed: `certmgr.msc` → Trusted Root Certification Authorities
- Check certificate files exist: `ls -l ~/code/sse-filesystem-mcp/*.pem`

### Server Not Responding
- Check server logs: `tail -f /tmp/mcp_http.log`
- Verify server is listening on `0.0.0.0` not `127.0.0.1`
- Test with curl: `curl -k https://192.168.1.70:8765` (should hang, that's normal)

### "Server Disconnected" in Claude Desktop
- Check `mcp-server-PythonFS.log` for specific errors
- Verify `mcp-remote` is installed: `npx -y mcp-remote --version`
- Make sure URL format is correct (no trailing `/sse`)

## Architecture

```
Claude Desktop (Windows)
    ↓ stdio
mcp-remote (npx proxy)
    ↓ HTTPS
server_http.py (Ubuntu)
    ↓
Filesystem
```

The flow:
1. Claude Desktop spawns `mcp-remote` as a local stdio process
2. `mcp-remote` converts stdio ↔ HTTP and connects to your Python server
3. Python server handles MCP protocol over HTTP
4. Responses flow back through the same chain

## Key Differences from SSE Transport

**Why HTTP instead of SSE?**
- Simpler to implement (request/response vs. streaming)
- More reliable with `mcp-remote`
- SSE requires complex connection management with multiple clients
- HTTP is stateless and easier to debug

**The failed SSE attempt:**
- SSE requires separate GET `/sse` endpoint for streaming
- POST messages go to different endpoint (`/message` or `/`)
- Client must manage connection IDs
- `mcp-remote` had timeout issues with SSE

## Files

- `server_http.py` - Working HTTP MCP server (simple, reliable)
- `server_fixed.py` - SSE implementation attempt (more complex, had issues)
- `server.py` - Original ChatGPT version (broken architecture)
- `CERT_INFO.md` - Certificate documentation
- `192.168.1.70+2.pem` - Server certificate
- `192.168.1.70+2-key.pem` - Server private key

## Security Notes

⚠️ **This is a development setup, not production-ready:**

- Server has minimal error handling
- No authentication/authorization
- File access is unrestricted (only has `read_file` tool currently)
- Self-signed certificates are for local/dev use only

**For production:**
- Use proper CA-signed certificates
- Add authentication (Bearer tokens, OAuth, etc.)
- Implement proper access controls
- Add rate limiting
- Use proper logging and monitoring

## Extending the Server

To add more tools, follow this pattern in `server_http.py`:

```python
def handle_your_tool(args):
    # Your tool logic here
    return {"result": "your data"}

# Add to TOOLS dict
TOOLS = {
    "read_file": handle_read_file,
    "your_tool": handle_your_tool  # Add here
}

# Update tools list response
def mcp_tools_list_response(msg_id):
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "result": {
            "tools": [
                # ... existing tools ...
                {
                    "name": "your_tool",
                    "description": "What your tool does",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "param": {"type": "string"}
                        },
                        "required": ["param"]
                    }
                }
            ]
        }
    }
```

## References

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [mcp-remote npm package](https://www.npmjs.com/package/@ownid/mcp-remote)
- [mkcert](https://github.com/FiloSottile/mkcert)
- [Claude Desktop MCP Documentation](https://support.anthropic.com/en/articles/11175166-about-custom-integrations-using-remote-mcp)

## Credits

Built through trial and error with Claude, after ChatGPT provided a broken SSE implementation. Key learnings:
- SSE transport is complex and `mcp-remote` has issues with it
- HTTP transport is simpler and more reliable for remote MCP servers
- Certificate management is critical for HTTPS
- `mcp-remote` is essential for connecting Claude Desktop to remote servers

## Management Scripts

Three convenience scripts are provided for easy server management:

### Start the Server
```bash
cd ~/code/sse-filesystem-mcp
./start.sh
```

**What it does:**
- Checks if server is already running
- Starts server in background
- Saves PID to `/tmp/mcp_http.pid`
- Logs to `/tmp/mcp_http.log`
- Shows recent log entries

**Example output:**
```
Starting MCP HTTP server...
Server started successfully (PID: 223509)
Log file: /tmp/mcp_http.log
Listening on: https://0.0.0.0:8765

=== Recent log entries ===
[SERVER] Starting HTTPS server on 0.0.0.0:8765
```

### Stop the Server
```bash
cd ~/code/sse-filesystem-mcp
./stop.sh
```

**What it does:**
- Tries graceful shutdown (SIGTERM)
- Waits up to 5 seconds
- Forces shutdown if needed (SIGKILL)
- Cleans up PID file
- Falls back to finding by process name if PID file missing

**Example output:**
```
Stopping MCP HTTP server (PID: 223509)...
Server stopped gracefully
```

### Check Server Status
```bash
cd ~/code/sse-filesystem-mcp
./status.sh
```

**What it shows:**
- Running status and PID
- Process start time
- CPU and memory usage
- Port 8765 listening status
- Recent log entries

**Example output:**
```
=== MCP HTTP Server Status ===

✓ Server is RUNNING
  PID: 223509
  Started: Tue Nov 18 16:48:38 2025
  CPU/Memory:  0.9  0.0

=== Port Status ===
✓ Port 8765 is listening
tcp        0      0 0.0.0.0:8765            0.0.0.0:*               LISTEN     

=== Log File ===
Location: /tmp/mcp_http.log
Size: 4.0K

Recent entries (last 10 lines):
---
[SERVER] Starting HTTPS server on 0.0.0.0:8765
```

### Quick Commands

```bash
# Start server
./start.sh

# Check status
./status.sh

# View live logs
tail -f /tmp/mcp_http.log

# Restart server
./stop.sh && ./start.sh

# Stop server
./stop.sh
```

### Log Management

The server logs to `/tmp/mcp_http.log`. To manage log growth:

```bash
# View last 50 lines
tail -50 /tmp/mcp_http.log

# Clear logs (while server is stopped)
./stop.sh
rm /tmp/mcp_http.log
./start.sh

# Rotate logs (keep server running)
mv /tmp/mcp_http.log /tmp/mcp_http.log.old
./stop.sh && ./start.sh
```
