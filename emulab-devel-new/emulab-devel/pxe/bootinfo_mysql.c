/*
 * Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <arpa/inet.h>
#include <string.h>
#include "config.h"
#include "log.h"
#include "tbdb.h"
#include "bootwhat.h"
#include "bootinfo.h"
#include <mysql/mysql.h>

/* XXX Should be configured in */
#define NEWNODEPID      "emulab-ops"
#define NEWNODEOSID	"NEWNODE-MFS"

#ifdef USE_MYSQL_DB

static int parse_multiboot_path(char *path, boot_what_t *info);
static void parse_features(char *path, boot_what_t *info);
static void parse_mfs_path(char *path, boot_what_t *info);
static int boot_newnode_mfs(struct in_addr, int, boot_what_t *);

int
open_bootinfo_db(void)
{
	if (!dbinit())
		return 1;

	return 0;
}

int
findnode_bootinfo_db(struct in_addr ipaddr, int *events)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;

	res = mydb_query("select n.node_id,na.attrvalue,nt.attrvalue "
			 "from nodes as n "
			 "left join interfaces as i "
			 "  on n.node_id=i.node_id "
			 "left join node_attributes as na on "
			 "  n.node_id=na.node_id and na.attrkey='boot_method' "
			 "left join node_type_attributes as nt on "
			 "  n.type=nt.type and nt.attrkey='boot_method' "
			 "where i.IP='%s' and "
			 "      (i.role='ctrl' or i.role='outer_ctrl')",
			 3, inet_ntoa(ipaddr));
	if (!res) {
		error("Query failed for host %s\n", inet_ntoa(ipaddr));
		return 0;
	}
	if (!mysql_num_rows(res)) {
		mysql_free_result(res);
		return 0;
	}

	row = mysql_fetch_row(res);
	if ((row[1] && strcmp(row[1], "pxelinux") == 0) ||
	    (row[2] && strcmp(row[2], "pxelinux") == 0))
		*events = 0;
	else
		*events = 1;

	mysql_free_result(res);
	return 1;
}

/*
  WARNING!!!
  
  DO NOT change this function without making corresponding changes to
  the perl version of this code in db/libdb.pm . They MUST ALWAYS
  return exactly the same result given the same inputs.
*/

