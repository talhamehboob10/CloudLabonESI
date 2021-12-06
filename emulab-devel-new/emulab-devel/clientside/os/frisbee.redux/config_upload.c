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
 * This is a special case null config for the Emulab ops node for uploading images.
 *
 * - imageid must be a path (start with a '/')
 * - paths have been validated by an upcall to our parent (boss)
 * - paths must start with /proj/<pid>/images/ or /groups/<pid>/<gid>/images/
 * - we do not use a tmp file when uploading, assume we are called by create_image
 * - we run as the owner/group of the file if it exists, root otherwise
 */ 

#ifdef USE_UPLOAD_CONFIG
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

/* Emulab includes */
#include "config.h"	/* the defs-* defines */

extern int debug;

static char *DEFAULT_PORTLOW	= "0";
static char *DEFAULT_NUMPORT	= "0";
static char *PROJDIR		= PROJROOT_DIR;
static char *GROUPSDIR	 	= GROUPSROOT_DIR;

static uint64_t	put_maxsize = 10000000000ULL;	/* zero means no limit */
static uint32_t put_maxwait = 2000;		/* zero means no limit */
static uint32_t put_maxiwait = 120;		/* zero means no limit */
static int      port_lo, port_num;

/* Memory alloc functions that abort when no memory */
static void *mymalloc(size_t size);
static char *mystrdup(const char *str);

static void
upload_deinit(void)
{
}

static int
upload_read(void)
{
	/* "Reading" the config file is a no-op. Just echo settings. */
	FrisLog("  NO download capability");
	FrisLog("  image_put_maxsize = %d GB",
		(int)(put_maxsize/(1000*1000*1000)));
	FrisLog("  image_put_maxwait = %d min",
		(int)(put_maxwait/60));
	FrisLog("  image_put_maxiwait = %d min",
		(int)(put_maxiwait/60));

	return 0;
}

static void *
upload_save(void)
{
	static int dummy;

	/* Just return non-zero value */
	return (void *)&dummy;
}

static int
upload_restore(void *state)
{
	FrisLog("  NO download capability");
	FrisLog("  image_put_maxsize = %d GB",
		(int)(put_maxsize/(1000*1000*1000)));
	FrisLog("  image_put_maxwait = %d min",
		(int)(put_maxwait/60));
	FrisLog("  image_put_maxiwait = %d min",
		(int)(put_maxiwait/60));

	return 0;
}

static void
upload_free(void *state)
{
}

#if 0
/*
 * Set the GET methods and options for a particular node/image.
 * XXX should never be used.
 */
static void
set_get_values(struct config_host_authinfo *ai, int ix)
{
	/* get_methods */
	ai->imageinfo[ix].get_methods = CONFIG_IMAGE_UNKNOWN;

	/* get_timeout */
	ai->imageinfo[ix].get_timeout = 0;

	/* get_options */
	ai->imageinfo[ix].get_options = "";

	/* and whack the put_* fields */
	ai->imageinfo[ix].put_maxsize = 0;
	ai->imageinfo[ix].put_timeout = 0;
	ai->imageinfo[ix].put_itimeout = 0;
	ai->imageinfo[ix].put_oldversion = NULL;
	ai->imageinfo[ix].put_options = NULL;

	/* and pget fields */
	ai->imageinfo[ix].pget_options = NULL;
}
#endif

/*
 * Set the PUT maxsize/options for a particular node/image.
 * XXX right now these are completely pulled out of our posterior.
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

	/* put_oldversion -- setting to NULL means no tmpfile during upload */
	ii->put_oldversion = NULL;

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
upload_free_host_authinfo(struct config_host_authinfo *ai)
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
 * Here we just keep a static index and increment through it for selecting
 * a port number.
 *
 * Return zero on success, non-zero otherwise.
 */
