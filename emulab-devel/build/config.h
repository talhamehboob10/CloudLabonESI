/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.ac by autoheader.  */

/* The Mothership. */
#define TBMAINSITE 0

/* Actual FS mount directory for AMD */
#define AMD_ROOT "/.amd_mnt/ops"

/* IPv4 address of pubsub server on boss */
#define BOSSEVENTPORT "16505"

/* DNS name of boss node */
#define BOSSNODE "boss.cloudlab.umass.edu"

/* IPv4 address of boss node to be used by nodes */
#define BOSSNODE_IP "198.22.255.3"

/* IQN prefix for blockstores */
#define BS_IQN_PREFIX "iqn.2000-10.net.emulab"

/* IPv4 node control network mask */
#define CONTROL_NETMASK "255.255.255.0"

/* IPv4 node control network */
#define CONTROL_NETWORK "198.22.255.0"

/* IPv4 address of router to be used by nodes */
#define CONTROL_ROUTER_IP "198.22.255.1"

/* Per-node root passwords */
#define DYNAMICROOTPASSWORDS 1

/* For an Emulab-in-Emulab configuration */
/* #undef ELABINELAB */

/* Obsolete */
/* #undef ELVIN_COMPAT */

/* Emulab event server node */
#define EVENTSERVER "event-server"

/* IPv4 address of boss used from outside */
#define EXTERNAL_BOSSNODE_IP ""

/* External NTP server for NTP node */
#define EXTERNAL_NTPSERVER1 "ntp.umass.edu"

/* External NTP server for NTP node */
#define EXTERNAL_NTPSERVER2 "ntp.umass.edu"

/* External NTP server for NTP node */
#define EXTERNAL_NTPSERVER3 "ntp.umass.edu"

/* External NTP server for NTP node */
#define EXTERNAL_NTPSERVER4 "ntp.umass.edu"

/* IPv4 address of ops used from outside */
#define EXTERNAL_USERNODE_IP ""

/* Base IPv4 multicast address for disk imaging */
#define FRISEBEEMCASTADDR "239.67.170"

/* Base IPv4 port for disk imaging */
#define FRISEBEEMCASTPORT "6000"

/* Number of IPv4 ports for disk imaging */
#define FRISEBEENUMPORTS "0"

/* Mount point of 'groups' filesystem on fs node */
#define FSDIR_GROUPS "/groups"

/* Mount point of 'proj' filesystem on fs node */
#define FSDIR_PROJ "/proj"

/* Mount point of 'scratch' filesystem on fs node */
/* #undef FSDIR_SCRATCH */

/* Mount point of 'share' filesystem on fs node */
#define FSDIR_SHARE "/share"

/* Mount point of 'users' filesystem on fs node */
#define FSDIR_USERS "/users"

/* DNS name of fs node */
#define FSNODE "ops.cloudlab.umass.edu"

/* IPv4 address of fs node to be used by nodes */
#define FSNODE_IP "198.22.255.4"

/* Root of 'groups' filesystem */
#define GROUPSROOT_DIR "/groups"

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the <linux/videodev.h> header file. */
/* #undef HAVE_LINUX_VIDEODEV_H */

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Obsolete */
/* #undef HAVE_MEZZANINE */

/* Define to 1 if you have the <Python.h> header file. */
#define HAVE_PYTHON_H 1

/* Define to 1 if you have the `srandomdev' function. */
/* #undef HAVE_SRANDOMDEV */

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* XXX */
/* #undef HAVE_ULXMLRPCPP */

/* Define to 1 if you have the <ulxmlrpcpp/ulxr_config.h> header file. */
/* #undef HAVE_ULXMLRPCPP_ULXR_CONFIG_H */

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Support imagezip delta images */
/* #undef IMAGEDELTAS */

/* Support image versioning */
#define IMAGEPROVENANCE 1

/* Directory to use for imported images */
#define IMPORT_TMPDIR "/q"

/* Base of IPv4 space used for experiments */
#define IPBASE "10"

/* Do not allow admins and non-admins in same project */
/* #undef ISOLATEADMINS */

/* Base of IPv4 space used for VMs */
#define JAILIPBASE "172.17.0.0"

/* Netmask for JAILIPBASE */
#define JAILIPMASK "255.240.0.0"

/* Syslog log facility for Emulab daemons */
#define LOG_TESTBED LOG_LOCAL5

/* IPv4 node management netmask */
#define MANAGEMENT_NETMASK "255.255.252.0"

/* IPv4 node mangagement network */
#define MANAGEMENT_NETWORK "10.0.0.0"

/* IPv4 node management default GW */
#define MANAGEMENT_ROUTER "10.0.0.1"

/* NFS server has race */
/* #undef NFSRACY */

/* Do not allow NFS-shared filesystems */
/* #undef NOSHAREDFS */

/* Do not use NFS mounts on virtual nodes */
/* #undef NOVIRTNFSMOUNTS */

/* Location of NTP driftfile */
#define NTPDRIFTFILE "/var/db/ntp.drift"

/* NTP server for nodes */
#define NTPSERVER "ops"

/* Obsolete */
/* #undef OPSDBSUPPORT */

/* ops node is a VM */
/* #undef OPSVM_ENABLE */

/* mount point on boss for ops VM FSes */
/* #undef OPSVM_MOUNTPOINT */

/* Domain name of Emulab site */
#define OURDOMAIN "cloudlab.umass.edu"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT ""

/* Define to the full name of this package. */
#define PACKAGE_NAME ""

/* Define to the full name and version of this package. */
#define PACKAGE_STRING ""

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME ""

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION ""

/* Root of 'proj' filesystem */
#define PROJROOT_DIR "/proj"

/* Support Protogeni rack */
/* #undef PROTOGENI_GENIRACK */

/* Configure for a target system (like a rack) */
/* #undef CONFIG_TARGETSYS */

/* Support Protogeni */
#define PROTOGENI_SUPPORT 1

/* Root of 'scratch' filesystem */
#define SCRATCHROOT_DIR ""

/* Need perl SelfLoader hack */
#define SELFLOADER_DATA ""

/* Root of 'share' filesystem */
#define SHAREROOT_DIR "/share"

/* Server rpm/tarballs from ops rather than boss */
/* #undef SPEWFROMOPS */

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Unix group of admin user */
#define TBADMINGROUP "tbadmin"

/* Base URL for Emulab files */
#define TBBASE "https://www.cloudlab.umass.edu"

/* Emulab DB name */
#define TBDBNAME "tbdb"

/* Emulab errorlog DB */
#define TBERRORLOGDBNAME "errorlog"

/* FS base for Emulab files */
#define TBROOT "/test"

/* Something about TPM */
/* #undef TPM */

/* DNS name of ops node */
#define USERNODE "ops.cloudlab.umass.edu"

/* IPv4 address of ops node to be used by nodes */
#define USERNODE_IP "198.22.255.4"

/* Root of 'users' filesystem */
#define USERSROOT_DIR "/users"

/* Support Windows images */
/* #undef WINSUPPORT */

/* Run AMD on boss node to handle shared FS mounts */
#define WITHAMD 1

/* Use ZFS on FS node for shared filesystems */
#define WITHZFS 1

/* We aree mapping geni users to local users. Ditto projects and groups. */
#define PROTOGENI_LOCALUSER 1