int
query_bootinfo_db(struct in_addr ipaddr, char *node_id, int version, 
		  boot_what_t *info, char* key)
{
	int		nrows, rval = 0;
	MYSQL_RES	*res, *res2;
	MYSQL_ROW	row, row2;
	char		ipstr[32];
	int		haskey=0;
	int             bootdisk_bios_id = 0;

	char		savedkey[HOSTKEY_LENGTH];
	if(key != NULL)
		{
		strncpy(savedkey, key, HOSTKEY_LENGTH);
		haskey=1;
		}
	info->cmdline[0] = 0;	/* Must zero first byte! */
	info->flags      = 0;
	strcpy(ipstr, inet_ntoa(ipaddr));

#define DEF_BOOT_OSID		0
#define DEF_BOOT_CMDLINE	1
#define DEF_BOOT_PATH		2
#define DEF_BOOT_MFS		3
#define DEF_BOOT_FEATURES	4
#define DEF_BOOT_PARTITION	5
#define TEMP_BOOT_OSID		6
#define TEMP_BOOT_PATH		7
#define TEMP_BOOT_MFS		8
#define TEMP_BOOT_FEATURES	9
#define TEMP_BOOT_PARTITION	10
#define NEXT_BOOT_OSID		11
#define NEXT_BOOT_CMDLINE	12
#define NEXT_BOOT_PATH		13
#define NEXT_BOOT_MFS		14
#define NEXT_BOOT_FEATURES	15
#define NEXT_BOOT_PARTITION	16
#define PID			17
#define PXE_BOOT_PATH		18

#define NCOLS			19

#define DEFINED(x)		(row[(x)] != NULL && row[(x)][0] != '\0')
#define TOINT(x)		(atoi(row[(x)]))

	if (node_id) {
		/*
		 * Right now, this is ONLY used for checking bootinfo for
		 * imageable vnodes.  All bets off if you try it for something
		 * else!
		 */
		res = mydb_query("select n.def_boot_osid, n.def_boot_cmd_line, "
				 "        odef.path, odef.mfs, "
				 "        odef.osfeatures, pdef.`partition`, "
				 "       n.temp_boot_osid, "
				 "        otemp.path, otemp.mfs, "
				 "        otemp.osfeatures, ptemp.`partition`, "
				 "       n.next_boot_osid, n.next_boot_cmd_line, "
				 "        onext.path, onext.mfs, "
				 "        onext.osfeatures, pnext.`partition`, "
				 "       r.pid,n.pxe_boot_path "
				 " from nodes as n "
				 "left join reserved as r on n.node_id=r.node_id "
				 "left join `partitions` as pdef on "
				 "     n.node_id=pdef.node_id and "
				 "     n.def_boot_osid=pdef.osid "
				 "left join os_info as oidef on "
				 "     oidef.osid=n.def_boot_osid "
				 "left join os_info_versions as odef on "
				 "     odef.osid=oidef.osid and "
				 "     odef.vers=oidef.version "
				 "left join `partitions` as ptemp on "
				 "     n.node_id=ptemp.node_id and "
				 "     n.temp_boot_osid=ptemp.osid "
				 "left join os_info as oitemp on "
				 "     oitemp.osid=n.temp_boot_osid "
				 "left join os_info_versions as otemp on "
				 "     otemp.osid=oitemp.osid and "
				 "     otemp.vers=oitemp.version "
				 "left join `partitions` as pnext on "
				 "     n.node_id=pnext.node_id and "
				 "     n.next_boot_osid=pnext.osid "
				 "left join os_info as oinext on "
				 "     oinext.osid=n.next_boot_osid "
				 "left join os_info_versions as onext on "
				 "     onext.osid=oinext.osid and "
				 "     onext.vers=oinext.version "
				 "left outer join "
				 "  (select type,attrvalue from node_type_attributes "
				 "     where attrkey='nobootinfo' and attrvalue='1' "
				 "     group by type,attrvalue) as nobootinfo_types "
				 "  on n.type=nobootinfo_types.type "
				 "where n.node_id='%s' "
				 "  and nobootinfo_types.attrvalue is NULL",
				 NCOLS, node_id);
	}
	else if (! haskey) {
		res = mydb_query("select n.def_boot_osid, n.def_boot_cmd_line, "
				 "        odef.path, odef.mfs, "
				 "        odef.osfeatures, pdef.`partition`, "
				 "       n.temp_boot_osid, "
				 "        otemp.path, otemp.mfs, "
				 "        otemp.osfeatures, ptemp.`partition`, "
				 "       n.next_boot_osid, n.next_boot_cmd_line, "
				 "        onext.path, onext.mfs, "
				 "        onext.osfeatures, pnext.`partition`, "
				 "       r.pid,n.pxe_boot_path "
				 " from interfaces as i "
				 "left join nodes as n on i.node_id=n.node_id "
				 "left join reserved as r on i.node_id=r.node_id "
				 "left join `partitions` as pdef on "
				 "     n.node_id=pdef.node_id and "
				 "     n.def_boot_osid=pdef.osid "
				 "left join os_info as oidef on "
				 "     oidef.osid=n.def_boot_osid "
				 "left join os_info_versions as odef on "
				 "     odef.osid=oidef.osid and "
				 "     odef.vers=oidef.version "
				 "left join `partitions` as ptemp on "
				 "     n.node_id=ptemp.node_id and "
				 "     n.temp_boot_osid=ptemp.osid "
				 "left join os_info as oitemp on "
				 "     oitemp.osid=n.temp_boot_osid "
				 "left join os_info_versions as otemp on "
				 "     otemp.osid=oitemp.osid and "
				 "     otemp.vers=oitemp.version "
				 "left join `partitions` as pnext on "
				 "     n.node_id=pnext.node_id and "
				 "     n.next_boot_osid=pnext.osid "
				 "left join os_info as oinext on "
				 "     oinext.osid=n.next_boot_osid "
				 "left join os_info_versions as onext on "
				 "     onext.osid=oinext.osid and "
				 "     onext.vers=oinext.version "
				 "left outer join "
				 "  (select type,attrvalue from node_type_attributes "
				 "     where attrkey='nobootinfo' and attrvalue='1' "
				 "     group by type,attrvalue) as nobootinfo_types "
				 "  on n.type=nobootinfo_types.type "
				 "where i.IP='%s' "
				 "  and nobootinfo_types.attrvalue is NULL",
				 NCOLS, inet_ntoa(ipaddr));

		/* Get boot drive from DB */
		res2 = mydb_query("select attrvalue from node_attributes as a, nodes as n, interfaces as i where "
				  "i.IP = '%s' and i.node_id = n.node_id and n.node_id = a.node_id and a.attrkey = 'bootdisk_bios_id';",
				  1, inet_ntoa(ipaddr));

		if (!res2) {
			error("Query failed for host %s\n", node_id ? node_id : ipstr);
			/* XXX Wrong. Should fail so client can request again later */
			return 0;
		}

		if (!mysql_num_rows(res2)) {
			mysql_free_result(res2);
			res2 = mydb_query("select attrvalue from node_type_attributes as a, nodes as n, interfaces as i where "
					  "i.IP = '%s' and i.node_id = n.node_id and n.type = a.type and a.attrkey = 'bootdisk_bios_id';",
					  1, inet_ntoa(ipaddr));

			if (!res2) {
				error("Query failed for host %s\n", node_id ? node_id : ipstr);
				/* XXX Wrong. Should fail so client can request again later */
				return 0;
			}
		}

		if (mysql_num_rows(res2)) {
			row2 = mysql_fetch_row(res2);
			bootdisk_bios_id = atoi(row2[0]);
		}
		
		mysql_free_result(res2);
	}
	else { /* User provided a widearea hostkey, so they don't have a necessarily-unique IP address. */
		/* This is meant to be similar to the above, but queries on the wideareanodekey instead. */
		res = mydb_query("SELECT n.def_boot_osid, n.def_boot_cmd_line, "
				 " odef.path, odef.mfs, "
				 " odef.osfeatures, pdef.`partition`, "
				 "n.temp_boot_osid, "
				 " otemp.path, otemp.mfs, "
				 " otemp.osfeatures, ptemp.`partition`, "
				 "n.next_boot_osid, n.next_boot_cmd_line, "
				 " onext.path, onext.mfs, "
				 " onext.osfeatures, pnext.`partition`, "
				 "r.pid,n.pxe_boot_path "
				 "FROM nodes AS n "
				 "LEFT JOIN reserved AS r ON "
				 "     n.node_id=r.node_id "
				 "LEFT JOIN `partitions` AS pdef ON "
				 "     n.node_id=pdef.node_id AND "
				 "     n.def_boot_osid=pdef.osid "
				 "LEFT JOIN os_info AS oidef ON "
				 "     oidef.osid=n.def_boot_osid "
				 "left join os_info_versions as odef on "
				 "     odef.osid=oidef.osid and "
				 "     odef.vers=oidef.version "
				 "LEFT JOIN `partitions` AS ptemp ON"
				 "     n.node_id=ptemp.node_id AND "
				 "     n.temp_boot_osid=ptemp.osid "
				 "LEFT JOIN os_info AS oitemp ON "
				 "     oitemp.osid=n.temp_boot_osid "
				 "left join os_info_versions as otemp on "
				 "     otemp.osid=oitemp.osid and "
				 "     otemp.vers=oitemp.version "
				 "LEFT JOIN `partitions` AS pnext ON "
				 "     n.node_id=pnext.node_id AND "
				 "     n.next_boot_osid=pnext.osid "
				 "LEFT JOIN os_info AS oinext ON "
				 "     oinext.osid=n.next_boot_osid "
				 "left join os_info_versions as onext on "
				 "     onext.osid=oinext.osid and "
				 "     onext.vers=oinext.version "
				 "LEFT OUTER JOIN "
					"(SELECT type,attrvalue FROM "
				 "         node_type_attributes WHERE "
				 "           attrkey='nobootinfo' AND "
				 "           attrvalue='1' "
				 "          GROUP BY type,attrvalue) "
				 	"AS nobootinfo_types ON "
				 "         n.type=nobootinfo_types.type "
				 "WHERE n.node_id IN "
				 "    (SELECT node_id FROM widearea_nodeinfo "
				 "     WHERE privkey='%s') "
				 "AND nobootinfo_types.attrvalue IS NULL;",
				 NCOLS, savedkey);
	}
	
	if (!res) {
		error("Query failed for host %s\n", node_id ? node_id : ipstr);
		/* XXX Wrong. Should fail so client can request again later */
		return 0;
	}
	nrows = mysql_num_rows(res);

	switch (nrows) {
	case 0:
		mysql_free_result(res);
		return boot_newnode_mfs(ipaddr, version, info);
	case 1:
		break;
	default:
		error("%d entries for host %s\n",
		      nrows, node_id ? node_id : ipstr);
		break;
	}
	row = mysql_fetch_row(res);

	/*
	 * Version >=1 supports wait if not allocated. Client will recontact
	 * us later.
	 */
	if (version >= 1 && row[PID] == (char *) NULL) {
		info->type = BIBOOTWHAT_TYPE_WAIT;
		goto done;
	}

	/*
	 * If we received a query from a node whose PXE boot program is
	 * not an "Emulab pxeboot", then the node may be coming out of PXEWAIT
	 * and we need to tell it to reboot again to pick up the new PXE boot
	 * program.  An "Emulab pxeboot" is one that speaks bootinfo.
	 *
	 * XXX note that an "Emulab pxeboot" is currently identified by
	 * its not being the default pxeboot and its path containing the
	 * string "pxeboot" anywhere.
	 */
	if (DEFINED(PXE_BOOT_PATH) &&
	    strstr(row[PXE_BOOT_PATH], "pxeboot") == NULL) {
		info->type = BIBOOTWHAT_TYPE_REBOOT;
		goto done;
	}

	/*
	 * Check next_boot_osid. It overrides the others. It should be
	 * the case that partition and path/mfs are mutually exclusive.
	 * mfs might be set when path is set.  
	 */
	if (DEFINED(NEXT_BOOT_OSID)) {
		if (DEFINED(NEXT_BOOT_PATH)) {
			if (DEFINED(NEXT_BOOT_MFS) && TOINT(NEXT_BOOT_MFS) == 1){
				info->type = BIBOOTWHAT_TYPE_MFS;
				parse_features(row[NEXT_BOOT_FEATURES], info);
				parse_mfs_path(row[NEXT_BOOT_PATH], info);
			}
			else {
				info->type = BIBOOTWHAT_TYPE_MB;
				parse_multiboot_path(row[NEXT_BOOT_PATH], info);
			}
		}
		else if (DEFINED(NEXT_BOOT_PARTITION)) {
			if (bootdisk_bios_id) {
				info->type = BIBOOTWHAT_TYPE_DISKPART;
				info->what.dp.disk = bootdisk_bios_id;
				info->what.dp.partition = TOINT(NEXT_BOOT_PARTITION);
			} else {
				info->type = BIBOOTWHAT_TYPE_PART;
				info->what.partition = TOINT(NEXT_BOOT_PARTITION);
			}
		}
		else {
			error("Invalid NEXT_BOOT entry for host %s\n",
			      node_id ? node_id : ipstr);
			rval = 1;
		}
		if (DEFINED(NEXT_BOOT_CMDLINE)) {
			/*
			 * XXX note that this will override any cmdline
			 * specified in the osid path.  Should append instead?
			 */
			strncpy(info->cmdline,
				row[NEXT_BOOT_CMDLINE], MAX_BOOT_CMDLINE-1);
		}
		goto done;
	}

	/*
	 * Check temp_boot_osid. It overrides def_boot but not next_boot.
	 */
	if (DEFINED(TEMP_BOOT_OSID)) {
		if (DEFINED(TEMP_BOOT_PATH)) {
			if (DEFINED(TEMP_BOOT_MFS) && TOINT(TEMP_BOOT_MFS) == 1){
				info->type = BIBOOTWHAT_TYPE_MFS;
				parse_features(row[TEMP_BOOT_FEATURES], info);
				parse_mfs_path(row[TEMP_BOOT_PATH], info);
			}
			else {
				info->type = BIBOOTWHAT_TYPE_MB;
				parse_multiboot_path(row[TEMP_BOOT_PATH], info);
			}
		}
		else if (DEFINED(TEMP_BOOT_PARTITION)) {
			if (bootdisk_bios_id) {
				info->type = BIBOOTWHAT_TYPE_DISKPART;
				info->what.dp.disk = bootdisk_bios_id;
				info->what.dp.partition = TOINT(TEMP_BOOT_PARTITION);
			} else {
				info->type = BIBOOTWHAT_TYPE_PART;
				info->what.partition = TOINT(TEMP_BOOT_PARTITION);
			}
		}
		else {
			error("Invalid TEMP_BOOT entry for host %s\n",
			      node_id ? node_id : ipstr);
			rval = 1;
		}
		goto done;
	}

	/*
	 * Lastly, def_boot.
	 */
	if (DEFINED(DEF_BOOT_OSID)) {
		if (DEFINED(DEF_BOOT_PATH)) {
			if (DEFINED(DEF_BOOT_MFS) && TOINT(DEF_BOOT_MFS) == 1) {
				info->type = BIBOOTWHAT_TYPE_MFS;
				parse_features(row[DEF_BOOT_FEATURES], info);
				parse_mfs_path(row[DEF_BOOT_PATH], info);
			}
			else {
				info->type = BIBOOTWHAT_TYPE_MB;
				parse_multiboot_path(row[DEF_BOOT_PATH], info);
			}
		}
		else if (DEFINED(DEF_BOOT_PARTITION)) {
			if (bootdisk_bios_id) {
				info->type = BIBOOTWHAT_TYPE_DISKPART;
				info->what.dp.disk = bootdisk_bios_id;
				info->what.dp.partition = TOINT(DEF_BOOT_PARTITION);
			} else {
				info->type = BIBOOTWHAT_TYPE_PART;
				info->what.partition = TOINT(DEF_BOOT_PARTITION);
			}
		}
		else {
			error("Invalid DEF_BOOT entry for host %s\n",
			      node_id ? node_id : ipstr);
			rval = 1;
		}
		if (DEFINED(DEF_BOOT_CMDLINE)) {
			/*
			 * XXX note that this will override any cmdline
			 * specified in the osid path.  Should append instead?
			 */
			strncpy(info->cmdline,
				row[DEF_BOOT_CMDLINE], MAX_BOOT_CMDLINE-1);
		}
		goto done;
	}
	/*
	 * If we get here, there is no bootinfo to give the client.
	 * New PXE boot clients get PXEWAIT, but older ones get an error.
	 */
	error("No OSIDs set for host %s\n", node_id ? node_id : ipstr);
	if (version >= 1) {
		info->type = BIBOOTWHAT_TYPE_WAIT;
		goto done;
	}
	rval = 1;
 done:

	/*
	 * XXX horrific state-specific hack.
	 *
	 * Currently, for nodes that use the gPXE boot dongle, they exit
	 * secure mode (do a TPM "sign-off") before entering PXEWAIT when
	 * freed. When such a node is allocated and it has to reload its
	 * disk, we must reboot the node so that the TPM sign off PCR is
	 * cleared and the secure boot path is cleanly restarted.
	 *
	 * For reasons too bogus to talk about, we cannot currently do
	 * this from stated. So here we detect a wakeup from PXEWAIT for
	 * the purposes of reloading the disk via the "secure MFS".
	 */
	if (!rval && !node_id && info->type == BIBOOTWHAT_TYPE_MFS &&
	    (info->flags & BIBOOTWHAT_FLAGS_SECURE) != 0) {
		res2 = mydb_query("select op_mode,eventstate from "
				  " nodes as n, interfaces as i "
				  " where n.node_id=i.node_id and i.IP='%s'",
				  2, ipstr);
		if (res2) {
			if (mysql_num_rows(res2)) {
				row2 = mysql_fetch_row(res2);
				error("Secure booting node %s in %s/%s\n",
				      ipstr, row2[0], row2[1]);
				if (strcmp(row2[0], "PXEKERNEL") == 0) {
					info->type = BIBOOTWHAT_TYPE_REBOOT;
					error("Forcing reboot of %s\n", ipstr);
				}
			}
			mysql_free_result(res2);
		}
	}

	mysql_free_result(res);
	return rval;
}

