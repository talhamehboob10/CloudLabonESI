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

/* hcmdgrab - utility to obtain stored data in hcmd */

#include "hmcd.h"

int main(int argc, char **argv) {

  int usd, numbytes;
  char lbuf[256], *msg, *enttime, *curtok;
  struct sockaddr_un unixaddr;
  
  if (argc < 2 || argc > 3) {
    printf("Usage: %s <node_name>\n", argv[0]);
    return 1;
  }

  bzero(lbuf, sizeof(lbuf));

  msg = (char*)malloc(strlen(argv[1])+5);
  sprintf(msg, "GET %s", argv[1]);

  bzero(&unixaddr, sizeof(struct sockaddr_un));
  unixaddr.sun_family = AF_LOCAL;
  strcpy(unixaddr.sun_path, SOCKPATH);
  
  if ((usd = socket(AF_LOCAL, SOCK_STREAM, 0)) < 0) {
    perror("Can't create UNIX domain socket");
    return 1;
  }

  if (connect(usd, (struct sockaddr*)&unixaddr, SUN_LEN(&unixaddr)) < 0) {
    perror("Couldn't connect to hcmd");
    return 1;
  }

  if (send(usd, msg, strlen(msg)+1, 0) < 0) {
    perror("Problem sending message");
    return 1;
  }

  if ((numbytes = recv(usd, lbuf, sizeof(lbuf), 0)) > 0) {
    lbuf[numbytes-1] = '\0';
    if (!strncmp(lbuf, "NULL", 4)) {
      return 1;
    }
    enttime = strtok(lbuf, " |");
    while ((curtok = strtok(NULL, " |"))) {
      printf("%s@%s\n", curtok, enttime);
    }
  }

  return 0;
}
