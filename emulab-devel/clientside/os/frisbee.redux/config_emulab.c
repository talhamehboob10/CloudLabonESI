/*
 * Copyright (c) 2010-2020 University of Utah and the Flux Group.
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

/*
 * Configuration "file" handling for Emulab.
 *
 * Uses info straight from the Emulab database.
 */ 

#ifdef USE_EMULAB_CONFIG
#include <sys/param.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <mysql/mysql.h>
#include "decls.h"
#include "log.h"
#include "configdefs.h"

/* Emulab includes */
#include "tbdb.h"	/* the DB library */
#include "config.h"	/* the defs-* defines */

extern int debug;

/*
 * Private configuration state that can be saved/restored.
 *
 * For Emulab, there are only a couple of DB values that don't change
 * that often.
 */
struct emulab_configstate {
	int image_maxsize;	/* sitevar:images/create/maxsize (in GB) */
	int image_maxwait;	/* sitevar:images/create/maxwait (in min) */
	int image_maxiwait;	/* sitevar:images/create/idlewait (in min) */
	int image_maxrate_dyn;	/* sitevar:images/frisbee/maxrate_dynamic */
	int image_maxrate_std;	/* sitevar:images/frisbee/maxrate_std (in Mb/s) */
	int image_maxrate_usr;	/* sitevar:images/frisbee/maxrate_usr (in Mb/s) */
	int image_maxlinger;	/* sitevar:images/frisbee/maxlinger (in sec) */
	int image_clientreport;	/* sitevar:images/frisbee/heartbeat (in sec) */
};

/* Extra info associated with a image information entry */
struct emulab_ii_extra_info {
	int DB_imageid;
};

/* Extra info associated with a host authentication entry */
struct emulab_ha_extra_info {
	char *pid;	/* project */
	int pidix;	/* project table index */
	char *gid;	/* group */
	int gidix;	/* group table index */
	char *eid;	/* experiment */
	int eidix;	/* experiment table index */
	char *sname;	/* swapper user name */
	int suidix;	/* swapper user table index */
	int suid;	/* swapper's unix uid */
	gid_t sgids[MAXGIDS];	/* swapper's unix gids */
	int ngids;	/* number of gids */
};

static char *MC_BASEADDR = FRISEBEEMCASTADDR;
static char *MC_BASEPORT = FRISEBEEMCASTPORT;
#ifdef FRISEBEENUMPORTS
static char *MC_NUMPORTS = FRISEBEENUMPORTS;
#else
static char *MC_NUMPORTS = "0";
#endif
static char *SHAREDIR	 = SHAREROOT_DIR;
static char *PROJDIR	 = PROJROOT_DIR;
static char *GROUPSDIR	 = GROUPSROOT_DIR;
static char *USERSDIR	 = USERSROOT_DIR;
static char *SCRATCHDIR	 = SCRATCHROOT_DIR;
#ifdef ELABINELAB
static int INELABINELAB  = ELABINELAB;
#else
static int INELABINELAB  = 0;
#endif
#ifdef WITHAMD
static char *AMDROOT     = AMD_ROOT;
#else
static char *AMDROOT     = NULL;
#endif

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

static uint64_t	put_maxsize = 10000000000ULL;	/* zero means no limit */
static uint32_t put_maxwait = 2000;		/* zero means no limit */
static uint32_t put_maxiwait = 120;		/* zero means no limit */
static uint32_t get_maxrate_dyn = 0;		/* non-zero means use dynamic */
static uint32_t get_maxrate_std = 72000000;	/* zero means no limit */
static uint32_t get_maxrate_usr = 54000000;	/* zero means no limit */
static int      get_maxlinger = 3600;		/* zero means forever */
static int	get_clientreport = 0;		/* zero means none */
static char *	get_eserver = "localhost";	/* not a sitevar right now */

/* Standard image directory: assumed to be "TBROOT/images" */
static char *STDIMAGEDIR;

/* Emit aliases when dumping the config info; makes it smaller */
static int dump_doaliases = 1;

/* Multicast address/port base info */
static int mc_a, mc_b, mc_c, mc_port_lo, mc_port_num;

/* Memory alloc functions that abort when no memory */
static void *mymalloc(size_t size);
static void *myrealloc(void *ptr, size_t size);
static char *mystrdup(const char *str);

/*
 * Return the value of a sitevar as a string.
 * Returns in order: the value if set, default_value if set, NULL
 */
static char *
emulab_getsitevar(char *name)
{
	MYSQL_RES *res;
	MYSQL_ROW row;
	char *value = NULL;

	res = mydb_query("SELECT value,defaultvalue FROM sitevariables "
			 " WHERE name='%s'", 2, name);
	if (res == NULL)
		return NULL;

	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return NULL;
	}

	row = mysql_fetch_row(res);
	if (row[0])
		value = mystrdup(row[0]);
	else if (row[1])
		value = mystrdup(row[1]);
	mysql_free_result(res);

	return value;
}

static void
emulab_deinit(void)
{
	dbclose();
}

static int
emulab_read(void)
{
	char *val;
	int ival;

	/*
	 * Grab a couple of image creation related sitevars that don't
	 * change that often. We don't want to be reading these everytime
	 * set_put_values() gets called, so we do it explicitly here.
	 */
	val = emulab_getsitevar("images/create/maxsize");
	if (val) {
		ival = atoi(val);
		/* in GB, allow up to 10TB */
		if (ival >= 0 && ival <= 10000)
			put_maxsize = (uint64_t)ival * 1000 * 1000 * 1000;
		free(val);
	}
	FrisLog("  image_put_maxsize = %d GB",
		(int)(put_maxsize/(1000*1000*1000)));

	val = emulab_getsitevar("images/create/maxwait");
	if (val) {
		ival = atoi(val);
		/* in minutes, allow up to about 10TB @ 10MB/sec */
		if (ival >= 0 && ival <= 20000)
			put_maxwait = (uint32_t)ival * 60;
		free(val);
	}
	FrisLog("  image_put_maxwait = %d min",
		(int)(put_maxwait/60));

	val = emulab_getsitevar("images/create/idlewait");
	if (val) {
		ival = atoi(val);
		/* in minutes, allow up to about 10TB @ 10MB/sec */
		if (ival >= 0 && ival <= 20000)
			put_maxiwait = (uint32_t)ival * 60;
		free(val);
	}
	FrisLog("  image_put_maxiwait = %d min",
		(int)(put_maxiwait/60));

	val = emulab_getsitevar("images/frisbee/maxrate_dyn");
	if (val) {
		ival = atoi(val);
		get_maxrate_dyn = ival ? 1 : 0;
		free(val);
	}
	FrisLog("  image_get_maxrate_dyn = %s",
		get_maxrate_dyn ? "true" : "false");

	val = emulab_getsitevar("images/frisbee/maxrate_std");
	if (val) {
		ival = atoi(val);
		/* in bytes/sec, allow up to 2Gb/sec */
		if (ival >= 0 && ival <= 2000000000)
			get_maxrate_std = (uint32_t)ival;
		free(val);
	}
	if (get_maxrate_std == 0)
		FrisLog("  image_get_maxrate_std = unlimited");
	else
		FrisLog("  image_get_maxrate_std = %d Mbit/sec",
			(int)(get_maxrate_std/1000000));

	val = emulab_getsitevar("images/frisbee/maxrate_usr");
	if (val) {
		ival = atoi(val);
		/* in bytes/sec, allow up to 2Gb/sec */
		if (ival >= 0 && ival <= 2000000000)
			get_maxrate_usr = (uint32_t)ival;
		free(val);
	}
	if (get_maxrate_usr == 0)
		FrisLog("  image_get_maxrate_usr = unlimited");
	else
		FrisLog("  image_get_maxrate_usr = %d Mbit/sec",
			(int)(get_maxrate_usr/1000000));

	val = emulab_getsitevar("images/frisbee/heartbeat");
	if (val) {
		ival = atoi(val);
		if (ival < 0)
			ival = 0;
		get_clientreport = ival;
		free(val);
	}
	if (get_clientreport > 0) {
		FrisLog("  clients report progress every %d seconds",
			get_clientreport);
		if (get_eserver)
			FrisLog("  progress events sent to %s", get_eserver);
	}

	val = emulab_getsitevar("images/frisbee/maxlinger");
	if (val) {
		ival = atoi(val);
		if (ival < 0)
			ival = -1;
		get_maxlinger = ival;
		free(val);
	}
	if (get_maxlinger == -1)
		FrisLog("  server exits after last client leaves");
	else if (get_maxlinger == 0)
		FrisLog("  server never exits");
	else
		FrisLog("  server exits after %d seconds idle",
			get_maxlinger);

	return 0;
}

static void *
emulab_save(void)
{
	struct emulab_configstate *cs = mymalloc(sizeof(cs));

	cs->image_maxsize = put_maxsize;
	cs->image_maxwait = put_maxwait;
	cs->image_maxiwait = put_maxiwait;
	cs->image_maxrate_dyn = get_maxrate_dyn;
	cs->image_maxrate_std = get_maxrate_std;
	cs->image_maxrate_usr = get_maxrate_usr;
	cs->image_maxlinger = get_maxlinger;
	cs->image_clientreport = get_clientreport;

	return (void *)cs;
}

static int
emulab_restore(void *state)
{
	struct emulab_configstate *cs = state;

	put_maxsize = cs->image_maxsize;
	FrisLog("  image_put_maxsize = %d GB",
		(int)(put_maxsize/(1000*1000*1000)));
	put_maxwait = cs->image_maxwait;
	FrisLog("  image_put_maxwait = %d min",
		(int)(put_maxwait/60));
	put_maxiwait = cs->image_maxiwait;
	FrisLog("  image_put_maxiwait = %d min",
		(int)(put_maxiwait/60));
	get_maxrate_dyn = cs->image_maxrate_dyn;
	FrisLog("  image_get_maxrate_dyn = %s",
		get_maxrate_dyn ? "true" : "false");
	get_maxrate_std = cs->image_maxrate_std;
	if (get_maxrate_std == 0)
		FrisLog("  image_get_maxrate_std = unlimited");
	else
		FrisLog("  image_get_maxrate_std = %d Mbit/sec",
			(int)(get_maxrate_std/1000000));
	get_maxrate_usr = cs->image_maxrate_usr;
	if (get_maxrate_usr == 0)
		FrisLog("  image_get_maxrate_usr = unlimited");
	else
		FrisLog("  image_get_maxrate_usr = %d Mbit/sec",
			(int)(get_maxrate_usr/1000000));
	get_clientreport = cs->image_clientreport;
	if (get_clientreport > 0) {
		FrisLog("  clients report progress every %d seconds",
			get_clientreport);
		if (get_eserver)
			FrisLog("  progress events sent to %s", get_eserver);
	}
	get_maxlinger = cs->image_maxlinger;
	if (get_maxlinger == -1)
		FrisLog("  server exits after last client leaves");
	else if (get_maxlinger == 0)
		FrisLog("  server never exits");
	else
		FrisLog("  server exits after %d seconds idle",
			get_maxlinger);

	return 0;
}

