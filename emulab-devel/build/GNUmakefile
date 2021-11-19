#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
# Testbed Makefile
#
SRCDIR		= ..
OBJDIR		= .
SUBDIR		= 
TESTBED_SRCDIR  = ..
DISTCLEAN_FILES =  Makeconf GNUmakefile 	assign/GNUmakefile         named/GNUmakefile firewall/GNUmakefile fwrules/GNUmakefile 	ssl/GNUmakefile ssl/mksig ssl/usercert.cnf ssl/mkserial 	db/GNUmakefile 	db/EmulabConstants.pm db/EmulabFeatures.pm db/Experiment.pm 	db/Firewall.pm db/Group.pm db/Image.pm db/Interface.pm 	db/Lan.pm db/Logfile.pm db/Node.pm db/NodeType.pm db/OSinfo.pm 	db/Project.pm db/User.pm db/VirtExperiment.pm 	db/nalloc db/nfree db/if2port db/backup 	db/webcontrol db/node_status db/genelists db/genelists.proxy 	db/dumperrorlog.proxy 	db/setsitevar db/audit db/changeuid db/changepid 	db/libdb.pm db/libtbdb.pm db/inuse db/avail db/nodeip db/showgraph 	db/emdb.pm db/emdbi.pm db/emutil.pm 	db/dhcpd_makeconf db/nodelog db/unixgroups 	db/dbcheck db/interswitch db/dbboot db/schemacheck 	db/sitevarscheck db/dbfillcheck db/libadminctrl.pm 	db/update_permissions 	db/grabron db/stategraph db/readycount 	db/idletimes db/idlemail db/xmlconvert 	db/libdb.py db/elabinelab_bossinit db/Reservation.pm 	ipod/GNUmakefile 	os/GNUmakefile os/split-image.sh 	pxe/GNUmakefile pxe/bootinfo.restart 	security/GNUmakefile security/lastlog_daemon         sensors/GNUmakefile 	sensors/and/GNUmakefile sensors/and/and-emulab.conf 	sensors/powermon/GNUmakefile sensors/powermon/powermon 	sensors/nfstrace/GNUmakefile sensors/nfstrace/nfstrace.init 	sensors/nfstrace/nfsdump2/GNUmakefile 	account/GNUmakefile account/tbacct 	account/addpubkey account/addsfskey account/genpubkeys 	account/quotamail account/mkusercert account/newproj account/newuser 	backend/GNUmakefile backend/moduserinfo backend/newgroup 	backend/newmmlist backend/editexp backend/editimageid 	backend/editnodetype backend/editsitevars backend/newimageid 	backend/editgroup backend/newimageid_ez 	tbsetup/GNUmakefile tbsetup/console_setup tbsetup/spewlogfile 	tbsetup/snmpit/GNUmakefile  	tbsetup/spewrpmtar tbsetup/gentopofile tbsetup/power_5gstore.pm 	tbsetup/console_reset tbsetup/bwconfig tbsetup/power_rpc27.pm 	tbsetup/power_mail.pm tbsetup/power_whol.pm 	tbsetup/os_load tbsetup/os_setup tbsetup/os_select tbsetup/power 	tbsetup/node_reboot tbsetup/nscheck tbsetup/pxe_select 	tbsetup/resetvlans tbsetup/rmuser tbsetup/rmproj 	tbsetup/sched_reload tbsetup/sched_reserve tbsetup/reload_daemon 	tbsetup/batchexp tbsetup/batch_daemon tbsetup/repos_daemon 	tbsetup/wanlinkinfo tbsetup/wanassign 	tbsetup/swapexp	tbsetup/endexp tbsetup/elabinelab 	tbsetup/eventsys.proxy 	tbsetup/ns2ir/GNUmakefile 	tbsetup/ns2ir/parse.tcl tbsetup/ns2ir/tb_compat.tcl 	tbsetup/ns2ir/parse-ns tbsetup/ns2ir/parse.proxy 	tbsetup/ns2ir/sim.tcl tbsetup/nseswap tbsetup/nseparse/GNUmakefile 	tbsetup/nseparse/nse.parse.proxy tbsetup/nseparse/parse-nse 	tbsetup/nseparse/nse.parse.tcl 	tbsetup/nsverify/GNUmakefile tbsetup/nsverify/nstbparse 	tbsetup/nsverify/verify-ns 	tbsetup/db2ns 	tbsetup/tbprerun tbsetup/tbswap tbsetup/tbend tbsetup/tbrestart 	tbsetup/tbreport tbsetup/named_setup tbsetup/exports_setup 	tbsetup/checkpass/GNUmakefile tbsetup/assign_wrapper tbsetup/ptopgen 	tbsetup/assign_wrapper2 	tbsetup/node_update 	tbsetup/savelogs tbsetup/setgroups 	tbsetup/savelogs.proxy tbsetup/rmgroup tbsetup/mkexpdir 	tbsetup/node_control tbsetup/node_attributes         tbsetup/mkgroup tbsetup/eventsys_start 	tbsetup/eventsys_control 	tbsetup/mkproj tbsetup/libtestbed.pm 	tbsetup/vnode_setup tbsetup/staticroutes 	tbsetup/console_setup.proxy tbsetup/exports_setup.proxy 	tbsetup/smbpasswd_setup.proxy 	tbsetup/checkports tbsetup/libaudit.pm 	tbsetup/libreboot.pm tbsetup/libosload.pm tbsetup/libadminmfs.pm 	tbsetup/sfskey_update tbsetup/sfskey_update.proxy 	tbsetup/idleswap tbsetup/switchmac 	tbsetup/newnode_reboot         tbsetup/libtestbed.py 	tbsetup/libArchive.pm tbsetup/archive_control 	tbsetup/tarfiles_setup 	tbsetup/fetchtar.proxy tbsetup/webfrisbeekiller 	tbsetup/tcpp 	tbsetup/plab/GNUmakefile tbsetup/plab/libplab.py         tbsetup/plab/mod_dslice.py tbsetup/plab/mod_PLC.py         tbsetup/plab/mod_PLCNM.py 	tbsetup/plab/plabslice tbsetup/plab/plabnode tbsetup/plab/plabrenewd         tbsetup/plab/plabrenewonce 	tbsetup/plab/plabmetrics tbsetup/plab/plabstats 	tbsetup/plab/plabmonitord tbsetup/plab/libplabmon.pm         tbsetup/plab/plabmon_badpool.pm tbsetup/plab/plabmon_goodpool.pm         tbsetup/plab/plablinkdata 	tbsetup/plab/libdslice/GNUmakefile tbsetup/plab/etc/GNUmakefile 	tbsetup/plab/plabdist tbsetup/plab/plabhttpd 	tbsetup/plab/plabdiscover tbsetup/plab/etc/netbed_files/GNUmakefile 	tbsetup/ipassign/GNUmakefile tbsetup/ipassign/src/GNUmakefile 	tbsetup/ipassign/ipassign_wrapper tbsetup/assign_prepass 	tbsetup/panic tbsetup/tbrsync tbsetup/nfstrace 	tbsetup/checkup/GNUmakefile tbsetup/checkup/checkup_daemon 	tbsetup/libtblog.pm tbsetup/template_cvsroot/GNUmakefile 	tmcd/GNUmakefile tmcd/tmcd.restart 	utils/GNUmakefile utils/vlandiff utils/vlansync utils/delay_config 	utils/sshtb utils/create_image utils/node_admin 	utils/firstuser utils/export_tables utils/eventping 	utils/cvsupd.pl utils/newnode utils/grantnodetype 	utils/nsgen/GNUmakefile utils/nsgen/webnsgen 	utils/link_config utils/import_commitlog 	utils/opsreboot utils/deletenode utils/spewleds 	utils/grabwebcams utils/loghole utils/webcopy 	utils/setdest utils/grabswitchconfig         utils/backupswitches utils/setbuildinfo utils/checkquota 	utils/spewconlog utils/xlogin 	utils/opsdb_control utils/opsdb_control.proxy 	utils/remove_old_www utils/epmodeset 	utils/mkblob utils/rmblob utils/ctrladdr utils/tcppd 	utils/mktestbedtest utils/pxelinux_makeconf 	utils/addvpubaddr utils/attend utils/atten utils/addrfdevice 	utils/addrfpath utils/reserve utils/predict utils/notify-reservations 	utils/setzfsquotas utils/checkipmi 	wbstore/GNUmakefile 	www/GNUmakefile www/defs.php3 www/dbdefs.php3 www/xmlrpc.php3 	www/xmlrpcpipe.php3 	www/swish.conf www/websearch 	www/garcia-telemetry/GNUmakefile www/tutorial/GNUmakefile 	www/sec-check/GNUmakefile www/emusearch.xml 	vis/GNUmakefile vis/webvistopology vis/dbvistopology 	vis/prerender vis/prerender_all vis/render 	vis/floormap vis/webfloormap 	rc.d/GNUmakefile rc.d/2.mysql-server.sh rc.d/3.testbed.sh 	rc.d/2.elvind.sh rc.d/3.plab.sh rc.d/2.dhcpd.sh rc.d/3.and.sh 	rc.d/3.elvin_gateway.sh rc.d/pelab.sh rc.d/capture.sh 	rc.d/3.mfrisbeed.sh rc.d/3.mfrisbeed-subboss.sh rc.d/3.mfrisbeed-ops.sh 	tools/GNUmakefile rc.d/1.mysql-server.sh tools/svn/GNUmakefile         tools/webcamapplet/GNUmakefile tools/whol/GNUmakefile         tools/selectapplet/GNUmakefile 	event/GNUmakefile clientside/lib/event/GNUmakefile 		    event/etc/elvind-boss.conf event/etc/elvind-ops.conf 		    event/etc/elvind-inetd.conf event/etc/GNUmakefile		    event/sched/GNUmakefile 		    event/new_sched/GNUmakefile                     event/example/GNUmakefile event/example/tbsend.pl 		    event/example/tbrecv.pl event/example/tbsend-short.pl                     event/example/tbsend.py event/example/tbrecv.py 		    event/example/eventdebug.pl 		    event/proxy/GNUmakefile 		    event/monitoring/GNUmakefile 		    event/nsetrafgen/GNUmakefile 		    event/nsetrafgen/nseinput.tcl 		    event/nsetrafgen/nse-makepatch 		    event/stated/waitForState 		    event/stated/GNUmakefile event/stated/stated 	 	 	 	apache/GNUmakefile apache/php.ini         xmlrpc/GNUmakefile xmlrpc/emulabserver.py 	xmlrpc/sslxmlrpc_server.py xmlrpc/webxmlrpc xmlrpc/xmlrpcbag 	cdrom/GNUmakefile cdrom/tbbootconfig/GNUmakefile 	cdrom/groklilo/GNUmakefile 	autofs/GNUmakefile flash/GNUmakefile 	dhcpd/dhcpd.conf.template dhcpd/GNUmakefile 	dhcpd/dhcpd.conf.subboss.template 	ntpd/GNUmakefile 	ntpd/ntp.conf-client ntpd/ntp.conf-server ntpd/ntp.conf-external 	install/GNUmakefile install/installvars.pm install/emulab-install 	install/ops-install install/boss-install install/fs-install 	install/load-descriptors install/dump-descriptors 	install/newnode_sshkeys/GNUmakefile install/smb.conf.head         install/clrhouse-install install/genirack/GNUmakefile 	install/powder-fixed/GNUmakefile install/powder-bus/GNUmakefile 	install/libinstall.pm install/update-install install/update-testbed 	mote/GNUmakefile mote/tbuisp mote/tbsgmotepower mote/newmote 	mote/sgtools/GNUmakefile         protogeni/GNUmakefile protogeni/security/GNUmakefile         protogeni/xmlrpc/GNUmakefile protogeni/lib/GNUmakefile         protogeni/scripts/GNUmakefile protogeni/etc/GNUmakefile         protogeni/test/GNUmakefile protogeni/pubxmlrpc/GNUmakefile 	protogeni/event/GNUmakefile 	protogeni/rspec-emulab/GNUmakefile         protogeni/rspec-emulab/0.1/GNUmakefile 	protogeni/rspec-emulab/0.2/GNUmakefile 	protogeni/rspec-emulab/2/GNUmakefile         apt/GNUmakefile         powder/GNUmakefile powder/sasproxy/GNUmakefile         collab/GNUmakefile 	collab/exp-vis/GNUmakefile collab/exp-vis/fetch-vis         scopus/GNUmakefile 	node_usage/GNUmakefile node_usage/mk-plots 	node_usage/analy node_usage/publish 	node_usage/analy2 node_usage/refresh 	node_usage/from_ptop node_usage/sanity 	node_usage/gather node_usage/mk-php-pages 	node_usage/get-start-date clientside/GNUmakefile clientside/setversion  clientside/lib/GNUmakefile clientside/lib/libtb/GNUmakefile  clientside/lib/tmcd/GNUmakefile  clientside/GNUmakefile clientside/event/GNUmakefile  clientside/event/program-agent/GNUmakefile  clientside/event/disk-agent/GNUmakefile  clientside/tools/GNUmakefile clientside/tools/pcapper/GNUmakefile  clientside/tools/teachswitch/GNUmakefile  clientside/sensors/GNUmakefile clientside/sensors/slothd/GNUmakefile  clientside/sensors/slothd/sdisrunning clientside/sensors/slothd/sddeploy  clientside/sensors/canaryd/GNUmakefile  clientside/sensors/canaryd/feedbacklogs  clientside/os/GNUmakefile clientside/os/syncd/GNUmakefile  clientside/event/link-agent/GNUmakefile  clientside/event/bs-agent/GNUmakefile  clientside/event/proxy/GNUmakefile  clientside/event/tevc/GNUmakefile  clientside/event/trafgen/GNUmakefile  clientside/event/linktest/GNUmakefile  clientside/event/linktest/iperf/GNUmakefile  clientside/event/linktest/rude/GNUmakefile  clientside/event/linktest/weblinktest  clientside/event/linktest/linktest.proxy  clientside/event/linktest/linktest_control  clientside/event/linktest/run_linktest.pl  clientside/event/delay-agent/GNUmakefile  clientside/tmcc/GNUmakefile  clientside/tmcc/common/GNUmakefile clientside/tmcc/common/config/GNUmakefile  clientside/tmcc/freebsd/GNUmakefile clientside/tmcc/freebsd/init/GNUmakefile  clientside/tmcc/freebsd/init/4/GNUmakefile  clientside/tmcc/freebsd/init/5/GNUmakefile  clientside/tmcc/freebsd/init/6/GNUmakefile  clientside/tmcc/freebsd/init/7/GNUmakefile  clientside/tmcc/freebsd/init/8/GNUmakefile  clientside/tmcc/freebsd/init/9/GNUmakefile  clientside/tmcc/freebsd/init/10/GNUmakefile  clientside/tmcc/freebsd/init/10.3/GNUmakefile  clientside/tmcc/freebsd/init/10.4/GNUmakefile  clientside/tmcc/freebsd/init/11/GNUmakefile  clientside/tmcc/freebsd/init/11.2/GNUmakefile  clientside/tmcc/freebsd/init/12/GNUmakefile  clientside/tmcc/freebsd/init/13/GNUmakefile  clientside/tmcc/freebsd/supfile clientside/tmcc/freebsd/sethostname  clientside/tmcc/linux/GNUmakefile clientside/tmcc/linux/supfile  clientside/tmcc/linux/sethostname.dhclient  clientside/tmcc/linux9/GNUmakefile clientside/tmcc/linux9/supfile  clientside/tmcc/fedora/GNUmakefile clientside/tmcc/fedora/supfile  clientside/tmcc/fedora15/GNUmakefile  clientside/tmcc/linux-sg/GNUmakefile clientside/tmcc/ubuntu7/GNUmakefile  clientside/tmcc/centos6/GNUmakefile  clientside/tmcc/centos7/GNUmakefile  clientside/tmcc/centos8/GNUmakefile  clientside/tmcc/onie/GNUmakefile  clientside/tmcc/ubuntu10/GNUmakefile  clientside/tmcc/ubuntu11/GNUmakefile  clientside/tmcc/ubuntu14/GNUmakefile  clientside/tmcc/ubuntu15/GNUmakefile  clientside/tmcc/ubuntu16/GNUmakefile  clientside/tmcc/ubuntu16-ms/GNUmakefile  clientside/tmcc/ubuntu18/GNUmakefile  clientside/tmcc/ubuntu18-ms/GNUmakefile  clientside/tmcc/ubuntu18-ppc64le/GNUmakefile  clientside/tmcc/ubuntu20/GNUmakefile  clientside/tmcc/ubuntu20-ms/GNUmakefile  clientside/tmcc/ubuntu20-ppc64le/GNUmakefile  clientside/tmcc/linux-ms/GNUmakefile  clientside/tmcc/archlinux/GNUmakefile  clientside/tmcc/alpine/GNUmakefile  clientside/tmcc/freebsd5/GNUmakefile clientside/tmcc/freebsd5/supfile  clientside/tmcc/freebsd6/GNUmakefile clientside/tmcc/freebsd6/supfile  clientside/tmcc/freebsd6/netif-emulab  clientside/tmcc/freebsd7/GNUmakefile clientside/tmcc/freebsd7/netif-emulab  clientside/tmcc/freebsd9/GNUmakefile clientside/tmcc/freebsd9/netif-emulab  clientside/tmcc/freebsd10/GNUmakefile clientside/tmcc/freebsd10/netif-emulab  clientside/tmcc/freebsd11/GNUmakefile clientside/tmcc/freebsd11/netif-emulab  clientside/tmcc/freebsd12/GNUmakefile clientside/tmcc/freebsd12/netif-emulab  clientside/tmcc/freebsd13/GNUmakefile clientside/tmcc/freebsd13/netif_emulab  clientside/tmcc/cygwinxp/GNUmakefile clientside/tmcc/dp/GNUmakefile  clientside/tmcc/openbsd/GNUmakefile clientside/tmcc/ron/GNUmakefile  clientside/tmcc/plab/GNUmakefile clientside/tmcc/cygwinseven/GNUmakefile  clientside/os/dijkstra/GNUmakefile clientside/os/genhostsfile/GNUmakefile  clientside/os/growdisk/GNUmakefile  clientside/os/bootinfo/GNUmakefile  clientside/os/zapdisk/GNUmakefile  clientside/os/frisbee.redux/GNUmakefile  clientside/os/imagezip/GNUmakefile  clientside/os/imagezip/mbr/GNUmakefile  clientside/os/imagezip/gpt/GNUmakefile  clientside/os/imagezip/ffs/GNUmakefile  clientside/os/imagezip/extfs/GNUmakefile  clientside/os/imagezip/hashmap/GNUmakefile  clientside/os/imagezip/libndz/GNUmakefile  clientside/os/capture/GNUmakefile  clientside/tip/GNUmakefile clientside/tip/console  clientside/xmlrpc/GNUmakefile clientside/xmlrpc/emulabclient.py  clientside/xmlrpc/sslxmlrpc_client.py  clientside/xmlrpc/script_wrapper.py clientside/xmlrpc/libxmlrpc.pm  clientside/protogeni/GNUmakefile 
EVENTSYS	= 1
PELABSUPPORT	= 0
PGENISUPPORT    = 1
ISMAINSITE	= 0
SPEWFROMOPS	= 0
MOBILESUPPORT   = 0
SYSTEM	       := $(shell uname -s)

