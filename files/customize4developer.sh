#!/bin/bash

set -e

if [ ! -d /root/.ssh ]
then
  echo "copying .ssh to /root"
  cp -r /home/czertainly/.ssh /root/
  chown -R root.root /root/.ssh
fi

cd /etc/ansible/roles
find -type f | grep \.git/config$ | while read CFG
do
  if grep https://github.com $CFG >/dev/null
  then
    echo "upgrading $CFG";
    cp $CFG $CFG.bak
    cat $CFG.bak | sed "s,https://github.com/,git@github.com:," > $CFG
  fi
done
