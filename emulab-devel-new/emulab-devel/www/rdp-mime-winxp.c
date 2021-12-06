/* rdp-mime-winxp.exe - Exe wrapper for a Perl script, making
 *                        it acceptable as a file-type opener.
 *
 * Compile with gcc -o rdp-mime-winxp.{exe,c}
 *
 * Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
#include <stdlib.h>
#include <stdio.h>

int main(int argc, char **argv)
{
  if (argc != 2)
    printf("Usage: rdp-mime-winxp.exe pcxxx.tbrdp\n");
  else
  {
    /* Just pass the file argument on to the Perl script. */
    argv[0] = "rdp-mime-winxp.pl";
    execvp(argv[0], argv);       /* Shouldn't return. */
    perror("rdp-mime-winxp.pl");
  }
  sleep(5);
  return 1;
}
