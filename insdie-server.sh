#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root user or run with sudo"
  exit
fi

apt update && apt install -y curl unzip

systemctl stop v2ray && systemctl disable v2ray
rm -rf /opt/v2ray/ && mkdir /opt/v2ray/
rm -rf /var/log/v2ray/ && mkdir /var/log/v2ray/
rm -rf /etc/systemd/system/v2ray.service

touch /var/log/v2ray/access.log
touch /var/log/v2ray/error.log

curl -L https://github.com/v2fly/v2ray-core/releases/download/v5.1.0/v2ray-linux-64.zip -o v2ray.zip
unzip -d v2ray/ v2ray.zip

## Get an UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
if [ $? -ne 0 ]
  then 
  UUID= $(curl -s "https://www.uuidgenerator.net/api/version4" )
fi

cat <<EOF > v2ray/config.json
{
  "log": {
    "loglevel": "error",
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "allocate": {
        "strategy": "always"
      },
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 1,
            "alterId": 0
          }
        ],
        "disableInsecureEncryption": true
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "connectionReuse": true,
          "path": "/graphql"
        },
        "security": "none",
        "tcpSettings": {
          "header": {
            "type": "http",
            "response": {
              "version": "1.1",
              "status": "200",
              "reason": "OK",
              "headers": {
                "Content-Type": [
                  "application/octet-stream",
                  "application/x-msdownload",
                  "text/html",
                  "application/x-shockwave-flash"
                ],
                "Transfer-Encoding": ["chunked"],
                "Connection": ["keep-alive"],
                "Pragma": "no-cache"
              }
            }
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "$1",
            "port": $2,
            "users": [
              {
                "id": "$3",
                "level": 1,
                "alterId": 0
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "connectionReuse": true,
          "path": "/graphql"
        },
        "security": "none",
        "tcpSettings": {
          "header": {
            "type": "http",
            "response": {
              "version": "1.1",
              "status": "200",
              "reason": "OK",
              "headers": {
                "Content-Type": [
                  "application/octet-stream",
                  "application/x-msdownload",
                  "text/html",
                  "application/x-shockwave-flash"
                ],
                "Transfer-Encoding": ["chunked"],
                "Connection": ["keep-alive"],
                "Pragma": "no-cache"
              }
            }
          }
        }
      }
    }
  ],
  "dns": {
    "servers": [
      "https+local://cloudflare-dns.com/dns-query",
      "4.2.2.4",
      "8.8.8.8",
      "8.8.4.4",
      "localhost"
    ]
  }
}

EOF

cat <<EOF > /etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target
[Service]
User=root
Environment=V2RAY_VMESS_AEAD_FORCED=false
ExecStart=/opt/v2ray/v2ray run -c /opt/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23
[Install]
WantedBy=multi-user.target
EOF

systemctl enable v2ray
systemctl start v2ray

IP=$(curl -s "https://api.ipify.org/" )
VMESS=$(echo "{\"add\":\"$IP\",\"aid\":\"0\",\"alpn\":\"\",\"host\":\"\",\"id\":\"$UUID\",\"net\":\"ws\",\"path\":\"/graphql\",\"port\":\"443\",\"ps\":\"$IP\",\"scy\":\"aes-128-gcm\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64)
VMESS=$(sed "s/\=//g" <<<"$VMESS")
VMESS=$(sed ':a; N; s/[[:space:]]//g; ta' <<<"$VMESS")

cat <<EOF > ./bridge-install.log
  IP: $IP
  PORT: 443
  UUID: $UUID
  Transport: WS
  PATH: /graphql
  Security: aes-128-gcm
  vmess://$VMESS
EOF

cat ./bridge-install.log