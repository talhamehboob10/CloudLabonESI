/*
 * Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
 * Logging and debug routines.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <assert.h>
#include <errno.h>
#include "decls.h"

#ifndef LOG_TESTBED
#define LOG_TESTBED	LOG_USER
#endif

static int usesyslog = 1;

/*
 * There is really no point in the client using syslog, but its nice
 * to use the same log functions either way.
 */
int
ClientLogInit(void)
{
	usesyslog = 0;
	return 0;
}

int
ServerLogInit(void)
{
	if (debug) {
		usesyslog = 0;
		return 1;
	}

	openlog("frisbeed", LOG_PID, LOG_TESTBED);

	return 0;
}

int
UploadLogInit(void)
{
	if (debug) {
		usesyslog = 0;
		return 1;
	}

	openlog("frisuploadd", LOG_PID, LOG_TESTBED);

	return 0;
}

int
MasterServerLogInit(void)
{
	if (debug) {
		usesyslog = 0;
		return 1;
	}

	openlog("mfrisbeed", LOG_PID, LOG_TESTBED);

	return 0;
}

void
FrisInfo(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	if (!usesyslog) {
		fputs(buf, stderr);
		fputc('\n', stderr);
	}
	else
		syslog(LOG_INFO, "%s", buf);
}

void
FrisLog(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	if (!usesyslog) {
		fputs(buf, stderr);
		fputc('\n', stderr);
	}
	else
		syslog(LOG_INFO, "%s", buf);
}

void
FrisWarning(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fputc('\n', stderr);
		fflush(stderr);
	}
	else
		vsyslog(LOG_WARNING, fmt, args);
	       
	va_end(args);
}

void
FrisError(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fputc('\n', stderr);
		fflush(stderr);
	}
	else
		vsyslog(LOG_ERR, fmt, args);
	       
	va_end(args);
}

void
FrisFatal(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fputc('\n', stderr);
		fflush(stderr);
	}
	else
		vsyslog(LOG_ERR, fmt, args);
	       
	va_end(args);
	exit(-1);
}

void
FrisPwarning(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	FrisWarning("%s: %s", buf, strerror(errno));
}

void
FrisPfatal(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	FrisFatal("%s: %s", buf, strerror(errno));
}