int
close_bootinfo_db(void)
{
	dbclose();
	return 0;
}

/*
 * Split a multiboot path into the IP and Path.
 */
static int
parse_multiboot_path(char *path, boot_what_t *info)
{
	char		*p  = path;
	struct hostent	*he;

	info->type = BIBOOTWHAT_TYPE_MB;
	info->what.mb.tftp_ip.s_addr = 0;

	strsep(&p, ":");
	if (p) {
		he = gethostbyname(path);
		path = p;
	}
	else {
		he = gethostbyname("users.emulab.net");
	}
	if (he) {
		memcpy((char *)&info->what.mb.tftp_ip,
		       he->h_addr, sizeof(info->what.mb.tftp_ip));
	}

	strncpy(info->what.mb.filename, path, MAX_BOOT_PATH-1);

	return 0;
}

/*
 * Arrange to boot the special newnode kernel.
 */
static int
boot_newnode_mfs(struct in_addr ipaddr, int version, boot_what_t *info)
{
	int		nrows;
	MYSQL_RES	*res;
	MYSQL_ROW	row;

	error("%s: nonexistent IP, booting '%s,%s'\n",
	      inet_ntoa(ipaddr), NEWNODEPID, NEWNODEOSID);

#define MFS_PATH	0

	res = mydb_query("select v.path from os_info as o "
			 "left join os_info_versions as v on "
			 "     v.osid=o.osid and v.vers=o.version "
			 "where o.pid='%s' and o.osname='%s' and v.mfs=1 ",
			 1, NEWNODEPID, NEWNODEOSID);

	if (!res) {
		error("Query failed\n");
		/* XXX Wrong. Should fail so client can request again later */
		return 0;
	}
	nrows = mysql_num_rows(res);

	switch (nrows) {
	case 0:
		error("No DB entry for OSID %s\n", NEWNODEOSID);
		mysql_free_result(res);
		return 1;
	case 1:
		break;
	default:
		error("Too many DB entries for OSID %s\n", NEWNODEOSID);
		mysql_free_result(res);
		return 1;
	}
	row = mysql_fetch_row(res);

	if (row[MFS_PATH] != 0 && row[MFS_PATH][0] != '\0') {
		info->type = BIBOOTWHAT_TYPE_MFS;
		parse_mfs_path(row[MFS_PATH], info);
		mysql_free_result(res);
		return 0;
	}
	mysql_free_result(res);
	error("No path info for OSID %s\n", NEWNODEOSID);
	return 1;
#undef  MFS_PATH
}

