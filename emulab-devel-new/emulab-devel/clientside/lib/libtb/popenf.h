/*
 * Copyright (c) 2004 University of Utah and the Flux Group.
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
 * @file popenf.h
 */

#ifndef _popenf_h
#define _popenf_h

#include <stdio.h>
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * The varargs version of popenf.
 *
 * @param fmt The printf(3)-like format for the command to execute.
 * @param type The direction of data flow for the pipe: "r" for reading and "w"
 * for writing.
 * @param args The arguments for the format.
 * @return The initialized FILE object that is connected to the other process
 * or NULL if there was an error.
 */
FILE *vpopenf(const char *fmt, const char *type, va_list args);

/**
 * A version of popen(3) that executes a command produced from a format.
 *
 * @code
 * @endcode
 *
 * @param fmt The printf(3)-like format for the command to execute.
 * @param type The direction of data flow for the pipe: "r" for reading and "w"
 * for writing.
 * @param ... The arguments for the format.
 * @return The initialized FILE object that is connected to the other process
 * or NULL if there was an error.
 */
FILE *popenf(const char *fmt, const char *type, ...);

#ifdef __cplusplus
}
#endif

#endif