static void
emulab_free(void *state)
{
	free(state);
}

/*
 * Set the GET options for a particular node/image.
 *
 * Methods:
 *   XXX for now, just multicast and unicast
 * Options:
 *   loading a "standard" image: 72Mb/sec
 *   any other image:            54Mb/sec
 *   running in elabinelab:      add keepalive of 15 sec.
 */
static void
set_get_values(struct config_host_authinfo *ai, int ix)
{
	struct config_imageinfo *ii = &ai->imageinfo[ix];
	char str[256];
	int maxrate;

	/* get_methods */
	ii->get_methods = CONFIG_IMAGE_MCAST;
#if 1
	/*
	 * XXX broadcast is a bad idea on a large shared LAN environment.
	 * But it can be enabled/disabled in the server, so this flag
	 * doesn't hurt.
	 */
	ii->get_methods |= CONFIG_IMAGE_BCAST;
#endif
#if 1
	/*
	 * XXX the current frisbee server allows only a single client
	 * in unicast mode, which makes this option rather limited.
	 * So you may not want to allow it by default.
	 */
	ii->get_methods |= CONFIG_IMAGE_UCAST;
#endif

	/* get_timeout */
	ii->get_timeout = get_maxlinger;

	/*
	 * We use a small server inactive timeout since we no longer have
	 * to start up a frisbeed well in advance of the client(s).
	 */
	if (INELABINELAB && ii->get_timeout > 60)
		ii->get_timeout = 60;

	/*
	 * get_options:
	 *  - max std/usr rate of zero means unlimited.
	 *  - for dynamic rate adjustment, we use the std/usr
	 *    bandwidth value as the maximum bandwidth.
	 */
	maxrate = isindir(STDIMAGEDIR, ii->path) ?
		get_maxrate_std : get_maxrate_usr;
	if (maxrate)
		snprintf(str, sizeof str, " -W %u", maxrate);
	else
		snprintf(str, sizeof str, " -G 0");
	if (get_maxrate_dyn)
		strcat(str, " -D");

	/*
	 * for client reporting we set the interval and the event server
	 */
	if (get_clientreport > 0) {
		int len = strlen(str);
		snprintf(&str[len], sizeof(str) - len, " -H %d",
			 get_clientreport);
		if (get_eserver) {
			len = strlen(str);
			snprintf(&str[len], sizeof(str) - len, " -E %s",
				 get_eserver);
		}
	}
#if 0
	/*
	 * Should not be needed anymore. If the multicast group is getting
	 * dropped, the mserver should be configured to run as a querier (-Q).
	 */
	if (INELABINELAB)
		strcat(str, " -K 15");
#endif
	ii->get_options = mystrdup(str);

	/* and whack the put_* fields */
	ii->put_maxsize = 0;
	ii->put_timeout = 0;
	ii->put_itimeout = 0;
	ii->put_options = NULL;
	ii->put_oldversion = NULL;

	/*
	 * parent GET options:
	 *  - if we are making client reports, make sure that our downloads
	 *    from a parent enable those.
	 *    XXX right now, the server always dictates the interval.
	 */
	if (get_clientreport > 0) {
		snprintf(str, sizeof str, " -H 0");
		ii->pget_options = mystrdup(str);
	} else
		ii->pget_options = NULL;
}

/*
 * Set the PUT maxsize/options for a particular node/image.
 * XXX right now these mostly come from the DB.
 */
static void
set_put_values(struct config_host_authinfo *ai, int ix)
{
	struct config_imageinfo *ii = &ai->imageinfo[ix];

	/* put_maxsize */
	ii->put_maxsize = put_maxsize;

	/* put_timeout */
	ii->put_timeout = put_maxwait;
	ii->put_itimeout = put_maxiwait;

	/* put_oldversion */
#if 0
	/*
	 * For standard images, we keep ALL old versions as:
	 * <path>.<timestamp>, just because we are extra paranoid about those.
	 */
	if (isindir(STDIMAGEDIR, ii->path)) {
		time_t curtime;
		char *str;
		int len;

		curtime = time(NULL);
		len = strlen(ii->path) + 11;
		str = mymalloc(len);
		snprintf(str, len, "%s.%09u", ii->path, (unsigned)curtime);
		ii->put_oldversion = str;
	} else
#endif
	{
		int len = strlen(ii->path) + 5;
		ii->put_oldversion = mymalloc(len);
		snprintf(ii->put_oldversion, len, "%s.bak", ii->path);
	}

	/* put_options */
	ii->put_options = NULL;

	/* and whack the get_* fields */
	ii->get_methods = 0;
	ii->get_timeout = 0;
	ii->get_options = NULL;

	/* and the pget_* fields */
	ii->pget_options = NULL;
}

#define FREE(p) { if (p) free(p); }

/*
 * Free the dynamically allocated host_authinfo struct.
 */
static void
emulab_free_host_authinfo(struct config_host_authinfo *ai)
{
	int i;

	if (ai == NULL)
		return;

	FREE(ai->hostid);
	if (ai->imageinfo != NULL) {
		for (i = 0; i < ai->numimages; i++) {
			FREE(ai->imageinfo[i].imageid);
			FREE(ai->imageinfo[i].dir);
			FREE(ai->imageinfo[i].path);
			FREE(ai->imageinfo[i].sig);
			FREE(ai->imageinfo[i].get_options);
			FREE(ai->imageinfo[i].put_options);
			FREE(ai->imageinfo[i].put_oldversion);
			FREE(ai->imageinfo[i].pget_options);
			FREE(ai->imageinfo[i].extra);
		}
		free(ai->imageinfo);
	}
	if (ai->extra) {
		struct emulab_ha_extra_info *ei = ai->extra;

		FREE(ei->pid);
		FREE(ei->gid);
		FREE(ei->eid);
		FREE(ei->sname);
		free(ai->extra);
	}
	free(ai);
}

/*
 * Return the IP address/port-range to be used by the server/clients for
 * the image listed in ai->imageinfo[0].  Methods lists one or more transfer
 * methods that the client can handle, we return the method chosen.
 * If first is non-zero, then we need to return a "new" address and *addrp,
 * *loportp, and *hiportp are uninitialized.  If non-zero, then our last
 * choice failed (probably due to a port conflict) and we need to choose
 * a new address to try, possibly based on the existing info in *addrp,
 * *loportp and *hiportp.
 *
 * For Emulab, we use the frisbee_index from the DB along with the base
 * multicast address and port to compute a unique address/port.  Uses the
 * same logic that frisbeelauncher used to use.  For retries (first==0),
 * we choose a whole new addr/port for multicast.
 *
 * For unicast, we use the index as well, just to produce a unique port
 * number.
 *
 * NOTE: as of May 2015, we no longer generate a specific port number.
 * We return 0 or a range and let the frisbeed/frisuploadd choose.
 *
 * Return zero on success, non-zero otherwise.
 */
static int
emulab_get_server_address(struct config_imageinfo *ii, int methods, int first,
			  in_addr_t *addrp, in_port_t *loportp,
			  in_port_t *hiportp, int *methp)
{
	int	  idx;
	int	  a, b, c, d;

	if (!mydb_update("UPDATE emulab_indicies "
			" SET idx=LAST_INSERT_ID(idx+1) "
			" WHERE name='frisbee_index'")) {
		FrisError("get_server_address: DB update error!");
		return 1;
	}
 again:
	idx = mydb_insertid();
	assert(idx > 0);

	a = mc_a;
	b = mc_b;
	c = mc_c;
	d = 1;

	d += idx;
	if (d > 254) {
		c += (d / 254);
		d = (d % 254) + 1;
	}
	if (c > 254) {
		b += (c / 254);
		c = (c % 254) + 1;
	}
	if (b > 254) {
		FrisError("get_server_address: ran out of MC addresses! "
			  "Reset your DB emulab_indicies frisbee_index.\n");
		return 1;
	}

	if (methods & CONFIG_IMAGE_MCAST) {
		/*
		 * XXX avoid addresses that "flood".
		 * 224.0.0.x and 224.128.0.x are defined to flood,
		 * but because of the way IP multicast addresses map
		 * onto ethernet addresses (only the low 23 bits are used)
		 * ANY MC address (224-239) with those bits will also flood.
		 * So avoid those, by skipping over the problematic range
		 * in the index.
		 *
		 * Note that because of the way the above increment process
		 * works, this should never happen except when the initial
		 * MC_BASEADDR is bad in this way (i.e., because of the
		 * "c = (c % 254) + 1" this function will never generate
		 * a zero value for c).
		 */
		if (c == 0 && (b == 0 || b == 128)) {
			if (!mydb_update("UPDATE emulab_indicies "
					 " SET idx=LAST_INSERT_ID(idx+254) "
					 " WHERE name='frisbee_index'")) {
				FrisError("get_server_address: DB update error!");
				return 1;
			}
			goto again;
		}

		/*
		 * Note that by construction we also avoid the "scope relative"
		 * addresses which are the last 256 addresses in any scope;
		 * i.e., in our scopes x.x.255.0 - x.x.255.255. But let's be
		 * paranoid.
		 */
		assert(c != 255);

		*methp = CONFIG_IMAGE_MCAST;
		*addrp = (a << 24) | (b << 16) | (c << 8) | d;
	}
	/*
	 * Unicast is our second choice.
	 */
	else if (methods & CONFIG_IMAGE_UCAST) {
		*methp = CONFIG_IMAGE_UCAST;
		/* XXX on retries, we don't mess with the address */
		if (first)
			*addrp = 0;
	}
	/*
	 * Broadcast is the method of last resort since it could melt down
	 * a good-sized network.
	 */
	else if (methods & CONFIG_IMAGE_BCAST) {
		*methp = CONFIG_IMAGE_BCAST;
		/* XXX on retries, we don't mess with the address */
		if (first)
			*addrp = INADDR_BROADCAST;
	}
	else {
		FrisError("get_server_address: no supported method requested");
		return 1;
	}

	/*
	 * Calculate a port range:
	 *
	 * If mc_port_lo == 0, the server always chooses so we just return
	 * lo == hi == 0.
	 *
	 * Otherwise, if this is the first call, we use the index to compute
	 * a starting value in the [mc_port_lo - mc_port_lo+mc_port_num]
	 * range. Given an increasing index, these keeps us from starting
	 * to look at the same place everytime and (hopefully) will reduce
	 * the number of conflicts that the server encounters.
	 *
	 * If this was not the first call, we return the full range on
	 * every call.
	 */
	if (mc_port_num == 0) {
		*loportp = 0;
		*hiportp = 0;
	} else if (first) {
		*loportp = mc_port_lo + (idx % mc_port_num);
		*hiportp = mc_port_lo + mc_port_num - 1;
	} else {
		*loportp = mc_port_lo;
		*hiportp = mc_port_lo + mc_port_num - 1;
	}

	if (debug)
		FrisLog("get_server_address: idx %d, addr 0x%x, port [%d-%d]",
			idx, *addrp, *loportp, *hiportp);

	return 0;
}

