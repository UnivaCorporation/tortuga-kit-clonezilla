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

#
# Script for resetting a CentOS 6.x installation back to "unconfigured"
#
# With the root filesystem of the node being imaged mounted on /mnt, invoke
# from a Clonezilla shell as follows:
#
#    wget -qO - http://<installer IP>/nodeprep.sh | sh -s /mnt
#

if [ -z "${1}" ]; then
    echo "usage: ${0} <root filesystem>"
    exit 1
fi

if [ ! -d "${1}" ]; then
    echo "Mount point ${1} does not exist. Unable to proceed!"
    exit 1
fi

echo "[INFO] Using filesystem mounted at \"${1}\""

echo "[INFO] Disable SELinux"
cat >$1/etc/sysconfig/selinux <<ENDL
SELINUX=disabled
ENDL

if `grep -q "^HOSTNAME=" $1/etc/sysconfig/network`; then
    sed -e "s/^HOSTNAME=.*/HOSTNAME=localhost.localdomain/" < $1/etc/sysconfig/network >$1/etc/sysconfig/network.new

    if ! `diff $1/etc/sysconfig/network $1/etc/sysconfig/network.new`; then
        echo "[INFO] Setting hostname to \"localhost.localdomain\""
        mv -f $1/etc/sysconfig/network.new $1/etc/sysconfig/network
    else
        rm -f $1/etc/sysconfig/network.new
    fi
else
    echo "[INFO] Adding HOSTNAME entry to /etc/sysconfig/network"

    echo "HOSTNAME=localhost.localdomain" >>$1/etc/sysconfig/network
fi

echo "[INFO] Removing persistent udev rules"

sed -i -e "/^SUBSYSTEM.*/d" -e "/.*PCI device.*/d" $1/etc/udev/rules.d/70-persistent-net.rules

# Reset /etc/hosts
cat >$1/etc/hosts <<ENDL
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
ENDL

# TODO: disable root password
chroot $1 passwd -l root

# Remove ssh host keys
rm -f $1/etc/ssh/ssh_host*

# Remove root ssh keys
rm -f $1/root/.ssh/*

# Cleanup /tmp
rm -f $1/tmp/*

# Cleanup log files
rm -f $1/var/log/tortuga_* $1/var/log/tortuga
:>$1/var/log/messages
rm -f $1/var/log/yum.log
rm -f $1/var/log/dracut.log $1/var/log/anaconda.*
rm -f $1/var/log/boot.log
:>$1/var/log/cron
rm -f $1/var/log/mcollective.log
:>$1/var/log/maillog
rm -f $1/var/log/audit/*
rm -f $1/var/log/dmesg.old
rm -f $1/var/log/dmesg
:>$1/var/log/secure
:>$1/var/log/lastlog
:>$1/var/log/wtmp

# Cleanup YUM cache
rm -rf $1/var/cache/yum/*

mount -o bind /dev $1/dev
chroot $1 sh -c "yum clean all; yum clean metadata"
umount $1/dev

# Restore stock /etc/rc.local
cat >$1/etc/rc.local <<ENDL
#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.

touch /var/lock/subsys/local
ENDL
