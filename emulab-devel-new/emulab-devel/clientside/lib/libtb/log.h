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
 * Log defs.
 */
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

int	loginit(int usesyslog, char const *name);
void	logsyslog(void);
void	logflush(void);
void	info(const char *fmt, ...);
void	warning(const char *fmt, ...);
void	error(const char *fmt, ...);
void	errorc(const char *fmt, ...);
void	fatal(const char *fmt, ...) __attribute__((noreturn));
void	pwarning(const char *fmt, ...);
void	pfatal(const char *fmt, ...) __attribute__((noreturn));

#ifdef __cplusplus
}
#endif
