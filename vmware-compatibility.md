# Creating Virtual Appliance compatible with VMWare

The appliance is created by deb-bootstrapping into QUEMu locally mounted drive. This is a pretty fast way to create a new virtual machine from scratch. This way ensures software integrity as deb-bootstrap validates Debian's signatures. And it is also able to run as GitHub Action on an Ubuntu host without VT-x support.

Next, we are using Oracle's VirtualBox to create an OVA file with the appliance. This task involves:

  * define parameters of the virtual machine, like drive size, amount of memory and other virtual hardware
  * convert QUEMu QCOW2 disk format into
  * exporting appliance into OVA format

## OVA format

OVA format is just a TAR file containing `ovf` file (XML description of virtual hardware), `mf` file (check sums) and `vmdk` file with "hardrive" of the appliance.

## Compatibility with VMWare Player (16, 17), Workstation Pro (17), Fusion

By default, virtual machines exported from VirtualBox have issues with compatibility with all products mentioned above. To import it, you need to press "Retry" on to relax ovf compatibility. Or replace value `virtualbox-2.2` in element `/Envelope/VirtualSystem/VirtualHardwareSection` from to `vmx-13` (that means [compatible with ESXi 6.5](https://kb.vmware.com/s/article/1003746) and above).

There is an [open ticket #7982 on VirtualBox](https://www.virtualbox.org/ticket/7982). Somebody opened it 12 years ago. **12 years ago!**

## Compatibility with VMWare ESXi 7 / 8

According to my experiments, ESXi doesn't care about checksum files. I'm not sure if it checks the validity of the ovf file at all.

## Compatiblity with VMWare vSphere Console 7

After editing `ovf` file to not contain `virtualbox-2.2` string, all captioned products are satisfied. Even `ovftool` is happy. But not [**vSphere Console**](files/vspher-client-err.png)! 🤯


The first attempt was to remove element `<Parent>3</Parent>` that made happy vSphere Console but unhappy VirtualBox. 😤


Later, after importing `OVA` into Workstation and exporting it out. I got the idea that the problem is maybe related to SATE Controller, not to Drive. All needed changes are well visited at [diff on `example.ovf` file](https://github.com/semik/CZERTAINLY-Appliance/commit/55759e7ffb02863bee785db8e27c92184686a662). If anyone is reading this and is interested in working code, you can take [`fix4vmware.pl`](files/fix4vmware.pl).

# Better way

There must be a better way to create Virtual Appliances compatible with VMware. Please, if you know it [let me know](https://github.com/semik).

Conditions:
* verified integrity of Debian software (i.e. pre-baked image from elsewhere is not permitted)
* ability to run inside Ubuntu GitHub Action Runner - the one without VT-x support
  * this takes out installation using preseed.cfg and VirtualBox
  * above apply also for [Packer](https://github.com/semik/CZERTAINLY-Appliance/commit/55759e7ffb02863bee785db8e27c92184686a662) from HashiCorp it uses virtualization and preseed.cfg instalation prescription
* to use free software if possible

Note: [I also tried Vagrant](https://github.com/semik/vagrant-github-action-test) by Hashicorp, but it needs VT-x capable runner and produces box which isn't compatible with VMWare. :(