/*
 * Returns one if the given path is the uploader_path from some image.
 * If imageid is non-NULL, return the <pid>/<name>:<version> string
 * for the image in question.
 */
static int
image_from_upath(char *path, char **imageid)
{
	MYSQL_RES *res;
	MYSQL_ROW row;

	/*
	 * XXX right now, the path may contain an AMD prefix.
	 * Strip it off if so.
	 */
	if (AMDROOT) {
		int arlen = strlen(AMDROOT);
		if (strncmp(AMDROOT, path, arlen) == 0) {
			path += arlen;
			assert(path[0] == '/');
		}
	}

	/*
	 * Look the path up, conveniently composing a canonical name in
	 * the process.
	 */
	res = mydb_query("SELECT CONCAT(pid,'%c',imagename,'%c',version) "
			 "FROM image_versions"
			 "  WHERE deleted IS NULL AND uploader_path='%s'",
			 1, IID_SEP_NAME, IID_SEP_VERS, path);
	if (res == NULL || mysql_num_rows(res) == 0) {
		if (res)
			mysql_free_result(res);
		return 0;
	}
	if (imageid != NULL) {
		/* XXX if rows > 1, we just return info from the first */
		row = mysql_fetch_row(res);
		assert(row[0] != NULL);
		*imageid = mystrdup(row[0]);
		mysql_free_result(res);
	}
	return 1;
}

/*
 * Check and see if the given image is in the set of standard directories
 * to which this node (actually pid/gid/eid/uid) has access.  The set is:
 *  - /share		      (GET only)
 *  - /proj/<pid>	      (GET or PUT)
 *  - in /groups/<pid>/<gid>  (GET or PUT)
 *  - in /users/<swapper-uid> (GET or PUT)
 * and, if it exists:
 *  - in /scratch/<pid>	      (GET or PUT)
 * For a GET, the entire path must exist and be accessible. For a PUT,
 * everything up to the final component must.
 *
 * If imageid is NULL, then we just return 

 * We assume the get and put structures have been initialized, in particular
 * that they contain the "extra" info which has the pid/gid/eid/uid.
 */
static void
allow_stddirs(char *imageid, 
	      struct config_host_authinfo *get,
	      struct config_host_authinfo *put)
{
	char tpath[PATH_MAX];
	char *fpath, *fdir;
	char *shdir, *pdir, *gdir, *scdir, *udir;
	struct emulab_ha_extra_info *ei;
	struct config_imageinfo *ci;
	struct stat sb;
	int exists;
	int onamd;

	if (get == NULL && put == NULL)
		return;

	fpath = NULL;

	/* XXX extra info is the same for both, we just need a valid one */
	ei = get ? get->extra : put->extra;

	/*
	 * Construct the allowed directories for this pid/gid/eid/uid.
	 * Note that these paths are "realpath approved".
	 */
	shdir = SHAREDIR;
	snprintf(tpath, sizeof tpath, "%s/%s", PROJDIR, ei->pid);
	pdir = mystrdup(tpath);

	snprintf(tpath, sizeof tpath, "%s/%s/%s", GROUPSDIR, ei->pid, ei->gid);
	gdir = mystrdup(tpath);

	snprintf(tpath, sizeof tpath, "%s/%s", USERSDIR, ei->sname);
	udir = mystrdup(tpath);

	if (SCRATCHDIR) {
		snprintf(tpath, sizeof tpath, "%s/%s", SCRATCHDIR, ei->pid);
		scdir = mystrdup(tpath);
	} else
		scdir = NULL;

	/*
	 * No image specified, just return info about the directories
	 * that are accessible.
	 */
	if (imageid == NULL) {
		int ni, i, j;
		size_t ns;
		char *dirs[8];

		/*
		 * Put allows all but SHAREDIR
		 */
		if (put != NULL) {
			dirs[0] = pdir;
			dirs[1] = gdir;
			dirs[2] = udir;
			dirs[3] = scdir;
			ni = put->numimages + (scdir ? 4 : 3);
			ns = ni * sizeof(struct config_imageinfo);
			if (put->imageinfo)
				put->imageinfo = myrealloc(put->imageinfo, ns);
			else
				put->imageinfo = mymalloc(ns);
			for (i = put->numimages; i < ni; i++) {
				ci = &put->imageinfo[i];
				ci->imageid = NULL;
				ci->dir = NULL;
				ci->path = mystrdup(dirs[i - put->numimages]);
				ci->flags = CONFIG_PATH_ISDIR;
				if (stat(ci->path, &sb) == 0) {
					ci->flags |= CONFIG_PATH_EXISTS;
					ci->sig = mymalloc(sizeof(time_t));
					*(time_t *)ci->sig = sb.st_mtime;
					ci->flags |= CONFIG_SIG_ISMTIME;
				} else
					ci->sig = NULL;
				ci->uid = ei->suid;
				for (j = 0; j < ei->ngids; j++)
					ci->gids[j] = ei->sgids[j];
				ci->ngids = ei->ngids;
				set_put_values(put, i);
				ci->extra = NULL;
			}
			put->numimages = ni;
		}
		/*
		 * Get allows any of the above
		 */
		if (get != NULL) {
			dirs[0] = shdir;
			dirs[1] = pdir;
			dirs[2] = gdir;
			dirs[3] = udir;
			dirs[4] = scdir;
			ni = get->numimages + (scdir ? 5 : 4);
			ns = ni * sizeof(struct config_imageinfo);
			if (get->imageinfo)
				get->imageinfo = myrealloc(get->imageinfo, ns);
			else
				get->imageinfo = mymalloc(ns);
			for (i = get->numimages; i < ni; i++) {
				ci = &get->imageinfo[i];
				ci->imageid = NULL;
				ci->dir = NULL;
				ci->path = mystrdup(dirs[i - get->numimages]);
				ci->flags = CONFIG_PATH_ISDIR;
				if (stat(ci->path, &sb) == 0) {
					ci->flags |= CONFIG_PATH_EXISTS;
					ci->sig = mymalloc(sizeof(time_t));
					*(time_t *)ci->sig = sb.st_mtime;
					ci->flags |= CONFIG_SIG_ISMTIME;
				} else
					ci->sig = NULL;
				ci->uid = ei->suid;
				for (j = 0; j < ei->ngids; j++)
					ci->gids[j] = ei->sgids[j];
				ci->ngids = ei->ngids;
				set_get_values(get, i);
				ci->extra = NULL;
			}
			get->numimages = ni;
		}
		goto done;
	}

	/*
	 * Image was specified.
	 *
	 * At this point we cannot do a full path check since the full path
	 * need not exist and we are possibly running with enhanced privilege.
	 * So we only weed out obviously bogus paths here (possibly checking
	 * just the partial path returned by realpath) and mark the imageinfo
	 * as needed a full resolution later.
	 */
	if (myrealpath(imageid, tpath) == NULL) {
		if (errno != ENOENT)
			goto done;
		exists = 0;
	} else
		exists = 1;
	fpath = mystrdup(tpath);
	if (debug)
		FrisInfo("%s: exists=%d, resolves to: '%s'",
			 imageid, exists, tpath);

	/*
	 * We have to explicitly check for the AMD prefix.
	 * The realpath resolution in emulab_init checks the root of
	 * each filesystem (e.g. "/proj") which won't be an AMD symlink,
	 * only the contents of the directories will be
	 * (e.g. "/proj/emulab-ops"). And, as of right now, we do not
	 * know which of /users, /proj, /groups and /share might be an
	 * AMD mount point.
	 */
	onamd = 0;
	if (AMDROOT) {
		int arlen = strlen(AMDROOT);

		if (strncmp(AMDROOT, tpath, arlen) == 0) {
			onamd = 1;
			free(fpath);
			fpath = mystrdup(tpath + arlen);
			if (debug)
				FrisInfo("%s: stripped AMD prefix", fpath);
		}
	}

	/*
	 * Make the appropriate access checks for get/put
	 */
	if (put != NULL &&
	    ((fdir = isindir(pdir, fpath)) ||
	     (fdir = isindir(gdir, fpath)) ||
	     (fdir = isindir(udir, fpath)) ||
	     (fdir = isindir(scdir, fpath)))) {
		int j;
		assert(put->imageinfo == NULL);

		put->imageinfo = mymalloc(sizeof(struct config_imageinfo));
		put->numimages = 1;
		ci = &put->imageinfo[0];
		ci->imageid = mystrdup(imageid);
		if (onamd) {
			assert(fdir[0] == '/');
			ci->dir = mymalloc(strlen(AMDROOT)+strlen(fdir)+1);
			strcpy(ci->dir, AMDROOT);
			strcat(ci->dir, fdir);
		} else
			ci->dir = mystrdup(fdir);
		ci->path = mystrdup(imageid);
		ci->flags = CONFIG_PATH_ISFILE|CONFIG_PATH_RESOLVE;
		if (exists && stat(ci->path, &sb) == 0) {
			ci->flags |= CONFIG_PATH_EXISTS;
			ci->sig = mymalloc(sizeof(time_t));
			*(time_t *)ci->sig = sb.st_mtime;
			ci->flags |= CONFIG_SIG_ISMTIME;
		} else
			ci->sig = NULL;
		ci->uid = ei->suid;
		for (j = 0; j < ei->ngids; j++)
			ci->gids[j] = ei->sgids[j];
		ci->ngids = ei->ngids;
		set_put_values(put, 0);
		if (ci->put_oldversion && image_from_upath(fpath, NULL)) {
			free(ci->put_oldversion);
			ci->put_oldversion = NULL;
		}
		ci->extra = NULL;
	} else if (put != NULL && debug)
		FrisInfo("authfail: image '%s' not in acceptable directory for '%s/%s'",
			 imageid, ei->pid, ei->gid);
	if (get != NULL &&
	    ((fdir = isindir(shdir, fpath)) ||
	     (fdir = isindir(pdir, fpath)) ||
	     (fdir = isindir(gdir, fpath)) ||
	     (fdir = isindir(scdir, fpath)) ||
	     (fdir = isindir(udir, fpath)))) {
		int j;
		assert(get->imageinfo == NULL);

		get->imageinfo = mymalloc(sizeof(struct config_imageinfo));
		get->numimages = 1;
		ci = &get->imageinfo[0];
		ci->imageid = mystrdup(imageid);
		if (onamd) {
			assert(fdir[0] == '/');
			ci->dir = mymalloc(strlen(AMDROOT)+strlen(fdir)+1);
			strcpy(ci->dir, AMDROOT);
			strcat(ci->dir, fdir);
		} else
			ci->dir = mystrdup(fdir);
		ci->path = mystrdup(imageid);
		ci->flags = CONFIG_PATH_ISFILE|CONFIG_PATH_RESOLVE;
		if (exists && stat(ci->path, &sb) == 0) {
			ci->flags |= CONFIG_PATH_EXISTS;
			ci->sig = mymalloc(sizeof(time_t));
			*(time_t *)ci->sig = sb.st_mtime;
			ci->flags |= CONFIG_SIG_ISMTIME;
		} else
			ci->sig = NULL;
		ci->uid = ei->suid;
		for (j = 0; j < ei->ngids; j++)
			ci->gids[j] = ei->sgids[j];
		ci->ngids = ei->ngids;
		set_get_values(get, 0);
		ci->extra = NULL;
	} else if (get != NULL && debug)
		FrisInfo("authfail: image '%s' not in acceptable directory for '%s/%s'",
			 imageid, ei->pid, ei->gid);