void
parse_mfs_path(char *str, boot_what_t *info)
{
	struct hostent *he;
	struct in_addr hip;
	char *path, *args;

	/* treat anything after a space as the command line */
	args = strchr(str, ' ');
	if (args != NULL) {
		*args++ = '\0';
		strncpy(info->cmdline, args, MAX_BOOT_CMDLINE-1);
	}

	/* no hostname, just copy string as is */
	path = strchr(str, ':');
	if (path == NULL) {
		strncpy(info->what.mfs, str, sizeof(info->what.mfs));
		return;
	}
	*path = '\0';

	/* hostname is a valid IP addr, copy as is */
	if (inet_addr(str) != INADDR_NONE) {
		*path = ':';
		strncpy(info->what.mfs, str, sizeof(info->what.mfs));
		return;
	}

	/* not a valid hostname, whine and copy it as is */
	he = gethostbyname(str);
	if (he == NULL) {
		*path = ':';
		error("Invalid hostname in MFS path '%s', passing anyway\n",
		      str);
		strncpy(info->what.mfs, str, sizeof(info->what.mfs));
		return;
	}
	*path = ':';

	/* valid hostname, translate to IP and replace in string */
	memcpy((char *)&hip, he->h_addr, he->h_length);
	strcpy(info->what.mfs, inet_ntoa(hip));
	strncat(info->what.mfs, path,
		sizeof(info->what.mfs)-strlen(info->what.mfs));
}

