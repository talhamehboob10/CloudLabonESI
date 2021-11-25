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
 * Configuration "file" handling for a "null" or default configuration.
 * Just uses globally configurated info for all images:
 *
 *  - images get/put to a standard image directory
 *  - servers run as same user as master server
 */ 

#ifdef USE_NULL_CONFIG
#include <sys/param.h>
#include <sys/stat.h>
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include "log.h"
#include "configdefs.h"

extern int debug;

static char *DEFAULT_IMAGEDIR	= "/usr/local/images";
static char *DEFAULT_MCADDR	= "239.192.1";
static char *DEFAULT_MCPORT	= "0";
static char *DEFAULT_MCNUMPORT	= "0";

static char *indexfile;
char *imagedir = NULL;
static char *rimagedir;
static uint32_t maxrate = 100000000;
static int dynrate = 0;
static char *eserver = NULL;
static int clientreport = 0;

/*
 * We use a small server inactive timeout since we no longer have
 * to start up a frisbeed well in advance of the client(s).
 *
 * XXX we cranked this from 60 to 180 seconds to account for clients
 * with lots of write buffer memory but slow disks, giving them time
 * to flush all their buffers and report their stats before we give
 * up on them.
 */
static int maxlinger = 180;

/* Multicast address/port base info */
static int mc_a, mc_b, mc_c, mc_port_lo, mc_port_num;

/* Memory alloc functions that abort when no memory */
static void *mymalloc(size_t size);
static void *myrealloc(void *ptr, size_t size);
static char *mystrdup(const char *str);

static void
null_deinit(void)
{
}

static int
null_read(void)
{
	/* "Reading" the config file is a no-op. Just echo settings. */
	FrisLog("  dynamic bandwidth = %s", dynrate ? "true" : "false");
	if (maxrate == 0)
		FrisLog("  max bandwidth = unlimited");
	else
		FrisLog("  max bandwidth = %d Mbit/sec",
			(int)(maxrate/1000000));

	if (clientreport > 0) {
		FrisLog("  clients report progress every %d seconds",
			clientreport);
		if (eserver)
			FrisLog("  progress events sent to %s", eserver);
	}

	if (maxlinger < 0)
		FrisLog("  server exits after last client leaves");
	else if (maxlinger == 0)
		FrisLog("  server never exits");
	else
		FrisLog("  server exits after %d seconds idle",
			maxlinger);

	return 0;
}

static void *
null_save(void)
{
	static int dummy;

	/* Just return non-zero value */
	return (void *)&dummy;
}

static int
null_restore(void *state)
{
	FrisLog("  dynamic bandwidth = %s", dynrate ? "true" : "false");
	if (maxrate == 0)
		FrisLog("  max bandwidth = unlimited");
	else
		FrisLog("  max bandwidth = %d Mbit/sec",
			(int)(maxrate/1000000));

	if (clientreport > 0) {
		FrisLog("  clients report progress every %d seconds",
			clientreport);
		if (eserver)
			FrisLog("  progress events sent to %s", eserver);
	}

	if (maxlinger < 0)
		FrisLog("  server exits after last client leaves");
	else if (maxlinger == 0)
		FrisLog("  server never exits");
	else
		FrisLog("  server exits after %d seconds idle",
			maxlinger);

	return 0;
}

static void
null_free(void *state)
{
}

/*
 * Set the GET methods and options for a particular node/image.
 */
