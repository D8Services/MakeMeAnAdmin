#!/bin/bash

###############################################
# This script will provide temporary admin    #
# rights to a standard user right from self   #
# service. First it will grab the username of #
# the logged in user, elevate them to admin   #
# and then create a launch daemon that will   #
# count down from 30 minutes and then create  #
# and run a secondary script that will demote #
# the user back to a standard account. The    #
# launch daemon will continue to count down   #
# no matter how often the user logs out or    #
# restarts their computer.                    #
###############################################

#
# Modified from original by Tomos Tyler 2019
# 2.5 - Tomos Tyler 2020, Altered the demotion of the Admin Users from one user to all users.
# 2.6 - Tomos Tyler 2020, Altered the removal of the LaunchD and Script.

#############################################
# find the logged in user and let them know #
#############################################

currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
currentUID=$(dscl . read /Users/$currentUser UniqueID | awk '{print $2}')
if [[ $currentUID == "0" ]];then
	exit 1
fi
echo $currentUser

RunSciptPass1="${4}"
RunSciptPass2="${5}"

MinutestoAllow="${6}"

secondstoAllow=$(expr ${MinutestoAllow} \* 60)
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
plistFile="/Library/LaunchDaemons/com.d8services.removeAdmin.plist"

## ChallengeUser Password ##
## Compare Password with password ##
UserPassLocal1=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e 'display dialog "To approve this action, please type the password provided by your IT Support Agent." default answer "" with hidden answer buttons {"OK"} default button 1 with icon {"/Library/Management/D8.png"}' -e 'return text returned of result')

if [[ "${RunSciptPass1}" == "${UserPassLocal1}" ]];then
	echo "User Typed correct password 1. Continuing."
else
	echo "User Did not type correct password 1. Exiting."
	exit 1
fi
theResult=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e 'display dialog "Do you wish to have permanent Administrative rights on this Mac?" buttons {"No","Yes"} default button 2 with icon {"/Library/Management/D8.png"}' -e 'return button returned of result')

if [[ ${theResult} == "Yes" ]];then
UserPassLocal2=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e 'display dialog "To Have permanent permissions, please type the authoritative password." default answer "" with hidden answer buttons {"OK"} default button 1 with icon {"/Library/Management/D8.png"}' -e 'return text returned of result')
else
	UserPassLocal2=""
fi

if [[ "${RunSciptPass2}" == "${UserPassLocal2}" ]];then
	echo "User Typed correct password 2. skipping LaunchD Timer and removing LaunchD if it exists."
	if [[ -f "${plistFile}" ]];then
		launchctl unload ${plistFile}
		rm -f ${plistFile}
	fi
    if [[ -f "/Library/Management/removeAdminRights.sh" ]]; then
		rm -f "/Library/Management/removeAdminRights.sh"
	fi
	echo "Making $CurrentUser an Admin."
	/usr/sbin/dseditgroup -o edit -a $currentUser -t user admin
	launchctl "asuser" "$currentUID" osascript -e 'display dialog "You now have administrative rights. PLEASE DO NOT ABUSE THIS PRIVILEGE..." buttons {"OK"} default button 1 with icon {"/Library/Management/D8.png"}'
	exit 0	
fi

echo "User Did not type correct password 2. Notifying User of temporary password."
launchctl "asuser" "$currentUID" "$jamfHelper" -title "Process Complete" -windowType utility -description "You will have administrative rights in one minute, this will continue for ${MinutestoAllow} minutes. DO NOT ABUSE THIS PRIVILEGE..." -icon "/Library/Management/D8.png" -button1 "OK" -defaultButton 1

#########################################################
# write a daemon that will let you remove the privilege #
# with another script and chmod/chown to make 			#
# sure it'll run, then load the daemon					#
#########################################################

if [[ -f ${plistFile} ]];then
rm ${plistFile}
fi



#Create the plist
sudo defaults write ${plistFile} Label -string "com.d8services.removeAdmin"

#Add program argument to have it run the update script
sudo defaults write ${plistFile} ProgramArguments -array -string /bin/sh -string "/Library/Management/removeAdminRights.sh"

#Set the run interval to run every xx mins
sudo defaults write ${plistFile} StartInterval -integer ${secondstoAllow}

#Set run at load
sudo defaults write ${plistFile} RunAtLoad -boolean no

#Set ownership
sudo chown root:wheel ${plistFile}
sudo chmod 644 ${plistFile}

#Load the daemon 
launchctl load ${plistFile}
sleep 10

#########################
# make file for removal #
#########################

if [ ! -d /private/var/userToRemove ]; then
	mkdir -p /private/var/userToRemove
	echo $currentUser >> /private/var/userToRemove/user
else
	echo $currentUser >> /private/var/userToRemove/user
fi

##################################
# give the user admin privileges #
##################################

/usr/sbin/dseditgroup -o edit -a $currentUser -t user admin

########################################
# write a script for the launch daemon #
# to run to demote the user back and   #
# then pull logs of what the user did. #
########################################

cat << 'EOF' > /Library/Management/removeAdminRights.sh
#!/bin/sh
if [[ -f /private/var/userToRemove/user ]]; then
userToRemove=$(cat /private/var/userToRemove/user)
echo "Removing $userToRemove's admin privileges"
/usr/sbin/dseditgroup -o edit -d $userToRemove -t user admin
rm -f /private/var/userToRemove/user
GRPMembers=$(dscl . read /Groups/admin GroupMembership | awk -F ": " '{print $NF}')
saveIFS=$IFS
IFS=$' '
for q in ${GRPMembers[@]};do
if [[ $q != "root" ]]||[[ $q != "_"* ]]||[[ $q != "ladmin" ]];then
echo "Delete $q from Admin Group."
/usr/sbin/dseditgroup -o edit -d $q -t user admin
fi
done
log collect --last 30m --output /private/var/userToRemove/$userToRemove.logarchive
fi
defaults write /Library/LaunchDaemons/com.d8services.removeAdmin.plist Disabled -bool true
launchctl list | grep com.d8services.removeAdmin
if [[ $? = 0 ]];then
launchctl disable /Library/LaunchDaemons/com.d8services.removeAdmin.plist
fi
rm /Library/LaunchDaemons/com.d8services.removeAdmin.plist;rm "$0"
EOF
exit 0
