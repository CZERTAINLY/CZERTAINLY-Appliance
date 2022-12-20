#!/bin/bash

set -e

# chown -R semik tmp/iso/ ; chmod -R +w tmp/iso/ ; rm -rf tmp/*.iso ; rm tmp/*.ova

echo ">> CREATING ISO IMAGE <<"
ansible-playbook -i inventory.conf build-iso-image.yaml

echo ""
echo ">> CREATING VBOX MACHINE <<"
echo ""
VERSION=`cat tmp/iso/3KeyCompany/czertainly_appliance_version`
NAME="czertainly-appliance-$VERSION".`date "+%g%m%d.%H%M%S"`
ISO='tmp/czertainly-appliance-netinstall-1.0.iso'
MAX_INST_TIME=$[360*60]
MAX_1ST_TIME=120

VBoxManage createvm --name $NAME --ostype Debian_64 --register

VBoxManage modifyvm $NAME --ioapic on --acpi on
VBoxManage modifyvm $NAME --memory 8192 --cpus 4 --pae=off
VBoxManage modifyvm $NAME --audio=pulse --audiocodec=ad1980 --audioout=on
VBoxManage modifyvm $NAME --graphicscontroller vmsvga --vram 16
VBoxManage modifyvm $NAME --nic1 bridged --bridgeadapter1=eth0
VBoxManage modifyvm $NAME --mouse=usbtablet --usbehci=on --usbohci=on
VBoxManage modifyvm $NAME --rtcuseutc=on

STORAGE=`VBoxManage showvminfo $NAME | grep 'Config file' | sed 's/Config file: *//' | sed 's/[^/]*$//'`

VBoxManage createhd --filename "${STORAGE}disk.vdi" --size 20000 --format VDI
VBoxManage storagectl $NAME --name "IDE" --add ide --controller PIIX4 --portcount=2
VBoxManage storageattach $NAME  --storagectl "IDE" --port 1 --device 0 --type dvddrive --medium  $ISO
VBoxManage storagectl $NAME --name "SATA" --add sata --controller IntelAhci --portcount=1
VBoxManage storageattach $NAME  --storagectl "SATA" --port 0 --device 0 --type hdd --medium  "${STORAGE}disk.vdi"
VBoxManage modifyvm $NAME --boot1 dvd --boot2 disk --boot3 none --boot4 none

echo ""
echo ">> STARTING VBOX MACHINE AUTO INSTALL <<"
echo ""

VBoxManage startvm $NAME --type=headless
echo ""

INST_START=`date +'%s'`
while VBoxManage list runningvms | grep "$NAME" >/dev/null 2>&1
do
    NOW=`date +'%s'`;
    DIFF=$[$NOW-$INST_START];
    if [ $DIFF -gt $MAX_INST_TIME ]
    then
	printf "$NAME install is running for $DIFF sec, that is too long. Check if it isn't stuck.\r"
	sleep 5
    else
	printf "$NAME install is running for $DIFF sec of $MAX_INST_TIME\r"
	sleep 5
    fi
done
echo "";

NOW=`date +'%s'`;
INST_RUNTIME=$[$NOW-$INST_START];
echo ">> AUTO INSTALL FINISHED IN $INST_RUNTIME sec";

echo ""
echo ">> EXPORTING VBOX TO OVA <<"
echo ""

VBoxManage export $NAME --output tmp/$NAME.ova --ovf10 --manifest
