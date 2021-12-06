/*
 * Copyright (c) 2003-2014 University of Utah and the Flux Group.
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
 * Dave swears we use this on plab nodes. Hand installed into the rootball.
 */
#include <stdio.h>
#include <ctype.h>
#include <netdb.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <paths.h>
#include <sys/errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "config.h"
#include "event.h"
#include "tbdefs.h"
#include "log.h"
#include <map>
#include <string>
#include <iostream>
#include <cstring>

#define IPADDRFILE "/var/emulab/boot/myip"

static int debug = 0;
static event_handle_t localhandle;
static event_handle_t bosshandle;
static std::map<std::string, event_subscription_t> exptmap;
static char nodeidstr[BUFSIZ], ipaddr[32];
;

void
usage(char *progname)
{
    fprintf(stderr, "Usage: %s [-s server] [-p port] [-l local_elvin_port] "
	    "-n pnodeid \n", progname);
    exit(-1);
}

static void
callback(event_handle_t handle,
	 event_notification_t notification, void *data);

static void
expt_callback(event_handle_t handle,
	 event_notification_t notification, void *data);

static void
sched_callback(event_handle_t handle,
	       event_notification_t notification, void *data);

static void subscribe_callback(event_handle_t handle,  int result,
			       event_subscription_t es, void *data);

static void status_callback(pubsub_handle_t *handle,
                            pubsub_status_t status, void *data,
                            pubsub_error_t *error);

static void schedule_updateevent();

static int do_remote_register(char const *server);


