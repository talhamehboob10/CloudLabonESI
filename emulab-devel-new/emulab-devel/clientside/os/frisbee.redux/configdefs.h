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

#include <netinet/in.h>
#include <arpa/inet.h>

/*
 * Maximum groups for a server process.
 * We limit NGROUPS_MAX because it is huge on Linux (64K).
 */
#if NGROUPS_MAX < 1024
#define MAXGIDS (NGROUPS_MAX+1)
#else
#define MAXGIDS	1024
#endif

#define MAXIMAGEDIRS 4

#define NOUID (-1)

/*
 * Config info for a single image
 * XXX needs to be extended for REs.
 */
struct config_imageinfo {
	char *imageid;		/* unique name of image */
	char *dir;		/* directory to which path must resolve */
	char *path;		/* path where image is stored */
	void *sig;		/* signature of image */
	int flags;		/* */
	int uid;		/* UID to run server process as */
	gid_t gids[MAXGIDS];	/* GIDs to run server process as */
	int ngids;		/* number of valid GIDs */
	char *get_options;	/* command line options for GET server */
	int get_methods;	/* allowed GET transfer mechanisms */
	int get_timeout;	/* max time to allow GET server to run */
	char *put_options;	/* command line options for PUT server */
	uint64_t put_maxsize;	/* maximum size for this image */
	int put_timeout;	/* max time to allow PUT server to run */
	int put_itimeout;	/* max time to allow per-socket-op to run */
	char *put_oldversion;	/* where to save the old version */
	char *pget_options;	/* options for parent-fetch client */
	void *extra;		/* config-type specific info */
};

/* flags */
#define CONFIG_PATH_ISFILE	0x1	/* path is an image file */
#define CONFIG_PATH_ISDIR	0x2	/* path is a directory */
#define CONFIG_PATH_ISGLOB	0x4	/* path is a file glob */
#define CONFIG_PATH_ISRE	0x8	/* path is a perl RE */
#define CONFIG_PATH_ISSIGFILE	0x10	/* path is an image sigfile */
#define CONFIG_PATH_RESOLVE	0x20	/* path needs resolution at use */
#define CONFIG_PATH_EXISTS	0x40	/* imaged named by path arg exists */
#define CONFIG_SIG_ISMTIME	0x1000	/* sig is path mtime */
#define CONFIG_SIG_ISMD5	0x2000	/* sig is MD5 hash of path */
#define CONFIG_SIG_ISSHA1	0x4000	/* sig is SHA1 hash of path */

/* methods */
#define CONFIG_IMAGE_UNKNOWN	0x0
#define CONFIG_IMAGE_UCAST	0x1
#define CONFIG_IMAGE_MCAST	0x2
#define CONFIG_IMAGE_BCAST	0x4
#define CONFIG_IMAGE_ANY	0x7

struct config_host_authinfo {
	char *hostid;		/* unique name of host */
	int numimages;		/* number of images in info array */
	struct config_imageinfo *imageinfo; /* info array */
	void *extra;		/* config-type specific info */
};

/*
 * Config file functions
 */
struct config {
	void (*config_deinit)(void);
	int (*config_read)(void);
	int (*config_get_host_authinfo)(struct in_addr *,
					struct in_addr *, char *,
					struct config_host_authinfo **,
					struct config_host_authinfo **);
	void (*config_free_host_authinfo)(struct config_host_authinfo *);
	int (*config_get_server_address)(struct config_imageinfo *, int, int,
					 in_addr_t *, in_port_t *, in_port_t *,
					 int *);
	char *(*config_canonicalize_imageid)(char *);
	int (*config_set_upload_status)(struct config_imageinfo *, int);
	void *(*config_save)(void);
	int (*config_restore)(void *);
	void (*config_free)(void *);
	void (*config_dump)(FILE *);
};

extern int	config_init(char *, int, char *);
extern void	config_deinit(void);
extern int	config_read(void);
extern int	config_get_host_authinfo(struct in_addr *,
					 struct in_addr *, char *,
					 struct config_host_authinfo **,
					 struct config_host_authinfo **);
extern void	config_dump_host_authinfo(struct config_host_authinfo *);
extern void	config_free_host_authinfo(struct config_host_authinfo *);
extern int	config_auth_by_IP(int, struct in_addr *, struct in_addr *,
				  char *, struct config_host_authinfo **);
extern int	config_get_server_address(struct config_imageinfo *, int, int,
					  in_addr_t *, in_port_t *, in_port_t *,
					  int *);
extern char *	config_canonicalize_imageid(char *);
extern int	config_set_upload_status(struct config_imageinfo *, int);
extern void *	config_save(void);
extern int	config_restore(void *);
extern void	config_dump(FILE *);

/* Common utility functions */
extern char *	isindir(char *dir, char *path);
extern char *	myrealpath(char *path, char rpath[PATH_MAX]);
extern char *	resolvepath(char *path, char *dir, int create);

