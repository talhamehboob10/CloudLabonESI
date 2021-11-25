#!/usr/bin/perl -w
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
# Emulab constants.
#

package EmulabConstants;
use strict;
use Exporter;
use SelfLoader;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter SelfLoader);

@EXPORT =
    qw ( NODERELOADING_PID NODERELOADING_EID NODEDEAD_PID NODEDEAD_EID
	 OLDRESERVED_PID OLDRESERVED_EID NFREELOCKED_PID NFREELOCKED_EID 
	 NODEBOOTSTATUS_OKAY NODEBOOTSTATUS_FAILED NODEBOOTSTATUS_UNKNOWN
	 NODESTARTSTATUS_NOSTATUS PROJMEMBERTRUST_NONE PROJMEMBERTRUST_USER
	 PROJMEMBERTRUST_ROOT PROJMEMBERTRUST_GROUPROOT
	 PROJMEMBERTRUST_PROJROOT PROJMEMBERTRUST_LOCALROOT
	 NODEILL_PID NODEILL_EID VLAN_PID VLAN_EID

	 TBOPSPID EXPTLOGNAME
	 PLABMOND_PID PLABMOND_EID PLABHOLDING_PID PLABHOLDING_EID
         PLABTESTING_PID PLABTESTING_EID PLABDOWN_PID PLABDOWN_EID

	 TBMinTrust TBTrustConvert

	 TB_NODEACCESS_READINFO TB_NODEACCESS_MODIFYINFO
	 TB_NODEACCESS_LOADIMAGE TB_NODEACCESS_REBOOT
	 TB_NODEACCESS_POWERCYCLE TB_NODEACCESS_MODIFYVLANS
	 TB_NODEACCESS_MIN TB_NODEACCESS_MAX

	 NODEFAILMODE_FATAL NODEFAILMODE_NONFATAL NODEFAILMODE_IGNORE

	 TB_USERINFO_READINFO TB_USERINFO_MODIFYINFO
	 TB_USERINFO_MIN TB_USERINFO_MAX

	 USERSTATUS_ACTIVE USERSTATUS_FROZEN USERSTATUS_INACTIVE
	 USERSTATUS_UNAPPROVED USERSTATUS_UNVERIFIED USERSTATUS_NEWUSER
	 USERSTATUS_ARCHIVED USERSTATUS_NONLOCAL

	 TB_EXPT_READINFO TB_EXPT_MODIFY TB_EXPT_DESTROY TB_EXPT_UPDATE
	 TB_EXPT_MIN TB_EXPT_MAX

	 TB_PROJECT_READINFO TB_PROJECT_MAKEGROUP
	 TB_PROJECT_EDITGROUP TB_PROJECT_DELGROUP
	 TB_PROJECT_GROUPGRABUSERS TB_PROJECT_BESTOWGROUPROOT
	 TB_PROJECT_LEADGROUP TB_PROJECT_ADDUSER
	 TB_PROJECT_DELUSER TB_PROJECT_MAKEOSID
	 TB_PROJECT_DELOSID TB_PROJECT_MAKEIMAGEID TB_PROJECT_DELIMAGEID
	 TB_PROJECT_CREATEEXPT TB_PROJECT_CREATELEASE
	 TB_PROJECT_MIN TB_PROJECT_MAX TB_PID_LEN TB_GID_LEN

	 TB_OSID_READINFO TB_OSID_CREATE
	 TB_OSID_DESTROY TB_OSID_MIN TB_OSID_MAX
	 TB_OSID_OSIDLEN TB_OSID_OSNAMELEN TB_OSID_VERSLEN

         TB_TAINTSTATE_USERONLY TB_TAINTSTATE_BLACKBOX TB_TAINTSTATE_DANGEROUS 
         TB_TAINTSTATE_MUSTRELOAD TB_TAINTSTATE_ALL

	 TB_IMAGEID_READINFO TB_IMAGEID_MODIFYINFO TB_IMAGEID_EXPORT
	 TB_IMAGEID_CREATE TB_IMAGEID_DESTROY
	 TB_IMAGEID_ACCESS TB_IMAGEID_MIN TB_IMAGEID_MAX
	 TB_IMAGEID_IMAGEIDLEN TB_IMAGEID_IMAGENAMELEN

         LEASE_ACCESS_READINFO LEASE_ACCESS_READ LEASE_ACCESS_MODIFY
         LEASE_ACCESS_MODIFYINFO
         LEASE_ACCESS_DESTROY LEASE_ACCESS_MIN LEASE_ACCESS_MAX

         LEASE_STATE_VALID LEASE_STATE_UNAPPROVED LEASE_STATE_GRACE
         LEASE_STATE_LOCKED LEASE_STATE_EXPIRED LEASE_STATE_FAILED

	 LEASE_ERROR_NONE LEASE_ERROR_FAILED LEASE_ERROR_BUSY
	 LEASE_ERROR_GONE LEASE_ERROR_ALLOCFAILED

         GLOBAL_PERM_ANON_RO GLOBAL_PERM_USER_RO
         GLOBAL_PERM_ANON_RO_IDX GLOBAL_PERM_USER_RO_IDX

	 DBLIMIT_NSFILESIZE NODERELOADPENDING_EID

	 NODEREPOSITIONING_PID NODEREPOSITIONING_EID NODEREPOSPENDING_EID

	 EXPTSTATE_NEW EXPTSTATE_PRERUN EXPTSTATE_SWAPPED EXPTSTATE_SWAPPING
	 EXPTSTATE_ACTIVATING EXPTSTATE_ACTIVE EXPTSTATE_PANICED
	 EXPTSTATE_TERMINATING EXPTSTATE_TERMINATED EXPTSTATE_QUEUED
	 EXPTSTATE_MODIFY_PARSE EXPTSTATE_MODIFY_REPARSE EXPTSTATE_MODIFY_RESWAP
	 EXPTSTATE_RESTARTING
	 BATCHSTATE_LOCKED BATCHSTATE_UNLOCKED
	 EXPTCANCEL_CLEAR EXPTCANCEL_TERM EXPTCANCEL_SWAP EXPTCANCEL_DEQUEUE

	 TB_NODELOGTYPE_MISC TB_NODELOGTYPES TB_DEFAULT_NODELOGTYPE

	 TB_DEFAULT_RELOADTYPE TB_RELOADTYPE_FRISBEE TB_RELOADTYPE_NETDISK

	 TB_EXPTPRIORITY_LOW TB_EXPTPRIORITY_HIGH

	 TB_ASSIGN_TOOFEWNODES TB_OPSPID

	 TBDB_TBEVENT_NODESTATE TBDB_TBEVENT_NODEOPMODE TBDB_TBEVENT_CONTROL
	 TBDB_TBEVENT_COMMAND TBDB_TBEVENT_EXPTSTATE
	 TBDB_TBEVENT_NODESTARTSTATUS TBDB_TBEVENT_NODEACCOUNTS
	 TBDB_TBEVENT_NODESTATUS TBDB_TBEVENT_FRISBEESTATUS 

	 TBDB_NODESTATE_ISUP TBDB_NODESTATE_REBOOTING TBDB_NODESTATE_REBOOTED
	 TBDB_NODESTATE_SHUTDOWN TBDB_NODESTATE_BOOTING TBDB_NODESTATE_TBSETUP
	 TBDB_NODESTATE_RELOADSETUP TBDB_NODESTATE_RELOADING
	 TBDB_NODESTATE_RELOADDONE TBDB_NODESTATE_RELOADDONE_V2
	 TBDB_NODESTATE_UNKNOWN
	 TBDB_NODESTATE_PXEWAIT TBDB_NODESTATE_PXEWAKEUP
	 TBDB_NODESTATE_PXEFAILED TBDB_NODESTATE_PXELIMBO
	 TBDB_NODESTATE_PXEBOOTING TBDB_NODESTATE_ALWAYSUP
	 TBDB_NODESTATE_MFSSETUP TBDB_NODESTATE_TBFAILED
	 TBDB_NODESTATE_POWEROFF TBDB_NODESTATE_SECVIOLATION
         TBDB_NODESTATE_GPXEBOOTING TBDB_NODESTATE_TPMSIGNOFF
	 TBDB_NODESTATE_VNODEBOOTSTART TBDB_NODESTATE_RELOADFAILED

	 TBDB_NODEOPMODE_NORMAL TBDB_NODEOPMODE_DELAYING
         TBDB_NODEOPMODE_ALWAYSUP
	 TBDB_NODEOPMODE_UNKNOWNOS TBDB_NODEOPMODE_RELOADING
	 TBDB_NODEOPMODE_NORMALv1 TBDB_NODEOPMODE_MINIMAL TBDB_NODEOPMODE_PCVM
	 TBDB_NODEOPMODE_RELOAD TBDB_NODEOPMODE_RELOADMOTE
         TBDB_NODEOPMODE_RELOADUE
	 TBDB_NODEOPMODE_RELOADPCVM TBDB_NODEOPMODE_RELOADPUSH
	 TBDB_NODEOPMODE_SECUREBOOT TBDB_NODEOPMODE_SECURELOAD
	 TBDB_NODEOPMODE_DELAY
	 TBDB_NODEOPMODE_BOOTWHAT
	 TBDB_NODEOPMODE_ANY
	 TBDB_NODEOPMODE_UNKNOWN TBDB_NODEOPMODE_NORMALv2

	 TBDB_COMMAND_REBOOT
	 TBDB_COMMAND_POWEROFF TBDB_COMMAND_POWERON TBDB_COMMAND_POWERCYCLE

	 TBDB_STATED_TIMEOUT_REBOOT TBDB_STATED_TIMEOUT_NOTIFY
	 TBDB_STATED_TIMEOUT_CMDRETRY

	 TBDB_ALLOCSTATE_FREE_CLEAN TBDB_ALLOCSTATE_FREE_DIRTY
	 TBDB_ALLOCSTATE_DOWN TBDB_ALLOCSTATE_RELOAD_TO_FREE
	 TBDB_ALLOCSTATE_RELOAD_PENDING TBDB_ALLOCSTATE_RES_RELOAD
	 TBDB_ALLOCSTATE_RES_INIT_DIRTY TBDB_ALLOCSTATE_RES_INIT_CLEAN
	 TBDB_ALLOCSTATE_RES_REBOOT_DIRTY TBDB_ALLOCSTATE_RES_REBOOT_CLEAN
	 TBDB_ALLOCSTATE_RES_READY TBDB_ALLOCSTATE_UNKNOWN
	 TBDB_ALLOCSTATE_RES_TEARDOWN TBDB_ALLOCSTATE_DEAD
	 TBDB_ALLOCSTATE_RES_RECONFIG TBDB_ALLOCSTATE_RES_REBOOT

	 TBDB_STATS_PRELOAD TBDB_STATS_START TBDB_STATS_TERMINATE
	 TBDB_STATS_SWAPIN TBDB_STATS_SWAPOUT TBDB_STATS_SWAPMODIFY
	 TBDB_STATS_FLAGS_IDLESWAP TBDB_STATS_FLAGS_PREMODIFY
	 TBDB_STATS_FLAGS_START TBDB_STATS_FLAGS_PRESWAPIN
	 TBDB_STATS_FLAGS_MODHOSED TBDB_STATS_SWAPUPDATE
	 TBDB_STATS_FLAGS_MODSWAPOUT

	 TBDB_JAILIPBASE TBDB_JAILIPMASK
	 TBDB_FRISBEEMCBASEADDR

	 TBDB_RSRVROLE_NODE TBDB_RSRVROLE_VIRTHOST TBDB_RSRVROLE_DELAYNODE
	 TBDB_RSRVROLE_SIMHOST TBDB_RSRVROLE_STORAGEHOST

	 TBDB_EXPT_WORKDIR TBDB_EXPT_INFODIR
	 TB_OSID_MBKERNEL TB_OSID_PATH_NFS
	 TB_OSID_FREEBSD_MFS TB_OSID_FRISBEE_MFS
	 TBDB_TBCONTROL_PXERESET TBDB_TBCONTROL_RESET
	 TBDB_TBCONTROL_RELOADDONE TBDB_TBCONTROL_RELOADDONE_V2
	 TBDB_TBCONTROL_TIMEOUT TBDB_NO_STATE_TIMEOUT
	 TBDB_TBCONTROL_PXEBOOT TBDB_TBCONTROL_BOOTING
	 TBDB_TBCONTROL_CHECKGENISUP

	 TBDB_LOWVPORT TBDB_MAXVPORT TBDB_PORTRANGE

	 TBDB_PHYSICAL_NODE_TABLES TBDB_PHYSICAL_NODE_HISTORY_TABLES

	 TBDB_WIDEAREA_LOCALNODE

         TBDB_WIRETYPE_NODE TBDB_WIRETYPE_SERIAL TBDB_WIRETYPE_POWER
         TBDB_WIRETYPE_DNARD TBDB_WIRETYPE_CONTROL TBDB_WIRETYPE_TRUNK
         TBDB_WIRETYPE_OUTERCONTROL TBDB_WIRETYPE_UNUSED 
         TBDB_WIRETYPE_MANAGEMENT

	 TBDB_IFACEROLE_CONTROL TBDB_IFACEROLE_EXPERIMENT
	 TBDB_IFACEROLE_JAIL TBDB_IFACEROLE_FAKE TBDB_IFACEROLE_OTHER
	 TBDB_IFACEROLE_GW TBDB_IFACEROLE_OUTER_CONTROL
	 TBDB_IFACEROLE_MANAGEMENT

	 TBDB_ROUTERTYPE_NONE	TBDB_ROUTERTYPE_OSPF
	 TBDB_ROUTERTYPE_STATIC TBDB_ROUTERTYPE_MANUAL
	 TBDB_USER_INTERFACE_EMULAB TBDB_USER_INTERFACE_PLAB
	 TBDB_EVENTKEY TBDB_WEBKEY

	 TBDB_SECLEVEL_GREEN TBDB_SECLEVEL_BLUE TBDB_SECLEVEL_YELLOW
	 TBDB_SECLEVEL_ORANGE TBDB_SECLEVEL_RED TBDB_SECLEVEL_ZAPDISK

	 TB_NODEHISTORY_OP_FREE TB_NODEHISTORY_OP_ALLOC TB_NODEHISTORY_OP_MOVE
	 PROTOUSER TB_NODEHISTORY_OP_CREATE TB_NODEHISTORY_OP_DESTROY
	 PROTOGENI_SUPPORT PROTOGENI_GENIRACK CKUPUSER GENIUSER
	 );