include Makeconf

#
# Ordering here matters!
# Things with no dependencies go first: 
#   assign db lib www
# Things that may have dependencies go next:
#    event (has event)
#   ipod os security sensors 
# Then things that only depend on stuff we've done:
#   pxe tbsetup tmcd utils backend www tip vis
# Then things that depend on stuff we just did:
#
ifeq ($(STANDALONE_CLEARINGHOUSE),0)
SUBDIRS = \
	clientside/lib \
	db assign www  event clientside ipod security sensors \
	pxe tbsetup account tmcd utils wbstore backend ipod vis \
	sensors os xmlrpc autofs install/newnode_sshkeys \
	tools/svn collab/exp-vis node_usage install
ifeq ($(ISMAINSITE),1)
SUBDIRS += tools/whol
endif
ifeq ($(PGENISUPPORT),1)
SUBDIRS += protogeni apt powder
endif
else
SUBDIRS = db tbsetup account protogeni
endif

all:		all-subdirs just-builddirs 

#
# We used to statically link our event agents.  We no longer do this, but
# if you want "old style" agents, use this target.
#
all-static:
	@LDSTATIC=-static $(MAKE) all

ifeq ($(STANDALONE_CLEARINGHOUSE),0)
install:	
	@echo "Choose either boss-install, ops-install or fs-install"
	@echo "Choose opsfs-install instead of ops-install for a combined ops/fs machine"
	@echo "Choose tipserv-install for dedicated tip server machines."
