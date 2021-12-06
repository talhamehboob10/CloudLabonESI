/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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
 * Quick hack to dump the current set of subscriptions on an Elvind server
 */

#include <stdio.h>
#include <ctype.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include "log.h"
#include "event.h"

static char	*progname;
static int      counter = 0;
static char     *ATTRS[] = {"SCHEDULER"};
static int      numattrs = 1;

void
usage()
{
	fprintf(stderr,
		"Usage: %s [-s server] [-p port] [-k keyfile]\n", progname);
	exit(-1);
}

void add_cb(elvin_handle_t handle,
            elvin_quench_t quench,
            int is_secure,
            int64_t term_id,
            elvin_ast_t term,
            void *rock,
            elvin_error_t error) {

  char *aststr;

  aststr = elvin_ast_to_string(term, error);

  counter++;
  printf("%s\n", aststr);
  
}

void modify_cb(elvin_handle_t handle,
               elvin_quench_t quench,
               int is_secure,
               int64_t term_id,
               elvin_ast_t term,
               void *rock,
               elvin_error_t error) {

  printf("Got MODIFY quench!\n");
}

void del_cb(elvin_handle_t handle,
            elvin_quench_t quench,
            int64_t term_id,
            void *rock,
            elvin_error_t error) {

  printf("Got DELETE quench!\n");
}

int
main(int argc, char **argv)
{
	event_handle_t handle;
        elvin_error_t elverr;
        elvin_attrlist_t attrlist;
	char *server = NULL;
	char *port = NULL;
	char buf[BUFSIZ];
        int lastcounter = 0;
	int c, i;

	progname = argv[0];
	
	while ((c = getopt(argc, argv, "s:p:")) != -1) {
		switch (c) {
		case 's':
			server = optarg;
			break;
		case 'p':
			port = optarg;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	loginit(0, 0);

	/*
	 * Convert server/port to elvin thing.
	 *
	 * XXX This elvin string stuff should be moved down a layer. 
	 */
	if (server) {
		snprintf(buf, sizeof(buf), "elvin://%s%s%s",
			 server,
			 (port ? ":"  : ""),
			 (port ? port : ""));
		server = buf;
	}

        /* Register with the event system */
	handle = event_register(server, 0);
	if (handle == NULL) {
		fatal("could not register with event system");
	}

        if ((elverr = elvin_error_alloc()) == NULL) {
          fatal("Cannot allocate elvin error structure!");
        }

        if ((attrlist = elvin_attrlist_alloc(elverr)) == NULL) {
          error("Problem allocating attribute list");
          elvin_error_fprintf(stderr, elverr);
          exit(1);
        }

        for (i = 0; i < numattrs; ++i) {
          if (!elvin_attrlist_add(attrlist, ATTRS[i], elverr)) {
            error("Could not add to attribute list");
            elvin_error_fprintf(stderr, elverr);
            exit(1);
          }
        }

        if (!elvin_sync_add_quench(handle->server, attrlist, NULL, 1,
                                   add_cb, modify_cb, del_cb,
                                   NULL, elverr)) {
          error("Error adding quench to server");
          elvin_error_fprintf(stderr, elverr);
          exit(1);
        }

        /*
	 * Begin the event loop...
         */

        i = 0;
        while(i < 2) {
          int retval = 0;
          retval = event_poll_blocking(handle, 1000);
          if (counter == lastcounter) {
            i++;
          } else {
            i = 0;
          }
          lastcounter = counter;
        }

        return 0;
}