 done:
	free(pdir);
	free(gdir);
	free(udir);
	if (scdir)
		free(scdir);
	if (fpath)
		free(fpath);
}

/*
 * Get the Emulab nodeid for the node with the indicated control net IP.
 * Return a malloc'ed string on success, NULL otherwise.
 */
static char *
emulab_nodeid(struct in_addr *cnetip)
{
	MYSQL_RES *res;
	MYSQL_ROW row;
	char *node;

	res = mydb_query("SELECT node_id FROM interfaces"
			 " WHERE IP='%s' AND role='ctrl'",
			 1, inet_ntoa(*cnetip));
	if (res == NULL)
		return NULL;

	/* No such node */
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return NULL;
	}

	/* NULL node_id!? */
	row = mysql_fetch_row(res);
	if (!row[0]) {
		FrisError("config_host_authinfo: null node_id!?");
		mysql_free_result(res);
		return NULL;
	}
	node = mystrdup(row[0]);
	mysql_free_result(res);

	return node;
}

/*
 * Get the Emulab role for the given node.
 * Return a malloc'ed string on success, NULL otherwise (node doesn't exist).
 */
static char *
emulab_noderole(char *node)
{
	MYSQL_RES *res;
	MYSQL_ROW row;
	char *role;

	res = mydb_query("SELECT erole,inner_elab_role FROM reserved"
			 " WHERE node_id='%s'", 2, node);
	if (res == NULL)
		return NULL;

	/* Node is free */
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return NULL;
	}

	/*
	 * Is node an inner boss?
	 * Note that string could be "boss" or "boss+router"
	 * so we just check the prefix.
	 */
	row = mysql_fetch_row(res);
	role = row[0];
	if (role == NULL || role[0] == '\0') {
		mysql_free_result(res);
		return NULL;
	}

	/* recognize an inner boss node */
	if (strcmp(role, "node") == 0 &&
	    row[1] && strncmp(row[1], "boss", 4) == 0)
		role = "innerboss";

	role = mystrdup(role);
	mysql_free_result(res);

	return role;
}

/*
 * Get the Emulab internal imageid for the image identified by ipid/iname.
 * Return a non-zero index on success, zero otherwise.
 */
static int
emulab_imageid(char *ipid, char *iname)
{
	MYSQL_RES *res;
	MYSQL_ROW row;
	int id;

	res = mydb_query("SELECT imageid FROM images"
			 " WHERE pid='%s' AND imagename='%s'",
			 1, ipid, iname);
	if (res == NULL)
		return 0;

	/* No such image */
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		return 0;
	}

	/* NULL imageid!? */
	row = mysql_fetch_row(res);
	if (!row[0]) {
		FrisError("config_host_authinfo: null imageid!?");
		mysql_free_result(res);
		return 0;
	}
	id = atoi(row[0]);
	mysql_free_result(res);

	return id;
}

/*
 * Get the list of unix gids needed to access an image.
 * Returns the count of IDs put in igids, or zero on error.
 */
static int
emulab_imagegids(int imageidx, int *igids)
{
	MYSQL_RES *res;
	MYSQL_ROW row;
	int nrows;

	igids[0] = igids[1] = -1;

	res = mydb_query("SELECT unix_gid FROM groups AS g, images AS i"
			 " WHERE g.pid_idx=i.pid_idx"
			 " AND (g.gid_idx=g.pid_idx OR g.gid_idx=i.gid_idx)"
			 " AND imageid=%d", 1, imageidx);
	if (res == NULL) {
		FrisError("config_host_authinfo: image gid query failed!?");
		return 0;
	}

	nrows = mysql_num_rows(res);
	if (nrows > 2) {
		FrisError("config_host_authinfo: image gid query returned too many rows!?");
		mysql_free_result(res);
		return 0;
	}

	if (nrows > 0) {
		row = mysql_fetch_row(res);
		if (row[0] && row[0][0])
			igids[0] = atoi(row[0]);
		if (nrows > 1) {
			row = mysql_fetch_row(res);
			if (row[0] && row[0][0])
				igids[1] = atoi(row[0]);
		}
	}
	mysql_free_result(res);

	return nrows;
}

/*
 * Based on the image_permissions table, see if the user or group of the
 * experiment identified by ei can access the image with the given Emulab
 * imagid for either upload or download.
 *
 * Returns 1 if explicitly yes, 0 otherwise.
 */
