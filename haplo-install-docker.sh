#!/bin/bash

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2019    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#
# This script installs the entire haplo stack, along with any necessary
# packages and system configuration
#
# If an argument is supplied, it will be interpreted as a hostname or URL
# and used to configure an initial application if one has not already been
# configured.
#

#
# The following assumptions are made:
#
# that we're running Ubuntu 16.04LTS or later
# that the system architecture is 64-bit
# that the system is dedicated to Haplo
# that the current user can use sudo to manage the system
# that we install to /haplo (persistent data) and /opt/haplo (code)
#
cd $HOME

echo ""
echo "  *** Welcome to the Haplo Docker installation script ***"
echo ""
echo " This script will set up Haplo for Docker use."
echo ""

# Using PostgreSQL 12 for Ubuntu 20.04
PG_VERSION=12
XAPIAN_PKG=libxapian30
OPENJDK_PKG=openjdk-8-jdk

#
# java needs the cacerts file populating correctly
#
echo " *** Haplo updating system CA certificate store ***"
sudo update-ca-certificates -f
echo " *** Haplo system CA certificate store updated ***"

#
# no longer need to configure maven
#
mkdir -p ${HOME}/.m2

#
# now download haplo if we haven't already
#
if [ ! -f haplo/fetch-and-compile.sh ]; then
    echo " *** Haplo cloning from github ***"
    # Using HTTPS URL to avoid SSH key issues in container
    git clone https://github.com/gigabyte-software/haplo.git
    cd haplo
    git checkout ek  # Using the specific branch
    cd ..
    echo " *** Haplo github clone done ***"
fi
#
# run the haplo build script, which will download all the components it
# needs, patch some known problems, and build our software
#
if [ -f haplo/fetch-and-compile.sh ]; then
    cd haplo
    echo " *** Building Haplo ***"
    ./fetch-and-compile.sh -n
    echo " *** Haplo build done ***"
else
    echo "ERROR: unable to find haplo"
    exit 1
fi

#
# create users
#  postgres should already exist from the postgres install
#  haplo is the user we use to run the application in production
#
echo " *** Haplo setting up accounts ***"
if grep -q '^postgres:' /etc/group
then
    echo "postgres group already exists"
else
    sudo groupadd postgres
fi
if grep -q '^postgres:' /etc/passwd
then
    echo "postgres account already exists"
else
    sudo useradd -s /bin/bash -g postgres -d /var/lib/postgresql -c "PostgreSQL administrator" postgres
fi
if grep -q '^haplo:' /etc/group
then
    echo "haplo group already exists"
else
    sudo groupadd haplo
fi
if grep -q '^haplo:' /etc/passwd
then
    echo "haplo account already exists"
else
    sudo useradd -s /bin/bash -g haplo -d /haplo -c "Haplo server" haplo
fi
#
# postgres needs to be in the haplo group so it can read the xapian files
#
sudo usermod -a -G haplo postgres
#
# and create all the locations we use
# data will be under /haplo (persistent)
# postgres database is under /haplo/database
# code will be under /opt/haplo (replaced on updates)
#
if [ ! -d /haplo ]; then
    sudo mkdir /haplo
    sudo chown haplo:haplo /haplo
fi
for subdir in log tmp run generated-downloads files textweighting plugins messages messages/app_create messages/app_modify messages/spool sslcerts
do
    if [ ! -d /haplo/$subdir ]; then
	sudo mkdir /haplo/$subdir
	sudo chown haplo:haplo /haplo/$subdir
    fi
done
if [ ! -d /haplo/textidx ]; then
    sudo mkdir /haplo/textidx
    sudo chown postgres:postgres /haplo/textidx
fi
if [ ! -d /opt/haplo ]; then
    sudo mkdir /opt/haplo
    sudo chown haplo:haplo /opt/haplo
fi
echo " *** Haplo account setup done ***"

#
# generate a deployable tarball
# to deploy this, you need to
#  cd /opt/haplo ; tar xf /tmp/haplo-build.tar
#
echo " *** Generating deployable archive ***"
./deploy/release
echo " *** Deployable archive generated ***"

#
# copy platform-prompt to somewhere likely to be in the default PATH
#
sudo cp script/platform-prompt /usr/bin

#
# iff the target code area is empty, for example if this is the first
# time this script has been run, unpack the tarball in the right place
#
if [ ! -d /opt/haplo/app ]; then
    echo " *** Deploying build to /opt/haplo ***"
    sudo su haplo -c 'cd /opt/haplo ; tar xf /tmp/haplo-build.tar'
    echo " *** Build deployed to /opt/haplo ***"
fi

#
# we use the normal postgres service for production use
#  redirect the location of the data to /haplo/database
#  use the /haplo/database/pg_hba.conf file for access conrol
#
# NOTE: For Docker we don't modify the PostgreSQL data location as we're using
# the development database configuration
#

#
# Certificate generation happens in the Dockerfile, so it's skipped here
#
echo " *** Haplo setup complete for Docker ***" 