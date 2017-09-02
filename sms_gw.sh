# sms_gw.sh
# script to send alert from zabbix over sms gateway on app.gosms.cz
# beranek@icewarp.cz

# vars
channel='164628'
cell_numbers='["+42076610386", "+420733343605"]'
message_test='Hello World'
token="$(curl -X POST "https://app.gosms.cz/oauth/v2/token" -d "client_id=2692_2bgmx65gkhogskw4ck880kwg0k4g8sok4o8o8gk8ww44s8c0c8&client_secret=4ais9mkxuoe80ssk0ossgsko0s8kgggg0wwgcg088s8k4ws4gc&grant_type=client_credentials" | grep access_token | perl -pe 's|{"access_token":"(.*)","expires_in".*|\1|')" || exit 1

# optional: template w/ JSON content that won't change
json_template='{"Content-Type: application/json"}'

# build JSON with content that *can* change with jq
json_data=$(jq --arg message_text="$message_text" \
               --arg cell_nr1="$cell_nr1" \
			   --arg channel="$channel" \
               '.message=$message_text | .recipients=$cell_numbers | .channel=$channel' \
               <<<"$json_template")

# send sms message
curl -X POST "https://app.gosms.cz/api/v1/messages/" \
     -H "Authorization: Bearer ${token}" \
     -d "${json_data}"

exit 0