static int
can_access(int imageidx, struct emulab_ha_extra_info *ei, int upload)
{
	MYSQL_RES *res;
	char *clause = "";

	if (upload)
		clause = "AND ip.allow_write=1";

	/*
	 * Check user permissions first.
	 */
	res = mydb_query("SELECT allow_write FROM image_permissions AS ip"
			 " WHERE ip.imageid=%d"
			 " AND ip.permission_type='user'"
			 " AND ip.permission_idx=%d %s",
			 1, imageidx, ei->suidix, clause);
	if (res) {
		if (mysql_num_rows(res) > 0) {
			mysql_free_result(res);
			return 1;
		}
		mysql_free_result(res);
	}

	/*
	 * No go? Try group permissions instead.
	 */
        res = mydb_query("SELECT allow_write FROM group_membership AS g"
			 " LEFT JOIN image_permissions AS ip ON"
			 "   ip.permission_type='group'"
			 "   AND ip.permission_idx=g.gid_idx"
			 " WHERE ip.imageid=%d"
			 " AND g.uid_idx=%d AND g.trust!='none' %s",
			 1, imageidx, ei->suidix, clause);
	if (res) {
		if (mysql_num_rows(res) > 0) {
			mysql_free_result(res);
			return 1;
		}
		mysql_free_result(res);
	}

	return 0;
}

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
static void
parse_imageid(char *str, char **pidp, char **namep, char **versp, char **metap)
{
	char *ipid, *iname, *ivers, *imeta;

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

static char *
build_imageid(char *ipid, char *iname, char *ivers, char *imeta)
{
	char *iid;
	int len;

	len = strlen(ipid) + strlen(iname) + 2;
	if (ivers)
		len += strlen(ivers) + 1;
	if (imeta)
		len += strlen(imeta) + 1;
	iid = mymalloc(len);
	strcpy(iid, ipid);
	len = strlen(ipid);
	iid[len++] = IID_SEP_NAME;
	strcpy(&iid[len], iname);
	len += strlen(iname);
	if (ivers) {
		iid[len++] = IID_SEP_VERS;
		strcpy(&iid[len], ivers);
		len += strlen(ivers);
	}
	if (imeta) {
		iid[len++] = IID_SEP_META;
		strcpy(&iid[len], imeta);
		len += strlen(imeta);
	}

	return iid;
}

/*
 * Find all images (imageid==NULL) or a specific image (imageid!=NULL)
 * that a particular node can access for GET/PUT.  At any time, a node is
 * associated with a specific project and group.  These determine the
 * ability to GET/PUT an image.  For the all image case, the list of
 * accessible images will include:
 *
 * - all "global" images (GET only)
 * - all "shared" images in the project and any group (GET only)
 * - all images in the project and group of the node (GET and PUT)
 *
 * We later added a more fine-grained mechanism for accessing "real"
 * (imageid[0]!='/') images. If the standard checks fail, we look for
 * specific images in the image_permissions table which allows per-group
 * and per-user access at individual image granularity. Right now we are
 * only checking this table if called for a specific image (imageid!=NULL).
 *
 * For a single image this will either return a single image or no image.
 * The desired image must be one of the images that would be returned in
 * the all images case.
 *
 * Imageids are constructed from "pid/imageid" which is the minimal unique
 * identifier (i.e., image name are a per-project namespace and not a
 * per-project, per-group namespace).
 *
 * Return zero on success, non-zero otherwise.
 *
 * Notes on validating paths:
 *
 *    For a GET of a DB-registered image (imageid in "pid/imageid" format),
 *    we just return the path recorded in the DB without any validation.
 *    That path can point anywhere and the file does not have to exist.
 *
 *    For a GET of a file (imageid starts with '/'), we canonicalize
 *    (via realpath) the user-provided path and ensure that the portion
 *    of the path that exists falls within one of the allowed directories.
 *    Note that this is still susceptible to time-of-check-to-time-of-use
 *    attacks by using symlinks, but the actual frisbeed that feeds the
 *    image will run as the user.
 */
static int
emulab_get_host_authinfo(struct in_addr *req, struct in_addr *host,
			 char *imageid,
			 struct config_host_authinfo **getp,
			 struct config_host_authinfo **putp)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	char		*node, *proxy = NULL, *role = NULL;
	int		i, j, nrows;
	char		*wantpid = NULL, *wantname = NULL, *wantvers = NULL;
	char		*wantmeta = NULL;
	struct config_host_authinfo *get = NULL, *put = NULL;
	struct emulab_ha_extra_info *ei = NULL;
	int		imageidx = 0, ngids, igids[2];
	int		issubbossquery = 0;

	if (getp == NULL && putp == NULL)
		return 0;

	if (getp) {
		get = mymalloc(sizeof *get);
		memset(get, 0, sizeof *get);
	}
	if (putp) {
		put = mymalloc(sizeof *put);
		memset(put, 0, sizeof(*put));
	}

	/*
	 * If the requester is not the same as the host, then it is a proxy
	 * request.  In Emulab, the only proxy scenarios we support are
	 * elabinelab inner bosses, subbosses and shared vnode hosts.
	 * So we first ensure that the requester is listed as one of those.
	 */
	if (req->s_addr != host->s_addr) {
#ifdef USE_LOCALHOST_PROXY
		/*
		 * XXX if node_id is localhost (i.e., boss), then allow
		 * proxying for any node.
		 */
		if (req->s_addr == htonl(INADDR_LOOPBACK)) {
			role = mystrdup("boss");
			proxy = mystrdup(role);
			goto isboss;
		}
#endif
		proxy = emulab_nodeid(req);
		if (proxy == NULL) {
			if (debug)
				FrisInfo("authfail: node %s not found",
					 inet_ntoa(*req));
			emulab_free_host_authinfo(get);
			emulab_free_host_authinfo(put);
			return 1;
		}

		/* Check the role of the node */
		role = emulab_noderole(proxy);
		if (role == NULL) {
			if (debug)
				FrisInfo("authfail: node '%s' has no role", proxy);
			free(proxy);
			emulab_free_host_authinfo(get);
			emulab_free_host_authinfo(put);
			return 1;
		}

		/* XXX ops appears as a regular node */
		if (strcmp(role, "node") == 0 && strcmp(proxy, "ops") == 0)
			role = mystrdup("opsnode");

		/* Must be ops, inner boss, subboss or virtnode host to proxy */
		if (strcmp(role, "opsnode") &&
		    strcmp(role, "innerboss") &&
		    strcmp(role, "subboss") && 
		    strcmp(role, "sharedhost") &&
		    strcmp(role, "virthost")) {
			if (debug)
				FrisInfo("authfail: node '%s' role '%s' not a proxy",
					 proxy, role);
			free(proxy);
			free(role);
			emulab_free_host_authinfo(get);
			emulab_free_host_authinfo(put);
			return 1;
		}
	} else if (get != NULL && imageid != NULL && imageid[0] != '/') {
		/*
		 * Another special case:
		 * If the requesting node is a subboss, requesting
		 * info on a specific image on its own behalf, we tell
		 * it whether the image exists (error=0) or not (error=3).
		 * This is for the subboss cache cleaner so it can get
		 * rid of cached copies of images that no longer exist.
		 */
		node = emulab_nodeid(host);
		if (node) {
			role = emulab_noderole(node);
			if (role) {
				if (strcmp(role, "subboss") == 0)
					issubbossquery = 1;
				free(role);
				role = NULL;
			}
		}
		goto gotnode;
	}

#ifdef USE_LOCALHOST_PROXY
 isboss:
#endif
	/*
	 * Find the node name from its control net IP.
	 * If the node doesn't exist, we return an empty list.
	 */
	node = emulab_nodeid(host);
 gotnode:
	if (node == NULL) {
		if (proxy) free(proxy);
		if (role) free(role);
		if (getp) *getp = get;
		if (putp) *putp = put;
		return 0;
	}
	if (get != NULL)
		get->hostid = mystrdup(node);
	if (put != NULL)
		put->hostid = mystrdup(node);

	/*
	 * We have a proxy node.  It should be one of:
	 * - boss (for any node)
	 * - a subboss (that is a frisbee subboss for the node or node host)
	 * - an inner-boss (in the same experiment as the node)
	 * - a sharedhost (that is hosting the node)
	 * Note that we could not do this check until we had the node name.
	 * Note also that we no longer care about proxy or not after this.
	 */
	if (proxy) {
		assert(role != NULL);
#ifdef USE_LOCALHOST_PROXY
		if (strcmp(role, "boss") == 0) {
			res = NULL;
		} else
#endif
		if (strcmp(role, "opsnode") == 0) {
			res = NULL;
		} else if (strcmp(role, "subboss") == 0) {
			res = mydb_query("SELECT s.node_id"
					 " FROM subbosses as s,"
					 "  nodes as n"
					 " WHERE s.subboss_id='%s'"
					 "  AND s.service='frisbee'"
					 "  AND s.disabled=0"
					 "  AND n.node_id='%s'"
					 "  AND s.node_id=n.phys_nodeid",
					 1, proxy, node);
			assert(res != NULL);
		} else if (strcmp(role, "innerboss") == 0) {
			res = mydb_query("SELECT r1.node_id"
					 " FROM reserved as r1,"
					 "  reserved as r2"
					 " WHERE r1.node_id='%s'"
					 "  AND r2.node_id='%s'"
					 "  AND r1.pid=r2.pid"
					 "  AND r1.eid=r2.eid",
					 1, proxy, node);
			assert(res != NULL);
		} else if (strcmp(role, "sharedhost") == 0 ||
			   strcmp(role, "virthost") == 0) {
			res = mydb_query("SELECT node_id"
					 " FROM nodes"
					 " WHERE phys_nodeid='%s'"
					 "  AND node_id='%s'",
					 1, proxy, node);
			assert(res != NULL);
		} else {
			/* XXX just make it fail */
			res = NULL;
			assert(res != NULL);
		}
		if (res) {
			if (mysql_num_rows(res) == 0) {
				mysql_free_result(res);
				if (debug)
					FrisInfo("authfail: '%s' not a proxy for '%s'",
						 proxy, node);
				free(role);
				free(proxy);
				free(node);
				emulab_free_host_authinfo(get);
				emulab_free_host_authinfo(put);
				return 1;
			}
			mysql_free_result(res);
		}
		free(role);
		free(proxy);
	}

	/*
	 * Find the pid/gid to which the node is currently assigned
	 * and also the unix uid of the swapper of the experiment and
	 * their gids in case we need to run a server process.
	 */
	res = mydb_query("SELECT e.pid,e.gid,r.eid,u.uid,u.unix_uid,"
			 "       e.pid_idx,e.gid_idx,e.idx,u.uid_idx"
			 " FROM reserved AS r,experiments AS e,users AS u"
			 " WHERE r.pid=e.pid AND r.eid=e.eid"
			 "  AND e.swapper_idx=u.uid_idx"
			 "  AND r.node_id='%s'", 9, node);
	assert(res != NULL);

	/* Node is free */
	if (mysql_num_rows(res) == 0) {
		mysql_free_result(res);
		free(node);
		if (getp) *getp = get;
		if (putp) *putp = put;
		return 0;
	}

	row = mysql_fetch_row(res);
	if (!row[0] || !row[1] || !row[2] || !row[3] || !row[4] ||
	    !row[5] || !row[6] || !row[7] || !row[8]) {
		mysql_free_result(res);
		FrisInfo("authfail: null pid/gid/eid/uname/uid for node '%s'!",
			 node);
		emulab_free_host_authinfo(get);
		emulab_free_host_authinfo(put);
		free(node);
		return 1;
	}

	if (get != NULL) {
		ei = mymalloc(sizeof *ei);
		ei->pid = mystrdup(row[0]);
		ei->gid = mystrdup(row[1]);
		ei->eid = mystrdup(row[2]);
		ei->sname = mystrdup(row[3]);
		ei->suid = atoi(row[4]);
		ei->pidix = atoi(row[5]);
		ei->gidix = atoi(row[6]);
		ei->eidix = atoi(row[7]);
		ei->suidix = atoi(row[8]);
		ei->ngids = 0;
		get->extra = ei;
	}
	if (put != NULL) {
		ei = mymalloc(sizeof *ei);
		ei->pid = mystrdup(row[0]);
		ei->gid = mystrdup(row[1]);
		ei->eid = mystrdup(row[2]);
		ei->sname = mystrdup(row[3]);
		ei->suid = atoi(row[4]);
		ei->pidix = atoi(row[5]);
		ei->gidix = atoi(row[6]);
		ei->eidix = atoi(row[7]);
		ei->suidix = atoi(row[8]);
		ei->ngids = 0;
		put->extra = ei;
	}
	mysql_free_result(res);

	/*
	 * Get all unix groups the swapper is a member of.
	 * XXX this does not include the extra non-Emulab managed groups
	 *     from unixgroup_membership.
	 */
	res = mydb_query("SELECT g.unix_gid"
			 " FROM groups AS g,group_membership AS gm"
			 " WHERE g.gid_idx=gm.gid_idx AND gm.uid='%s'",
			 1, ei->sname);
	assert(res != NULL);

	nrows = mysql_num_rows(res);
	if (nrows > MAXGIDS) {
		FrisWarning("User '%s' in more than %d groups, truncating list",
			    ei->sname, MAXGIDS);
		nrows = MAXGIDS;
	}
	for (i = 0; i < nrows; i++) {
		row = mysql_fetch_row(res);
		if (get != NULL) {
			ei = (struct emulab_ha_extra_info *)get->extra;
			ei->sgids[i] = atoi(row[0]);
			ei->ngids++;
		}
		if (put != NULL) {
			ei = (struct emulab_ha_extra_info *)put->extra;
			ei->sgids[i] = atoi(row[0]);
			ei->ngids++;
		}
	}
	mysql_free_result(res);

	/*
	 * If imageid is specified and starts with a '/', it is a path.
	 * In this case we compare that path to those accessible by
	 * the experiment swapper and pid/gid/eid.
	 */
	if (imageid && imageid[0] == '/') {
		allow_stddirs(imageid, get, put);
		goto done;
	}

	/*
	 * If we are interested in a specific image, extract the
	 * pid and imagename from the ID.
	 */
	if (imageid != NULL) {
		parse_imageid(imageid,
			      &wantpid, &wantname, &wantvers, &wantmeta);
		imageidx = emulab_imageid(wantpid, wantname);
		if (imageidx == 0) {
			if (debug)
				FrisInfo("authfail: no such image '%s'", imageid);
			goto done;
		}
	}

	if (put != NULL) {
		struct emulab_ha_extra_info *ei = put->extra;

		if (imageid != NULL) {
			/* Interested in a specific image */
			if (can_access(imageidx, ei, 1)) {
				if (wantvers) {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version,"
						"v.uploader_path"
						" FROM images as i "
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version='%s' "
						"WHERE i.pid='%s'"
						" AND i.imagename='%s'",
						7, wantvers, wantpid, wantname);
				}
				else {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version,"
						"v.uploader_path"
						" FROM images as i "
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version=i.version "
						"WHERE i.pid='%s'"
						" AND i.imagename='%s'",
						7, wantpid, wantname);
				}
			} else {
				/*
				 * Pid of expt must be same as pid of image
				 * and gid the same or image "shared".
				 */
				if (wantvers) {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version,"
						"v.uploader_path"
						" FROM images as i"
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version='%s' "
						" WHERE i.pid='%s' "
						" AND i.imagename='%s' "
						" AND i.pid='%s'"
						" AND (i.gid='%s' OR"
						"    (i.gid=i.pid AND "
						"     v.shared=1))",
						7, wantvers, wantpid, wantname,
						ei->pid, ei->gid);
				}
				else {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version,"
						"v.uploader_path"
						" FROM images as i"
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version=i.version "
						" WHERE i.pid='%s' "
						" AND i.imagename='%s'"
						" AND i.pid='%s'"
						" AND (i.gid='%s' OR"
						"    (i.gid=i.pid AND "
						"     v.shared=1))",
						7, wantpid, wantname,
						ei->pid, ei->gid);
				}
			}
		} else {
			/* Find all images that this pid/gid can PUT */
			res = mydb_query("SELECT i.pid,i.gid,i.imagename,"
					 "v.path,i.imageid,v.version,NULL"
					 " FROM images as i"
					 " LEFT JOIN image_versions as v on "
					 "    v.imageid=i.imageid and "
					 "    v.version=i.version "
					 " WHERE i.pid='%s'"
					 " AND (i.gid='%s' OR"
					 "     (i.gid=i.pid AND v.shared=1))"
					 " ORDER BY i.pid,i.gid,i.imagename",
					 7, ei->pid, ei->gid);
		}
		assert(res != NULL);

		/* Construct the list of "pid/imagename" imageids */
		nrows = mysql_num_rows(res);
		if (nrows)
			put->imageinfo =
				mymalloc(nrows *
					 sizeof(struct config_imageinfo));
		else if (debug)
			FrisInfo("authfail: PUT access to '%s' denied to '%s/%s'",
				 imageid, ei->pid, ei->eid);
		put->numimages = 0;
		for (i = 0; i < nrows; i++) {
			struct emulab_ii_extra_info *ii;
			struct config_imageinfo *ci;
			struct stat sb;
			char *iid, *targetpath;
			int iidx, hasuploadpath = 0;

			row = mysql_fetch_row(res);
			/* XXX ignore rows with null or empty info */
			/* XXX row[6] (uploader_path) can be NULL */
			if (!row[0] || !row[0][0] ||
			    !row[1] || !row[1][0] ||
			    !row[2] || !row[2][0] ||
			    !row[3] || !row[3][0] ||
			    !row[4] || !row[4][0] ||
			    !row[5] || !row[5][0])
				continue;

			/*
			 * If an uploader_path was specified, use that.
			 * Otherwise use the path.
			 */
			if (row[6] && row[6][0]) {
				targetpath = row[6];
				hasuploadpath = 1;
			} else
				targetpath = row[3];

			/*
			 * XXX if image is in the standard image directory,
			 * disallow PUTs.
			 *
			 * We would like to allow PUTs to the standard image
			 * directory, but I am not sure how to authenticate
			 * them. Checking that the swapper of the experiment
			 * (that the node is in) is an admin or otherwise
			 * "special" won't work because nodes get put into
			 * hwdown and other special experiments possibly
			 * without revoking the access of the previous user.
			 */
			if (isindir(STDIMAGEDIR, targetpath)) {
				FrisError("%s: cannot update image using "
					  "path '%s'", targetpath);
				continue;
			}

			/*
			 * XXX for the AMD case, we have to strip the AMD
			 * prefix from the path. This is to ensure that
			 * stats and other accesses of the path go through
			 * the AMD mountpoint (e.g., "/proj/foo") and not the
			 * NFS mountpoint (e.g., "/.amd_mnt/ops/proj/foo"),
			 * and thus trigger AMD to do the NFS mount when the
			 * FS is not already mounted.
			 */
			if (AMDROOT) {
				int arlen = strlen(AMDROOT);
				if (strncmp(AMDROOT, targetpath, arlen) == 0) {
					targetpath += arlen;
					assert(targetpath[0] == '/');
				}
			}

			iid = build_imageid(row[0], row[2], row[5], wantmeta);
			ci = &put->imageinfo[put->numimages];
			ci->imageid = iid;
			ci->dir = NULL;
			if (wantmeta && strcmp(wantmeta, "sig") == 0) {
				ci->path = mymalloc(strlen(targetpath) + 4);
				strcpy(ci->path, targetpath);
				strcat(ci->path, ".sig");
				ci->flags = CONFIG_PATH_ISSIGFILE;
			} else {
				ci->path = mystrdup(targetpath);
				ci->flags = CONFIG_PATH_ISFILE;
			}
			if (stat(ci->path, &sb) == 0) {
				ci->flags |= CONFIG_PATH_EXISTS;
				ci->sig = mymalloc(sizeof(time_t));
				*(time_t *)ci->sig = sb.st_mtime;
				ci->flags |= CONFIG_SIG_ISMTIME;
			} else
				ci->sig = NULL;
			ci->uid = ei->suid;
			iidx = atoi(row[4]);

			/*
			 * Find the unix gids to use for any server process.
			 * This includes the gid of the image's project and
			 * any subgroup gid if the image is associated with
			 * one. If for any reason we don't come up with
			 * these gids, we use the gids for the swapper of
			 * the experiment.
			 */
			ngids = emulab_imagegids(iidx, igids);
			if (ngids > 0) {
				for (j = 0; j < ngids; j++)
					ci->gids[j] = igids[j];
				ci->ngids = ngids;
			} else {
				for (j = 0; j < ei->ngids; j++)
					ci->gids[j] = ei->sgids[j];
				ci->ngids = ei->ngids;
			}

			set_put_values(put, put->numimages);

			/*
			 * XXX if we have an explict uploader path we are
			 * under control of image_create and don't need to
			 * worry about backups.
			 */
			if (hasuploadpath && ci->put_oldversion) {
				free(ci->put_oldversion);
				ci->put_oldversion = NULL;
			}
			ii = mymalloc(sizeof *ii);
			ii->DB_imageid = iidx;
			ci->extra = ii;
			put->numimages++;
		}
		mysql_free_result(res);
	}

	if (get != NULL) {
		struct emulab_ha_extra_info *ei = get->extra;

		/* Interested in a specific image */
		if (imageid != NULL) {
			/*
			 * If this is a non-proxy subboss query for a
			 * specific image, return info if the image exists.
			 * This allows the subboss cache flusher to find out
			 * if a cached image is valid or not.
			 *
			 * XXX this means that a subboss could load any
			 * image; we can live with that.
			 */
			if (issubbossquery || can_access(imageidx, ei, 0)) {
				if (wantvers) {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version"
						" FROM images as i "
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version='%s' "
						"WHERE i.pid='%s'"
						" AND i.imagename='%s' and "
						"     v.ready=1",
						6, wantvers, wantpid, wantname);
				}
				else {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version"
						" FROM images as i "
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version=i.version "
						"WHERE i.pid='%s'"
						" AND i.imagename='%s'",
						6, wantpid, wantname);
				}
			} else {
				if (wantvers) {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version"
						" FROM images as i"
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version='%s' "
						" WHERE i.pid='%s' "
						" AND i.imagename='%s' "
						" AND v.ready=1 " 
						" AND (v.global=1"
						"     OR (i.pid='%s'"
						"        AND (i.gid='%s'"
						"            OR v.shared=1)))"
						" ORDER BY pid,gid,imagename",
						6, wantvers, wantpid, wantname,
						ei->pid, ei->gid);
				}
				else {
					res = mydb_query("SELECT i.pid,i.gid,"
						"i.imagename,v.path,"
						"i.imageid,v.version"
						" FROM images as i"
						" LEFT JOIN image_versions "
						"  as v on "
						"    v.imageid=i.imageid and "
						"    v.version=i.version "
						" WHERE i.pid='%s' "
						" AND i.imagename='%s'"
						" AND (v.global=1"
						"     OR (i.pid='%s'"
						"        AND (i.gid='%s'"
						"            OR v.shared=1)))"
						" ORDER BY pid,gid,imagename",
						6, wantpid, wantname,
						ei->pid, ei->gid);
				}
			}
		} else {
			/* Find all images that this pid/gid can GET */
			res = mydb_query("SELECT i.pid,i.gid,i.imagename,"
					 "v.path,i.imageid,v.version"
					 " FROM images as i"
					 " LEFT JOIN image_versions as v on "
					 "    v.imageid=i.imageid and "
					 "    v.version=i.version "
					 " WHERE"
					 "  (v.global=1"
					 "  OR (i.pid='%s'"
					 "     AND (i.gid='%s' OR v.shared=1)))"
					 " ORDER BY i.pid,i.gid,i.imagename",
					 6, ei->pid, ei->gid);
		}
		assert(res != NULL);

		/* Construct the list of "pid/imagename" imageids */
		nrows = mysql_num_rows(res);
		if (nrows)
			get->imageinfo =
				mymalloc(nrows *
					 sizeof(struct config_imageinfo));
		else if (debug)
			FrisInfo("authfail: GET access to '%s' denied to '%s/%s'",
				 imageid, ei->pid, ei->eid);
		get->numimages = 0;
		for (i = 0; i < nrows; i++) {
			struct emulab_ii_extra_info *ii;
			struct config_imageinfo *ci;
			struct stat sb;
			char *iid, *path, *dpath;
			int iidx, wantsig;

			row = mysql_fetch_row(res);
			/* XXX ignore rows with null or empty info */
			if (!row[0] || !row[0][0] ||
			    !row[1] || !row[1][0] ||
			    !row[2] || !row[2][0] ||
			    !row[3] || !row[3][0] ||
			    !row[4] || !row[4][0] ||
			    !row[5] || !row[5][0])
				continue;

			wantsig = (wantmeta && strcmp(wantmeta, "sig") == 0);

			iid = build_imageid(row[0], row[2], row[5], wantmeta);
			ci = &get->imageinfo[get->numimages];
			ci->imageid = iid;
			ci->dir = NULL;
			/*
			 * If path is a directory, this is a new format
			 * image world. The directory contains one or both
			 * of a full image and delta (.ndz and .ddz) for
			 * each version of an image. We return the full
			 * image if it exists, the delta image otherwise.
			 * This means that you cannot get the delta image
			 * if the full image exists. If we want to support
			 * that in the future, we can make a new "metadata"
			 * tag (e.g., "delta") like we do for the signature
			 * so that you could request foo,delta to explicitly
			 * get the delta.
			 */
			if (stat(row[3], &sb) == 0 && S_ISDIR(sb.st_mode)) {
				char ch;
				int len = strlen(row[3]);

				ch = row[3][len-1];
				if (ch != '/')
					len++;

				len += strlen(row[2]);	/* <imagename> */
				len += 4;		/* .ndz */
				if (row[5])		/* :<vers> */
					len += strlen(row[5]) + 1;
				len++;			/* \0 */

				/* Return full image if it exists */
				path = mymalloc(len);
				if (row[5] && strcmp(row[5], "0") != 0)
					snprintf(path, len, "%s%s%s.ndz:%s",
						 row[3], (ch=='/') ? "" : "/",
						 row[2], row[5]);
				else
					snprintf(path, len, "%s%s%s.ndz",
						 row[3], (ch=='/') ? "" : "/",
						 row[2]);
				if (stat(path, &sb) == 0)
					goto gotit;

				/* Otherwise return delta if it exists */
				dpath = mymalloc(len);
				if (row[5] && strcmp(row[5], "0") != 0)
					snprintf(dpath, len,
						 "%s%s%s.ddz:%s",
						 row[3],
						 (ch=='/') ? "" : "/",
						 row[2], row[5]);
				else
					snprintf(dpath, len,
						 "%s%s%s.ddz",
						 row[3],
						 (ch=='/') ? "" : "/",
						 row[2]);
				if (stat(dpath, &sb) == 0) {
					free(path);
					path = dpath;
					goto gotit;
				}

				/* Otherwise, return full path */
				free(dpath);
			} else
				path = mystrdup(row[3]);

		gotit:
			if (wantsig) {
				ci->path = mymalloc(strlen(path) + 4);
				strcpy(ci->path, path);
				strcat(ci->path, ".sig");
				ci->flags = CONFIG_PATH_ISSIGFILE;
				free(path);
			} else {
				ci->path = path;
				ci->flags = CONFIG_PATH_ISFILE;
			}
			if (stat(ci->path, &sb) == 0) {
				ci->flags |= CONFIG_PATH_EXISTS;
				ci->sig = mymalloc(sizeof(time_t));
				*(time_t *)ci->sig = sb.st_mtime;
				ci->flags |= CONFIG_SIG_ISMTIME;
			} else
				ci->sig = NULL;
			ci->uid = ei->suid;
			iidx = atoi(row[4]);

			/*
			 * Find the unix gids to use for any server process.
			 * This includes the gid of the image's project and
			 * any subgroup gid if the image is associated with
			 * one. If for any reason we don't come up with
			 * these gids, we use the gids for the swapper of
			 * the experiment.
			 */
			ngids = emulab_imagegids(iidx, igids);
			if (ngids > 0) {
				for (j = 0; j < ngids; j++)
					ci->gids[j] = igids[j];
				ci->ngids = ngids;
			} else {
				for (j = 0; j < ei->ngids; j++)
					ci->gids[j] = ei->sgids[j];
				ci->ngids = ei->ngids;
			}

			set_get_values(get, get->numimages);
			ii = mymalloc(sizeof *ii);
			ii->DB_imageid = iidx;
			ci->extra = ii;
			get->numimages++;
		}
		mysql_free_result(res);
	}

	/*
	 * Finally add on the standard directories that a node can access.
	 */
	if (imageid == NULL)
		allow_stddirs(imageid, get, put);

 done:
	free(node);
	if (wantpid)
		free(wantpid);
	if (wantname)
		free(wantname);
	if (wantvers)
		free(wantvers);
	if (wantmeta)
		free(wantmeta);
	if (getp) *getp = get;
	if (putp) *putp = put;
	return 0;
}