static int
upload_get_server_address(struct config_imageinfo *ii, int methods, int first,
			  in_addr_t *addrp, in_port_t *loportp,
			  in_port_t *hiportp, int *methp)
{
	static int myidx = 0;

	/*
	 * Unicast is our ONLY choice.
	 */
	if ((methods & CONFIG_IMAGE_UCAST) == 0) {
		FrisError("get_server_address: only support unicast");
		return 1;
	}

	*methp = CONFIG_IMAGE_UCAST;
	/* XXX on retries, we don't mess with the address */
	if (first)
		*addrp = 0;

	/*
	 * Calculate a port range:
	 *
	 * If port_lo == 0, the server always chooses so we just return
	 * lo == hi == 0.
	 *
	 * Otherwise, if this is the first call, we use the index to compute
	 * a starting value in the [port_lo - port_lo+port_num]
	 * range. Given an increasing index, these keeps us from starting
	 * to look at the same place everytime and (hopefully) will reduce
	 * the number of conflicts that the server encounters.
	 *
	 * If this was not the first call, we return the full range on
	 * every call.
	 */
	if (port_num == 0) {
		*loportp = 0;
		*hiportp = 0;
	} else if (first) {
		*loportp = port_lo + (myidx % port_num);
		*hiportp = port_lo + port_num - 1;
	} else {
		*loportp = port_lo;
		*hiportp = port_lo + port_num - 1;
	}

	if (debug)
		fprintf(stderr,
			"get_server_address: idx %d, addr 0x%x, port [%d-%d]\n",
			myidx, *addrp, *loportp, *hiportp);

	myidx++;
	return 0;
}

/*
 * Find a specific image (imageid!=NULL) that a particular node can access
 * for PUT.  We do not allow GETs.
 *
 * PUTs calls must be for a single image, that image path must have been
 * validated by an upcall to our parent (boss), and the path must start with
 * either "/proj/<pid>/images/" or "/groups/<pid>/<gid>/images/".
 *
 * Return zero on success, non-zero otherwise.
 */
static int
upload_get_host_authinfo(struct in_addr *req, struct in_addr *host,
		       char *imageid,
		       struct config_host_authinfo **getp,
		       struct config_host_authinfo **putp)
{
	struct config_host_authinfo *put;
	struct config_imageinfo *ci;
	struct stat sb;
	int exists;
	char rpath[PATH_MAX], *cp, *fdir;
	int idlen;

	/* Upload only! */
	if (getp != NULL || putp == NULL) {
		if (debug)
			fprintf(stderr, "Only handle PUT requests\n");
		return 1;
	}

	/* Must specify an image */
	if (imageid == NULL || imageid[0] != '/') {
		if (debug)
			fprintf(stderr, "PUT requires a full path\n");
		return 1;
	}

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
	 * Run the path through realpath and then verify that it is within
	 * /proj or /groups.
	 *
	 * At this point we cannot do a full path check since the
	 * full path need not exist and we are possibly running with
	 * enhanced privilege. So we only weed out obviously bogus
	 * paths here (possibly checking just the partial path
	 * returned by realpath) and mark the imageinfo as needed a
	 * full resolution later.
	 */
	if (myrealpath(imageid, rpath) == NULL) {
		if (errno != ENOENT) {
			return 1;
		}
		exists = 0;
	} else
		exists = 1;
	if (debug)
		FrisInfo("%s: exists=%d, resolves to: '%s'",
			 imageid, exists, rpath);

	if ((fdir = isindir(PROJDIR, rpath)) == NULL &&
	    (fdir = isindir(GROUPSDIR, rpath)) == NULL)
		return 1;

	if (exists && stat(imageid, &sb) < 0)
		exists = 0;

	put = mymalloc(sizeof *put);
	memset(put, 0, sizeof(*put));

	/*
	 * XXX we don't care about the node identity right now.
	 * we should at least restrict it to the local subnet.
	 */
	put->hostid = mystrdup(inet_ntoa(*host));

	/*
	 * Return this image
	 */
	put->imageinfo = mymalloc(sizeof(struct config_imageinfo));
	put->numimages = 1;
	ci = &put->imageinfo[0];
	ci->imageid = mystrdup(imageid);
	ci->dir = mystrdup(fdir);
	ci->path = mystrdup(imageid);
	ci->flags = CONFIG_PATH_ISFILE|CONFIG_PATH_RESOLVE;
	if (exists) {
		ci->flags |= CONFIG_PATH_EXISTS;
		ci->sig = mymalloc(sizeof(time_t));
		*(time_t *)ci->sig = sb.st_mtime;
		ci->flags |= CONFIG_SIG_ISMTIME;
		/* XXX if the file exists, we run as the owner of that file */
		ci->uid = sb.st_uid;
		ci->gids[0] = sb.st_gid;
		ci->ngids = 1;
	} else {
		ci->sig = NULL;
		ci->uid = NOUID;
		ci->ngids = 0;
	}
	set_put_values(put, 0);
	ci->extra = NULL;