static void
set_get_values(struct config_host_authinfo *ai, int ix)
{
	char str[256];

	/* get_methods */
	ai->imageinfo[ix].get_methods = CONFIG_IMAGE_MCAST;
#if 1
	/*
	 * XXX broadcast is a bad idea on a large shared LAN environment.
	 * But it can be enabled/disabled in the server, so this flag
	 * doesn't hurt.
	 */
	ai->imageinfo[ix].get_methods |= CONFIG_IMAGE_BCAST;
#endif
#if 1
	/*
	 * XXX the current frisbee server allows only a single client
	 * in unicast mode, which makes this option rather limited.
	 * So you may not want to allow it by default.
	 */
	ai->imageinfo[ix].get_methods |= CONFIG_IMAGE_UCAST;
#endif

	/* get_timeout */
	ai->imageinfo[ix].get_timeout = maxlinger;

	/*
	 * get_options:
	 *  - maxrate of zero means unlimited.
	 *  - for dynamic rate adjustment, we use the std/usr
	 *    bandwidth value as the maximum bandwidth.
	 */
	if (maxrate)
		snprintf(str, sizeof str, " -W %u", maxrate);
	else
		snprintf(str, sizeof str, " -G 0");
	if (dynrate)
		strcat(str, " -D");
	strcat(str, " -K 15");
	if (clientreport > 0) {
		int len = strlen(str);
		snprintf(&str[len], sizeof(str) - len, " -H %d",
			 clientreport);
		if (eserver) {
			len = strlen(str);
			snprintf(&str[len], sizeof(str) - len, " -E %s",
				 eserver);
		}
	}
	ai->imageinfo[ix].get_options = mystrdup(str);

	/* and whack the put_* fields */
	ai->imageinfo[ix].put_maxsize = 0;
	ai->imageinfo[ix].put_timeout = 0;
	ai->imageinfo[ix].put_itimeout = 0;
	ai->imageinfo[ix].put_oldversion = NULL;
	ai->imageinfo[ix].put_options = NULL;

	/*
	 * parent GET options:
	 *  - if we are making client reports, make sure that our downloads
	 *    from a parent enable those.
	 *    XXX right now, the server always dictates the interval.
	 */
	if (clientreport > 0) {
		snprintf(str, sizeof str, " -H 0");
		ai->imageinfo[ix].pget_options = mystrdup(str);
	} else
		ai->imageinfo[ix].pget_options = NULL;
}

/*
 * Set the PUT maxsize/options for a particular node/image.
 * XXX right now these are completely pulled out of our posterior.
 */
static void
set_put_values(struct config_host_authinfo *ai, int ix)
{
	struct config_imageinfo *ii = &ai->imageinfo[ix];
	int len;

	/* put_maxsize */
	ii->put_maxsize = 20000000000ULL;	/* XXX 20GB */

	/* put_timeout */
	ii->put_timeout = 1200;
	ii->put_itimeout = 120;

	/* put_oldversion -- setting to NULL means no tmpfile during upload */
	len = strlen(ii->path) + 5;
	ii->put_oldversion = mymalloc(len);
	snprintf(ii->put_oldversion, len, "%s.bak", ii->path);

	/* put_options */
	ii->put_options = NULL;

	/* and whack the get_* fields */
	ii->get_methods = 0;
	ii->get_timeout = 0;
	ii->get_options = NULL;

	/* and pget fields */
	ii->pget_options = NULL;
}

#define FREE(p) { if (p) free(p); }

/*
 * Free the dynamically allocated host_authinfo struct.
 */
