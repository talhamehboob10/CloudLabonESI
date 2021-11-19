/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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

#ifndef _packet_table_h
#define _packet_table_h

#include <stdio.h>
#include <sys/types.h>

#include "nfs_prot.h"

#define PACKET_TABLE_SIZE 31

typedef struct _packetTrack {
    struct _packetTrack *pt_next;
    u_int32_t pt_host;
    u_int32_t pt_xid;
    u_int32_t pt_version;
    char pt_fh[96];
    int pt_fh_len;
    int pt_count;
    u_int32_t pt_secs;
    u_int32_t pt_usecs;
    int pt_bytes;

    char pt_fattr[13 * sizeof(u_int32_t) + 4 * sizeof(u_int64_t)];
} packetTrack_t;

typedef struct _packetTable {
    packetTrack_t *pt_tracks[PACKET_TABLE_SIZE];
} packetTable_t;

packetTable_t *ptCreateTable(void);
void ptDeleteTable(packetTable_t *pt);

unsigned int ptHash(u_int32_t host, char *fh, int fh_len);
packetTrack_t *ptLookupTrack(packetTable_t *pt, u_int32_t host,
			     char *fh, int fh_len, int *hash_out);
int ptUpdateTrack(packetTable_t *pt, u_int32_t host, char *fh, int fh_len,
		  u_int32_t secs, u_int32_t usecs, u_int32_t version,
		  u_int32_t xid, u_int32_t len, int *hash_out);
void ptUpdateTrackAttr(packetTable_t *pt, u_int32_t host, u_int32_t hash,
		       u_int32_t xid, u_int32_t *fa, u_int32_t *fae);
void ptDumpTable(FILE *file, packetTable_t *pt, char *proc);
void ptClearTable(packetTable_t *pt);

#endif
