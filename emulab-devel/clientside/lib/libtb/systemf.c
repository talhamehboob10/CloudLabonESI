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
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>

#include "systemf.h"

int vsystemf(const char *fmt, va_list args)
{
	char cmd_buf[1024], *cmd = cmd_buf;
	int rc, retval;

	assert(fmt != NULL);

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
		retval = system(cmd);
		if (cmd != cmd_buf) {
			free(cmd);
			cmd = NULL;
		}
	}
	else {
		retval = -1;
		errno = ENOMEM;
	}
	
	return retval;
}

int systemf(const char *fmt, ...)
{
	int retval;
	va_list args;

	va_start(args, fmt);
	retval = vsystemf(fmt, args);
	va_end(args);

	return retval;
}