static void
parse_features(char *str, boot_what_t *info)
{
	/* Note that features might be a null string; no features */
	if (str && strstr(str, "ontrustedboot")) {
		info->flags |= BIBOOTWHAT_FLAGS_SECURE;
	}
}

/*
 * ElabinElab hack. Its really terrible!
 */
#ifdef ELABINELAB
int
elabinelab_hackcheck(struct sockaddr_in *target)
{
	int		nrows;
	MYSQL_RES	*res;
	MYSQL_ROW	row;

	res = mydb_query("select i2.IP from interfaces as i1 "
			 "left join interfaces as i2 on i2.node_id=i1.node_id "
			 "     and i2.role='outer_ctrl' "
			 "where i1.IP='%s'", 1, inet_ntoa(target->sin_addr));
	if (!res) {
		error("elabinelab_hackcheck failed for host %s\n",
		      inet_ntoa(target->sin_addr));
		/* XXX Wrong. Should fail so client can request again later */
		return 0;
	}

	nrows = mysql_num_rows(res);

	switch (nrows) {
	case 0:
		/* No hack interface */
		mysql_free_result(res);
		return 0;
	case 1:
		break;
	default:
		error("elabinelab_hackcheck: Too many DB entries %s\n",
		      inet_ntoa(target->sin_addr));
		mysql_free_result(res);
		return 1;
	}
	row = mysql_fetch_row(res);

	if (row[0] != 0 && row[0][0] != '\0') {
		inet_aton(row[0], &(target->sin_addr));
		mysql_free_result(res);
		return 0;
	}
	mysql_free_result(res);
	error("elabinelab_hackcheck: No IP address %s\n",
	      inet_ntoa(target->sin_addr));
	return 1;
}
#endif

