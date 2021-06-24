# MakeMeAnAdmin

Script to elevate priviliges. Also creates a launchd to demote all admins that are not on the line 155. Adjust line 155 based on your needs.
Example
# Skip root user demotion and any user starting with "_"
`for q in ${GRPMembers[@]};do
if [[ $q != "root" ]]&&[[ $q != "_"* ]];then
echo "Delete $q from Admin Group."
/usr/sbin/dseditgroup -o edit -d $q -t user admin
fi`

# Skip root user demotion and any user starting with "_" and ladmin user
for q in ${GRPMembers[@]};do
if [[ $q != "root" ]]&&[[ $q != "_"* ]]&&[[ $q != "ladmin" ]];then
echo "Delete $q from Admin Group."
/usr/sbin/dseditgroup -o edit -d $q -t user admin
fi

# Line 28 The Logo
The logo included here is used with all end user dialog. It is base64 encoded to be included within the script.

Example
Image FileName: /tmp/Icon.png
Text Output File: /tmp/Icon.txt

base64 can be used via Terminal and the output can be sent to a new text file using

`base64 /tmp/Icon.png > /tmp/Icon.txt`