static void
null_free_host_authinfo(struct config_host_authinfo *ai)
{
	int i;

	if (ai == NULL)
		return;

	FREE(ai->hostid);
	if (ai->imageinfo != NULL) {
		for (i = 0; i < ai->numimages; i++) {
			FREE(ai->imageinfo[i].imageid);
			FREE(ai->imageinfo[i].path);
			FREE(ai->imageinfo[i].sig);
			FREE(ai->imageinfo[i].get_options);
			FREE(ai->imageinfo[i].put_oldversion);
			FREE(ai->imageinfo[i].put_options);
			FREE(ai->imageinfo[i].pget_options);
			FREE(ai->imageinfo[i].extra);
		}
		free(ai->imageinfo);
	}
	assert(ai->extra == NULL);
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
null_get_server_address(struct config_imageinfo *ii, int methods, int first,
			in_addr_t *addrp, in_port_t *loportp,
			in_port_t *hiportp, int *methp)
{
	int	a, b, c, d, idx;
	int	incr = 1;
	FILE	*fd;

 again:
	if ((fd = fopen(indexfile, "r+")) == NULL) {
		FrisError("get_server_address: could not open index file '%s'!",
			  indexfile);
		return 1;
	}
	if (fscanf(fd, "%d", &idx) != 1 || idx < 0) {
		FrisError("get_server_address: bogus index in '%s'!",
			  indexfile);
		fclose(fd);
		return 1;
	}

	/*
	 * Make this work like mysql LAST_INSERT_ID();
	 * i.e., the persistent value is the one we just used.
	 */
	idx += incr;

	if (fseek(fd, 0L, SEEK_SET) != 0 || fprintf(fd, "%d\n", idx) < 0) {
		FrisError("get_server_address: cannot update index in '%s'!",
			  indexfile);
		fclose(fd);
		return 1;
	}
	fclose(fd);

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
		FrisError("get_server_address: ran out of MC addresses!");
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
			incr = 254;
			goto again;
		}

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
		fprintf(stderr,
			"get_server_address: idx %d, addr 0x%x, port [%d-%d]\n",
			idx, *addrp, *loportp, *hiportp);

	return 0;
}

/*
 * Just return imagedir for GET and PUT.
 */
static void
allow_stddirs(char *imageid, 
	      struct config_host_authinfo *get,
	      struct config_host_authinfo *put)
{
	struct config_imageinfo *ci;
	struct stat sb;

	if (get == NULL && put == NULL)
		return;

	/*
	 * No image specified, just return info about the directories
	 * that are accessible.
	 */
	if (imageid == NULL) {
		int ni, i;
		size_t ns;
		char *dirs[8];

		/*
		 * Right now, allow PUT to imagedir.
		 */
		if (put != NULL) {
			dirs[0] = imagedir;
			ni = put->numimages + 1;
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
				ci->uid = NOUID;
				ci->ngids = 0;
				set_put_values(put, i);
				ci->extra = NULL;
			}
			put->numimages = ni;
		}
		/*
		 * and GETs as well.
		 */
		if (get != NULL) {
			dirs[0] = imagedir;
			ni = get->numimages + 1;
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
				ci->uid = NOUID;
				ci->ngids = 0;
				set_get_values(get, i);
				ci->extra = NULL;
			}
			get->numimages = ni;
		}
		goto done;
	}

	/*
	 * Image was specified; find the real path for the targetted file.
	 * Don't want users symlinking to files outside their allowed space.
	 */
	assert(imageid == NULL);

 done:
	return;
}

/*
 * Find all images (imageid==NULL) or a specific image (imageid!=NULL)
 * that a particular node can access for GET/PUT.  Pretty simple default:
 * any node can read/write any image within the default image directory.
 *
 * For a single image this will either return a single image or no image.
 * The desired image must be one of the images that would be returned in
 * the all images case.
 *
 * Imageids should be a path to which we prepend the imagedir if it is
 * not already there.
 *
 * Return zero on success, non-zero otherwise.
 */
static int
null_get_host_authinfo(struct in_addr *req, struct in_addr *host,
		       char *imageid,
		       struct config_host_authinfo **getp,
		       struct config_host_authinfo **putp)
{
	struct config_host_authinfo *get = NULL, *put = NULL;
	struct config_imageinfo *ci;
	struct stat sb;
	int exists;
	char *path = NULL;

/* XXX don't worry about this right now; breaks virthosts under subboss */
#if 0
	/*
	 * If the requester is not the same as the host, then it is a proxy
	 * request.  We don't do proxying.
	 */
	if (req->s_addr != host->s_addr)
		return 1;
#endif