#ifdef TEST
#include <stdarg.h>

static void
print_bootwhat(boot_what_t *bootinfo)
{
	switch (bootinfo->type) {
	case BIBOOTWHAT_TYPE_PART:
		printf("boot from partition %d\n",
		       bootinfo->what.partition);
		break;
	case BIBOOTWHAT_TYPE_SYSID:
		printf("boot from partition with sysid %d\n",
		       bootinfo->what.sysid);
		break;
	case BIBOOTWHAT_TYPE_MB:
		printf("boot multiboot image %s:%s\n",
		       inet_ntoa(bootinfo->what.mb.tftp_ip),
		       bootinfo->what.mb.filename);
		break;
	case BIBOOTWHAT_TYPE_WAIT:
		printf("No boot; waiting till allocated\n");
		break;
	case BIBOOTWHAT_TYPE_MFS:
		printf("boot from MFS %s\n", bootinfo->what.mfs);
		break;
	}
	if (bootinfo->cmdline[0])
		printf("Command line %s\n", bootinfo->cmdline);
		
}

int
main(int argc, char **argv)
{
	struct in_addr ipaddr;
	boot_info_t boot_info;
	boot_what_t *boot_whatp = (boot_what_t *)&boot_info.data;

	open_bootinfo_db();
	while (--argc > 0) {
		if (inet_aton(*++argv, &ipaddr))
			if (query_bootinfo_db(ipaddr, 1, boot_whatp) == 0) {
				printf("%s: ", *argv);
				print_bootwhat(boot_whatp);
			} else
				printf("%s: failed\n", *argv);
		else
			printf("bogus IP address `%s'\n", *argv);
	}
	close_bootinfo_db();
	exit(0);
}
#endif
#endif
