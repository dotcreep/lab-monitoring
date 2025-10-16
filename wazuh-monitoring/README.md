# What content
- [x] Installation
- [x] Telegram Alert
- [ ] Email Alert #TODO

# Replace Files
You can replace using file mod from **data** folder after clone the repository.

> Note: this **data** version ***4.11.2***

# Installation
Follow the Docummentaion for Installation and stop reading on change password.
- [Documentation Installation](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html)

Change Password on this area, change for **admin** and **kibanaserver**.
- [Change Password](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html#change-the-password-of-wazuh-users)
```plain
Password Wazuh
RzP9CSoH3uYVMVVrugSdyV4oocemD5vYzxZvbYs2QVPy2XtHwniT9R
$2y$12$36hkc0yUEDd3HFNlYWNwKOKA/QCFUSd5cI3clntmqpj9tXd7ooxf2

Password Kibana
gPeEyQsnecbuobKngQius2NxSj9ozvrDMYcyDFFaUufqbhdfmtDJaz
$2y$12$w853rstUI2ribUQ.8M7gquydVVaqUeyxXIy4EbYaeoA0yHWpUdmoa
```

# Add Alert
1. Create bot
2. Get ChatID (and Thread ID if using Topic Group)
## Telegram
1. Get Chat ID
```shell
curl "https://api.telegram.org/bot<your_bot_token>/getUpdates"
```

2. Search `<!-- Osquery integration -->` on `config/wazuh_cluster/wazuh_manager.conf`
Add this on below of comment
```xml
  <integration>
    <name>custom-telegram</name>
    <level>3</level>
    <hook_url>https://api.telegram.org/bot<your_bot_token>/sendMessage</hook_url>
    <alert_format>json</alert_format>
  </integration>
```

3. Add this line to volume for **wazuh.manager**
```yaml
services:
  wazuh.manager:
    volumes:
      # ...
      - ./custom-telegram:/var/ossec/integrations/custom-telegram
```

4. Create file `custom-telegram`
```shell
#!/bin/bash
if [ $# -lt 3 ]; then
    echo "Usage: $0 <alert_file> <unused_param> <telegram_url>"
    exit 1
fi

ALERT_FILE="$1"
TELEGRAM_URL="$3"
CHAT_ID="<CHAT_ID>"
THREAD_ID=""

if command -v jq >/dev/null 2>&1; then
    DESCRIPTION=$(jq -r '.description' "${ALERT_FILE}")
    LEVEL=$(jq -r '.rule.level' "${ALERT_FILE}")
    AGENT_NAME=$(jq -r '.agent' "${ALERT_FILE}")
    AGENT_IP=$(jq -r '.ip' "${ALERT_FILE}")
    LOG=$(jq -r '.log' "${ALERT_FILE}")
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
else
    DESCRIPTION=$(grep -oP '"description"\s*:\s*"\K[^"]+' "${ALERT_FILE}")
    LEVEL=$(grep -oP '"level"\s*:\s*\K[0-9]+' "${ALERT_FILE}")
    AGENT_NAME=$(grep -oP '"agent"\s*:\s*"\K[^"]+' "${ALERT_FILE}")
    AGENT_IP=$(grep -oP '"ip"\s*:\s*"\K[^"]+' "${ALERT_FILE}")
    LOG=$(grep -oP '"log"\s*:\s*"\K[^"]+' "${ALERT_FILE}")
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
fi

DESCRIPTION=${DESCRIPTION:-"No description"}
LEVEL=${LEVEL:-"N/A"}
AGENT="${AGENT_NAME:-Unknown Agent}"
HOST="${AGENT_IP:-Unknown IP}"
LOG=${LOG:-"No log details"}

MESSAGE="*🚨 Wazuh Alert Report 🚨*
*Time*: \`${TIMESTAMP}\`
*Alert Level*: \`${LEVEL}\`
*Agent*: *${AGENT}* - \`${HOST}\`
*Description*:
_${DESCRIPTION}_

*Log*:
\`\`\`
${LOG}
\`\`\`"

if [ -n "${THREAD_ID}" ]; then
    curl -s -X POST "${TELEGRAM_URL}" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "message_thread_id=${THREAD_ID}" \
        -d "parse_mode=Markdown"
else
    curl -s -X POST "${TELEGRAM_URL}" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=Markdown"
fi

exit 0
```

## Email
Read this Docummentation and still in trial
- [Docummentatoin](https://wazuh.com/blog/how-to-send-email-notifications-with-wazuh/)