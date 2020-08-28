#!/bin/bash
ARGS=$@
SL_USER=`echo "$ARGS" | jq -r '."SL_USER"'`
SL_APIKEY=`echo "$ARGS" | jq -r '."SL_APIKEY"'`
TO=`echo "$ARGS" | jq -r '."TO"'`
FROM=`echo "$ARGS" | jq -r '."FROM"'`
SUBJECT=`echo "$ARGS" | jq -r '."SUBJECT"'`
BODY=`echo "$ARGS" | jq -r '."BODY"'`

BUCKET_NAME=`echo "$ARGS" | jq -r '."bucket"'`
ENDPOINT=`echo "$ARGS" | jq -r '."endpoint"'`
REGION=$(echo $ENDPOINT | cut -d. -f3)

OBJECT_NAME=`echo "$ARGS" | jq -r '."notification"."object_name"'`

EVENT_TYPE=`echo "$ARGS" | jq -r '."notification"."event_type"'`
EVENT_TYPE=$(echo $EVENT_TYPE | cut -d: -f2)

SIZE=`echo "$ARGS" | jq -r '."notification"."object_length"'`

UTC_TIME=`echo "$ARGS" | jq -r '."notification"."request_time"'`
YMD=$(echo $UTC_TIME | cut -dT -f1) && HMS=$(echo $UTC_TIME | cut -dT -f2 | cut -d. -f1)
ISOTIME="${YMD} ${HMS}"
TZ=-9 date -d@"$(( `date -d "$ISOTIME" +%s`))" > /tmp/jst_time.txt
JST_TIME=$(cat /tmp/jst_time.txt)

SUBJECT=$($OBJECT_NAME is $EVENT_TYPE ed on your bucket)
BODY=$(Region: $REGION\\nBucket: $BUCKET_NAME\\nObject: $OBJECT_NAME\\nSize: $SIZE byte\\nOperation: $EVENT_TYPE\\nTime: $JST_TIME)

SENDGRID_ID=`curl -u "$SL_USER:$SL_APIKEY" -X GET 'https://api.softlayer.com/rest/v3.1/SoftLayer_Account/getNetworkMessageDeliveryAccounts.json?objectMask=mask[billingItem]' | jq -r '.[] | select (.billingItem.description=="Free Package") | .id'`

curl -v -i -u "$SL_USER:$SL_APIKEY" \
-X POST \
-H "Content-Type: application/json" \
-d @- "https://api.softlayer.com/rest/v3.1/SoftLayer_Network_Message_Delivery_Email_Sendgrid/$SENDGRID_ID/sendEmail" > /tmp/result.txt << EOS
{"parameters": [{"body":"$BODY","from":"$FROM","to":"$TO","subject":"$SUBJECT"}]}
EOS

if [ $? -ne 0 ]; then
  echo "ERROR" > /tmp/result.txt
  exit 1
fi

RESULT=$(cat /tmp/result.txt)

output=$(cat << EOS
{
  "args": $ARGS,
  "result": $(RESULT="$RESULT" jq -n 'env.RESULT')
}
EOS
)

echo "$output" | jq -c