use English;
use vars qw($TB $TBOPS $TBOPSPID $EXPTLOGNAME $PROJROOT $MAINSITE $OURDOMAIN);

# Configure variables
$TB	     = "/users/mshobana/emulab-devel/build";
$TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
$TBOPSPID    = "emulab-ops";
$EXPTLOGNAME = "activity.log";
$PROJROOT    = "/proj";
$MAINSITE    = 0;
$OURDOMAIN   = "cloudlab.umass.edu";

1;


#
# Needs to be configured.
#
sub TBDB_EXPT_WORKDIR()		{ "/usr/testbed/expwork"; }
sub TBDB_EXPT_INFODIR()		{ "/usr/testbed/expinfo"; }

#
# Define exported "constants". Basically, these are just perl subroutines
# that look like constants cause you do not need to call a perl subroutine
# with parens. That is, FOO and FOO() are the same thing.
#
sub NODERELOADING_PID()		{ $TBOPSPID; }
sub NODERELOADING_EID()		{ "reloading"; }
sub NODERELOADPENDING_EID()	{ "reloadpending"; }
sub NODEREPOSITIONING_PID()	{ $TBOPSPID; }
sub NODEREPOSITIONING_EID()	{ "repositioning"; }
sub NODEREPOSPENDING_EID()	{ "repositionpending"; }
sub NODEDEAD_PID()		{ $TBOPSPID; }
sub NODEDEAD_EID()		{ "hwdown"; }
sub NODEILL_PID()		{ $TBOPSPID; }
sub NODEILL_EID()		{ "hwcheckup"; }
sub PLABMOND_PID()		{ $TBOPSPID; }
sub PLABMOND_EID()		{ "plab-monitor"; }
sub PLABTESTING_PID()		{ $TBOPSPID; }
sub PLABTESTING_EID()		{ "plab-testing"; }
sub PLABHOLDING_PID()		{ $TBOPSPID; }
sub PLABHOLDING_EID()		{ "plabnodes"; }
sub PLABDOWN_PID()		{ $TBOPSPID; }
sub PLABDOWN_EID()		{ "hwdown"; }
sub VLAN_PID()			{ $TBOPSPID; }
sub VLAN_EID()			{ "vlan-holding"; }
sub OLDRESERVED_PID()		{ $TBOPSPID; }
sub OLDRESERVED_EID()		{ "oldreserved"; }
sub NFREELOCKED_PID()		{ $TBOPSPID; }
sub NFREELOCKED_EID()		{ "nfree-locked"; }
sub TBOPSPID()			{ $TBOPSPID; }
sub EXPTLOGNAME()		{ $EXPTLOGNAME; }
sub PROTOUSER()			{ 'elabman'; }
sub CKUPUSER()			{ 'elabckup'; }
sub GENIUSER()			{ 'geniuser'; }

