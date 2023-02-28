#!/bin/bash

fqdn_hostname=$1

if [ "$fqdn_hostname" != "" ]
then
    hostname=`echo "$fqdn_hostname" | sed "s/\..*$//"`

    logger "$fqdn_hostname $hostname"

    echo "127.0.0.1	localhost
127.0.1.1	$fqdn_hostname	$hostname

# The following lines are desirable for IPv6 capable hosts
::1	localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters" > /etc/hosts

    echo "$hostname" > /etc/hostname

    invoke-rc.d hostname.sh start
fi
