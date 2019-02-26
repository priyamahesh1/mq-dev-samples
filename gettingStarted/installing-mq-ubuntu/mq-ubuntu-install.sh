#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2015, 2019
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Install script for silent install of IBM MQ on Ubuntu
# Requires apt
# We need super user permissions for some steps

# Before we start the install and config, check that the user created the group "mqclient"
getent group mqclient
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "Group mqclient exists. Proceeding with install."
    echo
else
    echo "Group mqclient does not exist!" 
    echo "Please visit TUTORIAL_PAGE_URL to learn how to create the required group."
    exit $returnCode
fi

# Download MQ Advanced from public repo
cd ~/Downloads
#wget -c https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqadv/mqadv_dev911_ubuntu_x86-64.tar.gz
returnCode=$?
if [ $returnCode -eq 0 ]
then 
    echo "Download complete"
    echo
else
    echo "wget failed. See return code: " $returnCode
    exit $returnCode
fi

# Unzip and extract .tar.gz file
gunzip mqadv_dev911_ubuntu_x86-64.tar.gz
echo ".gz extract complete"
echo
tar -xf ./mqadv_dev911_ubuntu_x86-64.tar
returnCode=$?
if [ $returnCode -eq 0 ]
then 
    echo "File extraction complete"
    echo
else
    echo "File extraction failed. See return code: " $returnCode
    exit $returnCode
fi

# Accept the license
cd MQServer
./mqlicense.sh -accept
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "license accepted"
    echo
else
    echo "license not accepted"
    exit $returnCode
fi

# Create a .list file to let the system add the new packages to the apt cache
cd /etc/apt/sources.list.d
echo "deb [trusted=yes] file:/home/$SUDO_USER/Downloads/MQServer ./" > mq-install.list
apt-get update
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "apt cache update succeeded."
    echo
else
    echo "apt cache update failed! See return code: " $returnCode
    exit $returnCode
fi

echo "Beginning MQ install"
apt-get install "ibmmq-*"
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "Install succeeded."
else
    echo "Install failed. See return code: " $returnCode
    exit $returnCode
fi

echo "Checking MQ version"
/opt/mqm/bin/dspmqver
returnCode=$?
if [ $returnCode -ne 0 ]
then
    echo "Error with dspmqver. See return code: " $returnCode
    exit $returnCode
fi

# Delete .list file and run apt update again to clear the apt cache
rm /etc/apt/sources.list.d/mq-install.list
apt-get update
returnCode=$?
if [ $returnCode -ne 0 ]
then
    echo "Could not delete .list file /etc/apt/sources.list.d/mq-install.list."
    echo " See return code: " $returnCode
else
    echo "Successfully removed .list file"
fi

# The group "mqm" is created during the installation. Add the current user to it
adduser $SUDO_USER mqm
echo "Successfully added $SUDO_USER to group mqm"



exec sudo -u $SUDO_USER /bin/bash - << eof
cd /opt/mqm/bin
. setmqenv -s
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "MQ environment set"
else
    echo "MQ environment not set. See return code: " $returnCode
    exit $returnCode
fi

crtmqm QM1 
strmqm QM1
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "Successfully created and started a queue manager" 
else
    echo "Problem when creating and starting a queue manager. See return code: " $returnCode
    exit $returnCode
fi



# Download and run developer config file to create MQ objects
cd ~/Downloads
wget https://raw.githubusercontent.com/ibm-messaging/mq-dev-samples/master/gettingStarted/mqsc/mq-dev-config.mqsc 
returnCode=$?
if [ $returnCode -eq 0 ]
then
    echo "MQSC script successfully downloaded"
else
    echo "MQSC script download failed. See return code: " $returnCode
    exit $returnCode
fi

# Set up MQ environment from .mqsc script
runmqsc QM1 < mq-dev-config.mqsc
returnCode=$?
if [ $returnCode -eq 20 ]
then
    echo "error code $?"
    echo "Error running developer configuration script!"
    exit $returnCode
else
    echo "Developer configuration set up"
fi

# Set up authentication for members of the "mqclient" group
setmqaut -m QM1 -t qmgr -g mqclient +connect +inq
setmqaut -m QM1 -n DEV.** -t queue -g mqclient +put +get +browse +inq
echo 
echo "Now everything is set up with the developer configuration."
echo "For details on environment variables that must be created and" 
echo "a simple put/get test, visit TUTORIAL_PAGE_URL"
echo "ASCII lighthouse may go here"
echo "Thank you for visiting LearnMQ!"
echo

eof
exit 0