int
main(int argc, char **argv)
{
	address_tuple_t		tuple;
	char			*progname;
	char const		*server = NULL;
	char			*port = NULL, *lport = NULL;
	char			*myeid = NULL;
	char			*pnodeid = NULL;
	char			buf[BUFSIZ];
	char			hostname[MAXHOSTNAMELEN];
	struct hostent		*he;
	int			c;
	struct in_addr		myip;
        int                     o1, o2, o3, o4;
        int                     scanres;
	FILE			*fp;

	progname = argv[0];
	
	while ((c = getopt(argc, argv, "ds:p:e:n:l:")) != -1) {
		switch (c) {
		case 'd':
			debug++;
			break;
		case 's':
			server = optarg;
			break;
		case 'p':
			port = optarg;
			break;
		case 'l':
			lport = optarg;
			break;
		case 'e':
			myeid = optarg;
			break;
		case 'n':
		        pnodeid = optarg;
                        break;
		default:
			usage(progname);
		}
	}
	argc -= optind;
	argv += optind;

	if (argc)
		usage(progname);

	if (! pnodeid)
	   fatal("Must provide pnodeid"); 

	if (debug) {
	        loginit(0, 0);
        }

	/*
	 * Get our IP address. Thats how we name this host to the
	 * event System. 
	 */
        if (gethostname(hostname, MAXHOSTNAMELEN) == -1) {
                fatal("could not get hostname: %s\n", strerror(errno));
        }

        if ((he = gethostbyname(hostname)) != NULL) {
                memcpy((char *)&myip, he->h_addr, he->h_length);
                strcpy(ipaddr, inet_ntoa(myip));
        } else {
                error("could not get IP address from hostname: %s\n"
                      "Attempting to get it from local config file...\n", 
                      hostname);
                fp = fopen(IPADDRFILE, "r");
                if (fp != NULL) {
                        scanres = fscanf(fp, "%3u.%3u.%3u.%3u", 
                                         &o1, &o2, &o3, &o4);
                        (void) fclose(fp);
                        if (scanres != 4) {
                                fatal("IP address not found on first "
                                      "line of file!\n");
                        }
                        if (o1 > 255 || o2 > 255 || o3 > 255 || o4 > 255) {
                                fatal("IP address inside file is "
                                      "invalid!\n");
                        }
                        snprintf(ipaddr, sizeof(ipaddr), 
                                 "%u.%u.%u.%u", o1, o2, o3, o4);
                } else {
                        fatal("could not get IP from local file %s either!", 
                              IPADDRFILE);
                }
        }

        if (debug) {
                printf("My IP: %s\n", ipaddr);
        }

	/*
	 * If server is not specified, then it defaults to EVENTSERVER.
	 * This allows the client to work on either users.emulab.net
	 * or on a client node. 
	 */
	if (!server)
		server = "event-server";
	
	/*
	 * Convert server/port to elvin thing.
	 *
	 * XXX This elvin string stuff should be moved down a layer. 
	 */
	snprintf(buf, sizeof(buf), "elvin://%s%s%s",
		 server,
		 (port ? ":"  : ""),
		 (port ? port : ""));
	server = strdup(buf);

        /* Create nodeid string from pnode id passed in. */
	snprintf(nodeidstr, sizeof(nodeidstr), "__%s_proxy", pnodeid);

	/* Register with the event system on the local node */
	snprintf(buf, sizeof(buf), "elvin://localhost%s%s",
		 (lport ? ":"  : ""),
		 (lport ? lport : ""));
	localhandle = event_register(buf, 0);
	if (localhandle == NULL) {
		fatal("could not register with local event system");
	}
	
        /*
         * Setup local subscriptions:
         */
	tuple = address_tuple_alloc();
        
        tuple->host = ADDRESSTUPLE_ALL;
        tuple->scheduler = 1;
	
	if (! event_subscribe(localhandle, sched_callback, tuple,
			      NULL)) {
		fatal("could not subscribe to events on local server");
	}

        info("Successfully connected to local pubsubd.\n");

	/*
	 * Stash the pid away.
	 */
	snprintf(buf, sizeof(buf), "%s/evproxy.pid", _PATH_VARRUN);
	fp = fopen(buf, "w");
	if (fp != NULL) {
		fprintf(fp, "%d\n", getpid());
		(void) fclose(fp);
	}

	/*
	 * Do this now, once we have had a chance to fail on the above
	 * event system calls.
	 */
	if (!debug) {
		if (daemon(0, 0))
			fatal("could not daemonize");
		loginit(0, "/var/emulab/logs/evproxy.log");
	}
	
	/* Begin the event loop, waiting to receive event notifications */
        info("Entering main event loop.\n");
        while (1) {
          /* 
           * Register with the remote event system.
           * Keep trying until we get a connection.
           */
          while (do_remote_register(server) == 0) {
            event_unregister(bosshandle); /* just to be safe... */
            error("Failed to register with remote event system!\n"
                  "Sleeping for a bit before trying again...\n");
            sleep(10);
          }
          info("Remote pubsub registration complete.\n");
          /* Jump into the main event loop. */
          event_main(bosshandle);
          /* 
           * If we drop out of the event loop, it's because there was/is
           * some kind of problem with the connection to the remote event
           * server. So, clean up and re-register (re-subscribe).
           */
          error("exited event_main: retrying remote registration.\n");
          event_unregister(bosshandle);
          exptmap.clear(); /* clear our list of subs - it's invalid now. */
        }

	/* Unregister with the remote event system: */
	if (event_unregister(bosshandle) == 0) {
		fatal("could not unregister with remote event system");
	}
	/* Unregister with the local event system: */
	if (event_unregister(localhandle) == 0) {
		fatal("could not unregister with local event system");
	}

	return 0;
}


