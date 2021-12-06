/*
 * Copyright (c) 2000-2002 University of Utah and the Flux Group.
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

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <utmp.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <time.h>

#define UTMP_FILE "/var/log/wtmp"

int main() {

  int nbytes;
  struct utmp u;
  FILE *utfd;

  printf ("sizeof(struct utmp): %d\n", sizeof(struct utmp));

  if ((utfd = fopen(UTMP_FILE, "r")) < 0) {
    perror("Couldn't open utmp file");
    exit(1);
  }
  /*
  if (lseek(utfd, (off_t)0, SEEK_END) < 1) {
    perror("Can't seek to end");
    exit(1);
  }
  
  printf("File pos after SEEK_END: %ld\n", lseek(utfd, 0, SEEK_CUR));
  */

  if (fseek(utfd, -sizeof(struct utmp), SEEK_END) < 0) {
    perror("Can't rewind into file!");
    exit (1);
  }

  do {
    printf("File pos after SEEK_CUR: %ld\n", ftell(utfd));
    nbytes = fread(&u, 1, sizeof(struct utmp), utfd);

    if (nbytes < sizeof(struct utmp)) {
      perror("Problem reading from file");
      fprintf(stderr, "Nbytes: %d\n", nbytes);
      fprintf(stderr, "problem reading utmp structure - truncated.\n");
      exit(1);
    }
    else {
      printf("ut_line:  %s\n", u.ut_line);
      printf("ut_name:  %s\n", u.ut_name);
      printf("ut_host:  %s\n", u.ut_host);
      printf("ut_time:  %s\n", ctime(&u.ut_time));
    }
  } while (fseek(utfd, -2*sizeof(struct utmp), SEEK_CUR) == 0 &&
           !ferror(utfd));
  fclose(utfd);
  return 0;
}
