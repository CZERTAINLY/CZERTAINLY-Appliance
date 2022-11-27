# CZERTAINLY Appliance Builder

Builder of [CZERTAINLY Appliance](https://docs.czertainly.com/docs/installation-guide/deployment/deployment-appliance/overview). 

## Prerequisites

* a Linux system / - tested on GNU Debian/Linux 11 (Bullseye). In case of VPS you need suport for nested virtualization.
* `git` for cloning this repo
* VirtualBox 6.1 from [Debian Fast Track](https://fasttrack.debian.net/) is fine and 7.0 from Oracle is also tested
* Ansible 2.10
* `libarchive-tools` is required for bsdtar which capable for extracting ISO image
* `genisoimage` is needed for reasembling netinstall image after altering it
* `isohybrid` is needed for booting ISO image like from HDD

In short:
`apt install git virtualbox virtualbox-ext-pack ansible libarchive-tools genisoimage syslinux-utils`

## Usage

```
git clone https://github.com/semik/CZERTAINLY-Appliance.git
cd CZERTAINLY-Appliance
./build-appliance.sh
```

Finished apliance is exported into file `tmp/czertainly-appliance-$APPLIANCEVERSION."%g%m%d.%H%M%S.ova`. The proces takes about 7 minutes on i7-6700 CPU @ 3.40GHz.

## Tested compatibility

* VMPlayer 16.2.4 / TODO doplnit že je nutný odkliknout nějaký retry

## Notes

For cleaning working directory you can use `rm -rf tmp` or if you are on slow line maybe you would like more [specific command](https://github.com/semik/CZERTAINLY-Appliance/blob/main/build-appliance.sh#L5) which keeps offical Debian ISO image in place to save bandwith

Debian installation process can be automated by [preseed.cfg file](https://github.com/semik/CZERTAINLY-Appliance/blob/main/files/preseed.cfg) which is [documented](https://www.debian.org/releases/stable/amd64/apbs02.en.html). Or you can run [network install from minimal ISO](https://www.debian.org/CD/netinst/) and inside of newly installed image run `debconf-get-selections --installer`. And final tip is to try unantend install using VirtualBox, and examine storage of virtual servers, preseed and other needed configs are available there.

TODO nějak zdokumentovat proces bootu virtuálu instalátoru.

`



