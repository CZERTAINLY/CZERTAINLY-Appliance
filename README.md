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

Appliance comes with preconfigured Debian system. You need to initialiaze rke2 cluster and install CZERTAINLY. Please follow instructions from [offical documentation](https://docs.czertainly.com/docs/installation-guide/deployment/deployment-appliance/initialization).

## Tips for developers

By default Appliance builder uses parameters from [`vars/main.yml`](./vars/main.yml) you can make your own modifications to that file and pass it as first argument of the builder, for example:
```
./build-appliance.sh vars/develop.yml
```
Playbook for CZERTAINLY installation depends on following Ansible
roles:
  - [ansible-role-czertainly-branding](https://github.com/3KeyCompany/ansible-role-czertainly-branding)
  - [ansible-role-http-proxy](https://github.com/3KeyCompany/ansible-role-http-proxy)
  - [ansible-role-postgres](https://github.com/3KeyCompany/ansible-role-postgres)
  - [ansible-role-helm](https://github.com/3KeyCompany/ansible-role-helm)
  - [ansible-role-rke2](https://github.com/3KeyCompany/ansible-role-rke2)
  - [ansible-role-czertainly](https://github.com/3KeyCompany/ansible-role-czertainly)
they are provided by package [`czertainly-appliance-tools`](https://github.com/semik/CZERTAINLY-Appliance-Tools) if you need to work on any of them. Best option is to clone a repository of the role you need to work on into right place under `/etc/czertainly-ansible/roles`.

If you want to run Ansible playbooks by hand don't forget to set `ANSIBLE_CONFIG` to [right](https://github.com/semik/CZERTAINLY-Appliance-Tools/blob/main/usr/bin/czertainly-tui#L26) values. Typicaly you can run instalation command from menu of Text UI.

All Ansible roles have tags. You can run only parts you need to re-run to save your time. For example, when you want just reinstall czeratinly you can do:
```
kubectl delete ns czertainly
ANSIBLE_CONFIG=/etc/czertainly-ansible/ansible.cfg ansible-playbook /etc/czertainly-ansible/playbooks/czertainly.yml --tags czertainly --skip-tags czertainly_sleep10
```
## Tested compatibility of resulting OVA

* VirtualBox 6.1
* VirtualBox 7.0.4 / working environment
* VMPlayer 16.2.4 / during import you have to click 'Retry' button to relax OVA specification to VMPlayer accept image
* VMPlayer 17.0.0 / same as above

## Notes

For cleaning working directory you can use `rm -rf tmp` or if you are on slow line maybe you would like more [specific command](build-appliance.sh#L5) which keeps offical Debian ISO image in place to save bandwith.

Debian installation process can be automated by [preseed.cfg](./templates/preseed.cfg.j2) file which is [documented](https://www.debian.org/releases/stable/amd64/apbs02.en.html). Or you can run [network install from minimal ISO](https://www.debian.org/CD/netinst/) and inside of newly installed image run `debconf-get-selections --installer`. And final tip is to try unantend install using VirtualBox, and examine storage of virtual servers, preseed and other needed configs are available there.
