#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

VERSION ?= 3.3.0-0

obj-m += ipod.o

ifeq ($(KERNELRELEASE),)
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
endif

emulab-ipod-dkms_$(VERSION)_all.deb: debian/control debian/rules debian/changelog debian/compat
	dpkg-buildpackage -us -uc
	mv ../emulab-ipod-dkms_$(VERSION)_all.deb .

deb-dkms: emulab-ipod-dkms_$(VERSION)_all.deb

deb-dkms-install: deb-dkms
	dpkg -i emulab-ipod-dkms_$(VERSION)_all.deb

rpmbuild/RPMS/noarch/emulab-ipod-dkms-$(VERSION).noarch.rpm: rpm/emulab-ipod-dkms.conf rpm/emulab-ipod-dkms.spec
	mkdir -p rpmbuild/{RPMS,SRPMS,SPECS,SOURCES}
	cp -p Makefile ipod.c rpm/emulab-ipod-dkms.conf rpmbuild/SOURCES
	rpmbuild --define "_topdir "$(shell readlink -f rpmbuild) -ba \
		rpm/emulab-ipod-dkms.spec

rpm-dkms: rpmbuild/RPMS/noarch/emulab-ipod-dkms-$(VERSION).noarch.rpm

rpm-dkms-install: rpm-dkms
	rpm -iv rpmbuild/RPMS/noarch/emulab-ipod-dkms-$(VERSION).noarch.rpm