else
install: clrhouse-install
endif

#
# For installation on boss node
# 
boss-install:	install-checks \
		install-subdirs install-mkdirs \
		install-setbuildinfo
	@echo "Boss node installed!"

# Same target, with the checks omitted
boss-install-force:	install-subdirs install-mkdirs install-setbuildinfo
	@echo "Boss node installed!"

# Skip only the schema checks, but do the other checks.
boss-install-noschemacheck: install-updatecheck \
		install-sitevarscheck install-dbfillcheck \
		install-genischemacheck install-subdirs install-mkdirs \
		install-setbuildinfo

# Skip the update check. 
boss-install-noupdatecheck: install-schemacheck \
		install-sitevarscheck install-dbfillcheck \
		install-genischemacheck install-subdirs install-mkdirs \
		install-setbuildinfo

# Only the checks:
install-checks: \
		install-updatecheck \
		install-schemacheck \
		install-sitevarscheck \
		install-dbfillcheck install-genischemacheck
	@echo "Installation checks completed!"

clrhouse-install:	install-subdirs install-mkdirs
	@echo "CleaingHouse code installed!"

post-install:
	@$(MAKE) -C db post-install
	@$(MAKE) -C ipod post-install
	@$(MAKE) -C tbsetup post-install
	@$(MAKE) -C account post-install
	@$(MAKE) -C security post-install
	@$(MAKE) -C vis post-install
	@$(MAKE) -C www post-install
