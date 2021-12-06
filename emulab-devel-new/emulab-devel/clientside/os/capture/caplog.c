/*
 * Copyright (c) 2000-2008 University of Utah and the Flux Group.
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

#include <sys/param.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <strings.h>
#include <syslog.h>
#include <errno.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>
#include <assert.h>
#include <paths.h>
#include <sys/file.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <setjmp.h>
#include <netdb.h>
#ifndef __linux__
#include <rpc/rpc.h>
#endif
#ifdef WITHSSL
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif /* WITHSSL */
#include "config.h"
#include "capdecls.h"

/*
 *  Configurable things.
 */
#define ACLNAME		"%s/%s.acl"

char		*Progname;
char		*Aclname;
char		*nodeid;
char		*server;
int		debug = 0;
int		tailmode = 0;
int		offset;
int		sockfd, portnum = LOGGERPORT;
logger_t	logreq;

void		loadAcl(const char * filename);
void		usage(void);
void		ConnectToServer(void);
int		Write(void * data, int size);
int		Read(void * data, int size);

#ifdef  WITHSSL
SSL_CTX		*ctx;
SSL		*sslCon;
int		initializedSSL = 0;
int		usingSSL = 0;
char		*certString = NULL;

int
initializessl(void)
{
	static int initializedSSL = 0;
	
	if (initializedSSL)
		return 0;
	
	SSL_load_error_strings();
	SSL_library_init();
	
	ctx = SSL_CTX_new( SSLv23_method() );
	if (ctx == NULL) {
		fprintf(STDERR, "Failed to create context.");
		return 1;
	}
	initializedSSL = 1;
	return 0;
}
#endif /* WITHSSL */ 

int
main(int argc, char **argv)
{
	char		strbuf[MAXPATHLEN], *newstr();
	int		op, wfd, cc;
	extern int	optind;
	extern char	*optarg;

	if ((Progname = rindex(argv[0], '/')))
		Progname++;
	else
		Progname = *argv;

	/*
	 * The first argument has to be the +/- line option. Leave it
	 * someone else to generalize.
	 */
	if (argc > 1) {
	    if ((argv[1][0] == '+' || argv[1][0] == '-') &&
		isdigit(argv[1][1])) {
		offset = atoi(argv[1]);
		optind++;
	    }
	}

	while ((op = getopt(argc, argv, "da:p:f")) != EOF) {
		switch (op) {
		case 'd':
			debug++;
			break;
		case 'a':
			Aclname = optarg;
			break;
		case 'f':
			tailmode++;
			break;
		case 'p':
			portnum = atoi(optarg);
			break;
		}
	}
	argc -= optind;
	argv += optind;

	if (!Aclname && argc != 1)
	    usage();

	if (!Aclname) {
	    (void) snprintf(strbuf, sizeof(strbuf), ACLNAME, ACLPATH, argv[0]);
	    Aclname = strdup(strbuf);
	}
	if (argc)
	    nodeid = argv[0];
	
	loadAcl(Aclname);
	ConnectToServer();
	wfd = fileno(stdout);

	/*
	 * Spit whatever get forever.
	 */
	while (1) {
	    if ((cc = Read(strbuf, sizeof(strbuf))) <= 0) {
		if (cc < 0) {
		    perror("reading data from server");
		    exit(-1);
		}
		exit(0);
	    }
	    if (write(wfd, strbuf, cc) != cc) {
		exit(-1);
	    }
	}
	return 0;
}

/*
 * Contact the server and handshake.
 */
