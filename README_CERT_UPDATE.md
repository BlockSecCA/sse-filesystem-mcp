# Certificate Configuration Update

## The Proper Way (What Actually Works)

### Problem
Installing mkcert's root CA in Windows Certificate Store does NOT make Node.js trust it. Node.js has its own certificate validation and doesn't use the Windows certificate store.

### Solution
Use `NODE_EXTRA_CA_CERTS` environment variable to point Node.js to your root CA file.

## Step-by-Step Certificate Setup

### 1. On Ubuntu: Generate Certificates

```bash
cd ~/code/sse-filesystem-mcp
mkcert -install
mkcert 192.168.1.70 localhost 127.0.0.1

# Find where the root CA is stored
mkcert -CAROOT
# Output: /home/carlos/.local/share/mkcert
```

### 2. Copy Root CA to Windows

Copy the `rootCA.pem` file from Ubuntu to a permanent location on Windows:

**Recommended location:** `C:\certs\mkcert-rootCA.pem`

Methods to copy:
- Via network share: `\\192.168.1.70\home\carlos\.local\share\mkcert\rootCA.pem`
- Via USB drive
- Via SCP/SFTP

```powershell
# Example using network share (if enabled)
# Create directory
New-Item -ItemType Directory -Force -Path C:\certs

# Copy the file
Copy-Item "\\192.168.1.70\home\carlos\.local\share\mkcert\rootCA.pem" "C:\certs\mkcert-rootCA.pem"
```

### 3. Configure Claude Desktop

Edit: `%APPDATA%\Claude\claude_desktop_config.json`

**Full path:** `C:\Users\YourUsername\AppData\Roaming\Claude\claude_desktop_config.json`

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

**Important notes:**
- Use double backslashes `\\` in Windows paths
- Point to the `rootCA.pem` file (not the server certificate)
- This enables proper certificate validation (no bypassing)

### 4. Restart Claude Desktop

Completely quit and restart Claude Desktop for changes to take effect.

## Verification

Check the logs at `%APPDATA%\Claude\logs\mcp-server-PythonFS.log`

**Success looks like:**
```
Connected to remote server using StreamableHTTPClientTransport
Proxy established successfully between local STDIO and remote StreamableHTTPClientTransport
```

**Failure (certificate error) looks like:**
```
Error: unable to verify the first certificate
code: 'UNABLE_TO_VERIFY_LEAF_SIGNATURE'
```

## Why This Matters

### The Wrong Way (Insecure)
```json
"env": {
  "NODE_TLS_REJECT_UNAUTHORIZED": "0"
}
```
- ❌ Disables ALL certificate validation
- ❌ Vulnerable to man-in-the-middle attacks
- ❌ Will accept ANY certificate (even from wrong servers)
- ⚠️ Only acceptable for quick testing

### The Right Way (Secure)
```json
"env": {
  "NODE_EXTRA_CA_CERTS": "C:\\certs\\mkcert-rootCA.pem"
}
```
- ✅ Validates certificate properly
- ✅ Only trusts your specific CA
- ✅ Protects against man-in-the-middle attacks
- ✅ Production-grade security for local network

## Understanding the Certificate Chain

```
Windows Certificate Store
  └─ (NOT USED BY NODE.JS!)

Node.js Certificate Validation
  ├─ Built-in CA bundle (public CAs like Let's Encrypt, DigiCert, etc.)
  └─ NODE_EXTRA_CA_CERTS → Your custom CA (mkcert root)
       └─ Validates: 192.168.1.70+2.pem (your server cert)
```

**Key insight:** Windows trusting a cert ≠ Node.js trusting a cert

They are completely separate trust stores!

## Common Issues

### Issue: "unable to verify the first certificate"
**Cause:** Node.js doesn't trust your root CA

**Solution:** 
1. Verify `NODE_EXTRA_CA_CERTS` path is correct
2. Check file exists: `Test-Path C:\certs\mkcert-rootCA.pem`
3. Use double backslashes in JSON: `C:\\certs\\...`

### Issue: Still works after removing NODE_EXTRA_CA_CERTS
**Cause:** `NODE_TLS_REJECT_UNAUTHORIZED=0` is still set

**Solution:** Remove the env section entirely or only have `NODE_EXTRA_CA_CERTS`

### Issue: Certificate not found
**Cause:** Incorrect path or missing file

**Solution:**
```powershell
# Verify file exists
Test-Path C:\certs\mkcert-rootCA.pem

# View certificate details
Get-Content C:\certs\mkcert-rootCA.pem
```

## Optional: Installing in Windows Certificate Store

You CAN still install the root CA in Windows Certificate Store (it won't hurt), but it's not required for Claude Desktop MCP connections.

**When it DOES help:**
- Accessing `https://192.168.1.70:8765` in web browsers
- Other Windows applications that DO use the Windows certificate store
- PowerShell's `Invoke-WebRequest` commands

**To install in Windows:**
1. Right-click `rootCA.pem` → Install Certificate
2. Store Location: **Local Machine** (requires admin)
3. Place in: **Trusted Root Certification Authorities**
4. Set Friendly Name: `mkcert-ubuntu-192.168.1.70`

## For Corporate Environments (Behind Zscaler, etc.)

If you're behind a corporate proxy that intercepts HTTPS:

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
        "NODE_EXTRA_CA_CERTS": "C:\\certs\\zscaler-root.pem;C:\\certs\\mkcert-rootCA.pem",
        "HTTPS_PROXY": "http://proxy.company.com:8080"
      }
    }
  }
}
```

Note: Use semicolon `;` to separate multiple CA files on Windows

## Summary

**What you need:**
1. Generate certs with mkcert on Ubuntu ✅
2. Copy `rootCA.pem` to Windows ✅
3. Set `NODE_EXTRA_CA_CERTS` in Claude config ✅
4. Restart Claude Desktop ✅

**What you DON'T need:**
- ❌ Installing cert in Windows Certificate Store (optional but not required)
- ❌ `NODE_TLS_REJECT_UNAUTHORIZED=0` (insecure bypass)
- ❌ Modifying Node.js installation

**Result:** Proper TLS with certificate validation! 🎉
