#!/bin/bash


###############################################################
#	Copyright (c) 2020, D8 Services Ltd.  All rights reserved.  
#											
#	
#	THIS SOFTWARE IS PROVIDED BY D8 SERVICES LTD. "AS IS" AND ANY
#	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#	DISCLAIMED. IN NO EVENT SHALL D8 SERVICES LTD. BE LIABLE FOR ANY
#	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
###############################################################

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

##############################################
# find the logged in user and challenge them #
##############################################

# Modified by Tomos Tyler 13/Aug/2020

currentUser=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
currentUID=$(dscl . read /Users/$currentUser UniqueID | awk '{print $2}')
if [[ $currentUID == "0" ]];then
	exit 1
fi
echo $currentUser

RunSciptPass1="${4}"

## ChallengeUser Password ##
## Compare Password with password ##


UserPassLocal1=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e 'display dialog "To approve this action, please type the password provided by your Workplace IT Service Desk." default answer "" with hidden answer buttons {"OK"} default button 1' -e 'return text returned of result')
isDone="0"
while [[ $isDone == "0" ]];do
	if [[ "${RunSciptPass1}" == "${UserPassLocal1}" ]];then
		echo "User Typed correct password 1. Continuing."
		isDone="1"
	else
		theResult=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e 'display dialog "You have entered an incorrect password, do you want to try again?" buttons {"No","Yes"} default button 2' -e 'return button returned of result')
		if [[ ${theResult} == "Yes" ]];then
			UserPassLocal1=$(launchctl "asuser" "$currentUID" /usr/bin/osascript -e 'display dialog "To approve this action, please type the password provided by your Workplace IT Service Desk." default answer "" with hidden answer buttons {"OK"} default button 1' -e 'return text returned of result')

		else
			echo "User decided not to proceed. Exiting."
			isDone="1"
			exit 1
		fi
	fi
done



#osascript -e 'display dialog "You now have administrative rights for 30 minutes. DO NOT ABUSE THIS PRIVILEGE..." buttons {"Make me an admin, please"} default button 1'
launchctl "asuser" "$currentUID" osascript -e 'display dialog "You now have administrative rights for 30 minutes. PLEASE DO NOT ABUSE THIS PRIVILEGE..." buttons {"OK"} default button 1'

#########################################################
# write a daemon that will let you remove the privilege #
# with another script and chmod/chown to make 			#
# sure it'll run, then load the daemon					#
#########################################################

#Create the plist
defaults write /Library/LaunchDaemons/removeAdmin.plist Label -string "removeAdmin"

#Add program argument to have it run the update script
defaults write /Library/LaunchDaemons/removeAdmin.plist ProgramArguments -array -string /bin/sh -string "/Library/Application Support/JAMF/removeAdminRights.sh"

#Set the run inverval to run every 30 mins
defaults write /Library/LaunchDaemons/removeAdmin.plist StartInterval -integer 1800

#Set run at load
defaults write /Library/LaunchDaemons/removeAdmin.plist RunAtLoad -boolean no

#Set ownership
chown root:wheel /Library/LaunchDaemons/removeAdmin.plist
chmod 644 /Library/LaunchDaemons/removeAdmin.plist

#Load the daemon 
launchctl load /Library/LaunchDaemons/removeAdmin.plist
sleep 10

#########################
# make file for removal #
#########################

if [ ! -d /private/var/userToRemove ]; then
	mkdir /private/var/userToRemove
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

if [[ -f "/Library/Application Support/JAMF/removeAdminRights.sh" ]];then
rm "/Library/Application Support/JAMF/removeAdminRights.sh"
fi

cat << 'EOF' > /Library/Application\ Support/JAMF/removeAdminRights.sh
if [[ -f /private/var/userToRemove/user ]]; then
userToRemove=$(cat /private/var/userToRemove/user)
rm -f /private/var/userToRemove/user
launchctl disable /Library/LaunchDaemons/removeAdmin.plist
rm /Library/LaunchDaemons/removeAdmin.plist
GRPMembers=$(dscl . read /Groups/admin GroupMembership | awk -F ": " '{print $NF}')
saveIFS=$IFS
IFS=$' '
for q in ${GRPMembers[@]};do
if [[ $q != "root" ]]&&[[ $q != "_"* ]]&&[[ $q != "isslocala" ]];then
echo "Delete $q from Admin Group."
/usr/sbin/dseditgroup -o edit -d $q -t user admin
fi
done
log collect --last 30m --output /private/var/userToRemove/$userToRemove.logarchive

launchctl list | grep removeAdmin
if [[ $? = "0" ]];then
PIDKill=$(launchctl list | grep removeAdmin | awk '{print $1}')
kill $PIDKill
fi
fi
EOF

exit 0