int do_remote_register(char const *server) {
        address_tuple_t		tuple;
	char			buf[BUFSIZ];

	/* Register with the event system on boss */
	while ((bosshandle = event_register(server, 0)) == 0) {
		error("Could not register with remote event system\n"
                      "\tSleeping for a bit, then trying again.\n");
                sleep(60);
	}

        /* Setup handle to periodically ping remote event server */
        event_set_idle_period(bosshandle, 30);

        /* Turn off failover on the remote connection - we'll manage it
           ourselves via the status callback. */
        event_set_failover(bosshandle, 0);

        /* Setup a status callback to watch the remote connection. */
        if (pubsub_set_status_callback(bosshandle->server,
				       status_callback,
				       const_cast<char *>(server), &bosshandle->status) != 0) {
          error("Could not register status callback!");
        }

	/*
	 * Create a subscription to pass to the remote server. We want
	 * all events for this node, or all events for the experiment
	 * if the node is unspecified (we want to avoid getting events
	 * that are directed at specific nodes that are not us!). 
	 */
	snprintf(buf, sizeof(buf), "%s,%s,%s", 
                 TBDB_EVENTTYPE_UPDATE, TBDB_EVENTTYPE_CLEAR,
                 TBDB_EVENTTYPE_RELOAD);

        tuple = address_tuple_alloc();
	tuple->eventtype = buf;
	tuple->host = ipaddr;
	tuple->objname = nodeidstr;
	tuple->objtype = TBDB_OBJECTTYPE_EVPROXY;
	
	/* Subscribe to the test event: */
	if (! event_subscribe(bosshandle, callback, tuple, 
			      (void *)"event received")) {
		error("could not subscribe to events on remote server");
                return 0;
        }

        /* Setup the global event passthru */
	address_tuple_free(tuple);
	tuple = address_tuple_alloc();

	snprintf(buf, sizeof(buf), "%s,%s", 
                 ipaddr, ADDRESSTUPLE_ALL);

	tuple->host = buf;
	tuple->expt = TBDB_EVENTEXPT_NONE;

	if (! event_subscribe(bosshandle, expt_callback, tuple, 
			      NULL)) {
		error("could not subscribe to events on remote server");
                return 0;
        }

        schedule_updateevent();

        return 1;
}


/*
 * Handle incoming events from the remote server. 
 */
static void
callback(event_handle_t handle, event_notification_t notification, void *data)
{
	char		eventtype[TBDB_FLEN_EVEVENTTYPE];
	char		objecttype[TBDB_FLEN_EVOBJTYPE];
	char		objectname[TBDB_FLEN_EVOBJNAME];
	char            expt[TBDB_FLEN_PID + TBDB_FLEN_EID + 1];

	
	event_notification_get_eventtype(handle,
					 notification, eventtype, sizeof(eventtype));
	event_notification_get_objtype(handle,
				       notification, objecttype, sizeof(objecttype));
	event_notification_get_objname(handle,
				       notification, objectname, sizeof(objectname));
	event_notification_get_expt(handle, notification, expt, sizeof(expt));
	
	if (debug) {
	  info("%s %s %s\n", eventtype, objecttype, objectname);  
	}
	
	if (strcmp(objecttype,TBDB_OBJECTTYPE_EVPROXY) == 0) {
	  
	  /* Add a new subcription request if a new expt is added on
	   * the plab node.
	   */

	  if (strcmp(eventtype,TBDB_EVENTTYPE_UPDATE) == 0) {
	    
	    std::string key(expt);
	    std::map<std::string, event_subscription_t>::iterator member = 
	      exptmap.find(key);
	    
	    if(member == exptmap.end()) {

	      address_tuple_t tuple = address_tuple_alloc();
	      if (tuple == NULL) {
		fatal("could not allocate an address tuple");
	      }
	      
	      tuple->expt = expt;
		  
	      /* malloc data -- to be freed in subscribe_callback */
	      char *data = (char *) xmalloc(sizeof(expt));
	      strcpy(data, expt);

	      int retval = event_async_subscribe(bosshandle, 
					  expt_callback, tuple, NULL,
					  subscribe_callback, 
					  (void *) data, 1);
	      if (! retval) {
		error("could not subscribe to events on remote server.\n");
	      }
              info("Subscribing to experiment: %s\n", expt);

	      address_tuple_free(tuple);
	    }
	  } 

	  
	  /* Remove a old subcription whenever get a CLEAR message */
	  
	  else if (strcmp(eventtype,TBDB_EVENTTYPE_CLEAR) == 0) {
	    std::string key(expt);
	    
	    std::map<std::string, event_subscription_t>::iterator member = 
	      exptmap.find(key);
	    
	    if(member != exptmap.end()) {
	      event_subscription_t tmp = member->second;
	      
	      /* remove the subscription */
	      int success = event_async_unsubscribe(handle, tmp);
	      
	      if (!success) {
		error("not able to delete the subscription.\n");
		pubsub_error_fprintf(stderr, &handle->status);
	      } else {
		exptmap.erase(key);
                info("Unsubscribing from experiment: %s\n", expt);
	      }
	    }
	  }
	  
	  /* reset all subscriptions if you get a RELOAD event */
	  else if (strcmp(eventtype,TBDB_EVENTTYPE_RELOAD) == 0) {

            info("RELOAD received.  Clearing experiment subscriptions "
                 "and scheduling an UPDATE.\n");
	   
	    std::map<std::string, event_subscription_t>::iterator iter;
	    
	    for(iter = exptmap.begin(); iter != exptmap.end(); iter++) {
	      /* remove the subscription */
	      std::string key = iter->first;
	      event_subscription_t tmp = iter->second;
		
	      int success = event_async_unsubscribe(handle, tmp);
	      
	      if (!success) {
		error("not able to delete the subscription.\n");
		pubsub_error_fprintf(stderr, &handle->status);
	      }
	    }
	      
	    exptmap.clear();
            schedule_updateevent();
	    
	  }
	  
	  /* pass thru EVPROXY events to plab-scheduler */
	  if (! event_notify(localhandle, notification))
            error("Failed to deliver notification!\n");
	  
	}
}

