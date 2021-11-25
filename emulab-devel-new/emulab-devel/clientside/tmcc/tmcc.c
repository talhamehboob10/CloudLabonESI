/*
 * Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <sys/fcntl.h>
#include <stdio.h>
#include <errno.h>
#include <syslog.h>
#include <unistd.h>
#include <signal.h>
#ifdef __CYGWIN__
#  include <w32api/windef.h>
#  include <w32api/winbase.h>
#  include <w32api/iphlpapi.h>
  /* XXX: May no longer be required. */
  typedef _sig_func_ptr sig_t;
#endif /* __CYGWIN__ */
#include <stdarg.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <time.h>
#include <assert.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include "tmcd.h"
#include "ssl.h"
#ifndef STANDALONE
#  include "config.h"
#endif
/* 
 * XXX: This seems strange.  Unless something modifies this file, the
 * next "if" statment will always be true.
 */
#undef  BOSSNODE
#if !defined(BOSSNODE)
#  include <resolv.h>
#endif
#include <setjmp.h>
#ifdef linux
#define strlcpy strncpy
#endif

#ifndef KEYFILE
#  define KEYFILE		"/etc/emulab.pkey"
#endif

/*
 * We search a couple of dirs for the bossnode file.
 */
static char *bossnodedirs[] = {
	"/etc/testbed",
	"/etc/emulab",
	"/etc/rc.d/testbed",
	"/usr/local/etc/testbed",
	"/usr/local/etc/emulab",
	0
};

/*
 * Need to try several ports cause of firewalling. 
 */
static int portlist[] = {
	TBSERVER_PORT,
	TBSERVER_PORT2,
};
/* Locals */
static int	numports = sizeof(portlist)/sizeof(int);
static int	debug = 0;
static char    *logfile = NULL;
static int	do_proxy_retries = 1;

/* Forward decls */
static int	getbossnode(char **, int *);
static int	doudp(char *, int, struct in_addr, int);
static int	dotcp(char *, int, struct in_addr);
static int	dounix(char *, int, char *);
static void	beudproxy(char *, struct in_addr, char *);
static void	beidproxy(struct in_addr, int, struct in_addr, char *);
static void	beproxy(int, int, struct in_addr, char *);
static int	dooutput(int, char *, int);
static int	rewritecommand(char *, char *, char **);

char *usagestr = 
 "usage: tmcc [options] <command>\n"
 " -d		   Turn on debugging\n"
 " -s server	   Specify a tmcd server to connect to\n"
 " -p portnum	   Specify a port number to connect to\n"
 " -v versnum	   Specify a version number for tmcd\n"
 " -n vnodeid	   Specify the vnodeid\n"
 " -k keyfile	   Specify the private keyfile\n"
 " -u		   Use UDP instead of TCP\n"
 " -l path	   Use named unix domain socket instead of TCP\n"
 " -t timeout	   Timeout waiting for the controller.\n"
 " -x path	   Be a unix domain proxy listening on the named socket\n"
 " -X ip:port	   Be an inet domain proxy listening on the given IP:port\n"
 " -o logfile      Specify log file name for -x option\n"
 " -f datafile     Extra stuff to send to tmcd (tcp mode only)\n"
 " -i              Do not use SSL protocol\n"
 " -T              Use the TPM for SSL negotiation\n"
 " -R              Do not retry failed proxy request forwarding\n"
 "\n";

void
usage()
{
	fprintf(stderr, "%s", usagestr);
	exit(1);
}

/*
 * We cannot let remote nodes hang, but they can be slow. If we get connected
 * we give it an extra timeout, and if we make any progress at all, keep
 * giving it extra timeouts.
 */
static int connected = 0;
static int progress  = 0;
static int waitfor   = 0;
static sigjmp_buf progtimo;

/*
 * do{tcp,udp} all open a socket for sending a request and getting a reply.
 * If we timeout during one of those functions, that socket will be left open.
 * For a normal use of tmcc, we will immediately exit if a timeout happens so
 * this is not a problem. However, in the proxy case, a timeout is not fatal,
 * so we will have to close the socket. Note that the proxy does not use
 * dounix, so we do not augment that function.
 */
volatile int reqsock = -1;

static void
tooktoolong(void)
{
	static int	lastprogress = 0;

	/* If we made progress, keep going (reset timer too) */
	if (connected && progress > lastprogress) {
		lastprogress = progress;
		alarm(waitfor);
		return;
	}

	siglongjmp(progtimo, 1);
}

/*
 * We do not want to fail outright if we cannot resolve. Lets retry
 * a few times. This is imperfect of course; the caller should deal
 * with this, but most cases can be dealt with more easily here.
 */
