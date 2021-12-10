#!/bin/bash

## Your PushBullet Access Token
## Fetch yours from your "Account Settings" Page: https://www.pushbullet.com/#settings/account
## PushBullet API Documentation link: https://docs.pushbullet.com/#api-quick-start
ACCESSTOKEN="${PUSHBULLET_TOKEN}"

## Following bash script function taken from https://gist.github.com/cjus/1047794
## It extracts value for a corresponding key from a JSON response.
function jsonval {
    temp=`echo $json | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w $json_key`
    echo ${temp##*|}
}

## Get the current date and time
DATESTAMP=$(date +"%Y-%m-%d")
TIMESTAMP=$(date +"%H-%M-%S")

## Get the name of the latest AVI clip shot and placed with a folder on your Raspberry Pi's SD card
LATEST=$(ls -tr1 /var/lib/motioneye/Camera2/$DATESTAMP/*.mp4 | tail -1 | sed 's#.*/##')


## The latest AVI might still be open and being written to.
## So if we try to upload the file rightaway, the file size will be reported to be greater than 25 MB
## and PushBullet will reject it. So we will wait for 30 seconds to allow the system to finish writing the file.
## Ideally we should use lsof utility to wait until the file is done writing, but lsof command is not available on Motion Pie.
sleep 15

## Pushing a file is a 3 step process
## Step 1: Send a request for file upload.
##    PushBullet will respond with a URL to which you can upload your file. (upload URL)
##    PushBullet will also respond with a URL at which the file will be available after upload. (File URL)
##   No push message is sent in this step.
##   File is not uploaded in this step.
##   Documentation: https://docs.pushbullet.com/#upload-request
##
## Step 2: Upload the file to the URL which was assigned to you in Step 1
##   Documentation: https://docs.pushbullet.com/#upload
##
## Step 3: A push need to be sent for that file. This push can include a message as well as the File URL generated in Step 1.
##   Documentation:  https://docs.pushbullet.com/#push-a-file
##       https://docs.pushbullet.com/#create-push

## Step 1: Request file upload
json="$(curl \
--header 'Access-Token: '$ACCESSTOKEN \
--header 'Content-Type: application/json' \
--data-binary '{"file_name":"'"$LATEST"'","file_type":"video/mp4"}' \
--request POST \
https://api.pushbullet.com/v2/upload-request)"

## Extract the JSON fields: espesially the Upload URL and File URL
json_key='upload_url'
UPLOAD_URL=`jsonval`
echo $UPLOAD_URL

json_key='file_url'
FILE_URL=`jsonval`
echo $FILE_URL

json_key='file_name'
FILE_NAME=`jsonval`
echo $FILE_NAME

json_key='file_type'
FILE_TYPE=`jsonval`
echo $FILE_TYPE

## Step 2: Upload the file
echo "About to  upload $LATEST to $UPLOAD_URL"
curl -i -X POST $UPLOAD_URL -F file=@/var/lib/motioneye/Camera2/$DATESTAMP/$LATEST
echo "Done uploading. File now available at $FILE_URL"

## Step 3: Send a push message including a link to the file. 
## If the Push is received on a smart phone, the file will be automatically downloaded to it.
echo "Now pushing the file $LATEST to Devices."
echo $LATEST
echo $FILE_URL
curl \
--header 'Access-Token: '$ACCESSTOKEN \
--header 'Content-Type: application/json' \
--data-binary '{"type":"file","body":"Motion detected at '"$DATESTAMP $TIMESTAMP"'","file_name":"'"$FILE_NAME"'","file_type":"'"$FILE_TYPE"'","file_url":"'"$FILE_URL"'"}' \
--request POST \
https://api.pushbullet.com/v2/pushes
