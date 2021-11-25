/*
 * Copyright (c) 2000-2010 University of Utah and the Flux Group.
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

#include "sdcollectd.h"
#include <paths.h>

char *Pidname;

void siginthandler(int signum) {
  if (Pidname)
    (void) unlink(Pidname);
  info("Daemon exiting.\n");
  exit(0);
}


void usage(void) {  

  printf("Usage:\tslothd -h\n"
         "\tslothd [-d] [-p <port>]\n"
         "\t -h\t This message.\n"
         "\t -s\t Populate statistics tables/files.\n"
         "\t -d\t Debug mode; do not fork into background.\n"
         "\t -p <port>\t Listen on port <port> (default is %d).\n", 
         SDCOLLECTD_PORT);
}


int parse_args(int argc, char **argv) {

  char ch;

  /* setup defaults. */
  opts->dostats = DOSTATS;
  opts->debug = 0;
  opts->port = SDCOLLECTD_PORT;

  while ((ch = getopt(argc, argv, "sdp:h")) != -1) {
    switch (ch) {

    case 's':
      opts->dostats = 1;
      break;

    case 'd':
      info("Debug mode requested; staying in foreground.\n");
      opts->debug = 1;
      break;

    case 'p':
      opts->port = (u_short)atoi(optarg);
      break;

    case 'h':
    default:
      usage();
      return 0;
      break;
    }
  }
  return 1;
}


/* XXX:  Comment the code better! */