ifeq ($(EVENTSYS),1)
	@$(MAKE) -C event post-install
endif
ifeq ($(MOBILESUPPORT),1)
	@$(MAKE) -C mobile
endif
	@$(MAKE) -C tools post-install
	@$(MAKE) -C collab post-install
	@$(MAKE) -C utils post-install
ifeq ($(NODE_USAGE_SUPPORT),1)
	@$(MAKE) -C node_usage post-install
endif

#
# For installation on the 'ops' or 'users' node (okay, plastic)
# 
ops-install:
	-mkdir -p $(INSTALL_TOPDIR)/log
	-mkdir -p $(INSTALL_TOPDIR)/log/mysql
	-chmod 770 $(INSTALL_TOPDIR)/log/mysql
	-chown mysql $(INSTALL_TOPDIR)/log/mysql
	-chgrp mysql $(INSTALL_TOPDIR)/log/mysql
	-mkdir -p $(INSTALL_TOPDIR)/log/logfiles
	-chmod 777 $(INSTALL_TOPDIR)/log/logfiles
	@$(MAKE) -C rc.d control-install
	@$(MAKE) -C tbsetup control-install
	@$(MAKE) -C security control-install
	@$(MAKE) -C db control-install
	@$(MAKE) -C utils control-install
	@$(MAKE) -C clientside control-install
