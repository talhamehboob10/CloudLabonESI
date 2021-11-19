/*
 * Copyright (c) 2012-2014 University of Utah and the Flux Group.
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
 * Replacement for suid perl. Installed setuid, and just execs the
 * script/binary in the magic directory with the same name as us.
 * We run the script/binary with the following constraints:
 *
 * EUID is 0, UID is not changed.
 * GID and EGID list is not changed.
 * Path is set to a standard value
 * A couple of environment variables are purged.
 *
 * The latter two are not things that suidperl would do, but is something
 * that our scripts routinely do.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>
#include <sys/param.h>
#include <sys/stat.h>
#include "config.h"

#define SUIDDIR	TBROOT "/suidbin/"

char *safepath[] = {
	TBROOT "/bin",
	TBROOT "/sbin",
	TBROOT "/cgi-bin",
	"/bin",
	"/sbin",
	"/usr/bin",
	"/usr/sbin",
	"/usr/local/bin",
	"/usr/local/sbin"
};

char *badvars[] = {
	"IFS=", "CDPATH=", "ENV=", "BASH_ENV="
};

static int debug = 0;

static void
sanedir(char *dir)
{
	struct stat sb;
	char *rpath;

	if ((rpath = malloc(PATH_MAX)) == NULL) {
		fprintf(stderr, "no memory!\n");
		exit(2);
	}
	if (realpath(dir, rpath) == NULL) {
		perror(dir);
		exit(1);
	}
	if (strncmp(rpath, TBROOT, strlen(TBROOT)) != 0) {
		fprintf(stderr, "%s: must be in %s\n", dir, TBROOT);
		exit(1);
	}

	if (stat(rpath, &sb) != 0) {
		perror(dir);
		exit(1);
	}
	if (sb.st_uid != 0 ||
	    !S_ISDIR(sb.st_mode) || (sb.st_mode & (S_IWGRP|S_IWOTH)) != 0) {
		fprintf(stderr, "%s: must be root-owned, unwritable dir\n",
			dir);
		exit(1);
	}

	free(rpath);
}

static char **
saneenviron(char **oenvp, char *path)
{
	int i, ni, j;
	char **nenvp;
	int havepath = 0;

	for (i = 0; oenvp != NULL && oenvp[i] != NULL; i++)
		if (!strncmp(oenvp[i], "PATH=", 5))
			havepath++;
	if (!havepath)
		i++;

	nenvp = calloc(i, sizeof(char *));
	if (nenvp == NULL)
		return NULL;

	for (i = ni = 0; oenvp != NULL && oenvp[i] != NULL; i++) {
		for (j = 0; j < sizeof(badvars)/sizeof(badvars[0]); j++)
			if (!strncmp(oenvp[i], badvars[j], strlen(badvars[j])))
				break;
		if (j < sizeof(badvars)/sizeof(badvars[0]))
			continue;
		if (!strncmp(oenvp[i], "PATH=", 5)) {
			nenvp[ni++] = path;
			continue;
		}
		nenvp[ni++] = oenvp[i];
	}
	if (!havepath)
		nenvp[ni] = path;

	return nenvp;
}

int
main(int argc, char **argv)
{
	char *cp, *name = argv[0];
	char *exepath, *path, **envp;
	int i, len;
	extern char **environ;

	if (geteuid()) {
		fprintf(stderr, "%s: not running as root; not suid?\n", name);
		exit(1);
	}

	/* Check the state of the SUIDDIR */
	sanedir(SUIDDIR);

	if ((cp = strrchr(name, '/')) == NULL)
		cp = name;
	else
		cp++;

	assert(strlen(cp) > 0);
	if ((exepath = malloc(strlen(SUIDDIR) + strlen(cp) + 1)) == NULL) {
	nomem:
		fprintf(stderr, "%s: no memory!\n", name);
		exit(2);
	}
	strcpy(exepath, SUIDDIR);
	strcat(exepath, cp);

	len = 0;
	for (i = 0; i < sizeof(safepath)/sizeof(safepath[0]); i++)
		len += strlen(safepath[i]) + 1;
	if ((path = malloc(5+len)) == NULL)
		goto nomem;
	strcpy(path, "PATH=");
	cp = path + 5;
	for (i = 0; i < sizeof(safepath)/sizeof(safepath[0]); i++) {
		strcpy(cp, safepath[i]);
		cp += strlen(safepath[i]);
		*cp++ = ':';
	}
	if (cp != path)
		*--cp = '\0';

	if ((envp = saneenviron(environ, path)) == NULL)
		goto nomem;

	argv[0] = exepath;

	if (debug) {
		printf("Command: '%s'\n", exepath);
		printf("Args:\n");
		for (i = 0; argv[i] != NULL; i++)
			printf("  '%s'\n", argv[i]);
		if (envp) {
			printf("Env:\n");
			for (i = 0; envp[i] != NULL; i++)
				printf("  '%s'\n", envp[i]);
		}
		exit(0);
	}

	execve(exepath, argv, envp);
	perror(exepath);
}