sub PROTOGENI_SUPPORT()		{ 1; }
sub PROTOGENI_GENIRACK()	{ 0; }

sub NODEBOOTSTATUS_OKAY()	{ "okay" ; }
sub NODEBOOTSTATUS_FAILED()	{ "failed"; }
sub NODEBOOTSTATUS_UNKNOWN()	{ "unknown"; }
sub NODESTARTSTATUS_NOSTATUS()	{ "none"; }

sub NODEFAILMODE_FATAL()	{ "fatal"; }
sub NODEFAILMODE_NONFATAL()	{ "nonfatal"; }
sub NODEFAILMODE_IGNORE()	{ "ignore"; }

# Experiment states
sub EXPTSTATE_NEW()		{ "new"; }
sub EXPTSTATE_PRERUN()		{ "prerunning"; }
sub EXPTSTATE_SWAPPED()		{ "swapped"; }
sub EXPTSTATE_QUEUED()		{ "queued"; }
sub EXPTSTATE_SWAPPING()	{ "swapping"; }
sub EXPTSTATE_ACTIVATING()	{ "activating"; }
sub EXPTSTATE_ACTIVE()		{ "active"; }
sub EXPTSTATE_PANICED()		{ "paniced"; }
sub EXPTSTATE_TERMINATING()	{ "terminating"; }
sub EXPTSTATE_TERMINATED()	{ "ended"; }
sub EXPTSTATE_MODIFY_PARSE()	{ "modify_parse"; }
sub EXPTSTATE_MODIFY_REPARSE()	{ "modify_reparse"; }
sub EXPTSTATE_MODIFY_RESWAP()	{ "modify_reswap"; }
sub EXPTSTATE_RESTARTING()	{ "restarting"; }
# For the batch_daemon.
sub BATCHSTATE_LOCKED()		{ "locked";}
sub BATCHSTATE_UNLOCKED()	{ "unlocked";}

