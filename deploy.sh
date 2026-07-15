#!/bin/bash

# Ensure all required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <pi_user> <pi_ip> <pi_path> <ha_token>"
    echo "Example: $0 user_pi 192.168.1.50 /opt/docker/homeassistant/config/ abc123yourtokenhere..."
    exit 1
fi

# Assigning parameters to variables
PI_USER="$1"
PI_IP="$2"
PI_PATH="$3"
HA_TOKEN="$4"

LOCAL_PATH="./"
HA_URL="http://${PI_IP}:8123"

echo "==== 1. Synchronizing files to Raspberry Pi ===="
# rsync packages as only YAMLs there are immediately consumable by HA
rsync -avz --delete \
  --include='packages/' \
  --include='packages/***' \
  --exclude='*' \
  "$LOCAL_PATH" "$PI_USER@$PI_IP:$PI_PATH"

if [ $? -ne 0 ]; then
    echo "Error during rsync! Deployment stopped."
    exit 1
fi

echo -e "\n==== 2. Validating Home Assistant configuration ===="
# Requesting configuration check via HA REST API
VALIDATION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  "$HA_URL/api/config/core/check_config")

# Parsing the response. If the configuration is valid, HA returns JSON with "result": "valid"
IS_VALID=$(echo "$VALIDATION_RESPONSE" | grep -o '"result":\s*"valid"')

if [ -n "$IS_VALID" ]; then
    echo "[SUCCESS] Configuration is valid!"
else
    echo "[ERROR] YAML configuration error detected!"
    echo "Server response:"
    echo "$VALIDATION_RESPONSE" | grep -o '"errors":\s*"[^"]*"' || echo "$VALIDATION_RESPONSE"
    exit 1
fi

echo -e "\n==== 3. Reloading HA components ===="

# Helper function to trigger reload of specific HA domains
reload_service() {
    local service=$1
    echo -n "Reloading $service..."
    curl -s -o /dev/null -w "%{http_code}\n" -X POST \
      -H "Authorization: Bearer $HA_TOKEN" \
      -H "Content-Type: application/json" \
      "$HA_URL/api/services/homeassistant/$service"
}

# Reload core and key configuration-based domains
reload_service "reload_all" # All configurations

echo -e "\n[SUCCESS] Deployment completed successfully, new configurations applied!"
