/*
 * Copyright (c) 2000-2021 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <signal.h>
#include <stdarg.h>
#include <assert.h>
#include <sys/wait.h>
#include <sys/fcntl.h>
#include <sys/syscall.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <paths.h>
#include <setjmp.h>
#include <pwd.h>
#include <grp.h>
#include <mysql/mysql.h>
#include "tmcd.h"
#include "config.h"
#include "ssl.h"
#include "log.h"
#include "tbdefs.h"
#include "bsdefs.h"
#include "bootwhat.h"
#include "bootinfo.h"

#ifdef EVENTSYS
#include "event.h"
#endif

/* XXX: Not sure this is okay! */
#include "tpm.h"

/*
 * XXX This needs to be localized!
 */
#define FSPROJDIR	FSNODE ":" FSDIR_PROJ
#define FSGROUPDIR	FSNODE ":" FSDIR_GROUPS
#define FSUSERDIR	FSNODE ":" FSDIR_USERS
#ifdef  FSDIR_SHARE
#define FSSHAREDIR	FSNODE ":" FSDIR_SHARE
#endif
#ifdef  FSDIR_SCRATCH
#define FSSCRATCHDIR	FSNODE ":" FSDIR_SCRATCH
#endif
/* XXX InstaGeni Rack Hack. Hack until I decide on a better way */
#define FSJAILIP       "172.17.253.254"
#define PROJDIR		PROJROOT_DIR
#define GROUPDIR	GROUPSROOT_DIR
#define USERDIR		USERSROOT_DIR
#define SCRATCHDIR	SCRATCHROOT_DIR
#define SHAREDIR	SHAREROOT_DIR
#define NETBEDDIR	"/netbed"
#define PLISALIVELOGDIR "/usr/testbed/log/plabisalive"
#define RELOADPID	"emulab-ops"
#define RELOADEID	"reloading"
#define FSHOSTID	"/usr/testbed/etc/fshostid"
#define DOTSFS		".sfs"
#define RUNASUSER	"nobody"
#define RUNASGROUP	"nobody"
#define NTPCNAME	"ntp1"
#define PROTOUSER	"elabman"
#define PRIVKEY_LEN	128
#define URN_LEN		128
#define XSTRINGIFY(s)   STRINGIFY(s)
#define STRINGIFY(s)	#s

/* XXX backward compat */
#ifndef TBCOREDIR
#define	TBCOREDIR	TBROOT "/tmp"
#endif

/* socket read/write timeouts in ms */
#define READTIMO	3000
#define WRITETIMO	3000

#define TESTMODE
#define DEFAULTNETMASK	"255.255.255.0"
/* This can be tossed once all the changes are in place */
static char *
CHECKMASK(char *arg)
{
	if (arg && arg[0])
		return arg;

	error("No netmask defined!\n");
	return DEFAULTNETMASK;
}
/* #define CHECKMASK(arg)  ((arg) && (arg[0]) ? (arg) : DEFAULTNETMASK) */

#define DISKTYPE	"ad"
#define DISKNUM		0

/* Compiled in slothd parameters
 *
 * 1 - reg_interval  2 - agg_interval  3 - load_thresh
 * 4 - expt_thresh   5 - ctl_thresh
 */
#define SDPARAMS        "reg=300 agg=5 load=1 expt=5 ctl=1000"

/*
 * Compiled in tarball/rpm param.
 * Should come out of the DB.
 */
#ifdef SPEWFROMOPS
#define TARRPM_SERVER	USERNODE
#else
#define TARRPM_SERVER	BOSSNODE
#endif

#ifdef IMAGEPROVENANCE
#define WITHPROVENANCE	1
#else
#define WITHPROVENANCE	0
#endif

#ifdef WITHZFS
#undef WITHZFS
#define WITHZFS	1
#else
#define WITHZFS	0
#endif

/* Defined in configure and passed in via the makefile */
#define DBNAME_SIZE	64
#define HOSTID_SIZE	(32+64)
#define DEFAULT_DBNAME	TBDBNAME

/* For secure disk loading */
#define SECURELOAD_OPMODE "SECURELOAD"
#define SECURELOAD_STATE  "RELOADSETUP"

/* Our answer to "geni-get --version" */
#define GENI_VERSION "1"

/* Taint support */
#define TB_TAINTSTATE_BLACKBOX  1
#define TB_TAINTSTATE_USERONLY  2
#define TB_TAINTSTATE_DANGEROUS 4
#define TB_TAINTSTATE_MUSTRELOAD  8
#define HAS_ANY_TAINTS(tset, tcheck) (tset & tcheck)
#define HAS_ALL_TAINTS(tset, tcheck) ((tset & tcheck) == tcheck)
#define HAS_TAINT(tset, tcheck) HAS_ALL_TAINTS(tset, tcheck)

/* Per-experiment root keypair support */
#define TB_ROOTKEYS_NONE	0
#define TB_ROOTKEYS_PRIVATE	1
#define TB_ROOTKEYS_PUBLIC	2
#define TB_ROOTKEYS_BOTH	3

typedef struct {
	char pid[TBDB_FLEN_PID];
	char gid[TBDB_FLEN_GID];
	char name[TBDB_FLEN_IMAGENAME];
	char version[11]; /* Max size of a 32-bit int in string form. */
	char *path; /* A dynamically-allocated path string, if relevant. */
} imstrings_t;

int		debug = 0;
static int	verbose = 0;
static int	insecure = 0;
static int	byteswritten = 0;
static char	pidfile[MAXPATHLEN];
static char     dbname[DBNAME_SIZE];
static struct in_addr myipaddr;
static struct in_addr cnet, cmask, jnet, jmask;
static char	fshostid[HOSTID_SIZE];
static int	nodeidtoexp(char *nodeid, char *pid, char *eid, char *gid);
static void	tcpserver(int sock, int portnum);
static void	udpserver(int sock, int portnum);
static int      handle_request(int, struct sockaddr_in *, char *, int, int);
static int      checkcerts(char*);
static int	makesockets(int portnum, int *udpsockp, int *tcpsockp);
int		client_writeback(int sock, void *buf, int len, int tcp);
void		client_writeback_done(int sock, struct sockaddr_in *client);
MYSQL_RES *	mydb_query(char *query, int ncols, ...);
int		mydb_update(char *query, ...);
static int	safesymlink(char *name1, char *name2);
static int      getImageInfo(char *path, char *nodeid, char *pid, char *imagename,
			     unsigned int *mtime, off_t *isize);
static int	getrandomchars(char *buf, int len);

/* socket timeouts */
static int	readtimo = READTIMO;
static int	writetimo = WRITETIMO;

/* thread support */
#define MAXCHILDREN	20
#define MINCHILDREN	8
static int	numchildren;
static int	maxchildren       = 13;
static int      num_udpservers    = 3;
static int      num_altudpservers = 1;
static int      num_alttcpservers = 1;
static int	mypid;
static volatile int killme;

/* Output macro to check for string overflow */
#define OUTPUT(buf, size, format...) \
({ \
	int __count__ = snprintf((buf), (size), ##format); \
        \
        if (__count__ >= (size)) { \
		error("Not enough room in output buffer! line %d.\n", __LINE__);\
		return 1; \
	} \
	__count__; \
})

/*
 * This structure is passed to each request function. The intent is to
 * reduce the number of DB queries per request to a minimum.
 */
typedef struct {
	struct in_addr  client;
	int		allocated;
	int		jailflag;
	int		isvnode;
	int		isroutable_vnode; /* only valid if isvnode==1 */
	int		asvnode;
	int		issubnode;
	int		islocal;
	int		isdedicatedwa;
	int		iscontrol;
	int		isplabdslice;
	int		isplabsvc;
	int		elab_in_elab;
        int		singlenet;	  /* Modifier for elab_in_elab */
	int		update_accounts;
	int		exptidx;
	int		creator_idx;
	int		swapper_idx;
	int		swapper_isadmin;
        int		genisliver_idx;
        int		geniflags;
	int		isnonlocal_pid;
	unsigned short  taintstates;
	unsigned short  experiment_keys;
	char            nfsmounts[TBDB_FLEN_TINYTEXT];
	char		nodeid[TBDB_FLEN_NODEID];
	char		vnodeid[TBDB_FLEN_NODEID];
	char		pnodeid[TBDB_FLEN_NODEID]; /* XXX */
	char		pid[TBDB_FLEN_PID];
	char		eid[TBDB_FLEN_EID];
	char		gid[TBDB_FLEN_GID];
	char		nickname[TBDB_FLEN_VNAME];
	char		type[TBDB_FLEN_NODETYPE];
	char		class[TBDB_FLEN_NODECLASS];
        char		ptype[TBDB_FLEN_NODETYPE];	/* Of physnode */
	char		pclass[TBDB_FLEN_NODECLASS];	/* Of physnode */
	char		creator[TBDB_FLEN_UID];
	char		swapper[TBDB_FLEN_UID];
	char		syncserver[TBDB_FLEN_VNAME];	/* The vname */
	char		keyhash[TBDB_FLEN_PRIVKEY];
	char		eventkey[TBDB_FLEN_PRIVKEY];
	char		sfshostid[TBDB_FLEN_SFSHOSTID];
	char		testdb[TBDB_FLEN_TINYTEXT];
	char		sharing_mode[TBDB_FLEN_TINYTEXT];
	char		erole[TBDB_FLEN_TINYTEXT];
	char            privkey[PRIVKEY_LEN+1];
	char		nodeuuid[TBDB_FLEN_UUID];
        /* This key is a replacement for privkey, on protogeni resources */
	char            external_key[PRIVKEY_LEN+1];
} tmcdreq_t;
static int	iptonodeid(struct in_addr, tmcdreq_t *, char*);
static int	checkdbredirect(tmcdreq_t *);
static int      sendstoreconf(int sock, int tcp, tmcdreq_t *reqp, char *bscmd, 
			      char *vname, int dopersist, char *localproto);
static int      get_imagestrings(tmcdreq_t *reqp, imstrings_t *imstrings);
static void     free_imagestrings_content(imstrings_t *imstrings);

#ifdef EVENTSYS
int			myevent_send(address_tuple_t address);
static event_handle_t	event_handle = NULL;
#endif

/*
 * Commands we support.
 */
#define COMMAND_PROTOTYPE(x) \
	static int \
	x(int sock, tmcdreq_t *reqp, char *rdata, int tcp, int vers)

COMMAND_PROTOTYPE(doreboot);
COMMAND_PROTOTYPE(donodeid);
COMMAND_PROTOTYPE(donodetype);
COMMAND_PROTOTYPE(donodeuuid);
COMMAND_PROTOTYPE(domanifest);
COMMAND_PROTOTYPE(dostatus);
COMMAND_PROTOTYPE(doifconfig);
COMMAND_PROTOTYPE(doaccounts);
COMMAND_PROTOTYPE(dobridges);
COMMAND_PROTOTYPE(dodelay);
COMMAND_PROTOTYPE(dolinkdelay);
COMMAND_PROTOTYPE(dohosts);
COMMAND_PROTOTYPE(dorpms);
COMMAND_PROTOTYPE(dodeltas);
COMMAND_PROTOTYPE(dotarballs);
COMMAND_PROTOTYPE(doblobs);
COMMAND_PROTOTYPE(dostartcmd);
COMMAND_PROTOTYPE(dostartstat);
COMMAND_PROTOTYPE(doready);
COMMAND_PROTOTYPE(doreadycount);
COMMAND_PROTOTYPE(dostorageconfig);
COMMAND_PROTOTYPE(domounts);
COMMAND_PROTOTYPE(dosfshostid);
COMMAND_PROTOTYPE(doloadinfo);
COMMAND_PROTOTYPE(doreset);
COMMAND_PROTOTYPE(dorouting);
COMMAND_PROTOTYPE(dotrafgens);
COMMAND_PROTOTYPE(donseconfigs);
COMMAND_PROTOTYPE(dostate);
COMMAND_PROTOTYPE(docreator);
COMMAND_PROTOTYPE(dotunnels);
COMMAND_PROTOTYPE(dovnodelist);
COMMAND_PROTOTYPE(dosubnodelist);
COMMAND_PROTOTYPE(doisalive);
COMMAND_PROTOTYPE(doipodinfo);
COMMAND_PROTOTYPE(dontpinfo);
COMMAND_PROTOTYPE(dontpdrift);
COMMAND_PROTOTYPE(dojailconfig);
COMMAND_PROTOTYPE(doplabconfig);
COMMAND_PROTOTYPE(dosubconfig);
COMMAND_PROTOTYPE(doixpconfig);
COMMAND_PROTOTYPE(doslothdparams);
COMMAND_PROTOTYPE(doprogagents);
COMMAND_PROTOTYPE(dosyncserver);
COMMAND_PROTOTYPE(dokeyhash);
COMMAND_PROTOTYPE(doeventkey);
COMMAND_PROTOTYPE(dofullconfig);
COMMAND_PROTOTYPE(doroutelist);
COMMAND_PROTOTYPE(dorole);
COMMAND_PROTOTYPE(dorusage);
COMMAND_PROTOTYPE(dodoginfo);
COMMAND_PROTOTYPE(dohostkeys);
COMMAND_PROTOTYPE(dotmcctest);
COMMAND_PROTOTYPE(dofwinfo);
COMMAND_PROTOTYPE(dohostinfo);
COMMAND_PROTOTYPE(doemulabconfig);
COMMAND_PROTOTYPE(doeplabconfig);
COMMAND_PROTOTYPE(dolocalize);
COMMAND_PROTOTYPE(dorootpswd);
COMMAND_PROTOTYPE(dobooterrno);
COMMAND_PROTOTYPE(dobootlog);
COMMAND_PROTOTYPE(dobattery);
COMMAND_PROTOTYPE(dotopomap);
COMMAND_PROTOTYPE(douserenv);
COMMAND_PROTOTYPE(dotiptunnels);
COMMAND_PROTOTYPE(dorelayconfig);
COMMAND_PROTOTYPE(dotraceconfig);
COMMAND_PROTOTYPE(doltmap);
COMMAND_PROTOTYPE(doltpmap);
COMMAND_PROTOTYPE(doelvindport);
COMMAND_PROTOTYPE(doplabeventkeys);
COMMAND_PROTOTYPE(dointfcmap);
COMMAND_PROTOTYPE(domotelog);
COMMAND_PROTOTYPE(doportregister);
COMMAND_PROTOTYPE(dobootwhat);
COMMAND_PROTOTYPE(dotpmblob);
COMMAND_PROTOTYPE(dotpmpubkey);
COMMAND_PROTOTYPE(dotpmdummy);
COMMAND_PROTOTYPE(dodhcpdconf);
COMMAND_PROTOTYPE(dosecurestate);
COMMAND_PROTOTYPE(doquoteprep);
COMMAND_PROTOTYPE(doimagekey);
COMMAND_PROTOTYPE(donodeattributes);
COMMAND_PROTOTYPE(dodisks);
COMMAND_PROTOTYPE(doarpinfo);
COMMAND_PROTOTYPE(dohwinfo);
COMMAND_PROTOTYPE(dotiplineinfo);
COMMAND_PROTOTYPE(doimageid);
COMMAND_PROTOTYPE(doimagesize);
COMMAND_PROTOTYPE(dopnetnodeattrs);
COMMAND_PROTOTYPE(doserviceinfo);
COMMAND_PROTOTYPE(dosubbossinfo);
COMMAND_PROTOTYPE(dopublicaddrinfo);
COMMAND_PROTOTYPE(dohwcollect);
COMMAND_PROTOTYPE(dowbstore);
COMMAND_PROTOTYPE(doattenuatorlist);
COMMAND_PROTOTYPE(doattenuator);
#if PROTOGENI_SUPPORT
COMMAND_PROTOTYPE(dogeniclientid);
COMMAND_PROTOTYPE(dogenisliceurn);
COMMAND_PROTOTYPE(dogenisliceemail);
COMMAND_PROTOTYPE(dogeniuserurn);
COMMAND_PROTOTYPE(dogeniuseremail);
COMMAND_PROTOTYPE(dogenigeniuser);
COMMAND_PROTOTYPE(dogenimanifest);
COMMAND_PROTOTYPE(dogenicert);
COMMAND_PROTOTYPE(dogenikey);
COMMAND_PROTOTYPE(dogenicontrolmac);
COMMAND_PROTOTYPE(dogeniversion);
COMMAND_PROTOTYPE(dogenigetversion);
COMMAND_PROTOTYPE(dogenisliverstatus);
COMMAND_PROTOTYPE(dogenistatus);
COMMAND_PROTOTYPE(dogenicommands);
COMMAND_PROTOTYPE(dogeniall);
COMMAND_PROTOTYPE(dogeniparam);
COMMAND_PROTOTYPE(dogenirpccert);
COMMAND_PROTOTYPE(dogeniinvalid);
COMMAND_PROTOTYPE(dogeniportalmanifest);
#endif

/*
 * The fullconfig slot determines what routines get called when pushing
 * out a full configuration. Physnodes get slightly different
 * than vnodes, and at some point we might want to distinguish different
 * types of vnodes (jailed, plab).
 */
#define FULLCONFIG_NONE		0x0
#define FULLCONFIG_PHYS		0x1
#define FULLCONFIG_VIRT		0x2
#define FULLCONFIG_ALL		(FULLCONFIG_PHYS|FULLCONFIG_VIRT)

/*
 * Flags encode a few other random properties of commands
 */
#define F_REMUDP	0x01	/* remote nodes can request using UDP */
#define F_MINLOG	0x02	/* record minimal logging info normally */
#define F_MAXLOG	0x04	/* record maximal logging info normally */
#define F_ALLOCATED	0x08	/* node must be allocated to make call */
#define F_REMNOSSL	0x10	/* remote nodes can request without SSL */
#define F_REMREQSSL	0x20	/* remote nodes must connect with SSL */
#define F_REQTPM	0x40	/* require TPM on client */

struct command {
	char	*cmdname;
	int	fullconfig;
	int	flags;
	int    (*func)(int, tmcdreq_t *, char *, int, int);
} command_array[] = {
	{ "reboot",	  FULLCONFIG_NONE, 0, doreboot },
	{ "nodeid",	  FULLCONFIG_ALL,  0, donodeid },
	{ "nodetype",	  FULLCONFIG_ALL,  0, donodetype },
	{ "nodeuuid",	  FULLCONFIG_ALL,  0, donodeuuid },
	{ "manifest",	  FULLCONFIG_ALL,  0, domanifest },
	{ "status",	  FULLCONFIG_NONE, 0, dostatus },
	{ "ifconfig",	  FULLCONFIG_ALL,  F_ALLOCATED, doifconfig },
	{ "accounts",	  FULLCONFIG_ALL,  F_REMREQSSL, doaccounts },
	{ "delay",	  FULLCONFIG_ALL,  F_ALLOCATED, dodelay },
	{ "bridges",	  FULLCONFIG_ALL,  F_ALLOCATED, dobridges },
	{ "linkdelay",	  FULLCONFIG_ALL,  F_ALLOCATED, dolinkdelay },
	{ "hostnames",	  FULLCONFIG_NONE, F_ALLOCATED, dohosts },
	{ "rpms",	  FULLCONFIG_ALL,  F_ALLOCATED, dorpms },
	{ "deltas",	  FULLCONFIG_NONE, F_ALLOCATED, dodeltas },
	{ "tarballs",	  FULLCONFIG_ALL,  F_ALLOCATED, dotarballs },
	{ "blobs",	  FULLCONFIG_ALL,  F_ALLOCATED, doblobs },
	{ "startupcmd",	  FULLCONFIG_ALL,  F_ALLOCATED, dostartcmd },
	{ "startstatus",  FULLCONFIG_NONE, F_ALLOCATED, dostartstat }, /* Before startstat*/
	{ "startstat",	  FULLCONFIG_NONE, 0, dostartstat },
	{ "readycount",   FULLCONFIG_NONE, F_ALLOCATED, doreadycount },
	{ "ready",	  FULLCONFIG_NONE, F_ALLOCATED, doready },
	{ "storageconfig", FULLCONFIG_ALL, F_ALLOCATED, dostorageconfig},
	{ "mounts",	  FULLCONFIG_ALL,  F_ALLOCATED, domounts },
	{ "sfshostid",	  FULLCONFIG_NONE, F_ALLOCATED, dosfshostid },
	{ "loadinfo",	  FULLCONFIG_NONE, 0, doloadinfo},
	{ "reset",	  FULLCONFIG_NONE, 0, doreset},
	{ "routing",	  FULLCONFIG_ALL,  F_ALLOCATED, dorouting},
	{ "trafgens",	  FULLCONFIG_ALL,  F_ALLOCATED, dotrafgens},
	{ "nseconfigs",	  FULLCONFIG_ALL,  F_ALLOCATED, donseconfigs},
	{ "creator",	  FULLCONFIG_ALL,  F_ALLOCATED, docreator},
	{ "state",	  FULLCONFIG_NONE, 0, dostate},
	{ "tunnels",	  FULLCONFIG_ALL,  F_ALLOCATED, dotunnels},
	{ "vnodelist",	  FULLCONFIG_PHYS, 0, dovnodelist},
	{ "subnodelist",  FULLCONFIG_PHYS, 0, dosubnodelist},
	{ "isalive",	  FULLCONFIG_NONE, F_REMUDP|F_MINLOG, doisalive},
	{ "ipodinfo",	  FULLCONFIG_PHYS, 0, doipodinfo},
	{ "ntpinfo",	  FULLCONFIG_PHYS, 0, dontpinfo},
	{ "ntpdrift",	  FULLCONFIG_NONE, 0, dontpdrift},
	{ "jailconfig",	  FULLCONFIG_VIRT, F_ALLOCATED, dojailconfig},
	{ "plabconfig",	  FULLCONFIG_VIRT, F_ALLOCATED, doplabconfig},
	{ "subconfig",	  FULLCONFIG_NONE, 0, dosubconfig},
        { "sdparams",     FULLCONFIG_PHYS, 0, doslothdparams},
        { "programs",     FULLCONFIG_ALL,  F_ALLOCATED, doprogagents},
        { "syncserver",   FULLCONFIG_ALL,  F_ALLOCATED, dosyncserver},
        { "keyhash",      FULLCONFIG_ALL,  F_ALLOCATED|F_REMREQSSL, dokeyhash},
        { "eventkey",     FULLCONFIG_ALL,  F_ALLOCATED|F_REMREQSSL, doeventkey},
        { "fullconfig",   FULLCONFIG_NONE, F_ALLOCATED, dofullconfig},
        { "routelist",	  FULLCONFIG_PHYS, F_ALLOCATED, doroutelist},
        { "role",	  FULLCONFIG_PHYS, F_ALLOCATED, dorole},
        { "rusage",	  FULLCONFIG_NONE, F_REMUDP|F_MINLOG, dorusage},
        { "watchdoginfo", FULLCONFIG_ALL,  F_REMUDP|F_MINLOG, dodoginfo},
        { "hostkeys",     FULLCONFIG_NONE, 0, dohostkeys},
        { "tmcctest",     FULLCONFIG_NONE, F_MINLOG, dotmcctest},
        { "firewallinfo", FULLCONFIG_ALL,  0, dofwinfo},
        { "hostinfo",     FULLCONFIG_NONE, 0, dohostinfo},
	{ "emulabconfig", FULLCONFIG_NONE, F_ALLOCATED, doemulabconfig},
	{ "eplabconfig",  FULLCONFIG_NONE, F_ALLOCATED, doeplabconfig},
	{ "localization", FULLCONFIG_PHYS, 0, dolocalize},
	{ "rootpswd",     FULLCONFIG_NONE, F_REMREQSSL, dorootpswd},
	{ "booterrno",    FULLCONFIG_NONE, 0, dobooterrno},
	{ "bootlog",      FULLCONFIG_NONE, 0, dobootlog},
	{ "battery",      FULLCONFIG_NONE, F_REMUDP|F_MINLOG, dobattery},
	{ "topomap",      FULLCONFIG_NONE, F_MINLOG|F_ALLOCATED, dotopomap},
	{ "userenv",      FULLCONFIG_ALL,  F_ALLOCATED, douserenv},
	{ "tiptunnels",	  FULLCONFIG_ALL,  F_ALLOCATED, dotiptunnels},
	{ "traceinfo",	  FULLCONFIG_ALL,  F_ALLOCATED, dotraceconfig },
	{ "ltmap",        FULLCONFIG_NONE, F_MINLOG|F_ALLOCATED, doltmap},
	{ "ltpmap",       FULLCONFIG_NONE, F_MINLOG|F_ALLOCATED, doltpmap},
	{ "elvindport",   FULLCONFIG_NONE, 0, doelvindport},
	{ "plabeventkeys",FULLCONFIG_NONE, F_REMREQSSL, doplabeventkeys},
	{ "intfcmap",     FULLCONFIG_NONE, 0, dointfcmap},
	{ "motelog",      FULLCONFIG_ALL,  F_ALLOCATED, domotelog},
	{ "portregister", FULLCONFIG_NONE, F_REMNOSSL, doportregister},
	{ "bootwhat",	  FULLCONFIG_NONE, 0, dobootwhat },
	{ "tpmblob",	  FULLCONFIG_ALL, 0, dotpmblob },
	{ "tpmpubkey",	  FULLCONFIG_ALL, 0, dotpmpubkey },
	{ "tpmdummy",	  FULLCONFIG_ALL, F_REQTPM, dotpmdummy },
	{ "dhcpdconf",	  FULLCONFIG_ALL, 0, dodhcpdconf },
	{ "securestate",  FULLCONFIG_NONE, F_REMREQSSL, dosecurestate},
	{ "quoteprep",    FULLCONFIG_NONE, F_REMREQSSL, doquoteprep},
	{ "imagekey",     FULLCONFIG_NONE, F_REQTPM, doimagekey},
	{ "nodeattributes", FULLCONFIG_ALL, 0, donodeattributes},
	{ "disks",	  FULLCONFIG_ALL, 0, dodisks},
	{ "arpinfo",	  FULLCONFIG_NONE, 0, doarpinfo},
	{ "hwinfo",	  FULLCONFIG_NONE, 0, dohwinfo},
	{ "tiplineinfo",  FULLCONFIG_NONE,  F_ALLOCATED, dotiplineinfo},
	{ "imageinfo",      FULLCONFIG_NONE,  F_ALLOCATED, doimageid},
	{ "imagesize",   FULLCONFIG_NONE,  F_ALLOCATED, doimagesize},
	{ "pnetnodeattrs", FULLCONFIG_NONE, F_ALLOCATED, dopnetnodeattrs},
	{ "serviceinfo",  FULLCONFIG_NONE, 0, doserviceinfo },
	{ "subbossinfo",  FULLCONFIG_NONE, 0, dosubbossinfo },
	{ "publicaddrinfo",  FULLCONFIG_NONE, F_ALLOCATED, dopublicaddrinfo },
	{ "hwcollect",	  FULLCONFIG_NONE, 0, dohwcollect},
	{ "wbstore",	  FULLCONFIG_NONE, 0, dowbstore},
	{ "attenuatorlist", FULLCONFIG_NONE, F_ALLOCATED|F_REMREQSSL, doattenuatorlist },
	{ "attenuator",   FULLCONFIG_NONE, F_ALLOCATED|F_REMREQSSL, doattenuator },
#if PROTOGENI_SUPPORT
	{ "geni_client_id", FULLCONFIG_NONE, 0, dogeniclientid },
	{ "geni_slice_urn", FULLCONFIG_NONE, 0, dogenisliceurn },
	{ "geni_slice_email", FULLCONFIG_NONE, 0, dogenisliceemail },
	{ "geni_user_urn", FULLCONFIG_NONE, 0, dogeniuserurn },
	{ "geni_user_email", FULLCONFIG_NONE, 0, dogeniuseremail },
	/* Yes, "geni_user" is a stupid name.  Wasn't my idea. */
	{ "geni_geni_user", FULLCONFIG_NONE, 0, dogenigeniuser },
	{ "geni_manifest", FULLCONFIG_NONE, 0, dogenimanifest },
	{ "geni_certificate", FULLCONFIG_NONE, 0, dogenicert },
	{ "geni_key", FULLCONFIG_NONE, 0, dogenikey },
	{ "geni_control_mac", FULLCONFIG_NONE, 0, dogenicontrolmac },
	{ "geni_version", FULLCONFIG_NONE, 0, dogeniversion },
	{ "geni_getversion", FULLCONFIG_NONE, 0, dogenigetversion },
	{ "geni_sliverstatus", FULLCONFIG_NONE, 0, dogenisliverstatus },
	{ "geni_status", FULLCONFIG_NONE, 0, dogenistatus },
	{ "geni_commands", FULLCONFIG_NONE, 0, dogenicommands },
	{ "geni_all",     FULLCONFIG_NONE, 0, dogeniall },
	{ "geni_param",   FULLCONFIG_NONE, 0, dogeniparam },
	{ "geni_rpccert",   FULLCONFIG_NONE, 0, dogenirpccert },
	{ "geni_portalmanifest", FULLCONFIG_NONE, 0, dogeniportalmanifest },
	/* A rather ugly hack to avoid making error handling a special case.
	   THIS MUST BE THE LAST ENTRY IN THE ARRAY! */
	{ "geni_invalid", FULLCONFIG_NONE, 0, dogeniinvalid }
#endif
};
static int numcommands = sizeof(command_array)/sizeof(struct command);

char *usagestr =
 "usage: tmcd [-d] [-p #]\n"
 " -d              Turn on debugging. Multiple -d options increase output\n"
 " -p portnum	   Specify a port number to listen on\n"
 " -c num	   Specify number of servers (must be %d <= x <= %d)\n"
 " -v              More verbose logging\n"
 " -i ipaddr       Sets the boss IP addr to return (for multi-homed servers)\n"
 "\n";

void
usage()
{
	fprintf(stderr, usagestr, MINCHILDREN, MAXCHILDREN);
	exit(1);
}

static void
cleanup()
{
	signal(SIGHUP, SIG_IGN);
	killme = 1;
	killpg(0, SIGHUP);
	unlink(pidfile);
}

static void
setverbose(int sig)
{
	signal(sig, SIG_IGN);

	if (sig == SIGUSR1)
		verbose = 1;
	else
		verbose = 0;
	info("verbose logging turned %s\n", verbose ? "on" : "off");

	/* Just the parent sends this */
	if (numchildren)
		killpg(0, sig);
	signal(sig, setverbose);
}

int
main(int argc, char **argv)
{
	int			tcpsock, udpsock, i, ch;
	int			alttcpsock, altudpsock;
	int			status, pid;
	int			portnum = TBSERVER_PORT;
	FILE			*fp;
	char			buf[BUFSIZ];
	struct hostent		*he;
	extern char		build_info[];
	int			server_counts[4]; /* udp,tcp,altudp,alttcp */
	struct {
		int	pid;
		int	which;
	} servers[MAXCHILDREN];

	while ((ch = getopt(argc, argv, "dp:c:Xvi:")) != -1)
		switch(ch) {
		case 'p':
			portnum = atoi(optarg);
			break;
		case 'd':
			debug++;
			break;
		case 'c':
			maxchildren = atoi(optarg);
			break;
		case 'X':
			insecure = 1;
			break;
		case 'v':
			verbose++;
			break;
		case 'i':
			if (inet_aton(optarg, &myipaddr) == 0) {
				fprintf(stderr, "invalid IP address %s\n",
					optarg);
				usage();
			}
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (argc)
		usage();
	if (maxchildren < MINCHILDREN || maxchildren > MAXCHILDREN)
		usage();

#ifdef  WITHSSL
	if (tmcd_server_sslinit()) {
		error("SSL init failed!\n");
		exit(1);
	}
#endif
	if (debug)
		loginit(0, 0);
	else {
		/* Become a daemon */
		if (chdir(TBCOREDIR)) {
			daemon(0, 0);
		} else {
			daemon(1, 0);
		}
		loginit(1, "tmcd");
	}
	info("daemon starting (version %d)\n", CURRENT_VERSION);
	info("%s\n", build_info);

	/*
	 * Get FS's SFS hostid
	 * XXX This approach is somewhat kludgy
	 */
	strcpy(fshostid, "");
	if (access(FSHOSTID,R_OK) == 0) {
		fp = fopen(FSHOSTID, "r");
		if (!fp) {
			error("Failed to get FS's hostid");
		}
		else {
			fgets(fshostid, HOSTID_SIZE, fp);
			if (rindex(fshostid, '\n')) {
				*rindex(fshostid, '\n') = 0;
				if (debug) {
				    info("fshostid: %s\n", fshostid);
				}
			}
			else {
				error("fshostid from %s may be corrupt: %s",
				      FSHOSTID, fshostid);
			}
			fclose(fp);
		}
	}

	/*
	 * Grab our IP for security check below.
	 */
	if (myipaddr.s_addr == 0) {
#ifdef	LBS
		strcpy(buf, BOSSNODE);
#else
		if (gethostname(buf, sizeof(buf)) < 0)
			pfatal("getting hostname");
#endif
		if ((he = gethostbyname(buf)) == NULL) {
			error("Could not get IP (%s) - %s\n",
			      buf, hstrerror(h_errno));
			exit(1);
		}
		memcpy((char *)&myipaddr, he->h_addr, he->h_length);
	}

	/*
	 * If we were given a port on the command line, don't open the
	 * alternate ports
	 */
	if (portnum != TBSERVER_PORT) {
	    if (makesockets(portnum, &udpsock, &tcpsock) < 0) {
		error("Could not make sockets!");
		exit(1);
	    }
	    num_alttcpservers = num_altudpservers = 0;
	} else {
	    if (makesockets(portnum, &udpsock, &tcpsock) < 0 ||
		makesockets(TBSERVER_PORT2, &altudpsock, &alttcpsock) < 0) {
		    error("Could not make sockets!");
		    exit(1);
	    }
	}

	/*
	 * Get control net info into a usable form.
	 */
	if (!inet_aton(CONTROL_NETWORK, &cnet) ||
	    !inet_aton(CONTROL_NETMASK, &cmask) ||
	    !inet_aton(JAILIPBASE, &jnet) ||
	    !inet_aton(JAILIPMASK, &jmask)) {
		error("Could not convert control net addrs/masks");
		exit(1);
	}
	cnet.s_addr &= cmask.s_addr;
	jnet.s_addr &= jmask.s_addr;

	signal(SIGTERM, cleanup);
	signal(SIGINT, cleanup);
	signal(SIGHUP, cleanup);
	signal(SIGUSR1, setverbose);
	signal(SIGUSR2, setverbose);

	/*
	 * Stash the pid away.
	 */
	mypid = getpid();
	sprintf(pidfile, "%s/tmcd.pid", _PATH_VARRUN);
	fp = fopen(pidfile, "w");
	if (fp != NULL) {
		fprintf(fp, "%d\n", mypid);
		(void) fclose(fp);
	}

	/*
	 * Change to non-root user!
	 */
	if (geteuid() == 0) {
		struct passwd	*pw;
		uid_t		uid;
		gid_t		gid;

		/*
		 * Must be a valid user of course.
		 */
		if ((pw = getpwnam(RUNASUSER)) == NULL) {
			error("invalid user: %s", RUNASUSER);
			exit(1);
		}
		uid = pw->pw_uid;
		gid = pw->pw_gid;

		if (setgroups(1, &gid)) {
			errorc("setgroups");
			exit(1);
		}
		if (setgid(gid)) {
			errorc("setgid");
			exit(1);
		}
		if (setuid(uid)) {
			errorc("setuid");
			exit(1);
		}
		info("Flipped to user/group %d/%d\n", uid, gid);
	}

	/*
	 * Now fork a set of children to handle requests. We keep the
	 * pool at a set level. There are 4 types of servers, each getting
	 * a different number of servers. We do it this cause otherwise
	 * we have to deal with the select storm problem; a bunch of processes
	 * select on the same set of file descriptors, and all get woken up
	 * when something comes in, then all read from the socket but only
	 * one gets it and the others go back to sleep. There are various ways
	 * to deal with this problem, but all of them are a lot more code!
	 */
	server_counts[0] = num_udpservers;
	server_counts[1] = num_altudpservers;
	server_counts[2] = num_alttcpservers;
	server_counts[3] = maxchildren -
		(num_udpservers + num_altudpservers + num_altudpservers);
	bzero(servers, sizeof(servers));

	while (1) {
		while (!killme && numchildren < maxchildren) {
			int which = 3;

			/*
			 * Find which kind of server is short one.
			 */
			for (i = 0; i < 4; i++) {
				if (server_counts[i]) {
					which = i;
					break;
				}
			}

			if ((pid = fork()) < 0) {
				errorc("forking server");
				goto done;
			}
			if (pid) {
				server_counts[which]--;
				/*
				 * Find free slot
				 */
				for (i = 0; i < maxchildren; i++) {
					if (!servers[i].pid)
						break;
				}
				servers[i].pid   = pid;
				servers[i].which = which;
				numchildren++;
				continue;
			}
			/* Poor way of knowing parent/child */
			numchildren = 0;
			mypid = getpid();

			/* Child does useful work! Never Returns! */
			signal(SIGTERM, SIG_DFL);
			signal(SIGINT, SIG_DFL);
			signal(SIGHUP, SIG_DFL);

			switch (which) {
			case 0: udpserver(udpsock, portnum);
				break;
			case 1: udpserver(altudpsock, TBSERVER_PORT2);
				break;
			case 2: tcpserver(alttcpsock, TBSERVER_PORT2);
				break;
			case 3: tcpserver(tcpsock, portnum);
				break;
			}
			exit(-1);
		}

		/*
		 * Parent waits.
		 */
		pid = waitpid(-1, &status, 0);
		if (pid < 0) {
			errorc("waitpid failed");
			continue;
		}
		if (WIFSIGNALED(status)) {
			error("server %d exited with signal %d!\n",
			      pid, WTERMSIG(status));
		}
		else if (WIFEXITED(status)) {
			error("server %d exited with status %d!\n",
			      pid, WEXITSTATUS(status));
		}
		numchildren--;

		/*
		 * Figure out which and what kind of server it was that died.
		 */
		for (i = 0; i < maxchildren; i++) {
			if (servers[i].pid == pid) {
				servers[i].pid = 0;
				server_counts[servers[i].which]++;
				break;
			}
		}
		if (killme && !numchildren)
			break;
	}
 done:
	CLOSE(tcpsock);
	close(udpsock);
	info("daemon terminating\n");
	exit(0);
}

/*
 * Create sockets on specified port.
 */
static int
makesockets(int portnum, int *udpsockp, int *tcpsockp)
{
	struct sockaddr_in	name;
	socklen_t		length;
	int			i, udpsock, tcpsock;

	/*
	 * Setup TCP socket for incoming connections.
	 */

	/* Create socket from which to read. */
	tcpsock = socket(AF_INET, SOCK_STREAM, 0);
	if (tcpsock < 0) {
		pfatal("opening stream socket");
	}

	i = 1;
	if (setsockopt(tcpsock, SOL_SOCKET, SO_REUSEADDR,
		       (char *)&i, sizeof(i)) < 0)
		pwarning("setsockopt(SO_REUSEADDR)");;

	/* Create name. */
	name.sin_family = AF_INET;
	name.sin_addr.s_addr = INADDR_ANY;
	name.sin_port = htons((u_short) portnum);
	if (bind(tcpsock, (struct sockaddr *) &name, sizeof(name))) {
		pfatal("binding stream socket");
	}
	/* Find assigned port value and print it out. */
	length = sizeof(name);
	if (getsockname(tcpsock, (struct sockaddr *) &name, &length)) {
		pfatal("getsockname");
	}
	if (listen(tcpsock, 512) < 0) {
		pfatal("listen");
	}
	info("listening on TCP port %d\n", ntohs(name.sin_port));

	/*
	 * Setup UDP socket
	 */

	/* Create socket from which to read. */
	udpsock = socket(AF_INET, SOCK_DGRAM, 0);
	if (udpsock < 0) {
		pfatal("opening dgram socket");
	}

	i = 1;
	if (setsockopt(udpsock, SOL_SOCKET, SO_REUSEADDR,
		       (char *)&i, sizeof(i)) < 0)
		pwarning("setsockopt(SO_REUSEADDR)");;

	i = 128 * 1024;
	if (setsockopt(udpsock, SOL_SOCKET, SO_RCVBUF, &i, sizeof(i)) < 0)
		pwarning("setsockopt(SO_RCVBUF)");

	/* Create name. */
	name.sin_family = AF_INET;
	name.sin_addr.s_addr = INADDR_ANY;
	name.sin_port = htons((u_short) portnum);
	if (bind(udpsock, (struct sockaddr *) &name, sizeof(name))) {
		pfatal("binding dgram socket");
	}

	/* Find assigned port value and print it out. */
	length = sizeof(name);
	if (getsockname(udpsock, (struct sockaddr *) &name, &length)) {
		pfatal("getsockname");
	}
	info("listening on UDP port %d\n", ntohs(name.sin_port));

	*tcpsockp = tcpsock;
	*udpsockp = udpsock;
	return 0;
}

/*
 * Listen for UDP requests. This is not a secure channel, and so this should
 * eventually be killed off.
 */
static void
udpserver(int sock, int portnum)
{
	char			buf[MYBUFSIZE];
	struct sockaddr_in	client;
	socklen_t		length;
	int			cc;
	unsigned int		nreq = 0;

	info("udpserver starting: pid=%d sock=%d portnum=%d\n",
	     mypid, sock, portnum);

	/*
	 * Wait for udp connections.
	 */
	while (1) {
		setproctitle("UDP %d: %u done", portnum, nreq);
		length = sizeof(client);
		cc = recvfrom(sock, buf, sizeof(buf) - 1,
			      0, (struct sockaddr *)&client, &length);
		if (cc <= 0) {
			if (cc < 0)
				errorc("Reading UDP request");
			error("UDP Connection aborted\n");
			continue;
		}
		buf[cc] = '\0';
		handle_request(sock, &client, buf, cc, 0);
		nreq++;
	}
	exit(1);
}

int
tmcd_accept(int sock, struct sockaddr *addr, socklen_t *addrlen, int ms)
{
	int	newsock;

	if ((newsock = accept(sock, addr, addrlen)) < 0)
		return -1;

	/*
	 * Set timeout value to keep us from hanging due to a
	 * malfunctioning or malicious client.
	 */
	if (ms > 0) {
		struct timeval tv;

		tv.tv_sec = ms / 1000;
		tv.tv_usec = (ms % 1000) * 1000;
		if (setsockopt(newsock, SOL_SOCKET, SO_RCVTIMEO,
			       &tv, sizeof(tv)) < 0) {
			errorc("setting SO_RCVTIMEO");
		}
	}

	return newsock;
}

/*
 * Listen for TCP requests.
 */
static void
tcpserver(int sock, int portnum)
{
	char			buf[MAXTMCDPACKET];
	struct sockaddr_in	client;
	socklen_t		length;
	int			cc, newsock;
	unsigned int		nreq = 0;
	struct timeval		tv;

	info("tcpserver starting: pid=%d sock=%d portnum=%d\n",
	     mypid, sock, portnum);

	/*
	 * Wait for TCP connections.
	 */
	while (1) {
		setproctitle("TCP %d: %u done", portnum, nreq);
		length  = sizeof(client);
		newsock = ACCEPT(sock, (struct sockaddr *)&client, &length,
				 readtimo);
		if (newsock < 0) {
			errorc("accepting TCP connection");
			continue;
		}

		/*
		 * Set write timeout value to keep us from hanging due to a
		 * malfunctioning or malicious client.
		 * NOTE: ACCEPT function sets read timeout.
		 */
		tv.tv_sec = writetimo / 1000;
		tv.tv_usec = (writetimo % 1000) * 1000;
		if (setsockopt(newsock, SOL_SOCKET, SO_SNDTIMEO,
			       &tv, sizeof(tv)) < 0) {
			errorc("setting SO_SNDTIMEO");
			CLOSE(newsock);
			continue;
		}

		/*
		 * Read in the command request.
		 */
		if ((cc = READ(newsock, buf, sizeof(buf) - 1)) <= 0) {
			if (cc < 0) {
				if (errno == EWOULDBLOCK)
					errorc("Timeout reading TCP request");
				else
					errorc("Error reading TCP request");
			}
			error("TCP connection aborted\n");
			CLOSE(newsock);
			continue;
		}
		buf[cc] = '\0';
		handle_request(newsock, &client, buf, cc, 1);
		CLOSE(newsock);
		nreq++;
	}
	exit(1);
}

//#define error(x...)	fprintf(stderr, ##x)
//#define info(x...)	fprintf(stderr, ##x)

static int
handle_request(int sock, struct sockaddr_in *client, char *rdata, int rdatalen, int istcp)
{
	struct sockaddr_in redirect_client;
	int		   redirect = 0;
	char		   buf[BUFSIZ], *bp, *cp, *ordata;
	char		   privkeybuf[PRIVKEY_LEN];
	char		   *privkey = (char *) NULL;
	int		   i, overbose = 0, err = 0;
	int		   version = DEFAULT_VERSION;
	tmcdreq_t	   tmcdreq, *reqp = &tmcdreq;

	byteswritten = 0;
#ifdef	WITHSSL
	cp = (istcp ? (isssl ? "SSL" : "TCP") : "UDP");
#else
	cp = (istcp ? "TCP" : "UDP");
#endif
	setproctitle("%s: %s", inet_ntoa(client->sin_addr), cp);

	/*
	 * Init the req structure.
	 */
	bzero(reqp, sizeof(*reqp));

	/*
	 * Look for special tags.
	 */
	bp = ordata = rdata;
	while ((bp = strsep(&rdata, " ")) != NULL) {
		/*
		 * Look for PRIVKEY.
		 */
		if (sscanf(bp, "PRIVKEY=%" XSTRINGIFY(PRIVKEY_LEN) "s", buf)) {
			if (strlen(buf) < 16) {
				info("tmcd client provided short privkey");
				goto skipit;
			}
			for (i = 0; i < strlen(buf); i++){
				if (! isxdigit(buf[i])) {
					info("tmcd client provided invalid "
					     "characters in privkey");
					goto skipit;
				}
			}
			strncpy(privkeybuf, buf, sizeof(privkeybuf));
			privkey = privkeybuf;

			if (debug) {
				info("%s: PRIVKEY %s\n", reqp->nodeid, buf);
			}
			continue;
		}


		/*
		 * Look for VERSION.
		 * Check for clients that are newer than the server
		 * and complain.
		 */
		if (sscanf(bp, "VERSION=%d", &i) == 1) {
			version = i;
			if (version > CURRENT_VERSION) {
				error("version skew on request from %s: "
				      "server=%d, request=%d, "
				      "old TMCD installed?\n",
				      inet_ntoa(client->sin_addr),
				      CURRENT_VERSION, version);
			}
			continue;
		}

		/*
		 * Look for PROXYFOR, which tells us the client making the
		 * request is doing it on behalf of a container. This is
		 * now used from the XEN dom0 so we can tailor the results
		 * and should eventually replace the VNODEID below so that
		 * we can tell the difference between the host asking for
		 * the clients info and tmcc acting as a proxy (or even the
		 * container asking itself, which can happen too now that
		 * allow routable IPs for containers). 
		 */
		if (sscanf(bp, "PROXYFOR=%30s", buf)) {
			for (i = 0; i < strlen(buf); i++){
				if (! (isalnum(buf[i]) ||
				       buf[i] == '_' || buf[i] == '-')) {
					info("tmcd client provided invalid "
					     "characters in vnodeid");
					goto skipit;
				}
			}
			reqp->isvnode = 1;
			reqp->asvnode = 1;
			strncpy(reqp->vnodeid, buf, sizeof(reqp->vnodeid));

			if (debug) {
				info("PROXYFOR %s\n", buf);
			}
			continue;
		}

		/*
		 * Look for REDIRECT, which is a proxy request for a
		 * client other than the one making the request. Good
		 * for testing. Might become a general tmcd redirect at
		 * some point, so that we can test new tmcds.
		 */
		if (sscanf(bp, "REDIRECT=%30s", buf)) {
			redirect_client = *client;
			redirect        = 1;
			inet_aton(buf, &client->sin_addr);

			info("REDIRECTED from %s to %s\n",
			     inet_ntoa(redirect_client.sin_addr), buf);

			continue;
		}

		/*
		 * Look for VNODE. This is used for virtual nodes.
		 * It indicates which of the virtual nodes (on the physical
		 * node) is talking to us. Currently no perm checking.
		 *
		 * This is confusing cause we want to know the difference
		 * between the host asking for the container info, and the
		 * container asking for its own info (perhaps via the tmcc
		 * proxy). We will continue to use this as the host asking
		 * for the container info, and PROXYFOR to indicate the
		 * the container asking for its own info (via the tmcc proxy).
		 * Or if the actual IP of the caller is the container, which
		 * can also happen.  
		 */
		if (sscanf(bp, "VNODEID=%30s", buf)) {
			for (i = 0; i < strlen(buf); i++){
				if (! (isalnum(buf[i]) ||
				       buf[i] == '_' || buf[i] == '-')) {
					info("tmcd client provided invalid "
					     "characters in vnodeid");
					goto skipit;
				}
			}
			reqp->isvnode = 1;
			strncpy(reqp->vnodeid, buf, sizeof(reqp->vnodeid));

			if (debug) {
				info("VNODEID %s\n", buf);
			}
			continue;
		}

		/*
		 * Look for external key
		 */
		if (sscanf(bp, "IDKEY=%" XSTRINGIFY(PRIVKEY_LEN) "s", buf)) {
			for (i = 0; i < strlen(buf); i++){
				if (! isalnum(buf[i])) {
					info("tmcd client provided invalid "
					     "characters in IDKEY");
					goto skipit;
				}
			}
			strncpy(reqp->external_key,
				buf, sizeof(reqp->external_key));

			if (debug) {
				info("IDKEY %s\n", buf);
			}
			continue;
		}

		/*
		 * An empty token (two delimiters next to each other)
		 * is indicated by a null string. If nothing matched,
		 * and its not an empty token, it must be the actual
		 * command and arguments. Break out.
		 *
		 * Note that rdata will point to any text after the command.
		 *
		 */
		if (*bp) {
			break;
		}
	}

	/* Start with default DB */
	strcpy(dbname, DEFAULT_DBNAME);

	/*
	 * Map the ip to a nodeid.
	 */
	if ((err = iptonodeid(client->sin_addr, reqp, privkey))) {
		if (privkey) {
			error("No such node with wanode_key [%s] at %s\n",
			      privkey, inet_ntoa(client->sin_addr));
		}
		else if (reqp->external_key[0]) {
			if (reqp->isvnode)
				error("No such vnode %s with key %s at %s\n",
				      reqp->vnodeid, reqp->external_key,
				      inet_ntoa(client->sin_addr));
			else
				error("No such node with key %s at %s\n",
				      reqp->external_key,
				      inet_ntoa(client->sin_addr));
		}
		else if (reqp->isvnode) {
			error("No such vnode %s at %s\n",
			      reqp->vnodeid, inet_ntoa(client->sin_addr));
		}
		else {
			error("No such node at %s\n",
			      inet_ntoa(client->sin_addr));
		}
		goto skipit;
	}

	/*
	 * Redirect is allowed from the local host only.
	 */
	if (redirect &&
	    redirect_client.sin_addr.s_addr != myipaddr.s_addr &&
	    redirect_client.sin_addr.s_addr != htonl(INADDR_LOOPBACK)) {
		char	buf1[32], buf2[32];

		strcpy(buf1, inet_ntoa(redirect_client.sin_addr));
		strcpy(buf2, inet_ntoa(client->sin_addr));

		if (verbose)
			info("%s INVALID REDIRECT: %s\n", buf1, buf2);
		goto skipit;
	}

#ifdef  WITHSSL
	/*
	 * We verify UDP requests below based on the particular request
	 */
	if (!istcp)
		goto execute;

	/*
	 * If the connection is not SSL, then it must be a local node.
	 */
	if (isssl) {
		/*
		 * LBS: I took this test out. This client verification has
		 * always been a pain, and offers very little since since
		 * the private key is not encrypted anyway. Besides, we
		 * do not return any sensitive data via tmcd, just a lot of
		 * goo that would not be of interest to anyone. I will
		 * kill this code at some point.
		 */
		if (0 &&
		    tmcd_sslverify_client(reqp->nodeid, reqp->pclass,
					  reqp->ptype,  reqp->islocal)) {
			error("%s: SSL verification failure\n", reqp->nodeid);
			if (! redirect)
				goto skipit;
		}
	}
	else if (reqp->iscontrol) {
		error("%s: Control node connection without SSL!\n",
		      reqp->nodeid);
		if (!insecure)
			goto skipit;
	}
#else
	/*
	 * When not compiled for ssl, do not allow remote connections.
	 */
	if (!reqp->islocal) {
		error("%s: Remote node connection not allowed (Define SSL)!\n",
		      reqp->nodeid);
		if (!insecure)
			goto skipit;
	}
	if (reqp->iscontrol) {
		error("%s: Control node connection not allowed "
		      "(Define SSL)!\n", reqp->nodeid);
		if (!insecure)
			goto skipit;
	}
#endif
	/*
	 * Check for a redirect using the default DB. This allows
	 * for a simple redirect to a secondary DB for testing.
	 * Upon return, the dbname has been changed if redirected.
	 */
	if (checkdbredirect(reqp)) {
		/* Something went wrong */
		goto skipit;
	}

	/*
	 * Figure out what command was given.
	 */
 execute:
	for (i = 0; i < numcommands; i++)
		if (strncmp(bp, command_array[i].cmdname,
			    strlen(command_array[i].cmdname)) == 0)
			break;

	if (i == numcommands) {
	        if( !strncmp( bp, "geni_", 5 ) )
		        /* Any invalid command with a GENI prefix is treated
			   as geni_invalid. */
		        i = numcommands - 1;
		else {
		        info("%s: INVALID REQUEST: %.8s\n", reqp->nodeid, bp);
			goto skipit;
		}
	}

	/*
	 * If this is a UDP request from a remote node,
	 * make sure it is allowed.
	 */
	if (!istcp && !reqp->islocal &&
	    (command_array[i].flags & F_REMUDP) == 0) {
		error("%s: %s: Invalid UDP request from remote node\n",
		      reqp->nodeid, command_array[i].cmdname);
		goto skipit;
	}

	/*
	 * Ditto for remote node connection without SSL.
	 */
	if (istcp && !isssl && !reqp->islocal &&
	    (command_array[i].flags & F_REMREQSSL) != 0) {
		error("%s: %s: Invalid NO-SSL request from remote node\n",
		      reqp->nodeid, command_array[i].cmdname);
		goto skipit;
	}

	if (!reqp->allocated && (command_array[i].flags & F_ALLOCATED) != 0) {
		if (verbose || (command_array[i].flags & F_MINLOG) == 0)
			error("%s: %s: Invalid request from free node\n",
			      reqp->nodeid, command_array[i].cmdname);
		goto skipit;
	}

	/*
	 * Enforce TPM use with an iron fist!
	 */
	if ((command_array[i].flags & F_REQTPM)) {
		if (!isssl) {
			/* Should at least be TLS encrypted */
			error("%s: %s: Invalid non-SSL/TPM request\n",
			      reqp->nodeid, command_array[i].cmdname);
			goto skipit;
		}

		/*
		 * Make sure they are using the TPM certificate that we have in
		 * the database for this TLS sesion.
		 */
		if (checkcerts(reqp->nodeid)) {
			error("%s: %s: TPM certificate mismatch\n",
			      reqp->nodeid, command_array[i].cmdname);
			goto skipit;
		}
	}

	/*
	 * XXX For non-SSL TCP requests, make sure we have read the
	 * entire request. Fragmentation can cause the initial read to
	 * not get the entire request. Note that we can only do this
	 * for version 22 and later clients which explicitly shutdown
	 * their output side ensuring that we get an EOF at the end of
	 * the request.
	 */
	if (version >= 22 && istcp && !isssl) {
		bp = ordata + rdatalen;

		while (rdatalen < MAXTMCDPACKET) {
			int cc = READ(sock, bp, MAXTMCDPACKET - rdatalen);

			if (cc <= 0)
				break;

			if (verbose)
				info("%s: %s: got %d additional bytes of data\n",
				     reqp->nodeid, command_array[i].cmdname, cc);
			rdatalen += cc;
			bp += cc;
			*bp = 0;
		}
	}

	/*
	 * Execute it.
	 */
	if ((command_array[i].flags & F_MAXLOG) != 0) {
		overbose = verbose;
		verbose = 1;
	}
	if (verbose || (command_array[i].flags & F_MINLOG) == 0)
		info("%s: vers:%d %s %s\n", reqp->nodeid,
		     version, cp, command_array[i].cmdname);
	setproctitle("%s: %s %s", reqp->nodeid, cp, command_array[i].cmdname);

	err = command_array[i].func(sock, reqp, rdata, istcp, version);

	if (err)
		info("%s: %s: returned %d\n",
		     reqp->nodeid, command_array[i].cmdname, err);
	if ((command_array[i].flags & F_MAXLOG) != 0)
		verbose = overbose;

 skipit:
	if (!istcp)
		client_writeback_done(sock,
				      redirect ? &redirect_client : client);

	if (verbose ||
	    (byteswritten && (command_array[i].flags & F_MINLOG) == 0))
		info("%s: %s wrote %d bytes\n",
		     reqp->nodeid, command_array[i].cmdname,
		     byteswritten);

	return 0;
}

static int checkcerts(char *nid)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows, ret;

	X509		*local, *remote;

	res = mydb_query("select tpmx509 "
			"from node_hostkeys "
			"where node_id='%s' ",
			1, nid);

	/* Treat errors as failure */
	if (!res) {
		error("Couldn't get tpmx509 from database for node %s\n", nid);
		return 1;
	}

	nrows = mysql_num_rows(res);
	if (!nrows) {
		error("No tpmx509 in the database for node %s\n", nid);
		mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);

	remote = tmcd_sslgetpeercert();
	if (!remote) {
		error("SSL_get_peer_certificate() returned NULL for node %s\n",
		    nid);
		mysql_free_result(res);
		return 1;
	}

	local = tmcd_sslrowtocert(row[0], nid);
	if (!local) {
		error("Failure converting row to X509 for node %s\n",
		    nid);
		mysql_free_result(res);
		X509_free(remote);
		return 1;
	}

	ret = X509_cmp(local, remote);

	mysql_free_result(res);
	X509_free(local);
	X509_free(remote);

	return ret;
}

/*
 * Accept notification of reboot.
 */
COMMAND_PROTOTYPE(doreboot)
{
	/*
	 * This is now a no-op. The things this used to do are now
	 * done by stated when we hit RELOAD/RELOADDONE state
	 */
	return 0;
}

/*
 * Return emulab nodeid (not the experimental name).
 */
COMMAND_PROTOTYPE(donodeid)
{
	char		buf[MYBUFSIZE];

	OUTPUT(buf, sizeof(buf), "%s\n", reqp->nodeid);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return emulab node type.
 */
COMMAND_PROTOTYPE(donodetype)
{
	char		buf[MYBUFSIZE];

	OUTPUT(buf, sizeof(buf), "%s\n", reqp->type);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return emulab node uuid.
 */
COMMAND_PROTOTYPE(donodeuuid)
{
	char		buf[MYBUFSIZE];

	OUTPUT(buf, sizeof(buf), "%s\n", reqp->nodeuuid);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return a boot manifest for the node's boot scripts.
 */
COMMAND_PROTOTYPE(domanifest)
{
	MYSQL_RES	*res = NULL;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE];
	int		nrows = 0;
	int		disable_type = 0, disable_osid = 0, disable_node = 0;

	/* 
	 * Short-circuit manifests for nodes tainted with 'blackbox'
	 * or 'useronly'.  A user could use these to invoke arbitrary
	 * code as root.  Need to rework this function and possibly
	 * the manifest handling code on the clientside before even
	 * allowing admin-defined manifests to take effect.
	 */
	if (HAS_ANY_TAINTS(reqp->taintstates, 
			   (TB_TAINTSTATE_BLACKBOX | TB_TAINTSTATE_USERONLY)))
		return 0;

	res = mydb_query("select opt_name,opt_value"
			 " from virt_client_service_opts"
			 " where exptidx=%d or vnode='%s'",
			 2, reqp->exptidx, reqp->nickname);
	if (!res) {
		info("MANIFEST: %s: DB Error getting expt client service opts!\n",
		      reqp->nodeid);
	}
	else if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		res = NULL;
	}
	while (nrows) {
		row = mysql_fetch_row(res);

		if (strcmp(row[0],"disable_type") == 0 
		    && strcmp(row[1],"1") == 0) {
			disable_type = 1;
		}
		else if (strcmp(row[0],"disable_osid") == 0 
			 && strcmp(row[1],"1") == 0) {
			disable_osid = 1;
		}
		else if (strcmp(row[0],"disable_node") == 0 
			 && strcmp(row[1],"1") == 0) {
			disable_node = 1;
		}
		else {
			info("MANIFEST: %s: unknown expt client service opt %s!\n",
			     reqp->nodeid,row[0]);
		}
	}
	if (res) {
		mysql_free_result(res);
		res = NULL;
		nrows = 0;
	}

	/*
	 * This is a messy query.  The rules for the manifest are
	 * 0) only service and hook entries whose service (service,env,whence)
	 *    tuples exist in the client_services table can be returned;
	 * 1) only one SERVICE line foreach (service,env) tuple can be 
	 *    returned;
	 * 2) the user can only override (service,env) tuples that have
	 *    user_can_override set to 1;
	 *    (and if there are multiple admin tuples, but the highest-prio
	 *    one allows override, even if less prio ones don't, we still
	 *    allow override!)
	 * 3) multiple HOOK lines can be returned, and the order in
	 *    which hook lines are generated is by querying the
	 *    client_service_hooks table for node types matching this node;
	 *    the client_service_hooks table for osids matching this node;
	 *    the client_service_hooks table for nodes matching this node;
	 *    the virt_client_service_hooks table for '' nodes
	 *      (wildcard, experiment wide);
	 *    the virt_client_service_hooks table for nodes matching
	 *      this node.
	 * 4) the user can disable all admin hooks with
	 *    user_can_override set to 1
	 * 5) the virt_client_service_opts table controls which types of 
	 *    admin hooks are disabled, across the experiment, or per-node.
	 */
	res = mydb_query("select cs.service,cs.env,cs.whence,"
			 /* 3 */
			 "  vcsnodeblobs.uuid,vcsnode.alt_vblob_id,vcsnode.enable,vcsnode.enable_hooks,vcsnode.fatal,"
			 /* 8 */
			 "  vcsexptblobs.uuid,vcsexpt.alt_vblob_id,vcsexpt.enable,vcsexpt.enable_hooks,vcsexpt.fatal,"
			 /* 13 */
			 "  csnode.alt_blob_id,csnode.enable,csnode.enable_hooks,"
			 /* 16 */
			 "  csnode.fatal,csnode.user_can_override,"
			 /* 18 */
			 "  csos.alt_blob_id,csos.enable,csos.enable_hooks,"
			 /* 21 */
			 "  csos.fatal,csos.user_can_override,"
			 /* 23 */
			 "  cstype.alt_blob_id,cstype.enable,cstype.enable_hooks,"
			 /* 26 */
			 "  cstype.fatal,cstype.user_can_override,"
			 /* 28 */
			 "  cs.hooks_only"
			 " from reserved as r"
			 " left join nodes as n on r.node_id=n.node_id"
			 " straight_join client_services as cs"
			 " left join virt_client_service_ctl as vcsexpt on"
			 "   (r.exptidx=vcsexpt.exptidx and vcsexpt.vnode=''"
			 "    and cs.idx=vcsexpt.service_idx"
			 "    and cs.env=vcsexpt.env"
			 "    and cs.whence=vcsexpt.whence)"
			 " left join blobs as vcsexptblobs on"
			 "   (vcsexpt.exptidx=vcsexptblobs.exptidx"
			 "    and vcsexpt.alt_vblob_id=vcsexptblobs.vblob_id)"
			 " left join virt_client_service_ctl as vcsnode on"
			 "   (r.exptidx=vcsnode.exptidx"
			 "    and r.vname=vcsnode.vnode"
			 "    and cs.idx=vcsnode.service_idx"
			 "    and cs.env=vcsnode.env"
			 "    and cs.whence=vcsnode.whence)"
			 " left join blobs as vcsnodeblobs on"
			 "   (vcsnode.exptidx=vcsnodeblobs.exptidx"
			 "    and vcsnode.alt_vblob_id=vcsnodeblobs.vblob_id)"
			 " left join client_service_ctl as csnode on"
			 "   (csnode.obj_type='node'"
			 "    and r.node_id=csnode.obj_name"
			 "    and cs.idx=csnode.service_idx"
			 "    and cs.env=csnode.env"
			 "    and cs.whence=csnode.whence)"
			 " left join client_service_ctl as csos on"
			 "   (csos.obj_type='osid' and n.def_boot_osid=csos.obj_name"
			 "    and cs.idx=csos.service_idx and cs.env=csos.env"
			 "    and cs.whence=csos.whence)"
			 " left join client_service_ctl as cstype on"
			 "   (cstype.obj_type='node_type'"
			 "    and n.type=cstype.obj_name"
			 "    and cs.idx=cstype.service_idx"
			 "    and cs.env=cstype.env and cs.whence=cstype.whence)"
			 " where r.exptidx=%d and r.node_id='%s'"
			 "   and (vcsnode.enable is not NULL"
			 "        or vcsexpt.enable is not NULL"
			 "        or csnode.enable is not NULL"
			 "        or csos.enable is not NULL"
			 "        or cstype.enable is not NULL)",
			 29, reqp->exptidx, reqp->nodeid);
	if (!res) {
		error("MANIFEST: %s: DB Error getting manifest info!\n",
		      reqp->nodeid);
		nrows = 0;
	}
	else if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		res = NULL;
	}
	while (nrows) {
		char *enabled = NULL;
		char *hooks_enabled = NULL;
		char *fatal = NULL;
		char *blobid = NULL;
		int admin_service_not_overrideable = 0;
		int admin_idx = 0;
		int hooks_only;
		int disable_admin = 0;

		row = mysql_fetch_row(res);
		hooks_only = (strcmp(row[28],"1") == 0) ? 1 : 0;

		/* figure out which service control entry to use! */
		/* start by choosing the per-node or per-experiment stuff */
		if (row[5] != NULL && !hooks_only) {
		    enabled = row[5];
		    hooks_enabled = row[6];
		    fatal = row[7];
		    blobid = row[3];
		    /* 
		     * If there was nothing in blob_blobs for this blob, 
		     * just return the vblob and hope it was a real,
		     * hardcoded blob in the blob store.
		     */
		    if (blobid == NULL)
			blobid = row[4];
		}
		else if (row[9] != NULL && !hooks_only) {
		    enabled = row[10];
		    hooks_enabled = row[11];
		    fatal = row[12];
		    blobid = row[7];
		    if (blobid == NULL)
			blobid = row[8];
		}

		if (row[17] != NULL) {
		    admin_idx = 13;
		    if (strcmp(row[17],"0") == 0) {
			admin_service_not_overrideable = 1;
		    }
		    if (disable_node) 
			disable_admin = 1;
		}
		else if (row[22] != NULL) {
		    admin_idx = 18;
		    if (strcmp(row[22],"0") == 0) {
			admin_service_not_overrideable = 1;
		    }
		    if (disable_osid) 
			disable_admin = 1;
		}
		else if (row[27] != NULL) {
		    admin_idx = 23;
		    if (strcmp(row[27],"0") == 0) {
			admin_service_not_overrideable = 1;
		    }
		    if (disable_type) 
			disable_admin = 1;
		}

		/* If the user wants to ignore the admin setting, and
		 * the admin allows it to be overridden, AND the user
		 * didn't specify a control for this service... skip! */
		if (disable_admin && !admin_service_not_overrideable 
		    && enabled == NULL) {
		    --nrows;
		    continue;
		}

		/* If the admin set hooks_only on a service, and didn't
		 * specify a service entry, bail! */
		if (hooks_only && admin_idx == 0) {
		    --nrows;
		    continue;
		}

		/* If the admin seting can't be overridden, or if the
		 * user didn't specify a control for this node or
		 * experiment-wide, send the admin setting */
		if (admin_service_not_overrideable || enabled == NULL) {
		    enabled = row[admin_idx+1];
		    hooks_enabled = row[admin_idx+2];
		    fatal = row[admin_idx+3];
		    blobid = row[admin_idx+0];
		}

		/* the query should prevent against this, but... */
		if (enabled == NULL) {
		    error("MANIFEST: %s: got info from DB for %s, but no enabled!\n",
			  reqp->nodeid,row[0]);
		    --nrows;
		    continue;
		}

		if (blobid == NULL)
		    blobid = "";

		OUTPUT(buf, sizeof(buf),
		       "SERVICE NAME=%s ENV=%s WHENCE=%s"
		       " ENABLED=%s HOOKS_ENABLED=%s FATAL=%s"
		       " BLOBID=%s\n",
		       row[0],row[1],row[2],
		       enabled,hooks_enabled,fatal,blobid);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("MANIFEST: %s", buf);
	}
	if (res) {
		mysql_free_result(res);
		res = NULL;
		nrows = 0;
	}

	/* grab the admin client side hooks */
	res = mydb_query("select cs.service,cs.env,cs.whence,csh.obj_type,"
			 "  csh.hook_blob_id,csh.hook_op,csh.hook_point,"
			 "  csh.argv,csh.fatal,csh.user_can_override"
			 " from reserved as r"
			 " left join nodes as n on r.node_id=n.node_id"
			 " straight_join client_services as cs"
			 " left join client_service_hooks as csh on"
			 "   (cs.idx=csh.service_idx"
			 "    and cs.env=csh.env"
			 "    and cs.whence=csh.whence)"
			 " where r.exptidx=%d and r.node_id='%s'"
			 "   and ((csh.obj_type='node'"
			 "         and r.node_id=csh.obj_name)"
			 "        or (csh.obj_type='osid'"
			 "            and n.def_boot_osid=csh.obj_name)"
			 "        or (csh.obj_type='node_type'"
			 "            and n.type=csh.obj_name))",
			 10,reqp->exptidx,reqp->nodeid);
	if (!res) {
		error("MANIFEST: %s: DB Error getting manifest admin hook info!\n",
		      reqp->nodeid);
	}
	else if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		res = NULL;
	}
	while (nrows) {
		row = mysql_fetch_row(res);

		/*
		 * skip this admin hook if it can be overridden, and if
		 * the user turned off this type of admin hooks
		 */
		if (strcmp(row[9],"1") == 0
		    && ((strcmp(row[3],"node") == 0 && disable_node)
			|| (strcmp(row[3],"osid") == 0 && disable_osid)
			|| (strcmp(row[3],"type") == 0 && disable_type))) {
			--nrows;
			continue;
		}

		OUTPUT(buf, sizeof(buf),
		       "HOOK SERVICE=%s ENV=%s WHENCE=%s"
		       " OP=%s POINT=%s FATAL=%s BLOBID=%s ARGV=\"%s\"\n",
		       row[0],row[1],row[2],
		       row[5],row[6],row[8],row[4],row[7]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("MANIFEST: %s", buf);
	}
	if (res) {
		mysql_free_result(res);
		res = NULL;
		nrows = 0;
	}

	/* grab the user-specified client side hooks */
	res = mydb_query("select cs.service,cs.env,cs.whence,"
			 "  cshblobs.uuid,csh.hook_vblob_id,csh.hook_op,csh.hook_point,"
			 "  csh.argv,csh.fatal"
			 " from reserved as r"
			 " left join nodes as n on r.node_id=n.node_id"
			 " straight_join client_services as cs"
			 " left join virt_client_service_hooks as csh on"
			 "   (r.exptidx=csh.exptidx"
			 "    and (csh.vnode='' or r.vname=csh.vnode)"
			 "    and cs.idx=csh.service_idx"
			 "    and cs.env=csh.env"
			 "    and cs.whence=csh.whence)"
			 " left join blobs as cshblobs on"
			 "   (csh.exptidx=cshblobs.exptidx"
			 "    and csh.hook_vblob_id=cshblobs.vblob_id)"
			 " where r.exptidx=%d and r.node_id='%s'"
			 "   and csh.hook_vblob_id is not NULL",
			 9,reqp->exptidx,reqp->nodeid);
	if (!res) {
		error("MANIFEST: %s: DB Error getting manifest user hook info!\n",
		      reqp->nodeid);
	}
	else if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		res = NULL;
	}
	while (nrows) {
		row = mysql_fetch_row(res);

		OUTPUT(buf, sizeof(buf),
		       "HOOK SERVICE=%s ENV=%s WHENCE=%s"
		       " OP=%s POINT=%s FATAL=%s BLOBID=%s ARGV=\"%s\"\n",
		       row[0],row[1],row[2],
		       row[5],row[6],row[8],(row[3]) ? row[3] : row[4],row[7]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("MANIFEST: %s", buf);
	}
	if (res) {
		mysql_free_result(res);
		res = NULL;
		nrows = 0;
	}

	return 0;
}

/*
 * Return status of node. Is it allocated to an experiment, or free.
 */
COMMAND_PROTOTYPE(dostatus)
{
	char		buf[MYBUFSIZE];

	/*
	 * Now check reserved table
	 */
	if (! reqp->allocated) {
		info("%s: STATUS: FREE\n", reqp->nodeid);
		strcpy(buf, "FREE\n");
		client_writeback(sock, buf, strlen(buf), tcp);
		return 0;
	}

	OUTPUT(buf, sizeof(buf), "ALLOCATED=%s/%s NICKNAME=%s\n",
	       reqp->pid, reqp->eid, reqp->nickname);
	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("%s: STATUS: %s", reqp->nodeid, buf);
	return 0;
}

/*
 * Return ifconfig information to client.
 */
COMMAND_PROTOTYPE(doifconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		clause[BUFSIZ];
	char		buf[MYBUFSIZE], *ebufp = &buf[MYBUFSIZE];
	int		nrows;
	int		num_interfaces=0;
	int		cookedgeninode = (reqp->geniflags & 0x2);
	int		allowjumboframes = 0;

	/*
	 * Figure out if jumbo frames are a possibility at this site.
	 * XXX we only do this if the client is new enough to set jumbos.
	 */
	if (vers >= 44) {
		res = mydb_query("select value,defaultvalue "
				 "from sitevariables "
				 "where name='general/allowjumboframes'", 2);
		if (res && (int)mysql_num_rows(res) > 0) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0])
				allowjumboframes = (atoi(row[0]) > 0 ? 1 : 0);
			else if (row[1] && row[1][0])
				allowjumboframes = (atoi(row[1]) > 0 ? 1 : 0);
		}
		if (res)
			mysql_free_result(res);
	}

	if (cookedgeninode)
		goto skipphys;

	/*
	 * For Virtual Nodes, we return interfaces that belong to it.
	 */
	if (reqp->isvnode && !reqp->issubnode)
		sprintf(clause, "i.vnode_id='%s'", reqp->vnodeid);
	else
		strcpy(clause, "i.vnode_id is NULL");

	/*
	 * Find all the interfaces.
	 */
	res = mydb_query("select 0,i.IP,i.MAC,i.current_speed,"
			 "       i.duplex,i.IPaliases,i.iface,i.role,i.mask,"
			 "       i.rtabid,i.interface_type,vl.vname,vs.capval "
			 "  from interfaces as i "
			 "left join virt_lans as vl on "
			 "  vl.pid='%s' and vl.eid='%s' and "
			 "  vl.vnode='%s' and vl.ip=i.IP "
			 "left join virt_lan_settings as vs on "
			 "  vs.exptidx=vl.exptidx and vs.vname=vl.vname "
			 "    and vs.capkey='jumboframes' "
			 "where i.node_id='%s' and %s",
			 13, reqp->pid, reqp->eid, reqp->nickname,
			 reqp->issubnode ? reqp->nodeid : reqp->pnodeid,
			 clause);

	/*
	 * We need pnodeid in the query. But error reporting is done
	 * by nodeid. For vnodes, nodeid is pcvmXX-XX and for the rest
	 * it is the same as pnodeid
	 */
	if (!res) {
		error("%s: IFCONFIG: DB Error getting interfaces!\n",
		      reqp->nodeid);
		return 1;
	}

	/*
	 * Handle physical interfaces with IP addresses
	 */
	nrows = (int)mysql_num_rows(res);
	while (nrows) {
		row = mysql_fetch_row(res);
		if (row[1] && row[1][0]) {
			char *iface  = row[6];
			char *role   = row[7];
			char *type   = row[10];
			char *lan    = row[11];
			char *speed  = "100";
			char *unit   = "Mbps";
			char *duplex = "full";
			char *mtu    = "";
			char *bufp   = buf;
			char *mask;

			/* Never for the control net; sharks are dead */
			if (strcmp(role, TBDB_IFACEROLE_EXPERIMENT))
				goto skipit;

			/* Do not send along info for RF links (PhantomNet) */
			if (strcmp(type, "P2PLTE") == 0) {
				goto skipit;
			}

			/* Do this after above test to avoid error in log */
			mask = CHECKMASK(row[8]);

			/*
			 * Speed and duplex if not the default.
			 */
			if (row[3] && row[3][0])
				speed = row[3];
			if (row[4] && row[4][0])
				duplex = row[4];

			/*
			 * MTU:
			 *   "9000" if using jumbo frames,
			 *   "" otherwise (use client default)
			 *
			 * Note that >=50Gbps always use jumbo frames.
			 * There are no backward compat issues to worry
			 * about for these.
			 */
			if (atoi(speed) >= 50000 ||
			    (allowjumboframes && atoi(speed) >= 10000 &&
			     row[12] && atoi(row[12]) > 0))
				mtu = "9000";

			/*
			 * XXX As of 2020, our clientside will still attempt
			 * to explicitly set the speed of an interface based
			 * on the SPEED= value we return. If that fails, the
			 * script falls back on auto-negotiation. However, we
			 * have now hit a situation where we have interfaces
			 * that _must_ auto-negotiate or there is no link.
			 *
			 * Fortunately we can do that by passing zero as the
			 * speed. So look for the magic (anti-)capability
			 * on the interface type and change the speed to zero
			 * if it is set. Why wait all the wait til now to do
			 * this instead of just recording a zero speed in the
			 * DB? Well, we need the real speed as part of our
			 * MTU setting hack which is also done here.
			 *
			 * Don't hate on me.
			 */
			if (atoi(speed) > 0) {
				MYSQL_RES *res2;
				MYSQL_ROW row2;
				res2 = mydb_query("select capval from "
						  "interface_capabilities "
						  "where type='%s' and "
						  "capkey='autonegotiate'",
						  1, type);
				if (res2 && (int)mysql_num_rows(res2) > 0) {
					row2 = mysql_fetch_row(res2);
					if (row2[0] &&
					    strcmp(row2[0], "force") == 0)
						speed = "0";
				}
				if (res2)
					mysql_free_result(res2);
			}

			/*
			 * We now use the MAC to determine the interface, but
			 * older images still want that tag at the front.
			 */
			if (vers <= 15)
				bufp += OUTPUT(bufp, ebufp - bufp,
					       "IFACETYPE=eth ");
			else
				bufp += OUTPUT(bufp, ebufp - bufp,
					       "INTERFACE IFACETYPE=%s ", type);

			bufp += OUTPUT(bufp, ebufp - bufp,
				"INET=%s MASK=%s MAC=%s SPEED=%s%s DUPLEX=%s",
				row[1], mask, row[2], speed, unit, duplex);

			/*
			 * For older clients, we tack on IPaliases.
			 * This used to be in the interfaces table as a
			 * comma separated list, now we have to extract
			 * it from the vinterfaces table.
			 */
			if (vers >= 8 && vers < 27) {
				MYSQL_RES *res2;
				MYSQL_ROW row2;
				int nrows2;

				res2 = mydb_query("select IP "
						  "from vinterfaces "
						  "where type='alias' "
						  "and node_id='%s'",
						  1, reqp->nodeid);
				if (res2 == NULL)
					goto adone;

				nrows2 = (int)mysql_num_rows(res2);
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " IPALIASES=\"");
				while (nrows2 > 0) {
					nrows2--;
					row2 = mysql_fetch_row(res2);
					if (!row2 || !row2[0])
						continue;
					bufp += OUTPUT(bufp, ebufp - bufp,
						       "%s", row2[0]);
					if (nrows2 > 0)
						bufp += OUTPUT(bufp,
							       ebufp - bufp,
							       ",");
				}
				bufp += OUTPUT(bufp, ebufp - bufp, "\"");
				mysql_free_result(res2);
			adone: ;
			}

			/*
			 * Tack on iface for IXPs. This should be a flag on
			 * the interface instead of a match against type.
			 */
			if (vers >= 11) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " IFACE=%s",
					       (strcmp(reqp->class, "ixp") ?
						"" : iface));
			}
			if (vers >= 14) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " RTABID=%s", row[9]);
			}
			if (vers >= 17) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " LAN=%s", lan);
			}
			if (vers >= 44) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " MTU=%s", mtu);
			}

			OUTPUT(bufp, ebufp - bufp, "\n");
			client_writeback(sock, buf, strlen(buf), tcp);
			num_interfaces++;
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
		}
	skipit:
		nrows--;
	}
	mysql_free_result(res);

	/*
	 * XXX temporary hack to set up a shared LAN on a set of machines.
	 * This LAN is not represented in the usual way in the DB, it just
	 * exists as node_attributes that spell out everything. This is NOT
	 * intended as a general mechanism, only as a way to start using 10Gb
	 * on our new nodes before we have snmpit support for the 10Gb switch.
	 */
	res = mydb_query("select attrkey,attrvalue from node_attributes "
			 " where attrkey like 'shared_lan_%%' and "
			 " node_id='%s'", 2, reqp->nodeid);
	if (res) {
		char _ip[16], _mask[16], _mac[18], _speed[8], _mtu[6];
		char *bufp = buf;
		int got = 0;

		/* XXX optional */
		strcpy(_mtu, "");

		nrows = (int)mysql_num_rows(res);
		while (nrows > 0) {
			nrows--;
			row = mysql_fetch_row(res);
			if (!row || !row[0] || !row || !row[1])
				continue;
			if (strcmp(row[0], "shared_lan_ip") == 0) {
				strncpy(_ip, row[1], sizeof(_ip)-1);
				_ip[sizeof(_ip)-1] = '\0';
				got++;
			} else if (strcmp(row[0], "shared_lan_mask") == 0) {
				strncpy(_mask, row[1], sizeof(_mask)-1);
				_mask[sizeof(_mask)-1] = '\0';
				got++;
			} else if (strcmp(row[0], "shared_lan_mac") == 0) {
				strncpy(_mac, row[1], sizeof(_mac)-1);
				_mac[sizeof(_mac)-1] = '\0';
				got++;
			} else if (strcmp(row[0], "shared_lan_speed") == 0) {
				strncpy(_speed, row[1], sizeof(_speed)-1);
				_speed[sizeof(_speed)-1] = '\0';
				got++;
			} else if (strcmp(row[0], "shared_lan_mtu") == 0) {
				strncpy(_mtu, row[1], sizeof(_mtu)-1);
				_mtu[sizeof(_mtu)-1] = '\0';
			}
		}
		if (got == 4) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       "INTERFACE IFACETYPE=ixgbe "
				       "INET=%s MASK=%s MAC=%s "
				       "SPEED=%sMbps DUPLEX=full "
				       "IFACE= RTABID=0 LAN=shared_lan_0",
				       _ip, _mask, _mac, _speed);
			if (vers >= 44) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " MTU=%s", _mtu);
			}
			OUTPUT(bufp, ebufp - bufp, "\n");
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
		}
		mysql_free_result(res);
	}

	/*
	 * Interface settings.
	 */
	if (vers >= 16) {
		res = mydb_query("select i.MAC,s.capkey,s.capval "
				 "from interface_settings as s "
				 "left join interfaces as i on "
				 "     s.node_id=i.node_id and s.iface=i.iface "
				 "where s.node_id='%s' and %s ",
				 3,
				 reqp->issubnode ? reqp->nodeid : reqp->pnodeid,
				 clause);

		if (!res) {
			error("%s: IFCONFIG: "
			      "DB Error getting interface_settings!\n",
			      reqp->nodeid);
			return 1;
		}
		nrows = (int)mysql_num_rows(res);
		while (nrows) {
			row = mysql_fetch_row(res);

			sprintf(buf, "INTERFACE_SETTING MAC=%s "
				"KEY='%s' VAL='%s'\n",
				row[0], row[1], row[2]);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
			nrows--;
		}
		mysql_free_result(res);
	}

	/*
	 * Handle virtual interfaces for both physical nodes (multiplexed
	 * links) and virtual nodes.  Veths (the first virtual interface type)
	 * were added in rev 10.
	 */
	if (vers < 10)
		return 0;

 skipphys:
	/*
	 * First, return config info for physical interfaces underlying
	 * the virtual interfaces or delay interfaces. These are marked
	 * with a current_speed!=0 but no IP address. Note that we never
	 * want to return control network interfaces here, even though
	 * there might be vinterfaces on top of a control interface. 
	 */
	if (vers >= 18 && !reqp->isvnode) {
		char *aliasstr;

		res = mydb_query("select i.interface_type,i.mac, "
				 "       i.current_speed,i.duplex,i.iface "
				 "  from interfaces as i "
				 "where i.current_speed!='0' and "
				 "      i.current_speed!='' and "
				 "      i.role!='ctrl' and "
				 "      (i.IP='' or i.IP is null) and "
				 "      i.role='expt' and i.node_id='%s'",
				 5, reqp->pnodeid);
		if (!res) {
			error("%s: IFCONFIG: "
			     "DB Error getting active physical interfaces!\n",
			      reqp->nodeid);
			return 1;
		}

		if (vers < 27)
			aliasstr = "IPALIASES=\"\" ";
		else
			aliasstr = "";

		nrows = (int)mysql_num_rows(res);
		while (nrows) {
			char *mtu = "";
			char *bufp   = buf;

			row = mysql_fetch_row(res);
			char *speed = row[2];

			/*
			 * XXX we have to figure out if any vinterfaces
			 * associated with this interface require jumbo
			 * frames and set jumbo frames on the physical
			 * interface if so. This could no doubt be combined
			 * with the above query, but my head would explode
			 * if I tried that.
			 *
			 * XXX since this is such a skank query, we only
			 * do it if absolutely positively necessary:
			 * if we support using jumbo frames and
			 * if the interface speed is at least 10Gbps.
			 *
			 * XXX we also always set jumbo frames for 50Gb
			 * and above.
			 */
			if (atoi(speed) >= 50000)
				mtu= "9000";
			else if (vers >= 44 && allowjumboframes &&
				 atoi(speed) >= 10000) {
				MYSQL_RES *res2;
				MYSQL_ROW row2;
				res2 = mydb_query("select max(vls.capval) "
						  "from vinterfaces as v "
						  "left join interfaces as i "
						  " on i.node_id=v.node_id "
						  "  and i.iface=v.iface "
						  "left join virt_lan_lans as vll "
						  " on vll.idx=v.virtlanidx "
						  "  and vll.exptidx=v.exptidx "
						  "left join lan_attributes as la2 "
						  " on la2.lanid=v.vlanid "
						  "  and la2.attrkey='stack' "
						  "left join virt_lan_settings as vls "
						  " on vls.exptidx=vll.exptidx "
						  "  and vls.vname=vll.vname "
						  "  and vls.capkey='jumboframes' "
						  "where v.exptidx='%d' "
						  " and v.node_id='%s' "
						  " and v.iface='%s' "
						  " and (la2.attrvalue='Experimental' "
						  "  or la2.attrvalue is null) "
						  "and v.vnode_id is NULL",
						  1, reqp->exptidx,
						  reqp->nodeid, row[4]);
				if (res2 && (int)mysql_num_rows(res2) > 0) {
					row2 = mysql_fetch_row(res2);
					if (row2[0] && atoi(row2[0]) > 0)
						mtu = "9000";
				}
				if (res2)
					mysql_free_result(res2);
			}

			/*
			 * XXX see if we need to force auto-negotiation on
			 * the physical link. See comment above for details.
			 */
			if (atoi(speed) > 0) {
				MYSQL_RES *res2;
				MYSQL_ROW row2;
				res2 = mydb_query("select capval from "
						  "interface_capabilities "
						  "where type='%s'", 1, row[0]);
				if (res2 && (int)mysql_num_rows(res2) > 0) {
					row2 = mysql_fetch_row(res2);
					if (row2[0] &&
					    strcmp(row2[0], "force") == 0)
						speed = "0";
				}
				if (res2)
					mysql_free_result(res2);
			}

			bufp += OUTPUT(bufp, ebufp - bufp,
				       "INTERFACE IFACETYPE=%s "
				       "INET= MASK= MAC=%s "
				       "SPEED=%sMbps DUPLEX=%s "
				       "%sIFACE= RTABID= LAN=",
				       row[0], row[1], speed, row[3],
				       aliasstr);

			/*
			 * XXX MTU:
			 *   "9000" if allowing jumbo frames,
			 *   "" if not (use client default)
			 */
			if (vers >= 44) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " MTU=%s", mtu);
			}

			OUTPUT(bufp, ebufp - bufp, "\n");
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
			nrows--;
		}
		mysql_free_result(res);
	}

	/*
	 * Outside a vnode, return only those virtual devices that have
	 * vnode=NULL, which indicates its an emulated interface on a
	 * physical node. When inside a vnode, only return virtual devices
	 * for which vnode=curvnode, which are the interfaces that correspond
	 * to a jail node.
	 */
	if (reqp->isvnode)
		sprintf(buf, "v.vnode_id='%s'", reqp->vnodeid);
	else
		strcpy(buf, "v.vnode_id is NULL");

	/*
	 * Find all the virtual interfaces.
	 */
	res = mydb_query("select v.unit,v.IP,v.mac,i.mac,v.mask,v.rtabid, "
			 "       v.type,vll.vname,v.virtlanidx,vlans.tag, "
			 "       l.lanid,rvt.tag,i.current_speed,vls.capval "
			 "  from vinterfaces as v "
			 "left join interfaces as i on "
			 "  i.node_id=v.node_id and i.iface=v.iface "
			 "left join virt_lan_lans as vll on "
			 "  vll.idx=v.virtlanidx and vll.exptidx=v.exptidx "
			 "left join lans as l on "
			 "  l.exptidx=vll.exptidx and l.vname=vll.vname "
			 "left join vlans on "
			 "  vlans.id=v.vlanid "
			 "left join reserved_vlantags as rvt on "
			 "  rvt.lanid=v.vlanid "
			 "left join lan_attributes as la2 on "
			 "  la2.lanid=v.vlanid and la2.attrkey='stack' "
			 "left join virt_lan_settings as vls on "
			 "  vls.exptidx=vll.exptidx and vls.vname=vll.vname "
			 "      and vls.capkey='jumboframes' "
			 "where v.exptidx='%d' and v.node_id='%s' and "
			 "      (la2.attrvalue='Experimental' or "
			 "       la2.attrvalue is null) "
			 "      and %s",
			 14, reqp->exptidx, reqp->pnodeid, buf);
	if (!res) {
		error("%s: IFCONFIG: DB Error getting veth interfaces!\n",
		      reqp->nodeid);
		return 1;
	}
	nrows = (int)mysql_num_rows(res);
	while (nrows) {
		char *bufp   = buf;
		char *ifacetype;
		int isveth, doencap, isloop;

		row = mysql_fetch_row(res);
		nrows--;

		/*
		 * If the interface type is 'alias', and this is not
		 * do not process here.  Such IP alias entries will be
		 * handled below.  Old (very old) IP alias processing
		 * occurs via "IPALIAS=" lines, generated above.
		 */
		if (strcmp(row[6], "alias") == 0)
			continue;

		isloop = (strcmp(row[6], "vlan") == 0 && !row[3]) ? 1 : 0;

		/*
		 * When the proxy is asking for the container, we give it info
		 * for a plain interface, since that is all it sees.
		 */
		if (reqp->isvnode && reqp->asvnode) {
			char *speed = "100Mbps";
			char *mtuopt = "";

			/*
			 * XXX MTU setting.
			 *
			 * On a node-local interface (isloop != 0) we won't
			 * have an associated physical inteface and thus no
			 * current_speed setting. So here we just use the
			 * specified jumboframes capability to decide if the
			 * MTU should be set to 9000.
			 *
			 * If we are going to be setting MTU=9000, then we
			 * also explicitly set the speed to 10000Mbps just
			 * so the user doesn't get weirded-out by a 100Mbps
			 * link with jumbo frames.
			 */
			if (vers >= 44) {
				if (allowjumboframes &&
				    isloop && row[13] && atoi(row[13]) > 0) {
					mtuopt = " MTU=9000";
					speed = "10000Mbps";
				} else {
					mtuopt = " MTU=";
				}
			}
			bufp += OUTPUT(bufp, ebufp - bufp,
				       "INTERFACE IFACETYPE=any "
				       "INET=%s MASK=%s MAC=%s "
				       "SPEED=%s DUPLEX=full "
				       "IFACE= RTABID= LAN=%s%s\n",
				       row[1], row[4], row[2], speed,
				       row[7], mtuopt);

			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
			
			continue;
		}

		if (isloop) {
			/*
			 * A vlan that ended up trivial since all the
			 * members are on the same node. Convert to a
			 * loopback lan, however the client is able to do
			 * it.
			 */
			isveth    = 0;
			doencap   = 0;
			ifacetype = "loop";
		} else if (strcmp(row[6], "veth") == 0) {
			isveth = 1;
			doencap = 1;
			ifacetype = "veth";
		} else if (strcmp(row[6], "veth-ne") == 0) {
			isveth = 1;
			doencap = 0;
			ifacetype = "veth";
		} else {
			/* This is typically a plain vlan */
			isveth = 0;
			doencap = 0;
			ifacetype = row[6];
		}

		/*
		 * Older clients only know how to deal with "veth" here.
		 * "alias" is handled via IPALIASES= and "vlan" is unknown.
		 * So skip all but isveth cases.
		 */
		if (vers < 27 && !isveth)
			continue;

		if (vers >= 16) {
			bufp += OUTPUT(bufp, ebufp - bufp, "INTERFACE ");
		}

		/*
		 * Note that PMAC might be NULL, which happens if there is
		 * no underlying phys interface (say, colocated nodes in a
		 * link).
		 */
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "IFACETYPE=%s "
			       "INET=%s MASK=%s ID=%s VMAC=%s PMAC=%s",
			       ifacetype,
			       row[1], CHECKMASK(row[4]), row[0], row[2],
			       row[3] ? row[3] : "none");

		if (vers >= 14) {
			bufp += OUTPUT( bufp, ebufp - bufp,
					" RTABID=%s", row[5]);
		}
		if (vers >= 15) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " ENCAPSULATE=%d", doencap);
		}
		if (vers >= 17) {
			bufp += OUTPUT(bufp, ebufp - bufp, " LAN=%s", row[7]);
		}
		/*
		 * Return a VLAN tag.
		 *
		 * XXX for veth devices it comes out of the virt_lan_lans
		 * table, for vlan devices it comes out of the vlans table,
		 * for anything else it is zero.
		 */
		if (vers >= 20) {
			char *tag = "0";
			if (isveth)
				tag = row[8];
			else if (strcmp(ifacetype, "loop") == 0)
				tag = row[10];
			else if (strcmp(ifacetype, "vlan") == 0)
				tag = row[9] ? row[9] :
					row[11] ? row[11] : "0";

			/* sanity check the tag */
			if (!isdigit(tag[0])) {
				error("IFCONFIG: bogus encap tag '%s'\n", tag);
				tag = "0";
			}

			bufp += OUTPUT(bufp, ebufp - bufp, " VTAG=%s", tag);

			/*
			 * MTU: see if jumboframes capability is set, but
			 * then only set if physical interface is >= 10Gbps.
			 *
			 * XXX ugh. for VLAN devices on a physical node
			 * (!reqp->isvnode), we cannot just return the
			 * default "MTU=" if we want a non-jumbo (1500 byte)
			 * MTU. This is because we may have set the parent
			 * physical interface to an MTU of 9000, in which
			 * case "the default" will now be 9000 and not 1500!
			 * So always explicitly set the MTU for VLAN devices.
			 */
			if (vers >= 44) {
				char *mtu = "";
				if (row[12] && atoi(row[12]) >= 50000)
					mtu = "9000";
				else if (allowjumboframes) {
					if (row[13] && atoi(row[13]) > 0 &&
					    row[12] && atoi(row[12]) >= 10000)
						mtu = "9000";
					else if (!reqp->isvnode)
						mtu = "1500";
				}
				bufp += OUTPUT(bufp, ebufp - bufp, " MTU=%s",
					       mtu);
			}
		}
		OUTPUT(bufp, ebufp - bufp, "\n");
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("%s: IFCONFIG: %s", reqp->nodeid, buf);
	}
	mysql_free_result(res);

	/*
	 * Containers do not see egre/gre tunnels, they see plain interfaces,
	 * since the tunnel was set up in root (dom0) context. This applies to
	 * both xen and openvz.
	 */
	if (reqp->isvnode && reqp->asvnode) {
		MYSQL_RES *res2;
		MYSQL_ROW row2;
		int nrows2;
		
		res = mydb_query("select l.lanid from lans as l "
				 "left join lan_attributes as la on "
				 "     la.lanid=l.lanid and la.attrkey='style' "
				 "where l.exptidx='%d' and l.type='tunnel'",
				 1, reqp->exptidx, reqp->nodeid);

		nrows = (int)mysql_num_rows(res);
		while (nrows) {
			char *bufp = buf;
			char *ip = "", *ipmask = "", *mac = "", *lan = "";
			char *mtu = "";
			
			row = mysql_fetch_row(res);
			nrows--;

			res2 = mydb_query("select lma.attrkey,lma.attrvalue "
					  " from lan_members as lm "
					  "left join lan_member_attributes as lma on "
					  "     lma.lanid=lm.lanid and "
					  "     lma.memberid=lm.memberid "
					  "where lm.lanid='%s' and lm.node_id='%s' ",
					  2, row[0], reqp->nodeid);

			if (!res2) {
				error("IFCONFIG: %s: DB Error getting tunnel members\n",
				      reqp->nodeid);
				return 1;
			}
			nrows2 = (int)mysql_num_rows(res2);
			while (nrows2) {
				row2 = mysql_fetch_row(res2);
				nrows2--;

				if (!strcmp(row2[0], "tunnel_ip")) {
					ip = row2[1];
				}
				else if (!strcmp(row2[0], "tunnel_ipmask")) {
					ipmask = row2[1];
				}
				else if (!strcmp(row2[0], "tunnel_mac")) {
					mac = row2[1];
				}
				else if (!strcmp(row2[0], "tunnel_lan")) {
					lan = row2[1];
				}
				else if (!strcmp(row2[0], "tunnel_mtu")) {
					mtu = row2[1];
				}
			}
			bufp = buf;
			bufp += OUTPUT(bufp, ebufp - bufp,
				       "INTERFACE IFACETYPE=gre "
				       "INET=%s MASK=%s MAC=%s "
				       "SPEED=100Mbps DUPLEX=full "
				       "IFACE= RTABID= LAN=%s",
				       ip, ipmask, mac, lan);

			if (vers >= 44) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " MTU=%s", mtu);
			}

			OUTPUT(bufp, ebufp - bufp, "\n");
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
			mysql_free_result(res2);
		}
		mysql_free_result(res);
	}

	/* 
	 * A whole new wart here! Aliases, as we used them previously,
	 * are too conflated with VMs and VM hosts to try and re-tool
	 * the original logic.  Now we want to use them as distinct,
	 * user-definable entities that are attached to a particular
	 * interface. They should work on both physical and virtual nodes.
	 */
	if (vers >= 40) {
		MYSQL_RES *res;
		MYSQL_ROW row;
		int nrows;
		char *nodecol = "";

		nodecol = (reqp->isvnode && reqp->asvnode) 
			? "v.vnode_id" : "v.node_id";

		res = mydb_query("select v.IP, v.mask, v.unit, v.mac, "
				 " vll.vname "
				 "from vinterfaces as v "
				 "left join virt_lan_lans as vll "
				 "on v.virtlanidx = vll.idx "
				 "and v.exptidx = vll.exptidx "
				 "where v.type='alias' and %s='%s'",
				 5, nodecol, reqp->nodeid);
		if (res == NULL)
			goto ipadone;
		
		nrows = (int)mysql_num_rows(res);
		while (nrows > 0) {
			char *bufp = buf;

			nrows--;
			row = mysql_fetch_row(res);
			if (!row || !row[0] || !row[1] || !row[2] ||
			    !row[3] || !row[4])
				continue;
			bufp += OUTPUT(bufp, ebufp - bufp,
				       "INTERFACE IFACETYPE=alias "
				       "INET=%s MASK=%s ID=%s VMAC=%s PMAC=none "
				       "RTABID= ENCAPSULATE=0 LAN=%s VTAG=",
				       row[0], CHECKMASK(row[1]), row[2],
				       row[3], row[4]);

			/* XXX expected */
			if (vers >= 44) {
				bufp += OUTPUT(bufp, ebufp - bufp, " MTU=");
			}

			OUTPUT(bufp, ebufp - bufp, "\n");
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("%s: IFCONFIG: %s", reqp->nodeid, buf);
		}
		mysql_free_result(res);
	ipadone: ;
	}

	return 0;
}

/*
 * Return account stuff.
 */
COMMAND_PROTOTYPE(doaccounts)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE], leader[TBDB_FLEN_UID];
	int		nrows, gidint;
	int		tbadmin, didwidearea = 0, nodetypeprojects = 0;
	int		didnonlocal = 0;
	int             swapper_only = 0;
	int		dohashes = 0;

	if (! tcp) {
		error("ACCOUNTS: %s: Cannot give account info out over UDP!\n",
		      reqp->nodeid);
		return 1;
	}

	/*
	 * Now check reserved table
	 */
	if ((reqp->islocal || reqp->isvnode) && !reqp->allocated) {
		error("%s: accounts: Invalid request from free node\n",
		      reqp->nodeid);
		return 1;
	}

	/*
	 * We need the group leader below.
	 */
	res = mydb_query("select leader from groups "
			 "where pid='%s' and gid='%s'",
			 1, reqp->pid, reqp->gid);
	if (res) {
		row = mysql_fetch_row(res);
		if (row[0]) {
			strcpy(leader, row[0]);
		}
		else {
			error("%s: accounts: No leader for %s/%s\n",
			      reqp->nodeid, reqp->pid, reqp->gid);
			mysql_free_result(res);
			return 1;
		}
		mysql_free_result(res);
	}
	else {
		error("%s: accounts: Could not get leader for %s/%s\n",
		      reqp->nodeid, reqp->pid, reqp->gid);
		return 1;
	}

	/*
	 * See if a per-node-type set of projects is specified for accounts.
	 */
	res = mydb_query("select na.attrvalue from nodes as n "
			 "left join node_type_attributes as na on "
			 "  n.type=na.type "
			 "where n.node_id='%s' and "
			 "na.attrkey='project_accounts'", 1, reqp->nodeid);
	if (res) {
		if ((int)mysql_num_rows(res) != 0) {
			nodetypeprojects = 1;
		}
		mysql_free_result(res);
	}

	/*
	 * See if a per-project restriction on the accounts that are
	 * created.
	 */
	res = mydb_query("select experiment_accounts from projects "
			 "where pid='%s' and experiment_accounts is not null",
			 1, reqp->pid);
	if (res) {
		if ((int)mysql_num_rows(res) != 0) {
			row = mysql_fetch_row(res);
			if (row[0]) {
				if (strcmp(row[0], "swapper") == 0) {
					swapper_only = 1;
				}
			}
		}
		mysql_free_result(res);
	}

        /*
	 * We need the unix GID and unix name for each group in the project.
	 */
	if (reqp->iscontrol) {
		/*
		 * All groups!
		 */
		res = mydb_query("select unix_name,unix_gid from groups", 2);
	}
	else if (nodetypeprojects) {
		/*
		 * The projects/groups are specified as a comma separated
		 * list in the node_type_attributes table. Return this
		 * set of groups, plus those in emulab-ops since we want
		 * to include admin people too.
		 */
		res = mydb_query("select g.unix_name,g.unix_gid "
				 " from projects as p "
				 "left join groups as g on "
				 "     p.pid_idx=g.pid_idx "
				 "where p.approved!=0 and "
				 "  (FIND_IN_SET(g.gid_idx, "
				 "   (select na.attrvalue from nodes as n "
				 "    left join node_type_attributes as na on "
				 "         n.type=na.type "
				 "    where n.node_id='%s' and "
				 "    na.attrkey='project_accounts')) > 0 or "
				 "   p.pid='%s')",
				 2, reqp->nodeid, RELOADPID);
	}
	else if ((reqp->jailflag && !reqp->islocal) ||
		 (reqp->islocal && reqp->sharing_mode[0] && !reqp->isvnode) ||
		 HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX)) {
		/*
		 * This is for a remote node doing jails, a shared host, or
		 * a node with 'blackbox' taintstate. We still want to return
		 * a group for the admin people who get accounts outside
		 * the jails.  Send back the "emulab-ops" group info.
		 */
		res = mydb_query("select unix_name,unix_gid from groups "
				 "where pid='%s'",
				 2, RELOADPID);
	}
	else if (reqp->isvnode || reqp->islocal ||
		 (!reqp->islocal && reqp->isdedicatedwa)) {
		res = mydb_query("select unix_name,unix_gid from groups "
				 "where pid='%s'",
				 2, reqp->pid);
	}
	else if (!reqp->islocal) {
		/*
		 * XXX - Old style node, not doing jails.
		 *
		 * Added this for Dave. I love subqueries!
		 */
		res = mydb_query("select g.unix_name,g.unix_gid "
				 " from projects as p "
				 "left join groups as g on p.pid=g.pid "
				 "where p.approved!=0 and "
				 "  FIND_IN_SET(g.gid_idx, "
				 "   (select attrvalue from node_attributes "
				 "      where node_id='%s' and "
				 "            attrkey='dp_projects')) > 0",
				 2, reqp->pnodeid);

		if (!res || (int)mysql_num_rows(res) == 0) {
		 /*
		  * Temporary hack until we figure out the right model for
		  * remote nodes. For now, we use the pcremote-ok slot in
		  * in the project table to determine what remote nodes are
		  * okay'ed for the project. If connecting node type is in
		  * that list, then return all of the project groups, for
		  * each project that is allowed to get accounts on the type.
		  */
		  res = mydb_query("select g.unix_name,g.unix_gid "
				   "  from projects as p "
				   "join groups as g on p.pid=g.pid "
				   "where p.approved!=0 and "
				   "      FIND_IN_SET('%s',pcremote_ok)>0",
				   2, reqp->type);
		}
	}
	else {
		error("ACCOUNTS: %s: GIDs Fell off the bottom!\n", reqp->pid);
		return 1;
	}
	if (!res) {
		error("ACCOUNTS: %s: DB Error getting gids!\n", reqp->pid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		error("ACCOUNTS: %s: No Project!\n", reqp->pid);
		mysql_free_result(res);
		return 1;
	}

	while (nrows) {
		row = mysql_fetch_row(res);
		if (!row[1] || !row[1][1]) {
			error("ACCOUNTS: %s: No Project GID!\n", reqp->pid);
			mysql_free_result(res);
			return 1;
		}

		gidint = atoi(row[1]);
		OUTPUT(buf, sizeof(buf),
		       "ADDGROUP NAME=%s GID=%d\n", row[0], gidint);
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("%s: ACCOUNTS: %s", reqp->nodeid, buf);

		nrows--;
	}
	mysql_free_result(res);

	/*
	 * Each time a node picks up accounts, decrement the update
	 * counter. This ensures that if someone kicks off another
	 * update after this point, the node will end up getting to
	 * do it again in case it missed something.
	 */
	if (mydb_update("update nodes set update_accounts=update_accounts-1 "
			"where node_id='%s' and update_accounts!=0",
			reqp->nodeid)) {
		error("ACCOUNTS: %s: DB Error setting exit update_accounts!\n",
		      reqp->nodeid);
	}
#ifdef EVENTSYS
	if (reqp->update_accounts) {
		address_tuple_t tuple;
		char buf[BUFSIZ];

		tuple = address_tuple_alloc();
		if (tuple == NULL) {
			error("ACCOUNTS: Unable to allocate address tuple!\n");
		}
		else {
			tuple->host      = BOSSNODE;
			tuple->objtype   = "TBUPDATEACCOUNTS";
			tuple->objname	 = reqp->nodeid;
			sprintf(buf, "%d", reqp->update_accounts);
			tuple->eventtype = buf;

			if (myevent_send(tuple)) {
				error("Error sending event\n");
				info("%s: STARTSTAT: sendevent failed!\n",
				     reqp->nodeid);
			}
			address_tuple_free(tuple);
		}
	}
#endif /* EVENTSYS */

	/*
	 * For local nodes, see if we should return password hashes.
	 * This is controlled by the node/user_passwords sitevar.
	 */
	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='node/user_passwords'", 2);
	if (res) {
		if ((int)mysql_num_rows(res) > 0) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0])
				dohashes = atoi(row[0]);
			else if (row[1] && row[1][0])
				dohashes = atoi(row[1]);
		}
		mysql_free_result(res);
	}

	/*
	 * Now onto the users in the project.
	 */
	if (reqp->iscontrol) {
		char *passwdfield = dohashes ? "u.usr_pswd" : "'*'";

		/*
		 * All users! This is not currently used. The problem
		 * is that returning a list of hundreds of users whenever
		 * any single change is required is bad. Works fine for
		 * experimental nodes where the number of accounts is small,
		 * but is not scalable.
		 */
		res = mydb_query("select distinct "
				 "  u.uid,%s,u.unix_uid,u.usr_name, "
				 "  p.trust,g.pid,g.gid,g.unix_gid,u.admin, "
				 "  u.emulab_pubkey,u.home_pubkey, "
				 "  UNIX_TIMESTAMP(u.usr_modified), "
				 "  u.usr_email,u.usr_shell,u.uid_idx "
				 "from group_membership as p "
				 "join users as u on p.uid_idx=u.uid_idx "
				 "join groups as g on p.pid=g.pid "
				 "where p.trust!='none' "
				 "      and u.webonly=0 "
                                 "      and g.unix_id is not NULL "
				 "      and u.status='active' order by u.uid",
				 15, passwdfield);
	}
	else if (nodetypeprojects) {
		/*
		 * The projects/groups are specified as a comma separated
		 * list in the node_type_attributes table. Return this
		 * set of users.
		 */
		res = mydb_query("select distinct  "
				 "u.uid,'*',u.unix_uid,u.usr_name, "
				 "m.trust,g.pid,g.gid,g.unix_gid,u.admin, "
				 "u.emulab_pubkey,u.home_pubkey, "
				 "UNIX_TIMESTAMP(u.usr_modified), "
				 "u.usr_email,u.usr_shell, "
				 "u.widearearoot,u.wideareajailroot, "
				 "u.usr_w_pswd,u.uid_idx "
				 "from projects as p "
				 "join group_membership as m on "
				 "     m.pid_idx=p.pid_idx "
				 "join groups as g on "
				 "     g.gid_idx=m.gid_idx "
				 "join users as u on u.uid_idx=m.uid_idx "
				 "where p.approved!=0 "
				 "      and m.trust!='none' "
				 "      and u.webonly=0 "
                                 "      and g.unix_gid is not NULL "
				 "      and u.status='active' "
				 "      and u.admin=0 and "
				 "  (FIND_IN_SET(g.gid_idx, "
				 "   (select na.attrvalue from nodes as n "
				 "    left join node_type_attributes as na on "
				 "         n.type=na.type "
				 "    where n.node_id='%s' and "
				 "    na.attrkey='project_accounts')) > 0) "
				 "order by u.uid",
				 18, reqp->nodeid);
	}
	else if ((reqp->jailflag && !reqp->islocal) ||
		 (reqp->islocal && reqp->sharing_mode[0] && !reqp->isvnode) ||
		 HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX)) {
		/*
		 * A remote node doing jails, a local node being
		 * shared, or a node with 'blackbox' taintstate:
		 * We still want to return accounts for the
		 * admin people. Note that remote jail
		 * case is effectively deprecated at this point.
		 */
		res = mydb_query("select distinct "
			     "  u.uid,'*',u.unix_uid,u.usr_name, "
			     "  p.trust,g.pid,g.gid,g.unix_gid,u.admin, "
			     "  u.emulab_pubkey,u.home_pubkey, "
			     "  UNIX_TIMESTAMP(u.usr_modified), "
			     "  u.usr_email,u.usr_shell, "
			     "  u.widearearoot,u.wideareajailroot, "
			     "  u.usr_w_pswd,u.uid_idx "
			     "from group_membership as p "
			     "join users as u on p.uid_idx=u.uid_idx "
			     "join groups as g on "
			     "     p.pid=g.pid and p.gid=g.gid "
			     "where (p.pid='%s') and p.trust!='none' "
			     "      and u.status='active' and "
			     "      (u.admin=1 or u.uid='%s') "
			     "      order by u.uid",
			     18, RELOADPID, PROTOUSER);
	}
	else if (reqp->isvnode || reqp->islocal || 
		 (!reqp->islocal && reqp->isdedicatedwa)) {
		/*
		 * This crazy join is going to give us multiple lines for
		 * each user that is allowed on the node, where each line
		 * (for each user) differs by the project PID and it unix
		 * GID. The intent is to build up a list of GIDs for each
		 * user to return. Well, a primary group and a list of aux
		 * groups for that user.
		 */
	  	char adminclause[MYBUFSIZE];
		char *passwdfield =
			(!dohashes || (!reqp->islocal && reqp->isdedicatedwa))?
			"'*'" : "u.usr_pswd";
		strcpy(adminclause, "");
#ifdef ISOLATEADMINS
		sprintf(adminclause, "and u.admin=%d", reqp->swapper_isadmin);
#endif
		/*
		 * An experiment in a subgroup gets only the users in the
		 * subgroup.
		 */
		char subclause[MYBUFSIZE];

		if (strcmp(reqp->pid, reqp->gid)) {
			sprintf(subclause,
				"join groups as g on "
				"     p.pid=g.pid "
				"where (p.pid='%s' and p.gid='%s')",
				reqp->pid, reqp->gid);
		}
		else {
			sprintf(subclause,
				"join groups as g on "
				"     p.pid=g.pid and p.gid=g.gid "
				"where (p.pid='%s')", reqp->pid);
		}
		res = mydb_query("select distinct "
				 "  u.uid,%s,u.unix_uid,u.usr_name, "
				 "  p.trust,g.pid,g.gid,g.unix_gid,u.admin, "
				 "  u.emulab_pubkey,u.home_pubkey, "
				 "  UNIX_TIMESTAMP(u.usr_modified), "
				 "  u.usr_email,u.usr_shell, "
				 "  u.widearearoot,u.wideareajailroot, "
				 "  u.usr_w_pswd,u.uid_idx "
				 "from group_membership as p "
				 "join users as u on p.uid_idx=u.uid_idx "
				 "%s "
				 "      and p.trust!='none' "
				 "      and u.status='active' "
				 "      and u.webonly=0 "
				 "      %s "
                                 "      and g.unix_gid is not NULL "
				 "order by u.uid",
				 18, passwdfield, subclause, adminclause);
	}
	else if (! reqp->islocal) {
		/*
		 * XXX - Old style node, not doing jails.
		 *
		 * Temporary hack until we figure out the right model for
		 * remote nodes. For now, we use the pcremote-ok slot in
		 * in the project table to determine what remote nodes are
		 * okay'ed for the project. If connecting node type is in
		 * that list, then return user info for all of the users
		 * in those projects (crossed with group in the project).
		 */
		char subclause[MYBUFSIZE];
		int  count = 0;

		res = mydb_query("select attrvalue from node_attributes "
				 " where node_id='%s' and "
				 "       attrkey='dp_projects'",
				 1, reqp->pnodeid);

		if (res) {
			if ((int)mysql_num_rows(res) > 0) {
				row = mysql_fetch_row(res);

				count = snprintf(subclause,
					     sizeof(subclause) - 1,
					     "FIND_IN_SET(g.gid_idx,'%s')>0",
					     row[0]);
			}
			else {
				count = snprintf(subclause,
					     sizeof(subclause) - 1,
					     "FIND_IN_SET('%s',pcremote_ok)>0",
					     reqp->type);
			}
			mysql_free_result(res);

			if (count >= sizeof(subclause)) {
				error("ACCOUNTS: %s: Subclause too long!\n",
				      reqp->nodeid);
				return 1;
			}
		}

		res = mydb_query("select distinct  "
				 "u.uid,'*',u.unix_uid,u.usr_name, "
				 "m.trust,g.pid,g.gid,g.unix_gid,u.admin, "
				 "u.emulab_pubkey,u.home_pubkey, "
				 "UNIX_TIMESTAMP(u.usr_modified), "
				 "u.usr_email,u.usr_shell, "
				 "u.widearearoot,u.wideareajailroot, "
				 "u.usr_w_pswd,u.uid_idx "
				 "from projects as p "
				 "join group_membership as m "
				 "  on m.pid=p.pid "
				 "join groups as g on "
				 "  g.pid=m.pid and g.gid=m.gid "
				 "join users as u on u.uid_idx=m.uid_idx "
				 "where p.approved!=0 "
				 "      and %s "
				 "      and m.trust!='none' "
				 "      and u.webonly=0 "
				 "      and u.admin=0 "
                                 "      and g.unix_gid is not NULL "
				 "      and u.status='active' "
				 "order by u.uid",
				 18, subclause);
	}
	else {
		error("ACCOUNTS: %s: UIDs Fell off the bottom!\n", reqp->pid);
		return 1;
	}
	if (!res) {
		error("ACCOUNTS: %s: DB Error getting users!\n", reqp->pid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		error("ACCOUNTS: %s: No Users!\n", reqp->pid);
		mysql_free_result(res);
		return 0;
	}

 again:
	row = mysql_fetch_row(res);
	while (nrows) {
		MYSQL_ROW	nextrow = 0;
		MYSQL_RES	*pubkeys_res;
		MYSQL_RES	*sfskeys_res;
		int		pubkeys_nrows, sfskeys_nrows, i, root = 0;
		int		auxgids[1024], gcount = 0, isleader;
		char		glist[sizeof(buf)-512];
		char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
		char		*pswd, *wpswd, wpswd_buf[9];
		int		maxgcount = sizeof(auxgids) / sizeof(int) - 1;

		gidint     = -1;
		tbadmin    = root = atoi(row[8]);
		isleader   = 0;
		gcount     = 0;

		while (1) {

			/*
			 * The whole point of this mess. Figure out the
			 * main GID and the aux GIDs. Perhaps trying to make
			 * distinction between main and aux is unecessary, as
			 * long as the entire set is represented.
			 */
			if (strcmp(row[5], reqp->pid) == 0 &&
			    strcmp(row[6], reqp->gid) == 0) {
				gidint = atoi(row[7]);

				/*
				 * Only people in the main pid can get root
				 * at this time, so do this test here.
				 */
				if ((strcmp(row[4], "local_root") == 0) ||
				    (strcmp(row[4], "group_root") == 0) ||
				    (strcmp(row[4], "project_root") == 0))
					root = 1;
				
				if (strcmp(leader, row[0]) == 0) 
					isleader = 1;
			}
			else {
				int k, newgid = atoi(row[7]);

				/*
				 * Avoid dups, which can happen because of
				 * different trust levels in the join.
				 */
				for (k = 0; k < gcount; k++) {
				    if (auxgids[k] == newgid)
					goto skipit;
				}
				if (gcount > maxgcount) {
					if (gcount == maxgcount+1)
						error("Too many groups for user %s! "
						      "Only passing %d.\n",
						      row[0], maxgcount);
					goto skipit;
				}
				auxgids[gcount++] = newgid;
			skipit:
				;
			}
			nrows--;

			if (!nrows)
				break;

			/*
			 * See if the next row is the same UID. If so,
			 * we go around the inner loop again.
			 */
			nextrow = mysql_fetch_row(res);
			if (strcmp(row[0], nextrow[0]))
				break;
			row = nextrow;
		}

		/*
		 * widearearoot and wideareajailroot override trust values
		 * from the project (above) (IF the node is not isdedicatedwa,
		 * since these must behave like local). Of course, tbadmin
		 * overrides everthing!
		 */
		if (!reqp->islocal && !reqp->isdedicatedwa && !reqp->isplabdslice) {
			if (!reqp->isvnode)
				root = atoi(row[14]);
			else
				root = atoi(row[15]);

			if (tbadmin)
				root = 1;
		}

		/* 
		 * Nuke the root flag if the node is tainted with
		 * 'usermode', except for admins.  The 'blackbox' taintstate
		 * has already restricted the set of users to admins,
		 * so no need to check for that.
		 */
		if (HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_USERONLY) && 
		    !tbadmin)
		        root = 0;

		/* There is an optional Windows password column. */
		pswd = row[1];
		wpswd = row[16];
		if (strncmp(rdata, "windows", 7) == 0) {
			if (wpswd != NULL && strlen(wpswd) > 0) {
				row[1] = wpswd;
			}
			else {

				/* The initial random default for the Windows Password
				 * is based on the Unix encrypted password hash, in
				 * particular the random salt when it's an MD5 crypt.
				 * THis is the 8 characters after an initial "$1$" and
				 * followed by a "$".  Just use the first 8 chars if
				 * the hash is not an MD5 crypt.
				 */
				strncpy(wpswd_buf,
					(strncmp(pswd,"$1$",3)==0) ? pswd + 3 : pswd,
					8);
				wpswd_buf[8]='\0';
				row[1] = wpswd_buf;
			}
		}

		/*
		 * Okay, process the UID. If there is no primary gid,
		 * then use one from the list. Then convert the rest of
		 * the list for the GLIST argument below.
		 */

		/*
		 * The point of this test it to make sure that we do not
		 * return the project accounts in a geni experiment that is
		 * started in a nonlocal project. Those accounts are just
		 * stubs, the real accounts come from the ssh keys provided
		 * in the Geni API call (see nonlocal_user_accounts below).
		 * But we do need the project leader (geniuser), which is
		 * why we are in this part of the code at all. There is a
		 * corresponding test down below to make sure that we return
		 * *only* the project accounts when it is a *local* project
		 * (PROTOGENI_LOCALUSER=1); in this case we do not want any
		 * of the ssh accounts that came in with the Geni API call.
		 */
		if (reqp->genisliver_idx && reqp->isnonlocal_pid &&
		    !didnonlocal && !isleader)
			goto skipkeys;

		/*
		 * Watch for a swapper only project flag.
		 */
		if (swapper_only && !isleader &&
		    strcmp(reqp->swapper, row[0])) {
			goto skipkeys;
		}
		
		if (gidint == -1) {
			gidint = auxgids[--gcount];
		}
		glist[0] = '\0';
		if (gcount > 0) {
			int tlen;
			size_t sz;

			sprintf(&glist[0], "%d", auxgids[0]);
			tlen = strlen(glist);
			for (i = 1; i < gcount && tlen < sizeof(glist); i++) {
				sz = sizeof(glist) - tlen;
				if (snprintf(&glist[tlen], sz, ",%d",
					     auxgids[i]) >= sz) {
					error("Too many groups for user %s! "
					      "Only passing %d of %d.\n",
					      row[0], i, gcount);
					glist[tlen] = '\0';
					break;
				}
				tlen = strlen(glist);
			}
		}

		if (vers < 4) {
			bufp += OUTPUT(buf, sizeof(buf),
				"ADDUSER LOGIN=%s "
				"PSWD=%s UID=%s GID=%d ROOT=%d NAME=\"%s\" "
				"HOMEDIR=%s/%s GLIST=%s\n",
				row[0], row[1], row[2], gidint, root, row[3],
				USERDIR, row[0], glist);
		}
		else if (vers == 4) {
			bufp += OUTPUT(buf, sizeof(buf),
				"ADDUSER LOGIN=%s "
				"PSWD=%s UID=%s GID=%d ROOT=%d NAME=\"%s\" "
				"HOMEDIR=%s/%s GLIST=\"%s\" "
				"EMULABPUBKEY=\"%s\" HOMEPUBKEY=\"%s\"\n",
				row[0], row[1], row[2], gidint, root, row[3],
				USERDIR, row[0], glist,
				row[9] ? row[9] : "",
				row[10] ? row[10] : "");
		}
		else {
			if (!reqp->islocal) {
				if (vers == 5)
					row[1] = "'*'";
				else
					row[1] = "*";
			}
			bufp += OUTPUT(buf, sizeof(buf),
				"ADDUSER LOGIN=%s "
				"PSWD=%s UID=%s GID=%d ROOT=%d NAME=\"%s\" "
				"HOMEDIR=%s/%s GLIST=\"%s\" SERIAL=%s",
				row[0], row[1], row[2], gidint, root, row[3],
				USERDIR, row[0], glist, row[11]);

			if (vers >= 9) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " EMAIL=\"%s\"", row[12]);
			}
			if (vers >= 10) {
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " SHELL=%s", row[13]);
			}
			OUTPUT(bufp, ebufp - bufp, "\n");
		}

		client_writeback(sock, buf, strlen(buf), tcp);

		if (verbose)
			info("ACCOUNTS: "
			     "ADDUSER LOGIN=%s "
			     "UID=%s GID=%d ROOT=%d GLIST=%s\n",
			     row[0], row[2], gidint, root, glist);

		if (vers < 5)
			goto skipkeys;

		/*
		 * Skip pubkeys locally unless the node/experiment has no
		 * shared mounts, is a GENI sliver (no /users mounts).  is
		 * running Windows ("windows" arg), or explicitly asks for
		 * them ("pubkeys" arg).
		 */
#ifndef NOSHAREDFS
		if (reqp->islocal &&
		    ! (strcmp(reqp->nfsmounts, "none") == 0 ||
		       strcmp(reqp->nfsmounts, "genidefault") == 0) &&
		    ! reqp->sharing_mode[0] &&
		    ! (strncmp(rdata, "pubkeys", 7) == 0
		       || strncmp(rdata, "windows", 7) == 0))
			goto skipsshkeys;
#endif

		/*
		 * Need a list of keys for this user.
		 */
		if (didnonlocal) {
			pubkeys_res = mydb_query("select idx,pubkey "
						 " from nonlocal_user_pubkeys "
						 "where uid_idx='%s'",
						 2, row[17]);
		}
		else {
			pubkeys_res = mydb_query("select idx,pubkey "
						 " from user_pubkeys "
						 "where uid_idx='%s'",
						 2, row[17]);
		}
		if (!pubkeys_res) {
			error("ACCOUNTS: %s: DB Error getting keys\n", row[0]);
			goto skipkeys;
		}
		if ((pubkeys_nrows = (int)mysql_num_rows(pubkeys_res))) {
			while (pubkeys_nrows) {
				MYSQL_ROW	pubkey_row;
				int		klen;
				char		*kbuf;

				pubkey_row = mysql_fetch_row(pubkeys_res);

#define _KHDR	"PUBKEY LOGIN=%s KEY=\"%s\"\n"
				/*
				 * Pubkeys can be large, so we may have to
				 * malloc a special buffer.
				 */
				klen = strlen(_KHDR)
					+ strlen(row[0])
					+ strlen(pubkey_row[1])
					- 4 /* 2 x %s */
					+ 1;
				if (klen > sizeof(buf) - 1) {
					kbuf = malloc(klen);
					if (kbuf == 0) {
						info("ACCOUNT: WARNING "
						     "pubkey for %s too large, "
						     "skipped\n", row[0]);
						pubkeys_nrows--;
						continue;
					}
				} else {
					kbuf = buf;
					klen = sizeof(buf);
				}
				OUTPUT(kbuf, klen, _KHDR,
				       row[0], pubkey_row[1]);
				client_writeback(sock, kbuf, strlen(kbuf), tcp);
				if (kbuf != buf)
					free(kbuf);
				pubkeys_nrows--;
#undef _KHDR

				if (verbose)
					info("ACCOUNTS: PUBKEY LOGIN=%s "
					     "IDX=%s\n",
					     row[0], pubkey_row[0]);
			}
		}
		mysql_free_result(pubkeys_res);

#ifndef NOSHAREDFS
	skipsshkeys:
#endif
		/*
		 * Do not bother to send back SFS keys if the node is not
		 * running SFS.
		 */
		if (vers < 6 || !strlen(reqp->sfshostid))
			goto skipkeys;

		/*
		 * Need a list of SFS keys for this user.
		 */
		sfskeys_res = mydb_query("select comment,pubkey "
					 " from user_sfskeys "
					 "where uid_idx='%s'",
					 2, row[17]);

		if (!sfskeys_res) {
			error("ACCOUNTS: %s: DB Error getting SFS keys\n", row[0]);
			goto skipkeys;
		}
		if ((sfskeys_nrows = (int)mysql_num_rows(sfskeys_res))) {
			while (sfskeys_nrows) {
				MYSQL_ROW	sfskey_row;

				sfskey_row = mysql_fetch_row(sfskeys_res);

				OUTPUT(buf, sizeof(buf),
				       "SFSKEY KEY=\"%s\"\n", sfskey_row[1]);

				client_writeback(sock, buf, strlen(buf), tcp);
				sfskeys_nrows--;

				if (verbose)
					info("ACCOUNTS: SFSKEY LOGIN=%s "
					     "COMMENT=%s\n",
					     row[0], sfskey_row[0]);
			}
		}
		mysql_free_result(sfskeys_res);

	skipkeys:
		row = nextrow;
	}
	mysql_free_result(res);

	/* No more accounts will be added if the node has 'blackbox' taint. */
	if (!(reqp->islocal || reqp->isvnode) && !didwidearea &&
	    !HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX)) {
		didwidearea = 1;

		/*
		 * Sleazy. The only real downside though is that
		 * we could get some duplicate entries, which won't
		 * really harm anything on the client.
		 */
		res = mydb_query("select distinct "
				 "u.uid,'*',u.unix_uid,u.usr_name, "
				 "w.trust,'guest','guest',31,u.admin, "
				 "u.emulab_pubkey,u.home_pubkey, "
				 "UNIX_TIMESTAMP(u.usr_modified), "
				 "u.usr_email,u.usr_shell, "
				 "u.widearearoot,u.wideareajailroot "
				 "from widearea_accounts as w "
				 "join users as u on u.uid_idx=w.uid_idx "
				 "where w.trust!='none' and "
				 "      u.status='active' and "
				 "      node_id='%s' "
				 "order by u.uid",
				 16, reqp->nodeid);

		if (res) {
			if ((nrows = mysql_num_rows(res)))
				goto again;
			else
				mysql_free_result(res);
		}
	}

	/*
	 * When sharing mode is on, do not return these accounts to pnodes.
	 * Note that sharing_mode and genisliver_idx should not both be set
	 * on a pnode, but lets be careful.
	 * 
	 * No more accounts will be added if the node has 'blackbox' taint.
	 * If nfsmounts=emulabdefault, then we use the local users only.
	 */
	if (reqp->genisliver_idx && reqp->isnonlocal_pid && !didnonlocal &&
	    strcmp(reqp->nfsmounts, "emulabdefault") &&
	    (reqp->isvnode || !reqp->sharing_mode[0]) &&
	    !HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX)) {
	        didnonlocal = 1;

		/*
		 * Within the nonlocal_user_accounts table, we do not
		 * maintain globally unique unix_uid numbers, since these
		 * accounts are per slice (experiment). Instead, just
		 * use an auto_increment field, which always starts at
		 * 1, and so to create a unix_gid, we just bump the
		 * number into a typically unused area of the space.
		 */
		res = mydb_query("select distinct "
				 "  u.uid,'*', "
				 "  u.unix_uid+20000,"
				 "  u.name, "
				 "  u.privs,g.pid,g.gid,g.unix_gid,0, "
				 "  NULL,NULL, "
				 "  UNIX_TIMESTAMP(u.updated), "
				 "  u.email,u.shell, "
				 "  0,0, "
				 "  NULL,u.uid_idx "
				 "from nonlocal_user_accounts as u "
				 "join groups as g on "
				 "     g.pid='%s' and "
				 "     (g.pid=g.gid or g.gid='%s') "
				 "where (u.exptidx='%d') "
				 "order by u.uid",
				 18, reqp->pid, reqp->gid,
				 reqp->exptidx);

		if (res) {
			if ((nrows = mysql_num_rows(res)))
				goto again;
			else
				mysql_free_result(res);
		}
	}
	return 0;
}

/*
 * Return delay config stuff.
 */
COMMAND_PROTOTYPE(dodelay)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE], *ebufp = &buf[sizeof(buf)];
	int		nrows;

	/*
	 * Get delay parameters for the machine. The point of this silly
	 * join is to get the type out so that we can pass it back. Of
	 * course, this assumes that the type is the BSD name, not linux.
	 */
	res = mydb_query("select i.MAC,j.MAC, "
		 "pipe0,delay0,bandwidth0,lossrate0,q0_red, "
		 "pipe1,delay1,bandwidth1,lossrate1,q1_red, "
		 "d.vname, "
		 "q0_limit,q0_maxthresh,q0_minthresh,q0_weight,q0_linterm, "
		 "q0_qinbytes,q0_bytes,q0_meanpsize,q0_wait,q0_setbit, "
		 "q0_droptail,q0_gentle, "
		 "q1_limit,q1_maxthresh,q1_minthresh,q1_weight,q1_linterm, "
		 "q1_qinbytes,q1_bytes,q1_meanpsize,q1_wait,q1_setbit, "
		 "q1_droptail,q1_gentle,vnode0,vnode1,noshaping, "
		 "backfill0,backfill1,isbridge,vlan0,vlan1,v1.mac,v2.mac "
                 " from delays as d "
		 "left join interfaces as i on "
		 " i.node_id=d.node_id and i.iface=iface0 "
		 "left join interfaces as j on "
		 " j.node_id=d.node_id and j.iface=iface1 "
		 "left join vinterfaces as v1 on "
		 "   v1.node_id=d.node_id and v1.exptidx=d.exptidx and "
		 "   v1.unit=d.viface_unit0 "
		 "left join vinterfaces as v2 on "
		 "   v2.node_id=d.node_id and v2.exptidx=d.exptidx and "
		 "   v2.unit=d.viface_unit1 "
		 " where d.node_id='%s'",
		 47, reqp->nodeid);
	if (!res) {
		error("DELAY: %s: DB Error getting delays!\n", reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	while (nrows) {
		char	*bufp = buf;
		int     isbridge;
		char    *vnode0, *vnode1;

		row = mysql_fetch_row(res);

		/*
		 * Yikes, this is ugly! Sanity check though, since I saw
		 * some bogus values in the DB.
		 */
		if (!row[0] || !row[1] || !row[2] || !row[3]) {
			error("DELAY: %s: DB values are bogus!\n",
			      reqp->nodeid);
			mysql_free_result(res);
			return 1;
		}
		isbridge = atoi(row[42]);
		if (isbridge) {
			vnode0 = row[43];
			vnode1 = row[44];
		}
		else {
			vnode0 = (row[37] ? row[37] : "foo");
			vnode1 = (row[38] ? row[38] : "bar");
		}
		bufp += OUTPUT(bufp, ebufp - bufp,
			"DELAY INT0=%s INT1=%s "
			"PIPE0=%s DELAY0=%s BW0=%s PLR0=%s "
			"PIPE1=%s DELAY1=%s BW1=%s PLR1=%s "
			"LINKNAME=%s "
			"RED0=%s RED1=%s "
			"LIMIT0=%s MAXTHRESH0=%s MINTHRESH0=%s WEIGHT0=%s "
			"LINTERM0=%s QINBYTES0=%s BYTES0=%s "
			"MEANPSIZE0=%s WAIT0=%s SETBIT0=%s "
			"DROPTAIL0=%s GENTLE0=%s "
			"LIMIT1=%s MAXTHRESH1=%s MINTHRESH1=%s WEIGHT1=%s "
			"LINTERM1=%s QINBYTES1=%s BYTES1=%s "
			"MEANPSIZE1=%s WAIT1=%s SETBIT1=%s "
			"DROPTAIL1=%s GENTLE1=%s "
			"VNODE0=%s VNODE1=%s "
			"NOSHAPING=%s "
			"BACKFILL0=%s BACKFILL1=%s\n",
			(row[45] ? row[45] : row[0]),
			(row[46] ? row[46] : row[1]),
			row[2], row[3], row[4], row[5],
			row[7], row[8], row[9], row[10],
			row[12],
			row[6], row[11],
			row[13], row[14], row[15], row[16],
			row[17], row[18], row[19],
			row[20], row[21], row[22],
			row[23], row[24],
			row[25], row[26], row[27], row[28],
			row[29], row[30], row[31],
			row[32], row[33], row[34],
			row[35], row[36], vnode0, vnode1,
			row[39],
			row[40], row[41]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("DELAY: %s", buf);
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Return link delay config stuff.
 */
COMMAND_PROTOTYPE(dolinkdelay)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE];
	int		nrows;

	/*
	 * Get link delay parameters for the machine. We store veth
	 * interfaces in another dynamic table, so must join with both
	 * interfaces and vinterfaces to see which iface this link
	 * delay corresponds to. If there is a veth entry use that, else
	 * use the normal interfaces entry. I do not like this much.
	 * Maybe we should use the regular interfaces table, with type veth,
	 * entries added/deleted on the fly. I avoided that cause I view
	 * the interfaces table as static and pertaining to physical
	 * interfaces.
	 *
	 * Outside a vnode, return only those linkdelays for veths that have
	 * vnode=NULL, which indicates its an emulated interface on a
	 * physical node. When inside a vnode, only return veths for which
	 * vnode=curvnode, which are the interfaces that correspond to a
	 * jail node.
	 */
	if (reqp->isvnode)
		sprintf(buf, "and v.vnode_id='%s'", reqp->vnodeid);
	else
		strcpy(buf, "and v.vnode_id is NULL");

	res = mydb_query("select i.MAC,d.type,vlan,vnode,d.ip,netmask, "
		 "pipe,delay,d.bandwidth,lossrate, "
		 "rpipe,rdelay,rbandwidth,rlossrate, "
		 "q_red,q_limit,q_maxthresh,q_minthresh,q_weight,q_linterm, "
		 "q_qinbytes,q_bytes,q_meanpsize,q_wait,q_setbit, "
		 "q_droptail,q_gentle,v.mac "
                 " from linkdelays as d "
		 "left join interfaces as i on "
		 " i.node_id=d.node_id and i.iface=d.iface "
		 "left join vinterfaces as v on "
		 " v.node_id=d.node_id and v.IP=d.ip "
		 "where d.node_id='%s' and d.exptidx='%d' %s",
		 28, reqp->pnodeid, reqp->exptidx, buf);
	if (!res) {
		error("LINKDELAY: %s: DB Error getting link delays!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	while (nrows) {
		row = mysql_fetch_row(res);

		OUTPUT(buf, sizeof(buf),
		        "LINKDELAY IFACE=%s TYPE=%s "
			"LINKNAME=%s VNODE=%s INET=%s MASK=%s "
			"PIPE=%s DELAY=%s BW=%s PLR=%s "
			"RPIPE=%s RDELAY=%s RBW=%s RPLR=%s "
			"RED=%s LIMIT=%s MAXTHRESH=%s MINTHRESH=%s WEIGHT=%s "
			"LINTERM=%s QINBYTES=%s BYTES=%s "
			"MEANPSIZE=%s WAIT=%s SETBIT=%s "
			"DROPTAIL=%s GENTLE=%s\n",
			(row[27] ? row[27] : row[0]), row[1],
			row[2],  row[3],  row[4],  CHECKMASK(row[5]),
			row[6],	 row[7],  row[8],  row[9],
			row[10], row[11], row[12], row[13],
			row[14], row[15], row[16], row[17], row[18],
			row[19], row[20], row[21],
			row[22], row[23], row[24],
			row[25], row[26]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("LINKDELAY: %s", buf);
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Return bridge config stuff.
 */
COMMAND_PROTOTYPE(dobridges)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE], *ebufp = &buf[sizeof(buf)];
	int		nrows;

	/*
	 * Get bridge parameters for the machine. 
	 */
	res = mydb_query("select b.bridx,i.MAC,b.vnode,b.vname "
			 " from bridges as b "
			 "left join interfaces as i on "
			 " i.node_id=b.node_id and i.iface=b.iface "
			 " where b.node_id='%s' order by bridx",
			 4, reqp->nodeid);
	if (!res) {
		error("BRIDGES: %s: DB Error getting bridges!\n", reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	while (nrows) {
		char	*bufp = buf;

		row = mysql_fetch_row(res);

		/*
		 * Sanity check.
		 */
		if (!row[0] || !row[1] || !row[2] || !row[3]) {
			error("BRIDGES: %s: DB values are bogus!\n",
			      reqp->nodeid);
			mysql_free_result(res);
			return 1;
		}

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "BRIDGE IDX=%s IFACE=%s VNODE=%s LINKNAME=%s\n",
			       row[0], row[1], row[2], row[3]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("BRIDGES: %s", buf);
	}
	mysql_free_result(res);

	return 0;
}

COMMAND_PROTOTYPE(dohosts)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		hostcount, nrows;
	int		rv = 0;
	char		*thisvnode = (char *) NULL;

	/*
	 * We build up a canonical host table using this data structure.
	 * There is one item per node/iface. We need a shared structure
	 * though for each node, to allow us to compute the aliases.
	 */
	struct shareditem {
	    	int	hasalias;
		char	*firstvlan;	/* The first vlan to another node */
		int	is_me;          /* 1 if this node is the tmcc client */
	};
	struct shareditem *shareditem = (struct shareditem *) NULL;

	struct hostentry {
		char	nodeid[TBDB_FLEN_NODEID];
		char	vname[TBDB_FLEN_VNAME];
		char	vlan[TBDB_FLEN_VNAME];
		int	virtiface;
		struct in_addr	  ipaddr;
		struct shareditem *shared;
		struct hostentry  *next;
	} *hosts = 0, *host;

	/*
	 * Now use the virt_nodes table to get a list of all of the
	 * nodes and all of the IPs on those nodes. This is the basis
	 * for the canonical host table. Join it with the reserved
	 * table to get the node_id at the same time (saves a step).
	 *
	 * XXX NSE hack: Using the v2pmap table instead of reserved because
	 * of multiple simulated to one physical node mapping. Currently,
	 * reserved table contains a vname which is generated in the case of
	 * nse
	 *
	 * XXX PELAB hack: If virt_lans.protocol is 'ipv4' then this is a
	 * "LAN" of real internet nodes and we should return the control
	 * network IP address.  The intent is to give plab nodes some
	 * convenient aliases for refering to each other.
	 */
	res = mydb_query("select v.vname,v.vnode,v.ip,v.vport,v2p.node_id,"
			 "v.protocol,i.IP "
			 "    from virt_lans as v "
			 "left join v2pmap as v2p on "
			 "     v.vnode=v2p.vname and v.pid=v2p.pid and "
			 "     v.eid=v2p.eid "
			 "left join nodes as n on "
			 "     v2p.node_id=n.node_id "
			 "left join interfaces as i on "
			 "     n.phys_nodeid=i.node_id and i.role='ctrl' "
			 "where v.pid='%s' and v.eid='%s' and "
			 "      v2p.node_id is not null "
			 "      order by v.vnode,v.vname",
			 7, reqp->pid, reqp->eid);

	if (!res) {
		error("HOSTNAMES: %s: DB Error getting virt_lans!\n",
		      reqp->nodeid);
		return 1;
	}
	if (! (nrows = mysql_num_rows(res))) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Parse the list, creating an entry for each node/IP pair.
	 */
	while (nrows--) {
		row = mysql_fetch_row(res);
		if (!row[0] || !row[0][0] ||
		    !row[1] || !row[1][0])
			continue;

		if (!thisvnode || strcmp(thisvnode, row[1])) {
			if (! (shareditem = (struct shareditem *)
			       calloc(1, sizeof(*shareditem)))) {
				error("HOSTNAMES: "
				      "Out of memory for shareditem!\n");
				exit(1);
			}
			thisvnode = row[1];
		}

		/*
		 * Check to see if this is the node we're talking to
		 */
		if (!strcmp(row[1], reqp->nickname)) {
		    shareditem->is_me = 1;
		}

		/*
		 * Alloc the per-link struct and fill in.
		 */
		if (! (host = (struct hostentry *) calloc(1, sizeof(*host)))) {
			error("HOSTNAMES: Out of memory!\n");
			exit(1);
		}

		strcpy(host->vlan, row[0]);
		strcpy(host->vname, row[1]);
		strcpy(host->nodeid, row[4]);
		host->virtiface = atoi(row[3]);
		host->shared = shareditem;

		/*
		 * As mentioned above, links with protocol 'ipv4'
		 * use the control net addresses of connected nodes.
		 */
		if (row[5] && strcmp("ipv4", row[5]) == 0 && row[6])
			inet_aton(row[6], &host->ipaddr);
		else
			inet_aton(row[2], &host->ipaddr);

		host->next = hosts;
		hosts = host;
	}
	mysql_free_result(res);

	/*
	 * The last part of the puzzle is to determine who is directly
	 * connected to this node so that we can add an alias for the
	 * first link to each connected node (could be more than one link
	 * to another node). Since we have the vlan names for all the nodes,
	 * its a simple matter of looking in the table for all of the nodes
	 * that are in the same vlan as the node that we are making the
	 * host table for.
	 */
	host = hosts;
	while (host) {
		/*
		 * Only care about this nodes vlans.
		 */
		if (strcmp(host->nodeid, reqp->nodeid) == 0) {
			struct hostentry *tmphost = hosts;

			while (tmphost) {
				if (strlen(tmphost->vlan) &&
				    strcmp(host->vlan, tmphost->vlan) == 0 &&
				    strcmp(host->nodeid, tmphost->nodeid) &&
				    (!tmphost->shared->firstvlan ||
				     !strcmp(tmphost->vlan,
					     tmphost->shared->firstvlan))) {

					/*
					 * Use as flag to ensure only first
					 * link flagged as connected (gets
					 * an alias), but since a vlan could
					 * be a real lan with more than one
					 * other member, must tag all the
					 * members.
					 */
					tmphost->shared->firstvlan =
						tmphost->vlan;
				}
				tmphost = tmphost->next;
			}
		}
		host = host->next;
	}
#if 0
	host = hosts;
	while (host) {
		printf("%s %s %s %d %s %d\n", host->vname, host->nodeid,
		       host->vlan, host->virtiface, inet_ntoa(host->ipaddr),
		       host->connected);
		host = host->next;
	}
#endif

	/*
	 * Okay, spit the entries out!
	 */
	hostcount = 0;
	host = hosts;
	while (host) {
		char	*alias = " ";

		if ((host->shared->firstvlan &&
		     !strcmp(host->shared->firstvlan, host->vlan)) ||
		    /* Directly connected, first interface on this node gets an
		       alias */
		    (!strcmp(host->nodeid, reqp->nodeid) && !host->virtiface)){
			alias = host->vname;
		} else if (!host->shared->firstvlan &&
			   !host->shared->hasalias &&
			   !host->shared->is_me) {
		    /* Not directly connected, but we'll give it an alias
		       anyway */
		    alias = host->vname;
		    host->shared->hasalias = 1;
		}

		/* Old format */
		if (vers == 2) {
			OUTPUT(buf, sizeof(buf),
			       "NAME=%s LINK=%i IP=%s ALIAS=%s\n",
			       host->vname, host->virtiface,
			       inet_ntoa(host->ipaddr), alias);
		}
		else {
			OUTPUT(buf, sizeof(buf),
			       "NAME=%s-%s IP=%s ALIASES='%s-%i %s'\n",
			       host->vname, host->vlan,
			       inet_ntoa(host->ipaddr),
			       host->vname, host->virtiface, alias);
		}
		client_writeback(sock, buf, strlen(buf), tcp);
		host = host->next;
		hostcount++;
	}

	/*
	 * For plab slices, lets include boss and ops IPs as well
	 * in case of flaky name service on the nodes.
	 *
	 * XXX we only do this if we were going to return something
	 * otherwise.  In the event there are no other hosts, we would
	 * not overwrite the existing hosts file which already has boss/ops.
	 */
	if (reqp->isplabdslice && hostcount > 0) {
		OUTPUT(buf, sizeof(buf),
		       "NAME=%s IP=%s ALIASES=''\nNAME=%s IP=%s ALIASES=''\n",
		       BOSSNODE, EXTERNAL_BOSSNODE_IP,
		       USERNODE, EXTERNAL_USERNODE_IP);
		client_writeback(sock, buf, strlen(buf), tcp);
		hostcount += 2;
	}

	info("HOSTNAMES: %d hosts in list\n", hostcount);
	host = hosts;
	while (host) {
		struct hostentry *tmphost = host->next;
		free(host);
		host = tmphost;
	}
	return rv;
}

/*
 * Return RPM stuff.
 */
COMMAND_PROTOTYPE(dorpms)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE], *bp, *sp;
	char		*srv = TARRPM_SERVER;
	int		useweb = 0;
#ifdef NOVIRTNFSMOUNTS
	useweb = 1;
#endif
	if ((strcmp(reqp->nfsmounts, "none") == 0) ||
	    (reqp->sharing_mode[0] && reqp->isvnode)) {
		useweb = 1;
	}

	/* 
	 * Short-circuit rpm installation for nodes tainted with 'blackbox'
	 * or 'useronly'.  Users could use these to overwrite anything on
	 * the local node or invoke arbitrary code as root.
	 */
	if (HAS_ANY_TAINTS(reqp->taintstates, 
			   (TB_TAINTSTATE_BLACKBOX | TB_TAINTSTATE_USERONLY)))
		return 0;
	
	/*
	 * Get RPM list for the node.
	 */
	res = mydb_query("select rpms from nodes where node_id='%s' ",
			 1, reqp->nodeid);

	if (!res) {
		error("RPMS: %s: DB Error getting RPMS!\n", reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Text string is a colon separated list.
	 */
	row = mysql_fetch_row(res);
	if (! row[0] || !row[0][0]) {
		mysql_free_result(res);
		return 0;
	}

	bp  = row[0];
	sp  = bp;
	do {
		char *bufp = buf, *ebufp = &buf[sizeof(buf)];
		bp = strsep(&sp, ":");

		if (vers < 36) {
			OUTPUT(buf, sizeof(buf), "RPM=%s\n", bp);
		}
		else {
			bufp += OUTPUT(bufp, ebufp - bufp, "SERVER=%s ", srv);
			if (vers >= 37) {
				bufp += OUTPUT(bufp, ebufp - bufp, "USEWEB=%d ",
					useweb);
			}
			OUTPUT(bufp, ebufp - bufp, "RPM=%s\n", bp);
		}
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("RPM: %s", buf);

	} while ((bp = sp));

	mysql_free_result(res);
	return 0;
}

/*
 * Return Tarball stuff.
 */
COMMAND_PROTOTYPE(dotarballs)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE], *bp, *sp, *tp;
	char		*srv = TARRPM_SERVER;
	int		useweb = 0;
#ifdef NOVIRTNFSMOUNTS
	useweb = 1;
#endif
	if ((strcmp(reqp->nfsmounts, "none") == 0) ||
	    (reqp->sharing_mode[0] && reqp->isvnode)) {
		useweb = 1;
	}

	/* 
	 * Short-circuit tarballs for nodes tainted with 'blackbox'.
	 */
	if (HAS_ANY_TAINTS(reqp->taintstates, TB_TAINTSTATE_BLACKBOX))
		return 0;
	
	/*
	 * Get Tarball list for the node.
	 */
	res = mydb_query("select tarballs from nodes where node_id='%s' ",
			 1, reqp->nodeid);

	if (!res) {
		error("TARBALLS: %s: DB Error getting tarballs!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Text string is a colon separated list of "dir filename".
	 */
	row = mysql_fetch_row(res);
	if (! row[0] || !row[0][0]) {
		mysql_free_result(res);
		return 0;
	}

	bp  = row[0];
	sp  = bp;
	do {
		char *bufp = buf, *ebufp = &buf[sizeof(buf)];
		
		bp = strsep(&sp, ":");
		if ((tp = strchr(bp, ' ')) == NULL)
			continue;
		*tp++ = '\0';

		if (vers < 36) {
			OUTPUT(buf, sizeof(buf),
			       "DIR=%s TARBALL=%s\n", bp, tp);
		} else {
			bufp += OUTPUT(bufp, ebufp - bufp, "SERVER=%s ", srv);
			if (vers >= 37) {
				bufp += OUTPUT(bufp,
					       ebufp - bufp, "USEWEB=%d ",
					       useweb);
			}
			OUTPUT(bufp, ebufp - bufp,
			       "DIR=%s TARBALL=%s\n", bp, tp);
		}
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("TARBALLS: %s", buf);

	} while ((bp = sp));

	mysql_free_result(res);
	return 0;
}

/* 
 *
 */
COMMAND_PROTOTYPE(doblobs)
{
	MYSQL_RES       *res;
	MYSQL_ROW       row;
	int             nrows;
	char            buf[MYBUFSIZE];
	char            *bufp = buf, *ebufp = &buf[sizeof(buf)];

	/* 
	 * Short-circuit blobs for nodes tainted with 'blackbox' or
	 * 'useronly'. XXX: rc.blobs on the clientside needs an overhaul
	 * before this blanket ban can be lifted for 'useronly'.
	 */
	if (HAS_ANY_TAINTS(reqp->taintstates, 
			   (TB_TAINTSTATE_BLACKBOX | TB_TAINTSTATE_USERONLY)))
		return 0;
	
	res = mydb_query("select path,action from experiment_blobs "
			 " where exptidx=%d order by idx",
			 2, reqp->exptidx);
	
	if (!res) {
		error("BLOBS: %s: DB Error getting blobs for %s/%s!\n",
		      reqp->nodeid, reqp->pid, reqp->eid);
		return 1;
	}
	
	nrows = (int)mysql_num_rows(res);
	if (nrows <= 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Frisbee blobs did exist prior to version 33, but the infrastructure
	 * was not deployed on more than a couple of images and only at Utah.
	 * So we are not going to bother with frisbee backward compat changes
	 * and just require that all images have the new frisbee master server
	 * infrastructure.
	 */
	if (vers < 33) {
		error("BLOBS: %s: requires new frisbee, rebuild image!\n",
		      reqp->nodeid);
		mysql_free_result(res);
		return 1;
	}

	while (nrows > 0) {
		row = mysql_fetch_row(res);
		if (row[0] == NULL || row[0][0] == '\0' ||
		    row[1] == NULL || row[1][0] == '\0') {
			error("BLOBS: %s: bogus path/action for %s/%s in DB\n",
			      reqp->nodeid, reqp->pid, reqp->eid);
			continue;
		}

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "URL=frisbee://%s ACTION=%s\n",
			       row[0], row[1]);
		nrows--;
	}

	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("doblobs: %s", buf);

	mysql_free_result(res);
	return 0;
}


/*
 * This is deprecated, but left in case old images reference it.
 */
COMMAND_PROTOTYPE(dodeltas)
{
	return 0;
}

/*
 * Return node run command. We return the command to run, plus the UID
 * of the experiment creator to run it as!
 */
COMMAND_PROTOTYPE(dostartcmd)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];

	/* Short-circuit start commands for nodes tainted with 'blackbox'.*/
	if (HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX))
		return 0;

	/*
	 * Get run command for the node.
	 */
	res = mydb_query("select startupcmd from nodes where node_id='%s'",
			 1, reqp->nodeid);

	if (!res) {
		error("STARTUPCMD: %s: DB Error getting startup command!\n",
		       reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Simple text string.
	 */
	row = mysql_fetch_row(res);
	if (! row[0] || !row[0][0]) {
		mysql_free_result(res);
		return 0;
	}
	OUTPUT(buf, sizeof(buf), "CMD='%s' UID=%s\n", row[0], reqp->swapper);
	mysql_free_result(res);
	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("STARTUPCMD: %s", buf);

	return 0;
}

/*
 * Accept notification of start command exit status.
 */
COMMAND_PROTOTYPE(dostartstat)
{
	int		exitstatus;

	/*
	 * Dig out the exit status
	 */
	if (! sscanf(rdata, "%d", &exitstatus)) {
		error("STARTSTAT: %s: Invalid status: %s\n",
		      reqp->nodeid, rdata);
		return 1;
	}

	if (verbose)
		info("STARTSTAT: "
		     "%s is reporting startup command exit status: %d\n",
		     reqp->nodeid, exitstatus);

	/*
	 * Update the node table record with the exit status. Setting the
	 * field to a non-null string value is enough to tell whoever is
	 * watching it that the node is done.
	 */
	if (mydb_update("update nodes set startstatus='%d' "
			"where node_id='%s'", exitstatus, reqp->nodeid)) {
		error("STARTSTAT: %s: DB Error setting exit status!\n",
		      reqp->nodeid);
		return 1;
	}
#ifdef EVENTSYS
	address_tuple_t tuple;
	char buf[BUFSIZ];

	/*
	 * Send an event with the command status.
	 */
	/* XXX: Maybe we don't need to alloc a new tuple every time through */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		error("dostate: Unable to allocate address tuple!\n");
	}
	else {
		tuple->host      = BOSSNODE;
		tuple->objtype   = "TBSTARTSTATUS";
		tuple->objname	 = reqp->nodeid;
		sprintf(buf, "%d", exitstatus);
		tuple->eventtype = buf;

		if (myevent_send(tuple)) {
			error("Error sending event\n");
			info("%s: STARTSTAT: %d failed!\n",
			     reqp->nodeid, exitstatus);
		}
		address_tuple_free(tuple);
	}
#endif /* EVENTSYS */
	return 0;
}

/*
 * Accept notification of ready for action
 */
COMMAND_PROTOTYPE(doready)
{
	/*
	 * Vnodes not allowed!
	 */
	if (reqp->isvnode)
		return 0;

	/*
	 * Update the ready_bits table.
	 */
	if (mydb_update("update nodes set ready=1 "
			"where node_id='%s'", reqp->nodeid)) {
		error("%s: READY: DB Error setting ready bit!\n",
		      reqp->nodeid);
		return 1;
	}

	if (verbose)
		info("%s: READY: Node is reporting ready\n", reqp->nodeid);

	/*
	 * Nothing is written back
	 */
	return 0;
}

/*
 * Return ready bits count (NofM)
 */
COMMAND_PROTOTYPE(doreadycount)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		total, ready, i;

	/*
	 * Vnodes not allowed!
	 */
	if (reqp->isvnode)
		return 0;

	/*
	 * See how many are ready. This is a non sync protocol. Clients
	 * keep asking until N and M are equal. Can only be used once
	 * of course, after experiment creation.
	 */
	res = mydb_query("select ready from reserved "
			 "left join nodes on nodes.node_id=reserved.node_id "
			 "where reserved.eid='%s' and reserved.pid='%s'",
			 1, reqp->eid, reqp->pid);

	if (!res) {
		error("READYCOUNT: %s: DB Error getting ready bits.\n",
		      reqp->nodeid);
		return 1;
	}

	ready = 0;
	total = (int) mysql_num_rows(res);
	if (total) {
		for (i = 0; i < total; i++) {
			row = mysql_fetch_row(res);

			if (atoi(row[0]))
				ready++;
		}
	}
	mysql_free_result(res);

	OUTPUT(buf, sizeof(buf), "READY=%d TOTAL=%d\n", ready, total);
	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("READYCOUNT: %s: %s", reqp->nodeid, buf);

	return 0;
}

/*
 * Return information on storage composition.  This ultimately looks like
 * a series of commands that results in a layering of: remote disk
 * mounts, local disk checks, aggregate creation (volume managment),
 * slicing operations, and finally exports.
 *
 */
COMMAND_PROTOTYPE(dostorageconfig)
{
        MYSQL_RES	*res, *res2;
	MYSQL_ROW	row, row2;
	char		buf[MYBUFSIZE];
	char		*bufp, *ebufp = &buf[sizeof(buf)];
	char            *mynodeid;
	char            *vname, *bsid, *hostid, *localproto;
	int             rv;
	int             volsize, bsidx, cmdidx = 1;
	int		nrows, nrows2, nattrs;

	/* Request for a blockstore VM? If so, return blockstore slice info */
	if (reqp->isvnode &&
	    (strcmp(reqp->type, BS_VNODE_TYPE) == 0)) {
		/* Do Stuff:
		   0) A vlan interface setup is handled elsewhere (ifconfig).
		   1) Grab reservation info, log error if it does not exist and
		      return nothing.
		   - What local blockstore to slice (bs_id)
		   - Size (in mebibytes)
		   - Permissions (node and/or lan)
		   - Other attributes ... ?
		   2) Construct volume name
		   - "pid:eid:vname"
		*/
		res = mydb_query("select bsidx,bs_id,vname,size "
				 "from reserved_blockstores "
				 "where exptidx=%d and "
				 "vnode_id='%s'",
				 4, reqp->exptidx, reqp->vnodeid);

		if (!res) {
			error("STORAGECONFIG: %s: DB Error getting reserved "
			      "info.\n",
			      reqp->vnodeid);
			return 1;
		}

		nrows = (int) mysql_num_rows(res);
		if (nrows != 1) {
			/* Should only be one reserved row per blockstore vm. */
			error("STORAGECONFIG: %s: Wrong number of reserved "
			      "entries for blockstore vm: %d.\n",
			      reqp->vnodeid, nrows);
			mysql_free_result(res);
			return 0;
		}

		row = mysql_fetch_row(res);
		bsidx = atoi(row[0]);
		bsid = row[1];
		vname = row[2];
		volsize = atoi(row[3]);

		OUTPUT(buf, sizeof(buf), 
		       "CMD=SLICE IDX=%d BSID=%s VOLNAME=%s VOLSIZE=%d\n",
		       cmdidx++, bsid, vname, volsize);
		client_writeback(sock, buf, strlen(buf), tcp);

		OUTPUT(buf, sizeof(buf), 
		       "CMD=EXPORT IDX=%d VOLNAME=%s",
		       cmdidx++, vname);
		rv = sendstoreconf(sock, tcp, reqp, buf, vname, 0, NULL);

		mysql_free_result(res);
		return rv;
	}

	/* 
	 * If we are here, then this is a regular node.  Send over its
	 * list of storage-related commands so that it can build things
         * up.
	 *
	 * - List of local storage elements to verify.
	 * - List of remote storage elements to link up to.
	 * - List of static slices to setup
	 * - ... XXX: Other stuff later (e.g., aggregates).
	 */
	
	/* Remember the nodeid we care about up front. */
	mynodeid = reqp->isvnode ? reqp->vnodeid : reqp->nodeid;

	/* return blockstores entries (XXX: for now, just the elements) */
	res = mydb_query("select bsidx,bs_id,total_size "
			  "from blockstores "
			  "where node_id='%s' and role='element'", 
			  3, mynodeid);

	if (!res) {
		error("STORAGECONFIG: %s: DB Error getting blockstores.\n",
		      mynodeid);
		return 1;
	}

	/* Find out what type of blockstore we are dealing with and
	   grab some additional attributes. */
	nrows = (int) mysql_num_rows(res);
	while (nrows--) {
		char *class, *protocol, *serial;

		row = mysql_fetch_row(res);
		bsidx = atoi(row[0]);
		bsid = row[1];
		volsize = atoi(row[2]);

		/* Nifty sql union query that lets a blockstore's specific 
		   attributes override those inherited from its type. */
		res2 = mydb_query("(select attrkey,attrvalue "
				  " from blockstores as b "
				  " left join blockstore_type_attributes as a on "
				  "      b.type=a.type "
				  " where b.bsidx=%d) "
				  "union "
				  "(select attrkey,attrvalue "
				  "   from blockstore_attributes "
				  " where bsidx=%d) ",
				  2, bsidx, bsidx);

		nrows2 = nattrs = (int) mysql_num_rows(res2);
		class = protocol = serial = "\0";
		while (nrows2--) {
			char *key, *val;
			row2 = mysql_fetch_row(res2);
			key = row2[0];
			val = row2[1];
			if (strcmp(key,"class") == 0) {
				class = val;
			} else if (strcmp(key,"protocol") == 0) {
				protocol = val;
			} else if (strcmp(key, "serialnum") == 0) {
				serial = val;
			}
		}

		if (!(class && *class && 
		      protocol && *protocol && 
		      serial && *serial)) {
			error("STORAGECONFIG: %s: Missing attributes!", 
			      mynodeid);
			mysql_free_result(res);
			mysql_free_result(res2);
			return 0;
		}
		
		/* Now that we have the current blockstore's info, spit it out
		   for the client to consume. */
		OUTPUT(buf, sizeof(buf), 
		       "CMD=ELEMENT IDX=%d CLASS=%s PROTO=%s "
		       "HOSTID=localhost VOLNAME=%s UUID=%s UUID_TYPE=serial "
		       "VOLSIZE=%d\n",
		       cmdidx++, class, protocol, bsid, serial, volsize);

		client_writeback(sock, buf, strlen(buf), tcp);
		mysql_free_result(res2);
	}
	mysql_free_result(res);

	/*
	 * XXX short term hack
	 *
	 * Currently, we are not using the PROTO field for local
	 * blockstores. So we use it to convey to the user whether
	 * NONSYSVOL and ANY storage pools should be composed of
	 * HDD-only, SSD-only, or all storage types. We query the
	 * sitevar "storage/local/disktypes" for this info.
	 *
	 * So right now we decide in advance what types of storage
	 * the pools should include, set the sitevar, and also
	 * set the values of the existing DB nonsysvol/any features
	 * to include only that storage.
	 *
	 * Ultimately, we could get rid of the sitevar and use the
	 * PROTO field to select, per-blockstore, its type. But that
	 * will require additional per node (type) assign features
	 * differentiating the amount of each type available.
	 *
	 * Ultimately is not here yet, but I need a penultimate fix to
	 * handle the Powder d840 nodes. Right now, an ANY or NONSYSVOL
	 * blockstore will wind up with a combination of the single small,
	 * ugly-slow BOSS device RAID1 VD and the multiple large, stupid-fast
	 * NVMe devices. So I have added the node/node_type feature so I can
	 * restrict blockstores on these nodes to use just flash devices and
	 * adjusted the existing nonsysvol/any assign features so that the
	 * max size includes only that space. Right now, the node/type
	 * features override the sitevar. Not sure if that is a good thing...
	 */
	localproto = NULL;
	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='storage/local/disktypes'", 2);
	if (res) {
		if ((int)mysql_num_rows(res) > 0) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0])
				localproto = strdup(row[0]);
			else if (row[1] && row[1][0])
				localproto = strdup(row[1]);
		}
		mysql_free_result(res);
	}

	/*
	 * See if there are node or node_type overrides for the localproto.
	 */
	res = mydb_query("select na.attrvalue,nta.attrvalue from nodes as n "
			 "left join node_type_attributes as nta on "
			 "     nta.type=n.type and "
			 "     nta.attrkey='blockstore_localproto' "
			 "left join node_attributes as na on "
			 "     na.node_id=n.node_id and "
			 "     na.attrkey='blockstore_localproto' "
			 "where n.node_id='%s'",
			 2, reqp->pnodeid);
	if (res) {
		if ((int)mysql_num_rows(res) != 0) {
			char *attrvalue = NULL;
			
			row = mysql_fetch_row(res);

			if (row[0] && row[0][0])
				attrvalue = row[0];
			else if (row[1] && row[1][0]) {
				attrvalue = row[1];
			}
			if (attrvalue) {
				if (localproto)
					free(localproto);
				localproto = strdup(attrvalue);
			}
		}
		mysql_free_result(res);
	}
	
	/* 
	 * Send across local blockstore volumes (slices).  These don't
	 * show up in the reserved table, existing entirely in the
	 * virt_blockstore* tables since local disk space is dedicated
	 * to the current experiment.
	 */
	res = mydb_query("select vname,size "
			 "from virt_blockstores "
			 "where exptidx=%d and "
			 "fixed='%s'",
			 2, reqp->exptidx, reqp->nickname);
	if (!res) {
		error("STORAGECONFIG: %s: DB Error getting virt_blockstore "
		      "info.\n",
		      mynodeid);
		if (localproto)
			free(localproto);
		return 1;
	}

	nrows = (int) mysql_num_rows(res);
	while (nrows--) {
		row = mysql_fetch_row(res);
		vname = row[0];
		volsize = atoi(row[1]);
		OUTPUT(buf, sizeof(buf), 
		       "CMD=SLICE IDX=%d VOLNAME=%s VOLSIZE=%d", 
		       cmdidx++, vname, volsize);
		sendstoreconf(sock, tcp, reqp, buf, vname, 0, localproto);
	}
	mysql_free_result(res);
	if (localproto)
		free(localproto);
	
	/* 
	 * Now to send the remote elements (a.k.a SAN disks). Figuring
	 * out which ones we need to tell the client about is a little
	 * bit tricky.  It requires iterating over the lans that the
	 * node is a member of, looking for blockstores, and then
	 * sending back any found.
	 */

	/* First, get the lans that the node is a member of. */
	res = mydb_query("select vname "
			 "from virt_lans as vl "
			 "where pid='%s' and eid='%s' and vnode='%s'", 
			 1, reqp->pid, reqp->eid, reqp->nickname);

	if (!res) {
		error("STORAGECONFIG: %s: DB Error getting lan listing.\n",
		      mynodeid);
		return 1;
	}

	/* Now within the lans this node is a member of, find any blockstore
	   pseudo-VMs. (Yes, this could probably be done with a subquery.
	   Maybe later...) */
	nrows = (int) mysql_num_rows(res);
	if (nrows == 0) {
	  /* No lans connected to this node, so nothing else to do. */
	  mysql_free_result(res);
	  return 0;
	}
	bufp = buf;
	while (nrows--) {
		row = mysql_fetch_row(res);
		bufp += OUTPUT(bufp, ebufp-bufp,
			       nrows ? "'%s'," : "'%s'", 
			       row[0]);
	}
	mysql_free_result(res);

	res = mydb_query("select rb.bsidx, r.vname, rb.vname, rb.size, vl.ip, "
			 " vl.mask "
			 "from reserved_blockstores as rb "
			 " left join reserved as r "
			 "  on r.node_id = rb.vnode_id and "
			 "     r.exptidx = rb.exptidx "
			 " left join virt_lans as vl "
			 "  on r.vname = vl.vnode and "
			 "     r.exptidx = vl.exptidx "
			 "where vl.vname in (%s) "
			 " and vl.pid='%s' and vl.eid='%s'",
			 6, buf, reqp->pid, reqp->eid);

	if (!res) {
		error("STORAGECONFIG: %s: DB Error getting connected "
		      "blockstore info.\n",
		      mynodeid);
		return 1;
	}

	/* For each blockstore, spit out info for the client. */
	nrows = (int) mysql_num_rows(res);
	while (nrows--) {
		row = mysql_fetch_row(res);
		bsidx = atoi(row[0]);
		hostid = row[1];
		vname = row[2];
		volsize = atoi(row[3]);
	       
		OUTPUT(buf, sizeof(buf), 
		       "CMD=ELEMENT IDX=%d HOSTID=%s VOLNAME=%s VOLSIZE=%d"
		       " HOSTIP=%s HOSTMASK=%s",
		       cmdidx++, hostid, vname, volsize, row[4], row[5]);
		sendstoreconf(sock, tcp, reqp, buf, vname, 1, NULL);
	}
	mysql_free_result(res);
	
	/* All done. */
	return 0;
}

/* Helper function for "dostorageconfig" */
static int 
sendstoreconf(int sock, int tcp, tmcdreq_t *reqp, char *bscmd, char *vname,
	      int dopersist, char *localproto)
{
        MYSQL_RES	*res, *res2;
	MYSQL_ROW	row, row2;
	char		buf[MYBUFSIZE];
	char            *bufp, *ebufp = &buf[sizeof(buf)];
	char            iqn[BS_IQN_MAXSIZE];
	char            *mynodeid;
	char            *class, *protocol, *placement, *mountpoint, *lease;
	char		*dataset, *server;
	int		nrows, nattrs, ro, clone;

	/* Remember the nodeid we care about up front. */
	mynodeid = reqp->isvnode ? reqp->vnodeid : reqp->nodeid;

	/* Get the virt attributes for the blockstore. */
	res = mydb_query("select attrkey,attrvalue "
			 "from virt_blockstore_attributes "
			 "where exptidx=%d and vname='%s'", 
			 2, reqp->exptidx, vname);

	if (!res) {
		error("STORAGECONFIG: %s: DB Error getting vattrs.\n",
		      mynodeid);
		return 1;
	}

	/* Find out what type of blockstore we are dealing with and
	   grab some additional attributes. */
	nrows = nattrs = (int) mysql_num_rows(res);
	class = protocol = placement = mountpoint = lease = dataset = "\0";
	ro = clone = 0;
	while (nrows--) {
		char *key, *val;
		row = mysql_fetch_row(res);
		key = row[0];
		val = row[1];
		if (strcmp(key,"class") == 0) {
			class = val;
		} else if (strcmp(key,"protocol") == 0) {
			protocol = val;
		} else if (strcmp(key,"placement") == 0) {
			placement = val;
		} else if (strcmp(key,"mountpoint") == 0) {
			mountpoint = val;
		} else if (strcmp(key,"lease") == 0) {
			lease = val;
		} else if (strcmp(key,"readonly") == 0) {
			ro = (strcmp(val, "0") == 0) ? 0 : 1;
		} else if (strcmp(key,"dataset") == 0) {
			dataset = val;
		} else if (strcmp(key,"rwclone") == 0) {
			clone = (strcmp(val, "0") == 0) ? 0 : 1;
		}
	}

	/*
	 * For datasets, we need to tell the client what server to use.
	 */
	if (dataset) {
		res2 = mydb_query("select IP "
				  " from interfaces as i, subbosses as s "
				  " where i.node_id=s.subboss_id and "
				  " i.role='ctrl' and "
				  " s.node_id='%s' and s.service='frisbee'"
				  " and s.disabled=0",
				  1, reqp->isvnode ?
				  reqp->pnodeid : reqp->nodeid);
		if (!res2) {
			error("sendstoreconf: "
			      "%s: DB Error getting subboss info!\n",
			      reqp->nodeid);
			mysql_free_result(res);
			return 1;
		}
		if (mysql_num_rows(res2)) {
			row2 = mysql_fetch_row(res2);
			server = strdup(row2[0]);
		} else {
			server = strdup(BOSSNODE_IP);
		}
		mysql_free_result(res2);
	}

	/* iSCSI blockstore */
	if ((strcmp(class, BS_CLASS_SAN) == 0) &&
	    (strcmp(protocol, BS_PROTO_ISCSI) == 0)) {
		/*
		 * Construct IQN string.
		 * Currently, all leases have a unique IQN based on
		 * experiment-specific data.
		 */
		if (snprintf(iqn, sizeof(iqn), "%s:%s:%s:%s",
			     BS_IQN_PREFIX, reqp->pid,
			     reqp->eid, vname) >= sizeof(iqn)) {
			error("STORAGECONFIG: %s: Not enough room in "
			      "IQN string buffer", mynodeid);
			mysql_free_result(res);
			return 1;
		}

		/*
		 * XXX FreeNAS does not like '_' in its IQNs,
		 * so change them to '-'.
		 */
		if (strchr(iqn, '_') != NULL) {
			char *cp = iqn;
			while ((cp = strchr(cp, '_')) != NULL)
				*cp++ = '-';
		}

		bufp = buf;
		bufp += OUTPUT(bufp, ebufp-bufp,
			       "%s CLASS=%s PROTO=%s UUID=%s UUID_TYPE=iqn",
			       bscmd, class, protocol, iqn);
		/* XXX only return CLONE type to blockstore vnodes */
		if (clone && strcmp(reqp->type, BS_VNODE_TYPE) != 0)
			clone = 0;
		bufp += OUTPUT(bufp, ebufp-bufp, " PERMS=%s",
			       ro ? "RO" : (clone ? "CLONE" : "RW"));

		if (strlen(mountpoint)) {
			bufp += OUTPUT(bufp, ebufp-bufp, " MOUNTPOINT=%s",
				       mountpoint);
		}

		/*
		 * XXX we only put out the PERSIST flag if it is set.
		 * Since the client-side is stupid-picky about unknown
		 * attributes, this will cause an older client to fail
		 * when the attribute is passed. Believe it or not,
		 * that is a good thing! This will cause an older
		 * client to fail if presented with a persistent
		 * blockstore. If it did not fail, the client would
		 * proceed to unconditionally create a filesystem on
		 * the blockstore, wiping out what was previously
		 * there.
		 */
		if (dopersist && strlen(lease) && atoi(lease) != 0) {
			bufp += OUTPUT(bufp, ebufp-bufp, " PERSIST=1");
		}

		bufp += OUTPUT(bufp, ebufp-bufp, "\n");
		client_writeback(sock, buf, strlen(buf), tcp);
	}

	/* local disk. */
	else if (strcmp(class, BS_CLASS_LOCAL) == 0) {
		/* Set default placement if not defined. */
		placement = strlen(placement) ? placement : BS_PLACEMENT_DEF;

		bufp = buf;
		bufp += OUTPUT(bufp, ebufp-bufp,
			       "%s CLASS=%s BSID=%s",
			       bscmd, class, placement);

		/*
		 * If there is a global local storage type, we pass that
		 * along (see the "short term hack" comment above in
		 * dostorageconfig).
		 *
		 * XXX Since the clientside has a fixed set of values it will
		 * accept for PROTO, we map these as:
		 *
		 * Any       => PROTO="local"
		 * SSD-only  => PROTO="NVMe"
		 * HDD-only  => PROTO=<any other> (e.g., "SATA", "PATA")
		 */
		if (strlen(protocol) == 0 && localproto != NULL) {
			if (strcasecmp(localproto, "any") == 0) {
				protocol = "local";
			} else if (strcasecmp(localproto, "ssd-only") == 0) {
				protocol = "NVMe";
			} else if (strcasecmp(localproto, "hdd-only") == 0) {
				protocol = "SATA";
			}
		}

		/* Add the protocol to the buffer, if present.*/
		if (strlen(protocol)) {
			bufp += OUTPUT(bufp, ebufp-bufp, " PROTO=%s",
				       protocol);
		}

		/* Add the mountpoint to the buffer, if requested.*/
		if (strlen(mountpoint)) {
			bufp += OUTPUT(bufp, ebufp-bufp, " MOUNTPOINT=%s",
				       mountpoint);
		}

		/* Add the dataset to the buffer, if requested.*/
		if (strlen(dataset)) {
			bufp += OUTPUT(bufp, ebufp-bufp,
				       " DATASET=%s SERVER=%s",
				       dataset, server);
			free(server);
		}

		bufp += OUTPUT(bufp, ebufp-bufp, "\n");
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return mount stuff.
 */
COMMAND_PROTOTYPE(domounts)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp, *ebufp = &buf[sizeof(buf)];
	int		nrows, usesfs;
	int		nomounts = 0;
	char		*fsnode = FSNODE;
#ifdef  ISOLATEADMINS
	int		isadmin;
#endif
	if (strcmp(reqp->nfsmounts, "none") == 0) {
		nomounts = 1;
	}
	/*
	 * Do we export filesystems at all?
	 */
#ifdef	NOSHAREDFS
	nomounts = 1;
#endif

	/*
	 * Older clients will not properly handle the new format mount
	 * lines, so just return nothing and hope for the best.
	 */
	if (vers < 32 && nomounts)
		return 0;

	/*
	 * Should SFS mounts be served?
	 */
	usesfs = 0;
	if (vers >= 6 && strlen(fshostid) && !nomounts) {
		if (strlen(reqp->sfshostid))
			usesfs = 1;
		else {
			while (*rdata && isspace(*rdata))
				rdata++;

			if (!strncmp(rdata, "USESFS=1", strlen("USESFS=1")))
				usesfs = 1;
		}

		if (verbose) {
			if (usesfs) {
				info("Using SFS\n");
			}
			else {
				info("Not using SFS\n");
			}
		}
	}

	/*
	 * Remote nodes must use SFS.
	 */
	if (!reqp->islocal && !usesfs)
		return 0;

	/*
	 * Return info about the file server
	 */
	if (vers >= 32) {
		char *fstype = "";
		char *transport = NULL;

		/* XXX sanity for code below */
		if (reqp->sharing_mode[0] && !reqp->isvnode)
			usesfs = 0;

		if (nomounts) {
			fstype = "LOCAL";
		} else if (usesfs) {
			fstype = "SFS";
		} else {
			/*
			 * See what transport we should use.
			 *
			 * N.B. we did not need a version bump here because
			 * older clients only match on /^FSTYPE=/ and so are
			 * not affected by putting more stuff at the end of
			 * the line.
			 */
			res = mydb_query("select value,defaultvalue "
					 "from sitevariables "
					 "where name='node/nfs_transport'", 2);
			if (res && (nrows = (int)mysql_num_rows(res)) > 0) {
				char *value = NULL;

				row = mysql_fetch_row(res);
				if (row[0] && row[0][0])
					value = row[0];
				else if (row[1] && row[1][0])
					value = row[1];
				if (value) {
					if (!strcasecmp(value, "tcp"))
						transport = "TCP";
					else if (!strcasecmp(value, "udp"))
						transport = "UDP";
					else if (!strcasecmp(value, "osdefault"))
						transport = "osdefault";
				}
			}
			if (res)
				mysql_free_result(res);
#ifdef NFSRACY
			fstype = "NFS-RACY";
#else
			fstype = "NFS";
#endif
		}

		if (transport) {
			OUTPUT(buf, sizeof(buf), "FSTYPE=%s TRANSPORT=%s\n",
			       fstype, transport);
		} else {
			OUTPUT(buf, sizeof(buf), "FSTYPE=%s\n", fstype);
		}
		client_writeback(sock, buf, strlen(buf), tcp);
	}
#ifdef NOVIRTNFSMOUNTS
	if (reqp->sharing_mode[0] && reqp->isvnode &&
	    !reqp->isroutable_vnode) {
		return 0;
	}
#endif

	/*
	 * A local phys node acting as a shared host gets toplevel mounts only.
	 */
	if (reqp->sharing_mode[0] && !reqp->isvnode && !WITHZFS) {
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s ", FSUSERDIR);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s\n", USERDIR);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);

#ifdef FSSCRATCHDIR
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s ", FSSCRATCHDIR);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s\n", SCRATCHDIR);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);
#endif
#ifdef FSSHAREDIR
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s ", FSSHAREDIR);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s\n", SHAREDIR);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);
#endif
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s ", FSPROJDIR);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s\n", PROJDIR);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);

		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s ", FSGROUPDIR);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s\n", GROUPDIR);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);
		return 0;
	}
	else if (!usesfs) {
#ifdef  PROTOGENI_GENIRACK
		/*
		 * XXX Fix this ... crazy routing problems on the racks.
		 */
		if (reqp->isvnode && reqp->sharing_mode[0]) {
			/*
			 * See if the node has a public IP.
			 */
			res = mydb_query("select IP from virt_node_public_addr "
					 "where node_id='%s'",
					 1, reqp->vnodeid);
			if (!res) {
				error("MOUNTS: %s: DB Error public IP!\n",
				      reqp->vnodeid);
				return 1;
			}
			if (!mysql_num_rows(res)) {
				fsnode = FSJAILIP;
			}
			mysql_free_result(res);
		}
#endif
		/*
		 * Return project mount first.
		 */
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s:%s/%s ",
				       fsnode, FSDIR_PROJ, reqp->pid);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s/%s\n",
		       PROJDIR, reqp->pid);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);

		/*
		 * If pid!=gid, then this is group experiment, and we return
		 * a mount for the group directory too.
		 */
		if (strcmp(reqp->pid, reqp->gid)) {
			bufp = buf;
			if (!nomounts)
				bufp += OUTPUT(bufp, ebufp-bufp,
					       "REMOTE=%s:%s/%s/%s ",
					       fsnode, FSDIR_GROUPS,
					       reqp->pid, reqp->gid);
			OUTPUT(bufp, ebufp-bufp, "LOCAL=%s/%s/%s\n",
			       GROUPDIR, reqp->pid, reqp->gid);
			client_writeback(sock, buf, strlen(buf), tcp);
			/* Leave this logging on all the time for now. */
			info("MOUNTS: %s", buf);
		}
#ifdef FSSCRATCHDIR
		/*
		 * Return scratch mount if its defined.
		 */
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s:%s/%s ",
				       fsnode, FSDIR_SCRATCH, reqp->pid);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s/%s\n",
		       SCRATCHDIR, reqp->pid);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);
#endif
#ifdef FSSHAREDIR
		/*
		 * Return share mount if its defined.
		 */
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp,
				       "REMOTE=%s:%s ", fsnode, FSDIR_SHARE);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s\n", SHAREDIR);
		client_writeback(sock, buf, strlen(buf), tcp);
		/* Leave this logging on all the time for now. */
		info("MOUNTS: %s", buf);
#endif
	}
	else if (usesfs) {
		/*
		 * Return SFS-based mounts. Locally, we send back per
		 * project/group mounts (really symlinks) cause thats the
		 * local convention. For remote nodes, no point. Just send
		 * back mounts for the top level directories.
		 */
		if (reqp->islocal) {
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s/%s LOCAL=%s/%s\n",
			       fshostid, FSDIR_PROJ, reqp->pid,
			       PROJDIR, reqp->pid);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);

			/*
			 * Return SFS-based group mount.
			 */
			if (strcmp(reqp->pid, reqp->gid)) {
				OUTPUT(buf, sizeof(buf),
				       "SFS REMOTE=%s%s/%s/%s LOCAL=%s/%s/%s\n",
				       fshostid,
				       FSDIR_GROUPS, reqp->pid, reqp->gid,
				       GROUPDIR, reqp->pid, reqp->gid);
				client_writeback(sock, buf, strlen(buf), tcp);
				info("MOUNTS: %s", buf);
			}
#ifdef FSSCRATCHDIR
			/*
			 * Pointer to per-project scratch directory.
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s/%s LOCAL=%s/%s\n",
			       fshostid, FSDIR_SCRATCH, reqp->pid,
			       SCRATCHDIR, reqp->pid);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);
#endif
#ifdef FSSHAREDIR
			/*
			 * Pointer to /share.
			 */
			OUTPUT(buf, sizeof(buf), "SFS REMOTE=%s%s LOCAL=%s\n",
				fshostid, FSDIR_SHARE, SHAREDIR);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);
#endif
			/*
			 * Return a mount for "certprog dirsearch"
			 * that matches the local convention. This
			 * allows the same paths to work on remote
			 * nodes.
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s/%s LOCAL=%s%s\n",
			       fshostid, FSDIR_PROJ, DOTSFS, PROJDIR, DOTSFS);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
		else {
			/*
			 * Remote nodes get slightly different mounts.
			 * in /netbed.
			 *
			 * Pointer to /proj.
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s LOCAL=%s/%s\n",
			       fshostid, FSDIR_PROJ, NETBEDDIR, PROJDIR);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);

			/*
			 * Pointer to /groups
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s LOCAL=%s%s\n",
			       fshostid, FSDIR_GROUPS, NETBEDDIR, GROUPDIR);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);

			/*
			 * Pointer to /users
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s LOCAL=%s%s\n",
			       fshostid, FSDIR_USERS, NETBEDDIR, USERDIR);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);
#ifdef FSSCRATCHDIR
			/*
			 * Pointer to per-project scratch directory.
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s LOCAL=%s/%s\n",
			       fshostid, FSDIR_SCRATCH, NETBEDDIR, SCRATCHDIR);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);
#endif
#ifdef FSSHAREDIR
			/*
			 * Pointer to /share.
			 */
			OUTPUT(buf, sizeof(buf),
			       "SFS REMOTE=%s%s LOCAL=%s%s\n",
			       fshostid, FSDIR_SHARE, NETBEDDIR, SHAREDIR);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("MOUNTS: %s", buf);
#endif
		}
	}
	/*
	 * Remote nodes do not get per-user mounts.
	 * Geni nodes do not get them either.
	 * Nodes tainted with 'blackbox' do not get them either.
	 */
	if (!reqp->islocal ||
	    !strcmp(reqp->nfsmounts, "genidefault") ||
	    HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX))
	        return 0;

	/*
	 * Now a list of user directories. These include the members of the
	 * experiments projects if its a regular experimental node.
	 */
	res = mydb_query("select u.uid,u.admin from users as u "
			 "left join group_membership as p on "
			 "     p.uid_idx=u.uid_idx "
			 "where p.pid='%s' and p.gid='%s' and "
			 "      u.status='active' and "
			 "      u.webonly=0 and "
			 "      p.trust!='none'",
			 2, reqp->pid, reqp->gid);
	if (!res) {
		error("MOUNTS: %s: DB Error getting users!\n", reqp->pid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		error("MOUNTS: %s: No Users!\n", reqp->pid);
		mysql_free_result(res);
		return 0;
	}

	while (nrows--) {
		row = mysql_fetch_row(res);
#ifdef ISOLATEADMINS
		isadmin = atoi(row[1]);
		if (isadmin != reqp->swapper_isadmin) {
			continue;
		}
#endif
		bufp = buf;
		if (!nomounts)
			bufp += OUTPUT(bufp, ebufp-bufp, "REMOTE=%s:%s/%s ",
				       fsnode, FSDIR_USERS, row[0]);
		OUTPUT(bufp, ebufp-bufp, "LOCAL=%s/%s\n", USERDIR, row[0]);
		client_writeback(sock, buf, strlen(buf), tcp);

		if (verbose)
		    info("MOUNTS: %s", buf);
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Used by dosfshostid to make sure NFS doesn't give us problems.
 * (This code really unnerves me)
 */
int sfshostiddeadfl;
jmp_buf sfshostiddeadline;
static void
dosfshostiddead()
{
	sfshostiddeadfl = 1;
	longjmp(sfshostiddeadline, 1);
}

static int
safesymlink(char *name1, char *name2)
{
	/*
	 * Really, there should be a cleaner way of doing this, but
	 * this works, at least for now.  Perhaps using the DB and a
	 * symlinking deamon alone would be better.
	 */
	if (setjmp(sfshostiddeadline) == 0) {
		sfshostiddeadfl = 0;
		signal(SIGALRM, dosfshostiddead);
		alarm(1);

		unlink(name2);
		if (symlink(name1, name2) < 0) {
			sfshostiddeadfl = 1;
		}
	}
	alarm(0);
	if (sfshostiddeadfl) {
		errorc("symlinking %s to %s", name2, name1);
		return -1;
	}
	return 0;
}

/*
 * Create dirsearch entry for node.
 */
COMMAND_PROTOTYPE(dosfshostid)
{
	char	nodehostid[HOSTID_SIZE], buf[BUFSIZ];
	char	sfspath[BUFSIZ], dspath[BUFSIZ];

	if (!strlen(fshostid)) {
		/* SFS not being used */
		info("dosfshostid: Called while SFS is not in use\n");
		return 0;
	}

	/*
	 * Dig out the hostid. Need to be careful about not overflowing
	 * the buffer.
	 */
	sprintf(buf, "%%%ds", (int)sizeof(nodehostid));
	if (sscanf(rdata, buf, nodehostid) != 1) {
		error("dosfshostid: No hostid reported!\n");
		return 1;
	}

	/*
	 * No slashes allowed! This path is going into a symlink below.
	 */
	if (index(nodehostid, '/')) {
		error("dosfshostid: %s Invalid hostid: %s!\n",
		      reqp->nodeid, nodehostid);
		return 1;
	}

	/*
	 * Create symlink names
	 */
	OUTPUT(sfspath, sizeof(sfspath), "/sfs/%s", nodehostid);
	OUTPUT(dspath, sizeof(dspath), "%s/%s/%s.%s.%s", PROJDIR, DOTSFS,
	       reqp->nickname, reqp->eid, reqp->pid);

	/*
	 * Create the symlink. The directory in which this is done has to be
	 * either owned by the same uid used to run tmcd, or in the same group.
	 */
	if (safesymlink(sfspath, dspath) < 0) {
		return 1;
	}

	/*
	 * Stash into the DB too.
	 */
	mysql_escape_string(buf, nodehostid, strlen(nodehostid));

	if (mydb_update("update node_hostkeys set sfshostid='%s' "
			"where node_id='%s'", buf, reqp->nodeid)) {
		error("SFSHOSTID: %s: DB Error setting sfshostid!\n",
		      reqp->nodeid);
		return 1;
	}
	if (verbose)
		info("SFSHOSTID: %s: %s\n", reqp->nodeid, nodehostid);
	return 0;
}

/*
 * Return routing stuff.
 */
COMMAND_PROTOTYPE(dorouting)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		n, nrows, isstatic = 0;

	/*
	 * Get the routing type from the nodes table.
	 */
	res = mydb_query("select routertype from nodes where node_id='%s'",
			 1, reqp->nodeid);

	if (!res) {
		error("ROUTES: %s: DB Error getting router type!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Return type. At some point we might have to return a list of
	 * routes too, if we support static routes specified by the user
	 * in the NS file.
	 */
	row = mysql_fetch_row(res);
	if (! row[0] || !row[0][0]) {
		mysql_free_result(res);
		return 0;
	}
	if (!strcmp(row[0], "static")) {
		isstatic = 1;
	}
	OUTPUT(buf, sizeof(buf), "ROUTERTYPE=%s\n", row[0]);
	mysql_free_result(res);

	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("ROUTES: %s", buf);

	/*
	 * New images treat "static" as "static-ddijk", so even if there
	 * are routes in the DB, we do not want to return them to the node
	 * since that would be a waste of bandwidth.
	 */
	if (vers >= 19 && isstatic) {
		return 0;
	}

	/*
	 * Get the routing type from the nodes table.
	 */
	res = mydb_query("select dst,dst_type,dst_mask,nexthop,cost,src "
			 "from virt_routes as vi "
			 "where vi.vname='%s' and "
			 " vi.pid='%s' and vi.eid='%s'",
			 6, reqp->nickname, reqp->pid, reqp->eid);

	if (!res) {
		error("ROUTES: %s: DB Error getting manual routes!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	n = nrows;

	while (n) {
		char dstip[32];
		char *bufp = buf, *ebufp = &buf[sizeof(buf)];

		row = mysql_fetch_row(res);

		/*
		 * OMG, the Linux route command is too stupid to accept a
		 * host-on-a-subnet as the subnet address, so we gotta mask
		 * off the bits manually for network routes.
		 *
		 * Eventually we'll perform this operation in the NS parser
		 * so it appears in the DB correctly.
		 */
		if (strcmp(row[1], "net") == 0) {
			struct in_addr tip, tmask;

			inet_aton(row[0], &tip);
			inet_aton(row[2], &tmask);
			tip.s_addr &= tmask.s_addr;
			strncpy(dstip, inet_ntoa(tip), sizeof(dstip));
		} else
			strncpy(dstip, row[0], sizeof(dstip));

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "ROUTE DEST=%s DESTTYPE=%s DESTMASK=%s "
			       "NEXTHOP=%s COST=%s",
			       dstip, row[1], row[2], row[3], row[4]);

		if (vers >= 12) {
			bufp += OUTPUT(bufp, ebufp - bufp, " SRC=%s", row[5]);
		}
		OUTPUT(bufp, ebufp - bufp, "\n");
		client_writeback(sock, buf, strlen(buf), tcp);

		n--;
	}
	mysql_free_result(res);
	if (verbose)
	    info("ROUTES: %d routes in list\n", nrows);

	return 0;
}

static int
get_node_loadinfo(tmcdreq_t *reqp, char **serverp, char **disktypep,
		  int *disknump, int *biosdisknump, int *dotrimp,
		  char **useacpip, char **useasfp, char **noclflushp,
		  char **vgaonlyp, char **consoletypep, char **dom0memp,
		  char **disableifp)
{
	MYSQL_RES	*res2;
	MYSQL_ROW	row2;
	char		*disktype, *useacpi, *useasf, *noclflush, *dom0mem;
	char		*vgaonly, *consoletype, *disableif, *attrclause;
	int		disknum, biosdisknum, dotrim;
	unsigned int	trimiv, trimtime;

	res2 = mydb_query("select IP "
			  " from interfaces as i, subbosses as s "
			  " where i.node_id=s.subboss_id and "
			  " i.role='ctrl' and "
			  " s.node_id='%s' and s.service='frisbee'"
			  " and s.disabled=0",
			  1, reqp->isvnode ? reqp->pnodeid : reqp->nodeid);
	if (!res2) {
		error("doloadinfo: %s: DB Error getting subboss info!\n",
		      reqp->nodeid);
		return 1;
	}

	if (mysql_num_rows(res2)) {
		row2 = mysql_fetch_row(res2);
		*serverp = strdup(row2[0]);
	} else {
		*serverp = strdup(BOSSNODE_IP);
	}
	mysql_free_result(res2);

	/*
	 * Get per-disk or per-type attributes for the node
	 */
	disktype = NULL;
	disknum = DISKNUM;
	biosdisknum = -1;
	dotrim = 0;
	trimiv = 0;
	trimtime = 0;
	useacpi = NULL;
	useasf = NULL;
	noclflush = NULL;
	vgaonly = NULL;
	consoletype = NULL;
	dom0mem = NULL;
	disableif = NULL;

	/*
	 * This query is intended to select certain attributes from
	 * node_type_attributes table, but allow them to be overridden
	 * by entries in the node_attributes table for the node
	 * making the request. Use a "union" of two selects, where
	 * results from the second select on node_attributes will
	 * overwrite anything returned for the same key in the first
	 * select on node_type_attributes.
	 *
	 * N.B. the above paragraph is not correct. The union actually
	 * returns key/value rows from BOTH tables unless the values
	 * are also identical. It is the while loop below that always
	 * chooses the second value (the node_attributes value) in
	 * preference to the first.
	 *
	 * The original select required that the key be in the
	 * node_type_attributes table, else it would fail to find
	 * it in the node_attributes table. This was the easiest
	 * way to fix it. 
	 */
	attrclause =
		"(attrkey='bootdisk_unit' or "
		" attrkey='bootdisk_bios_id' or "
		" attrkey='bootdisk_trim' or "
		" attrkey='bootdisk_trim_interval' or "
		" attrkey='bootdisk_lasttrim' or "
		" attrkey='disktype' or "
		" attrkey='use_acpi' or "
		" attrkey='use_asf' or "
		" attrkey='console_type' or "
		" attrkey='vgaonly' or "
		" attrkey='dom0mem' or "
		" attrkey='disable_if' or "
		" attrkey='no_clflush')";

	res2 = mydb_query("(select attrkey,attrvalue from nodes as n "
			  " left join node_type_attributes as a on "
			  "      n.type=a.type "
			  " where %s and n.node_id='%s') "
			  "union "
			  "(select attrkey,attrvalue "
			  "   from node_attributes "
			  " where %s and node_id='%s') ",
			  2, attrclause, reqp->nodeid,
			  attrclause, reqp->nodeid);

	if (!res2) {
		error("doloadinfo: %s: DB Error getting disktype!\n",
		      reqp->nodeid);
		free(serverp);
		return 1;
	}

	if ((int)mysql_num_rows(res2) > 0) {
		int nrows2 = (int)mysql_num_rows(res2);

		while (nrows2) {
			char *attrstr;

			row2 = mysql_fetch_row(res2);

			if (row2[1] && row2[1][0])
				attrstr = strdup(row2[1]);
			else
				attrstr = NULL;

			if (attrstr) {
				if (strcmp(row2[0], "bootdisk_unit") == 0) {
					disknum = atoi(attrstr);
					free(attrstr);
				}
				else if (strcmp(row2[0], "bootdisk_bios_id") == 0) {
					biosdisknum = strtol(attrstr, 0, 0);
					free(attrstr);
				}
				else if (strcmp(row2[0], "bootdisk_trim") == 0) {
					dotrim = atoi(attrstr);
					free(attrstr);
				}
				else if (strcmp(row2[0], "bootdisk_trim_interval") == 0) {
					trimiv = (unsigned int)atoi(attrstr);
					free(attrstr);
				}
				else if (strcmp(row2[0], "bootdisk_lasttrim") == 0) {
					trimtime = (unsigned int)atoi(attrstr);
					free(attrstr);
				}
				else if (strcmp(row2[0], "disktype") == 0) {
					if (disktype) free(disktype);
					disktype = attrstr;
				}
				else if (strcmp(row2[0], "use_acpi") == 0) {
					if (useacpi) free(useacpi);
					useacpi = attrstr;
				}
				else if (strcmp(row2[0], "use_asf") == 0) {
					if (useasf) free(useasf);
					useasf = attrstr;
				}
				else if (strcmp(row2[0], "no_clflush") == 0) {
					if (noclflush) free(noclflush);
					noclflush = attrstr;
				}
				else if (strcmp(row2[0], "vgaonly") == 0) {
					if (vgaonly) free(vgaonly);
					vgaonly = attrstr;
				}
				else if (strcmp(row2[0], "dom0mem") == 0) {
					if (dom0mem) free(dom0mem);
					dom0mem = attrstr;
				}
				else if (strcmp(row2[0], "console_type") == 0) {
					if (consoletype) free(consoletype);
					consoletype = attrstr;
				}
				else if (strcmp(row2[0], "disable_if") == 0) {
					if (disableif) free(disableif);
					disableif = attrstr;
				}
			}
			nrows2--;
		}
	}

	*disktypep = disktype ? disktype : strdup(DISKTYPE);
	*disknump = disknum;
	*biosdisknump = biosdisknum;
	*useacpip = useacpi ? useacpi : strdup("unknown");
	*useasfp = useasf ? useasf : strdup("unknown");
	*noclflushp = noclflush ? noclflush : strdup("unknown");
	*vgaonlyp = vgaonly;
	*consoletypep = consoletype;
	*disableifp = disableif;
	*dom0memp = dom0mem ? dom0mem : strdup("1024M");

	if (res2)
		mysql_free_result(res2);

	/*
	 * Disk TRIMing. Originally, we had it so that a per node (nodetype)
	 * attribute 'bootdisk_trim' determined whether the boot disk should
	 * be TRIMed and the 'disk_trim_interval' site-variable specifying the
	 * interval between trims.
	 *
	 * That really too coarse-grained for the interval, so now we have
	 * the per node (nodetype) 'bootdisk_trim_interval' attribute which
	 * if non-zero specifies the interval. Thus, it is now a three-level
	 * hierarcy: system-wide, per-nodetype, per-node.
	 *
	 * To disable trim system-wide, set the site-variable to zero.
	 * Otherwise (if you are going to do any trimming at all), set it to
	 * some reasonable default value.
	 *
	 * To set a system-wide value, set the site-variable to the interval
	 * and set the bootdisk_trim attribute non-zero for nodetypes and/or
	 * nodes that should be trimmed.
	 *
	 * To set different per-nodetype (per node) trim intervals, set
	 * the site-variable non-zero, set the per-nodetype (per-node)
	 * bootdisk_trim attribute non-zero, and then set per-nodetype
	 * (per-node) 'bootdisk_trim_interval' values as desired.
	 *
	 * To disable trim for a particular node, just set its bootdisk_trim
	 * attribute to zero. To disable it for a nodetype, you will have to
	 * set the per-node bootdisk_trim attribute to zero for all nodes of
	 * that type.
	 */
	if (dotrim > 0) {
		struct timeval now;
		unsigned int gtrimiv = 0;

		/* default to no trim */
		dotrim = 0;

		/* XXX super conservative: only trim if going through reload */
		if (strcmp(reqp->pid, RELOADPID) != 0 ||
		    strcmp(reqp->eid, RELOADEID) != 0)
			goto trimdone;

		/* Get global trim interval. Trim disabled if == 0 */
		res2 = mydb_query("select value,defaultvalue from sitevariables "
				  "where name='general/disk_trim_interval'", 2);
		if (res2 && (int)mysql_num_rows(res2) > 0) {
			row2 = mysql_fetch_row(res2);
			if (row2[0] && row2[0][0])
				gtrimiv = (unsigned int)atoi(row2[0]);
			else if (row2[1] && row2[1][0])
				gtrimiv = (unsigned int)atoi(row2[1]);
		}
		if (res2)
			mysql_free_result(res2);

		/* if globally disabled, skip */
		if (!gtrimiv)
			goto trimdone;

		/* use global val if no node(type) specific trim interval */
		if (!trimiv)
			trimiv = gtrimiv;

		/* time to trim! */
		gettimeofday(&now, NULL);
		if (now.tv_sec > (time_t)(trimtime + trimiv)) {
			mydb_update("replace into node_attributes values "
				    "('%s','bootdisk_lasttrim','%u',0)",
				    reqp->nodeid, (unsigned)now.tv_sec);
			dotrim = 1;
		}
	}
 trimdone:
	*dotrimp = dotrim;

	return 0;
}

/*
 * Return address from which to load an image, along with the partition that
 * it should be written to and the OS type in that partition.
 */
COMMAND_PROTOTYPE(doloadinfo)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	char		address[MYBUFSIZE];
	char            server_address[MYBUFSIZE];
	char		mbrvers[51];
	char            *loadpart, *OS, *prepare, *version;
	int		nrows, zfill;
	char		*server, *disktype, *useacpi, *useasf, *noclflush;
	char		*vgaonly, *consoletype, *dom0mem, *disableif;
	int		disknum, biosdisknum, dotrim, heartbeat;

	/*
	 * Get the address the node should contact to load its image
	 */
	res = mydb_query("select iv.loadpart,ov.OS,mustwipe,iv.mbr_version,"
			 "   iv.access_key,"
			 "   i.imageid,prepare,i.imagename,p.pid,g.gid,iv.path,"
			 "   ov.version,pa.`partition`,iv.size,"
			 "   iv.lba_low,iv.lba_high,iv.lba_size,iv.relocatable,"
			 "   UNIX_TIMESTAMP(iv.updated),r.imageid_version,"
			 "   iv.format "
			 "from current_reloads as r "
			 "left join images as i on i.imageid=r.image_id "
			 "left join image_versions as iv on "
			 "     iv.imageid=i.imageid and "
			 "     iv.version=r.imageid_version "
			 "left join frisbee_blobs as f on f.imageid=i.imageid "
			 "left join os_info_versions as ov on "
			 "     ov.osid=iv.default_osid and "
			 "     ov.vers=iv.default_vers "
			 "left join projects as p on i.pid_idx=p.pid_idx "
			 "left join groups as g on i.gid_idx=g.gid_idx "
			 "left join `partitions` as pa on "
			 "     pa.node_id=r.node_id and "
			 "     pa.osid=iv.default_osid and loadpart=0 "
			 "where r.node_id='%s' order by r.idx",
			 21, reqp->nodeid);

	if (!res) {
		error("doloadinfo: %s: DB Error getting loading address!\n",
		       reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Cannot handle multiple images prior to version 29.
	 * Tell them to update their MFS.
	 */
	if (nrows > 1 && vers <= 29)
		goto updatemfs;

	/*
	 * See if we want the client to send periodic reports
	 */
	heartbeat = 0;
	if (vers >= 41) {
		MYSQL_RES	*res2;
		MYSQL_ROW	row2;

		res2 = mydb_query("select value,defaultvalue "
				  "from sitevariables "
				  "where name='images/frisbee/heartbeat'", 2);
		if (res2 && (int)mysql_num_rows(res2) > 0) {
			row2 = mysql_fetch_row(res2);
			if (row2[0] && row2[0][0])
				heartbeat = (unsigned int)atoi(row2[0]);
			else if (row2[1] && row2[1][0])
				heartbeat = (unsigned int)atoi(row2[1]);
		}
		if (res2)
			mysql_free_result(res2);
	}

	/*
	 * Get all the other node-specific info just once.
	 * XXX this is a total hack!
	 */
	if (get_node_loadinfo(reqp, &server, &disktype, &disknum, &biosdisknum,
			      &dotrim, &useacpi, &useasf, &noclflush,
			      &vgaonly, &consoletype, &dom0mem, &disableif)) {
		mysql_free_result(res);
		return 1;
	}

	while (nrows) {
		row = mysql_fetch_row(res);
		loadpart = row[0];
		OS = row[1];
		prepare = row[6];
		version = row[11];
		strcpy(server_address, server);

		/*
		 * Remote nodes get a URL for the address.
		 */
		if (!reqp->islocal) {
			if (!row[4] || !row[4][0]) {
				error("doloadinfo: %s: "
				      "No access key associated with imageid %s\n",
				      reqp->nodeid, row[5]);
				mysql_free_result(res);
				return 1;
			}
			OUTPUT(address, sizeof(address),
			       "%s/spewimage.php?imageid=%s&access_key=%s",
			       TBBASE, row[5], row[4]);
			
			server_address[0] = 0;
		}
		/*
		 * As of version 33, local nodes no longer get an address,
		 * they contact the frisbee master server instead.
		 *
		 * We provide temporary backward compat by firing off
		 * a proxy request to the master server. If that doesn't
		 * work, we draw attention to ourselves via the update MFS
		 * path above.
		 */
		else if (vers >= 33) {
			address[0] = '\0';
		} else {
			char _buf[512];
			int gotit = 0;
			FILE *cfd;

			info("%s LOADINFO compat: starting server for imageid %s",
			     reqp->nodeid, row[5]);
			/*
			 * XXX for vnodes we use the pnode name since the
			 * master server wants to validate a node_id by
			 * looking up its control net IP address in the
			 * interfaces table.  Vnodes have no interfaces
			 * table entries so that won't work.
			 */
			snprintf(_buf, sizeof _buf,
				 "%s/sbin/frisbeehelper -n %s %s",
				 TBROOT,
				 reqp->isvnode ? reqp->pnodeid : reqp->nodeid,
				 row[5]);
			if ((cfd = popen(_buf, "r")) == NULL)
				goto updatemfs;
			while (fgets(_buf, sizeof _buf, cfd) != NULL) {
#if 0
				if (debug > 1)
					info("got: '%s'\n", _buf);
#endif
				if (strncmp(_buf, "Address is ", 11) == 0) {
					gotit = 1;
					break;
				}
			}
			pclose(cfd);
			if (!gotit ||
			    sscanf(_buf, "Address is %32s", address) != 1)
				goto updatemfs;

			/* XXX address info is for boss, not a subboss */
			strcpy(server_address, BOSSNODE_IP);
		}

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "ADDR=%s PART=%s PARTOS=%s", address, loadpart, OS);

		if (server_address[0] && (vers >= 31)) {
			bufp += OUTPUT(bufp, ebufp - bufp,
			               " SERVER=%s", server_address);
		}
		bufp += OUTPUT(bufp, ebufp - bufp,
			       " OSVERSION=%s", version);
		/*
		 * For virtual node reloading, it is convenient to tell it what
		 * partition to boot, for the case that it is a whole disk image
		 * and the client can not derive which partition to boot from.
		 *
		 * XXX 7/17/2014: retroactively add a version number check.
		 * "BOOTPART=" confuses the old rc.frisbee argument parsing
		 * which looks for "PART=" with the RE ".*PART=" which will
		 * match BOOTPART= instead. Thus an old script loading a
		 * whole disk image (PART=0) winds up trying to load it in
		 * partition 2 (BOOTPART=2). So we can pick one of two
		 * versions, the one in effect when rc.frisbee changed its
		 * argument parsing (v30, circa 6/28/2010) or the version
		 * in effect when BOOTPART was added (v36, circa 6/13/2013).
		 * We choose the latter.
		 */
		if (row[12] && row[12][0] && vers >= 36) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " BOOTPART=%s", row[12]);
		}

		/*
		 * Add zero-fill free space, MBR version fields, and access_key
		 */
		zfill = 0;
		if (row[2] && row[2][0])
			zfill = atoi(row[2]);
		strcpy(mbrvers, "1");
		if (row[3] && row[3][0])
			strcpy(mbrvers, row[3]);

		bufp += OUTPUT(bufp, ebufp - bufp,
			       " DISK=%s%d ZFILL=%d ACPI=%s MBRVERS=%s"
			       " ASF=%s PREPARE=%s NOCLFLUSH=%s",
			       disktype, disknum, zfill, useacpi, mbrvers,
			       useasf, prepare, noclflush);
		if (consoletype) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " CONSOLE=%s", consoletype);
		} else if (vgaonly) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " VGAONLY=%s", vgaonly);
		}
		if (biosdisknum >= 0) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " BIOSDISK=0x%02x", biosdisknum);
		}
		bufp += OUTPUT(bufp, ebufp - bufp,
			       " DOM0MEM=%s", dom0mem);
		if (disableif) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " DISABLEIF=%s", disableif);
		}
		if (dotrim > 0) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " TRIM=%d", dotrim);
		}
		if (heartbeat > 0) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " HEARTBEAT=%d", heartbeat);
		}

		/*
		 * Vnodes (and post v32 local nodes) get additional image
		 * metadata fields so that they can uniquely identify the
		 * image.
		 */
		if (reqp->isvnode || (reqp->islocal && vers >= 33)) {
 			if (!row[7] || !row[7][0]) {
				error("doloadinfo: %s: No imagename"
				      " associated with imageid %s\n",
				      reqp->nodeid, row[5]);
				mysql_free_result(res);
				return 1;
			}
			if (!row[8] || !row[8][0]) {
				error("doloadinfo: %s: No pid"
				      " associated with imageid %s\n",
				      reqp->nodeid, row[5]);
				mysql_free_result(res);
				return 1;
			}
			if (!row[9] || !row[9][0]) {
				error("doloadinfo: %s: No gid"
				      " associated with imageid %s\n",
				      reqp->nodeid, row[5]);
				mysql_free_result(res);
				return 1;
			}

			bufp += OUTPUT(bufp, ebufp - bufp, " IMAGEID=%s,%s,%s",
				       row[8], row[9], row[7]);

			if (vers >= 39 || !reqp->isvnode) {
				/*
				 * older mkvnode cannot handle :version,
				 * nor can they handle deltas. So if the
				 * server side is not doing versions, do
				 * not return any version info even if the
				 * client is updated, since there is still
				 * an incompatibility with how images are
				 * named on existing XEN hosts. 
				 */
				if (WITHPROVENANCE) {
					bufp += OUTPUT(bufp,
						       ebufp - bufp, ":%s",
						       row[19]);
				}
			}

			/*
			 * All images version 38 and above, or just vnodes
			 * prior to that get additional info:
			 *
			 * all nodes v38+: mtime, chunks, sector range and
			 *                 size, relocatable flag
			 * pre-v38 vnodes: mtime, chunks.
			 */
			if (vers >= 38 || reqp->isvnode) {
				unsigned int mtime, chunks;
				off_t isize;
				
				if (!row[10] || !row[10][0]) {
					error("doloadinfo: %s: No path"
					      " associated with imageid %s\n",
					      reqp->nodeid, row[5]);
					mysql_free_result(res);
					return 1;
				}
				/*
				 * If mtime and size are set in the DB, use
				 * those values. Otherwise, take extraordinary
				 * measures to get the values.
				 */
				if (row[13] && row[13][0])
					isize = (off_t)strtoll(row[13], 0, 0);
				else
					isize = 0;
				if (row[18] && row[18][0])
					mtime = strtol(row[18], 0, 0);
				else
					mtime = 0;
				if (isize == 0 || mtime == 0) {
					if (getImageInfo(row[10], reqp->nodeid,
							 row[8], row[7],
							 &mtime, &isize)) {
						mysql_free_result(res);
						return 1;
					}
				}
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " IMAGEMTIME=%u", mtime);
				/* XXX assumes chunksize of 1MB */
				chunks = (unsigned)((isize + 1024*1024 - 1) /
						    (1024*1024));
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " IMAGECHUNKS=%u", chunks);
				/*
				 * Starting with version 38, we return DB
				 * info about the sector range occupied by
				 * the image and whether it is relocatable.
				 *
				 * XXX if lba_high==0 then assume the DB
				 * fields have not been initialized and
				 * don't return this info.
				 */
				if (vers >= 38 && row[15] && row[15][0] &&
				    strcmp(row[15], "0") != 0) {
					if (row[14]) {
						bufp += OUTPUT(bufp,
							       ebufp - bufp,
							       " IMAGELOW=%s",
							       row[14]);
					}
					if (row[15]) {
						bufp += OUTPUT(bufp,
							       ebufp - bufp,
							       " IMAGEHIGH=%s",
							       row[15]);
					}
					if (row[16]) {
						bufp += OUTPUT(bufp,
							       ebufp - bufp,
							       " IMAGESSIZE=%s",
							       row[16]);
					}
					if (row[17]) {
						bufp += OUTPUT(bufp,
							       ebufp - bufp,
							       " IMAGERELOC=%s",
							       row[17]);
					}
				}
			}
		}

		/*
		 * If this is a Docker vnode, hand back the path too.
		 * Updated for version 43, always return path.
		 */
		if (vers >= 43 ||
		    (reqp->isvnode && row[20] && row[20][0]
		     && strcmp("docker",row[20]) == 0)) {
			if (row[10])
				bufp += OUTPUT(bufp,ebufp - bufp,
					       " PATH=%s",row[10]);
			else
				bufp += OUTPUT(bufp,ebufp - bufp," PATH=");
		}

		/* Tack on the newline, finally */
		bufp += OUTPUT(bufp, ebufp - bufp, "\n");

		/* Output line at a time in case we have a lot of images */
		if (nrows > 1) {
			client_writeback(sock, buf, strlen(buf), tcp);
			bufp = buf;
		}

		nrows--;
	}
	if (res)
		mysql_free_result(res);

	if (server)
		free(server);
	if (disktype)
		free(disktype);
	if (useacpi)
		free(useacpi);
	if (useasf)
		free(useasf);
	if (noclflush)
		free(noclflush);
	if (vgaonly)
		free(vgaonly);
	if (consoletype)
		free(consoletype);
	if (dom0mem)
		free(dom0mem);
	if (disableif)
		free(disableif);

	/* Output the final (or only, or null) line */
	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("doloadinfo: %s", buf);

	return 0;

 updatemfs:
	bufp += OUTPUT(bufp, ebufp - bufp,
		       "ADDR=/NEWER-MFS-NEEDED PART=0 PARTOS=Bogus\n");

	error("doloadinfo: %s: Old MFS Version found, need version 33\n",
	      reqp->nodeid);

#ifdef EVENTSYS
	address_tuple_t tuple;
	/*
	 * Send the state out via an event
	 */
	/* XXX: Maybe we don't need to alloc a new tuple every time through */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		error("doreset: Unable to allocate address tuple!\n");
		return 1;
	}

	tuple->host      = BOSSNODE;
	tuple->objtype   = "TBNODESTATE";
	tuple->objname	 = reqp->nodeid;
	tuple->eventtype = "RELOADOLDMFS";

	if (myevent_send(tuple)) {
		error("doloadinfo: %s: "
		      "Unable to set state to RELOADOLDMFS",
		      reqp->nodeid);
	}

	address_tuple_free(tuple);
#endif
	if (res)
		mysql_free_result(res);

	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("doloadinfo: %s", buf);

	return 0;
}

/*
 * Have stated reset any next_pxe_boot_* and next_boot_* fields.
 * Produces no output to the client.
 */
COMMAND_PROTOTYPE(doreset)
{
#ifdef EVENTSYS
	address_tuple_t tuple;
	/*
	 * Send the state out via an event
	 */
	/* XXX: Maybe we don't need to alloc a new tuple every time through */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		error("doreset: Unable to allocate address tuple!\n");
		return 1;
	}

	tuple->host      = BOSSNODE;
	tuple->objtype   = TBDB_OBJECTTYPE_TESTBED; /* "TBCONTROL" */
	tuple->objname	 = reqp->nodeid;
	tuple->eventtype = TBDB_EVENTTYPE_RESET;

	if (myevent_send(tuple)) {
		error("doreset: Error sending event\n");
		return 1;
	} else {
	        info("Reset event sent for %s\n", reqp->nodeid);
	}

	address_tuple_free(tuple);
#else
	info("No event system - no reset performed.\n");
#endif
	return 0;
}

/*
 * Return trafgens info
 */
COMMAND_PROTOTYPE(dotrafgens)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	res = mydb_query("select vi.vname,role,proto,"
			 "  vnode,port,ip,target_vnode,target_port,target_ip, "
			 "  generator "
			 " from virt_trafgens as vi "
			 "where vi.vnode='%s' and "
			 " vi.pid='%s' and vi.eid='%s'",
			 10, reqp->nickname, reqp->pid, reqp->eid);

	if (!res) {
		error("TRAFGENS: %s: DB Error getting virt_trafgens\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		char myname[TBDB_FLEN_VNAME+2];
		char peername[TBDB_FLEN_VNAME+2];

		row = mysql_fetch_row(res);

		if (row[5] && row[5][0]) {
			strcpy(myname, row[5]);
			strcpy(peername, row[8]);
		}
		else {
			/* This can go away once the table is purged */
			strcpy(myname, row[3]);
			strcat(myname, "-0");
			strcpy(peername, row[6]);
			strcat(peername, "-0");
		}

		OUTPUT(buf, sizeof(buf),
		        "TRAFGEN=%s MYNAME=%s MYPORT=%s "
			"PEERNAME=%s PEERPORT=%s "
			"PROTO=%s ROLE=%s GENERATOR=%s\n",
			row[0], myname, row[4], peername, row[7],
			row[2], row[1], row[9]);

		client_writeback(sock, buf, strlen(buf), tcp);

		nrows--;
		if (verbose)
			info("TRAFGENS: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return nseconfigs info
 */
COMMAND_PROTOTYPE(donseconfigs)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows;

	if (!tcp) {
		error("NSECONFIGS: %s: Cannot do UDP mode!\n", reqp->nodeid);
		return 1;
	}

	res = mydb_query("select nseconfig from nseconfigs as nse "
			 "where nse.pid='%s' and nse.eid='%s' "
			 "and nse.vname='%s'",
			 1, reqp->pid, reqp->eid, reqp->nickname);

	if (!res) {
		error("NSECONFIGS: %s: DB Error getting nseconfigs\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	row = mysql_fetch_row(res);

	/*
	 * Just shove the whole thing out.
	 */
	if (row[0] && row[0][0]) {
		client_writeback(sock, row[0], strlen(row[0]), tcp);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Report that the node has entered a new state
 */
COMMAND_PROTOTYPE(dostate)
{
	char 		newstate[128];	/* More then we will ever need */
	MYSQL_RES	*res;
	int		nrows;
	int		i;
#ifdef EVENTSYS
	address_tuple_t tuple;
#endif

#ifdef LBS
	return 0;
#endif

	/*
	 * Dig out state that the node is reporting
	 */
	if (sscanf(rdata, "%128s", newstate) != 1 ||
	    strlen(newstate) == sizeof(newstate)) {
		error("DOSTATE: %s: Bad arguments\n", reqp->nodeid);
		return 1;
	}

        /*
         * Check to make sure that this is not a state that must be reported
         * by the securestate mechanism - we can tell because there are one
         * or more PCR values required in the tpm_quote_values table for
         * the state.
         */
	res = mydb_query("select q.pcr from nodes as n "
			"left join tpm_quote_values as q "
                        "on n.op_mode = q.op_mode "
			"where n.node_id='%s' and q.state ='%s'",
			1, reqp->nodeid,newstate);
	if (!res){
		error("state: %s: DB error check for pcr list\n",
			reqp->nodeid);
		return 1;
	}

	nrows = mysql_num_rows(res);

        mysql_free_result(res);

	if (nrows){
            error("state: %s: tried to go into secure state %s using "
                    "insecure state command\n",reqp->nodeid,newstate);
            return 1;
            // XXX Probably should send a SECVIOLATION state and/or send
            // mail, but this needs more thought before making it the
            // default action.
        }

	/*
	 * Sanity check. No special or weird chars.
	 */
	for (i = 0; i < strlen(newstate); i++) {
		if (! (isalnum(newstate[i]) ||
		       newstate[i] == '_' || newstate[i] == '-')) {
			error("DOSTATE: %s: Bad state name\n", reqp->nodeid);
			return 1;
		}
	}

#ifdef EVENTSYS
	/*
	 * Send the state out via an event
	 */
	/* XXX: Maybe we don't need to alloc a new tuple every time through */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		error("dostate: Unable to allocate address tuple!\n");
		return 1;
	}

	tuple->host      = BOSSNODE;
	tuple->objtype   = "TBNODESTATE";
	tuple->objname	 = reqp->nodeid;
	tuple->eventtype = newstate;

	if (myevent_send(tuple)) {
		error("Error sending event\n");
		info("%s: STATE: %s failed!\n", reqp->nodeid, newstate);
		return 1;
	}

	address_tuple_free(tuple);
#endif /* EVENTSYS */

	/* Leave this logging on all the time for now. */
	info("%s: STATE: %s\n", reqp->nodeid, newstate);
	return 0;

}

/* There are probably classic functions available to do this but I couldn't
 * find one that will convert two bytes of ACII to one byte.  sscanf writes a
 * full int and atoi gives us an int too
 */
static unsigned char hextochar(char *in)
{
	unsigned char lh, rh;

	lh = in[0];
	if (lh >= '0' && lh <= '9')
		lh = lh - '0';
	else if (lh >= 'A' && lh <= 'F')
		lh = lh - 'A' + 10;
	else if (lh >= 'a' && lh <= 'f')
		lh = lh - 'a' + 10;

	rh = in[1];
	if (rh >= '0' && rh <= '9')
		rh = rh - '0';
	else if (rh >= 'A' && rh <= 'F')
		rh = rh - 'A' + 10;
	else if (rh >= 'a' && rh <= 'f')
		rh = rh - 'a' + 10;

	return (lh << 4) | rh;
}

static int ishex(char in)
{
	return ((in >= 'a' && in <= 'f') || (in >= 'A' && in <= 'F') ||
	    (in >= '0' && in <= '9'));
}

/*
 * Report that the node has entered a new state - secure version: the report
 * includes a TPM quote that will be checked against the database.
 * If this check fails, we report a SECVIOLATION event instead, and tell the
 * client so.
 * TODO: Should probably reduce code duplication from dostate()
 */
COMMAND_PROTOTYPE(dosecurestate)
{
	char 		newstate[128];	/* More then we will ever need */
        char            quote[1024];
        char            pcomp[1024];
        unsigned char   quote_bin[256];
        unsigned char   pcomp_bin[512];
	ssize_t		pcomplen, quotelen;
        int             quote_passed;
        char            result[16];
	ETPM_NONCE	nonce;

	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows;
        unsigned long   *nlen;

        int             i,j;
	unsigned int	temp;

        unsigned short  wantpcrs;
        TPM_PCR         *pcrs;

#ifdef EVENTSYS
	address_tuple_t tuple;
#endif

	/*
	 * Dig out state that the node is reporting and the quote
	 */
	if (rdata == NULL ||
	    sscanf(rdata, "%127s %1023s %1023s", newstate, quote, pcomp) != 3 ||
	    strlen(newstate) + 1 == sizeof(newstate) ||
	    strlen(quote) + 1 == sizeof(quote) ||
	    strlen(pcomp) + 1 == sizeof(pcomp)) {
		error("SECURESTATE: %s: Bad arguments\n", reqp->nodeid);
		return 1;
	}

	/*
	 * Have to covert the hex representations of quote and pcomp into
	 * simple binary.
	 */
	if ((strlen(quote) % 2) != 0) {
		error("SECURESTATE: %s: Malformed quote: odd length\n",
		    reqp->nodeid);
		return 1;
	}
        quotelen = strlen(quote)/2;
        printf("quotelen is %ld\n", (long)quotelen);
        for (i = 0; i < quotelen; i++) {
		if (!ishex(quote[i * 2]) || !ishex(quote[i * 2 + 1])) {
			error("Error parsing quote\n");
			// XXX: Send error to client
			return 1;
		}
		quote_bin[i] = hextochar(&quote[i * 2]);
        }

	if ((strlen(pcomp) % 2) != 0) {
		error("SECURESTATE: %s: Malformed pcomp: odd length\n",
		    reqp->nodeid);
		return 1;
	}
        pcomplen = strlen(pcomp)/2;

	if (pcomplen > sizeof(pcomp_bin)) {
		error("SECURESTATE: %s: pcomp is too big (%zd)\n",
		    reqp->nodeid, pcomplen);
		return 1;
	}

        for (i = 0; i < pcomplen; i++) {
		if (!ishex(pcomp[i * 2]) || !ishex(pcomp[i * 2 + 1])) {
			error("Error parsing pcomp\n");
			// XXX: Send error to client
			return 1;
		}
		pcomp_bin[i] = hextochar(&pcomp[i * 2]);
        }

        /*
         * Pull the nonce out, verify the exipration date, and clear it so that
         * it can't be used again.
         */
	res = mydb_query("select nonce, (expires >= UNIX_TIMESTAMP()) "
			"from nonces "
			"where node_id='%s' and purpose='state-%s'",
			2, reqp->nodeid,newstate);
	if (!res){
		error("SECURESTATE: %s: DB error getting nonce\n",
			reqp->nodeid);
		return 1;
	}

	nrows = mysql_num_rows(res);

	if (!nrows){
		error("%s: no nonce in database for this node.\n",
			reqp->nodeid);
		mysql_free_result(res);
                // XXX: return error to client
		return 1;
	}

        // Delete from the database so that it can't be used again
	mydb_update("delete from nonces where node_id='%s' and "
                "purpose='state-%s' ", reqp->nodeid,newstate);


        row = mysql_fetch_row(res);
	nlen = mysql_fetch_lengths(res);
        // XXX: Check to make sure the expire check is working
        if (strcmp(row[1],"1") != 0) {
            error("SECURESTATE: %s: Nonce is expired\n");
            mysql_free_result(res);
            // XXX: return error to client
            return 1;
        }

        // Have to covert the hex representation in the database back into
        // simple binary
        if (nlen[0] != TPM_NONCE_BYTES * 2) {
            error("SECURESTATE: %s: Nonce length is incorrect (%d)",
                    reqp->nodeid, nlen[0]);
        }
        for (i = 0; i < TPM_NONCE_BYTES; i++) {
            if (sscanf(row[0] + (i*2),"%2x", &temp) != 1) {
                error("SECURESTATE: %s: Error parsing nonce\n", reqp->nodeid);
                mysql_free_result(res);
                // XXX: return error to client
                return 1;
            }

	    nonce[i] = (unsigned char)temp;
        }

        mysql_free_result(res);

        /*
         * Make a list of the PCR values we need to have verified
         */
	res = mydb_query("select q.pcr,q.value from nodes as n "
			 "left join tpm_quote_values as q "
			 "on (n.op_mode = q.op_mode or q.op_mode='*') "
			 "and n.node_id = q.node_id "
			 "where n.node_id='%s' and q.state ='%s' "
			 "order by q.pcr",
			 2, reqp->nodeid, newstate);
	if (!res) {
		error("SECURESTATE: %s: DB error getting pcr list\n",
			reqp->nodeid);
		return 1;
	}

	nrows = mysql_num_rows(res);

	if (!nrows){
		error("%s: no TPM quote values in database for state %s\n",
			reqp->nodeid, newstate);
		mysql_free_result(res);
		return 1;
	}

        wantpcrs = 0;
        pcrs = malloc(nrows*sizeof(TPM_PCR));
        for (i = 0; i < nrows; i++) {
            int pcr;

            row = mysql_fetch_row(res);
            // XXX: Check for nonsensical values for the pcr index
            // XXX: Check for nlen...
            // XXX: Check for proper PCR size
            pcr = atoi(row[0]);
            wantpcrs |= (1 << pcr);
            for (j = 0; j < TPM_PCR_BYTES; j++) {
                if (sscanf(row[1] + (j*2),"%2x", &temp) != 1) {
                    error("SECURESTATE: %s: Error parsing PCR\n", reqp->nodeid);
                    free(pcrs);
                    mysql_free_result(res);
                    // XXX: return error to client
                    return 1;
                }
		pcrs[i][j] = (unsigned char)temp;
            }

        }

        mysql_free_result(res);

        /*
         * Get the identity key for vertification purposes
         */
	res = mydb_query("select tpmidentity "
			"from node_hostkeys "
			"where node_id='%s' ",
			1, reqp->nodeid);

	if (!res){
		error("securestate: %s: DB error getting tpmidentity\n",
			reqp->nodeid);
                free(pcrs);
		return 1;
	}

	nrows = mysql_num_rows(res);

	if (!nrows){
		error("%s: no tpmidentity in database for this node.\n",
			reqp->nodeid);
                free(pcrs);
		mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);
	nlen = mysql_fetch_lengths(res);
	if (!nlen || !nlen[0]){
		error("%s: invalid identity length.\n",
			reqp->nodeid);
                free(pcrs);
		mysql_free_result(res);
		return 1;
	}

        // NOTE: Do *not* free the mysql result until *after* the call to
        // verify, as we're passing the identiy key directly from the SQL
        // result.

        /*
         * Parse and check the quote
         *
	 * quote and pcomp both come from the client's TPM - they are both
	 * returned from the quote operation.  We must dig up our nonce again.
         */
        quote_passed = tmcd_tpm_verify_quote(quote_bin, quotelen, pcomp_bin,
                pcomplen, nonce, wantpcrs, pcrs, (unsigned char *)row[0]);

	mysql_free_result(res);
        free(pcrs);

	/* The state reported below depends on whether the quote checked. */
	if (!quote_passed)
		strcpy(newstate, "SECVIOLATION");

#ifdef EVENTSYS
	/*
	 * Send the state out via an event
	 */
	/* XXX: Maybe we don't need to alloc a new tuple every time through */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		error("dostate: Unable to allocate address tuple!\n");
		return 1;
	}

        // TODO: It might be nice to mark in the event that it was verified
        // securely, but the connection to the event server is secure, and
        // we'll refuse the insecure state command for secure states.
	tuple->host      = BOSSNODE;
	tuple->objtype   = "TBNODESTATE";
	tuple->objname	 = reqp->nodeid;
	tuple->eventtype = newstate;

	if (myevent_send(tuple)) {
		error("dostate: Error sending event\n");
		return 1;
	}

	address_tuple_free(tuple);
#endif /* EVENTSYS */

        /*
         * Let the client know whether the quote checks out or not. Note that
         * we do this *after* sending the event so that a malicious client
         * can't stall or prevent the event notification by trying to hold up
         * the TCP connection.
         * Probably a slightly simpler way to do this, but want to stick with
         * the common idioms in this file.
         */
        if (quote_passed) {
            OUTPUT(result, sizeof(result), "OK");
        } else { 
            OUTPUT(result, sizeof(result), "FAILED");
        }
	client_writeback(sock, result, strlen(result), tcp);


	/* Leave this logging on all the time for now. */
	info("%s: SECURESTATE: %s\n", reqp->nodeid, newstate);
	return 0;

}

/*
 * Prepare for a TPM quote: give the client the encrypted identity key,
 * a nonce to use in the quote, and the set of PCRs that need to be included in
 * the quote. This saves some state (the nonce) that will be checked again in
 * dosecurestate().
 */
COMMAND_PROTOTYPE(doquoteprep)
{
	char            newstate[128];	/* More then we will ever need */
        ETPM_NONCE       nonce;
        char            nonce_hex[2*TPM_NONCE_BYTES + 1];
        int             i;

        // XXX: is MYBUFSIZE big enough?
	char		buf[MYBUFSIZE];
	char		*bufp = buf;
	char		*bufe = &buf[MYBUFSIZE];

	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows;
        unsigned long   *nlen;

	/*
	 * Dig out state that the node is reporting - we need this so that we
         * can tell it what PCRs to include
	 */
	if (rdata == NULL || sscanf(rdata, "%128s", newstate) != 1 ||
	    strlen(newstate) == sizeof(newstate)) {
		error("DOQUOTEPREP: %s: Bad arguments\n", reqp->nodeid);
		return 1;
	}

        /*
         * Get the set of PCRs that have to be quoted to move into this state.
         */
	res = mydb_query("select q.pcr from nodes as n "
			 "left join tpm_quote_values as q "
			 "on (n.op_mode = q.op_mode or q.op_mode='*') "
			 "and n.node_id = q.node_id "
			 "where n.node_id='%s' and q.state ='%s' "
			 "order by q.pcr",
			 1, reqp->nodeid, newstate);
	if (!res){
		error("quoteprep: %s: DB error getting pcr list\n",
			reqp->nodeid);
		return 1;
	}

	nrows = mysql_num_rows(res);

	if (!nrows){
		error("%s: no TPM quote values in database for state %s\n",
			reqp->nodeid,newstate);
		mysql_free_result(res);
		return 1;
	}

	bufp += OUTPUT(bufp, bufe - bufp, "PCR=");

        for (i = 0; i < nrows; i++) {
            row = mysql_fetch_row(res);
            // XXX: Is this already passed to us as a string?
            bufp += OUTPUT(bufp, bufe - bufp,"%s",row[0]);
            if (i < (nrows - 1)) {
                    bufp += OUTPUT(bufp, bufe - bufp, ",");
            }
        }

        bufp += OUTPUT(bufp, bufe - bufp, " ");
        mysql_free_result(res);

        /*
         * Grab the (encrypted) identity key for the node - noone else will be
         * able to decrypt it, so we don't have to be too paranoid about who
         * we give it to.
         */
	res = mydb_query("select tpmidentity "
			"from node_hostkeys "
			"where node_id='%s' ",
			1, reqp->nodeid);

	if (!res){
		error("quoteprep: %s: DB error getting tpmidentity\n",
			reqp->nodeid);
		return 1;
	}

	nrows = mysql_num_rows(res);

	if (!nrows){
		error("%s: no tpmidentity in database for this node.\n",
			reqp->nodeid);
		mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);
	nlen = mysql_fetch_lengths(res);
	if (!nlen || !nlen[0]){
		error("%s: invalid identity length.\n",
			reqp->nodeid);
		mysql_free_result(res);
		return 1;
	}

	bufp += OUTPUT(bufp, bufe - bufp, "IDENTITY=");
        for (i = 0;i < nlen[0];++i)
                bufp += OUTPUT(bufp, bufe - bufp,
                        "%.02x", (0xff & ((char)*(row[0]+i))));

        bufp += OUTPUT(bufp, bufe - bufp, " ");
	mysql_free_result(res);
        
        /*
         * Generate a cryptographic nonce - we have to keep track of this to
         * prevent replay attacks.
         */
        if (tmcd_tpm_generate_nonce(nonce)) {
            error("DOQUOTEPREP: %s: Failed to generate nonce\n", reqp->nodeid);
            return 1;
        }

        // Make a hex representation of the nonce
        for (i = 0; i < TPM_NONCE_BYTES; i++) {
            sprintf(nonce_hex + (i*2),"%.02x",nonce[i]);
        }
        nonce_hex[TPM_NONCE_BYTES*2] = '\0';

	if (debug)
		info("%s: NONCE %s\n", reqp->nodeid, nonce_hex);

        // Store the nonce in the database. It expires in one minute, and we
        // overwrite any existing nonces for this node/state combo
	mydb_update("replace into nonces "
		    " (node_id, purpose, nonce, expires) "
		    " values ('%s', 'state-%s','%s', UNIX_TIMESTAMP()+60)",
		    reqp->nodeid,newstate,nonce_hex);

	bufp += OUTPUT(bufp, bufe - bufp, "NONCE=%s",nonce_hex);

	bufp += OUTPUT(bufp, bufe - bufp, "\n");

        /*
         * Return to the client
         */
	client_writeback(sock, buf, bufp - buf, tcp);

        return 0;
}

/*
 * Get the decryption key for the image a node is suposed to be loading
 */
COMMAND_PROTOTYPE(doimagekey)
{
	char		buf[MYBUFSIZE];
	char		*bufp = buf;
	char		*bufe = &buf[MYBUFSIZE];

	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows;
        unsigned long   *nlen;

        /*
	 * No arguments - we don't allow the client to ask for a specific image
         * key, just the one for the image they are supposed to be loading
         * according to the database
         */
        
        /*
         * Make sure that this node is in the right state - hardcoding it is
         * probably not a good idea, but the right way to get it isn't clear
         */
        res = mydb_query("select op_mode,eventstate from nodes where "
			 "node_id='%s'", 2, reqp->nodeid);
	if (!res) {
		error("IMAGEKEY: %s: DB Error getting event state\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) != 1) {
		error("IMAGEKEY: %s: DB Error getting event state\n",
		      reqp->nodeid);
		mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);
	nlen = mysql_fetch_lengths(res);
	if (!nlen) {
		error("IMAGEKEY: %s: DB Error getting event state\n",
		      reqp->nodeid);
		mysql_free_result(res);
                return 1;
        }

        if (strncmp(row[0],SECURELOAD_OPMODE, nlen[0]) ||
            strncmp(row[1],SECURELOAD_STATE, nlen[1])) {
		error("IMAGEKEY: %s: Node is in the wrong state\n",
		      reqp->nodeid);
		mysql_free_result(res);
                return 1;
        }
        mysql_free_result(res);

        /*
         * Grab and return the key itself
         */
	res = mydb_query("select iv.auth_uuid,iv.auth_key,iv.decryption_key,"
			 " i.imagename,p.pid,g.gid "
			 "from current_reloads as r "
			 "left join images as i on i.imageid=r.image_id "
			 "left join image_versions as iv on "
			 "     iv.imageid=i.imageid and iv.version=i.version "
			 "left join projects as p on i.pid_idx=p.pid_idx "
			 "left join groups as g on i.gid_idx=g.gid_idx "
			 "where node_id='%s' order by r.idx",
			 6, reqp->nodeid);
	if (!res) {
		error("IMAGEKEY: %s: DB Error getting key\n", reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		info("IMAGEKEY: %s: No current reload for this node\n",
		     reqp->nodeid);
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Prior to version 33 there was no extended image info send along
	 * in loadinfo and thus no way to match an image with the
	 * corresponding secure load info. Hence we allow only a single
	 * image in this case and return it in the old format of one field
	 * per line.
	 */
	if (vers < 33) {
		if (nrows > 1) {
			info("IMAGEKEY: %s: client cannot handle multiple images\n",
			     reqp->nodeid);
			mysql_free_result(res);
			return 0;
		}
		row = mysql_fetch_row(res);
		if (row[0])
			bufp += OUTPUT(bufp, bufe - bufp,
				       "UUID=%s\n", row[0]);
		if (row[1])
			bufp += OUTPUT(bufp, bufe - bufp,
				       "SIGKEY=%s\n", row[1]);
		if (row[2])
			bufp += OUTPUT(bufp, bufe - bufp,
				       "ENCKEY=%s\n", row[2]);
		nrows = 0;
	}
	/*
	 * Note: if there is more than one reload, we are only grabbing the
	 * 'most recent' due to the 'order by' clause.
	 */
	while (nrows) {
		row = mysql_fetch_row(res);
		nlen = mysql_fetch_lengths(res);
		if (!row || !nlen) {
			error("IMAGEKEY: %s: no auth/encryption key info\n",
			      reqp->nodeid);
			mysql_free_result(res);
			return 1;
		}
        
		if (!row[3] || !row[3][0] || !row[4] || !row[4][0] ||
		    !row[5] || !row[5][0]) {
			error("IMAGEKEY: %s: missing or incomplete imageinfo\n",
			      reqp->nodeid);
			mysql_free_result(res);
			return 1;
		}

		bufp += OUTPUT(bufp, bufe - bufp,
			       "IMAGEID=%s,%s,%s", row[4], row[5], row[3]);
		if (row[0])
			bufp += OUTPUT(bufp, bufe - bufp,
				       " UUID=%s", row[0]);
		if (row[1])
			bufp += OUTPUT(bufp, bufe - bufp,
				       " SIGKEY=%s", row[1]);
		if (row[2])
			bufp += OUTPUT(bufp, bufe - bufp,
				       " ENCKEY=%s", row[2]);
		bufp += OUTPUT(bufp, bufe - bufp, "\n");

		nrows--;
	}
	client_writeback(sock, buf, strlen(buf), tcp);

        mysql_free_result(res);
        return 0;
}

/*
 * Return creator of experiment. Total hack. Must kill this.
 */
COMMAND_PROTOTYPE(docreator)
{
	char		buf[MYBUFSIZE];

	/* There was a $ anchored CREATOR= pattern in common/config/rc.misc . */
	if (vers<=20)
		OUTPUT(buf, sizeof(buf), "CREATOR=%s\n", reqp->creator);
	else
		OUTPUT(buf, sizeof(buf), "CREATOR=%s SWAPPER=%s\n",
		       reqp->creator, reqp->swapper);

	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("CREATOR: %s", buf);
	return 0;
}

/*
 * Return tunnels info.
 */
COMMAND_PROTOTYPE(dotunnels)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;
	char            *clause = "";

	/*
	 * There is no point in returning tunnel info to the container;
	 * they cannot do anything with it. The host has setup the container
	 * with interfaces that are linked to the tunnels, but within the
	 * container they just look like regular interfaces, and so we return
	 * them from doifconfig. 
	 */
	if (reqp->isvnode && reqp->asvnode) {
		return 0;
	}

	res = mydb_query("select lma.lanid,lma.memberid,"
			 "   lma.attrkey,lma.attrvalue from lans as l "
			 "left join lan_members as lm on lm.lanid=l.lanid "
			 "left join lan_attributes as la on "
			 "     la.lanid=l.lanid and la.attrkey='style' "
			 "left join lan_member_attributes as lma on "
			 "     lma.lanid=lm.lanid and "
			 "     lma.memberid=lm.memberid "
			 "where l.exptidx='%d' and l.type='tunnel' and "
			 "      lm.node_id='%s' and "
			 "      lma.attrkey like 'tunnel_%%' %s",
			 4, reqp->exptidx, reqp->nodeid, clause);

	if (!res) {
		error("TUNNELS: %s: DB Error getting tunnels\n", reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);

		OUTPUT(buf, sizeof(buf),
		       "TUNNEL=%s MEMBER=%s KEY='%s' VALUE='%s'\n",
		       row[0], row[1], row[2], row[3]);
		client_writeback(sock, buf, strlen(buf), tcp);

		nrows--;
		if (verbose)
			info("TUNNEL=%s MEMBER=%s KEY='%s' VALUE='%s'\n",
			     row[0], row[1], row[2], row[3]);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return vnode list for a widearea node.
 */
COMMAND_PROTOTYPE(dovnodelist)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	res = mydb_query("select r.node_id,n.jailflag from reserved as r "
			 "left join nodes as n on r.node_id=n.node_id "
                         "left join node_types as nt on nt.type=n.type "
                         "where nt.isvirtnode=1 and n.phys_nodeid='%s'",
                         2, reqp->nodeid);

	if (!res) {
		error("VNODELIST: %s: DB Error getting vnode list\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);

		if (vers <= 6) {
			OUTPUT(buf, sizeof(buf), "%s\n", row[0]);
		}
		else {
			/* XXX Plab? */
			OUTPUT(buf, sizeof(buf),
			       "VNODEID=%s JAILED=%s\n", row[0], row[1]);
		}
		client_writeback(sock, buf, strlen(buf), tcp);

		nrows--;
		if (verbose)
			info("VNODELIST: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return subnode list, and their types.
 */
COMMAND_PROTOTYPE(dosubnodelist)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	if (vers <= 23)
		return 0;

	res = mydb_query("select n.node_id,nt.class from nodes as n "
                         "left join node_types as nt on nt.type=n.type "
                         "where nt.issubnode=1 and n.phys_nodeid='%s'",
                         2, reqp->nodeid);

	if (!res) {
		error("SUBNODELIST: %s: DB Error getting vnode list\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);

		OUTPUT(buf, sizeof(buf), "NODEID=%s TYPE=%s\n", row[0], row[1]);
		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("SUBNODELIST: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * DB stuff
 */
static MYSQL	db;
static int	db_connected;
static char     db_dbname[DBNAME_SIZE];
static void	mydb_disconnect();

static int
mydb_connect()
{
	/*
	 * Each time we talk to the DB, we check to see if the name
	 * matches the last connection. If so, nothing more needs to
	 * be done. If we switched DBs (checkdbredirect()), then drop
	 * the current connection and form a new one.
	 */
	if (db_connected) {
		if (strcmp(db_dbname, dbname) == 0)
			return 1;
		mydb_disconnect();
	}

	mysql_init(&db);
	if (mysql_real_connect(&db, 0, "tmcd", 0,
			       dbname, 0, 0, CLIENT_INTERACTIVE) == 0) {
		error("%s: connect failed: %s\n", dbname, mysql_error(&db));
		return 0;
	}
	strcpy(db_dbname, dbname);
	db_connected = 1;
	return 1;
}

static void
mydb_disconnect()
{
	mysql_close(&db);
	db_connected = 0;
}

/*
 * Just so we can include bootinfo from the pxe directory.
 */
int	dbinit(void) { return 0;}
void	dbclose(void) {}

MYSQL_RES *
mydb_query(char *query, int ncols, ...)
{
	MYSQL_RES	*res;
	char		querybuf[2*MYBUFSIZE];
	va_list		ap;
	int		n;

	va_start(ap, ncols);
	n = vsnprintf(querybuf, sizeof(querybuf), query, ap);
	va_end(ap);
	if (n >= sizeof(querybuf)) {
		error("query too long for buffer\n");
		return (MYSQL_RES *) 0;
	}

	if (! mydb_connect())
		return (MYSQL_RES *) 0;

	if (mysql_real_query(&db, querybuf, n) != 0) {
		error("%s: query failed: %s, retrying\n",
		      dbname, mysql_error(&db));
		mydb_disconnect();
		/*
		 * Try once to reconnect.  In theory, the caller (client)
		 * will retry the tmcc call and we will reconnect and
		 * everything will be fine.  The problem is that the
		 * client may get a different tmcd process each time,
		 * and every one of those will fail once before
		 * reconnecting.  Hence, the client could wind up failing
		 * even if it retried.
		 */
		if (!mydb_connect() ||
		    mysql_real_query(&db, querybuf, n) != 0) {
			error("%s: query failed: %s\n",
			      dbname, mysql_error(&db));
			return (MYSQL_RES *) 0;
		}
	}

	res = mysql_store_result(&db);
	if (res == 0) {
		error("%s: store_result failed: %s\n",
		      dbname, mysql_error(&db));
		mydb_disconnect();
		return (MYSQL_RES *) 0;
	}

	if (ncols && ncols != (int)mysql_num_fields(res)) {
		error("%s: Wrong number of fields returned "
		      "Wanted %d, Got %d\n",
		      dbname, ncols, (int)mysql_num_fields(res));
		mysql_free_result(res);
		return (MYSQL_RES *) 0;
	}
	return res;
}

int
mydb_update(char *query, ...)
{
	char		querybuf[64 * 1024];
	va_list		ap;
	int		n;

	va_start(ap, query);
	n = vsnprintf(querybuf, sizeof(querybuf), query, ap);
	va_end(ap);
	if (n >= sizeof(querybuf)) {
		error("query too long for buffer\n");
		return 1;
	}

	if (! mydb_connect())
		return 1;

	if (mysql_real_query(&db, querybuf, n) != 0) {
		error("%s: query failed: %s\n", dbname, mysql_error(&db));
		mydb_disconnect();
		return 1;
	}
	return 0;
}

/*
 * Map IP to node ID (plus other info).
 *
 * N.B. This function may be called when a node is not in an experiment.
 * So any fields extracted from the reserved or experiment tables could be
 * NULL. Handle them accordingly!
 */
static int
iptonodeid(struct in_addr ipaddr, tmcdreq_t *reqp, char* nodekey)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;

	/*
	 * I love a good query!
	 *
	 * The join on node_types using control_iface is to prevent the
	 * (unlikely) possibility that we get an experimental interface
	 * trying to contact us! I doubt that can happen though.
	 *
	 * XXX Locally, the jail flag is not set on the phys node, only
	 * on the virtnodes. This is okay since all the routines that
	 * check jailflag also check to see if its a vnode or physnode.
	 */
	/*
	 * Widearea nodes have wanodekeys that should be used to get
	 * the nodeid.
	 */
	if ((nodekey != NULL) && (strlen(nodekey) > 1) && !reqp->isvnode) {
		res = mydb_query("SELECT t.class,t.type,n.node_id,"
				 " n.jailflag,r.pid,r.eid,r.vname, "
				 " e.gid,e.testdb,n.update_accounts, "
				 " n.role,e.expt_head_uid,e.expt_swap_uid, "
				 " e.sync_server,t.class,t.type, "
				 " t.isremotenode,t.issubnode,e.keyhash, "
				 " nk.sfshostid,e.eventkey,0, "
				 " 0, "
				 " e.elab_in_elab,e.elabinelab_singlenet, "
				 " e.idx,e.creator_idx,e.swapper_idx, "
				 " u.admin,dedicated_wa_types.attrvalue "
				 "   AS isdedicated_wa, "
				 " r.genisliver_idx,r.tmcd_redirect, "
				 " r.sharing_mode,e.geniflags,n.uuid, "
				 " n.nonfsmounts,e.nonfsmounts AS enonfs, "
				 " r.erole, n.taint_states, "
				 " n.nfsmounts,e.nfsmounts AS enfsmounts, "
				 " p.nonlocal_id,NULL, "
				 " r.rootkey_private,r.rootkey_public "
				 "FROM nodes AS n "
				 "LEFT JOIN reserved AS r ON "
				 "  r.node_id=n.node_id "
				 "LEFT JOIN experiments AS e ON "
				 " e.pid=r.pid and e.eid=r.eid "
				 "LEFT JOIN projects AS p ON "
				 " p.pid=r.pid "
				 "LEFT JOIN node_types AS t ON "
				 " t.type=n.type "
				 "LEFT JOIN node_hostkeys AS nk ON "
				 " nk.node_id=n.node_id "
				 "LEFT JOIN users AS u ON "
				 " u.uid_idx=e.swapper_idx "
				 "LEFT OUTER JOIN "
				 "  (SELECT type,attrvalue "
				 "    FROM node_type_attributes "
				 "    WHERE attrkey='notmcdinfo' "
				 "      AND attrvalue='1' "
				 "     GROUP BY type) AS notmcdinfo_types "
				 "  ON n.type=notmcdinfo_types.type "
				 "LEFT OUTER JOIN "
				 "  (SELECT type,attrvalue "
				 "   FROM node_type_attributes "
				 "   WHERE attrkey='dedicated_widearea' "
				 "   GROUP BY type) AS dedicated_wa_types "
				 "  ON n.type=dedicated_wa_types.type "
				 "WHERE n.node_id IN "
				 "     (SELECT node_id FROM widearea_nodeinfo "
				 "      WHERE privkey='%s') "
				 "  AND notmcdinfo_types.attrvalue IS NULL",
				 45, nodekey);
	}
	else if (reqp->isvnode) {
		char	clause[BUFSIZ];

		if (reqp->external_key[0]) {
			sprintf(clause,
				"r.external_resource_key is not null and "
				"r.external_resource_key='%s'",
				reqp->external_key);
		}
		else if (nodekey != NULL && strlen(nodekey) > 1) {
			sprintf(clause,
				"(np.node_id IN "
				"     (SELECT node_id FROM widearea_nodeinfo "
				"      WHERE privkey='%s')) ", nodekey);
		}
		else {
			sprintf(clause,
				"(i.IP='%s' and i.role='ctrl') or "
				"nv.jailip='%s'",
				inet_ntoa(ipaddr), inet_ntoa(ipaddr));
		}
		res = mydb_query("select vt.class,vt.type,np.node_id,"
				 " nv.jailflag,r.pid,r.eid,r.vname, "
				 " e.gid,e.testdb,nv.update_accounts, "
				 " np.role,e.expt_head_uid,e.expt_swap_uid, "
				 " e.sync_server,pt.class,pt.type, "
				 " pt.isremotenode,vt.issubnode,e.keyhash, "
				 " nk.sfshostid,e.eventkey,vt.isplabdslice, "
				 " ps.admin, "
				 " e.elab_in_elab,e.elabinelab_singlenet, "
				 " e.idx,e.creator_idx,e.swapper_idx, "
				 " u.admin,null, "
				 " r.genisliver_idx,r.tmcd_redirect, "
				 " r.sharing_mode,e.geniflags,nv.uuid, "
				 " nv.nonfsmounts,e.nonfsmounts AS enonfs, "
				 " r.erole, nv.taint_states, "
				 " nv.nfsmounts,e.nfsmounts AS enfsmounts, "
				 " p.nonlocal_id,va.attrvalue, "
				 " r.rootkey_private,r.rootkey_public "
				 "from nodes as nv "
				 "left join nodes as np on "
				 " np.node_id=nv.phys_nodeid "
				 "left join interfaces as i on "
				 " i.node_id=np.node_id "
				 "left join reserved as r on "
				 " r.node_id=nv.node_id "
				 "left join experiments as e on "
				 "  e.pid=r.pid and e.eid=r.eid "
				 "left join projects AS p ON "
				 " p.pid=r.pid "
				 "left join node_types as pt on "
				 " pt.type=np.type "
				 "left join node_types as vt on "
				 " vt.type=nv.type "
				 "left join plab_slices as ps on "
				 " ps.pid=e.pid and ps.eid=e.eid "
				 "left join node_hostkeys as nk on "
				 " nk.node_id=nv.node_id "
				 "left join users as u on "
				 " u.uid_idx=e.swapper_idx "
				 "left join virt_node_attributes as va on "
				 " va.pid=r.pid and va.eid=r.eid and "
				 " va.vname=r.vname and "
				 " va.attrkey='routable_control_ip' "
				 "where nv.node_id='%s' and (%s)",
				 45, reqp->vnodeid, clause);
	}
	else {
		char	clause[BUFSIZ];

		if (reqp->external_key[0]) {
			sprintf(clause,
				"r.external_resource_key is not null and "
				"r.external_resource_key='%s'",
				reqp->external_key);
		}
		else {
			sprintf(clause,
				"i.IP='%s' and i.role='ctrl'",
				inet_ntoa(ipaddr));
		}
		res = mydb_query("select t.class,t.type,n.node_id,n.jailflag,"
				 " r.pid,r.eid,r.vname,e.gid,e.testdb, "
				 " n.update_accounts,n.role, "
				 " e.expt_head_uid,e.expt_swap_uid, "
				 " e.sync_server,t.class,t.type, "
				 " t.isremotenode,t.issubnode,e.keyhash, "
				 " nk.sfshostid,e.eventkey,0, "
				 " 0,e.elab_in_elab,e.elabinelab_singlenet, "
				 " e.idx,e.creator_idx,e.swapper_idx, "
				 " u.admin,dedicated_wa_types.attrvalue "
				 "   as isdedicated_wa, "
				 " r.genisliver_idx,r.tmcd_redirect, "
				 " r.sharing_mode,e.geniflags,n.uuid, "
				 " n.nonfsmounts,e.nonfsmounts AS enonfs, "
				 " r.erole, n.taint_states, "
				 " n.nfsmounts,e.nfsmounts AS enfsmounts, "
				 " p.nonlocal_id,NULL, "
				 " r.rootkey_private,r.rootkey_public "
				 "from interfaces as i "
				 "left join nodes as n on n.node_id=i.node_id "
				 "left join reserved as r on "
				 "  r.node_id=i.node_id "
				 "left join experiments as e on "
				 " e.pid=r.pid and e.eid=r.eid "
				 "left join projects AS p ON "
				 " p.pid=r.pid "
				 "left join node_types as t on "
				 " t.type=n.type "
				 "left join node_hostkeys as nk on "
				 " nk.node_id=n.node_id "
				 "left join users as u on "
				 " u.uid_idx=e.swapper_idx "
				 "left outer join "
				 "  (select type,attrvalue "
				 "    from node_type_attributes "
				 "    where attrkey='notmcdinfo' "
				 "      and attrvalue='1' "
				 "     group by type) as notmcdinfo_types "
				 "  on n.type=notmcdinfo_types.type "
				 "left outer join "
				 "  (select type,attrvalue "
				 "   from node_type_attributes "
				 "   where attrkey='dedicated_widearea' "
				 "   group by type) as dedicated_wa_types "
				 "  on n.type=dedicated_wa_types.type "
				 "where (%s) "
				 "  and notmcdinfo_types.attrvalue is NULL",
				 45, clause);
	}

	if (!res) {
		error("iptonodeid: %s: DB Error getting interfaces!\n",
		      inet_ntoa(ipaddr));
		return 1;
	}

	if (! (int)mysql_num_rows(res)) {
		mysql_free_result(res);
		return 1;
	}
	row = mysql_fetch_row(res);
	if (!row[0] || !row[1] || !row[2]) {
		error("iptonodeid: %s: Malformed DB response!\n",
		      inet_ntoa(ipaddr));
		mysql_free_result(res);
		return 1;
	}
	reqp->client = ipaddr;
	strncpy(reqp->class,  row[0],  sizeof(reqp->class));
	strncpy(reqp->type,   row[1],  sizeof(reqp->type));
	strncpy(reqp->pclass, row[14], sizeof(reqp->pclass));
	strncpy(reqp->ptype,  row[15], sizeof(reqp->ptype));
	strncpy(reqp->nodeid, row[2],  sizeof(reqp->nodeid));
	strncpy(reqp->nodeuuid, row[34],  sizeof(reqp->nodeuuid));
	if(nodekey != NULL) {
		strncpy(reqp->privkey, nodekey, PRIVKEY_LEN);
	}
	else {
		strcpy(reqp->privkey, "");
	}
	reqp->islocal      = (! strcasecmp(row[16], "0") ? 1 : 0);
	reqp->jailflag     = (! strcasecmp(row[3],  "0") ? 0 : 1);
	reqp->issubnode    = (! strcasecmp(row[17], "0") ? 0 : 1);
	reqp->isplabdslice = (! strcasecmp(row[21], "0") ? 0 : 1);
	reqp->isplabsvc    = (row[22] && strcasecmp(row[22], "0")) ? 1 : 0;
	reqp->elab_in_elab = (row[23] && strcasecmp(row[23], "0")) ? 1 : 0;
	reqp->singlenet    = (row[24] && strcasecmp(row[24], "0")) ? 1 : 0;
	reqp->isdedicatedwa = (row[29] && !strncmp(row[29], "1", 1)) ? 1 : 0;
	reqp->geniflags    = 0;
	reqp->isnonlocal_pid = 0;

	if (row[8])
		strncpy(reqp->testdb, row[8], sizeof(reqp->testdb));
	if (row[4] && row[5]) {
		strncpy(reqp->pid, row[4], sizeof(reqp->pid));
		strncpy(reqp->eid, row[5], sizeof(reqp->eid));
		if (row[25])
			reqp->exptidx = atoi(row[25]);
		else {
			error("iptonodeid: %s: in non-existent experiment %s/%s!\n",
			      inet_ntoa(ipaddr), reqp->pid, reqp->eid);
			mysql_free_result(res);
			return 1;
		}
		reqp->allocated = 1;

		if (row[6])
			strncpy(reqp->nickname, row[6],sizeof(reqp->nickname));
		else
			strcpy(reqp->nickname, reqp->nodeid);

		if (row[11]) 
			strcpy(reqp->creator, row[11]);
		else
			strcpy(reqp->creator, "elabman");
		if (row[26])
			reqp->creator_idx = atoi(row[26]);
		else
			reqp->creator_idx = 0;
		if (row[12]) {
			strcpy(reqp->swapper, row[12]);
			reqp->swapper_idx = atoi(row[27]);
		}
		else {
			strcpy(reqp->swapper, reqp->creator);
			reqp->swapper_idx = reqp->creator_idx;
		}
		if (row[28])
			reqp->swapper_isadmin = atoi(row[28]);
		else
			reqp->swapper_isadmin = 0;

		/*
		 * If there is no gid (yes, thats bad and a mistake), then
		 * copy the pid in. Also warn.
		 */
		if (row[7])
			strncpy(reqp->gid, row[7], sizeof(reqp->gid));
		else {
			strcpy(reqp->gid, reqp->pid);
			error("iptonodeid: %s: No GID for %s/%s (pid/eid)!\n",
			      reqp->nodeid, reqp->pid, reqp->eid);
		}
		/* Sync server for the experiment */
		if (row[13])
			strcpy(reqp->syncserver, row[13]);
		/* keyhash for the experiment */
		if (row[18])
			strcpy(reqp->keyhash, row[18]);
		/* event key for the experiment */
		if (row[20])
			strcpy(reqp->eventkey, row[20]);
		/* geni sliver idx */
		if (row[30])
			reqp->genisliver_idx = atoi(row[30]);
		else
			reqp->genisliver_idx = 0;
		if (row[32])
			strcpy(reqp->sharing_mode, row[32]);
		/* geni flags idx */
		if (row[33])
			reqp->geniflags = atoi(row[33]);
		else
			reqp->geniflags = 0;
		if (row[37])
			strcpy(reqp->erole, row[37]);
		/* nonlocal project flag */
		if (row[41])
			reqp->isnonlocal_pid = 1;
	}

	if (row[9])
		reqp->update_accounts = atoi(row[9]);
	else
		reqp->update_accounts = 0;

	/* SFS hostid for the node */
	if (row[19])
		strcpy(reqp->sfshostid, row[19]);

	reqp->iscontrol = (! strcasecmp(row[10], "ctrlnode") ? 1 : 0);

	/* nfsmounts - per-experiment disable overrides per-node setting */
	if (row[40]) {
		if (strcmp(row[40], "none") == 0)
			strcpy(reqp->nfsmounts, "none");
		else if (row[39])
			strcpy(reqp->nfsmounts, row[39]);
		else
			strcpy(reqp->nfsmounts, row[40]);
	} else {
		strcpy(reqp->nfsmounts, "none");
	}

        /* taintstates - find the strings and set the bits.  */
        reqp->taintstates = 0;
        if (row[38]) {
		char tbuf[BUFSIZ];
		char *tptr, *tok;
		strcpy(tbuf, row[38]);
		tptr = tbuf;
		while ((tok = strsep(&tptr, ",")) != NULL) {
			if (strcmp(tok,"blackbox") == 0) {
				reqp->taintstates |= TB_TAINTSTATE_BLACKBOX;
			} else if (strcmp(tok,"useronly") == 0) {
				reqp->taintstates |= TB_TAINTSTATE_USERONLY;
			} else if (strcmp(tok,"dangerous") == 0) {
				reqp->taintstates |= TB_TAINTSTATE_DANGEROUS;
			} else if (strcmp(tok,"mustreload") == 0) {
				reqp->taintstates |= TB_TAINTSTATE_MUSTRELOAD;
			} else {
				error("iptonodeid: %s: Unknown taintstate: '%s'\n", reqp->nodeid, tok);
			}
		}
	}
	
	/* Do we have a routable IP */
	if (reqp->isvnode && row[42] && strcmp(row[42], "true") == 0)
		reqp->isroutable_vnode = 1;
	else
		reqp->isroutable_vnode = 0;

	/* Which per-experiment root keys should be propogated if any */
	reqp->experiment_keys = TB_ROOTKEYS_NONE;
	if (row[43] && atoi(row[43]) > 0)
		reqp->experiment_keys |= TB_ROOTKEYS_PRIVATE;
	if (row[44] && atoi(row[44]) > 0)
		reqp->experiment_keys |= TB_ROOTKEYS_PUBLIC;

	/* If a vnode, copy into the nodeid. Eventually split this properly */
	strcpy(reqp->pnodeid, reqp->nodeid);
	if (reqp->isvnode) {
		strcpy(reqp->nodeid,  reqp->vnodeid);
	}

	mysql_free_result(res);
	return 0;
}

/*
 * Map nodeid to PID/EID pair.
 */
static int
nodeidtoexp(char *nodeid, char *pid, char *eid, char *gid)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;

	res = mydb_query("select r.pid,r.eid,e.gid from reserved as r "
			 "left join experiments as e on "
			 "     e.pid=r.pid and e.eid=r.eid "
			 "where node_id='%s'",
			 3, nodeid);
	if (!res) {
		error("nodeidtoexp: %s: DB Error getting reserved!\n", nodeid);
		return 1;
	}

	if (! (int)mysql_num_rows(res)) {
		mysql_free_result(res);
		return 1;
	}
	row = mysql_fetch_row(res);
	mysql_free_result(res);
	strncpy(pid, row[0], TBDB_FLEN_PID);
	strncpy(eid, row[1], TBDB_FLEN_EID);

	/*
	 * If there is no gid (yes, thats bad and a mistake), then copy
	 * the pid in. Also warn.
	 */
	if (row[2]) {
		strncpy(gid, row[2], TBDB_FLEN_GID);
	}
	else {
		strcpy(gid, pid);
		error("nodeidtoexp: %s: No GID for %s/%s (pid/eid)!\n",
		      nodeid, pid, eid);
	}

	return 0;
}

/*
 * Check for DBname redirection.
 */
static int
checkdbredirect(tmcdreq_t *reqp)
{
	if (! reqp->allocated || !strlen(reqp->testdb))
		return 0;

	/* This changes the DB we talk to. */
	strcpy(dbname, reqp->testdb);

	/*
	 * Okay, lets test to make sure that DB exists. If not, fall back
	 * on the main DB.
	 */
	if (nodeidtoexp(reqp->nodeid, reqp->pid, reqp->eid, reqp->gid)) {
		error("CHECKDBREDIRECT: %s: %s DB does not exist\n",
		      reqp->nodeid, dbname);
		strcpy(dbname, DEFAULT_DBNAME);
	}
	return 0;
}

#ifdef EVENTSYS
/*
 * Connect to the event system. It's not an error to call this function if
 * already connected. Returns 1 on failure, 0 on sucess.
 */
int
event_connect()
{
#ifdef  TBMAINSITE
	/*
	 * On the Mothership we send a lot of events to stated, so shift
	 * the buffer sizes from the receive side to the send size.
	 */
	event_set_sockbufsizes(1024 * 128, 1024 * 8);
#endif
	
	if (!event_handle) {
		event_handle =
		  event_register("elvin://localhost:" BOSSEVENTPORT, 0);
	}

	if (event_handle) {
		return 0;
	} else {
		error("event_connect: "
		      "Unable to register with event system!\n");
		return 1;
	}
}

/*
 * Send an event to the event system. Automatically connects (registers)
 * if not already done. Returns 0 on sucess, 1 on failure.
 */
int myevent_send(address_tuple_t tuple) {
	event_notification_t notification;

	if (event_connect()) {
		return 1;
	}

	notification = event_notification_alloc(event_handle,tuple);
	if (notification == (event_notification_t) NULL) {
		error("myevent_send: Unable to allocate notification!");
		return 1;
	}

	if (! event_notify(event_handle, notification)) {
		event_notification_free(event_handle, notification);

		error("myevent_send: Unable to send notification!");
		/*
		 * Let's try to disconnect from the event system, so that
		 * we'll reconnect next time around.
		 */
		if (!event_unregister(event_handle)) {
			error("myevent_send: "
			      "Unable to unregister with event system!");
		}
		event_handle = NULL;
		return 1;
	} else {
		event_notification_free(event_handle,notification);
		return 0;
	}
}

/*
 * This is for bootinfo inclusion.
 */
int	bievent_init(void) { return 0; }

int
bievent_send(struct in_addr ipaddr, void *opaque, char *event)
{
	tmcdreq_t		*reqp = (tmcdreq_t *) opaque;
	static address_tuple_t	tuple;

	if (!tuple) {
		tuple = address_tuple_alloc();
		if (tuple == NULL) {
			error("bievent_send: Unable to allocate tuple!\n");
			return -1;
		}
	}
	tuple->host      = BOSSNODE;
	tuple->objtype   = "TBNODESTATE";
	tuple->objname	 = reqp->nodeid;
	tuple->eventtype = event;

	if (myevent_send(tuple)) {
		error("bievent_send: Error sending event\n");
		return -1;
	}
	return 0;
}
#endif /* EVENTSYS */

/*
 * Lets hear it for global state...Yeah!
 */
static char udpbuf[8192];
static int udpfd = -1, udpix;

/*
 * Write back to client
 */
int
client_writeback(int sock, void *buf, int len, int tcp)
{
	int	cc;
	char	*bufp = (char *) buf;

	if (tcp) {
		while (len) {
			if ((cc = WRITE(sock, bufp, len)) <= 0) {
				if (cc < 0) {
					errorc("writing to TCP client");
					return -1;
				}
				error("write to TCP client aborted");
				return -1;
			}
			byteswritten += cc;
			len  -= cc;
			bufp += cc;
		}
	} else {
		if (udpfd != sock) {
			if (udpfd != -1)
				error("UDP reply in progress!?");
			udpfd = sock;
			udpix = 0;
		}
		if (udpix + len > sizeof(udpbuf)) {
			error("client data write truncated");
			len = sizeof(udpbuf) - udpix;
		}
		memcpy(&udpbuf[udpix], bufp, len);
		udpix += len;
	}
	return 0;
}

void
client_writeback_done(int sock, struct sockaddr_in *client)
{
	int err;

	/*
	 * XXX got an error before we wrote anything,
	 * still need to send a reply.
	 */
	if (udpfd == -1)
		udpfd = sock;

	if (sock != udpfd)
		error("UDP reply out of sync!");
	else if (udpix != 0) {
		err = sendto(udpfd, udpbuf, udpix, 0,
			     (struct sockaddr *)client, sizeof(*client));
		if (err < 0)
			errorc("writing to UDP client");
	}
	byteswritten = udpix;
	udpfd = -1;
	udpix = 0;
}

/*
 * IsAlive(). Mark nodes as being alive.
 */
COMMAND_PROTOTYPE(doisalive)
{
	int		doaccounts = 0;
	char		buf[MYBUFSIZE];
#ifdef EVENTSYS
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	address_tuple_t tuple;

	/*
	 * Get current status. We want to send an event if it changes.
	 */
	res = mydb_query("select status from node_status where node_id='%s'",
			 1, reqp->nodeid);
	if (res) {
		if (mysql_num_rows(res)) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0] && strcmp(row[0], "up")) {
				tuple = address_tuple_alloc();
				if (tuple != NULL) {
					tuple->host      = BOSSNODE;
					tuple->objtype   = "TBNODESTATUS";
					tuple->objname	 = reqp->nodeid;
					tuple->eventtype = "up";

					if (myevent_send(tuple)) {
						error("Error sending event\n");
					}
					address_tuple_free(tuple);
				}
			}
		}
		mysql_free_result(res);
	}
#endif /* EVENTSYS */
	/*
	 * See db/node_status script, which uses this info (timestamps)
	 * to determine when nodes are down.
	 */
	mydb_update("replace into node_status "
		    " (node_id, status, status_timestamp) "
		    " values ('%s', 'up', now())",
		    reqp->nodeid);

	/*
	 * Return info about what needs to be updated.
	 */
	if (reqp->update_accounts)
		doaccounts = 1;

	/*
	 * At some point, maybe what we will do is have the client
	 * make a request asking what needs to be updated. Right now,
	 * just return yes/no and let the client assume it knows what
	 * to do (update accounts).
	 */
	OUTPUT(buf, sizeof(buf), "UPDATE=%d\n", doaccounts);
	client_writeback(sock, buf, strlen(buf), tcp);

	return 0;
}

/*
 * Return ipod info for a node
 */
COMMAND_PROTOTYPE(doipodinfo)
{
	char		buf[MYBUFSIZE], hashbuf[32+1];

	if (!tcp) {
		error("IPODINFO: %s: Cannot do this in UDP mode!\n",
		      reqp->nodeid);
		return 1;
	}
	if (getrandomchars(hashbuf, 32)) {
		error("IPODINFO: no random chars for password\n");
		return 1;
	}
	mydb_update("update nodes set ipodhash='%s' "
		    "where node_id='%s'",
		    hashbuf, reqp->nodeid);

	/*
	 * XXX host/mask hardwired to us
	 */
	OUTPUT(buf, sizeof(buf), "HOST=%s MASK=255.255.255.255 HASH=%s\n",
		inet_ntoa(myipaddr), hashbuf);
	client_writeback(sock, buf, strlen(buf), tcp);

	return 0;
}

/*
 * Return ntp config for a node.
 */
COMMAND_PROTOTYPE(dontpinfo)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	if (!tcp) {
		error("NTPINFO: %s: Cannot do this in UDP mode!\n",
		      reqp->nodeid);
		return 1;
	}

	/*
	 * First get the servers and peers.
	 */
	res = mydb_query("select type,IP from ntpinfo where node_id='%s'",
			 2, reqp->nodeid);

	if (!res) {
		error("NTPINFO: %s: DB Error getting ntpinfo!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res))) {
		while (nrows) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0] &&
			    row[1] && row[1][0]) {
				if (!strcmp(row[0], "peer")) {
					OUTPUT(buf, sizeof(buf),
					       "PEER=%s\n", row[1]);
				}
				else {
					OUTPUT(buf, sizeof(buf),
					       "SERVER=%s\n", row[1]);
				}
				client_writeback(sock, buf, strlen(buf), tcp);
				if (verbose)
					info("NTPINFO: %s", buf);
			}
			nrows--;
		}
	}
	else if (reqp->islocal) {
		/*
		 * All local nodes default to a our local ntp server,
		 * which is typically a CNAME to ops.
		 */
		OUTPUT(buf, sizeof(buf), "SERVER=%s.%s\n",
		       NTPCNAME, OURDOMAIN);

		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("NTPINFO: %s", buf);
	}
	mysql_free_result(res);

	/*
	 * Now get the drift.
	 */
	res = mydb_query("select ntpdrift from nodes "
			 "where node_id='%s' and ntpdrift is not null",
			 1, reqp->nodeid);

	if (!res) {
		error("NTPINFO: %s: DB Error getting ntpdrift!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res)) {
		row = mysql_fetch_row(res);
		if (row[0] && row[0][0]) {
			OUTPUT(buf, sizeof(buf), "DRIFT=%s\n", row[0]);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("NTPINFO: %s", buf);
		}
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Upload the current ntp drift for a node.
 */
COMMAND_PROTOTYPE(dontpdrift)
{
	float		drift;

	if (!tcp) {
		error("NTPDRIFT: %s: Cannot do this in UDP mode!\n",
		      reqp->nodeid);
		return 1;
	}
	if (!reqp->islocal) {
		error("NTPDRIFT: %s: remote nodes not allowed!\n",
		      reqp->nodeid);
		return 1;
	}

	/*
	 * Node can be free?
	 */

	if (sscanf(rdata, "%f", &drift) != 1) {
		error("NTPDRIFT: %s: Bad argument\n", reqp->nodeid);
		return 1;
	}
	mydb_update("update nodes set ntpdrift='%f' where node_id='%s'",
		    drift, reqp->nodeid);

	if (verbose)
		info("NTPDRIFT: %f", drift);
	return 0;
}

/*
 * Return the config for a virtual (jailed) node.
 */
COMMAND_PROTOTYPE(dojailconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		jailip[TBDB_FLEN_IP], jailipmask[TBDB_FLEN_IPMASK];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	imstrings_t     imstrings;
	int		low, high, nrows;

	/*
	 * Only vnodes get a jailconfig of course, and only allocated ones.
	 */
	if (!reqp->isvnode) {
		/* Silent error is fine */
		return 0;
	}
	/*
	 * geni nodes get something completely different.
	 */
	if (reqp->genisliver_idx && reqp->jailflag == 0) {
		OUTPUT(bufp, sizeof(buf),
		       "EVENTSERVER=\"event-server.%s\"\n", OURDOMAIN);
		client_writeback(sock, buf, strlen(buf), tcp);
		return 0;
	}
	if (!reqp->jailflag)
		return 0;

	/*
	 * Get the portrange for the experiment. Cons up the other params I
	 * can think of right now.
	 */
	res = mydb_query("select low,high from ipport_ranges "
			 "where pid='%s' and eid='%s'",
			 2, reqp->pid, reqp->eid);

	if (!res) {
		error("JAILCONFIG: %s: DB Error getting config!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		low  = 0;
		high = 0x0000FFFF;
	}
	else {
		row  = mysql_fetch_row(res);
		low  = atoi(row[0]);
		high = atoi(row[1]);
	}
	mysql_free_result(res);

	/*
	 * Now need the sshdport and jailip for this node. The jailip
	 * slot is not deprecated, but there might still exists nodes
	 * created before we switched to creating real interface entries
	 * for jailed nodes.
	 */
	res = mydb_query("select n.sshdport,n.jailip,n.jailipmask,"
			 "       i.IP,i.mask,i.mac "
			 "  from nodes as n "
			 "left join interfaces as i on "
			 "   i.node_id=n.node_id and i.role='ctrl' "
			 "where n.node_id='%s'",
			 6, reqp->nodeid);

	if (!res) {
		error("JAILCONFIG: %s: DB Error getting config!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}
	row   = mysql_fetch_row(res);
	if (row[3]) {
		strcpy(jailip, row[3]);
		strcpy(jailipmask, (row[4] ? row[4] : CONTROL_NETMASK));
	}
	else if (row[1]) {
		strcpy(jailip, row[1]);
		strcpy(jailipmask, (row[2] ? row[2] : JAILIPMASK));
	}
	else
		jailip[0] = '\0';

	bzero(buf, sizeof(buf));
	if (jailip[0]) {
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "JAILIP=\"%s,%s\"\n", jailip, jailipmask);
	}
	if (row[5] && strcmp(row[5], "000000000000")) {
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "CTRLMAC=\"%s\"\n", row[5]);
	}
	bufp += OUTPUT(bufp, ebufp - bufp,
		       "PORTRANGE=\"%d,%d\"\n"
		       "SSHDPORT=%d\n"
		       "SYSVIPC=1\n"
		       "INETRAW=1\n"
		       "BPFRO=1\n"
		       "INADDRANY=1\n"
		       "IPFW=1\n"
		       "IPDIVERT=1\n"
		       "ROUTING=%d\n"
		       "DEVMEM=%d\n"
		       "ELABINELAB=%d\n"
		       "EVENTSERVER=\"event-server.%s\"\n",
		       low, high, atoi(row[0]), reqp->islocal, reqp->islocal,
		       reqp->elab_in_elab, OURDOMAIN);

	client_writeback(sock, buf, strlen(buf), tcp);
	mysql_free_result(res);

	/*
	 * See if a per-node-type vnode disk size is specified, which
	 * can be overridden by a per-node disk size. 
	 */
	res = mydb_query("select nta.attrvalue,na.attrvalue from nodes as n "
			 "left join node_type_attributes as nta on "
			 "     nta.type=n.type and "
			 "     nta.attrkey='virtnode_disksize' "
			 "left join node_attributes as na on "
			 "     na.node_id=n.node_id and "
			 "     na.attrkey='virtnode_disksize' "
			 "where n.node_id='%s'",
			 2, reqp->pnodeid);
	
	if (res) {
		if ((int)mysql_num_rows(res) != 0) {
			char *attrvalue = NULL;
			
			row = mysql_fetch_row(res);

			if (row[0] && row[0][0])
				attrvalue = row[0];
			else if (row[1] && row[1][0]) {
				attrvalue = row[1];
			}
			
			if (attrvalue) {
				bufp = buf;
				bufp += OUTPUT(bufp, ebufp - bufp,
					       "VDSIZE=%s\n", attrvalue);
				client_writeback(sock, buf, strlen(buf), tcp);
			}
		}
		mysql_free_result(res);
	}

	/*
	 * Per jail root password hash if one has been set.
	 */
	res = mydb_query("select attrvalue from node_attributes "
			 " where node_id='%s' and "
			 "       attrkey='root_password'",
			 1, reqp->nodeid);
	
	if (!res) {
		error("JAILCONFIG: %s: DB Error getting root_password.\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res))) {
		row = mysql_fetch_row(res);
		if (row[0] && row[0][0]) {
			char saltbuf[8+1], *bp;

			if (getrandomchars(saltbuf, 8) != 0) {
				snprintf(saltbuf, sizeof(saltbuf),
					 "%lu", (unsigned long)time(NULL));
			}
			sprintf(buf, "$1$%s", saltbuf);
			bp = crypt(row[0], buf);

			bufp  = buf;
			bufp += OUTPUT(bufp, ebufp - bufp, "ROOTHASH=%s\n", bp);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
	}
	mysql_free_result(res);

	/*
	 * Now return the IP interface list that this jail has access to.
	 * These are tunnels or ip aliases on the real interfaces, but
	 * its easier just to consult the virt_lans table for all the
	 * ip addresses for this vnode.
	 */
	bufp  = buf;
	bufp += OUTPUT(bufp, ebufp - bufp, "IPADDRS=\"");

	res = mydb_query("select ip from virt_lans "
			 "where vnode='%s' and pid='%s' and eid='%s'",
			 1, reqp->nickname, reqp->pid, reqp->eid);

	if (!res) {
		error("JAILCONFIG: %s: DB Error getting virt_lans table\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res))) {
		while (nrows) {
			nrows--;
			row = mysql_fetch_row(res);

			if (row[0] && row[0][0]) {
				bufp += OUTPUT(bufp, ebufp - bufp, "%s", row[0]);
				if (nrows)
					bufp += OUTPUT(bufp, ebufp - bufp, ",");

			}
		}
	}
	mysql_free_result(res);
	bufp += OUTPUT(bufp, ebufp - bufp, "\"\n");

	/*
	 * Get the image to be booted. 
	 */
	if (get_imagestrings(reqp, &imstrings) == 0) {
		bufp += OUTPUT(bufp, ebufp - bufp, "IMAGENAME=\"%s,%s,%s", 
			       imstrings.pid, imstrings.gid, imstrings.name);
		/*
		 * older mkvnode could not handle :version, and to be
		 * backwards compatable with existing nodes, we do not
		 * return a :0 version.
		 */
		if (vers >= 39 && WITHPROVENANCE) {
			bufp += OUTPUT(bufp, ebufp - bufp, ":%s", 
				       imstrings.version);
		}
		bufp += OUTPUT(bufp, ebufp - bufp, "\"\n");
		if (imstrings.path) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       "IMAGEPATH=\"%s\"\n", 
				       imstrings.path);
		}
		free_imagestrings_content(&imstrings);
	}
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

COMMAND_PROTOTYPE(doimageid)
{
	imstrings_t imstrings;
	char        buf[BUFSIZ];

	if (get_imagestrings(reqp, &imstrings) == 0) {
		OUTPUT(buf, sizeof(buf), 
		       "PID='%s' GID='%s' NAME='%s' VERSION='%s'\n", 
		       imstrings.pid, imstrings.gid, 
		       imstrings.name, imstrings.version);
		client_writeback(sock, buf, strlen(buf), tcp);
		free_imagestrings_content(&imstrings);
	}

	return 0;
}

int get_imagestrings(tmcdreq_t *reqp, imstrings_t *imstrings)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int             retval = 1;

	/* Sanity. */
	if (imstrings == NULL) {
		error("get_imagestrings: NULL pointer argument!\n");
		return 1;
	}

	/* We want data on the default OS set for this node. */
	res = mydb_query("select p.pid,g.gid,iv.imagename,iv.version,"
			 " iv.format,iv.path "
			 "  from nodes as n "
			 "left join `partitions` as pa on "
			 "     pa.node_id=n.node_id and "
			 "     pa.osid=n.def_boot_osid "
			 "left join image_versions as iv on "
			 "     iv.imageid=pa.imageid and "
			 "     iv.version=pa.imageid_version "
			 "left join projects as p on iv.pid_idx=p.pid_idx "
			 "left join groups as g on iv.gid_idx=g.gid_idx "
			 "where n.node_id='%s'",
			 6, reqp->nodeid);

	if (!res) {
		error("get_imagestrings: %s: DB Error getting image info!\n",
		       reqp->nodeid);
		return 1;
	}

	/* Fill out the imstrings struct passed in with info from the DB. */
	if (mysql_num_rows(res)) {
		row = mysql_fetch_row(res);
		if (!row[0] || !row[1] || !row[2] || !row[3]) {
			error("get_imagestrings: %s: invalid data returned "
			      "from DB query!\n", reqp->nodeid);
			return 1;
		}
		strncpy(imstrings->pid, row[0], sizeof(imstrings->pid));
		strncpy(imstrings->gid, row[1], sizeof(imstrings->gid));
		strncpy(imstrings->name, row[2], sizeof(imstrings->name));
		strncpy(imstrings->version, row[3], sizeof(imstrings->version));
		if (row[4] && row[4][0] && strcmp("docker",row[4]) == 0
		    && row[5] && row[5][0]) {
			imstrings->path = strdup(row[5]);
		}
		else {
			imstrings->path = NULL;
		}

		if (debug) {
			info("get_imagestrings: %s: PID=%s GID=%s NAME=%s "
			     "VERSION=%s",
			     reqp->nodeid, imstrings->pid, imstrings->gid, 
			     imstrings->name, imstrings->version);
			if (imstrings->path)
				info("get_imagestrings: %s: IMAGEPATH=%s",
				     reqp->nodeid, imstrings->path);
		}
		retval = 0;
	} else {
		error("get_imagestrings: %s: No info returned for image "
		     "running on this node!", reqp->nodeid);
		retval = 1;
	}

	mysql_free_result(res);
	return retval;
}

void free_imagestrings_content(imstrings_t *imstrings)
{
	/* Sanity. */
	if (imstrings == NULL) {
		error("free_imagestrings_content: NULL pointer argument!\n");
	}
	if (imstrings->path) {
		free(imstrings->path);
		imstrings->path = NULL;
	}
}

/*
 * Return the config for a virtual Plab node.
 */
COMMAND_PROTOTYPE(doplabconfig)
{
	MYSQL_RES	*res, *res2;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
        char            *bufp = buf, *ebufp = &buf[MYBUFSIZE];

	if (!reqp->isplabdslice) {
		/* Silent error is fine */
		return 0;
	}
	/* XXX Check for Plab-ness */

	/*
	 * Now need the sshdport for this node.
	 */
	res = mydb_query("select n.sshdport, ps.admin, i.IP "
                         " from reserved as r "
                         " left join nodes as n "
                         "  on n.node_id=r.node_id "
                         " left join interfaces as i "
                         "  on n.phys_nodeid=i.node_id "
                         " left join plab_slices as ps "
                         "  on r.pid=ps.pid and r.eid=ps.eid "
                         " where i.role='ctrl' and r.node_id='%s'",
			 3, reqp->nodeid);

        /*
         * .. And the elvind port.
         */
        res2 = mydb_query("select attrvalue from node_attributes "
                          " where node_id='%s' and attrkey='elvind_port'",
                          1, reqp->pnodeid);

	if (!res || !res2) {
		error("PLABCONFIG: %s: DB Error getting config!\n",
		      reqp->nodeid);
                if (res) {
                    mysql_free_result(res);
                }
                if (res2) {
                    mysql_free_result(res2);
                }
		return 1;
	}

        /* Add the sshd port (if any) to the output */
        if ((int)mysql_num_rows(res) > 0) {
            row = mysql_fetch_row(res);
            bufp += OUTPUT(bufp, ebufp-bufp,
                           "SSHDPORT=%d SVCSLICE=%d IPADDR=%s ",
                           atoi(row[0]), atoi(row[1]), row[2]);
        }
        mysql_free_result(res);

        /* Add the elvind port to the output */
        if ((int)mysql_num_rows(res2) > 0) {
            row = mysql_fetch_row(res2);
            bufp += OUTPUT(bufp, ebufp-bufp, "ELVIND_PORT=%d ",
                           atoi(row[0]));
        }
        else {
            /*
             * XXX: should not hardwire port number here, but what should
             *      I reference for it?
             */
             bufp += OUTPUT(bufp, ebufp-bufp, "ELVIND_PORT=%d ", 2917);
        }
        mysql_free_result(res2);

        OUTPUT(bufp, ebufp-bufp, "\n");
        client_writeback(sock, buf, strlen(buf), tcp);

	/* XXX Anything else? */

	return 0;
}

/*
 * Return the config for a subnode (this is returned to the physnode).
 */
COMMAND_PROTOTYPE(dosubconfig)
{
	if (vers <= 23)
		return 0;

	if (!reqp->issubnode) {
		error("SUBCONFIG: %s: Not a subnode\n", reqp->nodeid);
		return 1;
	}

	if (! strcmp(reqp->type, "ixp-bv"))
		return(doixpconfig(sock, reqp, rdata, tcp, vers));

	if (! strcmp(reqp->type, "mica2"))
		return(dorelayconfig(sock, reqp, rdata, tcp, vers));

	error("SUBCONFIG: %s: Invalid subnode class %s\n",
	      reqp->nodeid, reqp->class);
	return 1;
}

COMMAND_PROTOTYPE(doixpconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	struct in_addr  mask_addr, bcast_addr;
	char		bcast_ip[16];

	/*
	 * Get the "control" net address for the IXP from the interfaces
	 * table. This is really a virtual pci/eth interface.
	 */
	res = mydb_query("select i1.IP,i1.iface,i2.iface,i2.mask,i2.IP "
			 " from nodes as n "
			 "left join interfaces as i1 on i1.node_id=n.node_id "
			 "     and i1.role='ctrl' "
			 "left join interfaces as i2 on i2.node_id='%s' "
			 "     and i2.iface=i1.iface "
			 "where n.node_id='%s'",
			 5, reqp->pnodeid, reqp->nodeid);

	if (!res) {
		error("IXPCONFIG: %s: DB Error getting config!\n",
		      reqp->nodeid);
		return 1;
	}
	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}
	row   = mysql_fetch_row(res);
	if (!row[1]) {
		error("IXPCONFIG: %s: No IXP interface!\n", reqp->nodeid);
		return 1;
	}
	if (!row[2]) {
		error("IXPCONFIG: %s: No host interface!\n", reqp->nodeid);
		return 1;
	}
	if (!row[3]) {
		error("IXPCONFIG: %s: No mask!\n", reqp->nodeid);
		return 1;
	}
	inet_aton(CHECKMASK(row[3]), &mask_addr);
	inet_aton(row[0], &bcast_addr);

	bcast_addr.s_addr = (bcast_addr.s_addr & mask_addr.s_addr) |
		(~mask_addr.s_addr);
	strcpy(bcast_ip, inet_ntoa(bcast_addr));

	OUTPUT(buf, sizeof(buf),
	       "IXP_IP=\"%s\"\n"
	       "IXP_IFACE=\"%s\"\n"
	       "IXP_BCAST=\"%s\"\n"
	       "IXP_HOSTNAME=\"%s\"\n"
	       "HOST_IP=\"%s\"\n"
	       "HOST_IFACE=\"%s\"\n"
	       "NETMASK=\"%s\"\n",
	       row[0], row[1], bcast_ip, reqp->nickname,
	       row[4], row[2], row[3]);

	client_writeback(sock, buf, strlen(buf), tcp);
	mysql_free_result(res);
	return 0;
}

/*
 * return slothd params - just compiled in for now.
 */
COMMAND_PROTOTYPE(doslothdparams)
{
	char buf[MYBUFSIZE];

	OUTPUT(buf, sizeof(buf), "%s\n", SDPARAMS);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return program agent info.
 */
COMMAND_PROTOTYPE(doprogagents)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	/* Short-circuit program agents for nodes tainted with 'blackbox'.*/
	if (HAS_TAINT(reqp->taintstates, TB_TAINTSTATE_BLACKBOX))
		return 0;

	res = mydb_query("select vname,command,dir,timeout,expected_exit_code "
			 "from virt_programs "
			 "where vnode='%s' and pid='%s' and eid='%s'",
			 5, reqp->nickname, reqp->pid, reqp->eid);

	if (!res) {
		error("PROGRAM: %s: DB Error getting virt_agents\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	/*
	 * First spit out the UID, then the agents one to a line.
	 */
	OUTPUT(buf, sizeof(buf), "UID=%s\n", reqp->swapper);
	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("PROGAGENTS: %s", buf);

	while (nrows) {
		char	*bufp = buf, *ebufp = &buf[sizeof(buf)];

		row = mysql_fetch_row(res);

		bufp += OUTPUT(bufp, ebufp - bufp, "AGENT=%s", row[0]);
		if (vers >= 23) {
			if (row[2] && strlen(row[2]) > 0)
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " DIR=%s", row[2]);
			if (row[3] && strlen(row[3]) > 0)
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " TIMEOUT=%s", row[3]);
			if (row[4] && strlen(row[4]) > 0)
				bufp += OUTPUT(bufp, ebufp - bufp,
					       " EXPECTED_EXIT_CODE=%s",
					       row[4]);
		}
		if (vers >= 13)
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " COMMAND='%s'", row[1]);
		OUTPUT(bufp, ebufp - bufp, "\n");
		client_writeback(sock, buf, strlen(buf), tcp);

		nrows--;
		if (verbose)
			info("PROGAGENTS: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return sync server info.
 */
COMMAND_PROTOTYPE(dosyncserver)
{
	char		buf[MYBUFSIZE];

	if (!strlen(reqp->syncserver))
		return 0;

	OUTPUT(buf, sizeof(buf),
	       "SYNCSERVER SERVER='%s.%s.%s.%s' ISSERVER=%d\n",
	       reqp->syncserver,
	       reqp->eid, reqp->pid, OURDOMAIN,
	       (strcmp(reqp->syncserver, reqp->nickname) ? 0 : 1));
	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("%s", buf);

	return 0;
}

/*
 * Return keyhash info
 */
COMMAND_PROTOTYPE(dokeyhash)
{
	char		buf[MYBUFSIZE];

	if (!strlen(reqp->keyhash))
		return 0;

	OUTPUT(buf, sizeof(buf), "KEYHASH HASH='%s'\n", reqp->keyhash);
	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("%s", buf);

	return 0;
}

/*
 * Return eventkey info
 */
COMMAND_PROTOTYPE(doeventkey)
{
	char		buf[MYBUFSIZE];

	if (!strlen(reqp->eventkey))
		return 0;

	OUTPUT(buf, sizeof(buf), "EVENTKEY KEY='%s'\n", reqp->eventkey);
	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("%s", buf);

	return 0;
}

/*
 * Return routing stuff for all vnodes mapped to the requesting physnode
 */
COMMAND_PROTOTYPE(doroutelist)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		n, nrows;

	/*
	 * Get the routing type from the nodes table.
	 */
	res = mydb_query("select routertype from nodes where node_id='%s'",
			 1, reqp->nodeid);

	if (!res) {
		error("ROUTES: %s: DB Error getting router type!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/*
	 * Return type. At some point we might have to return a list of
	 * routes too, if we support static routes specified by the user
	 * in the NS file.
	 */
	row = mysql_fetch_row(res);
	if (! row[0] || !row[0][0]) {
		mysql_free_result(res);
		return 0;
	}
	sprintf(buf, "ROUTERTYPE=%s\n", row[0]);
	mysql_free_result(res);

	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("ROUTES: %s", buf);

	/*
	 * Get the routing type from the nodes table.
	 */
	res = mydb_query("select vr.vname,src,dst,dst_type,dst_mask,nexthop,cost "
			 "from virt_routes as vr "
			 "left join v2pmap as v2p "
			 "using (pid,eid,vname) "
			 "where vr.pid='%s' and "
			 " vr.eid='%s' and v2p.node_id='%s'",
			 7, reqp->pid, reqp->eid, reqp->nodeid);

	if (!res) {
		error("ROUTELIST: %s: DB Error getting manual routes!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	n = nrows;

	while (n) {
		char dstip[32];

		row = mysql_fetch_row(res);

		/*
		 * OMG, the Linux route command is too stupid to accept a
		 * host-on-a-subnet as the subnet address, so we gotta mask
		 * off the bits manually for network routes.
		 *
		 * Eventually we'll perform this operation in the NS parser
		 * so it appears in the DB correctly.
		 */
		if (strcmp(row[3], "net") == 0) {
			struct in_addr tip, tmask;

			inet_aton(row[2], &tip);
			inet_aton(row[4], &tmask);
			tip.s_addr &= tmask.s_addr;
			strncpy(dstip, inet_ntoa(tip), sizeof(dstip));
		} else
			strncpy(dstip, row[2], sizeof(dstip));

		sprintf(buf, "ROUTE NODE=%s SRC=%s DEST=%s DESTTYPE=%s DESTMASK=%s "
			"NEXTHOP=%s COST=%s\n",
			row[0], row[1], dstip, row[3], row[4], row[5], row[6]);

		client_writeback(sock, buf, strlen(buf), tcp);

		n--;
	}
	mysql_free_result(res);
	if (verbose)
	    info("ROUTES: %d routes in list\n", nrows);

	return 0;
}

/*
 * Return routing stuff for all vnodes mapped to the requesting physnode
 */
COMMAND_PROTOTYPE(dorole)
{
	char		buf[MYBUFSIZE];

	if (! reqp->allocated) {
		return 0;
	}
	sprintf(buf, "%s\n", reqp->erole);

	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("ROLE: %s", buf);

	return 0;
}

/*
 * Return entire config.
 */
COMMAND_PROTOTYPE(dofullconfig)
{
	char		buf[MYBUFSIZE];
	int		i;
	int		mask;

	if (reqp->isvnode)
		mask = FULLCONFIG_VIRT;
	else
		mask = FULLCONFIG_PHYS;

	for (i = 0; i < numcommands; i++) {
		if (command_array[i].fullconfig & mask) {
			if (tcp && !isssl && !reqp->islocal &&
			    (command_array[i].flags & F_REMREQSSL) != 0) {
				/*
				 * Silently drop commands that are not
				 * allowed for remote non-ssl connections.
				 */
				continue;
			}
			/*
			 * Silently drop all TPM-required commands right now.
			 */
			if ((command_array[i].flags & F_REQTPM)) {
				continue;
			}
			OUTPUT(buf, sizeof(buf),
			       "*** %s\n", command_array[i].cmdname);
			client_writeback(sock, buf, strlen(buf), tcp);
			command_array[i].func(sock, reqp, rdata, tcp, vers);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
	}
	return 0;
}

/*
 * Report node resource usage. This also serves as an isalive(),
 * so we send back update info. The format for upload is:
 *
 *  LA1=x.y LA5=x.y LA15=x.y DUSED=x ...
 */
COMMAND_PROTOTYPE(dorusage)
{
	char		buf[MYBUFSIZE];
	float		la1, la5, la15, dused;
        int             plfd;
        struct timeval  now;
        struct tm       *tmnow;
        char            pllogfname[MAXPATHLEN];
        char            timebuf[10];

	if (sscanf(rdata, "LA1=%f LA5=%f LA15=%f DUSED=%f",
		   &la1, &la5, &la15, &dused) != 4) {
		strncpy(buf, rdata, 64);
		error("RUSAGE: %s: Bad arguments: %s...\n", reqp->nodeid, buf);
		return 1;
	}

	/*
	 * See db/node_status script, which uses this info (timestamps)
	 * to determine when nodes are down.
	 *
	 * XXX: Plab physnode status is reported from the management slice.
         *
	 */
	mydb_update("replace into node_rusage "
		    " (node_id, status_timestamp, "
		    "  load_1min, load_5min, load_15min, disk_used) "
		    " values ('%s', now(), %f, %f, %f, %f)",
		    reqp->nodeid, la1, la5, la15, dused);

	if (reqp->isplabdslice) {
		mydb_update("replace into node_status "
			    " (node_id, status, status_timestamp) "
			    " values ('%s', 'up', now())",
			    reqp->pnodeid);

		mydb_update("replace into node_status "
			    " (node_id, status, status_timestamp) "
			    " values ('%s', 'up', now())",
			    reqp->vnodeid);
        }

	/*
	 * At some point, maybe what we will do is have the client
	 * make a request asking what needs to be updated. Right now,
	 * just return yes/no and let the client assume it knows what
	 * to do (update accounts).
	 */
	OUTPUT(buf, sizeof(buf), "UPDATE=%d\n", reqp->update_accounts);
	client_writeback(sock, buf, strlen(buf), tcp);

        /* We're going to store plab up/down data in a file for a while. */
        if (reqp->isplabsvc) {
            gettimeofday(&now, NULL);
            tmnow = localtime((time_t *)&now.tv_sec);
            strftime(timebuf, sizeof(timebuf), "%Y%m%d", tmnow);
            snprintf(pllogfname, sizeof(pllogfname),
                     "%s/%s-isalive-%s",
                     PLISALIVELOGDIR,
                     reqp->pnodeid,
                     timebuf);

            snprintf(buf, sizeof(buf), "%ld %ld\n",
                     (long)now.tv_sec, (long)now.tv_usec);
            plfd = open(pllogfname, O_WRONLY|O_APPEND|O_CREAT,
                        S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
            if (plfd < 0) {
                errorc("Can't open log: %s", pllogfname);
            } else {
                write(plfd, buf, strlen(buf));
                close(plfd);
            }
        }

	return 0;
}

/*
 * Report time intervals to use in the watchdog process.  All times in
 * seconds (0 means never, -1 means no value is available in the DB):
 *
 *	INTERVAL=	how often to check for new intervals
 *	ISALIVE=	how often to report isalive info
 *			(note that also controls how often new accounts
 *			 are noticed)
 *	NTPDRIFT=	how often to report NTP drift values
 *	CVSUP=		how often to check for software updates
 *	RUSAGE=		how often to collect/report resource usage info
 */
COMMAND_PROTOTYPE(dodoginfo)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE], *bp;
	int		nrows, *iv;
	int		iv_interval, iv_isalive, iv_ntpdrift, iv_cvsup;
	int		iv_rusage, iv_hkeys, iv_dhcpdconf, iv_rootpswd;

	/*
	 * XXX sitevar fetching should be a library function
	 */
	res = mydb_query("select name,value,defaultvalue from "
			 "sitevariables where name like 'watchdog/%%'", 3);
	if (!res || (nrows = (int)mysql_num_rows(res)) == 0) {
		error("WATCHDOGINFO: no watchdog sitevars\n");
		if (res)
			mysql_free_result(res);
		return 1;
	}

	iv_interval = iv_isalive = iv_ntpdrift = iv_cvsup =
		iv_rusage = iv_hkeys = iv_dhcpdconf = -1;
#ifdef DYNAMICROOTPASSWORDS
	iv_rootpswd = 60;
#else
	iv_rootpswd = 0;
#endif
	while (nrows) {
		iv = 0;
		row = mysql_fetch_row(res);
		if (strcmp(row[0], "watchdog/interval") == 0) {
			iv = &iv_interval;
		} else if (strcmp(row[0], "watchdog/ntpdrift") == 0) {
			iv = &iv_ntpdrift;
		} else if (strcmp(row[0], "watchdog/cvsup") == 0) {
			iv = &iv_cvsup;
		} else if (strcmp(row[0], "watchdog/rusage") == 0) {
			iv = &iv_rusage;
		} else if (strcmp(row[0], "watchdog/hostkeys") == 0) {
			iv = &iv_hkeys;
		} else if (strcmp(row[0], "watchdog/dhcpdconf") == 0) {
			iv = &iv_dhcpdconf;
		} else if (strcmp(row[0], "watchdog/rootpswd") == 0) {
			iv = &iv_rootpswd;
		} else if (strcmp(row[0], "watchdog/isalive/local") == 0) {
			if (reqp->islocal && !reqp->isvnode)
				iv = &iv_isalive;
		} else if (strcmp(row[0], "watchdog/isalive/vnode") == 0) {
			if (reqp->islocal && reqp->isvnode)
				iv = &iv_isalive;
		} else if (strcmp(row[0], "watchdog/isalive/plab") == 0) {
			if (!reqp->islocal && reqp->isplabdslice)
				iv = &iv_isalive;
		} else if (strcmp(row[0], "watchdog/isalive/wa") == 0) {
			if (!reqp->islocal && !reqp->isplabdslice)
				iv = &iv_isalive;
		}

		if (iv) {
			/* use the current value if set */
			if (row[1] && row[1][0])
				*iv = atoi(row[1]) * 60;
			/* else check for default value */
			else if (row[2] && row[2][0])
				*iv = atoi(row[2]) * 60;
			/* XXX backward compat: use compiled in default */
			else if (*iv >= 0)
				*iv *= 60;
			else
				error("WATCHDOGINFO: sitevar %s not set\n",
				      row[0]);
		}
		nrows--;
	}
	mysql_free_result(res);

	/*
	 * XXX adjust for local policy
	 * - vnodes and plab nodes do not send NTP drift or cvsup
	 * - vnodes do not report host keys
	 * - widearea nodes do not record drift
	 * - local nodes do not cvsup
	 * - only a plab node service slice reports rusage
	 *   (which it uses in place of isalive)
	 * - only enforce root password reset if DYNAMICROOTPASSWORDS
	 *   is defined (handled above)
	 */
	if ((reqp->islocal && reqp->isvnode) || reqp->isplabdslice) {
		iv_ntpdrift = iv_cvsup = 0;
		if (!reqp->isplabdslice)
			iv_hkeys = 0;
	}
	if (!reqp->islocal)
		iv_ntpdrift = 0;
	else
		iv_cvsup = 0;
	if (reqp->isplabsvc)
		iv_isalive = 0;
	else if (reqp->sharing_mode[0] && !reqp->isvnode)
		iv_rusage = 60;

	bp = buf;
	bp += OUTPUT(bp, sizeof(buf),
		     "INTERVAL=%d ISALIVE=%d NTPDRIFT=%d CVSUP=%d "
		     "RUSAGE=%d HOSTKEYS=%d DHCPDCONF=%d",
		     iv_interval, iv_isalive, iv_ntpdrift, iv_cvsup,
		     iv_rusage, iv_hkeys, iv_dhcpdconf);
	if (vers >= 29)
		OUTPUT(bp, sizeof(buf) - (bp - buf), " SETROOTPSWD=%d\n",
		       iv_rootpswd);
	else
		OUTPUT(bp, sizeof(buf) - (bp - buf), "\n");

	client_writeback(sock, buf, strlen(buf), tcp);

	if (verbose)
		info("%s", buf);

	return 0;
}

/*
 * Stash info returned by the host into the DB
 * Right now we only recognize CDVERSION=<str> for CD booted systems.
 */
COMMAND_PROTOTYPE(dohostinfo)
{
	char		*bp, buf[MYBUFSIZE];

	bp = rdata;
	if (sscanf(bp, "CDVERSION=%31[a-zA-Z0-9-]", buf) == 1) {
		if (verbose)
			info("HOSTINFO CDVERSION=%s\n", buf);
		if (mydb_update("update nodes set cd_version='%s' "
				"where node_id='%s'",
				buf, reqp->nodeid)) {
			error("HOSTINFO: %s: DB update failed\n", reqp->nodeid);
			return 1;
		}
	}
	return 0;
}

/*
 * XXX Stash ssh host keys into the DB.
 */
COMMAND_PROTOTYPE(dohostkeys)
{
#define MAXKEY		4096
#define RSAV1_STR	"SSH_HOST_KEY='"
#define RSAV2_STR	"SSH_HOST_RSA_KEY='"
#define DSAV2_STR	"SSH_HOST_DSA_KEY='"

	char	*bp, rsav1[2*MAXKEY], rsav2[2*MAXKEY], dsav2[2*MAXKEY];
	char	buf[MAXKEY];

#if 0
	if (verbose)
		info("%d bytes: %s\n", strlen(rdata), rdata);
#endif

	/*
	 * The maximum key length we accept is 1024 bytes, but after we
	 * run it through mysql_escape_string() it could potentially double
	 * in size (although that is very unlikely).
	 */
	rsav1[0] = rsav2[0] = dsav2[0] = 0;

	/*
	 * Sheesh, perl string matching would be so much easier!
	 */
	bp = rdata;
	while (*bp) {
		char	*ep, *kp, *thiskey = (char *) NULL;

		while (*bp == ' ')
			bp++;
		if (! *bp)
			break;

		if (! strncasecmp(bp, RSAV1_STR, strlen(RSAV1_STR))) {
			thiskey = rsav1;
			bp += strlen(RSAV1_STR);
		}
		else if (! strncasecmp(bp, RSAV2_STR, strlen(RSAV2_STR))) {
			thiskey = rsav2;
			bp += strlen(RSAV2_STR);
		}
		else if (! strncasecmp(bp, DSAV2_STR, strlen(DSAV2_STR))) {
			thiskey = dsav2;
			bp += strlen(DSAV2_STR);
		}
		else {
			error("HOSTKEYS: %s: "
			      "Unrecognized key type '%.8s ...'\n",
			      reqp->nodeid, bp);
			if (verbose)
				error("HOSTKEYS: %s\n", rdata);
			return 1;
		}
		kp = buf;
		ep = &buf[sizeof(buf) - 1];

		/* Copy the part between the single quotes to the holding buf */
		while (*bp && *bp != '\'' && kp < ep)
			*kp++ = *bp++;
		if (*bp != '\'') {
			error("HOSTKEYS: %s: %s key data too long!\n",
			      reqp->nodeid,
			      thiskey == rsav1 ? "RSA v1" :
			      (thiskey == rsav2 ? "RSA v2" : "DSA v2"));
			if (verbose)
				error("HOSTKEYS: %s\n", rdata);
			return 1;
		}
		bp++;
		*kp = '\0';

		/* Okay, turn into something for mysql statement. */
		thiskey[0] = '\'';
		mysql_escape_string(&thiskey[1], buf, strlen(buf));
		strcat(thiskey, "'");
	}
	if (mydb_update("update node_hostkeys set "
			"       sshrsa_v1=%s,sshrsa_v2=%s,sshdsa_v2=%s "
			"where node_id='%s'",
			(rsav1[0] ? rsav1 : "NULL"),
			(rsav2[0] ? rsav2 : "NULL"),
			(dsav2[0] ? dsav2 : "NULL"),
			reqp->nodeid)) {
		error("HOSTKEYS: %s: setting hostkeys!\n", reqp->nodeid);
		return 1;
	}
	if (verbose) {
		/* XXX print them separately since "info" buffer is 1K */
		info("sshrsa_v1=%s\n", (rsav1[0] ? rsav1 : "NULL"));
		info("sshrsa_v2=%s\n", (rsav2[0] ? rsav2 : "NULL"));
		info("sshdsa_v2=%s\n", (dsav2[0] ? dsav2 : "NULL"));
	}
	return 0;
}

COMMAND_PROTOTYPE(dofwinfo)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		fwname[TBDB_FLEN_VNAME+2];
	char		fwtype[TBDB_FLEN_VNAME+2];
	char		fwstyle[TBDB_FLEN_VNAME+2];
	char		fwlog[TBDB_FLEN_TINYTEXT+1];
	int		n, nrows;
	char		*vlan;

	bzero(fwlog, sizeof(fwlog));

	/*
	 * Containers and shared hosts can each have specific rules.
	 * The shared host can protect itself with iptables-dom0 rules,
	 * and containers themselves can be firewalled with iptables-domU
	 * rules (in the default_firewall_rules table). The main point
	 * though, is that this done on the virt host dom0, not with a
	 * separate firewall node. 
	 */
	if (reqp->isvnode ||
	    strcmp(reqp->erole, "virthost") == 0 ||
	    strcmp(reqp->erole, "sharedhost") == 0) {
		/*
		 * Since we implement the firewall code on the outside of
		 * the container (dom0), containers themselves know
		 * nothing about it, nor can containers act *as* firewall
		 * nodes for an entire experiment (although this is
		 * something we should implement some day).  So just tell
		 * the container not to worry about it.
		 */
		if (reqp->asvnode) {
			goto nofirewall;
		}
		res = mydb_query("select firewall_style,firewall_log "
				 "from virt_nodes "
				 "where exptidx='%d' and "
				 "      vname='%s' and "
				 "      firewall_style is not null ",
				 2, reqp->exptidx, reqp->nickname);
		if (!res) {
			error("FWINFO: %s: DB Error getting firewall info!\n",
			      reqp->nodeid);
			return 1;
		}
		if ((int)mysql_num_rows(res) == 0) {
			mysql_free_result(res);
			goto nofirewall;
		}
		row = mysql_fetch_row(res);
		/*
		 * Ignore the type, we decide. 
		 */
		if (reqp->isvnode) {
			strcpy(fwtype, "iptables-domU");
		}
		else {
			strcpy(fwtype, "iptables-dom0");
		}
		strncpy(fwstyle, row[0], sizeof(fwstyle));
		if (row[1] && row[1][0])
			strncpy(fwlog, row[1], sizeof(fwlog));
		mysql_free_result(res);

		OUTPUT(buf, sizeof(buf),
		       "TYPE=%s STYLE=%s "
		       "IN_IF=na OUT_IF=na IN_VLAN=0 OUT_VLAN=0\n",
		       fwtype, fwstyle);
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("FWINFO: %s", buf);
	
		goto vnodefw;
	}
	else {
		/*
		 * See if this node's experiment has an associated firewall
		 *
		 * XXX will only work if there is one firewall per experiment.
		 */
		res = mydb_query("select r.node_id,v.type,v.style,v.log,"
			 "  f.fwname,i.IP,i.mac,f.vlan "
			 "from firewalls as f "
			 "left join reserved as r on"
			 "  f.pid=r.pid and f.eid=r.eid and f.fwname=r.vname "
			 "left join virt_firewalls as v on "
			 "  v.pid=f.pid and v.eid=f.eid and v.fwname=f.fwname "
			 "left join interfaces as i on r.node_id=i.node_id "
			 "where f.pid='%s' and f.eid='%s' "
			 "and i.role='ctrl'",	/* XXX */
			 8, reqp->pid, reqp->eid);

		if (!res) {
			error("FWINFO: %s: DB Error getting firewall info!\n",
			      reqp->nodeid);
			return 1;
		}
	}

	/*
	 * Common case, no firewall
	 */
	if ((int)mysql_num_rows(res) == 0) {
		mysql_free_result(res);
	nofirewall:
		strncpy(buf, "TYPE=none\n", sizeof(buf));
		client_writeback(sock, buf, strlen(buf), tcp);
		return 0;
	}

	/*
	 * DB data is bogus
	 */
	row = mysql_fetch_row(res);
	if (!row[0] || !row[0][0]) {
		mysql_free_result(res);
		error("FWINFO: %s: DB Error in firewall info, no firewall!\n",
		      reqp->nodeid);
		strncpy(buf, "TYPE=none\n", sizeof(buf));
		client_writeback(sock, buf, strlen(buf), tcp);
		return 0;
	}

	/*
	 * There is a firewall, but it isn't us.
	 * Put out base info with TYPE=remote.
	 */
	if (strcmp(row[0], reqp->nodeid) != 0) {
		char *fwip;

		/*
		 * XXX sorta hack: if we are a HW enforced firewall,
		 * then the client doesn't need to do anything.
		 * Set the FWIP to 0 to indicate this.
		 */
		if (strcmp(row[1], "ipfw2-vlan") == 0 || strcmp(row[1], "iptables-vlan") == 0)
			fwip = "0.0.0.0";
		else
			fwip = row[5];
		OUTPUT(buf, sizeof(buf), "TYPE=remote FWIP=%s\n", fwip);
		mysql_free_result(res);
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("FWINFO: %s", buf);
		return 0;
	}

	/*
	 * Grab vlan info if available
	 */
	if (row[7] && row[7][0])
		vlan = row[7];
	else
		vlan = "0";

	/*
	 * We are the firewall.
	 * Put out base information and all the rules
	 *
	 * XXX for now we use the control interface for in/out
	 */
	OUTPUT(buf, sizeof(buf),
	       "TYPE=%s STYLE=%s IN_IF=%s OUT_IF=%s IN_VLAN=%s OUT_VLAN=%s\n",
	       row[1], row[2], row[6], row[6], vlan, vlan);
	client_writeback(sock, buf, strlen(buf), tcp);
	if (verbose)
		info("FWINFO: %s", buf);

	strncpy(fwtype, row[1], sizeof(fwtype));
	strncpy(fwstyle, row[2], sizeof(fwstyle));
	strncpy(fwname, row[4], sizeof(fwname));
	if (row[3] && row[3][0])
		strncpy(fwlog, row[3], sizeof(fwlog));
	mysql_free_result(res);

vnodefw:
	/*
	 * Put out info about firewall rule logging
	 */
	if (vers > 25 && fwlog[0]) {
		OUTPUT(buf, sizeof(buf), "LOG=%s\n", fwlog);
		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("FWINFO: %s", buf);
	}

	/*
	 * Return firewall variables
	 */
	if (vers > 21) {
		/*
		 * Grab the node gateway MAC which is not currently part
		 * of the firewall variables table.
		 */
		res = mydb_query("select value from sitevariables "
				 "where name='node/gw_mac'", 1);
		if (res && mysql_num_rows(res) > 0) {
			row = mysql_fetch_row(res);
			if (row[0]) {
				OUTPUT(buf, sizeof(buf),
				       "VAR=EMULAB_GWIP VALUE=\"%s\"\n",
				       CONTROL_ROUTER_IP);
				client_writeback(sock, buf, strlen(buf), tcp);
				OUTPUT(buf, sizeof(buf),
				       "VAR=EMULAB_GWMAC VALUE=\"%s\"\n",
				       row[0]);
				client_writeback(sock, buf, strlen(buf), tcp);
			}
		}
		if (res)
			mysql_free_result(res);

		res = mydb_query("select name,value from default_firewall_vars",
				 2);
		if (!res) {
			error("FWINFO: %s: DB Error getting firewall vars!\n",
			      reqp->nodeid);
			nrows = 0;
		} else
			nrows = (int)mysql_num_rows(res);
		for (n = nrows; n > 0; n--) {
			row = mysql_fetch_row(res);
			if (!row[0] || !row[1])
				continue;
			OUTPUT(buf, sizeof(buf), "VAR=%s VALUE=\"%s\"\n",
			       row[0], row[1]);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
		if (res)
			mysql_free_result(res);
		if (verbose)
			info("FWINFO: %d variables\n", nrows);
	}

	if (reqp->isvnode) {
		/*
		 * Write a var for the sshdport number.
		 */
		res = mydb_query("select n.sshdport from nodes as n "
				 "where n.node_id='%s'",
				 1, reqp->nodeid);

		if (!res) {
			error("FWINFO: %s: DB Error getting sshdport!\n",
			      reqp->nodeid);
			return 1;
		}

		if ((int)mysql_num_rows(res)) {
			row  = mysql_fetch_row(res);

			OUTPUT(buf, sizeof(buf), "VAR=%s VALUE=\"%s\"\n",
			       "EMULAB_SSHDPORT", row[0]);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
		mysql_free_result(res);
	}

	/*
	 * Get the user firewall rules from the DB and return them.
	 * Note difference for vnodes/vhosts; these can store rules
	 # for each vnode/vhost in the topo.
	 */
	res = mydb_query("select ruleno,rule from firewall_rules "
			 "where pid='%s' and eid='%s' and fwname='%s' "
			 "order by ruleno",
			 2, reqp->pid, reqp->eid,
			 ((reqp->isvnode || reqp->sharing_mode[0]) ?
			  reqp->nickname : fwname));
	if (!res) {
		error("FWINFO: %s: DB Error getting firewall rules!\n",
		      reqp->nodeid);
		return 1;
	}
	nrows = (int)mysql_num_rows(res);

	for (n = nrows; n > 0; n--) {
		row = mysql_fetch_row(res);
		OUTPUT(buf, sizeof(buf), "RULENO=%s RULE=\"%s\"\n",
		       row[0], row[1]);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);
	if (verbose)
		info("FWINFO: %d user rules\n", nrows);

	/*
	 * Get the default firewall rules from the DB and return them.
	 */
	res = mydb_query("select ruleno,rule from default_firewall_rules "
			 "where type='%s' and style='%s' and enabled!=0 "
			 "order by ruleno",
			 2, fwtype, fwstyle);
	if (!res) {
		error("FWINFO: %s: DB Error getting default firewall rules!\n",
		      reqp->nodeid);
		return 1;
	}
	nrows = (int)mysql_num_rows(res);

	for (n = nrows; n > 0; n--) {
		row = mysql_fetch_row(res);
		OUTPUT(buf, sizeof(buf), "RULENO=%s RULE=\"%s\"\n",
		       row[0], row[1]);
		client_writeback(sock, buf, strlen(buf), tcp);
	}

	mysql_free_result(res);
	if (verbose)
	    info("FWINFO: %d default rules\n", nrows);

	/*
	 * Ohhh...I gotta bad case of the butt-uglies!
	 *
	 * Return the list of the unqualified names of the firewalled hosts
	 * along with their IP addresses.  The client code uses this to
	 * construct a local hosts file so that symbolic host names can
	 * be used in firewall rules.
	 *
	 * We also return the control net MAC address for each node so
	 * that we can provide proxy ARP.
	 */
	if (vers > 24) {
		res = mydb_query("select r.vname,i.IP,i.mac "
			"from reserved as r "
			"left join interfaces as i on r.node_id=i.node_id "
			"where r.pid='%s' and r.eid='%s' and i.role='ctrl'",
			 3, reqp->pid, reqp->eid);
		if (!res) {
			error("FWINFO: %s: DB Error getting host info!\n",
			      reqp->nodeid);
			return 1;
		}
		nrows = (int)mysql_num_rows(res);

		for (n = nrows; n > 0; n--) {
			row = mysql_fetch_row(res);
			if (vers > 25) {
				OUTPUT(buf, sizeof(buf),
				       "HOST=%s CNETIP=%s CNETMAC=%s\n",
				       row[0], row[1], row[2]);
			} else {
				OUTPUT(buf, sizeof(buf),
				       "HOST=%s CNETIP=%s\n",
				       row[0], row[1]);
			}
			client_writeback(sock, buf, strlen(buf), tcp);
		}

		mysql_free_result(res);
		if (verbose)
			info("FWINFO: %d firewalled hosts\n", nrows);
	}

	/*
	 * We also start returning the MAC addresses for boss, ops, fs
	 * and subboss servers so that we can create ARP entries. This is
	 * necessary if the servers are in the same subnet as the nodes
	 * and thus the gateway is not used to contact them.
	 */
	if (vers > 33) {
		res = mydb_query("select node_id,IP,mac from interfaces "
				 "where role='ctrl' and (node_id in "
				 "('boss','ops','fs') or node_id in "
				 "(select distinct subboss_id from subbosses where disabled=0))",
				 3);
		if (!res) {
			error("FWINFO: %s: DB Error getting server info!\n",
			      reqp->nodeid);
			return 1;
		}
		nrows = (int)mysql_num_rows(res);

		if (nrows > 0) {
			struct in_addr cnet, cmask, naddr;

			inet_aton(CONTROL_NETWORK, &cnet);
			inet_aton(CONTROL_NETMASK, &cmask);
			cnet.s_addr &= cmask.s_addr;

			for (n = nrows; n > 0; n--) {
				row = mysql_fetch_row(res);

				/*
				 * Return the ones on the node control net.
				 */
				inet_aton(row[1], &naddr);
				naddr.s_addr &= cmask.s_addr;
				if (naddr.s_addr != cnet.s_addr)
					continue;

				OUTPUT(buf, sizeof(buf),
				       "SERVER=%s CNETIP=%s CNETMAC=%s\n",
				       row[0], row[1], row[2]);
				client_writeback(sock, buf, strlen(buf), tcp);
			}
		}

		mysql_free_result(res);
		if (verbose)
			info("FWINFO: %d server hosts\n", nrows);
	}

	return 0;
}

/*
 * Return the config for an inner emulab
 */
COMMAND_PROTOTYPE(doemulabconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	char		myrole[32], rolebuf[256];
	int		nrows;

	/*
	 * Must be an elab_in_elab experiment.
	 */
	if (!reqp->elab_in_elab) {
		/* Silent error is fine */
		return 0;
	}

	/*
	 * Get the control network IPs. At the moment, it is assumed that
	 * that all the nodes are on a single lan. If we get fancier about
	 * that, we will have to figure out how to label the specific lans
	 * se we know which is which.
	 *
	 * Note the single vs dual control network differences!
	 */
	if (reqp->isvnode && reqp->singlenet) {
		res = mydb_query("select r.node_id,r.inner_elab_role,"
				 "   IFNULL(i.IP,n.jailip),r.vname "
				 "  from reserved as r "
				 "left join nodes as n on "
				 "     n.node_id=r.node_id "
				 "left join interfaces as i on "
				 "   i.node_id=r.node_id and i.role='ctrl' "
				 "where r.pid='%s' and r.eid='%s' and "
				 "      r.inner_elab_role is not null",
				 4, reqp->pid, reqp->eid);
	}
	else if (reqp->singlenet) {
		res = mydb_query("select r.node_id,r.inner_elab_role,"
				 "   i.IP,r.vname from reserved as r "
				 "left join interfaces as i on "
				 "     i.node_id=r.node_id and i.role='ctrl' "
				 "where r.pid='%s' and r.eid='%s' and "
				 "      r.inner_elab_role is not null",
				 4, reqp->pid, reqp->eid);
	}
	else {
		res = mydb_query("select r.node_id,r.inner_elab_role,"
				 "   vl.ip,r.vname from reserved as r "
				 "left join virt_lans as vl on "
				 "     vl.vnode=r.vname and "
				 "     vl.pid=r.pid and vl.eid=r.eid "
				 "where r.pid='%s' and r.eid='%s' and "
				 "      r.inner_elab_role is not null",
				 4, reqp->pid, reqp->eid);
	}

	if (!res) {
		error("EMULABCONFIG: %s: DB Error getting elab_in_elab\n",
		      reqp->nodeid);
		return 1;
	}
	if (! mysql_num_rows(res)) {
		mysql_free_result(res);
		return 0;
	}
	nrows = (int)mysql_num_rows(res);

	/*
	 * Lets find the role for the current node and spit that out first.
	 */
	bzero(buf, sizeof(buf));
	while (nrows--) {
		row = mysql_fetch_row(res);

		if (!strcmp(row[0], reqp->nodeid)) {
			bufp += OUTPUT(bufp, ebufp - bufp, "ROLE=%s\n", row[1]);
			strncpy(myrole, row[1], sizeof(myrole));
			break;
		}
	}

	/*
	 * Spit the names of the boss, ops and fs nodes for everyones benefit.
	 */
	mysql_data_seek(res, 0);
	nrows = (int)mysql_num_rows(res);

	while (nrows--) {
		row = mysql_fetch_row(res);

		if (!strcmp(row[1], "boss") || !strcmp(row[1], "boss+router") ||
		    !strcmp(row[1], "boss+fs+router")) {
			bufp += OUTPUT(bufp, ebufp - bufp, "BOSSNODE=%s\n",
				       row[3]);
			bufp += OUTPUT(bufp, ebufp - bufp, "BOSSIP=%s\n",
				       row[2]);
		}
		else if (!strcmp(row[1], "ops") || !strcmp(row[1], "ops+fs")) {
			bufp += OUTPUT(bufp, ebufp - bufp, "OPSNODE=%s\n",
				       row[3]);
			bufp += OUTPUT(bufp, ebufp - bufp, "OPSIP=%s\n",
				       row[2]);
		}
		else if (!strcmp(row[1], "fs")) {
			bufp += OUTPUT(bufp, ebufp - bufp, "FSNODE=%s\n",
				       row[3]);
			bufp += OUTPUT(bufp, ebufp - bufp, "FSIP=%s\n",
				       row[2]);
		}
	}
	mysql_free_result(res);

	/*
	 * Some package info and other stuff from sitevars.
	 */
	res = mydb_query("select name,value from sitevariables "
			 "where name like 'elabinelab/%%'", 2);
	if (!res) {
		error("EMULABCONFIG: %s: DB Error getting elab_in_elab\n",
		      reqp->nodeid);
		return 1;
	}
	nrows = (int)mysql_num_rows(res);
	while (nrows--) {
		row = mysql_fetch_row(res);
		if (strcmp(row[0], "elabinelab/boss_pkg_dir") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "BOSS_PKG_DIR=%s\n",
				       row[1]);
		} else if (strcmp(row[0], "elabinelab/boss_pkg") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "BOSS_PKG=%s\n",
				       row[1]);
		} else if (strcmp(row[0], "elabinelab/ops_pkg_dir") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "OPS_PKG_DIR=%s\n",
				       row[1]);
		} else if (strcmp(row[0], "elabinelab/ops_pkg") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "OPS_PKG=%s\n",
				       row[1]);
		} else if (strcmp(row[0], "elabinelab/fs_pkg_dir") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "FS_PKG_DIR=%s\n",
				       row[1]);
		} else if (strcmp(row[0], "elabinelab/fs_pkg") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "FS_PKG=%s\n",
				       row[1]);
		} else if (strcmp(row[0], "elabinelab/windows") == 0) {
			bufp += OUTPUT(bufp, ebufp - bufp, "WINSUPPORT=%s\n",
				       row[1]);
		}
	}
	mysql_free_result(res);

	/*
	 * Stuff from the experiments table.
	 */
	res = mydb_query("select elabinelab_cvstag "
			 "   from experiments "
			 "where pid='%s' and eid='%s'",
			 1, reqp->pid, reqp->eid);
	if (!res) {
		error("EMULABCONFIG: %s: DB Error getting experiments info\n",
		      reqp->nodeid);
		return 1;
	}
	if ((int)mysql_num_rows(res)) {
	    row = mysql_fetch_row(res);

	    if (row[0] && row[0][0]) {
		bufp += OUTPUT(bufp, ebufp - bufp, "CVSSRCTAG=%s\n",
			       row[0]);
	    }
	}
	mysql_free_result(res);

	/*
	 * Tell the inner elab if its a single control network setup.
	 */
	bufp += OUTPUT(bufp, ebufp - bufp, "SINGLE_CONTROLNET=%d\n",
		       reqp->singlenet);

	/*
	 * Put out new attributes.  Eventually, most of the above
	 * parameters should come from here.  Note that a node can have
	 * multiple roles and we need to construct a query for that.
	 */
	rolebuf[0] = '\0';
	if (strchr(myrole, '+')) {
		int gotone = 0;
		int len = sizeof(rolebuf) - 1;
		if (len > 0 && strstr(myrole, "boss")) {
			if (gotone)
				strcat(rolebuf, " or ");
			strncat(rolebuf, "role='boss'", len);
			len -= 11;
			gotone = 1;
		}
		if (len > 0 && strstr(myrole, "ops")) {
			if (gotone)
				strcat(rolebuf, " or ");
			strncat(rolebuf, "role='ops'", len);
			len -= 10;
			gotone = 1;
		}
		if (len > 0 && strstr(myrole, "fs")) {
			if (gotone)
				strcat(rolebuf, " or ");
			strncat(rolebuf, "role='fs'", len);
			len -= 9;
			gotone = 1;
		}
		if (len > 0 && strstr(myrole, "router")) {
			if (gotone)
				strcat(rolebuf, " or ");
			strncat(rolebuf, "role='router'", len);
			len -= 13;
			gotone = 1;
		}
	} else {
		snprintf(rolebuf, sizeof(rolebuf), "role='%s'", myrole);
	}

	/*
	 * Get all the attributes for the node's role.
	 * Note taht for backward compat, we don't worry if the attributes
	 * table does not exist.
	 */
	res = mydb_query("select attrkey,attrvalue "
			 "   from elabinelab_attributes "
			 "where exptidx=%d and (%s) order by ordering",
			 2, reqp->exptidx, rolebuf);
	if (res) {
		nrows = (int)mysql_num_rows(res);
		while (bufp < ebufp && nrows--) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0] && row[1])
				bufp += OUTPUT(bufp, ebufp - bufp, "%s=\"%s\"\n",
					       row[0], row[1]);
		}
		mysql_free_result(res);
	}

	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return the config for an emulated ("inner") planetlab
 */
COMMAND_PROTOTYPE(doeplabconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	int		nrows;

	/*
	 * We only respond if we are a PLC node
	 */
	res = mydb_query("select node_id from reserved "
			 "where pid='%s' and eid='%s' and plab_role='plc'",
			 1, reqp->pid, reqp->eid);
	if (!res) {
		error("EPLABCONFIG: %s: DB Error getting plab_role\n",
		      reqp->nodeid);
		return 1;
	}
	if (!mysql_num_rows(res)) {
		mysql_free_result(res);
		return 0;
	}
	row = mysql_fetch_row(res);
	if (!row[0] || strcmp(row[0], reqp->nodeid) != 0) {
		mysql_free_result(res);
		return 0;
	}
	mysql_free_result(res);

	/*
	 * VNAME=<vname> PNAME=<FQpname> ROLE=<role> CNETIP=<IP> CNETMAC=<MAC>
	 */
	res = mydb_query("select r.node_id,r.vname,r.plab_role,i.IP,i.mac "
			 "  from reserved as r join interfaces as i "
			 "  where r.node_id=i.node_id and "
			 "    i.role='ctrl' and r.pid='%s' and r.eid='%s'",
			 5, reqp->pid, reqp->eid);

	if (!res || mysql_num_rows(res) == 0) {
		error("EMULABCONFIG: %s: DB Error getting plab_in_elab info\n",
		      reqp->nodeid);
		if (res)
			mysql_free_result(res);
		return 1;
	}
	nrows = (int)mysql_num_rows(res);

	/*
	 * Spit out the PLC node first just cuz
	 */
	bzero(buf, sizeof(buf));
	while (nrows--) {
		row = mysql_fetch_row(res);

		if (!strcmp(row[2], "plc")) {
			bufp += OUTPUT(bufp, ebufp - bufp,
				       "VNAME=%s PNAME=%s.%s ROLE=%s CNETIP=%s CNETMAC=%s\n",
				       row[1], row[0], OURDOMAIN, row[2],
				       row[3], row[4]);
			client_writeback(sock, buf, strlen(buf), tcp);
			break;
		}
	}

	/*
	 * Then all the nodes
	 */
	mysql_data_seek(res, 0);
	nrows = (int)mysql_num_rows(res);

	while (nrows--) {
		row = mysql_fetch_row(res);
		bufp = buf;

		if (!strcmp(row[1], "plc"))
			continue;

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "VNAME=%s PNAME=%s.%s ROLE=%s CNETIP=%s CNETMAC=%s\n",
			       row[1], row[0], OURDOMAIN, row[2],
			       row[3], row[4]);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);

	/*
	 * Now report all the configured experimental interfaces:
	 *
	 * VNAME=<vname> IP=<IP> NETMASK=<mask> MAC=<MAC>
	 */
	res = mydb_query("select vl.vnode,i.IP,i.mask,i.mac from reserved as r"
			 "  left join virt_lans as vl"
			 "    on r.pid=vl.pid and r.eid=vl.eid"
			 "  left join interfaces as i"
			 "    on vl.ip=i.IP and r.node_id=i.node_id"
			 "  where r.pid='%s' and r.eid='%s' and"
			 "    r.plab_role!='none'"
			 "    and i.IP!='' and i.role='expt'",
			 4, reqp->pid, reqp->eid);

	if (!res) {
		error("EMULABCONFIG: %s: DB Error getting plab_in_elab info\n",
		      reqp->nodeid);
		return 1;
	}
	nrows = (int)mysql_num_rows(res);
	while (nrows--) {
		row = mysql_fetch_row(res);
		bufp = buf;

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "VNAME=%s IP=%s NETMASK=%s MAC=%s\n",
			       row[0], row[1], row[2], row[3]);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);

	/*
	 * Grab lanlink on which the node should be/contact plc.
	 */
	/*
	 * For now, just assume that plab_plcnet is a valid lan name and
	 * join it with virtlans and ifaces.
	 */
	res = mydb_query("select vl.vnode,r.node_id,vn.plab_plcnet,"
			 "       vn.plab_role,i.IP,i.mask,i.mac"
			 "  from reserved as r left join virt_lans as vl"
			 "    on r.exptidx=vl.exptidx"
			 "  left join interfaces as i"
			 "    on vl.ip=i.IP and r.node_id=i.node_id"
			 "  left join virt_nodes as vn"
			 "    on vl.vname=vn.plab_plcnet and r.vname=vn.vname"
			 "      and vn.exptidx=r.exptidx"
			 "  where r.pid='%s' and r.eid='%s' and"
                         "    r.plab_role != 'none' and i.IP != ''"
			 "      and vn.plab_plcnet != 'none'"
			 "      and vn.plab_plcnet != 'control'",
			 7,reqp->pid,reqp->eid);
	if (!res) {
	    error("EPLABCONFIG: %s: DB Error getting plab_in_elab info\n",
		  reqp->nodeid);
	    return 1;
	}
	nrows = (int)mysql_num_rows(res);
	while (nrows--) {
	    row = mysql_fetch_row(res);
	    bufp = buf;

	    bufp += OUTPUT(bufp,ebufp-bufp,
			   "VNAME=%s PNAME=%s.%s PLCNETWORK=%s ROLE=%s IP=%s NETMASK=%s MAC=%s\n",
			   row[0],row[1],OURDOMAIN,row[2],row[3],row[4],row[5],
			   row[6]);
	    client_writeback(sock,buf,strlen(buf),tcp);
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Hack to test timeouts and other anomolous situations for tmcc
 */
COMMAND_PROTOTYPE(dotmcctest)
{
	char		buf[MYBUFSIZE];
	int		logit;

	logit = verbose;

	if (logit)
		info("TMCCTEST: %s\n", rdata);

	/*
	 * Always allow the test that doesn't tie up a server thread
	 */
	if (strncmp(rdata, "noreply", strlen("noreply")) == 0)
		return 0;

	/*
	 * The rest can tie up a server thread for non-trivial amounts of
	 * time, only allow if debugging.
	 */
	if (!debug) {
		strcpy(buf, "tmcctest disabled\n");
		goto doit;
	}

	/*
	 * Delay reply by the indicated amount of time
	 */
	if (strncmp(rdata, "delayreply", strlen("delayreply")) == 0) {
		int delay = 0;
		if (sscanf(rdata, "delayreply %d", &delay) == 1 &&
		    delay < 20) {
			sleep(delay);
			sprintf(buf, "replied after %d seconds\n", delay);
		} else {
			strcpy(buf, "bogus delay value\n");
		}
		goto doit;
	}

	if (tcp) {
		/*
		 * Reply in pieces
		 */
		if (strncmp(rdata, "splitreply", strlen("splitreply")) == 0) {
			memset(buf, '1', MYBUFSIZE/4);
			buf[MYBUFSIZE/4] = 0;
			client_writeback(sock, buf, strlen(buf), tcp);
			sleep(1);
			memset(buf, '2', MYBUFSIZE/4);
			buf[MYBUFSIZE/4] = 0;
			client_writeback(sock, buf, strlen(buf), tcp);
			sleep(2);
			memset(buf, '4', MYBUFSIZE/4);
			buf[MYBUFSIZE/4] = 0;
			client_writeback(sock, buf, strlen(buf), tcp);
			sleep(4);
			memset(buf, '0', MYBUFSIZE/4);
			buf[MYBUFSIZE/4-1] = '\n';
			buf[MYBUFSIZE/4] = 0;
			logit = 0;
		} else {
			strcpy(buf, "no such TCP test\n");
		}
	} else {
		strcpy(buf, "no such UDP test\n");
	}

 doit:
	client_writeback(sock, buf, strlen(buf), tcp);
	if (logit)
		info("%s", buf);
	return 0;
}

/*
 * Return node localization. For example, boss root pub key, root password,
 * stuff like that.
 */
COMMAND_PROTOTYPE(dolocalize)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE]; /* strlen(privkey) > 2048 */
	int		nrows;
	char		*okey = NULL;
#ifdef ELABINELAB
	FILE		*fp = NULL;

	/*
	 * Include outer boss root key.
	 * We get it from /etc/emulab/outer_bossrootkey.pub which was
	 * created by rc.mkelab when the bossnode was setup.
	 */
	if ((fp = fopen("/etc/emulab/outer_bossrootkey.pub", "r")) != NULL) {
		char *cp;

		while ((fgets(buf, sizeof(buf), fp)) != NULL) {
			if (buf[0] != '#') {
				if ((cp = rindex(buf, '\n')) != NULL)
					*cp = '\0';
				okey = strdup(buf);
				break;
			}
		}
		fclose(fp);
	}
#endif

	/*
	 * XXX sitevar fetching should be a library function.
	 * WARNING: This sitevar (node/ssh_pubkey) is referenced in
	 *          install/boss-install during initial setup.
	 */
	res = mydb_query("select name,value "
			 "from sitevariables where name='node/ssh_pubkey'",
			 2);
	if (!res || (nrows = (int)mysql_num_rows(res)) == 0) {
		error("DOLOCALIZE: sitevar node/ssh_pubkey does not exist\n");
		if (res)
			mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);
	if (row[1]) {
		OUTPUT(buf, sizeof(buf), "ROOTPUBKEY='%s'\n", row[1]);
		client_writeback(sock, buf, strlen(buf), tcp);
	}

	/*
	 * Put the "other" key out after the main boss key, just in case we
	 * have software that only looks at the first key.
	 */
	if (okey) {
		if (row[1] == NULL || strcmp(okey, row[1])) {
			OUTPUT(buf, sizeof(buf), "ROOTPUBKEY='%s'\n", okey);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
		free(okey);
	}
	mysql_free_result(res);

	/*
	 * See if there is a per-experiment root public key that should
	 * be included.
	 */
	if ((reqp->experiment_keys & TB_ROOTKEYS_PUBLIC) != 0) {
		res = mydb_query("select ssh_pubkey from experiment_keys "
				 "where exptidx='%d'", 1, reqp->exptidx);
		if (res && (nrows = (int)mysql_num_rows(res)) > 0) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0]) {
				OUTPUT(buf, sizeof(buf),
				       "ROOTPUBKEY='%s'\n", row[0]);
				client_writeback(sock, buf, strlen(buf), tcp);
			}
		}
		if (res)
			mysql_free_result(res);
	}

	/*
	 * Pass back the public key half of the keypair.
	 * The version check is to avoid warnings from the client about
	 * bad localization lines. Mighty big of us don't ya think?
	 *
	 * XXX note that this pubkey is different than the SSH pubkey above.
	 *
	 * XXX note that we don't actually pass back the private key here!
	 * Once we start encrypting the private key with a per-node key
	 * planted at imaging time, then we can pass it back.
	 */
	if (vers > 41 && (reqp->experiment_keys & TB_ROOTKEYS_PRIVATE) != 0) {
		res = mydb_query("select rsa_pubkey,ssh_pubkey from "
				 "experiment_keys where exptidx='%d'",
				 2, reqp->exptidx);
		if (res && (nrows = (int)mysql_num_rows(res)) > 0) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0]) {
				OUTPUT(buf, sizeof(buf),
				       "ROOTKEY='%s' "
				       "KEYFILE='.ssl/%s.pub' "
				       "ENCRYPTED='no'\n",
				       row[0], reqp->nodeid);
				client_writeback(sock, buf, strlen(buf), tcp);
			}
			/* For completeness drop the ssh key in its own file */
			if (row[1] && row[1][0]) {
				OUTPUT(buf, sizeof(buf),
				       "ROOTKEY='%s' "
				       "KEYFILE='.ssh/id_rsa.pub' "
				       "ENCRYPTED='no'\n",
				       row[1]);
				client_writeback(sock, buf, strlen(buf), tcp);
			}
		}
		if (res)
			mysql_free_result(res);
	}

	return 0;
}

/*
 * Return root password
 */
COMMAND_PROTOTYPE(dorootpswd)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[BUFSIZ], hashbuf[BUFSIZ], saltbuf[8+1], *bp;
	char		*nodeid = reqp->pnodeid;

	/*
	 * On a virtnode, we return the password for the physical
	 * host, but not on a shared node, it needs its own.
	 */
	if (reqp->isvnode && reqp->sharing_mode[0]) {
		nodeid = reqp->nodeid;
	}

	res = mydb_query("select attrvalue from node_attributes "
			 " where node_id='%s' and "
			 "       attrkey='root_password'",
			 1, nodeid);

	if (!res || (int)mysql_num_rows(res) == 0) {
		if (getrandomchars(hashbuf, 12)) {
			error("DOROOTPSWD: no random chars for password\n");
			if (res)
				mysql_free_result(res);
			return 1;
		}
		mydb_update("replace into node_attributes set "
			    "  node_id='%s', "
			    "  attrkey='root_password',attrvalue='%s'",
			    nodeid, hashbuf);
	}
	else {
		row = mysql_fetch_row(res);
		strncpy(hashbuf, row[0], sizeof(hashbuf)-1);
		hashbuf[sizeof(hashbuf)-1] = '\0';
	}
	if (res)
		mysql_free_result(res);

	/*
	 * Need to crypt() this for the node since we obviously do not want
	 * to return the plain text.
	 */
	if (getrandomchars(saltbuf, 8)) {
		error("DOROOTPSWD: no random chars for salt\n");
		return 1;
	}
	sprintf(buf, "$1$%s", saltbuf);
	bp = crypt(hashbuf, buf);

	OUTPUT(buf, sizeof(buf), "HASH=%s\n", bp);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Upload boot log to DB for the node.
 */
COMMAND_PROTOTYPE(dobootlog)
{
	char		*cp = (char *) NULL;
	int		len;

	/*
	 * Dig out the log message text.
	 */
	while (*rdata && isspace(*rdata))
		rdata++;

	/*
	 * Stash optional text. Must escape it of course.
	 */
	if ((len = strlen(rdata))) {
		if ((cp = (char *) malloc((2*len)+1)) == NULL) {
			error("DOBOOTLOG: %s: Out of Memory\n", reqp->nodeid);
			return 1;
		}
		mysql_escape_string(cp, rdata, len);

		if (mydb_update("replace into node_bootlogs "
				" (node_id, bootlog, bootlog_timestamp) values "
				" ('%s', '%s', now())",
				reqp->nodeid, cp)) {
			error("DOBOOTLOG: %s: DB Error setting bootlog\n",
			      reqp->nodeid);
			free(cp);
			return 1;

		}
		if (verbose)
		    printf("DOBOOTLOG: %d '%s'\n", len, cp);

		free(cp);
	}
	return 0;
}

/*
 * Tell us about boot problems with a specific error code that we can use
 * in os_setup to figure out what went wrong, and if we should retry.
 */
COMMAND_PROTOTYPE(dobooterrno)
{
	int		myerrno;

	/*
	 * Dig out errno that the node is reporting
	 */
	if (sscanf(rdata, "%d", &myerrno) != 1) {
		error("DOBOOTERRNO: %s: Bad arguments\n", reqp->nodeid);
		return 1;
	}

	/*
	 * and update DB.
	 */
	if (mydb_update("update nodes set boot_errno='%d' "
			"where node_id='%s'",
			myerrno, reqp->nodeid)) {
		error("DOBOOTERRNO: %s: setting boot errno!\n", reqp->nodeid);
		return 1;
	}
	if (verbose)
		info("DOBOOTERRNO: errno=%d\n", myerrno);

	return 0;
}

/*
 * Tell us about battery statistics.
 */
COMMAND_PROTOTYPE(dobattery)
{
	float		capacity = 0.0, voltage = 0.0;
	char		buf[MYBUFSIZE];

	/*
	 * Dig out the capacity and voltage, then
	 */
	if ((sscanf(rdata,
		    "CAPACITY=%f VOLTAGE=%f",
		    &capacity,
		    &voltage) != 2) ||
	    (capacity < 0.0f) || (capacity > 100.0f) ||
	    (voltage < 5.0f) || (voltage > 15.0f)) {
		error("DOBATTERY: %s: Bad arguments\n", reqp->nodeid);
		return 1;
	}

	/*
	 * ... update DB.
	 */
	if (mydb_update("UPDATE nodes SET battery_percentage=%f,"
			"battery_voltage=%f,"
			"battery_timestamp=UNIX_TIMESTAMP(now()) "
			"WHERE node_id='%s'",
			capacity, voltage, reqp->nodeid)) {
		error("DOBATTERY: %s: setting boot errno!\n", reqp->nodeid);
		return 1;
	}
	if (verbose) {
		info("DOBATTERY: capacity=%.2f voltage=%.2f\n",
		     capacity,
		     voltage);
	}

	OUTPUT(buf, sizeof(buf), "OK\n");
	client_writeback(sock, buf, strlen(buf), tcp);

	return 0;
}

/*
 * Spit back the topomap. This is a backup for when NFS fails.
 * We send back the gzipped version.
 */
COMMAND_PROTOTYPE(dotopomap)
{
	FILE		*fp;
	char		buf[MYBUFSIZE];
	int		cc;

	/*
	 * Open up the file on boss and spit it back.
	 */
	sprintf(buf, "%s/expwork/%s/%s/topomap.gz", TBROOT,
		reqp->pid, reqp->eid);

	if ((fp = fopen(buf, "r")) == NULL) {
		errorc("DOTOPOMAP: Could not open topomap for %s",
		       reqp->nodeid);
		return 1;
	}

	while (1) {
		cc = fread(buf, sizeof(char), sizeof(buf), fp);
		if (cc == 0) {
			if (ferror(fp)) {
				fclose(fp);
				return 1;
			}
			break;
		}
		client_writeback(sock, buf, cc, tcp);
	}
	fclose(fp);
	return 0;
}

/*
 * Spit back the ltmap. This is a backup for when NFS fails.
 * We send back the gzipped version.
 */
COMMAND_PROTOTYPE(doltmap)
{
	FILE		*fp;
	char		buf[MYBUFSIZE];
	int		cc;

	/*
	 * Open up the file on boss and spit it back.
	 */
	sprintf(buf, "%s/expwork/%s/%s/ltmap.gz", TBROOT,
		reqp->pid, reqp->eid);

	if ((fp = fopen(buf, "r")) == NULL) {
		errorc("DOLTMAP: Could not open ltmap for %s",
		       reqp->nodeid);
		return 1;
	}

	while (1) {
		cc = fread(buf, sizeof(char), sizeof(buf), fp);
		if (cc == 0) {
			if (ferror(fp)) {
				fclose(fp);
				return 1;
			}
			break;
		}
		client_writeback(sock, buf, cc, tcp);
	}
	fclose(fp);
	return 0;
}

/*
 * Spit back the ltpmap. This is a backup for when NFS fails.
 * We send back the gzipped version.  Note that it is ok if this
 * file does not exist.
 */
COMMAND_PROTOTYPE(doltpmap)
{
	FILE		*fp;
	char		buf[MYBUFSIZE];
	int		cc;

	/*
	 * Open up the file on boss and spit it back.
	 */
	sprintf(buf, "%s/expwork/%s/%s/ltpmap.gz", TBROOT,
		reqp->pid, reqp->eid);

	if ((fp = fopen(buf, "r")) == NULL)
		return 0;

	while (1) {
		cc = fread(buf, sizeof(char), sizeof(buf), fp);
		if (cc == 0) {
			if (ferror(fp)) {
				fclose(fp);
				return 1;
			}
			break;
		}
		client_writeback(sock, buf, cc, tcp);
	}
	fclose(fp);
	return 0;
}

/*
 * Return user environment.
 */
COMMAND_PROTOTYPE(douserenv)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	res = mydb_query("select name,value from virt_user_environment "
			 "where pid='%s' and eid='%s' order by idx",
			 2, reqp->pid, reqp->eid);

	if (!res) {
		error("USERENV: %s: DB Error getting virt_user_environment\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		char	*bufp = buf, *ebufp = &buf[sizeof(buf)];

		row = mysql_fetch_row(res);

		bufp += OUTPUT(bufp, ebufp - bufp, "%s=%s\n", row[0], row[1]);
		client_writeback(sock, buf, strlen(buf), tcp);

		nrows--;
		if (verbose)
			info("USERENV: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return tip tunnels for the node.
 */
COMMAND_PROTOTYPE(dotiptunnels)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	res = mydb_query("select vtt.vnode,tl.server,tl.portnum,tl.keylen,"
			 "tl.keydata "
			 "from virt_tiptunnels as vtt "
			 "left join reserved as r on r.vname=vtt.vnode and "
			 "  r.pid=vtt.pid and r.eid=vtt.eid "
			 "left join tiplines as tl on tl.node_id=r.node_id "
			 "where vtt.pid='%s' and vtt.eid='%s' and "
			 "vtt.host='%s'",
			 5, reqp->pid, reqp->eid, reqp->nickname);

	if (!res) {
		error("TIPTUNNELS: %s: DB Error getting virt_tiptunnels\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);

		if (row[1]) {
			OUTPUT(buf, sizeof(buf),
			       "VNODE=%s SERVER=%s PORT=%s KEYLEN=%s KEY=%s\n",
			       row[0], row[1], row[2], row[3], row[4]);
			client_writeback(sock, buf, strlen(buf), tcp);
		}

		nrows--;
		if (verbose)
			info("TIPTUNNELS: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

COMMAND_PROTOTYPE(dorelayconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	int		nrows;

	res = mydb_query("select tl.server,tl.portnum from tiplines as tl "
			 "where tl.node_id='%s'",
			 2, reqp->nodeid);

	if (!res) {
		error("RELAYCONFIG: %s: DB Error getting relay config\n",
		      reqp->nodeid);
		return 1;
	}
	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);

		OUTPUT(buf, sizeof(buf),
		       "TYPE=%s\n"
		       "CAPSERVER=%s\n"
		       "CAPPORT=%s\n",
		       reqp->type, row[0], row[1]);
		client_writeback(sock, buf, strlen(buf), tcp);

		nrows--;
		if (verbose)
			info("RELAYCONFIG: %s", buf);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return trace config
 */
COMMAND_PROTOTYPE(dotraceconfig)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[2*MYBUFSIZE], *ebufp = &buf[sizeof(buf)];
	int		nrows;

	/*
	 * Get delay parameters for the machine. The point of this silly
	 * join is to get the type out so that we can pass it back. Of
	 * course, this assumes that the type is the BSD name, not linux.
	 */
	if (! reqp->isvnode) {
	  res = mydb_query("select linkvname,i0.MAC,i1.MAC,t.vnode,i2.MAC, "
			   "       t.trace_type,t.trace_expr,t.trace_snaplen, "
			   "       t.idx "
			   "from traces as t "
			   "left join interfaces as i0 on "
			   " i0.node_id=t.node_id and i0.iface=t.iface0 "
			   "left join interfaces as i1 on "
			   " i1.node_id=t.node_id and i1.iface=t.iface1 "
			   "left join reserved as r on r.vname=t.vnode and "
			   "     r.pid='%s' and r.eid='%s' "
			   "left join virt_lans as v on v.vname=t.linkvname  "
			   " and v.pid=r.pid and v.eid=r.eid and "
			   "     v.vnode=t.vnode "
			   "left join interfaces as i2 on "
			   "     i2.node_id=r.node_id and i2.IP=v.ip "
			   " where t.node_id='%s'",
			   9, reqp->pid, reqp->eid, reqp->nodeid);
	}
	else {
	  res = mydb_query("select linkvname,i0.mac,i1.mac,t.vnode,'', "
			   "       t.trace_type,t.trace_expr,t.trace_snaplen, "
			   "       t.idx "
			   "from traces as t "
			   "left join vinterfaces as i0 on "
			   " i0.vnode_id=t.node_id and "
			   " i0.unit=SUBSTRING(t.iface0, 5) "
			   "left join vinterfaces as i1 on "
			   " i1.vnode_id=t.node_id and "
			   " i1.unit=SUBSTRING(t.iface1, 5) "
			   "left join reserved as r on r.vname=t.vnode and "
			   "     r.pid='%s' and r.eid='%s' "
			   "left join virt_lans as v on v.vname=t.linkvname  "
			   " and v.pid=r.pid and v.eid=r.eid and "
			   "     v.vnode=t.vnode "
			   "left join interfaces as i2 on "
			   "     i2.node_id=r.node_id and i2.IP=v.ip "
			   " where t.node_id='%s'",
			   9, reqp->pid, reqp->eid, reqp->nodeid);
	}

	if (!res) {
		error("TRACEINFO: %s: DB Error getting trace table!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}
	while (nrows) {
		char	*bufp = buf;
		int     idx;

		row = mysql_fetch_row(res);

		/*
		 * XXX plab hack: add the vnode number to the idx to
		 * prevent vnodes on the same pnode from using the same
		 * port number!
		 */
		idx = atoi(row[8]);
		if (reqp->isplabdslice &&
		    strncmp(reqp->nodeid, "plabvm", 6) == 0) {
		    char *cp = index(reqp->nodeid, '-');
		    if (cp && *(cp+1))
			idx += (atoi(cp+1) * 10);
		}

		bufp += OUTPUT(bufp, ebufp - bufp,
			       "TRACE LINKNAME=%s IDX=%d MAC0=%s MAC1=%s "
			       "VNODE=%s VNODE_MAC=%s "
			       "TRACE_TYPE=%s TRACE_EXPR='%s' "
			       "TRACE_SNAPLEN=%s\n",
			       row[0], idx,
			       (row[1] ? row[1] : ""),
			       (row[2] ? row[2] : ""),
			       row[3], row[4],
			       row[5], row[6], row[7]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("TRACEINFO: %s", buf);
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Acquire plab node elvind port update.
 *
 * Since there is (currently) no way to hard reserve a port on a plab node
 * we might bind to a non-default port, and so must track this so that
 * client vservers on the plab node know where to connect.
 *
 * XXX: should make sure it's the service slice reporting this.
 */
COMMAND_PROTOTYPE(doelvindport)
{
	char		buf[MYBUFSIZE];
	unsigned int	elvport = 0;

	if (sscanf(rdata, "%u",
		   &elvport) != 1) {
		strncpy(buf, rdata, 64);
		error("ELVIND_PORT: %s: Bad arguments: %s...\n", reqp->nodeid,
                      buf);
		return 1;
	}

	/*
         * Now shove the elvin port # we got into the db.
	 */
	mydb_update("replace into node_attributes "
                    " values ('%s', '%s', %u)",
		    reqp->pnodeid, "elvind_port", elvport);

	return 0;
}

/*
 * Return all event keys on plab node to service slice.
 */
COMMAND_PROTOTYPE(doplabeventkeys)
{
	char		buf[MYBUFSIZE];
        int             nrows = 0;
	MYSQL_RES	*res;
	MYSQL_ROW	row;

        if (!reqp->isplabsvc) {
                error("PLABEVENTKEYS: Unauthorized request from node: %s\n",
                      reqp->vnodeid);
                return 1;
        }

        res = mydb_query("select e.pid, e.eid, e.eventkey from reserved as r "
                         " left join nodes as n on r.node_id = n.node_id "
                         " left join experiments as e on r.pid = e.pid "
                         "  and r.eid = e.eid "
                         " where n.phys_nodeid = '%s' ",
                         3, reqp->pnodeid);

	if ((nrows = (int)mysql_num_rows(res)) == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);

		OUTPUT(buf, sizeof(buf),
                       "PID=%s EID=%s KEY=%s\n",
                       row[0], row[1], row[2]);

		client_writeback(sock, buf, strlen(buf), tcp);
		nrows--;
		if (verbose)
			info("PLABEVENTKEYS: %s\n", buf);
	}
	mysql_free_result(res);

	return 0;
}

/*
 * Return a map of pc node id's with their interface MAC addresses.
 */
COMMAND_PROTOTYPE(dointfcmap)
{
	char		buf[MYBUFSIZE] = {0}, pc[8] = {0};
        int             nrows = 0, npcs = 0;
	MYSQL_RES	*res;
	MYSQL_ROW	row;

        res = mydb_query("select node_id, mac from interfaces "
			 "where node_id like 'pc%%' order by node_id",
                         2);

	nrows = (int)mysql_num_rows(res);
	if (verbose)
		info("intfcmap: nrows %d\n", nrows);
	if (nrows == 0) {
		mysql_free_result(res);
		return 0;
	}

	while (nrows) {
		row = mysql_fetch_row(res);
		/* if (verbose) info("intfcmap: %s %s\n", row[0], row[1]); */

		/* Consolidate interfaces on the same pc into a single line. */
		if (pc[0] == '\0') {
			/* First pc. */
			strncpy(pc, row[0], 8);
			snprintf(buf, MYBUFSIZE, "%s %s", row[0], row[1]);
		} else if (strncmp(pc, row[0], 8) == 0 ) {
			/* Same pc, append. */
			strcat(buf, " ");
			strcat(buf, row[1]);
		} else {
			/* Different pc, dump this one and start the next. */
			strcat(buf, "\n");
			client_writeback(sock, buf, strlen(buf), tcp);
			npcs++;

			strncpy(pc, row[0], 8);
			snprintf(buf, MYBUFSIZE, "%s %s", row[0], row[1]);
		}
		nrows--;
	}
	strcat(buf, "\n");
	client_writeback(sock, buf, strlen(buf), tcp); /* Dump the last one. */
	npcs++;
	if (verbose)
		info("intfcmap: npcs %d\n", npcs);

	mysql_free_result(res);

	return 0;
}


/*
 * Return motelog info for this node.
 */
COMMAND_PROTOTYPE(domotelog)
{
    MYSQL_RES *res;
    MYSQL_ROW row;
    char buf[MYBUFSIZE];
    int nrows;

    res = mydb_query("select vnm.logfileid,ml.classfilepath,ml.specfilepath "
		     "from virt_node_motelog as vnm "
		     "left join motelogfiles as ml on vnm.pid=ml.pid "
		     "  and vnm.logfileid=ml.logfileid "
		     "left join reserved as r on r.vname=vnm.vname "
		     "  and vnm.eid=r.eid and vnm.pid=r.pid "
		     "where vnm.pid='%s' and vnm.eid='%s' "
		     "  and vnm.vname='%s'",
		     3,reqp->pid,reqp->eid,reqp->nickname);

    if (!res) {
	error("MOTELOG: %s: DB Error getting virt_node_motelog\n",
	      reqp->nodeid);
    }

    /* no motelog stuff for this node */
    if ((nrows = (int)mysql_num_rows(res)) == 0) {
	mysql_free_result(res);
	return 0;
    }

    while (nrows) {
	row = mysql_fetch_row(res);

	/* only specfilepath can possibly be null */
	OUTPUT(buf, sizeof(buf),
	       "MOTELOGID=%s CLASSFILE=%s SPECFILE=%s\n",
	       row[0],row[1],row[2]);
	client_writeback(sock, buf, strlen(buf), tcp);

	--nrows;
	if (verbose) {
	    info("MOTELOG: %s", buf);
	}
    }

    mysql_free_result(res);
    return 0;
}

/*
 * Return motelog info for this node.
 */
COMMAND_PROTOTYPE(doportregister)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE], service[128];
	int		rc, port;

	/*
	 * Dig out the service and the port number.
	 * Need to be careful about not overflowing the buffer.
	 */
	sprintf(buf, "%%%ds %%d", (int)sizeof(service));
	rc = sscanf(rdata, buf, service, &port);

	if (rc == 0) {
		error("doportregister: No service specified!\n");
		return 1;
	}
	if (rc != 1 && rc != 2) {
		error("doportregister: Wrong number of arguments!\n");
		return 1;
	}

	/* No special characters means it will fit */
	mysql_escape_string(buf, service, strlen(service));
	if (strlen(buf) >= sizeof(service)) {
		error("doportregister: Illegal chars in service!\n");
		return 1;
	}
	strcpy(service, buf);

	/*
	 * Single argument, lookup up service.
	 */
	if (rc == 1) {
		res = mydb_query("select port,node_id "
				 "   from port_registration "
				 "where pid='%s' and eid='%s' and "
				 "      service='%s'",
				 2, reqp->pid, reqp->eid, service);

		if (!res) {
			error("doportregister: %s: "
			      "DB Error getting registration for %s\n",
			      reqp->nodeid, service);
			return 1;
		}
		if ((int)mysql_num_rows(res) > 0) {
			row = mysql_fetch_row(res);
			OUTPUT(buf, sizeof(buf), "PORT=%s NODEID=%s.%s\n",
			       row[0], row[1], OURDOMAIN);
			client_writeback(sock, buf, strlen(buf), tcp);
			if (verbose)
				info("PORTREG: %s: %s", reqp->nodeid, buf);
		}
		mysql_free_result(res);
		return 0;
	}

	/*
	 * If port is zero, clear it from the DB
	 */
	if (port == 0) {
		mydb_update("delete from port_registration  "
			    "where pid='%s' and eid='%s' and "
			    "      service='%s'",
			    reqp->pid, reqp->eid, service);
	}
	else {
		/*
		 * Register port for the service.
		 */
		if (mydb_update("replace into port_registration set "
				"     pid='%s', eid='%s', exptidx=%d, "
				"     service='%s', node_id='%s', port='%d'",
				reqp->pid, reqp->eid, reqp->exptidx,
				service, reqp->nodeid, port)) {
			error("doportregister: %s: DB Error setting %s=%d!\n",
			      reqp->nodeid, service, port);
			return 1;
		}
	}
	if (verbose)
		info("PORTREG: %s: %s=%d\n", reqp->nodeid, service, port);

	return 0;
}

/*
 * Ugh. At Utah, boss and ops are in the DB in the "normal way"
 * (they have nodes and interfaces table entries). But by default,
 * other testbeds won't. The quick fix was to put the necessary into
 * into sitevars instead (gw info was already there).
 *
 * When we normalize boss/ops/fs, we can undef this.
 */
#define GET_SERVERS_FROM_SITEVARS

/*
 * Return MAC/IP (ARP) information for a node's "peers" on the control net.
 * We always return info for the control net gateway (if there is one).
 *
 * Right now we just support calls by subbosses to return the info for
 * the set of nodes they control and Emulab servers.
 *
 * Note that this should be an SSL-only call.
 */
COMMAND_PROTOTYPE(doarpinfo)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows, xenvifrouting = 0;
	char		buf[MYBUFSIZE], arptype[32];
#ifdef GET_SERVERS_FROM_SITEVARS
	struct serv {
		char name[8];
		char ip[16];
		char mac[18];
		int hits;
	} servs[4];
	int i;
#endif

	if (!isssl) {
		error("doarpinfo: %s: non-SSL request ignored\n",
		      reqp->nodeid);
		return 1;
	}

	/*
	 * We only report info to callers on the node control net,
	 * since the included IP and MAC values are only for that net.
	 */
	if ((reqp->client.s_addr & cmask.s_addr) != cnet.s_addr)
		return 0;

	/*
	 * See if we are even doing ARP lockdown of any sort.
	 * If not, return "none" to the user.
	 */
	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='general/arplockdown'", 2);
	if (!res || (int)mysql_num_rows(res) == 0) {
		error("ARPINFO: general/arplockdown sitevar "
		      "not set, assuming 'none'\n");
		if (res)
			mysql_free_result(res);
		goto noinfo;
	}
	row = mysql_fetch_row(res);
	if (!row[0] || !row[0][0]) {
		if (!row[1] || !row[1][0]) {
			mysql_free_result(res);
			goto noinfo;
		}
		strncpy(arptype, row[1], sizeof(arptype));
	} else
		strncpy(arptype, row[0], sizeof(arptype));
	mysql_free_result(res);
	if (strcmp(arptype, "none") != 0 &&
	    strcmp(arptype, "static") != 0 &&
	    strcmp(arptype, "staticonly") != 0) {
		error("ARPINFO: general/arplockdown sitevar "
		      "has invalid value '%s', using 'none' instead\n");
		goto noinfo;
	}
	if (0 && strcmp(arptype, "none") == 0) {
	noinfo:
		OUTPUT(buf, sizeof(buf), "ARPTYPE=none\n");
		client_writeback(sock, buf, strlen(buf), tcp);
		return 0;
	}

	/*
	 * Look for xenvifrouting sitevar
	 */
	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='general/xenvifrouting'", 2);
	if (!res || (int)mysql_num_rows(res) == 0) {
		error("ARPINFO: general/xenvifrouting sitevar "
		      "not set, assuming no\n");
		if (res)
			mysql_free_result(res);
	}
	row = mysql_fetch_row(res);
	if (row[0] && row[0][0]) {
		xenvifrouting = 1;
	}
	mysql_free_result(res);

	/*
	 * Get the GW and primary server (boss, ops, fs) info.
	 */
#ifdef GET_SERVERS_FROM_SITEVARS
	memset(servs, 0, sizeof(servs));
	res = mydb_query("select name,value from sitevariables where "
			 " name like 'node/%%_ip'", 2);
	if (!res) {
		error("doarpinfo: %s: DB Error getting server info\n",
		      reqp->nodeid);
		return 1;
	}
	for (nrows = (int)mysql_num_rows(res); nrows > 0; nrows--) {
		row = mysql_fetch_row(res);
		if (row && row[1] && row[1][0]) {
			struct in_addr naddr;
			inet_aton(row[1], &naddr);

#if 0 /* we do need to report ourselves */
			/* Do not report ourselves */
			if (reqp->client.s_addr == naddr.s_addr)
				continue;
#endif

			/* and only for servers on the node control net */
			naddr.s_addr &= cmask.s_addr;
			if (naddr.s_addr != cnet.s_addr)
				continue;

			/* record the server name/IP */
			if (strncmp(row[0], "node/gw", 7) == 0) {
				strncpy(servs[0].name, "gw",
					sizeof(servs[0].name));
				strncpy(servs[0].ip, row[1],
					sizeof(servs[0].ip));
				servs[0].hits++;
				continue;
			}
			if (strncmp(row[0], "node/boss", 9) == 0) {
				strncpy(servs[1].name, "boss",
					sizeof(servs[1].name));
				strncpy(servs[1].ip, row[1],
					sizeof(servs[1].ip));
				servs[1].hits++;
				continue;
			}
			if (strncmp(row[0], "node/ops", 8) == 0) {
				strncpy(servs[2].name, "ops",
					sizeof(servs[2].name));
				strncpy(servs[2].ip, row[1],
					sizeof(servs[2].ip));
				servs[2].hits++;
				continue;
			}
			if (strncmp(row[0], "node/fs", 7) == 0) {
				strncpy(servs[3].name, "fs",
					sizeof(servs[3].name));
				strncpy(servs[3].ip, row[1],
					sizeof(servs[3].ip));
				servs[3].hits++;
				continue;
			}
		}
	}
	mysql_free_result(res);

	/* now the mac info */
	res = mydb_query("select name,value from sitevariables where "
			 " name like 'node/%%_mac'", 2);
	if (!res) {
		error("doarpinfo: %s: DB Error getting server info\n",
		      reqp->nodeid);
		return 1;
	}
	for (nrows = (int)mysql_num_rows(res); nrows > 0; nrows--) {
		row = mysql_fetch_row(res);
		if (row && row[1] && row[1][0]) {
			char macbuf[18];

			/* XXX ugh, nuke any ':'s */
			strncpy(macbuf, row[1], sizeof(macbuf));
			if (index(row[1], ':')) {
				int x1, x2, x3, x4, x5, x6;
				if (sscanf(row[1], "%2x:%2x:%2x:%2x:%2x:%2x",
					   &x1, &x2, &x3, &x4, &x5, &x6) == 6)
					snprintf(macbuf, sizeof(macbuf),
						 "%02x%02x%02x%02x%02x%02x",
						 x1, x2, x3, x4, x5, x6);
			}

			/* record the server mac */
			if (strncmp(row[0], "node/gw", 7) == 0) {
				strncpy(servs[0].mac, macbuf,
					sizeof(servs[0].mac));
				servs[0].hits++;
				continue;
			}
			if (strncmp(row[0], "node/boss", 9) == 0) {
				strncpy(servs[1].mac, macbuf,
					sizeof(servs[1].mac));
				servs[1].hits++;
				continue;
			}
			if (strncmp(row[0], "node/ops", 8) == 0) {
				strncpy(servs[2].mac, macbuf,
					sizeof(servs[2].mac));
				servs[2].hits++;
				continue;
			}
			if (strncmp(row[0], "node/fs", 7) == 0) {
				strncpy(servs[3].mac, macbuf,
					sizeof(servs[3].mac));
				servs[3].hits++;
				continue;
			}
		}
	}
	mysql_free_result(res);

	/* put out the type before anything else */
	OUTPUT(buf, sizeof(buf), "ARPTYPE=%s\n", arptype);
	client_writeback(sock, buf, strlen(buf), tcp);

	/* finally, put them out */
	for (i = 0; i < 4; i++) {
		/* gotta have both IP and MAC info */
		if (servs[i].hits != 2)
			continue;

		/* XXX if ops/fs are the same, don't output fs */
		if (i == 3 && servs[2].hits == 2 &&
		    strcmp(servs[2].ip, servs[3].ip) == 0)
			continue;

		OUTPUT(buf, sizeof(buf),
		       "SERVER=%s CNETIP=%s CNETMAC=%s\n",
		       servs[i].name, servs[i].ip, servs[i].mac);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
#else
	res = mydb_query("select value from sitevariables "
			 "where name='node/gw_mac'", 1);
	if (!res) {
		error("doarpinfo: %s: DB Error getting server info\n",
		      reqp->nodeid);
		return 1;
	}

	/* put out the type before anything else */
	OUTPUT(buf, sizeof(buf), "ARPTYPE=%s\n", arptype);
	client_writeback(sock, buf, strlen(buf), tcp);

	if (mysql_num_rows(res) > 0) {
		row = mysql_fetch_row(res);
		if (row && row[0]) {
			char macbuf[18];

			/* XXX ugh, nuke any ':'s */
			strncpy(macbuf, row[0], sizeof(macbuf));
			if (index(row[0], ':')) {
				int x1, x2, x3, x4, x5, x6;
				if (sscanf(row[0], "%2x:%2x:%2x:%2x:%2x:%2x",
					   &x1, &x2, &x3, &x4, &x5, &x6) == 6)
					snprintf(macbuf, sizeof(macbuf),
						 "%02x%02x%02x%02x%02x%02x",
						 x1, x2, x3, x4, x5, x6);
			}
			OUTPUT(buf, sizeof(buf),
			       "SERVER=gw CNETIP=%s CNETMAC=%s\n",
			       CONTROL_ROUTER_IP, macbuf);
			client_writeback(sock, buf, strlen(buf), tcp);
		}
	}
	mysql_free_result(res);
#endif

	/*
	 * Check for other servers that are normal testbed nodes
	 * (i.e., have nodes and interfaces table entries).
	 */
	res = mydb_query("select node_id,IP,mac from interfaces "
			 "where role='ctrl' and ("
#ifndef GET_SERVERS_FROM_SITEVARS
			 "node_id in ('boss','ops','fs') or "
#endif
			 " node_id in "
			 " (select distinct subboss_id from subbosses "
			 "  where disabled=0))", 3);
	if (!res) {
		error("doarpinfo: %s: DB Error getting server info\n",
		      reqp->nodeid);
		return 1;
	}

	for (nrows = (int)mysql_num_rows(res); nrows > 0; nrows--) {
		struct in_addr naddr;

		row = mysql_fetch_row(res);
		inet_aton(row[1], &naddr);

#if 0 /* we do need to report ourselves */
		/* Do not report ourselves */
		if (reqp->client.s_addr == naddr.s_addr)
			continue;
#endif

		/* and only for servers on the node control net */
		naddr.s_addr &= cmask.s_addr;
		if (naddr.s_addr != cnet.s_addr)
			continue;

		OUTPUT(buf, sizeof(buf),
		       "SERVER=%s CNETIP=%s CNETMAC=%s\n",
		       row[0], row[1], row[2]);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);

	/*
	 * Subbosses get info for all nodes they provide a service for. 
	 */
	if (strcmp(reqp->erole, "subboss") == 0) {
		res = mydb_query("select distinct i.node_id,i.IP,i.mac from "
				 "interfaces as i,subbosses as s where "
				 "s.node_id=i.node_id and "
				 "s.subboss_id='%s' and s.disabled=0 and "
				 "i.role='ctrl'", 3, reqp->nodeid);
		if (!res) {
			error("doarpinfo: %s: DB Error getting"
			      "control interface info\n", reqp->nodeid);
			return 1;
		}
		for (nrows = (int)mysql_num_rows(res); nrows > 0; nrows--) {
			row = mysql_fetch_row(res);
			if (!row[0] || !row[0][0] ||
			    !row[1] || !row[1][0] ||
			    !row[2] || !row[2][0])
				continue;
			OUTPUT(buf, sizeof(buf),
			       "HOST=%s CNETIP=%s CNETMAC=%s\n",
			       row[0], row[1], row[2]);
			client_writeback(sock, buf, strlen(buf), tcp);
		}

		mysql_free_result(res);
	}

	/*
	 * Ops/fs nodes: in addition to other servers on the control
	 * net, we also provide info for all testnodes and virtnodes on
	 * either the node control net or the "jail" net.
	 *
	 * XXX right now we identify them by its name in the DB.
	 * Maybe not the best thing...
	 */
	else if (strcmp(reqp->nodeid, "ops") == 0 ||
		 strcmp(reqp->nodeid, "fs") == 0) {
		struct in_addr nnet;

		res = mydb_query(
			"select i.node_id,i.IP,i.mac,n.role,"
			"   FIND_IN_SET('xen-host',ov.osfeatures) as isxen, "
			"   vn.attrvalue as vif,ip.mac "
			"from interfaces as i,nodes as n "
			"left join reserved as r on r.node_id=n.node_id "
			"left join nodes as np on np.node_id=n.phys_nodeid "
			"left join os_info as o on o.osid=np.def_boot_osid "
			 "left join os_info_versions as ov on "
			 "     ov.osid=o.osid and ov.vers=o.version "
			"left join reserved as rp on rp.node_id=n.phys_nodeid "
			"left join interfaces as ip on "
			"     ip.node_id=rp.node_id and ip.role='ctrl' "
			"left join virt_node_attributes as vn on "
			"     vn.exptidx=rp.exptidx and vn.vname=rp.vname and "
			"     vn.attrkey='xenvifrouting' "
			"where n.node_id=i.node_id and "
			"      (i.role='ctrl' or i.role='mngmnt') and "
			"      i.mac not like '000000%%' and "
			"      (n.role='testnode' or n.role='virtnode')", 7);
		if (!res) {
			error("doarpinfo: %s: DB Error getting"
			      "control interface info\n", reqp->nodeid);
			return 1;
		}

		for (nrows = (int)mysql_num_rows(res); nrows > 0; nrows--) {
			char *cnetmac;
			
			row = mysql_fetch_row(res);
			if (!row[0] || !row[0][0] ||
			    !row[1] || !row[1][0] ||
			    !row[2] || !row[2][0] ||
			    !row[3] || !row[3][0])
				continue;
			/*
			 * Make sure node is on the node control net
			 * or is a virtnode in the "jail" net.
			 */
			if (!inet_aton(row[1], &nnet) ||
			    !((nnet.s_addr & cmask.s_addr) == cnet.s_addr ||
			      (strcmp(row[3], "virtnode") == 0 &&
			       (nnet.s_addr & jmask.s_addr) == jnet.s_addr)))
				continue;
			cnetmac = row[2];
			
			/*
			 * If virtnode on a xen-host doing xenvifrouting,
			 * then we want to return the mac of the physical
			 * host instead of the virtual host.
			 */
			if (strcmp(row[3], "virtnode") == 0 &&
			    /* isxen != 0 */
			    row[4] && row[4][0] && atoi(row[4]) &&
			    /* xenvifrouting != NULL */
			    (row[5] || xenvifrouting) &&
			    /* mac is set, should always be set though */
			    row[6]) {
				cnetmac = row[6];
			}
			
			OUTPUT(buf, sizeof(buf),
			       "HOST=%s CNETIP=%s CNETMAC=%s\n",
			       row[0], row[1], cnetmac);
			client_writeback(sock, buf, strlen(buf), tcp);
		}

		mysql_free_result(res);
	}

	return 0;
}

/*
 * Return dhcpd configuration as a set of key-value pairs, one node
 * per line.
 */
COMMAND_PROTOTYPE(dodhcpdconf)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int nodes, nrows, remain, rc;
	char buf[MYBUFSIZE];
	char *b;

	res = mydb_query("select erole from reserved "
			 "where node_id='%s' and erole='subboss'",
			 1, reqp->nodeid);

	if (!res) {
		error("dodhcpconf: %s: "
		      "DB Error checking for reserved.erole\n",
		      reqp->nodeid);
		return 1;
	}

	/* node isn't a subboss, so nothing to return */
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}
	mysql_free_result(res);

	res = mydb_query("select n.node_id,n.pxe_boot_path,i.IP,i.mac,n.type,"
			 "r.eid,r.pid,r.inner_elab_role,r.inner_elab_boot,"
			 "r.plab_role,r.plab_boot,n.next_pxe_boot_path "
			 "from nodes as n "
			 "left join subbosses as s on n.node_id=s.node_id "
			 "left join interfaces as i on n.node_id=i.node_id "
			 "left join reserved as r on n.node_id=r.node_id "
			 "where s.subboss_id='%s' and "
	                 "s.service='dhcp' and s.disabled=0 and i.role='ctrl' "
			 "order by n.priority", 12, reqp->nodeid);
	if (!res) {
		error("dodhcpconf: %s: DB Error getting dhcpd configuration\n",
		      reqp->nodeid);
		return 1;
	}

	nodes = (int)mysql_num_rows(res);
	while (nodes > 0) {
		char tftp_server[16];
		char bootinfo_server[16];
		int elabinelab_singlenet = 0;
		int inner_elab_boot = 0;
		int plab_boot = 0;
		MYSQL_RES *res2;

		memset(tftp_server, 0, sizeof(tftp_server));
		memset(bootinfo_server, 0, sizeof(bootinfo_server));

		rc = 0;

		b = buf;
		remain = sizeof(buf);

		row = mysql_fetch_row(res);
		rc = snprintf(b, remain, "HOSTNAME=%s MAC=%s IP=%s",
			      row[0], row[3], row[2]);
		if (rc < 0) {
			error("dodhcpdconf: error creating output\n");
			mysql_free_result(res);
			return 1;
		}

		b += rc;
		remain -= rc;

		/* Check to see if this is an inner elab node or a plab node.
		 * if so, use the boss/boss+router/plc for this experiment as
		 * the boot server.
		 */
		if (row[8]) {
			inner_elab_boot = atoi(row[8]);
		}
		if (row[10]) {
			plab_boot = atoi(row[10]);
		}

		if (inner_elab_boot) {
			res2 = mydb_query("select elabinelab_singlenet "
					  "from experiments where "
					  "eid='%s' and pid='%s'",
					  1, row[5], row[6]);
			if (!res2) {
				error("dodhcpconf: %s: DB Error getting "
				      "experiment info for %s/%s\n",
				      reqp->nodeid, row[6], row[5]);
				mysql_free_result(res);
				return 1;
			}

			if (mysql_num_rows(res2)) {
				MYSQL_ROW row2 = mysql_fetch_row(res2);
				elabinelab_singlenet = atoi(row2[0]);
			}
			mysql_free_result(res2);

		}
		if ((inner_elab_boot && row[7] && !strcmp(row[7], "node")) ||
		    (plab_boot && row[9] && !strcmp(row[9], "node"))) {
			res2 = mydb_query("select i.IP from "
					  "reserved as r, interfaces as i "
					  "where r.node_id=i.node_id and "
					  "r.eid='%s' and r.pid='%s' and "
					  "(r.inner_elab_role='boss' or "
					  "r.inner_elab_role='boss+router' or "
					  "r.inner_elab_role='boss+fs+router' or "
					  "r.plab_role='plc') and i.role='ctrl'",
					  1, row[5], row[6]);
			if (!res2) {
				error("dodhcpconf: %s: DB Error getting "
				      "interface info for %s/%s\n",
				      reqp->nodeid, row[6], row[5]);
				mysql_free_result(res);
				return 1;
			}

			if (mysql_num_rows(res2)) {
				MYSQL_ROW row2 = mysql_fetch_row(res2);
				strlcpy(tftp_server, row2[0],
					sizeof(tftp_server));
				/* XXX should server do bootinfo as well? */
				strlcpy(bootinfo_server, row2[0],
					sizeof(bootinfo_server));
			}
			mysql_free_result(res2);
		}

		res2 = mydb_query("select s.subboss_id,s.service,i.IP "
				  "from subbosses as s, interfaces as i "
				  "where s.node_id='%s' and "
				  "s.service!='dhcp' and s.disabled=0 "
		                  "and s.subboss_id=i.node_id and i.role='ctrl'",
				  3, row[0]);
		if (!res) {
			error("dodhcpconf: %s: "
			      "DB Error getting subbosses for %s\n",
			      reqp->nodeid, row[0]);
			mysql_free_result(res);
			return 1;
		}

		nrows = (int)mysql_num_rows(res2);
		while (nrows > 0) {
			MYSQL_ROW row2;

			row2 = mysql_fetch_row(res2);
			if (strcmp(row2[1], "tftp") == 0) {
				if (tftp_server[0] == '\0') {
					strlcpy(tftp_server, row2[2],
						sizeof(tftp_server));
				}
			} else if (strcmp(row2[1], "bootinfo") == 0) {
				if (bootinfo_server[0] == '\0') {
					strlcpy(bootinfo_server, row2[2],
						sizeof(bootinfo_server));
				}
			}

			if (rc < 0) {
				error("dodhcpdconf: error creating output\n");
				mysql_free_result(res);
				return 1;
			}

			nrows--;
		}

		mysql_free_result(res2);

		if (inner_elab_boot) {
			rc = snprintf(b, remain,
				      " INNER_ELAB_BOOT=1 INNER_ELAB_ROLE=%s",
				      row[7] ? row[7] : "");
			b += rc;
			remain -= rc;
			if (elabinelab_singlenet) {
				rc = snprintf(b, remain, " SINGLENET=1");
				b += rc;
				remain -= rc;
			}
		} else if (plab_boot) {
			rc = snprintf(b, remain, " PLAB_BOOT=1");
			b += rc;
			remain -= rc;
		}

		if (tftp_server[0]) {
			rc = snprintf(b, remain, " TFTP=%s", tftp_server);
			b += rc;
			remain -= rc;
		}

		if (bootinfo_server[0]) {
			rc = snprintf(b, remain, " BOOTINFO=%s", bootinfo_server);
			b += rc;
			remain -= rc;
		}

		if (row[11] && row[11][0]) {
			rc = snprintf(b, remain, " FILENAME=\"%s\"", row[11]);

			if (rc < 0) {
				error("dodhcpdconf: error creating output\n");
				mysql_free_result(res);
				return 1;
			}

			b += rc;
			remain -= rc;
		} else if (row[1] && row[1][0]) {
			rc = snprintf(b, remain, " FILENAME=\"%s\"", row[1]);

			if (rc < 0) {
				error("dodhcpdconf: error creating output\n");
				mysql_free_result(res);
				return 1;
			}

			b += rc;
			remain -= rc;
		} else {
			MYSQL_ROW row2;

			/* See if there is a default value for the node */
			res2 = mydb_query("select attrvalue from "
					  "node_attributes where "
			                  "attrkey='pxe_boot_path' and "
					  "node_id='%s'", 1, row[0]);
			if (res2 && (int)mysql_num_rows(res2) == 0) {
				/* or for the node type */
				mysql_free_result(res2);
				res2 = mydb_query("select attrvalue from "
						  "node_type_attributes where "
						  "attrkey='pxe_boot_path' and "
						  "type = '%s'", 1, row[4]);
			}
			if (!res2) {
				error("dodhcpconf: %s: DB Error getting "
				      "pxe_boot_path from attributes for %s\n",
				      reqp->nodeid, row[0]);
				mysql_free_result(res);
				return 1;
			}

			if ((int)mysql_num_rows(res2)) {
				row2 = mysql_fetch_row(res2);
				rc = 0;

				if (row2[0] != NULL) {
					rc = snprintf(b, remain,
						      " FILENAME=\"%s\"",
						      row2[0]);
				}

				if (rc < 0) {
					error("dodhcpdconf: error creating output\n");
					mysql_free_result(res2);
					mysql_free_result(res);
					return 1;
				}

				b += rc;
				remain -= rc;
			}

			mysql_free_result(res2);
		}

		snprintf(b, remain, "\n");

		client_writeback(sock, buf, strlen(buf), tcp);
		if (verbose)
			info("DHCPDCONF: %s: %s", reqp->nodeid, buf);

		nodes--;
	}

	mysql_free_result(res);
	return 0;
}

/*
 * Return bootwhat info using the bootinfo routine from the pxe directory.
 * This is used by the dongle boot on widearea nodes. Better to use tmcd
 * then open up another daemon to the widearea.
 */
COMMAND_PROTOTYPE(dobootwhat)
{
	boot_info_t	boot_info;
	boot_what_t	*boot_whatp = (boot_what_t *) &boot_info.data;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];

	boot_info.opcode  = BIOPCODE_BOOTWHAT_REQUEST;
	boot_info.version = BIVERSION_CURRENT;

	if(strlen(reqp->privkey) > 1) { /* We have a private key, so prepare bootinfo for it. */
		boot_info.opcode = BIOPCODE_BOOTWHAT_KEYED_REQUEST;
		strncpy(boot_info.data, reqp->privkey, PRIVKEY_LEN);
	}

	if (bootinfo(reqp->client, (reqp->isvnode) ? reqp->nodeid : NULL,
		     &boot_info, (void *) reqp,
		     (reqp->isvnode) ? 1 : 0, NULL)) {
		OUTPUT(buf, sizeof(buf), "STATUS=failed\n");
	}
	else {
		bufp += OUTPUT(bufp, ebufp - bufp,
			      "STATUS=success TYPE=%d",
			      boot_whatp->type);

		/*
		 * XXX older, "cdboot" parsers for the bootwhat info will
		 * blow up if FLAGS= is included anywhere on the line.
		 */
		if (vers > 34)
			bufp += OUTPUT(bufp, ebufp - bufp, " FLAGS=%d",
				       boot_whatp->flags);

		if (boot_whatp->type == BIBOOTWHAT_TYPE_PART) {
			bufp += OUTPUT(bufp, ebufp - bufp, " WHAT=%d",
				      boot_whatp->what.partition);
		}
		else if (boot_whatp->type == BIBOOTWHAT_TYPE_SYSID) {
			bufp += OUTPUT(bufp, ebufp - bufp, " WHAT=%d",
				      boot_whatp->what.sysid);
		}
		else if (boot_whatp->type == BIBOOTWHAT_TYPE_MFS) {
			bufp += OUTPUT(bufp, ebufp - bufp, " WHAT=%s",
				      boot_whatp->what.mfs);
		}
		if (strlen(boot_whatp->cmdline)) {
			bufp += OUTPUT(bufp, ebufp - bufp, " CMDLINE='%s'",
				      boot_whatp->cmdline);
		}
		bufp += OUTPUT(bufp, ebufp - bufp, "\n");
	}
	client_writeback(sock, buf, strlen(buf), tcp);

	info("BOOTWHAT: %s: %s\n", reqp->nodeid, buf);
	return 0;
}

COMMAND_PROTOTYPE(dotpmblob)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows,i;
	unsigned long	*nlen;
	int		hex = 1;
	char		buf[MYBUFSIZE];
	char		*bufp = buf;
	char		*bufe = &buf[MYBUFSIZE];

	if (rdata)
		if (strncasecmp(rdata, "nohex", strlen("nohex")) == 0)
			hex = 0;

	/*
	 * Get the blob
	 */
	res = mydb_query("select tpmblob "
			"from node_hostkeys "
			"where node_id='%s' ",
			1, reqp->nodeid);

	if (!res) {
		error("gettpmblob: %s: DB error getting tpmblob\n",
		      reqp->nodeid);
		return 1;
	}

	nrows = mysql_num_rows(res);
	if (!nrows) {
		error("%s: no node_hostkeys info in the database!\n",
			reqp->nodeid);
		mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);
	nlen = mysql_fetch_lengths(res);
	if (!nlen || !nlen[0]) {
		mysql_free_result(res);
#if 0 /* not an error yet */
		error("%s: no TPM blob.\n", reqp->nodeid);
		return 1;
#endif
		return 0;
	}

	bufp += OUTPUT(bufp, bufe - bufp,
		       (hex ? "BLOBHEX=" : "BLOB="));
	if (hex) {
		for (i = 0;i < nlen[0];++i)
			bufp += OUTPUT(bufp, bufe - bufp,
				       "%.02x", (0xff & ((char)*(row[0]+i))));
	} else {
		for (i = 0;i < nlen[0];++i)
			bufp += OUTPUT(bufp, bufe - bufp,
				       "%c", (char)*(row[0]+i));
	}
	bufp += OUTPUT(bufp, bufe - bufp, "\n");

	client_writeback(sock, buf, bufp - buf, tcp);

	mysql_free_result(res);
	return 0;
}

COMMAND_PROTOTYPE(dotpmpubkey)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		nrows;
	char		buf[MYBUFSIZE];

	res = mydb_query("select tpmx509 "
			"from node_hostkeys "
			"where node_id='%s' ",
			1, reqp->nodeid);
	if (!res) {
		error("gettpmpub: %s: DB error getting tpmx509\n",
			reqp->nodeid);
		return 1;
	}
	nrows = mysql_num_rows(res);
	if (!nrows) {
		error("%s: no node_hostkeys info in the database!\n",
			reqp->nodeid);
		mysql_free_result(res);
		return 1;
	}

	row = mysql_fetch_row(res);
	if (!row || !row[0]) {
		mysql_free_result(res);
#if 0 /* not an error yet */
		error("%s: no x509 cert.\n", reqp->nodeid);
		return 1;
#endif
		return 0;
	}

	OUTPUT(buf, sizeof(buf), "TPMPUB=%s\n", row[0]);

	client_writeback(sock, buf, strlen(buf), tcp);

	mysql_free_result(res);
	return 0;
}

COMMAND_PROTOTYPE(dotpmdummy)
{
	char buf[MYBUFSIZE];

	OUTPUT(buf, sizeof(buf),
	    "You'd better be using the TPM, you twicky wabbit!\n");

	client_writeback(sock, buf, strlen(buf), tcp);

	return 0;
}

/*
 * Return the virt_node_attributes for a node.
 */
COMMAND_PROTOTYPE(donodeattributes)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	int		nrows;

	if (! reqp->allocated) {
		return 0;
	}
	bzero(buf, sizeof(buf));

	/*
	 * Get all the *virt* attributes for the node.
	 */
	res = mydb_query("select attrkey,attrvalue "
			 "   from virt_node_attributes "
			 "where exptidx=%d and vname='%s'",
			 2, reqp->exptidx, reqp->nickname);
	if (res) {
		nrows = (int)mysql_num_rows(res);
		while (bufp < ebufp && nrows--) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0] && row[1])
				bufp += OUTPUT(bufp, ebufp - bufp,
					       "%s=\"%s\"\n",
					       row[0], row[1]);
		}
		mysql_free_result(res);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	/*
	 * Brutal hack to get this site variable to dedicated XEN
	 * physical hosts since they are added by the mapper, and have no
	 * virt table entries.
	 */
	res = mydb_query("select node_id from nodes as n "
			 "left join os_info as o on o.osid=n.def_boot_osid "
			 "left join os_info_versions as ov on "
			 "     ov.osid=o.osid and ov.vers=o.version "
			 "where node_id='%s' and "
			 "      FIND_IN_SET('xen-host',ov.osfeatures)",
			 1, reqp->nodeid);
	if (!res || (int)mysql_num_rows(res) == 0) {
		if (res)
			mysql_free_result(res);
		return 0;
	}
	res = mydb_query("select value,defaultvalue from sitevariables "
			"where name='general/xenvifrouting'", 2);
	if (!res || (int)mysql_num_rows(res) == 0) {
		if (res)
			mysql_free_result(res);
		return 0;
	}
	row = mysql_fetch_row(res);
	if (row[0] && row[0][0]) {
		strcpy(buf, "xenvifrouting=1\n");
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);
	return 0;
}

/*
 * Return the virt_node_disks for a node.
 */
COMMAND_PROTOTYPE(dodisks)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	int		nrows;

	if (! reqp->allocated) {
		return 0;
	}
	bzero(buf, sizeof(buf));

	/*
	 * Get all the *virt* disks for the node.
	 */
	res = mydb_query("select diskname,disktype,disksize,mountpoint,"
			 "parameters,command "
			 "   from virt_node_disks "
			 "where exptidx=%d and vname='%s'",
			 6, reqp->exptidx, reqp->nickname);
	if (res) {
		nrows = (int)mysql_num_rows(res);
		while (bufp < ebufp && nrows--) {
			row = mysql_fetch_row(res);

			bufp += OUTPUT(bufp, ebufp - bufp,
				       "DISK DISKNAME=%s DISKTYPE='%s' "
				       "DISKSIZE='%s' "
				       "MOUNTPOINT='%s' PARAMETERS='%s' "
				       "COMMAND='%s'\n",
				       row[0], 
				       (row[1] ? row[1] : ""),
				       (row[2] ? row[2] : ""),
				       (row[3] ? row[3] : ""),
				       (row[4] ? row[4] : ""),
				       (row[5] ? row[5] : ""));
		}
		mysql_free_result(res);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	return 0;
}

/*
 * Return info about hardware that should be present on the node.
 * Current info looks like:
 *
 * General test info:
 *
 * TESTINFO LOGDIR=<path> COLLECT=<1|0> CHECK=<1|0>
 *
 * CPU (one line per node):
 *
 * CPUINFO SOCKETS=<#> CORES=<#> THREADS=<#> SPEED=<MHz> BITS=<32|64> HV=<1|0>
 *
 * Memory (one line per node):
 *
 * MEMINFO SIZE=<MiB>
 *
 * Disks (one DISKINFO per node, one DISKUNIT per disk):
 *
 * DISKINFO UNITS=<#>
 * DISKUNIT SN=<serial> TYPE=<PATA|SATA|...> SECSIZE=<#> \
 *    SIZE=<MB> RSPEED=<MB/s> WSPEED=<MB/s>
 *
 * Network (one NETINFO per node, one NETUNIT per interface):
 *
 * NETINFO UNITS=<#>
 * NETUNIT TYPE=<ETH|WIFI|...> ID=<mac>
 */
COMMAND_PROTOTYPE(dohwinfo)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	/* XXX "MYBUFSIZE*2" for Clemson nodes with 47 disks */
	char		buf[MYBUFSIZE*2];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	int		nrows;
	int		collect = 0, check = 0;
	char		*path = NULL;

	/* XXX only done for allocated physical nodes right now */
	if (!reqp->allocated || reqp->isvnode) {
		return 0;
	}

	/*
	 * Are we collecting, checking, or both?
	 */
	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='nodecheck/collect'", 2);
	if (res && (int)mysql_num_rows(res) > 0) {
		row = mysql_fetch_row(res);
		if (row[0] && row[0][0])
			collect = atoi(row[0]);
		else if (row[1] && row[1][0])
			collect = atoi(row[1]);
	}
	if (res)
		mysql_free_result(res);

	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='nodecheck/check'", 2);
	if (res && (int)mysql_num_rows(res) > 0) {
		row = mysql_fetch_row(res);
		if (row[0] && row[0][0])
			check = atoi(row[0]);
		else if (row[1] && row[1][0])
			check = atoi(row[1]);
	}
	if (res)
		mysql_free_result(res);

	/*
	 * If collecting, set the path
	 * XXX hardwired for now.
	 */
	if (collect) {
		path = malloc(strlen("/proj//nodecheck") +
			      strlen(reqp->pid) + 1);
		if (path)
			sprintf(path, "/proj/%s/nodecheck", reqp->pid);
	}

	bufp += OUTPUT(bufp, ebufp - bufp,
		       "TESTINFO LOGDIR=\"%s\" COLLECT=%d CHECK=%d\n",
		       (path ? path : ""), collect, check);
	client_writeback(sock, buf, strlen(buf), tcp);
	bufp = buf;
	if (path)
		free(path);

	/*
	 * CPU and memory info comes from node_type_attributes or
	 * node_attributes.
	 */

	/*
	 * Note that the union query returns key/value rows from both
	 * node_attributes and node_type_attributes. The while loop
	 * following the query chooses the last value (from node_attributes)
	 * in preference to the first for any attrkey.
	 */
	res = mydb_query("(select attrkey,attrvalue from nodes as n,"
			 " node_type_attributes as a where "
			 "   n.type=a.type and n.node_id='%s' and "
			 "   a.attrkey like 'hw_%%') "
			 "union "
			 "(select attrkey,attrvalue "
			 "   from node_attributes "
			 " where node_id='%s' and attrkey like 'hw_%%')",
			 2, reqp->nodeid, reqp->nodeid);
	if (!res) {
		error("dohwinfo: %s: DB Error getting CPU attributes!\n",
		      reqp->nodeid);
		return 1;
	}

	if ((nrows = (int)mysql_num_rows(res)) > 0) {
		int sockets, cores, threads, speed, bits, hv, memsize;

		sockets = cores = threads = speed = bits = hv = memsize = -1;
		while (nrows) {
			row = mysql_fetch_row(res);
			if (row[1] && row[1][0]) {
				char *key = row[0] + 3; /* skip "hw_" */
				char *val = row[1];

				if (strcmp(key, "cpu_sockets") == 0) {
					sockets = atoi(val);
				}
				else if (strcmp(key, "cpu_cores") == 0) {
					cores = atoi(val);
				}
				else if (strcmp(key, "cpu_threads") == 0) {
					threads = atoi(val);
				}
				else if (strcmp(key, "cpu_speed") == 0) {
					speed = atoi(val);
				}
				else if (strcmp(key, "cpu_bits") == 0) {
					bits = atoi(val);
				}
				else if (strcmp(key, "cpu_hv") == 0) {
					hv = atoi(val);
				}
				else if (strcmp(key, "mem_size") == 0) {
					memsize = atoi(val);
				}
			}
			nrows--;
		}

		bufp += OUTPUT(bufp, ebufp - bufp, "CPUINFO");
		if (sockets >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, " SOCKETS=%d",
				       sockets);
		if (cores >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, " CORES=%d",
				       cores);
		if (threads >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, " THREADS=%d",
				       threads);
		if (speed >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, " SPEED=%d",
				       speed);
		if (bits >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, " BITS=%d",
				       bits);
		if (hv >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, " HV=%d",
				       hv);
		bufp += OUTPUT(bufp, ebufp - bufp, "\n");

		if (memsize >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp, "MEMINFO SIZE=%d\n",
				       memsize);
		client_writeback(sock, buf, strlen(buf), tcp);
		bufp = buf;
	}
	mysql_free_result(res);

	/*
	 * Disk info comes from blockstores, blockstore_type_attributes, and
	 * blockstore_attributes.
	 */
	res = mydb_query("select bs.total_size,a.attrvalue,ta.attrvalue "
			 "from "
			 "  blockstores as bs,"
			 "  blockstore_type_attributes as ta,"
			 "  blockstore_attributes as a "
			 "where "
			 "  bs.bsidx=a.bsidx and bs.role='element' and "
			 "  bs.type=ta.type and ta.attrkey='protocol' and "
			 "  a.attrkey='serialnum' and node_id='%s'",
			 3, reqp->nodeid);
	if (!res) {
		error("dohwinfo: %s: DB Error getting DISK attributes!\n",
		      reqp->nodeid);
		return 1;
	}

	nrows = (int)mysql_num_rows(res);
	if (nrows)
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "DISKINFO UNITS=%d\n", nrows);

	while (nrows) {
		row = mysql_fetch_row(res);
		bufp += OUTPUT(bufp, ebufp - bufp, "DISKUNIT");

		/* SN */
		if (row[1] && row[1][0])
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " SN=\"%s\"", row[1]);

		/* TYPE */
		if (row[2] && row[2][0])
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " TYPE=\"%s\"", row[2]);

		/* SECSIZE -- XXX hardwired for now */
		bufp += OUTPUT(bufp, ebufp - bufp, " SECSIZE=512");

		/* SIZE -- convert MiB to MB */
		if (row[0] && row[0][0]) {
			long disksize;

			disksize = strtol(row[0], 0, 0);
			disksize = (long)(((long long)disksize *
					   1048576) / 1000000);
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " SIZE=%ld", disksize);
		}

		bufp += OUTPUT(bufp, ebufp - bufp, "\n");
		nrows--;
	}

	if (bufp != buf) {
		client_writeback(sock, buf, strlen(buf), tcp);
		bufp = buf;
	}
	mysql_free_result(res);

	/*
	 * Network info comes from interfaces table. Ignore:
	 *
	 *  - Obviously hacky and fake addresses: '000000xxxxxx'
	 *  - Management (role == 'mngmnt') interfaces. Currently there
	 *    is no OS visible HW for these, the corresponding MACs are
	 *    just used by the management HW.
	 *  - Infiniband (guid != NULL) interfaces. We need support on
	 *    the client side before we start sending those over.
	 */
	res = mydb_query("select mac,iface from interfaces where "
			 " mac not like '000000%%' and "
			 " role!='mngmnt' and "
			 " node_id='%s' order by iface",
			 2, reqp->nodeid);
	if (!res) {
		error("dohwinfo: %s: DB Error getting NET attributes!\n",
		      reqp->nodeid);
		return 1;
	}

	nrows = (int)mysql_num_rows(res);
	if (nrows)
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "NETINFO UNITS=%d\n", nrows);

	while (nrows) {
		row = mysql_fetch_row(res);
		bufp += OUTPUT(bufp, ebufp - bufp, "NETUNIT");

		if (row[0] && row[0][0]) {
			/* TYPE -- XXX everything it "ETH" right now */
			bufp += OUTPUT(bufp, ebufp - bufp, " TYPE=\"ETH\"");

			/* ID is MAC */
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " ID=\"%s\"", row[0]);

			bufp += OUTPUT(bufp, ebufp - bufp, "\n");
		}
		nrows--;
	}

	if (bufp != buf)
		client_writeback(sock, buf, strlen(buf), tcp);
	mysql_free_result(res);

	return 0;
}

/*
 * Collect information about node hardware.
 *
 * This overlaps quite a lot with "hwinfo" on the collection side
 * but is a little more general. Returns a series of lines:
 *
 *   COLLECT=(0|1)	Only collect stats if set to one.
 *   OUTDIR=<path>	Absolute path for a directory where output is stored
 *   PREFIX=<string>	Prefix of file name in which to write results
 *   			File names are of the form:
 *			<OUTDIR>/<NODE>/<PREFIX>-<NAME>.(out,err,status)
 *			with stdout, stderr, and exit status respectively
 *   OS=<OS> NAME=<string> CMDLINE=<cmdline>
 *			First command to run if node is running OS.
 *			OS should be one of FreeBSD, Linux, Any, or None.
 *			Output to files identified by NAME as described above.
 *   			Everything after 'CMDLINE=' is given to system().
 *   ...
 *   OS=<OS> NAME=<string> CMDLINE=<cmdline>
 *			Last command to run if node is running OS.
 *
 * Most of this info comes from sitevars:
 * 	hwcollect/interval	how often to collect new info, zero to disable
 *	hwcollect/experiment	<pid> or <pid>/<eid> that node must be in
 *	hwcollect/outputdir	collection directory
 *	hwcollect/commands	semicolon separated list of
 *				OS,NAME,CMDLINE triples
 */
COMMAND_PROTOTYPE(dohwcollect)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];
	int		nrows;
	int		interval;
	unsigned int	last = 0;
	char		*pideid, *outputdir, *commands;
	char		*bp, *cbp, *attrclause, *eid;
	struct timeval	now;

	/* Only allocated physical nodes need apply */
	if (!reqp->allocated || reqp->isvnode) {
		return 0;
	}

	/*
	 * Get our sitevars. If none, consider collection disabled.
	 */
	res = mydb_query("select name,value,defaultvalue from sitevariables "
			 "where name like 'hwcollect/%%'", 3);
	if (!res || (nrows = (int)mysql_num_rows(res)) == 0) {
		error("HWCOLLECT: no hwcollect sitevars\n");
		if (res)
			mysql_free_result(res);
		return 0;
	}

	interval = 0;
	outputdir = commands = 0;
	while (nrows) {
		row = mysql_fetch_row(res);
		if (strcmp(row[0], "hwcollect/interval") == 0) {
			if (row[1] && row[1][0])
				interval = atoi(row[1]);
			else if (row[2] && row[2][0])
				interval = atoi(row[2]);
		} else if (strcmp(row[0], "hwcollect/experiment") == 0) {
			if (row[1] && row[1][0])
				pideid = strdup(row[1]);
			else if (row[2] && row[2][0])
				pideid = strdup(row[2]);
		} else if (strcmp(row[0], "hwcollect/outputdir") == 0) {
			if (row[1] && row[1][0])
				outputdir = strdup(row[1]);
			else if (row[2] && row[2][0])
				outputdir = strdup(row[2]);

		} else if (strcmp(row[0], "hwcollect/commands") == 0) {
			if (row[1] && row[1][0])
				commands = strdup(row[1]);
			else if (row[2] && row[2][0])
				commands = strdup(row[2]);
		}
		nrows--;
	}
	mysql_free_result(res);

	bufp += OUTPUT(bufp, ebufp - bufp, "COLLECT=%d\n",
		       interval > 0 ? 1 : 0);
	if (interval <= 0 || pideid == 0 || outputdir == 0 || commands == 0) {
		client_writeback(sock, buf, strlen(buf), tcp);
		if (pideid)
			free(pideid);
		if (outputdir)
			free(outputdir);
		if (commands)
			free(commands);
		return 0;
	}

	/* Check the experiment context */
	if ((eid = strchr(pideid, '/'))) {
		*eid++ = '\0';
	}
	if (strcmp(reqp->pid, pideid) ||
	    (eid != 0 && strcmp(reqp->eid, eid))) {
		client_writeback(sock, buf, strlen(buf), tcp);
		free(pideid);
		free(outputdir);
		free(commands);
		return 0;
	}
	free(pideid);

	gettimeofday(&now, NULL);

	/* See if sufficient time has past */
	attrclause =
		"(attrkey='hwcollect_interval' or "
		" attrkey='hwcollect_last')";

	res = mydb_query("(select attrkey,attrvalue from nodes as n "
			 " left join node_type_attributes as a on "
			 "      n.type=a.type "
			 " where %s and n.node_id='%s') "
			 "union "
			 "(select attrkey,attrvalue "
			 "   from node_attributes "
			 " where %s and node_id='%s') ",
			 2, attrclause, reqp->nodeid,
			 attrclause, reqp->nodeid);

	if (res && (nrows = (int)mysql_num_rows(res) > 0)) {
		while (nrows--) {
			row = mysql_fetch_row(res);
			if (row[1] && row[1][0]) {
				if (strcmp(row[0], "hwcollect_interval") == 0)
					interval = atoi(row[1]);
				else if (strcmp(row[0], "hwcollect_last") == 0)
					last = (unsigned int)atoi(row[1]);
			}
		}
	}
	if (res)
		mysql_free_result(res);
	if (interval <= 0 || now.tv_sec < (time_t)(last + (interval*60))) {
		client_writeback(sock, buf, strlen(buf), tcp);
		free(outputdir);
		free(commands);
		return 0;
	}
	
	bufp += OUTPUT(bufp, ebufp - bufp, "OUTDIR=%s\n", outputdir);
	free(outputdir);
	
	/* XXX just use current timestamp as the prefix */
	bufp += OUTPUT(bufp, ebufp - bufp, "PREFIX=%ld-\n", now.tv_sec);

	cbp = commands;
	while ((bp = strsep(&cbp, ";")) != NULL) {
		char *os = strsep(&bp, ",");
		char *name = strsep(&bp, ",");
		char *cmdline = bp;
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "OS=%s NAME=%s CMDLINE=%s\n",
			       os, name, cmdline);
	}
	free(commands);

	client_writeback(sock, buf, strlen(buf), tcp);

	/* record that info was collected */
	mydb_update("replace into node_attributes values "
		    "('%s','hwcollect_last','%u',0)",
		    reqp->nodeid, (unsigned)now.tv_sec);

	return 0;
}

/*
 * Return info about write-back store.
 */
COMMAND_PROTOTYPE(dowbstore)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];

	if (!reqp->allocated)
		return 0;

	res = mydb_query("select eid_uuid from experiments "
			 "where pid='%s' and eid='%s'",
			 1, reqp->pid, reqp->eid);
	if (!res || (int)mysql_num_rows(res) == 0) {
		if (res)
			mysql_free_result(res);
		return 0;
	}

	row = mysql_fetch_row(res);
	if (row[0] && row[0][0]) {
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "UUID=%s PID=%s\n", row[0], reqp->pid);
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	mysql_free_result(res);

	return 0;
}

#if PROTOGENI_SUPPORT
/* ProtoGENI "geni-get" commands. */

/* Output macro to check for string overflow */
#define GOUTPUT(buf, size, format...) \
({ \
	int __count__ = snprintf((buf), (size), ##format); \
        \
        if (__count__ >= (size)) { \
		error("Not enough room in output buffer! line %d.\n", __LINE__);\
		return NULL; \
	} \
	__count__; \
})

static int dogeni( int sock, tmcdreq_t *reqp, int tcp,
		   char *( *func )( tmcdreq_t * ) ) {

    char *result = func( reqp );

    if( result ) {
	client_writeback( sock, "", 1, tcp ); /* single NUL */
	client_writeback( sock, result, strlen( result ), tcp );
	client_writeback( sock, "\n", 1, tcp );
	free( result );
	
	return 0;
    } else {
	static char error_msg[] = "\0\0internal error handling request\n";
	
	client_writeback( sock, error_msg, sizeof error_msg - 1, tcp );
	
	return 1;
    }
}

static char *geni_append( char *buf, char *buf_end, char *p ) {

    while( *p && buf < buf_end )
	*buf++ = *p++;

    if( buf >= buf_end )
	buf--;

    *buf = 0;

    return buf;
}

static char *geni_quote( char *buf, char *buf_end, char *p ) {

    if( buf < buf_end )
	*buf++ = '"';
    
    while( *p && buf < buf_end )
	if( *p == '"' ) {
	    *buf++ = '\\';
	    if( buf < buf_end )
		*buf++ = *p++;
	} else
	    *buf++ = *p++;

    if( buf < buf_end )
	*buf++ = '"';
    
    if( buf >= buf_end )
	buf--;

    *buf = 0;

    return buf;
}

static char *getgeniclientid( tmcdreq_t *reqp ) {

	char buf[ MYBUFSIZE ];

	GOUTPUT( buf, sizeof buf, "%s", reqp->nickname );

	if( verbose )
		info( "%s: geni_client_id: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenisliceurn( tmcdreq_t *reqp ) {

	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];

	res = mydb_query( "SELECT c.urn FROM `geni-cm`.geni_slivers AS s, "
			  "`geni-cm`.geni_certificates AS c WHERE "
			  "s.resource_uuid='%s' AND "
			  "c.uuid = s.slice_uuid", 1, reqp->nodeuuid );

	if( !res || !mysql_num_rows( res ) ) {
		error( "geni_slice_urn: %s: DB error getting URN!\n",
		       reqp->nodeid );
		return NULL;
	}

	row = mysql_fetch_row( res );

	GOUTPUT( buf, sizeof buf, "%s", row[ 0 ] );

	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_slice_urn: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *cert_email( char *cert, char *DN ) {
    
    /* NB: We should really hunt through the certificate's
       subjectAltName extensions (which is where the GENI spec says
       e-mail addresses go) and extract the address from there.  Right
       now, we don't do that for two reasons: (1) OpenSSL makes that
       seemingly trivial task excruciatingly painful; and (2) it's not
       actually where Emulab sticks e-mail addresses anyway. */

    char *p = strstr( DN, "/emailAddress=" );

    if( p )
	return p + 14;
    else
	return NULL;
}

static char *getgenisliceemail( tmcdreq_t *reqp ) {

	MYSQL_RES	*res;
	char		buf[MYBUFSIZE];

	
	res = mydb_query( "SELECT c.cert, c.DN FROM `geni-cm`.geni_slivers "
			  "AS s, `geni-cm`.geni_certificates AS c WHERE "
			  "s.resource_uuid='%s' AND "
			  "c.uuid = s.slice_uuid", 2, reqp->nodeuuid );

	if( !res ) {
		error( "geni_slice_urn: %s: DB error getting slice cert!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );
		
		char *p = cert_email( row[ 0 ], row[ 1 ] );
		    
		if( p )
			GOUTPUT( buf, sizeof buf, "%s", p );
		else {
		        /* oh well */
		        mysql_free_result( res );
			return NULL;
		}
	}

	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_slice_email: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgeniuserurn( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];

	res = mydb_query("SELECT u.nonlocal_id,slice.creator_urn FROM "
			 "  `geni-cm`.geni_slices AS slice "
			 "join `geni-cm`.geni_slivers AS sliver on "
			 "   slice.uuid = sliver.slice_uuid "
			 "join users as u on "
			 "   u.uid_uuid=slice.creator_uuid "
			 "WHERE sliver.resource_uuid='%s'",
			 2, reqp->nodeuuid);

	if( !res || !mysql_num_rows( res ) ) {
		error( "geni_user_urn: %s: DB error getting URN!\n",
		       reqp->nodeid );
		return NULL;
	}

	row = mysql_fetch_row( res );
	if (row[0] && row[0][0]) {
		GOUTPUT( buf, sizeof buf, "%s", row[ 0 ] );
	}
	else {
		GOUTPUT( buf, sizeof buf, "%s", row[ 1 ] );
	}
	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_user_urn: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgeniuseremail( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res, *res_cert;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*urn, *p;
	static char     localurn[] = "urn:publicid:IDN+" OURDOMAIN "+";
	
	/* This is a big pain, because certificates for local users are
	   stored differently than those for foreign users.  First
	   figure out who the user is... */
	res = mydb_query( "SELECT slice.creator_urn FROM "
			  "`geni-cm`.geni_slices AS slice, "
			  "`geni-cm`.geni_slivers AS sliver WHERE "
			  "sliver.resource_uuid='%s' AND "
			  "slice.uuid = sliver.slice_uuid", 1,
			  reqp->nodeuuid );
	
	if( !res ) {
		error( "geni_user_email: %s: DB error getting URN!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( !mysql_num_rows( res ) ) {
		error( "geni_user_email: %s: No record for URN!\n",
		       reqp->nodeid );
		mysql_free_result( res );
		return NULL;
	}

	row = mysql_fetch_row( res );
	urn = row[ 0 ];

	if( strncasecmp( urn, localurn, ( sizeof localurn ) - 1 ) ) {
	        /* Foreign user -- they should have an entry in
		   geni-cm.geni_certificates. */
	        res_cert = mydb_query( "SELECT cert, DN FROM "
				       "`geni-cm`.geni_certificates WHERE "
				       "urn='%s'", 2, urn );
		
		if( !res_cert ) {
		        error( "geni_user_email: %s: DB error getting "
			       "foreign cert!\n", reqp->nodeid );
			mysql_free_result( res );
			return NULL;
		}

		row = mysql_fetch_row( res_cert );
	} else {
	        /* Local user -- they should have an entry in
		   tbdb.user_sslcerts. */
	        if( strncmp( urn + ( sizeof localurn ) - 1, "user+", 5 ) ) {
 		        /* Unrecognised URL.  Give up. */
			mysql_free_result( res );
			return NULL;
		}
		
	        res_cert = mydb_query( "SELECT cert, DN FROM user_sslcerts "
				       "WHERE uid='%s' AND revoked IS NULL "
				       "AND encrypted=1", 2, urn +
				       ( sizeof localurn - 1 ) + 5 );
		
		if( !res_cert ) {
		        error( "geni_user_email: %s: DB error getting "
			       "local cert!\n", reqp->nodeid );
			mysql_free_result( res );
			return NULL;
		}

		row = mysql_fetch_row( res_cert );
	}
	
	p = cert_email( row[ 0 ], row[ 1 ] );
		    
	if( p )
	        GOUTPUT( buf, sizeof buf, "%s", p );
	else {
	        /* oh well */
	        mysql_free_result( res );
		mysql_free_result( res_cert );
		return NULL;
	}
	
	mysql_free_result( res );
	mysql_free_result( res_cert );

	if( verbose )
		info( "%s: geni_user_urn: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenimanifest( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res;
	char		*buf;

	res = mydb_query( "SELECT m.manifest FROM `geni-cm`.geni_slivers AS s, "
			  "`geni-cm`.geni_manifests AS m WHERE "
			  "s.resource_uuid='%s' AND "
			  "m.slice_uuid = s.slice_uuid", 1, reqp->nodeuuid );

	if( !res ) {
		error( "geni_slice_urn: %s: DB error getting manifest!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );

		buf = strdup( row[ 0 ] );
	} else
	        buf = strdup( "" );

	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_slice_urn: %s", reqp->nodeid, buf );
	
	return buf;
}

static char *getgeniportalmanifest( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res;
	char		*buf;

	res = mydb_query( "SELECT m.manifest FROM `geni-cm`.geni_slivers AS s, "
			  "`geni-cm`.portal_manifests AS m WHERE "
			  "s.resource_uuid='%s' AND "
			  "m.slice_uuid = s.slice_uuid", 1, reqp->nodeuuid );

	if( !res ) {
		error( "geni_portal_manifest: %s: DB error getting manifest!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );

		buf = strdup( row[ 0 ] );
	} else {
	        buf = strdup( "" );
	}

	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_portal_manifest: %s", reqp->nodeid, buf );
	
	return buf;
}

static char *getgenicert( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res;
	char		buf[ MAXTMCDPACKET ];
	buf[0] = (char) NULL;  

	res = mydb_query( "SELECT c.cert FROM `geni-cm`.geni_slivers AS s, "
			  "`geni-cm`.geni_slicecerts AS c WHERE "
			  "s.resource_uuid='%s' AND "
			  "c.uuid = s.slice_uuid", 1, reqp->nodeuuid );

	if( !res ) {
		error( "getgenicert: %s: DB error getting certificate!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );

		GOUTPUT( buf, sizeof buf, "%s", row[ 0 ] );
	}

	mysql_free_result( res );

	if( verbose )
		info( "%s: getgenicert: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenikey( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res;
	char		buf[ MAXTMCDPACKET ];
	buf[0] = (char) NULL;  

	res = mydb_query( "SELECT c.privkey FROM `geni-cm`.geni_slivers AS s, "
			  "`geni-cm`.geni_slicecerts AS c WHERE "
			  "s.resource_uuid='%s' AND "
			  "c.uuid = s.slice_uuid", 1, reqp->nodeuuid );

	if( !res ) {
		error( "getgenikey: %s: DB error getting certificate!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );

		GOUTPUT( buf, sizeof buf, "%s", row[ 0 ] );
	}

	mysql_free_result( res );

	if( verbose )
		info( "%s: getgenikey: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenigeniuser( tmcdreq_t *reqp ) {
    
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[ 0x4000 ], *p;
	int             first = 1;
	
	res = mydb_query( "SELECT a.urn, p.idx, p.pubkey FROM "
			  "nonlocal_user_accounts AS a, "
			  "nonlocal_user_pubkeys AS p WHERE "
			  "a.uid_idx=p.uid_idx AND "
			  "a.exptidx=%d ORDER BY a.urn, p.idx", 3,
			  reqp->exptidx );

	if( !res ) {
		error( "geni_slice_urn: %s: DB error getting users!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( !mysql_num_rows( res ) ) {
		error( "geni_user_email: %s: No users found\n",
		       reqp->nodeid );
		mysql_free_result( res );
		return NULL;
	}

	p = geni_append( buf, buf + sizeof buf, "[" );
	
	while( ( row = mysql_fetch_row( res ) ) ) {
		if( !strcmp( row[ 1 ], "1" ) ) {
			if( !first )
			        p = geni_append( p, buf + sizeof buf, "]}," );

			p = geni_append( p, buf + sizeof buf, "{\"urn\":" );
			p = geni_quote( p, buf + sizeof buf, row[ 0 ] );
			p = geni_append( p, buf + sizeof buf, ",\"keys\":[" );
		} else
			p = geni_append( p, buf + sizeof buf, "," );

		p = geni_quote( p, buf + sizeof buf, row[ 2 ] );
				
		first = 0;
	}
	
	geni_append( p, buf + sizeof buf, "]}]" );
	
	mysql_free_result( res );
	
	if( verbose )
		info( "%s: geni_geni_users: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenicontrolmac( tmcdreq_t *reqp ) {

	MYSQL_RES	*res;
	char		buf[MYBUFSIZE];

	res = mydb_query( "SELECT mac FROM interfaces WHERE node_id='%s' AND "
			  "role='ctrl'", 1, reqp->nodeid );

	if( !res ) {
		error( "geni_slice_urn: %s: DB error getting interface!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );

		GOUTPUT( buf, sizeof buf, "%s", row[ 0 ] );
	}

	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_control_mac: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgeniversion( tmcdreq_t *reqp ) {

	char buf[ MYBUFSIZE ];

	GOUTPUT( buf, sizeof buf, GENI_VERSION );

	if( verbose )
		info( "%s: geni_version: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

/* This is "getversion".  Not to be confused with "version", which is
   obviously completely different. */
static char *getgenigetversion( tmcdreq_t *reqp ) {

	MYSQL_RES	*res;
	char		buf[MYBUFSIZE];

	res = mydb_query( "SELECT value FROM version_info WHERE "
			  "name='commithash'", 1 );

	if( !res ) {
		error( "geni_slice_urn: %s: DB error getting version!\n",
		       reqp->nodeid );
		return NULL;
	}

	if( mysql_num_rows( res ) ) {
		MYSQL_ROW row = mysql_fetch_row( res );

		GOUTPUT( buf, sizeof buf, "{\"geni_am_code_version\":\"%s\","
			 "\"geni_urn\":\"urn:publicid:IDN+" OURDOMAIN
			 "+authority+cm\","
			 "\"geni_am_type\":\"protogeni\","
			 "\"geni_single_allocation\":true,"
			 "\"geni_allocate\":\"geni_disjoint\","
			 "\"geni_api_versions\":{"
			 "\"1\":\"" TBBASE ":12369/protogeni/xmlrpc/am/1.0\","
			 "\"2\":\"" TBBASE ":12369/protogeni/xmlrpc/am/2.0\","
			 "\"3\":\"" TBBASE ":12369/protogeni/xmlrpc/am/3.0\"},"
			 "\"geni_credential_types\":["
			 "{\"geni_type\":\"geni_sfa\","
			 "\"geni_version\":\"2\"},"
			 "{\"geni_type\":\"geni_sfa\","
			 "\"geni_version\":\"3\"}]}",
			 row[ 0 ] );
	}
			 
	mysql_free_result( res );

	if( verbose )
		info( "%s: geni_slice_urn: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenisliverstatus( tmcdreq_t *reqp ) {

	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[ 0x4000 ], *p, *status;
	int		first = 1;
	
	res = mydb_query( "SELECT a.idx, a.status FROM "
			  "`geni-cm`.geni_aggregates AS a, "
			  "`geni-cm`.geni_slivers AS s WHERE "
			  "s.resource_uuid = '%s' AND "
			  "a.uuid = s.aggregate_uuid", 2, reqp->nodeuuid );

	if( !res || !mysql_num_rows( res ) ) {
		error( "geni_sliverstatus: %s: DB error getting aggregate!\n",
		       reqp->nodeid );
		return NULL;
	}

	row = mysql_fetch_row( res );

	status = strcmp( row[ 1 ], "ready" ) && strcmp( row[ 1 ], "failed" ) ?
	        "unknown" : row[ 1 ];
	
	p = buf + snprintf( buf, sizeof buf, "{\"geni_urn\":\"urn:publicid:"
			    "IDN+" OURDOMAIN "+sliver+%s\",\"geni_status\""
			    ":\"%s\",\"geni_resources\":[", row[ 0 ], status );

	mysql_free_result( res );

	res = mydb_query( "SELECT x.idx, x.status, x.errorlog FROM "
			  "`geni-cm`.geni_slivers AS x, "
			  "`geni-cm`.geni_slivers AS y WHERE "
			  "x.aggregate_uuid = y.aggregate_uuid AND "
			  "y.resource_uuid = '%s'", 3, reqp->nodeuuid );
	
	if( !res || !mysql_num_rows( res ) ) {
		error( "geni_sliverstatus: %s: DB error getting sliver!\n",
		       reqp->nodeid );
		return NULL;
	}

	while( ( row = mysql_fetch_row( res ) ) ) {
		p += snprintf( p, buf + sizeof buf - p, "%s{\"geni_urn\":"
			       "\"urn:publicid:IDN+" OURDOMAIN "+sliver+%s\","
			       "\"geni_status\":\"%s\",\"geni_error\":\"%s\"}",
			       first ? "" : ",", row[ 0 ], row[ 1 ],
			       row[ 2 ] ? row[ 2 ] : "" );
		first = 0;
	}

	mysql_free_result( res );
	
	geni_append( p, buf + sizeof buf, "]}" );
	
	if( verbose )
		info( "%s: geni_sliverstatus: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

/* This is "status", which returns the status of the sliver.  Not to be
   confused with "sliverstatus", which returns the status of the sliver
   slightly differently.  Hands up if you like design by committee! */
static char *getgenistatus( tmcdreq_t *reqp ) {

	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[ 0x4000 ], *p, expires[ 0x40 ];
	int		first = 1;
	
	res = mydb_query( "SELECT c.urn, s.expires FROM "
			  "`geni-cm`.geni_certificates AS c, "
			  "`geni-cm`.geni_slices AS s, "
			  "`geni-cm`.geni_slivers AS l WHERE "
			  "l.resource_uuid = '%s' AND "
			  "c.uuid = l.slice_uuid AND "
			  "s.uuid = l.slice_uuid", 2, reqp->nodeuuid );

	if( !res || !mysql_num_rows( res ) ) {
		error( "geni_sliverstatus: %s: DB error getting aggregate!\n",
		       reqp->nodeid );
		return NULL;
	}

	row = mysql_fetch_row( res );

	p = buf + snprintf( buf, sizeof buf, "{\"geni_urn\":\"%s\","
			    "geni_slivers\":[", row[ 0 ] );
	strcpy( expires, row[ 1 ] );

	mysql_free_result( res );

	res = mydb_query( "SELECT x.idx, x.status, x.errorlog FROM "
			  "`geni-cm`.geni_slivers AS x, "
			  "`geni-cm`.geni_slivers AS y WHERE "
			  "x.aggregate_uuid = y.aggregate_uuid AND "
			  "y.resource_uuid = '%s'", 3, reqp->nodeuuid );
	
	if( !res || !mysql_num_rows( res ) ) {
		error( "geni_sliverstatus: %s: DB error getting sliver!\n",
		       reqp->nodeid );
		return NULL;
	}

	while( ( row = mysql_fetch_row( res ) ) ) {
		p += snprintf( p, buf + sizeof buf - p, "%s{\"geni_urn\":"
			       "\"urn:publicid:IDN+" OURDOMAIN "+sliver+%s\","
			       "\"geni_expires\":\"%s\","
			       "\"geni_allocation_status\":"
			       "\"geni_provisioned\","
			       "\"geni_operational_status\":\"geni_%s\","
			       "\"geni_error\":\"%s\"}",
			       first ? "" : ",", row[ 0 ], expires,
			       row[ 1 ], row[ 2 ] ? row[ 2 ] : "" );
		first = 0;
	}

	mysql_free_result( res );
	
	geni_append( p, buf + sizeof buf, "]}" );
	
	if( verbose )
		info( "%s: geni_sliverstatus: %s", reqp->nodeid, buf );
	
	return strdup( buf );
}

static char *getgenirpccert(tmcdreq_t *reqp)
{
    
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MAXTMCDPACKET];
	buf[0] = (char) NULL;

	if (!reqp->geniflags) {
		return NULL;
	}

	res = mydb_query("select cert,privkey from user_sslcerts "
			 "where uid='%s' and encrypted=0 and "
			 "      DN like '%%sslxmlrpc%%'",
			 2, reqp->creator);

	if (!res || !mysql_num_rows(res)) {
		error("getgenirpccert: %s: "
		      "DB error getting certificate for %s!\n",
		      reqp->nodeid, reqp->creator);
		return NULL;
	}
	row = mysql_fetch_row(res);
	strcpy(buf, "-----BEGIN RSA PRIVATE KEY-----\n");
	strcat(buf, row[1]);
	strcat(buf, "-----END RSA PRIVATE KEY-----\n");
	strcat(buf, "-----BEGIN CERTIFICATE-----\n");
	strcat(buf, row[0]);
	strcat(buf, "-----END CERTIFICATE-----\n");
	mysql_free_result(res);
	
	if (1 || verbose)
		info("%s: getgenicert %s", reqp->nodeid, reqp->creator);

	return strdup(buf);
}

#define MAKEGENICOMMAND( cmd ) \
        COMMAND_PROTOTYPE( dogeni ## cmd ) { \
		return dogeni( sock, reqp, tcp, getgeni ## cmd ); \
	}

MAKEGENICOMMAND(clientid)
MAKEGENICOMMAND(sliceurn)
MAKEGENICOMMAND(sliceemail)
MAKEGENICOMMAND(userurn)
MAKEGENICOMMAND(useremail)
MAKEGENICOMMAND(geniuser)
MAKEGENICOMMAND(manifest)
MAKEGENICOMMAND(portalmanifest)
MAKEGENICOMMAND(cert)
MAKEGENICOMMAND(key)
MAKEGENICOMMAND(controlmac)
MAKEGENICOMMAND(version)
MAKEGENICOMMAND(getversion)
MAKEGENICOMMAND(sliverstatus)
MAKEGENICOMMAND(status)
MAKEGENICOMMAND(rpccert)

struct genicommand {
    char *tag;
    char *( *func )( tmcdreq_t * );
    int quote;
    char *desc;
} genicommands[] = {
    { "all", NULL, 0, NULL },
    { "client_id", getgeniclientid, 1, "Return the experimenter-specified "
      "client_id for this node" },
    { "commands", NULL, 0, "Show all available commands" },
    { "control_mac", getgenicontrolmac, 1, "Show the MAC address of the "
      "control interface on this node" },
    { "geni_user", getgenigeniuser, 0, "Show user accounts and public keys "
      "installed on this node" },
    { "getversion", getgenigetversion, 0, "Report the GetVersion output of "
      "the aggregate manager that allocated this node" },
    { "manifest", getgenimanifest, 1, "Show the manifest rspec for the local "
      "aggregate sliver" },
    { "slice_email", getgenisliceemail, 1, "Retrieve the e-mail address from "
      "the certificate of the slice containing this node" },
    { "slice_urn", getgenisliceurn, 1, "Show the URN of the slice containing "
      "this node" },
    { "sliverstatus", getgenisliverstatus, 0, "Give the current status of "
      "this sliver (AM API v2)" },
    { "status", getgenistatus, 0, "Give the current status of "
      "this sliver (AM API v3)" },
    { "user_email", getgeniuseremail, 1, "Show the e-mail address of this "
      "sliver's creator" },
    { "user_urn", getgeniuserurn, 1, "Show the URN of this sliver's creator" },
    { "version", getgeniversion, 1, NULL },
    { "certificate", getgenicert, 1, NULL },
    { "key", getgenikey, 1, NULL },
    { "rpccert", getgenirpccert, 1, NULL },
    { "portalmanifest", getgeniportalmanifest, 1,
      "Show the portal aggregated manifest for the local aggregate sliver" },
};

COMMAND_PROTOTYPE(dogenicommands)
{
    char buf[ MAXTMCDPACKET ], *p;
    int i, maxlen, first = 1;

    buf[ 0 ] = 0; /* NUL */
    buf[ 1 ] = '{';
    buf[ 2 ] = '\n';
    p = buf + 3;

    for( i = 0, maxlen = 0; i < sizeof genicommands / sizeof *genicommands;
	 i++ ) {
	char *tag = genicommands[ i ].tag;
	int len;
	
	if( tag && ( len = strlen( tag ) ) > maxlen )
	    maxlen = len;
    }
    
    for( i = 0; i < sizeof genicommands / sizeof *genicommands; i++ ) {
	char *desc = genicommands[ i ].desc;

	if( desc ) {
	    if( first )
		first = 0;
	    else
		p = geni_append( p, buf + sizeof buf, ",\n" );
	    
	    p += snprintf( p, buf + sizeof buf - p,
			   " \"%s\":%*s\"%s\"",
			   genicommands[ i ].tag,
			   (int)(maxlen + 1 - strlen( genicommands[ i ].tag )),
			   "", genicommands[ i ].desc );
	}
    }
    
    geni_append( p, buf + sizeof buf, "\n}\n" );
    
    client_writeback( sock, buf, 1 + strlen( buf + 1 ), tcp );

    return 0;
}

COMMAND_PROTOTYPE(dogeniall)
{
    /* Glob all the other stuff into a JSON structure.  Hey, at least
       it's not XML! */
    char buf[ MAXTMCDPACKET ], *p;
    int i, first = 1;

    buf[ 0 ] = 0; /* NUL */
    buf[ 1 ] = '{';
    p = buf + 2;

    for( i = 0; i < sizeof genicommands / sizeof *genicommands; i++ ) {
	char *( *f )( tmcdreq_t * ) = genicommands[ i ].func;
	char *val;

	if( !f || !( val = f( reqp ) ) )
	    continue;

	if( first )
	    first = 0;
	else
	    p = geni_append( p, buf + sizeof buf, "," );
	    
	p = geni_quote( p, buf + sizeof buf, genicommands[ i ].tag );
	p = geni_append( p, buf + sizeof buf, ":" );
	p = ( genicommands[ i ].quote ? geni_quote :
	      geni_append )( p, buf + sizeof buf, val );
	
	free( val );
    }

    geni_append( p, buf + sizeof buf, "}\n" );
    
    client_writeback( sock, buf, 1 + strlen( buf + 1 ), tcp );

    return 0;
}

COMMAND_PROTOTYPE(dogeniparam)
{
    char *p;
    MYSQL_RES *res;
    MYSQL_ROW row;

    for( p = rdata; *p; p++ )
	if( isspace( *p ) ) {
	    *p = 0;
	    break;
	} else if( ( *p < 'a' || *p > 'z' ) &&
	    ( *p < 'A' || *p > 'Z' ) &&
	    ( *p < '0' || *p >= '9' ) &&
	    *p != '_' && *p != '-' ) {
	    static char error_msg[] = "\0\0illegal parameter\n";

	    client_writeback( sock, error_msg, sizeof error_msg - 1, tcp );
	    
	    return 1;
	}

    res = mydb_query( "SELECT value FROM virt_profile_parameters "
		      "WHERE exptidx=%d AND name='%s'", 1, reqp->exptidx,
		      rdata );
    if( !res ) {
	error( "PARAM: error retrieving value\n" );
	return 1;
    }

    if( mysql_num_rows( res ) < 1 ) {
	static char error_msg[] = "\0\0undefined parameter\n";

	client_writeback( sock, error_msg, sizeof error_msg - 1, tcp );
	    
	mysql_free_result( res );
	
	return 1;
    }

    row = mysql_fetch_row( res );

    client_writeback( sock, "", 1, tcp ); /* single NUL */
    client_writeback( sock, row[ 0 ], strlen( row[ 0 ] ), tcp );
    client_writeback( sock, "\n", 1, tcp ); /* single NUL */

    mysql_free_result( res );
    
    return 0;
}

COMMAND_PROTOTYPE(dogeniinvalid)
{
    static char error_msg[] = "\0\0unknown request\n";
	
    client_writeback( sock, error_msg, sizeof error_msg - 1, tcp );
	
    return 1;
}	
#endif

/*
 * Get image size and mtime.
 */
static int
getImageInfo(char *path, char *nodeid, char *pid, char *imagename,
	     unsigned int *mtime, off_t *isize)
{
	struct stat sb;

	/*
	 * The image may not be directly accessible since tmcd runs as
	 * "nobody". If so, use the imageinfo helper to get the info
	 * via the frisbee master server.
	 */
	if (stat(path, &sb)) {
		char _buf[512];
		FILE *cfd;

		snprintf(_buf, sizeof _buf,
			 "%s/sbin/imageinfo -qm -N %s "
			 "%s/%s",
			 TBROOT, nodeid, pid, imagename);
		if ((cfd = popen(_buf, "r")) == NULL) {
		badimage1:
			error("doloadinfo: %s: "
			      "Could not determine "
			      "mtime for %s/%s\n", nodeid, pid, imagename);
			return 1;
		}
		_buf[0] = 0;
		fgets(_buf, sizeof _buf, cfd);
		if (pclose(cfd))
			goto badimage1;
		sb.st_mtime = 0;
		if (_buf[0] != 0 && _buf[0] != '\n') {
			long _tmp;
			sscanf(_buf, "%ld", &_tmp);
			sb.st_mtime = _tmp;
		}
		if (sb.st_mtime == 0)
			goto badimage1;

		snprintf(_buf, sizeof _buf,
			 "%s/sbin/imageinfo -qs -N %s "
			 "%s/%s",
			 TBROOT, nodeid, pid, imagename);
		if ((cfd = popen(_buf, "r")) == NULL) {
		badimage2:
			error("doloadinfo: %s: "
			      "Could not determine "
			      "size for %s/%s\n", nodeid, pid, imagename);
			return 1;
		}
		_buf[0] = 0;
		fgets(_buf, sizeof _buf, cfd);
		if (pclose(cfd))
			goto badimage2;
		sb.st_size = 0;
		if (_buf[0] != 0 && _buf[0] != '\n') {
			long long _tmp;
			sscanf(_buf, "%lld", &_tmp);
			sb.st_size = _tmp;
		}
		if (sb.st_size == 0)
			goto badimage2;
	}
	*mtime  = sb.st_mtime;
	*isize = sb.st_size;
	return 0;
}

/*
 * Allow virtual host nodes to upload capture (tiptunnel) info.
 */
COMMAND_PROTOTYPE(dotiplineinfo)
{
#define MAXINFO		128
#define HOST_STR	"host:"
#define PORT_STR	"port:"
#define KEYLEN_STR	"keylen:"
#define KEY_STR		"key:"

	char	*bp, host[MAXINFO], port[MAXINFO], keylen[MAXINFO],
		key[MAXINFO];
#if 0
	printf("%s", rdata);
#endif
	if (!reqp->isvnode) {
		return 0;
	}

	/*
	 * The maximum length we accept is 128 bytes.
	 */
	host[0] = port[0] = keylen[0] = key[0] = 0;

	/*
	 * Sheesh, perl string matching would be so much easier!
	 */
	bp = rdata;
	while (*bp) {
		char	*ep, *sp, *tp;

		while (*bp == ' ')
			bp++;
		if (! *bp)
			break;

		if (! strncasecmp(bp, HOST_STR, strlen(HOST_STR))) {
			tp = host;
			ep = tp + sizeof(host);
			bp += strlen(HOST_STR);
		}
		else if (! strncasecmp(bp, PORT_STR, strlen(PORT_STR))) {
			tp = port;
			ep = tp + sizeof(port);
			bp += strlen(PORT_STR);
		}
		else if (! strncasecmp(bp, KEYLEN_STR, strlen(KEYLEN_STR))) {
			tp = keylen;
			ep = tp + sizeof(keylen);
			bp += strlen(KEYLEN_STR);
		}
		else if (! strncasecmp(bp, KEY_STR, strlen(KEY_STR))) {
			tp = key;
			ep = tp + sizeof(key);
			bp += strlen(KEY_STR);
		}
		else {
			error("TIPLINEINFO: %s: "
			      "Unrecognized key type '%.8s ...'\n",
			      reqp->nodeid, bp);
			if (verbose)
				error("TIPLINEINFO: %s\n", rdata);
			return 1;
		}
		sp = tp;
		while (*bp && isspace(*bp))
			bp++;
		while (*bp && *bp != '\n') {
			if (! (isalnum(*bp) || *bp == '.' || *bp == '-')) {
				error("TIPLINEINFO: %s: bad data!\n",
				      reqp->nodeid);
				return 1;
			}
			if (tp >= ep) {
				error("TIPLINEINFO: %s: data too long!\n",
				      reqp->nodeid);
				return 1;
			}
			*tp++ = *bp++;
		}
		*tp = '\0';
		// Skip the newline we stopped at above.
		bp++;
		fprintf(stderr, "%s\n", sp);
	}
	/*
	 * We do not need to escape the stuff; we checked above to
	 * confirm that the strings contained only alphanumeric, dot, dash.
	 */
	if (mydb_update("replace into tiplines set "
			"       tipname='%s',node_id='%s',server='%s', "
			"       portnum='%s',keylen='%s',keydata='%s'",
			reqp->nodeid,reqp->nodeid,host,port,keylen,key)) {
		error("TIPLINEINFO: %s: setting hostkeys!\n", reqp->nodeid);
		return 1;
	}
	return 0;
}

/*
 * Get a 'len' character random string.
 * 'buf' had better be at least len+1 chars because we null terminate.
 */
static int
getrandomchars(char *buf, int len)
{
	unsigned char	randdata[MYBUFSIZE];
	int		fd, cc, i, j, rdlen;
	char		*bp;

	rdlen = len / 2;
	if (len <= 0 || (len & 1) == 1 || rdlen >= MYBUFSIZE) {
		error("Bad buffer size in getrandomchars");
		return 1;
	}

	if ((fd = open("/dev/urandom", O_RDONLY)) < 0) {
		errorc("opening /dev/urandom");
		return 1;
	}
	if ((cc = read(fd, randdata, rdlen)) < 0) {
		errorc("reading /dev/urandom");
		close(fd);
		return 1;
	}
	if (cc != rdlen) {
		error("Short read from /dev/urandom: %d", rdlen);
		close(fd);
		return 1;
	}
	bp = buf;
	for (i = 0, j = 0; i < len;) {
		cc = sprintf(bp, "%02x", randdata[j]);
		i  += cc;
		bp += cc;
		j++;
	}
	buf[len] = '\0';
	
	close(fd);
	return 0;
}

/*
 * An Emulab image ID string looks like:
 *    [<pid>]<imagename>[<vers>][<meta>]
 * where:
 *    <pid> is the project
 *    <imagename> is the image identifier string
 *    <vers> is an image version number (not yet implemented)
 *    <meta> is a string indicating that this is not the actual image,
 *           rather it is metadata file associated with the image.
 *           By convention, the string is the filename extension used
 *           for the metadata file in question. Currently, the only
 *           metadata string is 'sig' indicating that this is an image
 *           signature file.
 * Each of these fields has a separator character distinguishing the
 * start of the field. These are defined here.
 */
#define IID_SEP_NAME '/'
#define IID_SEP_VERS ':'
#define IID_SEP_META ','

/*
 * Parse an Emulab image ID string:
 *
 *    [<pid>]<imagename>[<vers>][<meta>]
 *
 * into its component parts. Returned components are malloced strings and
 * need to be freed by the caller.
 *
 * Note that right now there are no errors. Even with a malformed string,
 * we will return 'emulab-ops' as 'pid' and the given string as 'imagename'.
 */
#define mystrdup strdup

static void
parse_imageid(char *str, char **pidp, char **namep, char **versp, char **metap)
{
	char *ipid, *iname, *ivers, *imeta;
	
	/* Watch for trailing whitespace */
	char *cp;
	while ((cp = rindex(str, ' ')) != NULL) {
		*cp = '\0';
	}
	
	ipid = mystrdup(str);
	iname = index(ipid, IID_SEP_NAME);
	if (iname == NULL) {
		iname = ipid;
		ipid = mystrdup("emulab-ops");
	} else {
		*iname = '\0';
		iname = mystrdup(iname+1);
	}
	ivers = index(iname, IID_SEP_VERS);
	if (ivers) {
		char *eptr;

		/* If we can't convert to a number, consider it part of name */
		if (strtol(ivers+1, &eptr, 10) == 0 && eptr == ivers+1) {
			ivers = NULL;
		} else {
			*ivers = '\0';
			ivers = mystrdup(ivers+1);
		}
	}
	imeta = index(ivers ? ivers : iname, IID_SEP_META);
	if (imeta != NULL) {
		*imeta = '\0';
		imeta = mystrdup(imeta+1);
	}

	*pidp = ipid;
	*namep = iname;
	*versp = ivers;
	*metap = imeta;
}

COMMAND_PROTOTYPE(doimagesize)
{
	char		*ipid, *iname, *ivers, *imeta;
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		buf[MYBUFSIZE];
	char		*bufp = buf, *ebufp = &buf[sizeof(buf)];

	/* No special characters */
	mysql_escape_string(buf, rdata, strlen(rdata));
	if (strlen(buf) != strlen(rdata)) {
		error("doimagesize: Illegal chars in imagename!\n");
		return 1;
	}
	parse_imageid(buf, &ipid, &iname, &ivers, &imeta);
	if (ipid == NULL || iname == NULL) {
		return 1;
	}

	if (ivers == NULL) {
		res = mydb_query("SELECT v.lba_low,v.lba_high, "
				 "  v.lba_size,v.relocatable  "
				 " FROM images AS i, image_versions AS v "
				 "WHERE i.imageid=v.imageid "
				 "  AND i.version=v.version "
				 "  AND i.pid='%s' "
				 "  AND i.imagename='%s' "
				 "  AND v.deleted IS NULL",
				 4, ipid, iname);
	}
	else {
		res = mydb_query("SELECT v.lba_low,v.lba_high, "
				 "  v.lba_size,v.relocatable  "
				 " FROM images as i "
				 " LEFT JOIN image_versions "
				 "  as v on "
				 "    v.imageid=i.imageid and "
				 "    v.version='%s' "
				 "WHERE i.pid='%s'"
				 " AND i.imagename='%s'",
				 4, ivers, ipid, iname);
	}
	if (!res) {
		error("DB error getting image: %s/%s%s%s\n", ipid, iname,
		      (ivers ? ":" : ""), (ivers ? ivers : ""));
	}
	else if (!mysql_num_rows(res)) {
		error("No such image: %s/%s%s%s\n", ipid, iname,
		      (ivers ? ":" : ""), (ivers ? ivers : ""));
		mysql_free_result(res);
	}
	free(ipid);
	free(iname);
	if (ivers)
		free(ivers);
	if (imeta)
		free(imeta);

	if (!res || !mysql_num_rows(res)) {
		return 1;
	}
	row = mysql_fetch_row(res);

	/*
	 * XXX if lba_high==0 then assume the DB
	 * fields have not been initialized and
	 * don't return this info.
	 */
	if (row[1] && strcmp(row[1], "0") != 0 && row[0] && row[2] && row[3]) {
		bufp += OUTPUT(bufp, ebufp - bufp,
			       "IMAGELOW=%s IMAGEHIGH=%s IMAGESSIZE=%s "
			       "IMAGERELOC=%s\n",
			       row[0], row[1], row[2], row[3]);
	}
	mysql_free_result(res);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/* Return attributes relevant to PhantomNet experiments. */
COMMAND_PROTOTYPE(dopnetnodeattrs)
{
	MYSQL_RES   *res;
	MYSQL_ROW   row;
	int         nrows = 0;
	char	    buf[MYBUFSIZE];
	char	    *bufp = buf, *ebufp = &buf[sizeof(buf)];
	char        *pnet_nattr_keys = "('sim_imsi', 'sim_sequence_number')";

	res = mydb_query( "SELECT na.node_id,na.attrkey,na.attrvalue "
			  " from reserved as r"
			  " left join node_attributes as na "
			  "  on r.node_id=na.node_id"
			  "       where r.pid='%s' and r.eid='%s'"
			  "       and na.attrkey in %s",
			  3, reqp->pid, reqp->eid, pnet_nattr_keys );

	if( !res ) {
		error( "dopnetnodeattrs: %s: DB error getting node_attrs!\n",
		       reqp->nodeid );
		return 1;
	}

	nrows = (int)mysql_num_rows(res);
	while (nrows-- > 0) {
		char *node_id, *key, *val;

		row = mysql_fetch_row(res);
		if (!(row[0] && *row[0]
		      && row[1] && *row[1]
		      && row[2] && *row[2] )) {
			continue;
		}

		node_id = row[0];
		key     = row[1];
		val     = row[2];

		bufp += OUTPUT(bufp, ebufp-bufp,
			       "NODE_ID=%s KEY=%s VALUE=%s\n",
			       node_id, key, val);
	}

	mysql_free_result(res);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return service (subboss) info to a node.
 */
COMMAND_PROTOTYPE(doserviceinfo)
{
	MYSQL_RES   *res;
	MYSQL_ROW   row;
	int         nrows = 0;
	char	    buf[MYBUFSIZE];
	char        *tftp    = "boss";
	char        *pubsub  = "boss";
	char        *dhcp    = "boss";
	char        *frisbee = "boss";

	res = mydb_query("select service,subboss_id from subbosses "
			 "where node_id='%s' and disabled=0",
			 2, reqp->nodeid);

	if (!res) {
		error("doserviceinfo: %s: DB error getting serviceinfo!\n",
		       reqp->nodeid);
		return 1;
	}

	nrows = (int)mysql_num_rows(res);
	while (nrows-- > 0) {
		row = mysql_fetch_row(res);
		if (!(row[0] && *row[0] &&
		      row[1] && *row[1])) {
			continue;
		}
		if (strcmp(row[0], "tftp") == 0) {
			tftp = row[1];
		}
		else if (strcmp(row[0], "dhcp") == 0) {
			dhcp = row[1];
		}
		else if (strcmp(row[0], "frisbee") == 0) {
			frisbee = row[1];
		}
		else if (strcmp(row[0], "pubsub") == 0) {
			pubsub = row[1];
		}
	}
	mysql_free_result(res);

	OUTPUT(buf, sizeof(buf), "TFTP=%s DHCP=%s FRISBEE=%s PUBSUB=%s\n",
	       tftp, dhcp, frisbee, pubsub);
	client_writeback(sock, buf, strlen(buf), tcp);
	return 0;
}

/*
 * Return subboss configuration info to a subboss.
 */
COMMAND_PROTOTYPE(dosubbossinfo)
{
	MYSQL_RES   *res;
	MYSQL_ROW   row;
	int         nrows = 0;
	char	    buf[MYBUFSIZE];
	char	    *bufp = buf, *ebufp = &buf[sizeof(buf)];
	char	    *curservice;
	int	    isfrisbee, fcreport = -1;

	/* make sure caller is a subboss */
	res = mydb_query("select erole from reserved "
			 "where node_id='%s' and erole='subboss'",
			 1, reqp->nodeid);
	if (!res) {
		error("dosubbossinfo: %s: "
		      "DB Error checking for reserved.erole\n",
		      reqp->nodeid);
		return 1;
	}
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}
	mysql_free_result(res);

	/*
	 * XXX make sure subbosses respect sitevar for frisbee client reports.
	 * Note again that a heartbeat of zero means disabled.
	 *
	 * It is debatable whether this should override the attributes value.
	 * Right now it doesn't. It only takes effect if no frisbee
	 * "clientreport" attribute is specified.
	 */
	res = mydb_query("select value,defaultvalue from sitevariables "
			 "where name='images/frisbee/heartbeat'", 2);
	if (res && (int)mysql_num_rows(res) > 0) {
		row = mysql_fetch_row(res);
		if (row[0] && row[0][0])
			fcreport = atoi(row[0]);
		else if (row[1] && row[1][0])
			fcreport = atoi(row[1]);
	}
	if (res)
		mysql_free_result(res);

	/*
	 * Get info for all services, one line per service
	 */
	res = mydb_query("select service,attrkey,attrvalue "
			 " from subboss_attributes where subboss_id='%s' "
			 " order by service,attrkey",
			 3, reqp->nodeid);
	if (!res) {
		error("dosubbossinfo: %s: DB error getting attributes!\n",
		      reqp->nodeid);
		return 1;
	}

	curservice = NULL;
	nrows = (int)mysql_num_rows(res);
	while (nrows-- > 0) {
		row = mysql_fetch_row(res);
		if (!(row[0] && *row[0] &&
		      row[1] && *row[1])) {
			continue;
		}
		if (curservice == NULL || strcmp(curservice, row[0]) != 0) {
			if (curservice) {
				if (isfrisbee && fcreport >= 0)
					bufp += OUTPUT(bufp, ebufp - bufp,
						       " clientreport=\"%d\"",
						       fcreport);
				OUTPUT(bufp, ebufp - buf, "\n");
				client_writeback(sock, buf, strlen(buf), tcp);
				bufp = buf;
				free(curservice);
			}
			curservice = mystrdup(row[0]);
			bufp += OUTPUT(bufp, ebufp - bufp, "%s", curservice);
			if (strcmp(curservice, "frisbee") == 0)
				isfrisbee = 1;
			else
				isfrisbee = 0;
		}
		/*
		 * Just remember frisbee clientreport value for now.
		 * XXX note that per subboss attribute overrides sitevar.
		 */
		if (isfrisbee && strcmp(row[1], "clientreport") == 0)
			fcreport = row[2] ? atoi(row[2]) : -1;
		else
			bufp += OUTPUT(bufp, ebufp - bufp, " %s=\"%s\"",
				       row[1], row[2] ? row[2] : "");
	}
	mysql_free_result(res);

	if (bufp != buf) {
		if (isfrisbee && fcreport >= 0)
			bufp += OUTPUT(bufp, ebufp - bufp,
				       " clientreport=\"%d\"", fcreport);
		OUTPUT(bufp, ebufp - buf, "\n");
		client_writeback(sock, buf, strlen(buf), tcp);
	}
	if (curservice)
		free(curservice);

	return 0;
}

/*
 * Return virt_node_public_addr dump to any node in an experiment.
 */
COMMAND_PROTOTYPE(dopublicaddrinfo)
{
	MYSQL_RES   *res;
	MYSQL_ROW   row;
	int         nrows = 0;
	char	    buf[MYBUFSIZE];
	char	    *bufp = buf, *ebufp = &buf[sizeof(buf)];

	res = mydb_query("select IP,mask,node_id,pool_id"
			 " from virt_node_public_addr"
			 " where pid='%s' and eid='%s'",
			 4, reqp->pid, reqp->eid);
	if (!res) {
		error("dopublicaddrinfo: %s: "
		      "DB Error checking for experiment public addrs\n",
		      reqp->nodeid);
		return 1;
	}
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	nrows = (int)mysql_num_rows(res);
	while (nrows-- > 0) {
		row = mysql_fetch_row(res);
		bufp += OUTPUT(bufp, ebufp - buf,
			       "IP=\"%s\" MASK=\"%s\" NODE_ID=\"%s\""
			       " POOL_ID=\"%s\"\n",
			       row[0],row[1] ? row[1] : "",row[2] ? row[2] : "",
			       row[3] ? row[3] : "");
	}
	mysql_free_result(res);
	client_writeback(sock, buf, strlen(buf), tcp);

	return 0;
}

/*
 * Attenuator inventory.
 */
COMMAND_PROTOTYPE(doattenuatorlist)
{
	MYSQL_RES   *res;
	MYSQL_ROW   row;
	int         nrows;
	char	    buf[MYBUFSIZE];
	char	    *bufp = buf, *ebufp = &buf[sizeof(buf)];
	
	res = mydb_query( "SELECT w.external_wire, w.node_id1, w.node_id2 "
			  "FROM wires AS w, reserved AS r1, reserved AS r2 "
			  "WHERE w.node_id1=r1.node_id AND "
			  "w.node_id2=r2.node_id AND r1.exptidx=%d AND "
			  "r2.exptidx=%d AND w.iface1 LIKE 'rf%%' AND "
			  "w.iface2 LIKE 'rf%%'", 3,
			  reqp->exptidx, reqp->exptidx );
	
	if( !res ) {
		error( "ATTENUATORLIST: %s: query failed\n",
		       reqp->nodeid );
		
		return 1;
	}
	
	if( !mysql_num_rows( res ) ) {
		/* no attenuated RF paths in experiment */
		mysql_free_result( res );
		return 0;
	}

	nrows = (int)mysql_num_rows(res);
	while (nrows-- > 0) {
		row = mysql_fetch_row(res);
		bufp += OUTPUT( bufp, ebufp - buf,
			        "%s:%s/%s\n", row[ 0 ], row[ 1 ], row[ 2 ] );
	}
	
	mysql_free_result( res );
	
	client_writeback( sock, buf, strlen( buf ), tcp );

	return 0;
}

/*
 * Attenuator control.
 */
COMMAND_PROTOTYPE(doattenuator)
{
	int atten, val;
	MYSQL_RES *res;
	int attendsock;
	struct sockaddr_in sin;
	unsigned char cmd[ 3 ];
	char *response;
	
	if( !sscanf( rdata, "%d %d", &atten, &val ) ) {
		error( "ATTENUATOR: %s: Invalid format\n", reqp->nodeid );
		
		return 1;
	}
	
	/* The attenuator must be on a wire path between two nodes both reserved
	   to reqp->exptidx. */
	res = mydb_query( "SELECT w.node_id1 FROM wires AS w, reserved AS r1, "
			  "reserved AS r2 WHERE w.node_id1=r1.node_id AND "
			  "w.node_id2=r2.node_id AND r1.exptidx=%d AND "
			  "r2.exptidx=%d AND ( w.external_wire=%d OR "
			  "w.external_wire LIKE '%d,%%' OR "
			  "w.external_wire LIKE '%%,%d' )", 1, reqp->exptidx,
			  reqp->exptidx, atten, atten, atten );

	if( mysql_num_rows( res ) ) {
		sin.sin_family = AF_INET;
		sin.sin_addr.s_addr = htonl( INADDR_LOOPBACK );
		sin.sin_port = htons( 0x10DB );
	
		cmd[ 0 ] = 1; /* version */
		cmd[ 1 ] = atten; /* attenuator ID */
		cmd[ 2 ] = val; /* attenuation in dB */
		
		if( ( attendsock = socket( AF_INET, SOCK_STREAM, 0 ) ) < 0 ||
		    connect( attendsock, (struct sockaddr *) &sin,
			     sizeof sin ) < 0 ||
		    write( attendsock, cmd, sizeof cmd ) != sizeof cmd )
			response = "error changing attenuation\n";
		else
			response = "changing attenuation\n";

		close( attendsock );
	} else
	    response = "invalid attenuator ID\n";
	    
	client_writeback( sock, response, strlen( response ), tcp );

	mysql_free_result( res );
		
	return 0;	    
}