	/*
	 * If an imageid is specified, convert it into a plausible path.
	 */
	if (imageid != NULL) {
		char rpath[PATH_MAX], *cp;
		int idlen;

		/*
		 * We seriously limit what chars can be in an imageid since we
		 * use it as a file name. This check is based on the Emulab
		 * regex for image paths: "^[-_\w\.\/:+]+$". We need ',' as
		 * well to allow download of image signatures.
		 */
		idlen = strlen(imageid);
		if (idlen == 0 || idlen >= PATH_MAX) {
			if (debug)
				fprintf(stderr, "imageid too short/long\n");
			return 1;
		}
		for (cp = imageid; *cp != '\0'; cp++) {
			if (isalnum(*cp) || *cp == '-' || *cp == '_' ||
			    *cp == '.' || *cp == '/' || *cp == ':' ||
			    *cp == '+' || *cp == ',')
				continue;
			if (debug)
				fprintf(stderr,
					"bogus char (0x%x) in imageid\n", *cp);
			return 1;
		}

		/*
		 * If imageid is specified and starts with a '/', it is an
		 * absolute path.  We prepend imagedir if it doesn't already
		 * start with that. If it doesn't start with a '/' we prepend
		 * imagedir. Either way the result is an absolute path rooted
		 * at imagedir.
		 */
		assert(imagedir && imagedir[0]);
		if (imageid[0] != '/' ||
		    strstr(imageid, imagedir) != imageid) {
			path = mymalloc(strlen(imagedir) + idlen + 2);
			strcpy(path, imagedir);
			if (imageid[0] != '/')
				strcat(path, "/");
			strcat(path, imageid);
		} else
			path = mystrdup(imageid);
		if (debug)
			fprintf(stderr, "imageid %s: mapped to path '%s'\n",
				imageid, path);

		/*
		 * Run the result through realpath to insure it is still in
		 * imagedir.
		 *
		 * At this point we cannot do a full path check since the
		 * full path need not exist and we are possibly running with
		 * enhanced privilege. So we only weed out obviously bogus
		 * paths here (possibly checking just the partial path
		 * returned by realpath) and mark the imageinfo as needed a
		 * full resolution later.
		 */
		if (myrealpath(path, rpath) == NULL) {
			if (errno != ENOENT) {
				free(path);
				return 1;
			}
			exists = 0;
		} else
			exists = 1;
		if (!isindir(rimagedir, rpath)) {
			free(path);
			return 1;
		}
		if (exists && stat(path, &sb) < 0)
			exists = 0;
	}

	if (getp == NULL && putp == NULL) {
		if (path)
			free(path);
		return 0;
	}

	if (getp) {
		get = mymalloc(sizeof *get);
		memset(get, 0, sizeof *get);
	}
	if (putp) {
		put = mymalloc(sizeof *put);
		memset(put, 0, sizeof(*put));
	}

	/*
	 * XXX we don't care about the node identity right now.
	 * we should at least restrict it to the local subnet.
	 */
	if (get != NULL)
		get->hostid = mystrdup(inet_ntoa(*host));
	if (put != NULL)
		put->hostid = mystrdup(inet_ntoa(*host));

	/*
	 * If no image specified, just return the standard directories.
	 * We could also return the list of images that already exist...
	 * someday.
	 */
	if (imageid == NULL) {
		allow_stddirs(imageid, get, put);
		goto done;
	}

	/*
	 * Need to make sure path really exists.
	 *
	 * imageidtopath will return success even when the final component
	 * does not exist.  That is alright for a put, but not a get.
	 * What do we return for flags on a PUT?  What about sig?
	 */
	if (stat(path, &sb) < 0)
		exists = 0;
	else
		exists = 1;

	/*
	 * Otherwise, return this image
	 */
	if (put != NULL) {
		put->imageinfo = mymalloc(sizeof(struct config_imageinfo));
		put->numimages = 1;
		ci = &put->imageinfo[0];
		ci->imageid = mystrdup(imageid);
		ci->dir = mystrdup(rimagedir);
		ci->path = mystrdup(path);
		ci->flags = CONFIG_PATH_ISFILE|CONFIG_PATH_RESOLVE;
		if (exists) {
			ci->flags |= CONFIG_PATH_EXISTS;
			ci->sig = mymalloc(sizeof(time_t));
			*(time_t *)ci->sig = sb.st_mtime;
			ci->flags |= CONFIG_SIG_ISMTIME;
		} else
			ci->sig = NULL;
		ci->uid = NOUID;
		ci->ngids = 0;
		set_put_values(put, 0);
		ci->extra = NULL;
	}