# Cancel flags
sub EXPTCANCEL_CLEAR()		{ 0 ;}
sub EXPTCANCEL_TERM()		{ 1 ;}
sub EXPTCANCEL_SWAP()		{ 2 ;}
sub EXPTCANCEL_DEQUEUE()	{ 3 ;}

sub USERSTATUS_ACTIVE()		{ "active"; }
sub USERSTATUS_FROZEN()		{ "frozen"; }
sub USERSTATUS_UNAPPROVED()	{ "unapproved"; }
sub USERSTATUS_UNVERIFIED()	{ "unverified"; }
sub USERSTATUS_NEWUSER()	{ "newuser"; }
sub USERSTATUS_ARCHIVED()	{ "archived"; }
sub USERSTATUS_NONLOCAL()	{ "nonlocal"; }
sub USERSTATUS_INACTIVE()	{ "inactive"; }

#
# We want valid project membership to be non-zero for easy membership
# testing. Specific trust levels are encoded thusly.
#
sub PROJMEMBERTRUST_NONE()	{ 0; }
sub PROJMEMBERTRUST_USER()	{ 1; }
sub PROJMEMBERTRUST_ROOT()	{ 2; }
sub PROJMEMBERTRUST_LOCALROOT()	{ 2; }
sub PROJMEMBERTRUST_GROUPROOT()	{ 3; }
sub PROJMEMBERTRUST_PROJROOT()	{ 4; }
sub PROJMEMBERTRUST_ADMIN()	{ 5; }

#
# Access types. Duplicated in the web interface. Make changes there too!
#
# Things you can do to a node.
sub TB_NODEACCESS_READINFO()	{ 1; }
sub TB_NODEACCESS_MODIFYINFO()	{ 2; }
sub TB_NODEACCESS_LOADIMAGE()	{ 3; }
sub TB_NODEACCESS_REBOOT()	{ 4; }
sub TB_NODEACCESS_POWERCYCLE()	{ 5; }
sub TB_NODEACCESS_MODIFYVLANS()	{ 6; }
sub TB_NODEACCESS_MIN()		{ TB_NODEACCESS_READINFO(); }
sub TB_NODEACCESS_MAX()		{ TB_NODEACCESS_MODIFYVLANS(); }

# User Info (modinfo web page, etc).
sub TB_USERINFO_READINFO()	{ 1; }
sub TB_USERINFO_MODIFYINFO()	{ 2; }
sub TB_USERINFO_MIN()		{ TB_USERINFO_READINFO(); }
sub TB_USERINFO_MAX()		{ TB_USERINFO_MODIFYINFO(); }

# Experiments.
sub TB_EXPT_READINFO()		{ 1; }
sub TB_EXPT_MODIFY()		{ 2; }
sub TB_EXPT_DESTROY()		{ 3; }
sub TB_EXPT_UPDATE()		{ 4; }
sub TB_EXPT_MIN()		{ TB_EXPT_READINFO(); }
sub TB_EXPT_MAX()		{ TB_EXPT_UPDATE(); }

# Projects.
sub TB_PROJECT_READINFO()	{ 1; }
sub TB_PROJECT_MAKEGROUP()	{ 2; }
sub TB_PROJECT_EDITGROUP()	{ 3; }
sub TB_PROJECT_GROUPGRABUSERS() { 4; }
sub TB_PROJECT_BESTOWGROUPROOT(){ 5; }
sub TB_PROJECT_DELGROUP()	{ 6; }
sub TB_PROJECT_LEADGROUP()	{ 7; }
sub TB_PROJECT_ADDUSER()	{ 8; }
sub TB_PROJECT_DELUSER()	{ 9; }
sub TB_PROJECT_MAKEOSID()	{ 10; }
sub TB_PROJECT_DELOSID()	{ 11; }
sub TB_PROJECT_MAKEIMAGEID()	{ 12; }
sub TB_PROJECT_DELIMAGEID()	{ 13; }
sub TB_PROJECT_CREATEEXPT()	{ 14; }
sub TB_PROJECT_CREATELEASE()	{ 15; }
sub TB_PROJECT_MIN()		{ TB_PROJECT_READINFO(); }
sub TB_PROJECT_MAX()		{ TB_PROJECT_CREATELEASE(); }
sub TB_PID_LEN()		{ 48; }
sub TB_GID_LEN()		{ 32; }

# OSIDs
sub TB_OSID_READINFO()		{ 1; }
sub TB_OSID_CREATE()		{ 2; }
sub TB_OSID_DESTROY()		{ 3; }
sub TB_OSID_MIN()		{ TB_OSID_READINFO(); }
sub TB_OSID_MAX()		{ TB_OSID_DESTROY(); }
sub TB_OSID_OSIDLEN()		{ 35; }
sub TB_OSID_OSNAMELEN()		{ 30; }
sub TB_OSID_VERSLEN()		{ 12; }

