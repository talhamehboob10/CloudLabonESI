/*
 * Copyright (c) 2000-2003, 2007 University of Utah and the Flux Group.
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

/* sdcollectd.h - header file for Slothd Collection Daemon.
*/
#ifndef SDCOLLECTD_H
#define SDCOLLECTD_H

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <netdb.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <pwd.h>
#include <grp.h>
#include "config.h"
#include "tbdb.h"
#include "log.h"

#define SDPROTOVERS 2
#define NODENAMESIZE 100
#define BUFSIZE 1500
#define MAXNUMIFACES 10
#define MACADDRLEN 12

#define MAXKEYSIZE 10
#define MAXVALUESIZE 40

#define LONG_FORMAT "%20lu"
#define DBL_FORMAT "%20lf"
#define HEX_FORMAT "%8lx"
#define MADDR_FORMAT "%17[0-9a-fA-F:-]"
/* CPP wackiness */
#define KVSCAN_FORMAT(x,y) KVSCAN_FORMAT_INDIRECT(x,y)
#define KVSCAN_FORMAT_INDIRECT(x,y) "%" #x "[^=]=%" #y "s"

#define NUMACTTYPES 4
#define ACTSTRARRAY {"last_tty_act", "last_cpu_act", "last_net_act", "last_ext_act"}

#ifndef SDCOLLECTD_PORT
#define SDCOLLECTD_PORT 8509
#endif

#ifndef RUNASUSER
#define RUNASUSER "nobody"
#endif

#ifndef DOSTATS
#define DOSTATS 0
#endif

#ifdef USE_RRDTOOL
#include <rrd.h>

#define SD_RRD_STORAGEDIR TBROOT "/data/slothd_rrd"
#define SD_RRD_STEPSIZE 300  /* five minutes. */

const char *SD_RRD_NODE_LAYOUT[] = {
  "DS:last_tty:DERIVE:600:0:U",
  "DS:load_1min:GAUGE:600:0:U",
  "DS:load_5min:GAUGE:600:0:U",
  "DS:load_15min:GAUGE:600:0:U",
  "RRA:AVERAGE:0.5:1:288",       /* 5m samples for a day. */
  "RRA:MAX:0.5:12:168",          /* Max of 12 x 5m samples (1 hr), keep 1w. */
  "RRA:AVERAGE:0.5:12:168"       /* Avg of 12 x 5m samples (1 hr), keep 1w. */
};

const char *SD_RRD_IFACE_LAYOUT[] = {
  "DS:ipkts:DERIVE:600:0:U",
  "DS:opkts:DERIVE:600:0:U",
  "RRA:AVERAGE:0.5:1:288",       /* 5m samples for a day. */
  "RRA:MAX:0.5:12:168",          /* Max of 12 x 5m samples (1 hr), keep 1w. */
  "RRA:AVERAGE:0.5:12:168"       /* Avg of 12 x 5m samples (1 hr), keep 1w. */
};
#endif

typedef struct {
  u_char dostats;
  u_char debug;
  u_short port;
} SDCOLLECTD_OPTS;

SDCOLLECTD_OPTS *opts;

typedef struct {
  long   mis;
  double l1m;
  double l5m;
  double l15m;
  u_char ifcnt;
  u_int  actbits;
  u_int  version;
  struct {
    char mac[MACADDRLEN+1];
    unsigned long ipkts;
    unsigned long opkts;
  }      ifaces[MAXNUMIFACES];
  char   id[NODENAMESIZE];      /* Host identifier - probably local part of hostname */
  char   buf[BUFSIZE];    /* String containing monitor output values */
} IDLE_DATA;

extern int errno;

int CollectData(int, IDLE_DATA*);
int ParseRecord(IDLE_DATA*);
void PrintRecord(IDLE_DATA*);
void UpdateDBRecord(IDLE_DATA*);
void PutDBStats(IDLE_DATA*);
void PutRRDStats(IDLE_DATA*);

char *tbmac(char*, char**);


#endif
