# MakeMeAnAdmin

This is a heavily modified version of the Jamf Makemeanadmin script. 

The script is called and receives 4 strings from the Jamf server script parameters. Parameter 4 and 5 are the strings required by the end user. The idea is that a User may need Admin rights, so they will have to contact IT Support to obtain either Parameter 4 for temporary admin rights or parameter 4 and parameter 5 in order to obtain the perminant admin rights, i.e. revert the user to a full admin without a timer applied.

Synopsis
`MakeMeAnAdmin.sh {mount point} {computer name} {username} TemporaryAdminString PerminantAdminString TimeForTemporaryPassword PathToLogo`
or
`sh MakeMeAnAdmin.sh {mount point} {computer name} {username} "1234567890" "1234567890-=" "2" "/Library/Management/Logo.png"

Script to elevate priviliges. Also creates a launchd to demote **all** admins that are not on the line 243. Adjust line 243 based on your needs. Designed to run in Jamf Self Service.

Examples line 243 where specific accounts will be skipped
Skip root user demotion and any user starting with "_"
```for q in ${GRPMembers[@]};do
  if [[ $q != "root" ]]&&[[ $q != "_"* ]];then
    echo "Delete $q from Admin Group."
    /usr/sbin/dseditgroup -o edit -d $q -t user admin
  fi
 done
```

Skip root user demotion and any user starting with "_" and ladmin user
```for q in ${GRPMembers[@]};do
if [[ $q != "root" ]]&&[[ $q != "_"* ]]&&[[ $q != "ladmin" ]];then
echo "Delete $q from Admin Group."
/usr/sbin/dseditgroup -o edit -d $q -t user admin
fi
```

# Line 47 The Logo
The logo included here is used with all end user dialog. It is base64 encoded to be included within the script. You can remove this but you will have to use Parameter 7 for provide an image path.

Example
Image FileName: /tmp/Icon.png
Text Output File: /tmp/Icon.txt

base64 can be used via Terminal and the output can be sent to a new text file using

`base64 /tmp/Icon.png > /tmp/Icon.txt`

This can then be opened and copied to the MakeMeAnAdmin_D8 Script and pasted into parameter "theLogo" on line 28 for hard coded or put a path in for parameter 7.

# Parameters

We assume you are using this script with Jamf, so we assume Parameters 1-3 are predefined.

Parameter 4 - Temporary Password authority string

Parameter 5 - Perminant Password authority string

Parameter 6 - Time to Allow for Temporary admin rights

Parameter 7 - Path to a company graphic