	if (get != NULL) {
		get->imageinfo = mymalloc(sizeof(struct config_imageinfo));
		get->numimages = 1;
		ci = &get->imageinfo[0];
		ci->imageid = mystrdup(imageid);
		ci->dir = mystrdup(rimagedir);
		ci->path = mystrdup(path);
		ci->flags = CONFIG_PATH_ISFILE|CONFIG_PATH_RESOLVE;
		if (exists) {
			ci->flags |= CONFIG_PATH_EXISTS;
			ci->sig = mymalloc(sizeof(time_t));
			*(time_t *)ci->sig = sb.st_mtime;
			ci->flags |= CONFIG_SIG_ISMTIME;
		} else
			ci->sig = NULL;
		ci->uid = NOUID;
		ci->ngids = 0;
		set_get_values(get, 0);
		ci->extra = NULL;
	}

 done:
	if (path)
		free(path);
	if (getp) *getp = get;
	if (putp) *putp = put;
	return 0;
}

#if 0
static void
dump_host_authinfo(FILE *fd, char *node, char *cmd,
		   struct config_host_authinfo *ai)
{
	int i;

	/*
	 * Otherwise, dump the whole list of images for each node
	 */
	for (i = 0; i < ai->numimages; i++)
		if (ai->imageinfo[i].flags == CONFIG_PATH_ISFILE)
			fprintf(fd, "%s ", ai->imageinfo[i].imageid);

	/*
	 * And dump any directories that can be accessed
	 */
	for (i = 0; i < ai->numimages; i++)
		if (ai->imageinfo[i].flags == CONFIG_PATH_ISDIR)
			fprintf(fd, "%s/* ", ai->imageinfo[i].path);

	fprintf(fd, "\n");
}
#endif

static char *
null_canonicalize_imageid(char *imageid)
{
	if (imageid != NULL)
		return mystrdup(imageid);
	return NULL;
}

static int
null_set_upload_status(struct config_imageinfo *ii, int status)
{
	/* This status has already been logged by our caller, so do nothing */
	return 0;
}

static void
null_dump(FILE *fd)
{
	fprintf(fd, "Basic master frisbee config:\n");
	/* XXX do something */
}

struct config null_config = {
	null_deinit,
	null_read,
	null_get_host_authinfo,
	null_free_host_authinfo,
	null_get_server_address,
	null_canonicalize_imageid,
	null_set_upload_status,
	null_save,
	null_restore,
	null_free,
	null_dump
};

