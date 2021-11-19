/*
 * Copyright (c) 2004-2011 University of Utah and the Flux Group.
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
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>

#include "popenf.h"

/*
 * Define vfork to fork. Why? Well starting at 6.X FreeBSD switched
 * its underlying pthread impl, and popen is broken in threaded apps,
 * since it uses vfork. I have no understanding of any of this, only
 * that avoiding vfork solves the problem.  We can back this change
 * out once we figure out a real solution.
 */
int vfork()
{
  return fork();
}

FILE *vpopenf(const char *fmt, const char *type, va_list args)
{
	char cmd_buf[1024], *cmd = cmd_buf;
	FILE *retval;
	int rc;

	assert(fmt != NULL);
	assert(type != NULL);

	if ((rc = vsnprintf(cmd,
			    sizeof(cmd_buf),
			    fmt,
			    args)) >= sizeof(cmd_buf)) {
		if ((cmd = malloc(rc + 1)) != NULL) {
			vsnprintf(cmd, rc + 1, fmt, args);
			cmd[rc] = '\0';
		}
	}

	if (cmd != NULL) {
		retval = popen(cmd, type);
		if (cmd != cmd_buf) {
			free(cmd);
			cmd = NULL;
		}
	}
	else {
		retval = NULL;
		errno = ENOMEM;
	}
	
	return retval;
}

FILE *popenf(const char *fmt, const char *type, ...)
{
	FILE *retval;
	va_list args;

	va_start(args, type);
	retval = vpopenf(fmt, type, args);
	va_end(args);

	return retval;
}