# Magic OSID constants
sub TB_OSID_MBKERNEL()          { "_KERNEL_"; } # multiboot kernel OSID

# Magic OSID path
sub TB_OSID_PATH_NFS()		{ "" ne "" ? "fs:" : "" };

# Magic MFS constants
sub TB_OSID_FREEBSD_MFS()	{ "FREEBSD-MFS" };
sub TB_OSID_FRISBEE_MFS()	{ "FRISBEE-MFS" };

# OS/Node taint states
sub TB_TAINTSTATE_USERONLY()    { "useronly"; };
sub TB_TAINTSTATE_MUSTRELOAD()  { "mustreload"; };
sub TB_TAINTSTATE_BLACKBOX()    { "blackbox"; };
sub TB_TAINTSTATE_DANGEROUS()   { "dangerous"; };
sub TB_TAINTSTATE_ALL()         { (TB_TAINTSTATE_USERONLY(),
				   TB_TAINTSTATE_MUSTRELOAD(),
				   TB_TAINTSTATE_BLACKBOX(),
				   TB_TAINTSTATE_DANGEROUS()); };

# ImageIDs
#
# Clarification:
# READINFO is read-only access to the image and its contents
# (This is what people get for shared images)
# ACCESS means complete power over the image and its [meta]data
sub TB_IMAGEID_READINFO()	{ 1; }
sub TB_IMAGEID_MODIFYINFO()	{ 2; }
sub TB_IMAGEID_CREATE()		{ 3; }
sub TB_IMAGEID_DESTROY()	{ 4; }
sub TB_IMAGEID_EXPORT()		{ 5; }
sub TB_IMAGEID_ACCESS()		{ 6; }
sub TB_IMAGEID_MIN()		{ TB_IMAGEID_READINFO(); }
sub TB_IMAGEID_MAX()		{ TB_IMAGEID_ACCESS(); }
sub TB_IMAGEID_IMAGEIDLEN()	{ 45; }
sub TB_IMAGEID_IMAGENAMELEN()	{ 30; }

# Lease Access Types
sub LEASE_ACCESS_READINFO()     { 1; }
sub LEASE_ACCESS_READ()         { 2; }
sub LEASE_ACCESS_MODIFYINFO()   { 3; }
sub LEASE_ACCESS_MODIFY()       { 4; }
sub LEASE_ACCESS_DESTROY()      { 5; }
sub LEASE_ACCESS_MIN()          { LEASE_ACCESS_READINFO(); }
sub LEASE_ACCESS_MAX()          { LEASE_ACCESS_DESTROY(); }

# Lease States
sub LEASE_STATE_VALID()         { "valid"; }
sub LEASE_STATE_UNAPPROVED()    { "unapproved"; }
sub LEASE_STATE_FAILED()        { "failed"; }
sub LEASE_STATE_GRACE()         { "grace"; }
sub LEASE_STATE_LOCKED()        { "locked"; }
sub LEASE_STATE_EXPIRED()       { "expired"; }
sub LEASE_STATE_INITIALIZING()  { "initializing"; }

# Lease Error returns
sub LEASE_ERROR_NONE()		{ 0; }
sub LEASE_ERROR_FAILED()	{ -1; }
sub LEASE_ERROR_BUSY()		{ -2; }
sub LEASE_ERROR_GONE()		{ -3; }
sub LEASE_ERROR_ALLOCFAILED()	{ -4; }

# Global permissions identifiers and indexes for *_permissions tables.
sub GLOBAL_PERM_ANON_RO         { "GLOBAL_ANON_RO"; }
sub GLOBAL_PERM_USER_RO         { "GLOBAL_USER_RO"; }
sub GLOBAL_PERM_ANON_RO_IDX     { 1; }
sub GLOBAL_PERM_USER_RO_IDX     { 2; }

# Node Log Types
sub TB_NODELOGTYPE_MISC		{ "misc"; }
sub TB_NODELOGTYPES()		{ ( TB_NODELOGTYPE_MISC() ) ; }
sub TB_DEFAULT_NODELOGTYPE()	{ TB_NODELOGTYPE_MISC(); }

# Node History Stuff.
sub TB_NODEHISTORY_OP_FREE	{ "free"; }
sub TB_NODEHISTORY_OP_ALLOC	{ "alloc"; }
sub TB_NODEHISTORY_OP_MOVE	{ "move"; }
sub TB_NODEHISTORY_OP_CREATE	{ "create"; }
sub TB_NODEHISTORY_OP_DESTROY	{ "destroy"; }

# Reload Types.
sub TB_RELOADTYPE_NETDISK()	{ "netdisk"; }
sub TB_RELOADTYPE_FRISBEE()	{ "frisbee"; }
sub TB_DEFAULT_RELOADTYPE()	{ TB_RELOADTYPE_FRISBEE(); }

# Experiment priorities.
sub TB_EXPTPRIORITY_LOW()	{ 0; }
sub TB_EXPTPRIORITY_HIGH()	{ 20; }

# Assign exit status for too few nodes.
sub TB_ASSIGN_TOOFEWNODES()	{ 2; }

# System PID.
sub TB_OPSPID()			{ $TBOPSPID; }

#
# Events we may want to send
#
sub TBDB_TBEVENT_NODESTATE	{ "TBNODESTATE"; }
sub TBDB_TBEVENT_NODEOPMODE	{ "TBNODEOPMODE"; }
sub TBDB_TBEVENT_CONTROL	{ "TBCONTROL"; }
sub TBDB_TBEVENT_COMMAND	{ "TBCOMMAND"; }
sub TBDB_TBEVENT_EXPTSTATE	{ "TBEXPTSTATE"; }
sub TBDB_TBEVENT_NODESTARTSTATUS{ "TBSTARTSTATUS"; }
sub TBDB_TBEVENT_NODEACCOUNTS   { "TBUPDATEACCOUNTS"; }
sub TBDB_TBEVENT_NODESTATUS     { "TBNODESTATUS"; }
sub TBDB_TBEVENT_FRISBEESTATUS  { "FRISBEESTATUS"; }