static void
dump_host_authinfo(FILE *fd, char *node, char *cmd,
		   struct config_host_authinfo *ai)
{
	struct emulab_ha_extra_info *ei = ai->extra;
	int i;

	if (strcmp(cmd, "GET") == 0)
		fprintf(fd, "# %s in %s/%s\n", node, ei->pid, ei->eid);
	fprintf(fd, "%s %s ", node, cmd);

	/*
	 * If we have defined image aliases, just dump the appropriate
	 * aliases here for each node.
	 */
	if (dump_doaliases) {
		if (strcmp(cmd, "GET") == 0)
			fprintf(fd, "global-images %s-images %s-%s-images ",
				ei->pid, ei->pid, ei->gid);
		else
			fprintf(fd, "%s-%s-images ", ei->pid, ei->gid);
	}
	/*
	 * Otherwise, dump the whole list of images for each node
	 */
	else {
		for (i = 0; i < ai->numimages; i++)
			if (ai->imageinfo[i].flags == CONFIG_PATH_ISFILE)
				fprintf(fd, "%s ", ai->imageinfo[i].imageid);
	}

	/*
	 * And dump any directories that can be accessed
	 */
	for (i = 0; i < ai->numimages; i++)
		if (ai->imageinfo[i].flags == CONFIG_PATH_ISDIR)
			fprintf(fd, "%s/* ", ai->imageinfo[i].path);

