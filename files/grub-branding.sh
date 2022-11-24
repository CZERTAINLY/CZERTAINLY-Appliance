#!/bin/bash -x

if ! grep CZERTAINLY /etc/default/grub >/dev/null 2>&1
then
    cp /etc/default/grub /etc/default/grub.dist
    cat /etc/default/grub.dist | sed 's/^GRUB_DISTRIBUTOR=.*$/GRUB_DISTRIBUTOR="CZERTAINLY Appliance"\nGRUB_BACKGROUND=\/boot\/grub\/czertainly.tga/' > /etc/default/grub
    update-grub
    systemctl disable grub-branding.service
    rm -rf /etc/systemd/system/grub-branding.service
fi
