import json
from http.server import BaseHTTPRequestHandler, HTTPServer
import os
import ssl

# Configuration
HOST = "0.0.0.0"
PORT = 8765

def log(msg):
    print(f"[SERVER] {msg}", flush=True)

# MCP Protocol Helpers
def mcp_initialize_response(msg_id):
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "result": {
            "protocolVersion": "2024-11-05",
            "serverInfo": {
                "name": "python-filesystem-server",
                "version": "0.1.0"
            },
            "capabilities": {
                "tools": {}
            }
        }
    }

def mcp_tools_list_response(msg_id):
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "result": {
            "tools": [
                {
                    "name": "read_file",
                    "description": "Read a file from the filesystem",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "path": {"type": "string", "description": "Path to file"}
                        },
                        "required": ["path"]
                    }
                }
            ]
        }
    }

def mcp_tool_result(msg_id, content):
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "result": {
            "content": [{"type": "text", "text": json.dumps(content)}]
        }
    }

def handle_read_file(args):
    path = args.get("path", "")
    if not path:
        return {"error": "Missing 'path'"}
    if not os.path.exists(path):
        return {"error": "File does not exist"}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return {"content": f.read()[:1000]}  # Limit to 1000 chars
    except Exception as e:
        return {"error": str(e)}

TOOLS = {"read_file": handle_read_file}

class MCPHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        return  # Silence default logs
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length).decode("utf-8")
        
        try:
            msg = json.loads(raw)
        except:
            log(f"Invalid JSON: {raw[:100]}")
            self.send_response(400)
            self.end_headers()
            return
        
        log(f"Received: {msg.get('method', 'unknown')}")
        
        method = msg.get("method")
        msg_id = msg.get("id")
        
        if method == "initialize":
            resp = mcp_initialize_response(msg_id)
        elif method == "tools/list":
            resp = mcp_tools_list_response(msg_id)
        elif method == "tools/call":
            name = msg["params"]["name"]
            args = msg["params"].get("arguments", {})
            handler = TOOLS.get(name)
            result = handler(args) if handler else {"error": f"Unknown tool: {name}"}
            resp = mcp_tool_result(msg_id, result)
        else:
            resp = {"jsonrpc": "2.0", "id": msg_id, "error": {"code": -32601, "message": "Method not found"}}
        
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(resp).encode("utf-8"))
        log(f"Sent response for {method}")

def run():
    log(f"Starting HTTPS server on {HOST}:{PORT}")
    httpd = HTTPServer((HOST, PORT), MCPHandler)
    
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile="192.168.1.70+2.pem", keyfile="192.168.1.70+2-key.pem")
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        log("Server stopped")

if __name__ == "__main__":
    run()
