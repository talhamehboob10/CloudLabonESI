/*
 * Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

#define SERVERPORT	855
#define LOGGERPORT	858
#define DEVPATH		"/dev"
#define TIPPATH		"/dev/tip"
#ifndef LOGPATH
#define LOGPATH		"/var/log/tiplogs"
#endif
/* Socket based tip/capture uses an ACL file to hold key below. */
#define ACLPATH		LOGPATH

/*
 * The key is transferred from capture to capserver in ascii text.
 */
typedef struct {
	int		keylen;		/* of the key string */
	char		key[256];	/* and the string itself. */
} secretkey_t;
#define DEFAULTKEYLEN	32

/*
 * The capserver then returns this structure as part of the handshake.
 */
typedef struct {
	uid_t		uid;
	gid_t		gid;
} tipowner_t;

/*
 * The remote capture sends this back when it starts up
 */
typedef struct {
	char		name[64];	/* "tipname" in tiplines table */
	int		portnum;
	secretkey_t	key;
} whoami_t;

/*
 * This is for the cap logger handshake, which passes additional stuff.
 */
typedef struct {
    secretkey_t		secretkey;
    char		node_id[128];
    int			offset;
    unsigned int	flags;
} logger_t;
#define CAPLOGFLAG_NOFLAGS	0x0
#define CAPLOGFLAG_TAIL		0x1

/*
 * Return Status. Define a constant size return to ensure that the
 * status is read as an independent block, distinct from any output
 * that might be sent. An int is a reasonable thing to use.
 *
 * XXX: If you change this, be sure to change the PERL code!
 */
#define CAPOK		0
#define CAPBUSY		1
#define CAPNOPERM	2
#define CAPERROR        3
typedef int		capret_t;