struct hostent *
gethostbyname_retry(const char *name)
{
	int		count = 5;

	while (count) {
		struct hostent *he = gethostbyname(name);
		if (he)
			return he;
		if (debug) {
			herror("gethostbyname failed");
		}
		count--;
		if (count)
			sleep(5);
	}
	return (struct hostent *) NULL;
}

struct hostent *
gethostbyaddr_retry(const void *addr, socklen_t len, int type)
{
	int		count = 5;

	while (count) {
		struct hostent *he = gethostbyaddr(addr, len, type);
		if (he)
			return he;
		if (debug) {
			herror("gethostbyaddr failed");
		}
		count--;
		if (count)
			sleep(5);
	}
	return (struct hostent *) NULL;
}
#define gethostbyname gethostbyname_retry
#define gethostbyaddr gethostbyaddr_retry

int
main(int argc, char **argv)
{
	int			n, ch;
	struct hostent		*he;
	struct in_addr		serverip;
	char			buf[MAXTMCDPACKET], *bp;
	FILE			*fp;
	volatile int		useudp    = 0;
	char			* volatile unixpath = NULL;
	char			*bossnode = NULL;
	int			version   = CURRENT_VERSION;
	char			*vnodeid  = NULL;
	char			*keyfile  = NULL;
	char			*privkey  = NULL;
	char			*proxypath= NULL;
	struct in_addr		proxyaddr;
	int			proxyport = 0;
	char			*datafile = NULL;

	while ((ch = getopt(argc, argv, "v:s:p:un:t:k:x:X:l:do:if:TR")) != -1)
		switch(ch) {
		case 'd':
			debug++;
			break;
		case 'p':
			portlist[0] = atoi(optarg);
			numports    = 1;
			break;
		case 's':
			bossnode = optarg;
			break;
		case 'n':
			vnodeid = optarg;
			break;
		case 'k':
			keyfile = optarg;
			break;
		case 'v':
			version = atoi(optarg);
			break;
		case 't':
			waitfor = atoi(optarg);
			break;
		case 'u':
			useudp = 1;
			break;
		case 'x':
			proxypath = optarg;
			break;
		case 'X':
		{
			char *ap, *pp = optarg;
			ap = strsep(&pp, ":");
			if (!inet_aton(*ap ? ap : "127.0.0.1", &proxyaddr))
				usage();
			proxyport = pp ? atoi(pp) : TBSERVER_PORT+1;
			break;
		}
		case 'l':
			unixpath  = optarg;
			break;
		case 'o':
			logfile  = optarg;
			break;
		case 'f':
			datafile  = optarg;
			break;
		case 'i':
#ifdef WITHSSL
			nousessl = 1;
#endif
			break;
		case 'T':
			usetpm = 1;
			break;
		case 'R':
			do_proxy_retries = 0;
			break;
		default:
			usage();
		}

	argv += optind;
	argc -= optind;
	if (!(proxypath || proxyport) && (argc < 1 || argc > 5)) {
		usage();
	}
	if (unixpath && proxypath) {
		fprintf(stderr,
			"Cannot be both proxy server (-x) and client (-l)\n");
		usage();
	}

	if (proxypath && proxyport) {
		fprintf(stderr,
			"Cannot be both unix (-x) and inet (-X) domain proxy\n");
		usage();
	}

	if (useudp && datafile) {
		fprintf(stderr,
			"Cannot send a file (-f) in UDP mode (-u)\n");
		usage();
	}

	if (unixpath && (keyfile || bossnode)) {
		fprintf(stderr,
			"You may not use the -k or -s with the -l option\n");
		usage();
	}
	if (usetpm && nousessl) {
		fprintf(stderr, "You cannot use -T and -i together\n");
		usage();
	}
#ifndef	WITHSSL
	if (usetpm) {
		fprintf(stderr,
		    "You used -T but compiled without WITHSSL.  Bailing!\n");
		exit(1);
	}
#endif
	if( (! unixpath) && (0==access("/etc/emulab/emulab-privkey", R_OK)) ) {
		keyfile = strdup("/etc/emulab/emulab-privkey");
	}
#ifdef WITHSSL
	/*
	 * Brutal hack for inner elab; see rc.inelab.
	 */
	if (getenv("TMCCNOSSL") != NULL)
		nousessl = 1;
#endif
	if (!bossnode) {
		int	port = 0;
		
		getbossnode(&bossnode, &port);
		/* In other words, do not override command line port spec! */
		if (port && numports > 1) {
			portlist[0] = port;
			numports    = 1;
		}
	}

	he = gethostbyname(bossnode);
	if (he)
		memcpy((char *)&serverip, he->h_addr, he->h_length);
	else {
		fprintf(stderr, "gethostbyname(%s) failed\n", bossnode); 
		exit(1);
	}

	/*
	 * Handle built-in "bossinfo" command
	 */
	if (!(proxypath || proxyport) &&
	    argc > 0 && (strcmp(argv[0], "bossinfo") == 0)) {
		printf("%s %s\n", bossnode, inet_ntoa(serverip));
		exit(0);
	}

	/*
	 * Grab the key. Its not an error if we do not find it.
	 */
	if (keyfile) {
		/* Well, if one was specifed it has to exist. */
		if (access(keyfile, R_OK) < 0) {
			perror("keyfile"); 
			exit(1);
		}
	}
	else
		keyfile = KEYFILE;

	if ((fp = fopen(keyfile, "r")) != NULL) {
	    if (fgets(buf, sizeof(buf), fp)) {
		if ((bp = strchr(buf, '\n')))
		    *bp = '\0';
		privkey = strdup(buf);
	    }
	    fclose(fp);
	}

	/*
	 * Build up the command request string.
	 */
	buf[0] = '\0';
	
	/* Tack on vnodeid */
	if (vnodeid) {
		if (proxypath || proxyport) {
			sprintf(&buf[strlen(buf)], "PROXYFOR=%s ", vnodeid);
		}
		else {
			sprintf(&buf[strlen(buf)], "VNODEID=%s ", vnodeid);
		}
	}

	/* Tack on privkey */
	if (privkey) {
		sprintf(&buf[strlen(buf)], "PRIVKEY=%s ", privkey);
	}

	/*
	 * If specified udp with unixpath, then pass through a UDP flag
	 * to the proxy, which will do what it thinks is appropriate.
	 */
	if (useudp && unixpath) {
		sprintf(&buf[strlen(buf)], "USEUDP=1 ");
		useudp = 0;
	}

	/*
	 * In proxy mode ...
	 */
	if (proxypath) {
		beudproxy(proxypath, serverip, buf);
		exit(0);
	}
	if (proxyport != 0) {
		beidproxy(proxyaddr, proxyport, serverip, buf);
		exit(0);
	}

	/* Tack on version number */
	sprintf(&buf[strlen(buf)], "VERSION=%d ", version);

	/*
	 * Since we've gone through a getopt() pass, argv[0] is now the
	 * first argument
	 */
	n = strlen(buf);
	while (argc && n < sizeof(buf)) {
		n += snprintf(&buf[n], sizeof(buf) - (n + 1), "%s ", argv[0]);
		argc--;
		argv++;
	}
	if (n >= sizeof(buf)) {
		fprintf(stderr, "Command too large!\n");
		exit(-1);
	}
	if (!useudp && datafile) {
		int len;
		
		if ((fp = fopen(datafile, "r")) == NULL) {
			perror("accessing datafile");
			exit(-1);
		}
		len = fread(&buf[n], sizeof(char), sizeof(buf) - (n + 1), fp);
		if (!len) {
			perror("reading datafile");
			exit(-1);
		}
		n += len;
		fclose(fp);
	}
	buf[n] = '\0';

	/*
	 * When a timeout is requested, setup the alarm and die if it triggers.
	 */
	if (waitfor) {
		if (sigsetjmp(progtimo, 1) != 0) {
			fprintf(stderr,
				"Timed out because there was no progress!\n");
			exit(-1);
		}
		signal(SIGALRM, (sig_t)tooktoolong);
		alarm(waitfor);
	}

	if (useudp)
		n = doudp(buf, fileno(stdout), serverip, portlist[0]);
	else if (unixpath)
		n = dounix(buf, fileno(stdout), unixpath);
	else
		n = dotcp(buf, fileno(stdout), serverip);
	if (waitfor)
		alarm(0);
	fflush(stderr);
	exit(n);
}

