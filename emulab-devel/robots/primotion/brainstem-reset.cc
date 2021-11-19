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

/**
 * @file brainstem-reset.cc
 *
 * Simple utility to reset the brainstem.
 */

#include "config.h"

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <assert.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <ucontext.h>

#include <sys/stat.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#include <list>
#include <algorithm>

#include "acpGarcia.h"
#include "acpValue.h"
/* necessary to reset brainstem mods */
#include "aStem.h"

#include "garcia-pilot.hh"
#include "pilotClient.hh"
#include "dashboard.hh"
#include "wheelManager.hh"
#include "pilotButtonCallback.hh"
#include "garciaUtil.hh"

/**
 * Prints the usage message for this daemon to stderr.
 */
static void usage(char *prog)
{
    fprintf(stderr,
	    "usage: %s [module_list]\n"
	    "  (default modules: 4 (Moto), then 2 (GP))\n"
	    "Optional:\n"
	    "  module_list An ordered list (separated by spaces) of\n"
	    "    addresses of brainstem modules you wish to reset.\n",
	    prog);
}

int main(int argc, char *argv[])
{
    int retval;
    aIOLib ioRef;
    aErr err;
    acpGarcia garcia;
    unsigned char default_modules[2] = { 4,2 };
    unsigned char *modules = default_modules;
    int modules_len = 2;
    int i;

    /* grab the modules */
    if (argc == 2 && strcmp(argv[1],"-h") == 0) {
	usage(argv[0]);
	exit(0);
    }
    else if (argc > 1) {
	modules = NULL;
	modules_len = 0;
	for (i = 0; i < argc-1; ++i) {
	    modules = (unsigned char *)realloc(modules,sizeof(char)*i);
	    modules[i] = (unsigned char)atoi(argv[i+1]);
	    ++modules_len;
	}
    }
    
    aIO_GetLibRef(&ioRef, &err);

    if (!wait_for_brainstem_link(ioRef, garcia)) {
	fprintf(stderr,
		"error: could not connect to robot %d\n",
		garcia.getNamedValue("status")->getIntVal());
	exit(-1);
    }

    retval = brainstem_reset(ioRef,modules,modules_len);

    aIO_ReleaseLibRef(ioRef, &err);

    if (modules != default_modules) {
	free(modules);
    }
    
    return retval;
}
