/*
 * Copyright (c) 2013-2016 University of Utah and the Flux Group.
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
 * Timed dd. Adds an additional timeout= argument to dd.
 *
 * Parses the args looking for timeout=%d argument which we extract from
 * the arglist. Then we fork and run a real dd process with the other params,
 * ensuring that it does not run longer than the time indicated.
 */
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <signal.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/wait.h>

/* dd to use if TDD_DD environment var is not set */
#define DEF_DD	"/bin/dd"

void
handler(int sig)
{
	return;
}

int
main(int argc, char **argv, char **envp)
{
	int i, gotit = 0, timeout = 0;
	char *ddprog;

	if (argc == 1) {
		fprintf(stderr, "Usage: tdd timeout=<sec> <dd args ...>\n");
		fprintf(stderr, "  Runs 'dd' for max of <sec> seconds\n");
		exit(1);
	}

	/*
	 * Extract any timeout= argument and patch up the arg list.
	 */
	for (i = 1; i < argc; i++) {
		if (strncmp(argv[i], "timeout=", 8) == 0) {
			char *estr, *str;

			if (gotit) {
				fprintf(stderr,
					"Only one timeout= arg allowed\n");
				exit(1);
			}
			str = strchr(argv[i], '=');
			if (str) {
				timeout = (int)strtol(str+1, &estr, 0);
				if (*estr != '\0') {
					fprintf(stderr,
						"Invalid timeout value '%s'\n",
						str+1);
					exit(1);
				}
			}
			gotit = 1;
		} else if (gotit) {
			argv[i-1] = argv[i];
		}
	}
	if (gotit) {
		argc--;
		argv[argc] = NULL;
	}

	/*
	 * Set the DD program.
	 *
	 * If the TDD_DD environment variable is set, use that
	 * otherwise use the default dd.
	 */
	ddprog = getenv("TDD_DD");
	if (ddprog == NULL) {
		ddprog = DEF_DD;
	}
	if (access(ddprog, X_OK) != 0) {
		fprintf(stderr, "Cannot execute dd program '%s', "
			"set TDD_DD env var correctly\n", ddprog);
		exit(1);
	}
	argv[0] = ddprog;
#if 0
	printf("timeout=%d, newcmd='", timeout);
	for (i = 0; i < argc; i++) {
		printf("%s%s", argv[i], (i == argc-1 ? "'" : " "));
	}
	printf("\n");
#endif

	if (timeout > 0) {
		int cpid = fork();
		/* parent */
		if (cpid) {
			struct sigaction sa;
			struct itimerval itval;
			int rv, stat = 0;

			memset(&sa, 0, sizeof(sa));
			sa.sa_handler = handler;
			sigaction(SIGALRM, &sa, NULL);

			itval.it_interval.tv_sec = 0;
			itval.it_interval.tv_usec = 0;
			itval.it_value.tv_sec = timeout;
			itval.it_value.tv_usec = 0;
			setitimer(ITIMER_REAL, &itval, NULL);

			rv = waitpid(cpid, &stat, 0);
			if (rv < 0 && errno == EINTR) {
				kill(cpid, SIGINT);
				rv = waitpid(cpid, &stat, 0);

				/* should we return 0 instead? */
				stat = 255;
			} else {
				stat = WEXITSTATUS(stat);
			}
			exit(stat);
		}
		/* child */
	}
	execve(argv[0], argv, envp);
	exit(-1);
}