/*
 * Find the bossnode name if one was not specified on the command line.
 */
static int
getbossnode(char **bossnode, int *portp)
{
#ifdef BOSSNODE
	*bossnode = strdup(BOSSNODE);
	return 0;
#else
	FILE		*fp;
	char		buf[BUFSIZ], **cp = bossnodedirs, *bp;

	/*
	 * Brutal hack for inner elab; see rc.inelab.
	 */
	if ((bp = getenv("BOSSNAME")) != NULL) {
		strcpy(buf, bp);
		
		/*
		 * Look for port spec
		 */
		if ((bp = strchr(buf, ':'))) {
			*bp++  = '\0';
			*portp = atoi(bp);
		}
		*bossnode = strdup(buf);
		return 0;
	}
	
	/*
	 * Search for the file.
	 */
	while (*cp) {
		sprintf(buf, "%s/%s", *cp, BOSSNODE_FILENAME);

		if (access(buf, R_OK) == 0)
			break;
		cp++;
	}
	if (*cp) {
		if ((fp = fopen(buf, "r")) != NULL) {
			if (fgets(buf, sizeof(buf), fp)) {
				if ((bp = strchr(buf, '\n')))
					*bp = '\0';
				fclose(fp);
				/*
				 * Look for port spec
				 */
				if ((bp = strchr(buf, ':'))) {
					*bp++  = '\0'; 
					*portp = atoi(bp);
				}
				*bossnode = strdup(buf);
				return 0;
			}
			fclose(fp);
		}
	}
#ifdef __CYGWIN__
/*
 * Cygwin discourages the use of resolv.conf and provides no mechanism to 
 * automatically generate it.  We instead use of the "IP Helper" 
 * Windows API functions to get the IP address of the DNS server. This host
 * is assumed to also be the boss node.
 *
 * A good chunk of the code here was lifted from examples in the API reference.
 */
	{
		FIXED_INFO *pFixedInfo;
		struct in_addr dnsAddr;
		struct hostent *he;
		char *pIPAddrStr;
		unsigned long ulOutBufLen;
		int dwRetVal;

		/* Typical Windows trick for right-sizing the output buffer. */
		pFixedInfo = (FIXED_INFO *) malloc(sizeof (FIXED_INFO));
		ulOutBufLen = sizeof (FIXED_INFO);
		if (GetNetworkParams(pFixedInfo, &ulOutBufLen) == 
		    ERROR_BUFFER_OVERFLOW) {
			free(pFixedInfo);
			pFixedInfo = (FIXED_INFO *) malloc(ulOutBufLen);
		}

		/* Actually perform the call to get network configuration. */
		if ((dwRetVal = GetNetworkParams(pFixedInfo, &ulOutBufLen)) != 
		    NO_ERROR) {
			fprintf(stderr, 
				"GetNetworkParams failed with error %08x\n", 
				dwRetVal);
			if (pFixedInfo) {
				free(pFixedInfo);
			}
		} else {
			/* 
			 * The IP address of the DNS server is presented as a 
			 * decimal dot notation string. Convert it and do a 
			 * reverse lookup to get the hostname.
			 */
			pIPAddrStr = pFixedInfo->DnsServerList.IpAddress.String;
			if (pIPAddrStr && inet_aton(pIPAddrStr, &dnsAddr)) {
				he = gethostbyaddr((char *)&dnsAddr,
						   sizeof(struct in_addr), 
						   AF_INET);
				if (he && he->h_name) {
					*bossnode = strdup(he->h_name);
				} else {
				  herror("gethostbyaddr failed");
				}
			} else {
			  fprintf(stderr,
				  "No value returned for DNS server or can't" 
				  " convert to network byte representation.\n");
			}

			if (pFixedInfo) {
				free(pFixedInfo);
				pFixedInfo = NULL;
			}
		}

		if (!bossnode) {
			*bossnode = strdup("UNKNOWN");
		}
		return 0;
	}
#else
	{
		/*
		 * Nameserver goo 
		 */
		struct hostent	*he;
		res_init();
		he = gethostbyaddr((char *)&_res.nsaddr.sin_addr,
				   sizeof(struct in_addr), AF_INET);
		if (he && he->h_name) 
			*bossnode = strdup(he->h_name);
		else
			*bossnode = strdup("UNKNOWN");
		return 0;
	}
#endif /* __CYGWIN__ */
	*bossnode = strdup("UNKNOWN");
	return 0;
#endif /* BOSSNODE */
}