struct config *
null_init(char *opts)
{
	char pathbuf[PATH_MAX], *path;
	static int called;
	struct stat sb;

	if (called)
		return &null_config;
	called++;

	/*
	 * Options:
	 *   mcaddr=A.B.C.D      MC base address
	 *   mcportbase=N	 MC base portnum (0 for any ephem)
	 *   mcportnum=N	 Number of MC ports (0 for all above base)
	 *   bandwidth=NNNNNNNN  Max bandwidth of a server
	 *   dynamicbw=(1|0)	 Use dynamic bandwidth control
	 *   maxlinger=N	 Server lingers for N seconds after last req
	 *   report=N		 Clients report progress every N seconds
	 *   eventserver=host	 Host to sent client report events to
	 *
	 * Dependencies:
	 *
	 *   If "bandwidth" is zero, max bandwidth is unlimited.
	 *
	 *   "maxlinger" should be at least as long as "report" to ensure
	 *   you don't exit between reports.
	 *
	 *   If reporting is disabled, then "maxlinger" should be set higher
	 *   (say, 3-5 minutes) to account for clients with lots of memory
	 *   that download all the chunks well before they finish writing
	 *   them to disk. Not critical, but you could lose client stats.
	 *
	 *   If "report" is non-zero but "eventserver" is not set, reports
	 *   are only logged to the server log.
	 */
	if (opts && opts[0]) {
		char *opt;

		opts = mystrdup(opts);
		while ((opt = strsep(&opts, ",")) != NULL) {
			char *cp = index(opt, '=');
			if (cp) {
				*cp = 0;
				if (strcmp(opt, "mcaddr") == 0)
					DEFAULT_MCADDR = mystrdup(cp + 1);
				else if (strcmp(opt, "mcportbase") == 0)
					DEFAULT_MCPORT = mystrdup(cp + 1);
				else if (strcmp(opt, "mcportnum") == 0)
					DEFAULT_MCNUMPORT = mystrdup(cp + 1);
				else if (strcmp(opt, "bandwidth") == 0)
					maxrate = (uint32_t)
						strtol(cp+1, NULL, 10);
				else if (strcmp(opt, "dynamicbw") == 0)
					dynrate =
						(strtol(cp+1, NULL, 10) != 0) ?
						1 : 0;
				else if (strcmp(opt, "maxlinger") == 0)
					maxlinger = strtol(cp+1, NULL, 10);
				else if (strcmp(opt, "report") == 0)
					clientreport = strtol(cp+1, NULL, 10);
				else if (strcmp(opt, "eventserver") == 0)
					eserver = mystrdup(cp + 1);
			}
		}
		free(opts);
	}

	/* XXX we should attempt to validate the event server here */
	if (eserver && clientreport == 0) {
		FrisError("null_init: no report interval specified, event server disabled");
		free(eserver);
		eserver = NULL;
	}

	if (imagedir == NULL)
		imagedir = DEFAULT_IMAGEDIR;
	if ((path = myrealpath(imagedir, pathbuf)) == NULL) {
		FrisError("null_init: could not resolve '%s'", imagedir);
		return NULL;
	}
	rimagedir = mystrdup(path);

	indexfile = mymalloc(strlen(imagedir) + 1 + strlen(".index") + 1);
	sprintf(indexfile, "%s/.index", imagedir);
	if (stat(indexfile, &sb) < 0) {
		FILE *fd;

		if ((fd = fopen(indexfile, "w")) == NULL) {
			FrisError("null_init: could not create index file '%s'",
				  indexfile);
			unlink(indexfile);
			free(indexfile);
			return NULL;
		}
		fputs("0\n", fd);
		fclose(fd);
	}

	/* One time parsing of MC address info */
	if (sscanf(DEFAULT_MCADDR, "%d.%d.%d", &mc_a, &mc_b, &mc_c) != 3) {
		FrisError("null_init: MC base addr '%s' not in A.B.C format!",
			  DEFAULT_MCADDR);
		return NULL;
	}
	mc_port_lo = atoi(DEFAULT_MCPORT);
	mc_port_num = atoi(DEFAULT_MCNUMPORT);
	if (mc_port_num < 0 || mc_port_num >= 65536) {
		FrisError("emulab_init: MC numports '%s' not in valid range!",
			  DEFAULT_MCNUMPORT);
		return NULL;
	}
	if (mc_port_lo > 0) {
		if (mc_port_num == 0)
			mc_port_num = 65536 - mc_port_lo;
		if (mc_port_lo + mc_port_num > 65536) {
			FrisError("emulab_init: MC baseport (%d) + "
				  "MC numports (%d) too large!",
				  mc_port_lo, mc_port_num);
			return NULL;
		}
	}

	return &null_config;
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
		FrisError("config_null: out of memory!");
		abort();
	}
	return ptr;
}

static void *
myrealloc(void *ptr, size_t size)
{
	void *nptr = realloc(ptr, size);
	if (nptr == NULL) {
		FrisError("config_null: out of memory!");
		abort();
	}
	return nptr;
}

static char *
mystrdup(const char *str)
{
	char *nstr = strdup(str);
	if (nstr == NULL) {
		FrisError("config_null: out of memory!");
		abort();
	}
	return nstr;
}

#else
struct config *
null_init(void)
{
	return 0;
}
#endif
