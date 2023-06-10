#!/bin/bash

mode=$1
room=$2
room_name=$3

printf " > Fetching top tracks of the month...\n"

map_response=$(curl -sS "https://trackmania.exchange/mapsearch2/search?api=on&mode=$mode&limit=30&priord=8&length=5&lengthop=1")
if [[ $? -eq 0 ]]; then
    map_IDs=$(echo "$map_response" | jq -r '.results | map(select(.SizeWarning == false)) | limit(25;.[]) | .TrackUID')
else
    printf "Request failed\n"
fi

maps_string=$(echo "$map_IDs" | sed 's/.*/"&"/' | tr '\n' ',')
printf "Maps: $maps_string\n"

printf " > Authenticating to Trackmania API...\n"

# Get access token for Trackmania Live Services API
ticket_response=$(curl -sS -X POST -u "$TRACKMANIA_API_USERNAME:$TRACKMANIA_API_PASSWORD" -H "Content-Type: application/json" -H "Ubi-AppId: 86263886-327a-4328-ac69-527f0d20a237" -A "Daily top TM trackers updater / https://github.com/anthonynd/daily-top-TM-tracks-updater" -d '{"audience":"NadeoLiveServices"}' "https://public-ubiservices.ubi.com/v3/profiles/sessions")

printf "Ticket response: $ticket_response\n"

if [[ $? -eq 0 ]]; then
    ticket=$(echo "$ticket_response" | jq -r '.ticket')
    if [ -z "$ticket" ]; then
        printf "Failed to retrieve ticket\n"
        printf "Ticket response: $ticket_response\n"
        exit 1
    fi
else
    # Request failed
    printf "Request failed\n"
fi

token_response=$(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: ubi_v1 t=$ticket" -d '{"audience":"NadeoLiveServices"}' "https://prod.trackmania.core.nadeo.online/v2/authentication/token/ubiservices")

printf "Token response: $token_response\n"

if [[ $? -eq 0 ]]; then
    token=$(echo "$token_response" | jq -r '.accessToken')
    if [ -z "$token" ]; then
        printf "Failed to retrieve token\n"
        printf "Token response: $token_response\n"
        exit 1
    fi
else
    # Request failed
    printf "Request failed\n"
fi

data='{
    "name":"'${room_name}'",
    "region":"ca-central",
    "maxPlayersPerServer":100,
    "script":"TrackMania/TM_TimeAttack_Online.Script.txt",
    "settings":[
        {"key":"S_TimeLimit","value":"300","type":"integer"},
        {"key":"S_ForceLapsNb","value":"-1","type":"integer"},
        {"key":"S_DecoImageUrl_WhoAmIUrl","value":"/api/club/61598","type":"text"}
    ],
    "maps":['"${maps_string%?}"'],
    "scalable":1,
    "password":0
}'

printf " > Updating tracks in room...\n"

club_response=$(curl -sS -X POST -H "Authorization: nadeo_v1 t=$token" -d "$data" "https://live-services.trackmania.nadeo.live/api/token/club/61598/room/$room/edit")
if [[ $? -eq 0 ]]; then
    printf "Club response: $club_response\n"
else
    printf "Request failed\n"
fi

