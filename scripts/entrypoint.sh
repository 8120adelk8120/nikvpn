#!/bin/bash
set -e

echo "====================================="
echo "NikVPN Codespace - Xray xHTTP Setup"
echo "====================================="

# Install dependencies
sudo apt-get update
sudo apt-get install -y wget unzip tmux curl

# Download latest Xray core
echo "Downloading Xray core..."
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
sudo unzip -q -d /usr/local/bin /tmp/xray.zip
sudo chmod +x /usr/local/bin/xray

# Generate random UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "Generated UUID: $UUID"

# Create config directory
sudo mkdir -p /usr/local/etc/xray

# Create Xray config.json with VLESS + xHTTP + TLS (no flow, mode packet-up)
sudo tee /usr/local/etc/xray/config.json > /dev/null <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "github.com",
          "allowInsecure": false
        },
        "xhttpSettings": {
          "path": "/",
          "mode": "packet-up"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": ["geosite:category-ads-all"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

# Save UUID for later
echo "$UUID" > /home/vscode/uuid.txt

# Start Xray in tmux session
tmux new-session -d -s nikvpn 'sudo /usr/local/bin/xray run -c /usr/local/etc/xray/config.json'

# Get workspace directory
WORKSPACE_DIR=$(pwd)

# Start keepalive script
bash "$WORKSPACE_DIR/scripts/keepalive.sh" &

# Show connection link
bash "$WORKSPACE_DIR/scripts/show-link.sh"

echo "Setup complete. Xray (xHTTP) is running on port 443"
echo "To stop Xray: tmux kill-session -t nikvpn"