ifeq ($(EVENTSYS),1)
	@$(MAKE) -C event control-install
endif
	@$(MAKE) -C account control-install
ifeq ($(PELABSUPPORT),1)
	@$(MAKE) -C pelab control-install
endif

fs-install:
	@$(MAKE) -C rc.d fs-install
	@$(MAKE) -C tbsetup fs-install
	@$(MAKE) -C clientside fs-install
	@$(MAKE) -C sensors fs-install

opsfs-install: ops-install fs-install
	@echo "Combined ops/fs install done."

install-mkdirs:
	-mkdir -p $(INSTALL_TOPDIR)/db
	-mkdir -p $(INSTALL_TOPDIR)/locks
	-mkdir -p $(INSTALL_TOPDIR)/log
	-mkdir -p $(INSTALL_TOPDIR)/log/mysql
	-mkdir -p $(INSTALL_TOPDIR)/etc
	-mkdir -p $(INSTALL_TOPDIR)/www
	-mkdir -p $(INSTALL_TOPDIR)/suidbin
	-mkdir -p $(INSTALL_TOPDIR)/ssl
	-chmod 770 $(INSTALL_TOPDIR)/ssl
ifeq ($(STANDALONE_CLEARINGHOUSE),0)
	-mkdir -p $(INSTALL_TOPDIR)/opsdir
	-mkdir -p $(INSTALL_TOPDIR)/log/exports
	-mkdir -p $(INSTALL_TOPDIR)/lists
	-mkdir -p $(INSTALL_TOPDIR)/backup
	-mkdir -p $(INSTALL_TOPDIR)/expwork
	-mkdir -p $(INSTALL_TOPDIR)/batch
	-chmod 777 $(INSTALL_TOPDIR)/batch
	-mkdir -p $(INSTALL_TOPDIR)/expinfo
	-chmod 777 $(INSTALL_TOPDIR)/expinfo
	-mkdir -p $(INSTALL_TOPDIR)/exparchive
	-chmod 777 $(INSTALL_TOPDIR)/exparchive
	-mkdir -p $(INSTALL_TOPDIR)/exparchive/Archive
	-chmod 777 $(INSTALL_TOPDIR)/exparchive/Archive
	-mkdir -p $(INSTALL_TOPDIR)/images
	-chmod 775 $(INSTALL_TOPDIR)/images
	-ln -sf /usr/testbed/bin/nse $(INSTALL_TOPDIR)/bin