void
ConnectToServer(void)
{
    struct sockaddr_in	name;
    struct hostent	*he;
    capret_t		capret;
    int			cc;

    name.sin_family = AF_INET;
    name.sin_port   = htons(portnum);

    he = gethostbyname(server);   
    if (!he) {
	fprintf(stderr, "Unknown hostname %s: %s\n",
		server, hstrerror(h_errno));
	exit(-1);
    }

    /* Additonal options to pass to the server */
    if (tailmode)
	logreq.flags |= CAPLOGFLAG_TAIL;
    if (offset)
	logreq.offset = offset;

#ifdef WITHSSL
    if (usingSSL)
	initSSL();
#endif
    
    memcpy((char *)&name.sin_addr, he->h_addr, he->h_length);
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
	perror("allocating socket");
	exit(-1);
    }
    if (connect(sockfd, (struct sockaddr *)&name, sizeof(name)) < 0) {
	close(sockfd);
	perror("connecting to server");
	exit(-1);
    }
    
#ifdef WITHSSL
    if (usingSSL)
	sslConnect();
#endif

    if ((cc = Write(&logreq, sizeof(logreq))) != sizeof(logreq)) {
	if (cc < 0)
	    perror("writing authentication info to server");
	else
	    fprintf(stderr, "Error writing authentication info!\n");
	exit(-1);
    }
    if ((cc = Read(&capret, sizeof(capret))) != sizeof(capret)) {
	if (cc < 0)
	    perror("reading authentication reply from server");
	else
	    fprintf(stderr, "Error reading authentication reply!\n");
	exit(-1);
    }
    switch(capret) {
    case CAPOK: 
	return;
    case CAPNOPERM:
	fprintf(stderr, "You do not have permission to view logfile!\n");
	break;
    case CAPERROR:
	fprintf(stderr, "Error trying to view logfile!\n");
	break;
    default:
	fprintf(stderr, "Unknown return code 0x%02x.\n", (unsigned int)capret);
	break;
    }
    close(sockfd);
    exit(-1);
}

/*
 * Load the contents of the acl file.
 */
void
loadAcl(const char * filename)
{
    FILE	*aclFile = fopen(filename, "r");
    char	b1[256];
    char	b2[256];

    if (!aclFile) {
	fprintf(stderr, "Error opening ACL file '%s' - %s\n",
		filename, strerror(errno));
	exit(-1);
    }
    bzero(&logreq, sizeof(logreq));

    while (fscanf(aclFile, "%s %s\n", b1, b2) != EOF) {
	if (strcmp(b1, "host:") == 0 || strcmp(b1, "server:") == 0) {
	    server = strdup(b2);
	}
	if (strcmp(b1, "nodeid:") == 0 || strcmp(b1, "node_id:") == 0) {
	    nodeid = strdup(b2);
	}
	else if (strcmp(b1, "keylen:") == 0) {
	    logreq.secretkey.keylen = atoi(b2);
	}
	else if (strcmp(b1, "key:") == 0 || strcmp(b1, "keydata:") == 0) {
	    strcpy(logreq.secretkey.key, b2);
#ifdef WITHSSL
	}
	else if (strcmp(b1, "ssl-server-cert:") == 0) {
	    if (debug)
		printf("Using SSL to connect to capture.\n");
	    certString = strdup(b2);
	    usingSSL++;
#endif
	}
	else {
	    /* fprintf(stderr, "Ignored unknown ACL: %s %s\n", b1, b2); */
	}
    }
    fclose(aclFile);

    strcpy(logreq.node_id, nodeid);
    if (!logreq.secretkey.keylen)
	logreq.secretkey.keylen = strlen(logreq.secretkey.key);

    if (!server || !strlen(logreq.secretkey.key)) {
	fprintf(stderr, "Incomplete ACL\n");
	exit(-1);
    }
}

int
Write(void * data, int size)
{
#ifdef	WITHSSL
    if (usingSSL)
	return SSL_write(ssl, data, size);
    else
#endif
	return write(sockfd, data, size);
}

int
Read(void * data, int size)
{
#ifdef	WITHSSL
    if (usingSSL)
	return SSL_read(ssl, data, size);
    else
#endif
	return read(sockfd, data, size);
}

/*
 *  Display proper usage / error message and exit.
 */
void
usage(void)
{
	fprintf(stderr, "usage: %s "
		"[-/+line] [-f] [-p port] [-a aclfile] machine\n",
		Progname);
	exit(1);
}