#
# For nodes, we use this set of events.
#
sub TBDB_NODESTATE_ISUP()	{ "ISUP"; }
sub TBDB_NODESTATE_ALWAYSUP()	{ "ALWAYSUP"; }
sub TBDB_NODESTATE_REBOOTED()	{ "REBOOTED"; }
sub TBDB_NODESTATE_REBOOTING()	{ "REBOOTING"; }
sub TBDB_NODESTATE_SHUTDOWN()	{ "SHUTDOWN"; }
sub TBDB_NODESTATE_BOOTING()	{ "BOOTING"; }
sub TBDB_NODESTATE_TBSETUP()	{ "TBSETUP"; }
sub TBDB_NODESTATE_RELOADSETUP(){ "RELOADSETUP"; }
sub TBDB_NODESTATE_MFSSETUP()   { "MFSSETUP"; }
sub TBDB_NODESTATE_TBFAILED()	{ "TBFAILED"; }
sub TBDB_NODESTATE_RELOADING()	{ "RELOADING"; }
sub TBDB_NODESTATE_RELOADDONE()	{ "RELOADDONE"; }
sub TBDB_NODESTATE_RELOADDONE_V2(){ "RELOADDONEV2"; }
sub TBDB_NODESTATE_UNKNOWN()	{ "UNKNOWN"; };
sub TBDB_NODESTATE_PXEWAIT()	{ "PXEWAIT"; }
sub TBDB_NODESTATE_PXELIMBO()	{ "PXELIMBO"; }
sub TBDB_NODESTATE_PXEWAKEUP()	{ "PXEWAKEUP"; }
sub TBDB_NODESTATE_PXEFAILED()	{ "PXEFAILED"; }
sub TBDB_NODESTATE_PXEBOOTING()	{ "PXEBOOTING"; }
sub TBDB_NODESTATE_POWEROFF()	{ "POWEROFF"; }
sub TBDB_NODESTATE_GPXEBOOTING(){ "GPXEBOOTING"; }
sub TBDB_NODESTATE_TPMSIGNOFF() { "TPMSIGNOFF"; }
sub TBDB_NODESTATE_SECVIOLATION(){ "SECVIOLATION"; }
sub TBDB_NODESTATE_MFSBOOTING() { "MFSBOOTING"; }
sub TBDB_NODESTATE_VNODEBOOTSTART() { "VNODEBOOTSTART"; }
sub TBDB_NODESTATE_RELOADFAILED() { "RELOADFAILED"; }

sub TBDB_NODEOPMODE_ANY		{ "*"; } # A wildcard opmode
sub TBDB_NODEOPMODE_NORMAL	{ "NORMAL"; }
sub TBDB_NODEOPMODE_DELAYING	{ "DELAYING"; }
sub TBDB_NODEOPMODE_UNKNOWNOS	{ "UNKNOWNOS"; }
sub TBDB_NODEOPMODE_RELOADING	{ "RELOADING"; }
sub TBDB_NODEOPMODE_NORMALv1	{ "NORMALv1"; }
sub TBDB_NODEOPMODE_NORMALv2	{ "NORMALv2"; }
sub TBDB_NODEOPMODE_ALWAYSUP	{ "ALWAYSUP"; }
sub TBDB_NODEOPMODE_MINIMAL	{ "MINIMAL"; }
sub TBDB_NODEOPMODE_PCVM	{ "PCVM"; }
sub TBDB_NODEOPMODE_RELOAD	{ "RELOAD"; }
sub TBDB_NODEOPMODE_RELOADMOTE	{ "RELOAD-MOTE"; }
sub TBDB_NODEOPMODE_RELOADUE	{ "RELOAD-UE"; }
sub TBDB_NODEOPMODE_SECUREBOOT  { "SECUREBOOT"; }
sub TBDB_NODEOPMODE_SECURELOAD  { "SECURELOAD"; }
sub TBDB_NODEOPMODE_RELOADPCVM	{ "RELOAD-PCVM"; }
sub TBDB_NODEOPMODE_RELOADPUSH	{ "RELOAD-PUSH"; }
sub TBDB_NODEOPMODE_DELAY	{ "DELAY"; }
sub TBDB_NODEOPMODE_BOOTWHAT	{ "_BOOTWHAT_"; } # A redirection opmode
sub TBDB_NODEOPMODE_UNKNOWN	{ "UNKNOWN"; }

sub TBDB_COMMAND_REBOOT         { "REBOOT"; }
sub TBDB_COMMAND_POWEROFF       { "POWEROFF"; }
sub TBDB_COMMAND_POWERON        { "POWERON"; }
sub TBDB_COMMAND_POWERCYCLE     { "POWERCYCLE"; }

sub TBDB_STATED_TIMEOUT_REBOOT  { "REBOOT"; }
sub TBDB_STATED_TIMEOUT_NOTIFY  { "NOTIFY"; }
sub TBDB_STATED_TIMEOUT_CMDRETRY{ "CMDRETRY"; }

sub TBDB_ALLOCSTATE_FREE_CLEAN()       { "FREE_CLEAN"; }
sub TBDB_ALLOCSTATE_FREE_DIRTY()       { "FREE_DIRTY"; }
sub TBDB_ALLOCSTATE_DOWN()             { "DOWN"; }
sub TBDB_ALLOCSTATE_DEAD()             { "DEAD"; }
sub TBDB_ALLOCSTATE_RELOAD_TO_FREE()   { "RELOAD_TO_FREE"; }
sub TBDB_ALLOCSTATE_RELOAD_PENDING()   { "RELOAD_PENDING"; }
sub TBDB_ALLOCSTATE_RES_RELOAD()       { "RES_RELOAD"; }
sub TBDB_ALLOCSTATE_RES_REBOOT_DIRTY() { "RES_REBOOT_DIRTY"; }
sub TBDB_ALLOCSTATE_RES_REBOOT_CLEAN() { "RES_REBOOT_CLEAN"; }
sub TBDB_ALLOCSTATE_RES_INIT_DIRTY()   { "RES_INIT_DIRTY"; }
sub TBDB_ALLOCSTATE_RES_INIT_CLEAN()   { "RES_INIT_CLEAN"; }
sub TBDB_ALLOCSTATE_RES_READY()        { "RES_READY"; }
sub TBDB_ALLOCSTATE_RES_RECONFIG()     { "RES_RECONFIG"; }
sub TBDB_ALLOCSTATE_RES_REBOOT()       { "RES_REBOOT"; }
sub TBDB_ALLOCSTATE_RES_TEARDOWN()     { "RES_TEARDOWN"; }
sub TBDB_ALLOCSTATE_UNKNOWN()          { "UNKNOWN"; };