/*
 * TCP version, which uses ssl if compiled in.
 */
static int
dotcp(char *data, int outfd, struct in_addr serverip)
{
	int			n, sock, cc;
	struct sockaddr_in	name;
	char			*bp, buf[MYBUFSIZE];
	int			redirectlimit = 5;
	
#ifdef  WITHSSL
	if (!nousessl && tmcd_client_sslinit()) {
		printf("SSL initialization failed!\n");
		return -1;
	}
#endif
 again:
	while (1) {
		for (n = 0; n < numports; n++) {
			/* Create socket from which to read. */
			sock = socket(AF_INET, SOCK_STREAM, 0);
			if (sock < 0) {
				perror("creating stream socket");
				return -1;
			}

			/* XXX see comment on declaration of reqsock */
			reqsock = sock;

			/* Create name. */
			name.sin_family = AF_INET;
			name.sin_addr   = serverip;
			name.sin_port   = htons(portlist[n]);

			if (CONNECT(sock, (struct sockaddr *) &name,
				    sizeof(name)) == 0) {
				goto foundit;
			}
			if (errno == ECONNRESET || errno == ETIMEDOUT
			    || errno == EAGAIN || errno == EINTR) {
				fprintf(stderr,"retrying failed connect (%s)\n",
					strerror(errno));
			}
			else if (errno != ECONNREFUSED) {
				perror("connecting stream socket");
				CLOSE(sock);
				reqsock = -1;
				return -1;
			}
			CLOSE(sock);
			reqsock = -1;
		}
		if (debug) 
			fprintf(stderr,
				"Connection to TMCD refused. Waiting ...\n");
		sleep(10);
	}
 foundit:
	connected = 1;

	n = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, (void *)&n, sizeof(n)) < 0) {
		perror("setsockopt SO_KEEPALIVE");
		goto bad;
	}

	/*
	 * Write the command to the socket and wait for the response.
	 */
	bp = data;
	n  = strlen(data);
	while (n) {
		if ((cc = WRITE(sock, bp, n)) <= 0) {
			if (cc < 0) {
				if (errno == EAGAIN || errno == ECONNRESET
				    || errno == EINTR || errno == EPIPE) {
					if (bp == data) {
						fprintf(stderr,
							"write error (nothing "
							"written): %s; retrying\n",
							strerror(errno));
						CLOSE(sock);
						reqsock = -1;
						goto again;
					}
					else {
						fprintf(stderr,
							"write error (sent %ld "
							" bytes): %s, not "
							" retrying\n",
							bp-data,strerror(errno));
					}
				}
				else
				    perror("Writing to socket");
				goto bad;
			}
			fprintf(stderr, "write aborted");
			goto bad;
		}
		bp += cc;
		n  -= cc;
	}
	if (! isssl) {
		/*
		 * Send EOF to server so it knows it has all the data.
		 * SSL mode takes care of this for us by making sure the
		 * the server gets all the data when it reads. Still, its
		 * a terrible way to do this. 
		 */
		shutdown(sock, SHUT_WR);
	}

	while (1) {
		if ((cc = READ(sock, buf, sizeof(buf) - 1)) <= 0) {
			if (cc < 0) {
				perror("Reading from socket");
				goto bad;
			}
			break;
		}
		if (strncmp(buf, "REDIRECT=", strlen("REDIRECT=")) == 0) {
			struct hostent	*he;

			redirectlimit--;
			if (redirectlimit == 0) {
				fprintf(stderr, "Redirect limit reached\n");
				goto bad;
			}
			buf[cc] = '\0';
			if (rewritecommand(buf, data, &bp)) {
				goto bad;
			}
			he = gethostbyname(bp);
			if (he)
				memcpy((char *)&serverip,
				       he->h_addr, he->h_length);
			else {
				fprintf(stderr,
					"gethostbyname(%s) failed\n", buf); 
				goto bad;
			}
			CLOSE(sock);
			reqsock = -1;
			goto again;
		}
		progress += cc;
		if (dooutput(outfd, buf, cc) < 0)
			goto bad;
	}
	CLOSE(sock);
	reqsock = -1;
	return 0;
 bad:
	CLOSE(sock);
	reqsock = -1;
	return -1;
}

