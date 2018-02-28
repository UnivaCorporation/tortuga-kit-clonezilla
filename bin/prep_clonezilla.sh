#!/bin/sh

# Copyright 2008-2018 Univa Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ROOTDIR="/mnt"

rm -f "$ROOTDIR/etc/udev/rules.d/70-persistent-net.rules"

# Rewrite rc.local
cat >$ROOTDIR/etc/rc.local <<ENDL
#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.

touch /var/lock/subsys/local
ENDL

# Rewrite the hosts file
cat >$ROOTDIR/etc/hosts <<ENDL
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
ENDL

# Reset the system hostname
sed -i -e 's/^HOSTNAME=.*/HOSTNAME=localhost.localdomain/' \
    $ROOTDIR/etc/sysconfig/network

# Rewrite eth1 configuration
cat >$ROOTDIR/etc/sysconfig/network-scripts/ifcfg-eth0 <<ENDL
DEVICE="eth0"
BOOTPROTO="dhcp"
NM_CONTROLLED="no"
ONBOOT="yes"
TYPE="Ethernet"
ENDL

# Setup timezone/UTC
cat >$ROOTDIR/etc/sysconfig/clock <<ENDL
ZONE="Canada/Eastern"
UTC="true"
ENDL

# This is a bit dodgy, but for my installation it works fine.  Adjust
# accordingly.

sed -i \
    -e '/^#/d' \
    -e '/^$/d' \
    -e 's/^UUID=.* \//\/dev\/vda2 \//' \
    -e 's/^UUID=.* swap/\/dev\/vda1 swap/' $ROOTDIR/etc/fstab

# Disable ntpd/ntpdate
find $ROOTDIR/etc/rc.d -name 'S*ntpd' -o -name 'S*ntpdate' | while read f; do
    rm -f "$f"
done

# YUM cleanup
rm -f $ROOTDIR/yum.repos.d/*.repo
rm -rf $ROOTDIR/var/lib/yum/yumdb/*
rm -rf $ROOTDIR/var/cache/yum/*
rm -rf $ROOTDIR/var/lib/yum/history/*
rm -rf $ROOTDIR/var/lib/yum/repos/*

# Puppet cleanup
rm -rf $ROOTDIR/var/lib/puppet/client_data/catalog/*
rm -rf $ROOTDIR/var/lib/puppet/clientbucket/*
rm -rf $ROOTDIR/etc/puppetlabs/puppet/ssl/*
rm -rf $ROOTDIR/var/lib/puppet/state/*
rm -rf $ROOTDIR/var/lib/puppet/lib/*
rm -f $ROOTDIR/var/lib/puppet/classes.txt

rm -f $ROOTDIR/var/lock/subsys/*
rm -rf $ROOTDIR/var/run/*
find $ROOTDIR/var/log -type f -exec rm -f {} \;
rm -f $ROOTDIR/var/lib/dhclient/*

rm -f $ROOTDIR/var/cache/rpcbind/*

# Tortuga remnants
rm -rf $ROOTDIR/opt/tortuga
rm -f $ROOTDIR/etc/tortuga-release
rm -f $ROOTDIR/etc/profile.d/tortuga.sh

# Remove existing ssh configuration
rm -rf $ROOTDIR/root/.ssh/*
rm -f $ROOTDIR/etc/ssh/*_key $ROOTDIR/etc/ssh/*_key.pub
