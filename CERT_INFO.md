# Certificate Information

## Root CA Location (Ubuntu)
Path: `~/.local/share/mkcert/rootCA.pem`
Command to find: `mkcert -CAROOT`

## Windows Installation
Friendly Name: `mkcert-ubuntu-YOUR_SERVER_IP`
Location: certmgr.msc → Trusted Root Certification Authorities → Certificates

## To Remove from Windows
1. Win+R → certmgr.msc
2. Search for: mkcert-ubuntu-YOUR_SERVER_IP
3. Right-click → Delete

## Generated Certs
- Server cert: server.pem
- Server key: server-key.pem