/*
 * Not very robust, send a single request, read a single reply. 
 */
static int
doudp(char *data, int outfd, struct in_addr serverip, int portnum)
{
	int			sock, n, cc;
	struct sockaddr_in	name, client;
	socklen_t		length;
	char			buf[MYBUFSIZE];

	/* Create socket from which to read. */
	sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0) {
		perror("creating dgram socket");
		return -1;
	}

	/* XXX see comment on declaration of reqsock */
	reqsock = sock;

	/* Create name. */
	name.sin_family = AF_INET;
	name.sin_addr   = serverip;
	name.sin_port   = htons(portnum);

	/*
	 * Write the command to the socket and wait for the response
	 */
	n  = strlen(data);
	cc = sendto(sock, data, n, 0, (struct sockaddr *)&name, sizeof(name));
	if (cc != n) {
		if (cc < 0)
			perror("Writing to socket");
		else
			fprintf(stderr, "short write (%d != %d)\n", cc, n);
		close(sock);
		reqsock = -1;
		return -1;
	}
	connected = 1;

	length = sizeof(client);
	cc = recvfrom(sock, buf, sizeof(buf) - 1, 0,
		      (struct sockaddr *)&client, &length);
	if (cc < 0) {
		perror("Reading from socket");
		close(sock);
		reqsock = -1;
		return -1;
	}
	close(sock);
	reqsock = -1;
	progress += cc;
	if (dooutput(outfd, buf, cc) < 0)
		return -1;
	return 0;
}

/*
 * Unix domain version.
 */
