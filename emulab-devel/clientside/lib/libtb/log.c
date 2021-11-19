/*
 * Copyright (c) 2000-2007 University of Utah and the Flux Group.
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
#include <fcntl.h>
#include <unistd.h>
#include <syslog.h>
#include <assert.h>
#include <errno.h>
#include "config.h"
#include "log.h"

static int	usesyslog = 0;
static char const   *filename;
#define LOG_IDENT   "Testbed"

/*
 * Initialize.  If slog is non-zero use syslog with name (if provided)
 * as the identifier.  If slog is zero, then name (if set) is the name of
 * a logfile to which stdout and stderr are redirected.
 */
int
loginit(int slog, char const *name)
{
	if (slog) {
		usesyslog = 1;
		if (! name)
			name = LOG_IDENT;
		openlog(name, LOG_PID, LOG_TESTBED);
		return 0;
	}

	usesyslog = 0;

	if (name) {
		int	fd;

		if ((fd = open(name, O_RDWR|O_CREAT|O_APPEND, 0644)) != -1) {
			(void)dup2(fd, STDOUT_FILENO);
			(void)dup2(fd, STDERR_FILENO);
			if (fd > 2)
				(void)close(fd);
		}
		filename = name;
	}
	return 0;
}

/*
 * Switch to syslog; caller has already opened syslog connection.
 */
void
logsyslog(void)
{
	usesyslog = 1;
}

/*
 * Flush any buffered log output
 */
void
logflush(void)
{
	if (!usesyslog)
		fflush(stderr);
}

void
info(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	if (!usesyslog) {
		fputs(buf, stderr);
	}
	else
		syslog(LOG_INFO, "%s", buf);
}

void
warning(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fflush(stderr);
	}
	else
		vsyslog(LOG_WARNING, fmt, args);
	       
	va_end(args);
}

void
error(const char *fmt, ...)
{
	va_list args;

	va_start(args, fmt);
	if (!usesyslog) {
		vfprintf(stderr, fmt, args);
		fflush(stderr);
	}
	else
		vsyslog(LOG_ERR, fmt, args);
	       
	va_end(args);
}

void
errorc(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	error("%s : %s\n", buf, strerror(errno));
}

void
fatal(const char *fmt, ...)
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
pwarning(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	warning("%s : %s\n", buf, strerror(errno));
}

void
pfatal(const char *fmt, ...)
{
	va_list args;
	char	buf[BUFSIZ];

	va_start(args, fmt);
	vsnprintf(buf, sizeof(buf), fmt, args);
	va_end(args);

	fatal("%s : %s", buf, strerror(errno));
}