int main(int argc, char **argv) {

  int sd;
  struct sockaddr_in servaddr;
  static IDLE_DATA iddata;
  static SDCOLLECTD_OPTS gopts;

  extern char build_info[];

  opts = &gopts;
  
  /* Foo on SIGPIPE & SIGHUP. */
  signal(SIGPIPE, SIG_IGN);
  signal(SIGHUP, SIG_IGN);
  
  /* Cleanup on sigint/term */
  signal(SIGTERM, siginthandler);
  signal(SIGINT, siginthandler);

  /* setup logging facilities */
  loginit(1, "sdcollectd");
  
  if (!parse_args(argc, argv)) {
    error("Error processing arguments, exiting.\n");
    exit(1);
  }

  if (opts->dostats) {
    info("Populating statistics tables/files");
  }
  
  /* clear, and initialize inet sockaddr */
  bzero(&servaddr, sizeof(struct sockaddr_in));
  servaddr.sin_family = AF_INET;
  servaddr.sin_addr.s_addr = INADDR_ANY;
  if (opts->port) {
    servaddr.sin_port = htons(opts->port);
  } else {
    servaddr.sin_port = htons(SDCOLLECTD_PORT);
  }

  /* Create and bind udp socket for collecting slothd client-side idle data */
  if ((sd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    errorc("Can't create socket");
    exit(1);
  }

  if (bind(sd, (struct sockaddr*)&servaddr, sizeof(struct sockaddr_in)) < 0) {
    errorc("Can't bind socket");
    exit(1);
  }

  /* get DB funcs ready - libtb */
  if (!dbinit()) {
    error("Couldn't connect to db. bailing out.");
    exit(1);
  }

  if (!opts->debug) {
    if (daemon(0, 0) < 0) {
      errorc("Couldn't become daemon");
      exit(1);
    }
    info("sdcollectd started successfully");
    info(build_info);
  }

  if (!getuid()) {
    FILE	*fp;
    char    mybuf[BUFSIZ];
	    
    sprintf(mybuf, "%s/sdcollectd.pid", _PATH_VARRUN);
    fp = fopen(mybuf, "w");
    if (fp != NULL) {
      fprintf(fp, "%d\n", getpid());
      (void) fclose(fp);
      Pidname = strdup(mybuf);
    }
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

  /* do our thing - just loop collecting data from clients, and insert into
     DB. 
  */
  for ( ;; ) {
    bzero(&iddata, sizeof(IDLE_DATA)); /* cleanse out old values, if any */
    if (CollectData(sd, &iddata)) {
      if (ParseRecord(&iddata)) {
	if (opts->debug) {
	  PrintRecord(&iddata);
	}
	UpdateDBRecord(&iddata);
	if (opts->dostats) {
#ifdef USE_RRDTOOL
	  PutRRDStats(&iddata);
#else
	  PutDBStats(&iddata);
#endif
	}
      }
    }
  }
  /* NOTREACHED */
}

int CollectData(int sd, IDLE_DATA *iddata) {
  int numbytes;
  socklen_t slen;
  time_t curtime;
  /* struct hostent *hent; */
  struct sockaddr_in cliaddr;
  char *ipaddr;

  bzero(&cliaddr, sizeof(struct sockaddr_in));
  slen = sizeof(struct sockaddr_in);

  if((numbytes = recvfrom(sd, iddata->buf, sizeof(iddata->buf), 0,
                          (struct sockaddr*)&cliaddr, &slen))) {
    ipaddr = inet_ntoa(cliaddr.sin_addr);
    if (!mydb_iptonodeid(ipaddr, iddata->id)) {
      error("Couldn't obtain node id for IP: %s", ipaddr);
      return 0;
    }
    if (opts->debug) {
      curtime = time(NULL);
      printf("Received data from: %s at %s\n", iddata->id, ctime(&curtime));
      printf("buffer: %s\n", iddata->buf);
    }
  }

  /* Null terminate the received buffer for safety. */
  iddata->buf[sizeof(iddata->buf)-1] = '\0';
  return 1;
}

/******************************************************************************
Function:  tbmac

Purpose:  Utility function which takes buffers with ascii strings corresponding
          to ethernet mac addresses, and converts them into the standard 12
          character testbed format.

Args:  char *maddr: NULL-terminated input C-string which should contain a 
                    macaddr of the form "[X]X:[X]X:[X]X:[X]X:[X]X:[X]X.  If 
                    the first char in an octet is missing, it is assumed to 
                    be zero. Delimiter can actually be any non-hex digit (not 
                    just ':')

       char **endptr: mem addr to be filled in with pointer to character 
                     proceeding mac addr conversion in the input string *maddr.
                     Behaves as in strtol() and friends.

Returns: Pointer to static memory containing a testbed-style mac address (this
         being a string of exactly 12 hex digits.  NULL is returned if the
         input buffer does not have a mac address conforming to the form
         specified above for *maddr.

Side Effects:  Return memory area is overwritten on each call.

Notes:  *maddr parameter is unaltered.
******************************************************************************/

char *tbmac(char *maddr, char **endptr) {

  int i = 0;
  static char tbaddr[MACADDRLEN+1];
  char *myptr = maddr, *mylast = maddr;

  bzero(&tbaddr, sizeof(tbaddr));

  while (i < MACADDRLEN) {
    while (*myptr && isxdigit(*myptr)) myptr++;
    
    if (myptr - mylast == 1) {
      tbaddr[i++] = '0';
      tbaddr[i++] = toupper(*(myptr-1));
      mylast = ++myptr;
    }
    else if (myptr - mylast == 2) {
      tbaddr[i++] = toupper(*mylast);
      tbaddr[i++] = toupper(*(myptr-1));
      mylast = ++myptr;
    }
    else if (myptr - maddr == MACADDRLEN) {
      strncpy(tbaddr, maddr, MACADDRLEN);
      tbaddr[MACADDRLEN] = '\0';
      ++myptr;
      break;
    }
    else {
      break;
    }
  }

  if (strlen(tbaddr) != MACADDRLEN) {
    if (endptr) *endptr = NULL;
    return NULL;
  }
  else {
    if (endptr) *endptr = myptr-1;
    return tbaddr;
  }
}


int ParseRecord(IDLE_DATA *iddata) {
  char *itemptr, *tmpstr;
  int sres = 0;
  char key[MAXKEYSIZE+1], value[MAXVALUESIZE+1];
  unsigned long val1, val2;
  double dval1, dval2, dval3;
  char maddr[18];

  iddata->ifcnt = 0;
  
  /* First parsing pass: separate out the key/value pairs. */
  itemptr = strtok(iddata->buf, " \t");
  if (itemptr == NULL) {
    error("No valid data; rejecting.");
    return 0;
  }

  do {
    /* Second pass: split off the key and value */
    sres = sscanf(itemptr, KVSCAN_FORMAT(MAXKEYSIZE, MAXVALUESIZE), 
		  key, value);
    if (sres == 2) {
      /* Third pass: parse value according to key type. */
      if (!strcmp(key,"vers")) {
	sres = sscanf(value, LONG_FORMAT, &val1);
	if (sres == 1) {
	  if (val1 > SDPROTOVERS) {
	    error("Unsupported protocol version; report rejected.");
	    return 0;
	  } else {
	    iddata->version = val1;
	  }
	}
	else {
	  error("Packet from node %s rejected: Bad data in version field: %s", 
		iddata->id, value);
	  return 0;
	}
      }
      else if (!strcmp(key,"mis")) {
	sres = sscanf(value, LONG_FORMAT, &val1);
	if (sres == 1) {
	  iddata->mis = val1;
	}
	else {
	  error("Packet from node %s rejected: Bad data in mis field: %s", 
		iddata->id, value);
	  return 0;
	}
      }
      else if (!strcmp(key,"abits")) {
	sres = sscanf(value, HEX_FORMAT, &val1);
	if (sres == 1) {
	  iddata->actbits = val1;
	}
	else {
	  error("Packet from node %s rejected: Bad data in abits field: %s", 
		iddata->id, value);
	  return 0;
	}
      }
      else if (!strcmp(key,"lave")) {
	sres = sscanf(value, DBL_FORMAT "," DBL_FORMAT "," DBL_FORMAT , 
		      &dval1, &dval2, &dval3);
	if (sres == 3) {
	  iddata->l1m  = dval1;
	  iddata->l5m  = dval2;
	  iddata->l15m = dval3;
	} else {
	  error("Packet from node %s rejected: Bad data in lave field: %s", 
		iddata->id, value);
	  return 0;
	}
      }
      else if (!strcmp(key,"iface")) {
	sres = sscanf(value, MADDR_FORMAT "," LONG_FORMAT "," LONG_FORMAT , 
		      maddr, &val1, &val2);
	if (sres == 3) {
	  tmpstr = tbmac(maddr, NULL);
	  if (tmpstr) {
	    strncpy(iddata->ifaces[iddata->ifcnt].mac, tmpstr, MACADDRLEN);
	    iddata->ifaces[iddata->ifcnt].mac[MACADDRLEN] = '\0';
	    iddata->ifaces[iddata->ifcnt].ipkts = val1;
	    iddata->ifaces[iddata->ifcnt].opkts = val2;
	    iddata->ifcnt++;
	  } else {
	    error("Malformed interface record for node %s encountered: %s",
		  iddata->id,
		  maddr);
	    continue;
	  }
	}
	else {
	  error("Packet from node %s rejected: Bad data in iface field: %s", 
		iddata->id, value);
	  return 0;
	}
      }
      else {
	error("Packet rejected from node %s: Unknown key: %s", iddata->id, key);
	return 0;
      }
    } 
    else {
      error("Malformed packet received from node %s; rejecting.", iddata->id);
      return 0;
    }

  } while ((itemptr = strtok(NULL, " \t")) && iddata->ifcnt < MAXNUMIFACES);

  return 1;
}


void PrintRecord(IDLE_DATA *iddata) {
  int i;
  
  printf("Received and parsed packet. Contents:\n"
	 "Version: %u\n"
	 "Node: %s\n"
	 "Last TTY: %s"
	 "Load averages (1, 5, 15): %f, %f, %f\n"
	 "Active bits: 0x%04x\n",
	 iddata->version,
	 iddata->id,
	 ctime(&iddata->mis),
	 iddata->l1m,
	 iddata->l5m,
	 iddata->l15m,
	 iddata->actbits);
  for (i = 0; i < iddata->ifcnt; ++i) {
    printf("Interface %s: ipkts: %lu  opkts: %lu\n",
	   iddata->ifaces[i].mac,
	   iddata->ifaces[i].ipkts,
	   iddata->ifaces[i].opkts);
  }
  printf("\n\n");

  return;
}


void UpdateDBRecord(IDLE_DATA *iddata) {
  int i;
  time_t now = time(NULL);
  char curstamp[100];
  char tmpstr[(NUMACTTYPES+1)*sizeof(curstamp)];
  char *actstr[] = ACTSTRARRAY;

  sprintf(curstamp, "FROM_UNIXTIME(%lu)", (long unsigned int)now);  
  sprintf(tmpstr, "last_report=%s", curstamp);
  for (i = 0; i < NUMACTTYPES; ++i) {
    if (iddata->actbits & (1<<i)) {
      sprintf(tmpstr, "%s, %s=%s",
	      tmpstr,
	      actstr[i], 
	      curstamp);
    }
  }

  if(!mydb_update("UPDATE node_activity SET %s WHERE node_id = '%s'",
		  tmpstr,
		  iddata->id)) {
    error("Error updating stamps in node_activity table");
  }

  return;
}


void PutDBStats(IDLE_DATA *iddata) {
  int i;
  time_t now = time(NULL);

  if (!mydb_update("INSERT INTO node_idlestats VALUES ('%s', FROM_UNIXTIME(%lu), FROM_UNIXTIME(%lu), %f, %f, %f)", 
		   iddata->id, 
		   now,
		   iddata->mis, 
		   iddata->l1m, 
		   iddata->l5m, 
		   iddata->l15m)) {
    error("Error inserting data into node_idlestats table");
  }
    
  for (i = 0; i < iddata->ifcnt; ++i) {
    if (!mydb_update("INSERT INTO iface_counters VALUES ('%s', FROM_UNIXTIME(%lu), '%s', %lu, %lu)",
		     iddata->id,
		     now,
		     iddata->ifaces[i].mac,
		     iddata->ifaces[i].ipkts,
		     iddata->ifaces[i].opkts)) {
      error("Error inserting data into iface_counters table");
    }
  }
  
  return;
}


#ifdef USE_RRDTOOL

void PutRRDStats(IDLE_DATA *iddata) {
  int i;
  time_t now = time(NULL);
  char rrdfile[sizeof(SD_RRD_STORAGEDIR) + TBDB_FLEN_NODEID + MACADDRLEN + 7];
  char updstr[100];
  const char *updarr[] = {updstr};
  
  rrd_clear_error(); /* Precautionary */
  
  /* Create the RRD file if it doesn't exist. */
  sprintf(rrdfile, "%s/%s.rrd", SD_RRD_STORAGEDIR, iddata->id);
  if (access(rrdfile, F_OK) == -1) {
    if (errno == ENOENT) {
      if (rrd_create_r(rrdfile,
		       SD_RRD_STEPSIZE,
		       now - 10,
		       sizeof(SD_RRD_NODE_LAYOUT)/sizeof(char*),
		       SD_RRD_NODE_LAYOUT) != 0) {
	error("Failed to create RRD file for node %s: %s",
	      iddata->id,
	      rrd_get_error());
	return;
      }
    } else {
      errorc("RRD file check failed for node %s", iddata->id);
      return;
    }
  }

  /* Update RRD with new data. */
  sprintf(updstr, "N:%lu:%f:%f:%f",
	  iddata->mis, iddata->l1m, iddata->l5m, iddata->l15m);
  if (rrd_update_r(rrdfile, NULL, 1, updarr) != 0) {
    error("Failed to update RRD file for node %s: %s",
	  iddata->id,
	  rrd_get_error());
    return;
  }

  /* Now do the same for each network interface. One RRD for each iface. */
  for (i = 0; i < iddata->ifcnt; i++) {
    sprintf(rrdfile, "%s/%s-%s.rrd", SD_RRD_STORAGEDIR,
	    iddata->id, iddata->ifaces[i].mac);
    if (access(rrdfile, F_OK) == -1) {
      if (errno == ENOENT) {
	if (rrd_create_r(rrdfile,
			 SD_RRD_STEPSIZE,
			 now - 10,
			 sizeof(SD_RRD_IFACE_LAYOUT)/sizeof(char*),
			 SD_RRD_IFACE_LAYOUT) != 0) {
	  error("Failed to create RRD file for node/iface %s/%s: %s",
		iddata->id, iddata->ifaces[i],
		rrd_get_error());
	  return;
	}
      } else {
	errorc("RRD file check failed for node/iface %s/%s",
	       iddata->id, iddata->ifaces[i]);
	return;
      }
    }

    sprintf(updstr, "N:%lu:%lu",
	    iddata->ifaces[i].ipkts, iddata->ifaces[i].opkts);
    if (rrd_update_r(rrdfile, NULL, 1, updarr) != 0) {
      error("Failed to update RRD file for node/iface %s/%s: %s",
	    iddata->id, iddata->ifaces[i].mac,
	    rrd_get_error());
      return;
    }
  }
  
  return;
}

#endif