sub TBDB_TBCONTROL_PXERESET	{ "PXERESET"; }
sub TBDB_TBCONTROL_RESET	{ "RESET"; }
sub TBDB_TBCONTROL_RELOADDONE	{ "RELOADDONE"; }
sub TBDB_TBCONTROL_RELOADDONE_V2{ "RELOADDONEV2"; }
sub TBDB_TBCONTROL_TIMEOUT	{ "TIMEOUT"; }
sub TBDB_TBCONTROL_PXEBOOT	{ "PXEBOOT"; }
sub TBDB_TBCONTROL_BOOTING	{ "BOOTING"; }
sub TBDB_TBCONTROL_CHECKGENISUP	{ "CHECKGENISUP"; }

# Constant we use for the timeout field when there is no timeout for a state
sub TBDB_NO_STATE_TIMEOUT	{ 0; }

#
# Node name we use in the widearea_* tables to represent a generic local node.
# All local nodes are considered to have the same network characteristcs.
#
sub TBDB_WIDEAREA_LOCALNODE     { "boss"; }

#
# We should list all of the DB limits.
#
sub DBLIMIT_NSFILESIZE()	{ (2**24 - 1); }

#
# Virtual nodes must operate within a restricted port range. The range
# is effective across all virtual nodes in the experiment. When an
# experiment is swapped in, allocate a subrange from this and setup
# all the vnodes to allocate from that range. We tell the user this
# range so this they can set up their programs to operate in that range.
#
# XXX this should be obsolete, dating from the days of FreeBSD jail-based
# vnodes. But we continue to maintain the pretense for now.
#
sub TBDB_LOWVPORT()		{ 25000; }
sub TBDB_MAXVPORT()		{ 60000; }
sub TBDB_PORTRANGE()		{ 200;   }

#
# STATS constants.
#
sub TBDB_STATS_PRELOAD()	{ "preload"; }
sub TBDB_STATS_START()		{ "start"; }
sub TBDB_STATS_TERMINATE()	{ "destroy"; }
sub TBDB_STATS_SWAPIN()		{ "swapin"; }
sub TBDB_STATS_SWAPOUT()	{ "swapout"; }
sub TBDB_STATS_SWAPMODIFY()	{ "swapmod"; }
sub TBDB_STATS_SWAPUPDATE()	{ "swapupdate"; }
sub TBDB_STATS_FLAGS_IDLESWAP()	{ 0x01; }
sub TBDB_STATS_FLAGS_PREMODIFY(){ 0x02; }
sub TBDB_STATS_FLAGS_START()    { 0x04; }
sub TBDB_STATS_FLAGS_PRESWAPIN(){ 0x08; }
sub TBDB_STATS_FLAGS_BATCHCTRL(){ 0x10; }
sub TBDB_STATS_FLAGS_MODHOSED() { 0x20; }
sub TBDB_STATS_FLAGS_MODSWAPOUT() { 0x40; }

# Jail.
sub TBDB_JAILIPBASE()		{ "172.17.0.0"; }
sub TBDB_JAILIPMASK()		{ "255.240.0.0"; }

# Frisbee.
sub TBDB_FRISBEEMCBASEADDR()	{ "239.67.170:6000"; }

# Reserved node "roles"
sub TBDB_RSRVROLE_NODE()	{ "node"; }
sub TBDB_RSRVROLE_VIRTHOST()	{ "virthost"; }
sub TBDB_RSRVROLE_DELAYNODE()	{ "delaynode"; }
sub TBDB_RSRVROLE_SIMHOST()	{ "simhost"; }
sub TBDB_RSRVROLE_STORAGEHOST()	{ "storagehost"; }

# Interfaces roles.
sub TBDB_IFACEROLE_CONTROL()	{ "ctrl"; }
sub TBDB_IFACEROLE_EXPERIMENT()	{ "expt"; }
sub TBDB_IFACEROLE_JAIL()	{ "jail"; }
sub TBDB_IFACEROLE_FAKE()	{ "fake"; }
sub TBDB_IFACEROLE_GW()		{ "gw"; }
sub TBDB_IFACEROLE_OTHER()	{ "other"; }
sub TBDB_IFACEROLE_OUTER_CONTROL(){ "outer_ctrl"; }
sub TBDB_IFACEROLE_MANAGEMENT()	{ "mngmnt"; }

# Wire types.
sub TBDB_WIRETYPE_NODE()          { "Node"; }
sub TBDB_WIRETYPE_SERIAL()        { "Serial"; }
sub TBDB_WIRETYPE_POWER()         { "Power"; }
sub TBDB_WIRETYPE_DNARD()         { "Dnard"; }
sub TBDB_WIRETYPE_CONTROL()       { "Control"; }
sub TBDB_WIRETYPE_TRUNK()         { "Trunk"; }
sub TBDB_WIRETYPE_OUTERCONTROL()  { "OuterControl"; }
sub TBDB_WIRETYPE_UNUSED()        { "Unused"; }
sub TBDB_WIRETYPE_MANAGEMENT()    { "Management"; }

# Routertypes.
sub TBDB_ROUTERTYPE_NONE()	{ "none"; }
sub TBDB_ROUTERTYPE_OSPF()	{ "ospf"; }
sub TBDB_ROUTERTYPE_STATIC()	{ "static"; }
sub TBDB_ROUTERTYPE_MANUAL()	{ "manual"; }

# User Interface types.
sub TBDB_USER_INTERFACE_EMULAB(){ "emulab"; }
sub TBDB_USER_INTERFACE_PLAB()	{ "plab"; }