endif

just-builddirs:
	@$(MAKE) -C rc.d all
	@$(MAKE) -C apache all

tipserv-install:
	-mkdir -p $(INSTALL_TOPDIR)/log/tiplogs
	-mkdir -p $(INSTALL_TOPDIR)/etc
	@$(MAKE) -C clientside/tip tipserv-install
	@$(MAKE) -C clientside/os/capture tipserv-install
	@$(MAKE) -C tbsetup tipserv-install

client-mkdirs:
	-mkdir -p $(DESTDIR)$(CLIENT_BINDIR)
	-mkdir -p $(DESTDIR)$(CLIENT_MANDIR)

client:
	@$(MAKE) -C clientside client
	@$(MAKE) -C os client

client-install: client client-mkdirs
	@$(MAKE) -C clientside client-install
	@$(MAKE) -C os client-install

subboss: 
	@$(MAKE) -C clientside subboss
	@$(MAKE) -C tbsetup subboss
	@$(MAKE) -C db subboss
	@$(MAKE) -C os subboss
	@$(MAKE) -C utils subboss

subboss-install: subboss
	@$(MAKE) -C clientside subboss-install
	@$(MAKE) -C tbsetup subboss-install
	@$(MAKE) -C os subboss-install
	@$(MAKE) -C utils subboss-install
	@$(MAKE) -C db subboss-install
	@$(MAKE) -C rc.d subboss-install
	@$(MAKE) -C dhcpd subboss-install
	# Hack: this should probably be done by a subboss-install
	# script, but there isn't a huge need for that yet
	@rm -f $(INSTALL_RCDIR)/isc-dhcpd

TARBALLDESTDIR = /var/tmp/emulab-client

client-tarball:
	@$(MAKE) -C clientside client-tarball

client-src-tarball:
	@rm -f emulab-client-src.tar.gz
	tar clzf emulab-client-src.tar.gz -C clientside

# This is not finished yet.
client-shadow-rpm:
	-$(RM) -rf rpmbuild
	mkdir -p rpmbuild/SOURCES rpmbuild/SRPMS
	$(CP) emulab-client-src.tar.gz rpmbuild/SOURCES
	$(RPM) -v -bs --nodeps --define='_topdir $(TOPDIR)/rpmbuild' \
		clientside/shadow.spec

destdircheck:
	@if [ -z "$(DESTDIR)" ]; then \
	    echo "You must define DESTDIR for this target!"; \
	    false; \
	fi
	@if [ "$(DESTDIR)" = "/" ]; then \
	    echo "DESTDIR is '/', really really bad idea!"; \
	    false; \
	fi