static int
dounix(char *data, int outfd, char *unixpath)
{
	int			n, sock, cc, length;
	struct sockaddr_un	sunaddr;
	char			*bp, buf[MYBUFSIZE];

	sunaddr.sun_family = AF_UNIX;
	strlcpy(sunaddr.sun_path, unixpath, sizeof(sunaddr.sun_path));
	length = SUN_LEN(&sunaddr)+1;
#if !defined(__CYGWIN__) && !defined(linux)
	sunaddr.sun_len = length;
#  endif /* __CYGWIN__ */

	/* Create socket from which to read. */
	sock = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sock < 0) {
		perror("creating stream socket");
		return -1;
	}

	/*
	 * Retry if the unixpath does not exist. Caller must use timeout option.
	 */
	while (1) {
		if (connect(sock, (struct sockaddr *) &sunaddr, length) == 0)
			break;

		if (errno != ENOENT && errno != ECONNREFUSED) {
			perror("connecting unix domain socket");
			close(sock);
			return -1;
		}

		if (debug) 
			fprintf(stderr,
				"Connection to TMCD refused. Waiting ...\n");
		sleep(1);
	}
	connected = 1;

	/*
	 * Write the command to the socket and wait for the response.
	 */
	bp = data;
	n  = strlen(data);
	while (n) {
		if ((cc = write(sock, bp, n)) <= 0) {
			if (cc < 0) {
				perror("Writing to socket");
				goto bad;
			}
			fprintf(stderr, "write aborted");
			goto bad;
		}
		bp += cc;
		n  -= cc;
	}

	while (1) {
		if ((cc = read(sock, buf, sizeof(buf) - 1)) <= 0) {
			if (cc < 0) {
				perror("Reading from socket");
				goto bad;
			}
			break;
		}
		progress += cc;
		if (dooutput(outfd, buf, cc) < 0)
			goto bad;
	}
	close(sock);
	return 0;
 bad:
	close(sock);
	return -1;
}

/*
 * Be a proxy. Basically, listen for requests from the localhost and
 * forward. At the moment this is strictly for the benefit of jailed
 * environments on FreeBSD, hence we use a unix domain socket to provide
 * the security (the socket is visible to the jail only).
 *
 * Note that only TCP traffic goes through the proxy. The jailed tmcc
 * can speak directly to tmcd over udp since it never returns anything
 * sensitive that way.
 */
static void
beudproxy(char *localpath, struct in_addr serverip, char *partial)
{
	int			sock;
	socklen_t		length;
	struct sockaddr_un	sunaddr;
	
	/* don't let a client kill us */
	signal(SIGPIPE, SIG_IGN);

	sock = socket(AF_UNIX, SOCK_STREAM, 0);
	if (sock < 0) {
		perror("creating unix domain socket");
		exit(-1);
	}

	unlink(localpath);
	memset(&sunaddr, 0, sizeof(sunaddr));
	sunaddr.sun_family = AF_UNIX;
	strlcpy(sunaddr.sun_path, localpath, sizeof(sunaddr.sun_path));
	length = SUN_LEN(&sunaddr) + 1;
#if !defined(__CYGWIN__) && !defined(linux)
	sunaddr.sun_len = length;
#endif /* __CYGWIN__ */
	if (bind(sock, (struct sockaddr *)&sunaddr, length) < 0) {
		perror("binding unix domain socket");
		exit(-1);
	}
	chmod(localpath, S_IRWXU|S_IRWXG|S_IRWXO);

	if (listen(sock, 5) < 0) {
		perror("listen on unix domain socket");
		exit(-1);
	}

	beproxy(sock, -1, serverip, partial);
}

static void
beidproxy(struct in_addr ip, int port, struct in_addr serverip, char *partial)
{
	int			tcpsock, udpsock;
	socklen_t		length;
	struct sockaddr_in	name;

	/* don't let a client kill us */
	signal(SIGPIPE, SIG_IGN);

	/* get a TCP socket */
	tcpsock = socket(AF_INET, SOCK_STREAM, 0);
	if (tcpsock < 0) {
		perror("creating TCP socket");
		exit(-1);
	}

	name.sin_family = AF_INET;
	name.sin_addr = ip;
	name.sin_port = htons(port);
	length = sizeof(name);
	if (bind(tcpsock, (struct sockaddr *)&name, length) < 0) {
		perror("binding TCP socket");
		exit(-1);
	}

	if (listen(tcpsock, 5) < 0) {
		perror("listen on TCP socket");
		exit(-1);
	}

	/* and a UDP socket */
	udpsock = socket(AF_INET, SOCK_DGRAM, 0);
	if (udpsock < 0) {
		perror("creating UDP socket");
		exit(-1);
	}

	name.sin_family = AF_INET;
	name.sin_addr = ip;
	name.sin_port = htons(port);
	length = sizeof(name);
	if (bind(udpsock, (struct sockaddr *)&name, length) < 0) {
		perror("binding UDP socket");
		exit(-1);
	}
	beproxy(tcpsock, udpsock, serverip, partial);
}