	fprintf(fd, "\n");
}

/*
 * Dump image alias lines for:
 * - global images (global=1)                     => "global-images"
 * - project-wide images (pid=<pid> and shared=1) => "<pid>-images"
 * - per-group images (pid=<pid> and gid=<gid>)   => "<pid>-<gid>-images"
 */
static void
dump_image_aliases(FILE *fd)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		i, nrows;
	char		*lastpid;

	/* First the global image alias */
	res = mydb_query("SELECT i.pid,i.imagename"
			 " FROM images as i"
			 " LEFT JOIN image_versions "
			 "  as v on "
			 "    v.imageid=i.imageid and "
			 "    v.version=i.version "
			 " WHERE v.global=1"
			 " ORDER BY i.pid,i.imagename", 2);
	assert(res != NULL);

	nrows = mysql_num_rows(res);
	if (nrows) {
		fprintf(fd, "imagealias global-images ");
		for (i = 0; i < nrows; i++) {
			row = mysql_fetch_row(res);
			/* XXX ignore rows with null or empty info */
			if (!row[0] || !row[0][0] ||
			    !row[1] || !row[1][0])
				continue;
			fprintf(fd, "%s/%s ", row[0], row[1]);
		}
		fprintf(fd, "\n");
	}
	mysql_free_result(res);

	/* Only create aliases for pid/gids that have imageable nodes now */
	res = mydb_query("SELECT e.pid,e.gid"
			 " FROM nodes AS n,node_types AS t,"
			 "  node_type_attributes AS a,"
			 "  reserved AS r,experiments AS e"
			 " WHERE n.type=t.type AND n.type=a.type"
			 "  AND n.node_id=r.node_id"
			 "  AND r.pid=e.pid AND r.eid=e.eid"
			 "  AND n.role='testnode' AND t.class='pc'"
			 "  AND a.attrkey='imageable' AND a.attrvalue!='0'"
			 " GROUP by e.pid,e.gid", 2);
	assert(res != NULL);

	lastpid = mystrdup("NONE");
	nrows = mysql_num_rows(res);
	for (i = 0; i < nrows; i++) {
		MYSQL_RES	*res2;
		MYSQL_ROW	row2;
		int		i2, nrows2;

		row = mysql_fetch_row(res);
		/* XXX ignore rows with null or empty info */
		if (!row[0] || !row[0][0] ||
		    !row[1] || !row[1][0])
			continue;

		/* New pid, put out shared project image alias */
		if (strcmp(lastpid, row[0])) {
			free(lastpid);
			lastpid = mystrdup(row[0]);

			res2 = mydb_query("SELECT i.imagename"
					  " FROM images as i"
					  " LEFT JOIN image_versions "
					  "  as v on "
					  "    v.imageid=i.imageid and "
					  "    v.version=i.version "
					  " WHERE i.pid='%s' AND v.shared=1"
					  " ORDER BY i.imagename",
					  1, lastpid);
			assert(res2 != NULL);

			nrows2 = mysql_num_rows(res2);
			if (nrows2) {
				fprintf(fd, "imagealias %s-images ", lastpid);
				for (i2 = 0; i2 < nrows2; i2++) {
					row2 = mysql_fetch_row(res2);
					if (!row2[0] || !row2[0][0])
						continue;
					fprintf(fd, "%s/%s ",
						lastpid, row2[0]);
				}
				fprintf(fd, "\n");
			}
			mysql_free_result(res2);
		}

		/* Put out pid/eid image alias */
		res2 = mydb_query("SELECT imagename"
				  " FROM images"
				  " WHERE pid='%s' AND gid='%s'"
				  " ORDER BY imagename",
				  1, row[0], row[1]);
		assert(res2 != NULL);

		nrows2 = mysql_num_rows(res2);
		if (nrows2) {
			fprintf(fd, "imagealias %s-%s-images ",
				row[0], row[1]);
			for (i2 = 0; i2 < nrows2; i2++) {
				row2 = mysql_fetch_row(res2);
				if (!row2[0] || !row2[0][0])
					continue;
				fprintf(fd, "%s/%s ", lastpid, row2[0]);
			}
			fprintf(fd, "\n");
		}
		mysql_free_result(res2);
	}
	mysql_free_result(res);
	free(lastpid);
}

static char *
emulab_canonicalize_imageid(char *path)
{
	MYSQL_RES *res;
	MYSQL_ROW row;
	char *iid = NULL, *ipath, *dpath, *fname, *cp;
	int len, issig = 0, version;

	/*
	 * The only non-path (imageid) conversion we do right now is
	 * to make sure we have a version number. If no version was specified
	 * it means "the most recent" version and we look that up here.
	 */
	if (path[0] != '/') {
		char *ipid, *iname, *ivers, *imeta;

		parse_imageid(path, &ipid, &iname, &ivers, &imeta);
		assert(ipid != NULL);
		assert(iname != NULL);

		if (debug)
			FrisInfo("canonicalize(%s): pid=%s, name=%s, vers=%s, meta=%s",
				 path, ipid, iname,
				 ivers ? ivers : "", imeta ? imeta : "");
		if (ivers == NULL) {
			res = mydb_query("SELECT i.version FROM "
					 "  images AS i, image_versions AS v "
					 "WHERE i.imageid=v.imageid "
					 "  AND i.version=v.version "
					 "  AND i.pid='%s' "
					 "  AND i.imagename='%s' "
					 "  AND v.deleted IS NULL",
					 1, ipid, iname);
			if (res) {
				if (mysql_num_rows(res)) {
					row = mysql_fetch_row(res);
					if (row[0])
						ivers = mystrdup(row[0]);
				}
				mysql_free_result(res);
			}
		}

		iid = build_imageid(ipid, iname, ivers, imeta);
		free(ipid);
		free(iname);
		if (ivers)
			free(ivers);
		if (imeta)
			free(imeta);

		return iid;
	}

	/*
	 * We have a path to an image (or image signature) file.
	 *
	 * Unfortunately, we cannot just match this to the path column in
	 * the DB, because that path might be a complete path for the image
	 * file or it might be the path to the image directory in which all
	 * versions of the image exist. String parsing in C, oh joy!
	 */
	ipath = mystrdup(path);
	len = strlen(ipath);

	/*
	 * Remember if it is a sigfile, and strip off the .sig.
	 */
	if (len > 4 && strcmp(ipath+len-4, ".sig") == 0) {
		len -= 4;
		ipath[len] = '\0';
		issig = 1;
	}

	/*
	 * First see if this is the uploader_path for some image.
	 */
	if (image_from_upath(ipath, &iid)) {
		free(ipath);
		goto constructid2;
	}

	/*
	 * Next try looking up based on the full path.
	 * Look up the path in image_versions, returning the version number
	 * and a string composed of <pid>/<imagename>:<version>.
	 */
	res = mydb_query("SELECT CONCAT(pid,'%c',imagename,'%c',version) "
			 "FROM image_versions"
			 "  WHERE deleted IS NULL AND path='%s'",
			 1, IID_SEP_NAME, IID_SEP_VERS, ipath);
	if (res != NULL) {
		if (mysql_num_rows(res) > 0) {
			free(ipath);
			goto constructid;
		}
		mysql_free_result(res);
	}

	/*
	 * That didn't work, try looking up by image directory and name. 
	 * Split off the directory part (including the final '/').
	 * Note that we know there is at least one '/' since we start with one.
	 */
	dpath = mystrdup(ipath);
	cp = strrchr(dpath, '/');
	fname = mystrdup(cp + 1);
	cp[1] = '\0';
	free(ipath);

	/*
	 * Image file names in an image directory (IMAGEDIRS) setup look like:
	 * 
	 *    <imagename>.ndz[:<vers>]
	 */
	if (strlen(fname) < 5 || (cp = strstr(fname, ".ndz")) == NULL) {
		if (debug)
			FrisInfo("canonicalize(%s): ill-formed fname '%s'",
				 path, fname);
		free(fname);
		free(dpath);
		return NULL;
	}
	*cp = '\0';
	cp += 4;
	if (cp[0] == '\0')
		version = 0;
	else if (cp[0] == ':')
		version = atoi(cp+1);
	else {
		if (debug)
			FrisInfo("canonicalize(%s): ill-formed version in fname '%s'",
				 path, fname);
		free(fname);
		free(dpath);
		return NULL;
	}

	if (debug)
		FrisInfo("canonicalize(%s): dpath=%s, fname=%s, version=%d",
			 path, dpath, fname, version);

	res = mydb_query("SELECT CONCAT(pid,'%c',imagename,'%c',version) "
			 "FROM image_versions"
			 "  WHERE deleted IS NULL AND path='%s'"
			 "    AND imagename='%s' AND version=%d",
			 1, IID_SEP_NAME, IID_SEP_VERS, dpath, fname, version);
	free(fname);
	free(dpath);
	if (res != NULL) {
		if (mysql_num_rows(res) > 0)
			goto constructid;
		mysql_free_result(res);
	}

	/*
	 * Ah well, it was a good try.
	 */
	return NULL;

	/*
	 * We got a hit in the DB
	 */
 constructid:
	/* XXX if rows > 1, we just return info from the first */
	row = mysql_fetch_row(res);
	if (row[0] == NULL) {
		mysql_free_result(res);
		return NULL;
	}
	iid = mystrdup(row[0]);
	mysql_free_result(res);
 
	/*
	 * Tack on ",sig" to indicate that we want the signature
	 * for the indicated image.
	 */
 constructid2:
	if (issig && iid != NULL) {
		char *niid;
		len = strlen(iid);
		niid = mymalloc(len + 4);
		strcpy(niid, iid);
		niid[len++] = IID_SEP_META;
		strcpy(&niid[len], "sig");
		free(iid);
		iid = niid;
	}

	return iid;
}