	*putp = put;
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
upload_canonicalize_imageid(char *imageid)
{
	if (imageid != NULL)
		return mystrdup(imageid);
	return NULL;
}

static int
upload_set_upload_status(struct config_imageinfo *ii, int status)
{
	/* This status has already been logged by our caller, so do nothing */
	return 0;
}

static void
upload_dump(FILE *fd)
{
	fprintf(fd, "Emulab upload-only master frisbee config:\n");
	/* XXX do something */
}

struct config upload_config = {
	upload_deinit,
	upload_read,
	upload_get_host_authinfo,
	upload_free_host_authinfo,
	upload_get_server_address,
	upload_canonicalize_imageid,
	upload_set_upload_status,
	upload_save,
	upload_restore,
	upload_free,
	upload_dump
};

struct config *
upload_init(char *opts)
{
	char pathbuf[PATH_MAX], *path;
	static int called;

	if (called)
		return &upload_config;
	called++;

	/*
	 * Options:
	 *   portbase=N	 base portnum to use for uploads (0 for any ephem)
	 *   portnum=N	 Number of ports in upload range (0 for all above base)
	 *   maxsize=N   Max size of an uploaded image in GB
	 *   maxwait=N   Max time to allow for an upload in minutes
	 *   maxidle=N   Max idle time to allow during an upload in minutes
	 */
	if (opts && opts[0]) {
		char *opt;

		opts = mystrdup(opts);
		while ((opt = strsep(&opts, ",")) != NULL) {
			char *cp = index(opt, '=');
			if (cp) {
				*cp = 0;
				if (strcmp(opt, "portbase") == 0)
					DEFAULT_PORTLOW = mystrdup(cp + 1);
				else if (strcmp(opt, "portnum") == 0)
					DEFAULT_NUMPORT = mystrdup(cp + 1);
				else if (strcmp(opt, "maxsize") == 0)
					put_maxsize = (uint64_t)
						strtol(cp+1, NULL, 10) *
						1000 * 1000 * 1000;
				else if (strcmp(opt, "maxwait") == 0)
					put_maxwait = (uint32_t)
						strtol(cp+1, NULL, 10) * 60;
				else if (strcmp(opt, "maxidle") == 0)
					put_maxiwait = (uint32_t)
						strtol(cp+1, NULL, 10) * 60;
			}
		}
		free(opts);
	}

	if ((path = myrealpath(PROJROOT_DIR, pathbuf)) == NULL) {
		FrisError("upload_init: could not resolve '%s'",
			  PROJROOT_DIR);
		return NULL;
	}
	PROJDIR = mystrdup(path);

	if ((path = myrealpath(GROUPSROOT_DIR, pathbuf)) == NULL) {
		FrisError("upload_init: could not resolve '%s'",
			  GROUPSROOT_DIR);
		return NULL;
	}
	GROUPSDIR = mystrdup(path);

	port_lo = atoi(DEFAULT_PORTLOW);
	port_num = atoi(DEFAULT_NUMPORT);
	if (port_num < 0 || port_num >= 65536) {
		FrisError("emulab_init: numports '%s' not in valid range!",
			  DEFAULT_NUMPORT);
		return NULL;
	}
	if (port_lo > 0) {
		if (port_num == 0)
			port_num = 65536 - port_lo;
		if (port_lo + port_num > 65536) {
			FrisError("emulab_init: baseport (%d) + "
				  "numports (%d) too large!",
				  port_lo, port_num);
			return NULL;
		}
	}

	return &upload_config;
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
		FrisError("config_upload: out of memory!");
		abort();
	}
	return ptr;
}

static char *
mystrdup(const char *str)
{
	char *nstr = strdup(str);
	if (nstr == NULL) {
		FrisError("config_upload: out of memory!");
		abort();
	}
	return nstr;
}

#else
struct config *
upload_init(void)
{
	return 0;
}
#endif
