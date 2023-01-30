# CZERTAINLY Appliance Builder

Builder of [CZERTAINLY Appliance](https://docs.czertainly.com/docs/installation-guide/deployment/deployment-appliance/overview), if you are not interested in developement you should just [download](https://docs.czertainly.com/docs/installation-guide/deployment/deployment-appliance/overview#download-and-import-image) published Appliance image. This repository is ment for developers.

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

## Building

```
git clone https://github.com/3KeyCompany/CZERTAINLY-Appliance.git
cd CZERTAINLY-Appliance
./build-appliance.sh
```
Finished apliance is exported into file `tmp/czertainly-appliance-$APPLIANCEVERSION."%g%m%d.%H%M%S.ova`. The proces takes about 7 minutes on i7-6700 CPU @ 3.40GHz.

## Usage of the Appliance

Start virtual machine, login as `czertainly` user with password `newgenerationtrustcare` and exec:

```
$ sudo -i
# adjust access credentials to harbor.3key.company
vim /etc/ansible/group_vars/all.yml
# exec CZERTAINLY instalation
ansible-playbook /etc/ansible/playbooks/czertainly.yml
```
## Tips for developers

By default Appliance builder uses parameters from [`vars/main.yml`](./vars/main.yml) you can make your own modifications to that file and pass it as first argument of the builder, for example:
```
./build-appliance.sh vars/develop.yml
```

Playbook for CZERTAINLY installation depends on following Ansible
roles:
  - [CZERTAINLY-Appliance-Branding](https://github.com/3KeyCompany/CZERTAINLY-Appliance-Branding)
  - [CZERTAINLY-Appliance-Host-Config](https://github.com/3KeyCompany/CZERTAINLY-Appliance-Host-Config)
  - [CZERTAINLY-Appliance-RKE2](https://github.com/3KeyCompany/CZERTAINLY-Appliance-RKE2)
  - [ansible-role-czertainly](https://github.com/3KeyCompany/ansible-role-czertainly)

They are cloned into `/etc/ansible` directory during Appliance image
creation. If you need use your own forks of role repositories you can
provide path to them inside your own copy of `vars/develop.yml`. Do
not use SSH access method, repos are being cloned during
`late_command` of [preseed.cfg](templates/preseed.cfg.j2#L58) file -
at that moment you wont be able to enter ssh password or use ssh key.

Later inside running Appliance you can run
[/etc/ansible/customize4developer.sh](files/customize4developer.sh) which
will adjust repos to be pushable and copy .ssh directory from
`czertainlyuser` to allow direct access to `root` account.

All Ansible roles have tags. You can run only parts you need to re-run to save your time. For example, when you want just reinstall czeratinly you can do:
```
kubectl delete ns czertainly
ansible-playbook /etc/ansible/playbooks/czertainly.yml --tags czertainly --skip-tags czertainly_sleep10
```

## Tested compatibility of resulting OVA

* VirtualBox 6.1
* VirtualBox 7.0.4 / working environment
* VMPlayer 16.2.4 / during import you have to click 'Retry' button to relax OVA specification to VMPlayer accept image
* VMPlayer 17.0.0 / same as above

## Notes

For cleaning working directory you can use `rm -rf tmp` or if you are on slow line maybe you would like more [specific command](build-appliance.sh#L5) which keeps offical Debian ISO image in place to save bandwith

Debian installation process can be automated by [preseed.cfg](./templates/preseed.cfg.j2) file which is [documented](https://www.debian.org/releases/stable/amd64/apbs02.en.html). Or you can run [network install from minimal ISO](https://www.debian.org/CD/netinst/) and inside of newly installed image run `debconf-get-selections --installer`. And final tip is to try unantend install using VirtualBox, and examine storage of virtual servers, preseed and other needed configs are available there.
