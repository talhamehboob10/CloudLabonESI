/*
 * Copyright (c) 2000-2013 University of Utah and the Flux Group.
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

int	ClientLogInit(void);
int	ServerLogInit(void);
int	UploadLogInit(void);
int	MasterServerLogInit(void);
void	FrisLog(const char *fmt, ...);
void	FrisInfo(const char *fmt, ...);
void	FrisWarning(const char *fmt, ...);
void	FrisError(const char *fmt, ...);
void	FrisFatal(const char *fmt, ...);
void	FrisPwarning(const char *fmt, ...);
void	FrisPfatal(const char *fmt, ...);