static int
emulab_set_upload_status(struct config_imageinfo *ii, int status)
{
	char *imageid;
	char *pid, *name, *vers, *meta;
	int imageidx;
	char msgbuf[256];	/* tinytext size */

	if (ii->imageid == NULL)
		return 1;

	FrisLog("%s: Recording upload status %d", ii->imageid, status);

	imageid = emulab_canonicalize_imageid(ii->imageid);
	if (imageid == NULL) {
		FrisError("%s: set_upload_status: "
			  "could not map to a valid image", ii->imageid);
		return 1;
	}

	parse_imageid(imageid, &pid, &name, &vers, &meta);
	imageidx = emulab_imageid(pid, name);
	if (debug)
		FrisLog("%s: set_upload_status: "
			"pid=%s, name=%s, vers=%s, meta=%s => %d", ii->imageid,
			pid, name, vers ? vers : "", meta ? meta : "",
			imageidx);

	if (imageidx) {
		char *stat;

		switch (status) {
		case UE_NOERROR:
			stat = "";
			break;
		case UE_OTHER:
			stat = "terminated";
			break;
		case UE_TOOLONG:
			stat = "timed-out";
			break;
		case UE_TOOBIG:
			stat = "exceeded max size";
			break;
		case UE_NOSPACE:
			stat = "exceeded quota";
			break;
		case UE_CONNERR:
			stat = "connection error";
			break;
		case UE_FILEERR:
			stat = "image file error";
			break;
		default:
			stat = "unknown error";
			break;
		}
		strncpy(msgbuf, stat, sizeof(msgbuf)-1);

		if (!mydb_update("UPDATE image_versions"
				 "  SET uploader_status='%s'"
				 "  WHERE imageid=%d AND pid='%s'"
				 "    AND imagename='%s' AND version='%s'",
				 msgbuf, imageidx, pid, name, vers)) {
			FrisError("%s: set_upload_status: "
				  "could not update DB status", ii->imageid);
			imageidx = 0;
		}
	} else {
		FrisError("%s: set_upload_status: "
			  "could not map to a current image", ii->imageid);
	}
	free(pid);
	free(name);
	if (vers)
		free(vers);
	if (meta)
		free(meta);
	free(imageid);

	return imageidx ? 0 : 1;
}

static void
emulab_dump(FILE *fd)
{
	MYSQL_RES	*res;
	MYSQL_ROW	row;
	int		i, nrows;

	fprintf(fd, "Emulab master frisbee config:\n");

	if (dump_doaliases)
		dump_image_aliases(fd);

	res = mydb_query("SELECT n.node_id,i.IP"
			 " FROM nodes AS n,node_types AS t,"
			 "  node_type_attributes AS a,interfaces AS i"
			 " WHERE n.type=t.type AND n.type=a.type"
			 "  AND n.node_id=i.node_id AND i.role='ctrl'"
			 "  AND n.role='testnode' AND t.class='pc'"
			 "  AND a.attrkey='imageable' AND a.attrvalue!='0'"
			 " ORDER BY n.priority", 2);
	assert(res != NULL);

	nrows = mysql_num_rows(res);
	for (i = 0; i < nrows; i++) {
		row = mysql_fetch_row(res);
		if (row[0] && row[1]) {
			struct config_host_authinfo *get, *put;
			struct in_addr in;

			inet_aton(row[1], &in);
			if (emulab_get_host_authinfo(&in, &in, NULL,
						     &get, &put)) {
				FrisWarning("Could not get node authinfo for %s",
					    row[0]);
			}
			if (strcmp(get->hostid, row[0])) {
				FrisWarning("node_id mismatch (%s != %s)",
					    get->hostid, row[0]);
			}
			if (get->numimages)
				dump_host_authinfo(fd, row[0], "GET", get);
			emulab_free_host_authinfo(get);
			if (put->numimages)
				dump_host_authinfo(fd, row[0], "PUT", put);
			emulab_free_host_authinfo(put);
		}
	}
	mysql_free_result(res);
}

struct config emulab_config = {
	emulab_deinit,
	emulab_read,
	emulab_get_host_authinfo,
	emulab_free_host_authinfo,
	emulab_get_server_address,
	emulab_canonicalize_imageid,
	emulab_set_upload_status,
	emulab_save,
	emulab_restore,
	emulab_free,
	emulab_dump
};

struct config *
emulab_init(char *opts)
{
	static int called;
	char pathbuf[PATH_MAX], *path;
	int len;

	if (!dbinit())
		return NULL;

	if (called)
		return &emulab_config;
	called++;

	/* One time parsing of MC address info */
	if (sscanf(MC_BASEADDR, "%d.%d.%d", &mc_a, &mc_b, &mc_c) != 3) {
		FrisError("emulab_init: MC_BASEADDR '%s' not in A.B.C format!",
			  MC_BASEADDR);
		return NULL;
	}
	mc_port_lo = atoi(MC_BASEPORT);
	mc_port_num = atoi(MC_NUMPORTS);
	if (mc_port_num < 0 || mc_port_num >= 65536) {
		FrisError("emulab_init: MC_NUMPORTS '%s' not in valid range!",
			  MC_NUMPORTS);
		return NULL;
	}
	if (mc_port_lo > 0) {
		if (mc_port_num == 0)
			mc_port_num = 65536 - mc_port_lo;
		if (mc_port_lo + mc_port_num > 65536) {
			FrisError("emulab_init: MC_BASEPORT (%d) + "
				  "MC_NUMPORTS (%d) too large!",
				  mc_port_lo, mc_port_num);
			return NULL;
		}
	}

	if ((path = myrealpath(SHAREROOT_DIR, pathbuf)) == NULL) {
		FrisError("emulab_init: could not resolve '%s'",
			  SHAREROOT_DIR);
		return NULL;
	}
	SHAREDIR = mystrdup(path);

	if ((path = myrealpath(PROJROOT_DIR, pathbuf)) == NULL) {
		FrisError("emulab_init: could not resolve '%s'",
			  PROJROOT_DIR);
		return NULL;
	}
	PROJDIR = mystrdup(path);

	if ((path = myrealpath(GROUPSROOT_DIR, pathbuf)) == NULL) {
		FrisError("emulab_init: could not resolve '%s'",
			  GROUPSROOT_DIR);
		return NULL;
	}
	GROUPSDIR = mystrdup(path);

	if ((path = myrealpath(USERSROOT_DIR, pathbuf)) == NULL) {
		FrisError("emulab_init: could not resolve '%s'",
			  USERSROOT_DIR);
		return NULL;
	}
	USERSDIR = mystrdup(path);

	if (strlen(SCRATCHROOT_DIR) > 0) {
		if ((path = myrealpath(SCRATCHROOT_DIR, pathbuf)) == NULL) {
			FrisError("emulab_init: could not resolve '%s'",
				  SCRATCHROOT_DIR);
			return NULL;
		}
		SCRATCHDIR = mystrdup(path);
	} else
		SCRATCHDIR = NULL;

	/*
	 * Construct the standard image directory path.
	 * XXX Should we run realpath on this? I don't think so.
	 */
	len = strlen(TBROOT) + strlen("/images") + 1;
	STDIMAGEDIR = mymalloc(len);
	snprintf(STDIMAGEDIR, len, "%s/images", TBROOT);

	return &emulab_config;
}

/*
 * XXX memory allocation functions that either return memory or abort.
 * We shouldn't run out of memory and don't want to check every return values.
 */
static void *
mymalloc(size_t size)
{
	void *ptr = malloc(size);
	if (ptr == NULL) {
		FrisError("config_emulab: out of memory!");
		abort();
	}
	return ptr;
}

static void *
myrealloc(void *ptr, size_t size)
{
	void *nptr = realloc(ptr, size);
	if (nptr == NULL) {
		FrisError("config_emulab: out of memory!");
		abort();
	}
	return nptr;
}

static char *
mystrdup(const char *str)
{
	char *nstr = strdup(str);
	if (nstr == NULL) {
		FrisError("config_emulab: out of memory!");
		abort();
	}
	return nstr;
}

#else
struct config *
emulab_init(void)
{
	return NULL;
}
#endif