static int proxymode = 0;

static void
beproxy(int tcpsock, int udpsock, struct in_addr serverip, char *partial)
{
	int			newsock, cc;
	struct sockaddr_in	client;
	socklen_t		length;
	char			command[MAXTMCDPACKET], buf[MAXTMCDPACKET];
	char			*bp, *cp;
	fd_set			rfds;
	int			fdcount = 0;
	int			retries = 0;
	
	proxymode = 1;
	if (logfile) {
		int	fd;

		/*
		 * Detach, but do not daemonize. The caller tracks the
		 * pid and kills us. Needs to be fixed at some point ...
		 */
		if ((fd = open("/dev/null", O_RDONLY, 0)) < 0) {
			perror("Could not open /dev/null");
			exit(-1);
		}
		(void)dup2(fd, STDIN_FILENO);
		if (fd != STDIN_FILENO)
			(void)close(fd);
		
		if ((fd = open(logfile, O_WRONLY|O_CREAT|O_APPEND,0640)) < 0) {
			perror("Could not open logfile");
			exit(-1);
		}
		(void)dup2(fd, STDOUT_FILENO);
		(void)dup2(fd, STDERR_FILENO);
		if (fd > STDERR_FILENO)
			(void)close(fd);
	}

	FD_ZERO(&rfds);
	if (tcpsock >= 0) {
		FD_SET(tcpsock, &rfds);
		fdcount = tcpsock;
	}
	if (udpsock >= 0) {
		FD_SET(udpsock, &rfds);
		if (udpsock > fdcount)
			fdcount = udpsock;
	}
	fdcount++;

	/*
	 * Wait for messages.
	 */
	while (1) {
		int	rval;
		volatile int usingudp = 0;
		fd_set	fds;
		
		fds = rfds;
		rval = select(fdcount, &fds, NULL, NULL, NULL);
		if (rval < 0) {
			if (errno == EINTR)
				continue;
			perror("proxy: select failed");
			exit(1);
		}

		/*
		 * Yes, we only handle one request per loop, even if both
		 * FDs were ready.  This is potentially unfair to UDP
		 * clients but there really shouldn't be much UDP traffic.
		 */
		if (tcpsock >= 0 && FD_ISSET(tcpsock, &fds)) {
			retries = 0;
			/*
			 * Accept and read the message
			 */
			length  = sizeof(client);
			newsock = accept(tcpsock, (struct sockaddr *)&client,
					 &length);
			if (newsock < 0) {
				perror("proxy: accepting connection");
				continue;
			}
			cc = read(newsock, buf, sizeof(buf) - 1);
		} else if (udpsock >= 0 && FD_ISSET(udpsock, &fds)) {
			retries = 0;
			/*
			 * Read the message and create a reply socket
			 */
			length = sizeof(client);
			cc = recvfrom(udpsock, buf, sizeof(buf) - 1, 0,
				      (struct sockaddr *)&client, &length);
			if (cc > 0) {
				newsock = socket(AF_INET, SOCK_DGRAM, 0);
				if (newsock < 0) {
					perror("creating UDP reply socket");
					continue;
				}
				if (connect(newsock,
					    (struct sockaddr *)&client,
					    length) < 0) {
					perror("connecting UDP reply socket");
					close(newsock);
					continue;
				}
				usingudp = 1;
			} else
				newsock = -1;
		} else {
			fprintf(stderr,
				"proxy: select returned with no fd!\n");
			sleep(5);
			continue;
		}

		/*
		 * Check read
		 */
		if (cc <= 0) {
			if (cc < 0)
				perror("proxy: reading request");
			fprintf(stderr, "proxy: connection aborted\n");
			if (newsock >= 0)
				close(newsock);
			continue;
		}
		buf[cc] = '\0';

		/*
		 * Do not allow PRIVKEY or VNODEID options to be specified
		 * by the proxy user. 
		 */
		strcpy(command, partial);
		bp = cp = buf;
		while ((bp = strsep(&cp, " ")) != NULL) {
			if (strstr(bp, "PRIVKEY=") ||
			    strstr(bp, "VNODEID="))
				continue;
			if (strstr(bp, "USEUDP=1")) {
				usingudp = 1;
				continue;
			}
			strcat(command, bp);
			strcat(command, " ");
		}

		if (debug) {
			fprintf(stderr, "%sREQ: %s\n",
				usingudp ? "UDP " : "TCP ", command);
			fflush(stderr);
		}

		/*
		 * Set a timeout for the server-side operation
		 */
	retry:
		if (retries) {
			int count = 10;
			/*
			 * If we are retrying, check to see if we have a
			 * new incoming request, and quit retrying if we
			 * do.  In the udp case, we cannot know if the
			 * client has given up on us.  In the tcp case,
			 * we can see if we get a 0-length read and then
			 * give up, so we expand the select rfds to
			 * handle that.  Note, either a new tcp OR udp
			 * request will scuttle our retry attempts, due
			 * to the nature of this loop!
			 */
			fprintf(stderr, "Request failed, will retry (%d)!\n",
				retries);
			rval = 0;
			while (!rval && count--) {
				fd_set retry_rfds;
				int retry_fdcount = 0;
				struct timeval notime = { 1, 0 };
				struct timespec timerem = { 0, 0 };
				FD_ZERO(&retry_rfds);
				if (tcpsock >= 0) {
					FD_SET(tcpsock, &retry_rfds);
					retry_fdcount = tcpsock;
				}
				if (udpsock >= 0) {
					FD_SET(udpsock, &retry_rfds);
					if (udpsock > retry_fdcount)
						retry_fdcount = udpsock;
				}
				if (!usingudp && newsock >= 0) {
					FD_SET(newsock, &retry_rfds);
					if (newsock > retry_fdcount)
						retry_fdcount = newsock;
				}
				retry_fdcount++;

				rval = select(retry_fdcount, &retry_rfds,
					      NULL, NULL, &notime);
				if (rval > 0) {
					if ((tcpsock >= 0
					     && FD_ISSET(tcpsock, &retry_rfds))
					    || (udpsock >= 0
						&& FD_ISSET(udpsock, &retry_rfds))) {
						fprintf(stderr,
							"new request; halting "
							" proxy retry (%d)\n",
							retries);
						close(newsock);
						retries = 0;
						continue;
					}
				}
				timerem.tv_nsec = notime.tv_usec * 1000;
				nanosleep(&timerem,NULL);
			}
			if (retries == 0) {
				if (newsock >= 0)
					close(newsock);
				continue;
			}
		}
		if (waitfor) {
			if (sigsetjmp(progtimo, 1) != 0) {
				fprintf(stderr,
					"Server %s request timeout on: %s\n",
					usingudp ? "UDP" : "TCP", command);
				if (do_proxy_retries)
					goto retry_init;
				if (newsock >= 0)
					close(newsock);
				if (reqsock >= 0) {
					fprintf(stderr,
						"Closing service socket %d\n",
						reqsock);
					if (usingudp)
						close(reqsock);
					else
						CLOSE(reqsock);
					reqsock = -1;
				}
				continue;
			}
			signal(SIGALRM, (sig_t)tooktoolong);
			alarm(waitfor);
		}
		if (usingudp)
			rval = doudp(command, newsock, serverip, portlist[0]);
		else
			rval = dotcp(command, newsock, serverip);
		if (waitfor)
			alarm(0);
		if (rval < 0 && debug) {
			fprintf(stderr, "Request failed!\n");
			fflush(stderr);
		}
		if (rval < 0 && do_proxy_retries) {
		retry_init:
			++retries;
			goto retry;
		}
		if (newsock >= 0)
			close(newsock);
	}
}