/*
 * Handle incoming experiment events from the remote server  
 */
static void
expt_callback(event_handle_t handle, event_notification_t notification, void *data)
{
	char		objecttype[TBDB_FLEN_EVOBJTYPE];
        char		objectname[TBDB_FLEN_EVOBJNAME];
	char            expt[TBDB_FLEN_PID + TBDB_FLEN_EID + 1];

	event_notification_get_objtype(handle,
				       notification, objecttype, sizeof(objecttype));
        event_notification_get_objname(handle,
				       notification, objectname, sizeof(objectname));
        event_notification_get_expt(handle, notification, expt, sizeof(expt));

        if (debug) {
          info("Received event for %s: %s %s\n", expt, objecttype, objectname);
	}

	if (strcmp(objecttype,TBDB_OBJECTTYPE_EVPROXY) != 0) {
	  if (! event_notify(localhandle, notification))
	    error("Failed to deliver notification!\n");
	}
}

static void
sched_callback(event_handle_t handle,
	       event_notification_t notification,
	       void *data)
{
        if (! event_notify(bosshandle, notification))
		error("Failed to deliver scheduled notification!\n");
  
}



/* Callback functions for asysn event subscribe */

void subscribe_callback(event_handle_t handle,  int result,
			event_subscription_t es, void *data) {
  if (!result) {
    std::string key((char *)data);
    exptmap[key] = es;
    info("Subscription for %s added successfully.\n", (char *)data);
  } else {
    error("not able to add the subscription.\n");
    pubsub_error_fprintf(stderr, &handle->status);
  }
  
  free(data);

}


/* Status callback function - tries to maintain remote connection */
static void status_callback(pubsub_handle_t *handle,
                            pubsub_status_t status, void *data,
                            pubsub_error_t *ignored)
{
  switch (status) {

  case PUBSUB_STATUS_CONNECTION_FAILED:
    /* sleep, and try to connect again. */
    error("Failed to connect to remote server");
    /* XXX: may need to do something more. */
    break;

  case PUBSUB_STATUS_CONNECTION_LOST:
    error("Connection loss/failure, trying to reconnect...\n");
    event_stop_main(bosshandle);
    break;

  case PUBSUB_STATUS_CONNECTION_FOUND:
    info("Remote connection established.");
    break;

  default:
    break;
  }
}


void schedule_updateevent() {
  /* send a message to event server on ops */
  address_tuple_t tuple = address_tuple_alloc();

  struct timeval now;
  gettimeofday(&now, NULL);

  if (tuple == NULL) {
    fatal("could not allocate an address tuple");
  }
  
  tuple->objtype = TBDB_OBJECTTYPE_EVPROXY;
  tuple->objname = nodeidstr;
  tuple->eventtype = TBDB_EVENTTYPE_UPDATE;
  tuple->host = ipaddr;
  
  event_notification_t notification = 
    event_notification_alloc(bosshandle, tuple);
  
  if (notification == NULL) {
    fatal("could not allocate notification\n");
  }
  
  if (event_schedule(bosshandle, notification, &now) == 0) {
    error("could not schedule update event.\n");
  }

  info("Scheduled remote UPDATE event.\n");

  event_notification_free(bosshandle, notification);
  
  address_tuple_free(tuple);

}