# Key Stuff
sub TBDB_EVENTKEY($$)	{ TBExptUserDir($_[0],$_[1]) . "/tbdata/eventkey"; }
sub TBDB_WEBKEY($$)	{ TBExptUserDir($_[0],$_[1]) . "/tbdata/webkey"; }

# Security Levels.
sub TBDB_SECLEVEL_GREEN()	{ 0; }
sub TBDB_SECLEVEL_BLUE()	{ 1; }
sub TBDB_SECLEVEL_YELLOW()	{ 2; }
sub TBDB_SECLEVEL_ORANGE()	{ 3; }
sub TBDB_SECLEVEL_RED()		{ 4; }

# This is the level at which we get extremely cautious when swapping out
sub TBDB_SECLEVEL_ZAPDISK()	{ TBDB_SECLEVEL_YELLOW(); }

#
# A hash of all tables that contain information about physical nodes - the
# value for each key is the list of columns that could contain the node's ID.
#
sub TBDB_PHYSICAL_NODE_TABLES() {
    return (
	'blockstore_state'	=> [ 'node_id' ],
	'blockstores'		=> [ 'node_id' ],
	'current_reloads'	=> [ 'node_id' ],
	'delays'		=> [ 'node_id' ],
	'iface_counters'	=> [ 'node_id' ],
	'interfaces'		=> [ 'node_id' ],
	'interface_settings'	=> [ 'node_id' ],
	'interface_state'	=> [ 'node_id' ],
	'interfaces_rf_limit'	=> [ 'node_id' ],
	'last_reservation'	=> [ 'node_id' ],
	'linkdelays'		=> [ 'node_id' ],
	'location_info'		=> [ 'node_id' ],
	'next_reserve'		=> [ 'node_id' ],
	'node_activity'		=> [ 'node_id' ],
	'node_auxtypes'		=> [ 'node_id' ],
	'node_attributes'	=> [ 'node_id' ],
	'node_features'		=> [ 'node_id' ],
	'node_hostkeys'		=> [ 'node_id' ],
	'node_idlestats'	=> [ 'node_id' ],
	'node_status'   	=> [ 'node_id' ],
	'node_rusage'		=> [ 'node_id' ],
	'node_rf_reports'       => [ 'node_id' ],
	'nodeipportnum'		=> [ 'node_id' ],
	'nodes'			=> [ 'node_id', 'phys_nodeid' ],
	'nodeuidlastlogin'	=> [ 'node_id' ],
	'ntpinfo'		=> [ 'node_id' ],
	'outlets'		=> [ 'node_id' ],
	'outlets_remoteauth'	=> [ 'node_id' ],
	'partitions'		=> [ 'node_id' ],
	'plab_slice_nodes'	=> [ 'node_id' ],
	'port_counters'		=> [ 'node_id' ],
	'reserved'		=> [ 'node_id' ],
	'scheduled_reloads'	=> [ 'node_id' ],
	'state_triggers'	=> [ 'node_id' ],
	'switch_stacks'		=> [ 'node_id' ],
	'tiplines'		=> [ 'node_id' ],
	'tmcd_redirect'		=> [ 'node_id' ],
	'uidnodelastlogin'	=> [ 'node_id' ],
	'v2pmap'		=> [ 'node_id' ],
	'vinterfaces'		=> [ 'node_id' ],
	'widearea_nodeinfo'	=> [ 'node_id' ],
	'widearea_accounts'	=> [ 'node_id' ],
	'widearea_delays'	=> [ 'node_id1', 'node_id2' ],
	'widearea_recent'	=> [ 'node_id1', 'node_id2' ],
	'wires'			=> [ 'node_id1', 'node_id2' ],
	'node_startloc'		=> [ 'node_id' ],
	'node_bootlogs'		=> [ 'node_id' ],
	'plab_mapping'          => [ 'node_id' ],
	'subbosses'		=> [ 'node_id' ],
	'node_licensekeys'	=> [ 'node_id' ],
	'node_utilization'	=> [ 'node_id' ],
	'tcp_proxy'             => [ 'node_id' ]
    );
}

# 
# Node DB tables that contain history information.
# When deleting nodes, we typically want to retain this information.
#
sub TBDB_PHYSICAL_NODE_HISTORY_TABLES() {
    return (
	'node_history'		=> [ 'node_id' ],
	'nodelog'		=> [ 'node_id' ],
	'node_utilization'      => [ 'node_id' ],
    );
}

#
# Convert a trust string to the above numeric values.
#
sub TBTrustConvert($)
{
    my ($trust_string) = @_;
    my $trust_value = 0;

    #
    # Convert string to value. Perhaps the DB should have done it this way?
    #
    if ($trust_string eq "none") {
	$trust_value = PROJMEMBERTRUST_NONE();
    }
    elsif ($trust_string eq "user") {
	$trust_value = PROJMEMBERTRUST_USER();
    }
    elsif ($trust_string eq "local_root") {
	$trust_value = PROJMEMBERTRUST_LOCALROOT();
    }
    elsif ($trust_string eq "group_root") {
	$trust_value = PROJMEMBERTRUST_GROUPROOT();
    }
    elsif ($trust_string eq "project_root") {
	$trust_value = PROJMEMBERTRUST_PROJROOT();
    }
    elsif ($trust_string eq "admin") {
	$trust_value = PROJMEMBERTRUST_ADMIN();
    }
    else {
	    die("*** Invalid trust value $trust_string!");
    }

    return $trust_value;
}

#
# Return true if the given trust string is >= to the minimum required.
# The trust value can be either numeric or a string; if a string its
# first converted to the numeric equiv.
#
sub TBMinTrust($$)
{
    my ($trust_value, $minimum) = @_;

    if ($minimum < PROJMEMBERTRUST_NONE() ||
	$minimum > PROJMEMBERTRUST_ADMIN()) {
	    die("*** Invalid minimum trust $minimum!");
    }

    #
    # Sleazy? How do you do a typeof in perl?
    #
    if (length($trust_value) != 1) {
	$trust_value = TBTrustConvert($trust_value);
    }

    return $trust_value >= $minimum;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