/*
 * Little helper to write tmcd response to output. 
 */
static int
dooutput(int fd, char *buf, int len)
{
	int		cc, count = len;

	if (debug) {
		if (proxymode)
			fprintf(stderr, "REP: ");
		fwrite(buf, 1, len, stderr);
	}
	
	while (count) {
		if ((cc = write(fd, buf, count)) <= 0) {
			if (cc < 0) {
				perror("Writing to output stream");
				return -1;
			}
			fprintf(stderr, "write to socket aborted");
			return -1;
		}
		buf   += cc;
		count -= cc;
	}
	return len;
}

static int
rewritecommand(char *redirect, char *command, char **server)
{
	char	*bp;
	char	buf[MAXTMCDPACKET];
			
	bp = strchr(redirect, '\n');
	if (bp)
		*bp = '\0';
	bp = strchr(redirect, '=');
	if (!bp)
		return -1;
	bp++;
	*server = bp;

	bp = strchr(bp, ':');
	if (!bp)
		return 0;
	*bp++ = '\0';

	sprintf(buf, "VNODEID=%s ", bp);

	bp = command;
	if (strncmp(bp, "VNODEID=", strlen("VNODEID=")) == 0) {
		bp = strchr(bp, ' ');
		if (!bp)
			return -1;
		bp++;
	}
	strncat(buf, bp, sizeof(buf) - strlen(buf) - 1);
	strcpy(command, buf);
	fprintf(stderr, "%s, %s\n", command, *server);
	return 0;
}