mfsoscheck:
	@if [ `uname -s` != "FreeBSD" ]; then \
	    echo "Must build CDROM/MFS files on a FreeBSD system!"; \
	    false; \
	fi

mfs: mfsoscheck
	@$(MAKE) -C clientside mfs

mfs-nostatic: mfsoscheck
	@NOSTATIC=1 $(MAKE) -C clientside mfs

mfs-install: destdircheck mfs client-mkdirs
	@$(MAKE) -C clientside mfs-install

mfs-nostatic-install: destdircheck mfs-nostatic client-mkdirs
	@$(MAKE) -C clientside mfs-install

frisbee-mfs: mfsoscheck
	@$(MAKE) -C clientside frisbee-mfs

frisbee-mfs-nostatic: mfsoscheck
	@NOSTATIC=1 $(MAKE) -C clientside frisbee-mfs

frisbee-mfs-install: destdircheck frisbee-mfs
	@$(MAKE) -C clientside frisbee-mfs-install

frisbee-mfs-nostatic-install: destdircheck frisbee-mfs-nostatic
	@$(MAKE) -C clientside frisbee-mfs-install

newnode-mfs: mfsoscheck
	@$(MAKE) -C clientside newnode-mfs

newnode-mfs-nostatic: mfsoscheck
	@NOSTATIC=1 $(MAKE) -C clientside newnode-mfs

newnode-mfs-install: destdircheck newnode-mfs client-mkdirs
	@$(MAKE) -C clientside newnode-mfs-install

newnode-mfs-nostatic-install: destdircheck newnode-mfs-nostatic client-mkdirs
	@$(MAKE) -C clientside newnode-mfs-install

cdboot: mfsoscheck client
	@echo "CD/Dongle files built"

cdboot-install: destdircheck cdboot
	@$(MAKE) -C cdrom client-install
	@$(MAKE) -C clientside/tmcc/freebsd6 cdboot-install

flashboot: mfsoscheck client
	@echo "Flash dongle files built"

flashboot-install: destdircheck flashboot
	@$(MAKE) -C clientside/tmcc/freebsd6 cdboot-install
	@$(MAKE) -C os frisbee-mfs-install
	@$(MAKE) -C flash client-install
	@$(MAKE) -C clientside frisbee-mfs-install

#
# A check to see if this is a 'real' install. Kinda hacky, but as far as I can
# tell, you can't put ifeq()'s inside of targets
#
ifeq ($(TBROOT),/usr/testbed)
UPDATETESTBED= @cd $(OBJDIR)/install && perl update-testbed
else
UPDATETESTBED= @echo "Skipping update check, since prefix isn't /usr/testbed"
endif
ifeq ($(ISMAINSITE),1)
update-testbed: update-testbed-nostop
else
update-testbed:	update-testbed-install
endif

update-testbed-install:
	@echo "Updating the testbed ..."
	$(UPDATETESTBED) -i -s

update-testbed-noinstall:
	@echo "Updating the testbed ..."
	$(UPDATETESTBED)

update-testbed-nostop:
	@echo "Updating the testbed ..."
	$(UPDATETESTBED) -i

update-testbed-force:
	@echo "Updating the testbed in force mode ..."
	$(UPDATETESTBED) -f

ifeq ($(TBROOT),/usr/testbed)
UPDATECHECK= @cd $(OBJDIR)/install && perl update-testbed -v
else
UPDATECHECK= @echo "Skipping update checks, since prefix isn't /usr/testbed"
endif
install-updatecheck:
	@echo "Checking to see if updates need to be run"
	$(UPDATECHECK)

ifeq ($(TBROOT),/usr/testbed)
SCHEMACHECK= cd $(OBJDIR)/db && perl schemacheck
else
SCHEMACHECK= @echo "Skipping schema check, since prefix isn't /usr/testbed"
endif
install-schemacheck:
	@echo "Checking DB schema..."
	$(SCHEMACHECK)

ifeq ($(TBROOT),/usr/testbed)
SITEVARSCHECK= cd $(OBJDIR)/db && perl sitevarscheck
else
SITEVARSCHECK= @echo "Skipping sitevars check, since prefix isn't /usr/testbed"
endif
install-sitevarscheck:
	@echo "Checking Site variables..."
	$(SITEVARSCHECK)

ifeq ($(TBROOT),/usr/testbed)
DBFILLCHECK= cd $(OBJDIR)/db && perl dbfillcheck
else
DBFILLCHECK= @echo "Skipping DB fill check, since prefix isn't /usr/testbed"
endif
install-dbfillcheck:
	@echo "Checking Initial DB Fill ..."
	$(DBFILLCHECK)

ifeq ($(TBROOT),/usr/testbed)
SETBUILDINFO= cd $(OBJDIR)/utils && perl setbuildinfo
else
SETBUILDINFO= @echo "Skipping setbuildinfo, since prefix isn't /usr/testbed"
endif
install-setbuildinfo:
	@echo "Setting the Build and Version info"
	$(SETBUILDINFO)

install-genischemacheck:
ifeq ($(PGENISUPPORT),1)
	@$(MAKE) -C protogeni install-genischemacheck
endif
	@echo "Done"

BRANCHCHECK=
BRANCHECHO= @echo "Skipping branch check since not the Mothership"
ifeq ($(ISMAINSITE),1)
ifeq ($(TBROOT),/usr/testbed)
BRANCHCHECK= cd $(SRCDIR) && \
		git status --porcelain -s -b | head -1 | grep -q -s current
BRANCHECHO= @echo "Checking to make sure you are on the mothership branch"
endif
endif
install-branchcheck:
	$(BRANCHECHO)
	$(BRANCHCHECK)

# We use separate src and obj trees in Emulab, so the traditional distclean to
# clean "made" files from a mingled source-and-obj tree is unnecessary.
# However, this may be useful if you mistakenly configure and make a src tree.
clean:		clean-subdirs
distclean:	distclean-subdirs
	rm -f Makeconf GNUmakefile config.h config.status config.cache config.log
	rm -f $(DISTCLEAN_FILES)

#
# Be careful, do not run these unless you are updating your installation
# with a new IP subnet or domain name. 
#
boss-updateip-clean:	clean
	@$(MAKE) -C rc.d clean
	@$(MAKE) -C apache clean
	@$(MAKE) -C named clean
	@$(MAKE) -C dhcpd clean

ops-updateip-clean:	clean
	@$(MAKE) -C rc.d clean
	@$(MAKE) -C apache clean

update-rcd:
	@$(MAKE) -C rc.d all
	@$(MAKE) -C rc.d install

#
# Here's a different approch to recover from just configure problems.  It cleans
# all files from an obj tree that have a corresponding .in file in the src tree.
undo-configure:
	find $SRCDIR -name '*.in' -a -not -name configure.in | \
	    sed -e "s;$SRCDIR;$OBJDIR;" -e 's;[.]in$;;' | xargs rm -f

#
# XXX a "temporary" hack for scripts that were evolving fast.
# We didn't want to have to remake the client image whenever we changed these.
# They are copied over to the embryonic boss and ops during setup.
#
elabinelab-scripts:
	mkdir -p $(INSTALL_TOPDIR)/etc
	cp -f $(SRCDIR)/clientside/tmcc/freebsd/mkextrafs.pl $(INSTALL_TOPDIR)/etc/
	cp -f $(SRCDIR)/clientside/tmcc/common/config/rc.mkelab $(INSTALL_TOPDIR)/etc/

ifeq ($(SPEWFROMOPS),1)
elabinelab-nogit: elabinelab-scripts
	-mkdir -p /share/emulab
	rm -f /share/emulab/emulab-src.tar.gz
	tar czf /share/emulab/emulab-src.tar.gz -C $(SRCDIR) --exclude=.git .

elabinelab-git: elabinelab-scripts
	-mkdir -p /share/emulab
	rm -f /share/emulab/emulab-src.tar.gz
	(cd $(SRCDIR); \
	 git archive HEAD > /share/emulab/emulab-src.tar)
	tar rf /share/emulab/emulab-src.tar -C $(SRCDIR) \
	 --exclude=.git protogeni/rspec-geni
	gzip /share/emulab/emulab-src.tar
else
elabinelab-nogit: elabinelab-scripts
	-mkdir -p $(INSTALL_TOPDIR)/src
	rm -f $(INSTALL_TOPDIR)/src/emulab-src.tar.gz
	tar czf $(INSTALL_TOPDIR)/src/emulab-src.tar.gz -C $(SRCDIR) --exclude=.git .

elabinelab-git: elabinelab-scripts
	-mkdir -p $(INSTALL_TOPDIR)/src
	rm -f $(INSTALL_TOPDIR)/src/emulab-src.tar.gz
	(cd $(SRCDIR); \
	 git archive HEAD > $(INSTALL_TOPDIR)/src/emulab-src.tar)
	tar rf $(INSTALL_TOPDIR)/src/emulab-src.tar -C $(SRCDIR) \
	 --exclude=.git protogeni/rspec-geni
	gzip $(INSTALL_TOPDIR)/src/emulab-src.tar
endif

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

# By default, make any target by descending into subdirectories.
%: %-subdirs ;

.PHONY: post-install install-mkdirs clrhouse-install install \
	boss-install-noupdatecheck boss-install-noschemacheck \
	boss-install-force update-testbed update-testbed-install \
	update-testbed-noinstall update-testbed-nostop

# Get rid of a bunch of nasty built-in implicit rules.
.SUFFIXES:
