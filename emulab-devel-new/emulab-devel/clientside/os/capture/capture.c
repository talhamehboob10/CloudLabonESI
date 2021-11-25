/*
 * Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
 * Testbed note:  This code has developed over the last several
 * years in RCS.  This is an import of the current version of
 * capture from the /usr/src/utah RCS repository into the testbed,
 * with some new hacks to port it to Linux.
 *
 * - dga, 10/10/2000
 */

/*
 * A LITTLE hack to record output from a tty device to a file, and still
 * have it available to tip using a pty/tty pair.
 */

#define SAFEMODE
	
#ifndef USESOCKETS
#undef WITH_TELNET
#endif

#include <sys/param.h>

#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <strings.h>
#include <syslog.h>
#include <termios.h>
#include <errno.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>
#include <assert.h>
#include <paths.h>

#include <sys/param.h>
#include <sys/file.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <signal.h>
#include <sys/ioctl.h>
#ifdef USESOCKETS
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/resource.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <setjmp.h>
#include <netdb.h>
#include <sys/wait.h>
#ifndef __linux__
#include <rpc/rpc.h>
#endif
#ifdef WITHSSL
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif /* WITHSSL */
#include "config.h"
#endif /* USESOCKETS */
#include "capdecls.h"
#ifndef BOSSNODE
#define BOSSNODE "boss"
#endif

#define geterr(e)	strerror(e)

void quit(int);
void reinit(int);
void newrun(int);
void terminate(int);
void cleanup(void);
void capture(void);
void deadchild(int);

void usage(void);
void warning(char *format, ...);
void die(char *format, ...);
void dolog(int level, char *format, ...);

int val2speed(int val);
int rawmode(char *devname, int speed);
int netmode(int isrestart);
int progmode(int isrestart);
int xenmode(int isrestart);
void writepid(void);
void createkey(void);
int handshake(void);
#ifdef USESOCKETS
int clientconnect(void);
#endif
int handleupload(void);

#ifdef __linux__
#define _POSIX_VDISABLE '\0'
#define revoke(tty)	(0)
#endif

#ifndef LOG_TESTBED
#define LOG_TESTBED	LOG_USER
#endif

/*
 *  Configurable things.
 */
#define PIDNAME		"%s/%s.pid"
#define LOGNAME		"%s/%s.log"
#define RUNNAME		"%s/%s.run"
#define TTYNAME		"%s/%s"
#define PTYNAME		"%s/%s-pty"
#define ACLNAME		"%s/%s.acl"
#define DEVNAME		"%s/%s"
#define BUFSIZE		4096
#define DROP_THRESH	(32*1024)
#define MAX_UPLOAD_SIZE	(32 * 1024 * 1024)
#define DEFAULT_CERTFILE PREFIX"/etc/capture.pem"
#define DEFAULT_CLIENT_CERTFILE PREFIX"/etc/client.pem"
#define DEFAULT_CAFILE	PREFIX"/etc/emulab.pem"

char 	*Progname;
char 	*Pidname;
char	*Logname;
char	*Runname;
char	*Ttyname;
char	*Ptyname;
char	*Devname;
char	*Machine;
int	logfd = -1, runfd, devfd = -1, ptyfd = -1, xsfd = -1;
int	hwflow = 0, speed = B9600, debug = 0, runfile = 0, standalone = 0;
int     foreground = 0;
int     nologfile = 0;
int	stampinterval = -1;
int	stamplast = 0;
sigset_t actionsigmask;
sigset_t allsigmask;
int	 powermon = 0;
char   **programargv;
#ifndef  USESOCKETS
#define relay_snd 0
#define relay_rcv 0
#define remotemode 0
#define programmode 0
#define xendomain 0
#define retryinterval 0
#define nomodpath 0
#define insecure 0
#else
char		  *Bossnode = BOSSNODE;
struct sockaddr_in Bossaddr;
char		  *Aclname;
int		   serverport = SERVERPORT;
int		   sockfd, tipactive, portnum, relay_snd, relay_rcv;
int		   remotemode;
int		   programmode;
char		  *xendomain;
int		   retryinterval = 5000;
int		   maxretries = 0;
int		   nomodpath = 0;
int		   maxfailures = 10;
int		   insecure = 0;
int		   failures;
int		   upportnum = -1, upfd = -1, upfilefd = -1;
char		   uptmpnam[64];
size_t		   upfilesize = 0;
struct sockaddr_in tipclient;
struct sockaddr_in relayclient;
struct in_addr	   relayaddr;
secretkey_t	   secretkey;
char		   ourhostname[MAXHOSTNAMELEN];
int		   needshake;
gid_t		   tipgid;
uid_t		   tipuid;
volatile int	   progpid = -1;
char		  *uploadCommand;

int		   docircbuf = 0;
void		   initcircbuf();
void		   clearcircbuf();
void		   addtocircbuf(const char *bp, int cc);
void		   dumpcircbuf();

int	Devproto;
#define PROTO_RAW	1
#define PROTO_TELNET	2

#ifdef WITH_TELNET
static inline void proto_telnet_send_to_client(char *buf, int cc);
static inline void proto_telnet_send_to_device(char *buf, int cc);
static void proto_telnet_init(void);
#endif

#ifdef  WITHSSL

SSL_CTX * ctx;
SSL * sslCon;
SSL * sslRelay;
SSL * sslUpload;

int initializedSSL = 0;

const char * certfile = NULL;
const char * cafile = NULL;

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
		dolog( LOG_NOTICE, "Failed to create context.");
		return 1;
	}
	
#ifndef PREFIX
#define PREFIX
#endif
	
	if (relay_snd) {
		if (!cafile) { cafile = DEFAULT_CAFILE; }
		if (SSL_CTX_load_verify_locations(ctx, cafile, NULL) == 0) {
			die("cannot load verify locations");
		}
		
		/*
		 * Make it so the client must provide authentication.
		 */
		SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER |
				   SSL_VERIFY_FAIL_IF_NO_PEER_CERT, 0);
		
		/*
		 * No session caching! Useless and eats up memory.
		 */
		SSL_CTX_set_session_cache_mode(ctx, SSL_SESS_CACHE_OFF);
		
		if (!certfile) { certfile = DEFAULT_CLIENT_CERTFILE; }
		if (SSL_CTX_use_certificate_file( ctx,
						  certfile,
						  SSL_FILETYPE_PEM ) <= 0) {
			dolog(LOG_NOTICE, 
			      "Could not load %s as certificate file.",
			      certfile );
			return 1;
		}
		
		if (SSL_CTX_use_PrivateKey_file( ctx,
						 certfile,
						 SSL_FILETYPE_PEM ) <= 0) {
			dolog(LOG_NOTICE, 
			      "Could not load %s as key file.",
			      certfile );
			return 1;
		}
	}
	else {
		if (!certfile) { certfile = DEFAULT_CERTFILE; }
		
		if (SSL_CTX_use_certificate_file( ctx,
						  certfile,
						  SSL_FILETYPE_PEM ) <= 0) {
			dolog(LOG_NOTICE, 
			      "Could not load %s as certificate file.",
			      certfile );
			return 1;
		}
		
		if (SSL_CTX_use_PrivateKey_file( ctx,
						 certfile,
						 SSL_FILETYPE_PEM ) <= 0) {
			dolog(LOG_NOTICE, 
			      "Could not load %s as key file.",
			      certfile );
			return 1;
		}
	}
		
	initializedSSL = 1;

	return 0;
}

int
sslverify(SSL *ssl, char *requiredunit)
{
	X509		*peer = NULL;
	char		cname[256], unitname[256];
	
	assert(ssl != NULL);
	assert(requiredunit != NULL);

	if (SSL_get_verify_result(ssl) != X509_V_OK) {
		dolog(LOG_NOTICE,
		      "sslverify: Certificate did not verify!\n");
		return -1;
	}
	
	if (! (peer = SSL_get_peer_certificate(ssl))) {
		dolog(LOG_NOTICE, "sslverify: No certificate presented!\n");
		return -1;
	}

	/*
	 * Grab stuff from the cert.
	 */
	X509_NAME_get_text_by_NID(X509_get_subject_name(peer),
				  NID_organizationalUnitName,
				  unitname, sizeof(unitname));

	X509_NAME_get_text_by_NID(X509_get_subject_name(peer),
				  NID_commonName,
				  cname, sizeof(cname));
	X509_free(peer);
	
	/*
	 * On the server, things are a bit more difficult since
	 * we share a common cert locally and a per group cert remotely.
	 *
	 * Make sure common name matches.
	 */
	if (strcmp(cname, BOSSNODE)) {
		dolog(LOG_NOTICE,
		      "sslverify: commonname mismatch: %s!=%s\n",
		      cname, BOSSNODE);
		return -1;
	}

	/*
	 * If the node is remote, then the unitname must match the type.
	 * Simply a convention. 
	 */
	if (strcmp(unitname, requiredunit)) {
		dolog(LOG_NOTICE,
		      "sslverify: unitname mismatch: %s!=Capture Server\n",
		      unitname);
		return -1;
	}
	
	return 0;
}
#endif /* WITHSSL */ 
#endif /* USESOCKETS */

int
main(int argc, char **argv)
{
	char strbuf[MAXPATHLEN], *newstr();
	char *logpath = LOGPATH, *aclpath = ACLPATH;
	int op, i;
	struct sigaction sa;
	extern int optind;
	extern char *optarg;
#ifdef  USESOCKETS
	struct sockaddr_in name;
#endif

	if ((Progname = rindex(argv[0], '/')))
		Progname++;
	else
		Progname = *argv;

	while ((op = getopt(argc, argv, "rds:Hb:ip:c:T:aonu:v:PmMLCl:X:R:y:AI")) != EOF)
		switch (op) {
#ifdef	USESOCKETS
#ifdef  WITHSSL
		case 'c':
		        certfile = optarg;
			break;
#endif  /* WITHSSL */
		case 'C':
		        docircbuf = 1;
			break;
		case 'b':
			Bossnode = optarg;
			break;

		case 'p':
			serverport = atoi(optarg);
			break;

		case 'I':
			insecure = 1;
			break;

		case 'i':
			standalone = 1;
			break;

		case 'm':
			remotemode = 1;
			break;

		case 'M':
			programmode = 1;
			break;
		case 'X':
			xendomain = optarg;
			break;
		case 'R':
			retryinterval = atoi(optarg);
			/*
			 * XXX Not less than 100ms. This is mostly just a
			 * heuristic to catch people who think the value
			 * is in seconds rather than milliseconds.
			 */
			if (retryinterval < 100) {
				fprintf(stderr,
					"Retry interval is measured in ms, "
					"NOT seconds; must be >= 100\n");
				usage();
			}
			break;
		case 'y':
			maxretries = atoi(optarg);
			break;
		case 'A':
			nomodpath = 1;
			break;
#endif /* USESOCKETS */
		case 'H':
			++hwflow;
			break;

		case 'd':
			debug++;
			break;

		case 'f':
			foreground++;
			break;

		case 'r':
			runfile++;
			break;

		case 's':
			if ((i = atoi(optarg)) == 0 ||
			    (speed = val2speed(i)) == 0)
				usage();
			break;
		case 'n':
			nologfile = 1;
			break;
		case 'l':
			logpath = optarg;
			aclpath = optarg;
			break;
		case 'L':
			stamplast = 1;
			break;
		case 'T':
			stampinterval = atoi(optarg);
			if (stampinterval < 0)
				usage();
			break;
		case 'P':
			powermon = 1;
			break;
#ifdef  WITHSSL
		case 'a':
			relay_snd = 1;
			break;
			
		case 'o':
			relay_rcv = 1;
			break;
			
		case 'u':
			uploadCommand = optarg;
			break;

		case 'v':
			cafile = optarg;
			break;
#endif
		}

	argc -= optind;
	argv += optind;

	if (!(programmode || xendomain) && argc != 2)
		usage();

	if (!(debug || foreground) && daemon(0, 0))
		die("Could not daemonize");

	Machine = argv[0];
	programargv = argv;

	(void) snprintf(strbuf, sizeof(strbuf), PIDNAME, logpath, argv[0]);
	Pidname = newstr(strbuf);
	(void) snprintf(strbuf, sizeof(strbuf), LOGNAME, logpath, argv[0]);
	Logname = newstr(strbuf);
	(void) snprintf(strbuf, sizeof(strbuf), RUNNAME, logpath, argv[0]);
	Runname = newstr(strbuf);
	(void) snprintf(strbuf, sizeof(strbuf), TTYNAME, TIPPATH, argv[0]);
	Ttyname = newstr(strbuf);
	(void) snprintf(strbuf, sizeof(strbuf), PTYNAME, TIPPATH, argv[0]);
	Ptyname = newstr(strbuf);
	if (remotemode || programmode) {
		strcpy(strbuf, argv[1]);
	}
	else if (xendomain)
		strcpy(strbuf, xendomain);
	else if (nomodpath)
		strcpy(strbuf, argv[1]);
	else
		(void) snprintf(strbuf, sizeof(strbuf),
				DEVNAME, DEVPATH, argv[1]);
	Devname = newstr(strbuf);

	openlog(Progname, LOG_PID, LOG_TESTBED);
	dolog(LOG_NOTICE, "starting");

	/*
	 * We process the "action" signals sequentially, there are just
	 * too many interdependencies.  We block em while we shut down too.
	 */
	sigemptyset(&actionsigmask);
	sigaddset(&actionsigmask, SIGHUP);
	sigaddset(&actionsigmask, SIGUSR1);
	sigaddset(&actionsigmask, SIGUSR2);
	if (programmode) 
		sigaddset(&actionsigmask, SIGCHLD);
	allsigmask = actionsigmask;
	sigaddset(&allsigmask, SIGINT);
	sigaddset(&allsigmask, SIGTERM);
	memset(&sa, 0, sizeof sa);
	sa.sa_handler = quit;
	sa.sa_mask = allsigmask;
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	if (!relay_snd) {
		sa.sa_handler = reinit;
		sa.sa_mask = actionsigmask;
		sigaction(SIGHUP, &sa, NULL);
	}
	if (runfile) {
		sa.sa_handler = newrun;
		sigaction(SIGUSR1, &sa, NULL);
	}
	sa.sa_handler = terminate;
	sigaction(SIGUSR2, &sa, NULL);
	if (programmode) {
		sa.sa_handler = deadchild;
		sigaction(SIGCHLD, &sa, NULL);
	}
	
#ifdef HAVE_SRANDOMDEV
	srandomdev();
#else
	srand(time(NULL));
#endif
	
	/*
	 * Open up run/log file, console tty, and controlling pty.
	 */
	if (runfile) {
		unlink(Runname);
		
		if ((runfd = open(Runname,O_WRONLY|O_CREAT|O_APPEND,0600)) < 0)
			die("%s: open: %s", Runname, geterr(errno));
		if (fchmod(runfd, 0640) < 0)
			die("%s: fchmod: %s", Runname, geterr(errno));
	}
#ifdef  USESOCKETS
	/*
	 * Verify the bossnode and stash the address info
	 */
	if (!standalone) {
		struct hostent *he;

		he = gethostbyname(Bossnode);
		if (he == 0) {
			die("gethostbyname(%s): %s",
			    Bossnode, hstrerror(h_errno));
		}
		memcpy ((char *)&Bossaddr.sin_addr, he->h_addr, he->h_length);
		Bossaddr.sin_family = AF_INET;
		Bossaddr.sin_port   = htons(serverport);
	}

	(void) snprintf(strbuf, sizeof(strbuf), ACLNAME, aclpath, Machine);
	Aclname = newstr(strbuf);
	
	/*
	 * Create and bind our socket.
	 */
	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sockfd < 0)
		die("socket(): opening stream socket: %s", geterr(errno));

	i = 1;
	if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR,
		       (char *)&i, sizeof(i)) < 0)
		die("setsockopt(): SO_REUSEADDR: %s", geterr(errno));
	
	/* Create wildcard name. */
	name.sin_family = AF_INET;
	if (insecure) {
		inet_aton("127.0.0.1", &name.sin_addr);
	}
	else {
		name.sin_addr.s_addr = INADDR_ANY;
	}
	name.sin_port = 0;
	if (bind(sockfd, (struct sockaddr *) &name, sizeof(name)))
		die("bind(): binding stream socket: %s", geterr(errno));

	/* Find assigned port value and print it out. */
	i = sizeof(name);
	if (getsockname(sockfd, (struct sockaddr *)&name, (unsigned int *)&i))
		die("getsockname(): %s", geterr(errno));
	portnum = ntohs(name.sin_port);

	if (listen(sockfd, 1) < 0)
		die("listen(): %s", geterr(errno));

	if (gethostname(ourhostname, sizeof(ourhostname)) < 0)
		die("gethostname(): %s", geterr(errno));

	if (docircbuf) {
		initcircbuf();
	}

	createkey();
	dolog(LOG_NOTICE, "Ready! Listening on TCP port %d", portnum);

	if (relay_snd) {
		struct sockaddr_in sin;
		struct hostent *he;
		secretkey_t key;
		char *port_idx;
		int port;

		if ((port_idx = strchr(argv[0], ':')) == NULL)
			die("%s: bad format, expecting 'host:port'", argv[0]);
		*port_idx = '\0';
		port_idx += 1;
		if (sscanf(port_idx, "%d", &port) != 1)
			die("%s: bad port number", port_idx);
		he = gethostbyname(argv[0]);
		if (he == 0) {
			die("gethostbyname(%s): %s",
			    argv[0], hstrerror(h_errno));
		}
		bzero(&sin, sizeof(sin));
		memcpy ((char *)&sin.sin_addr, he->h_addr, he->h_length);
		sin.sin_family = AF_INET;
		sin.sin_port = htons(port);

		if ((ptyfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
			die("socket(): %s", geterr(errno));
		if (connect(ptyfd, (struct sockaddr *)&sin, sizeof(sin)) < 0)
			die("connect(): %s", geterr(errno));
		snprintf(key.key, sizeof(key.key), "RELAY %d", portnum);
		key.keylen = strlen(key.key);
		if (write(ptyfd, &key, sizeof(key)) != sizeof(key))
			die("write(): %s", geterr(errno));
#ifdef  WITHSSL
		initializessl();
		sslRelay = SSL_new(ctx);
		if (!sslRelay)
			die("SSL_new()");
		if (SSL_set_fd(sslRelay, ptyfd) <= 0)
			die("SSL_set_fd()");
		if (SSL_connect(sslRelay) <= 0)
			die("SSL_connect()");
		if (sslverify(sslRelay, "Capture Server"))
			die("SSL connection did not verify");
#endif
		if (fcntl(ptyfd, F_SETFL, O_NONBLOCK) < 0)
			die("fcntl(O_NONBLOCK): %s", geterr(errno));
		tipactive = 1;
	}

	if (relay_rcv) {
		struct hostent *he;

		he = gethostbyname(argv[1]);
		if (he == 0) {
			die("gethostbyname(%s): %s",
			    argv[1], hstrerror(h_errno));
		}
		memcpy ((char *)&relayaddr, he->h_addr, he->h_length);
	}
#else
	if ((ptyfd = open(Ptyname, O_RDWR)) < 0)
		die("%s: open: %s", Ptyname, geterr(errno));
#endif
	
	if (!(relay_snd || nologfile)) {
		if ((logfd = open(Logname,O_WRONLY|O_CREAT|O_APPEND,0640)) < 0)
			die("%s: open: %s", Logname, geterr(errno));
		if (chmod(Logname, 0640) < 0)
			die("%s: chmod: %s", Logname, geterr(errno));
	}
	
	writepid();
	if (!relay_rcv) {
#ifdef  USESOCKETS
		/*
		 * For these modes, we keep trying until they are successful.
		 * This mimics the behavior if the connection/program/domain
		 * dies later and we auto-restart.
		 *
		 * Note that progmode only attempts a restart "maxfailures"
		 * times before it dies. This prevents infinite retries due
		 * to things like a bad command line argument.
		 *
		 * Also for progmode, we increase the retry interval
		 * additively on each failure, resetting on success.
		 */
		int isrestart = -1;
	retry:
		isrestart++;
		if (remotemode) {
			if (netmode(isrestart) != 0) {
				warning("could not connect;"
					" waiting and trying again");
				usleep(retryinterval * 1000);
				goto retry;
			}
		}
		else if (programmode) {
			if (progmode(isrestart) != 0) {
				warning("sub-program did not start;"
					" waiting %ds and trying again",
					(failures * retryinterval) / 1000);
				usleep((failures * retryinterval) * 1000);
				goto retry;
			}
		}
		else if (xendomain) {
			if (xenmode(isrestart) != 0) {
				warning("could not find console for domain;",
					" waiting and trying again");
				usleep(retryinterval * 1000);
				goto retry;
			}
		}
		else
#endif
		if (rawmode(Devname, speed))
			die("rawmode failed");
	}
	capture();
	cleanup();
	exit(0);
}

#ifdef TWOPROCESS
int	pid;

void
capture(void)
{
	int flags = FNDELAY;

	(void) fcntl(ptyfd, F_SETFL, &flags);

	if (pid = fork())
		in();
	else
		out();
}

/*
 * Loop reading from the console device, writing data to log file and
 * to the pty for tip to pick up.
 */
in(void)
{
	char buf[BUFSIZE];
	int cc;
	sigset_t omask;
	
	while (1) {
		if ((cc = read(devfd, buf, BUFSIZE)) < 0) {
			if ((errno == EWOULDBLOCK) || (errno == EINTR))
				continue;
			else
				die("%s: read: %s", Devname, geterr(errno));
		}
		sigprocmask(SIG_BLOCK, &actionsigmask, &omask);

		if (logfd >= 0) {
			if (write(logfd, buf, cc) < 0)
				die("%s: write: %s", Logname, geterr(errno));
		}

		if (runfile) {
			if (write(runfd, buf, cc) < 0)
				die("%s: write: %s", Runname, geterr(errno));
		}

		if (write(ptyfd, buf, cc) < 0) {
			if ((errno != EIO) && (errno != EWOULDBLOCK))
				die("%s: write: %s", Ptyname, geterr(errno));
		}
		sigprocmask(SIG_SETMASK, &omask, NULL);
	}
}

/*
 * Loop reading input from pty (tip), and send off to the console device.
 */
out(void)
{
	char buf[BUFSIZE];
	int cc;
	sigset_t omask;
	struct timeval timeout;

	timeout.tv_sec  = 0;
	timeout.tv_usec = 100000;
	
	while (1) {
		sigprocmask(SIG_BLOCK, &actionsigmask, &omask);
		if ((cc = read(ptyfd, buf, BUFSIZE)) < 0) {
			sigprocmask(SIG_SETMASK, &omask, NULL);
			if ((errno == EIO) || (errno == EWOULDBLOCK) ||
			    (errno == EINTR)) {
				select(0, 0, 0, 0, &timeout);
				continue;
			}
			else
				die("%s: read: %s", Ptyname, geterr(errno));
		}

		if (write(devfd, buf, cc) < 0)
			die("%s: write: %s", Devname, geterr(errno));
		
		sigprocmask(SIG_SETMASK, &omask, NULL);
	}
}
#else
static fd_set	sfds;
static int	fdcount;
#ifdef LOG_DROPS
static int drop_topty_chars = 0;
static int drop_todev_chars = 0;
#endif

void
send_to_client(const char *buf, int cc)
{
	int i, lcc, lerrno;

#ifdef	USESOCKETS
	if (!tipactive)
		return;
#endif

	for (lcc = 0; lcc < cc; lcc += i) {
#ifdef  WITHSSL
		if (relay_snd) {
			i = SSL_write(sslRelay, &buf[lcc], cc-lcc);
		}
		else if (sslCon != NULL) {
			i = SSL_write(sslCon, &buf[lcc], cc-lcc);
			if (i < 0) { i = 0; } /* XXX Hack */
		} else
#endif /* WITHSSL */ 
		{
			i = write(ptyfd, &buf[lcc], cc-lcc);
		}
		lerrno = errno;
		if (debug > 1)
			fprintf(stderr, "%s: client write returns %d\n",
				Machine, i);
		if (i < 0) {
			/*
			 * Either tip is blocked (^S) or
			 * not running (the latter should
			 * return EIO but doesn't due to a
			 * pty bug).  Note that we have
			 * dropped some chars.
			 */
			if (lerrno == EIO || lerrno == EAGAIN) {
#ifdef LOG_DROPS
				drop_topty_chars += (cc-lcc);
#endif
				return;
			}
			if (lerrno == ECONNRESET) {
				if (debug == 1) {
					fprintf(stderr,
						"%s: client write ECONNRESET\n",
						Machine);
				}
#ifdef	USESOCKETS
				tipactive = 0;
				return;
#endif
			}
			die("%s: write: %s", Ptyname, geterr(lerrno));
		}
		if (i == 0) {
#ifdef	USESOCKETS
			tipactive = 0;
			return;
#else
			die("%s: write: zero-length", Ptyname);
#endif
		}
	}
}

void
send_to_device(const char *buf, int cc)
{
	int i, lcc, lerrno;
 
	for (lcc = 0; lcc < cc; lcc += i) {
		if (relay_rcv) {
#ifdef USESOCKETS
#ifdef  WITHSSL
			if (sslRelay != NULL) {
				i = SSL_write(sslRelay, &buf[lcc], cc - lcc);
			} else
#endif
			{
				i = cc - lcc;
			}
#endif
		}
		else {
			i = write(devfd, &buf[lcc], cc-lcc);
		}
		lerrno = errno;
		if (debug > 1)
			fprintf(stderr, "%s: device write returns %d\n",
				Machine, i);
		if (i < 0) {
			/*
			 * Device backed up (or FUBARed)
			 * Note that we dropped some chars.
			 */
			if (lerrno == EAGAIN) {
#ifdef LOG_DROPS
				drop_todev_chars += (cc-lcc);
#endif
				return;
			}
			die("%s: write: %s", Devname, geterr(lerrno));
		}
		if (i == 0)
			die("%s: write: zero-length", Devname);
	}
}

void
send_to_logfile(const char *buf, int cc)
{
	int i;

	if (stampinterval >= 0) {
		static time_t laststamp;
		struct timeval tv;
		char stampbuf[64], *cts;
		time_t now, delta;

		gettimeofday(&tv, 0);
		now = tv.tv_sec;
		delta = now - laststamp;
		if (stampinterval == 0 ||
		    delta > stampinterval) {
			cts = ctime(&now);
			cts[24] = 0;
			if (stamplast && laststamp)
				snprintf(stampbuf, sizeof stampbuf,
					 "\nSTAMP{%u@%s}\n",
					 (unsigned)delta, cts);
			else
				snprintf(stampbuf, sizeof stampbuf,
					 "\nSTAMP{%s}\n",
					 cts);
			if (logfd >= 0) {
				if (write(logfd, stampbuf, strlen(stampbuf)) < 0)
					;
			}
		}
		laststamp = now;
	}
	if (logfd >= 0) {
		i = write(logfd, buf, cc);
		if (i < 0)
			die("%s: write: %s", Logname, geterr(errno));
		if (i != cc)
			die("%s: write: incomplete", Logname);
	}
	if (runfile) {
		i = write(runfd, buf, cc);
		if (i < 0)
			die("%s: write: %s", Runname, geterr(errno));
		if (i != cc)
			die("%s: write: incomplete", Runname);
	}
}

void
capture(void)
{
	fd_set fds;
	int i, cc;
	sigset_t omask;
	char buf[BUFSIZE];
	struct timeval timeout;
#ifdef  USESOCKETS
	int nretries;
#endif
	/*
	 * XXX for now we make both directions non-blocking.  This is a
	 * quick hack to achieve the goal that capture never block
	 * uninterruptably for long periods of time (use threads).
	 * This has the unfortunate side-effect that we may drop chars
	 * from the perspective of the user (use threads).  A more exotic
	 * solution would be to poll the readiness of output (use threads)
	 * as well as input and not read from one end unless we can write
	 * the other (use threads).
	 *
	 * I keep thinking (use threads) that there is a better way to do
	 * this (use threads).  Hmm...
	 */
	if ((devfd >= 0) && (fcntl(devfd, F_SETFL, O_NONBLOCK) < 0))
		die("%s: fcntl(O_NONBLOCK): %s", Devname, geterr(errno));
#ifndef USESOCKETS
	/*
	 * It gets better!
	 * In FreeBSD 4.0 and beyond, the fcntl fails because the slave
	 * side is not open even though the only effect of this call is
	 * to set the file description's FNONBLOCK flag (i.e. the pty and
	 * tty code do nothing additional).  Turns out that we could use
	 * ioctl instead of fcntl to set the flag.  The call will still
	 * fail, but the flag will be left set.  Rather than rely on that
	 * dubious behavior, I temporarily open the slave, do the fcntl
	 * and close the slave again.
	 */
#ifdef __FreeBSD__
	if ((i = open(Ttyname, O_RDONLY)) < 0)
		die("%s: open: %s", Ttyname, geterr(errno));
#endif
	if (fcntl(ptyfd, F_SETFL, O_NONBLOCK) < 0)
		die("%s: fcntl(O_NONBLOCK): %s", Ptyname, geterr(errno));
#ifdef __FreeBSD__
	close(i);
#endif
#endif /* USESOCKETS */

	FD_ZERO(&sfds);
	if (devfd >= 0)
		FD_SET(devfd, &sfds);
	fdcount = devfd;
#ifdef  USESOCKETS
	if (fdcount < sockfd)
		fdcount = sockfd;
	FD_SET(sockfd, &sfds);
#endif	/* USESOCKETS */
	if (ptyfd >= 0) {
		if (fdcount < ptyfd)
			fdcount = ptyfd;
		FD_SET(ptyfd, &sfds);
	}
#ifdef  USESOCKETS
	if (xsfd >= 0) {
		if (fdcount < xsfd)
			fdcount = xsfd;
		FD_SET(xsfd, &sfds);
	}
#endif

	fdcount++;

	for (;;) {
#ifdef LOG_DROPS
		if (drop_topty_chars >= DROP_THRESH) {
			warning("%d dev -> pty chars dropped",
				drop_topty_chars);
			drop_topty_chars = 0;
		}
		if (drop_todev_chars >= DROP_THRESH) {
			warning("%d pty -> dev chars dropped",
				drop_todev_chars);
			drop_todev_chars = 0;
		}
#endif
		fds = sfds;
		timeout.tv_usec = 0;
		timeout.tv_sec  = 30;
#ifdef	USESOCKETS
		if (needshake) {
			timeout.tv_sec += (random() % 60);
		}
#endif
		i = select(fdcount, &fds, NULL, NULL, &timeout);
		if (i < 0) {
			if (errno == EINTR) {
				warning("input select interrupted, continuing");
				continue;
			}
			die("%s: select: %s", Devname, geterr(errno));
		}
		if (i == 0) {
#ifdef	USESOCKETS
			if (needshake) {
				(void) handshake();
				continue;
			}
#endif
			continue;
		}
#ifdef	USESOCKETS
		if (FD_ISSET(sockfd, &fds)) {
			(void) clientconnect();
		}
		if ((upfd >=0) && FD_ISSET(upfd, &fds)) {
			(void) handleupload();
		}
#endif	/* USESOCKETS */
		if ((devfd >= 0) && FD_ISSET(devfd, &fds)) {
			if (debug > 1)
				fprintf(stderr, "%s: device has data\n",
					Machine);
			errno = 0;
#ifdef  WITHSSL
			if (relay_rcv) {
				cc = SSL_read(sslRelay, buf, sizeof(buf));
				if (cc <= 0) {
					FD_CLR(devfd, &sfds);
					devfd = -1;
					bzero(&relayclient, sizeof(relayclient));
					continue;
				}
			} else
#endif
			cc = read(devfd, buf, sizeof(buf));
			if (debug > 1)
				fprintf(stderr, "%s: device read returns %d\n",
					Machine, cc);
			if (cc <= 0) {
#ifdef  USESOCKETS
				if (remotemode || programmode || xendomain
				    || maxretries) {
					FD_CLR(devfd, &sfds);
					close(devfd);
					devfd = -1;
					if (remotemode) {
						warning("remote socket closed;"
						" attempting to reconnect");
						while (netmode(1) != 0)
							usleep(retryinterval
							       * 1000);
					}
					else if (programmode) {
						warning("sub-program died;"
						" attempting to restart");
						while (progmode(1) != 0) {
							warning("sub-program did not restart;"
								" waiting %ds and trying again",
								(failures *
								 retryinterval)
								/ 1000);
							usleep((failures *
								retryinterval)
							       * 1000);
						}

					}
					else if (xendomain) {
						warning("xen console %s closed;"
							" attempting to reopen",
							Devname);
						if (xsfd >= 0)
							FD_CLR(xsfd, &sfds);
						while (xenmode(1) != 0)
							usleep(retryinterval
							       * 1000);
						if (xsfd >= 0) {
							FD_SET(xsfd, &sfds);
							if (xsfd >= fdcount)
								fdcount = xsfd + 1;
						}
					}
					else {
						warning("devfd %s closed;"
							" attempting to reopen",
							Devname);
						nretries = 0;
						while (rawmode(Devname,speed) != 0) {
							if (maxretries > 0
							    && nretries > maxretries) {
								die("%s: failed to reopen (%d tries)",
								    Devname,nretries);
							}
							++nretries;
							usleep(retryinterval
							       * 1000);
						}
					}
					if (devfd >= 0) {
						FD_SET(devfd, &sfds);
						if (devfd >= fdcount)
							fdcount = devfd + 1;
					}
					continue;
				}
#endif
				if (cc < 0)
					die("%s: read: %s",
					    Devname, geterr(errno));
				if (cc == 0)
					die("%s: read: EOF", Devname);
			}

			errno = 0;
			sigprocmask(SIG_BLOCK, &actionsigmask, &omask);
#ifdef	USESOCKETS
#ifdef WITH_TELNET
			if (Devproto == PROTO_TELNET)
				proto_telnet_send_to_client(buf, cc);
			else
#endif
			{
				if (tipactive) {
					send_to_client(buf, cc);

					/* got EOF from client */
					if (!tipactive) {
						send_to_logfile(buf, cc);
						addtocircbuf(buf, cc);
						sigprocmask(SIG_SETMASK,
							    &omask, NULL);
						goto disconnected;
					}
				}
				else {
					addtocircbuf(buf, cc);
				}
				send_to_logfile(buf, cc);
			}
#else
			send_to_client(buf, cc);
			send_to_logfile(buf, cc);
#endif
			sigprocmask(SIG_SETMASK, &omask, NULL);
		}
		if ((ptyfd >= 0) && FD_ISSET(ptyfd, &fds)) {
			if (debug > 1)
				fprintf(stderr, "%s: client has data\n",
					Machine);
			int lerrno;

			sigprocmask(SIG_BLOCK, &actionsigmask, &omask);
			errno = 0;
#ifdef WITHSSL
			if (relay_snd) {
				cc = SSL_read( sslRelay, buf, sizeof(buf) );
				if (cc < 0) { /* XXX hack */
					cc = 0;
					SSL_free(sslRelay);
					sslRelay = NULL;
					upportnum = -1;
				}
			}
			else if (sslCon != NULL) {
			        cc = SSL_read( sslCon, buf, sizeof(buf) );
				if (cc < 0) { /* XXX hack */
					cc = 0;
					SSL_free(sslCon);
					sslCon = NULL;
				}
			} else
#endif /* WITHSSL */ 
			cc = read(ptyfd, buf, sizeof(buf));
			lerrno = errno;
			if (debug > 1)
				fprintf(stderr, "%s: client read returns %d\n",
					Machine, cc);
			sigprocmask(SIG_SETMASK, &omask, NULL);
			if (cc < 0) {
				/* XXX commonly observed */
				if (lerrno == EIO || lerrno == EAGAIN)
					continue;
#ifdef	USESOCKETS
				if (lerrno == ECONNRESET || lerrno == ETIMEDOUT)
					goto disconnected;
				die("%s: socket read: %s",
				    Machine, geterr(lerrno));
#else
				die("%s: read: %s", Ptyname, geterr(lerrno));
#endif
			}
			if (cc == 0) {
#ifdef	USESOCKETS
			disconnected:
				/*
				 * Other end disconnected.
				 */
				if (relay_snd)
					die("relay receiver died");
				dolog(LOG_INFO, "%s disconnecting",
				      inet_ntoa(tipclient.sin_addr));
				FD_CLR(ptyfd, &sfds);
				close(ptyfd);
				tipactive = 0;
				continue;
#else
				/*
				 * Delay after reading 0 bytes from the pty.
				 * At least under FreeBSD, select on a
				 * disconnected pty (control half) always
				 * return ready and the subsequent read always
				 * returns 0.  To keep capture from eating up
				 * CPU constantly when no one is connected to
				 * the pty (i.e., most of the time) we delay
				 * after doing a zero length read.
				 *
				 * Note we keep tabs on the device so that we
				 * will wake up early if it goes active.
				 */
				timeout.tv_sec  = 1;
				timeout.tv_usec = 0;
				FD_ZERO(&fds);
				FD_SET(devfd, &fds);
				select(devfd+1, &fds, 0, 0, &timeout);
				continue;
#endif
			}

			errno = 0;
			sigprocmask(SIG_BLOCK, &actionsigmask, &omask);
#ifdef WITH_TELNET
			if (Devproto == PROTO_TELNET)
				proto_telnet_send_to_device(buf, cc);
			else
#endif
			send_to_device(buf, cc);
			sigprocmask(SIG_SETMASK, &omask, NULL);
		}
#ifdef  USESOCKETS
		if (xsfd >= 0 && FD_ISSET(xsfd, &fds)) {
			if (debug > 1)
				fprintf(stderr,
					"%s: xenstore_watch has data\n",
					Machine);
			/* XXX xenmode may reopen device */
			if (devfd >= 0)
			    FD_CLR(devfd, &sfds);
			FD_CLR(xsfd, &sfds);
			while (xenmode(1) != 0)
				usleep(retryinterval * 1000);
			assert(devfd >= 0);
			FD_SET(devfd, &sfds);
			if (devfd >= fdcount)
				fdcount = devfd + 1;
			if (xsfd >= 0) {
				FD_SET(xsfd, &sfds);
				if (xsfd >= fdcount)
					fdcount = xsfd + 1;
			}
		}
#endif
	}
}
#endif

/*
 * SIGHUP means we want to close the old log file (because it has probably
 * been moved) and start a new version of it.
 */
void
reinit(int sig)
{
	/*
	 * We know that the any pending write to the log file completed
	 * because we blocked SIGHUP during the write.
	 */
	if (logfd >= 0) {
		close(logfd);
	}
	if (!nologfile) {
		if ((logfd = open(Logname,
				  O_WRONLY|O_CREAT|O_APPEND, 0640)) < 0)
			die("%s: open: %s", Logname, geterr(errno));
		if (chmod(Logname, 0640) < 0)
			die("%s: chmod: %s", Logname, geterr(errno));
	}
	dolog(LOG_NOTICE, "new log started");

	if (runfile)
		newrun(sig);
}

/*
 * SIGUSR1 means we want to close the old run file and start a new version
 * of it. The run file is not rolled or saved, so we unlink it to make sure
 * that no one can hang onto an open fd.
 */
void
newrun(int sig)
{
	/*
	 * We know that the any pending write to the log file completed
	 * because we blocked SIGUSR1 during the write.
	 */
	close(runfd);
	unlink(Runname);

	if ((runfd = open(Runname, O_WRONLY|O_CREAT|O_APPEND, 0600)) < 0)
		die("%s: open: %s", Runname, geterr(errno));

#ifdef  USESOCKETS
	if (docircbuf)
		clearcircbuf();
	/*
	 * Set owner/group of the new run file. Avoid race in which a
	 * user can get the new file before the chmod, by creating 0600
	 * and doing the chmod below.
	 */
	if (fchown(runfd, tipuid, tipgid) < 0)
		die("%s: fchown: %s", Runname, geterr(errno));
#endif
	if (fchmod(runfd, 0640) < 0)
		die("%s: fchmod: %s", Runname, geterr(errno));
	
	dolog(LOG_NOTICE, "new run started");
}

/*
 * SIGUSR2 means we want to revoke the other side of the pty to close the
 * tip down gracefully.  We flush all input/output pending on the pty,
 * do a revoke on the tty and then close and reopen the pty just to make
 * sure everyone is gone.
 */
void
terminate(int sig)
{
#ifdef	USESOCKETS
	if (tipactive) {
		shutdown(ptyfd, SHUT_RDWR);
		close(ptyfd);
		FD_CLR(ptyfd, &sfds);
		ptyfd = 0;
		tipactive = 0;
		dolog(LOG_INFO, "%s revoked", inet_ntoa(tipclient.sin_addr));
	}
	else
		dolog(LOG_INFO, "revoked");

	tipuid = tipgid = 0;
	if (runfile)
		newrun(sig);

	if (docircbuf)
		clearcircbuf();
	
	/* Must be done *after* all the above stuff is done! */
	createkey();
#else
	int ofd = ptyfd;
	
	/*
	 * We know that the any pending access to the pty completed
	 * because we blocked SIGUSR2 during the operation.
	 */
	tcflush(ptyfd, TCIOFLUSH);
	if (revoke(Ttyname) < 0)
		dolog(LOG_WARNING, "could not revoke access to tty");
	close(ptyfd);
	
	if ((ptyfd = open(Ptyname, O_RDWR)) < 0)
		die("%s: open: %s", Ptyname, geterr(errno));

	/* XXX so we don't have to recompute the select mask */
	if (ptyfd != ofd) {
		dup2(ptyfd, ofd);
		close(ptyfd);
		ptyfd = ofd;
	}

#ifdef __FreeBSD__
	/* see explanation in capture() above */
	if ((ofd = open(Ttyname, O_RDONLY)) < 0)
		die("%s: open: %s", Ttyname, geterr(errno));
#endif
	if (fcntl(ptyfd, F_SETFL, O_NONBLOCK) < 0)
		die("%s: fcntl(O_NONBLOCK): %s", Ptyname, geterr(errno));
#ifdef __FreeBSD__
	close(ofd);
#endif
	
	dolog(LOG_NOTICE, "pty reset");
#endif	/* USESOCKETS */
}

/*
 * Our child has died. We do not restart it here, but wait till
 * it is noticed in the capture loop above. 
 */
void
deadchild(int sig)
{
#ifdef	USESOCKETS
	int	status, rval;

	/*
	 * We may be receiving a delayed signal after being blocked
	 * in progmode(). Make sure there really is a child process.
	 */
	if (progpid < 0) {
		/* XXX sanity check */
		while ((rval = waitpid(-1, &status, WNOHANG)) > 0)
			dolog(LOG_NOTICE,
			      "waitpid found unexpected child %d (0x%x)\n",
			      rval, status);
		return;
	}

	rval = waitpid(progpid, &status, WNOHANG);
	if (rval < 0) {
		warning("waitpid(%d): %s", progpid, geterr(errno));
		progpid = -1;
		return;
	}
	/*
	 * Huh, something must have died, so do a wait and find it.
	 */
	if (rval == 0) {
		dolog(LOG_NOTICE, "waitpid(%d) returned zero, doing general wait", progpid);
		while ((rval = waitpid(-1, &status, WNOHANG)) > 0)
			dolog(LOG_NOTICE, "  pid %d: status=0x%x\n",
			      rval, status);
		progpid = -1;
		return;
	}
	if (rval != progpid) {
		die("waitpid(%d): waitpid returned some other pid", progpid);
	}
	progpid = -1;
	dolog(LOG_NOTICE, "child died");
#endif	/* USESOCKETS */
}

/*
 *  Display proper usage / error message and exit.
 */
char *optstr =
#ifdef USESOCKETS
#ifdef WITHSSL
"[-c certfile] [-v calist] [-u uploadcmd] "
#endif
"[-b bossnode] [-p bossport] [-i] "
#endif
"-HdraoPL [-s speed] [-T stampinterval]";
void
usage(void)
{
	fprintf(stderr, "usage: %s %s machine tty\n", Progname, optstr);
	exit(1);
}

void
warning(char *format, ...)
{
	char msgbuf[BUFSIZE];
	va_list ap;

	va_start(ap, format);
	vsnprintf(msgbuf, BUFSIZE, format, ap);
	va_end(ap);
	dolog(LOG_WARNING, msgbuf);
}

void
die(char *format, ...)
{
	char msgbuf[BUFSIZE];
	va_list ap;

	va_start(ap, format);
	vsnprintf(msgbuf, BUFSIZE, format, ap);
	va_end(ap);
	dolog(LOG_ERR, msgbuf);
	cleanup();
	exit(1);
}

void
dolog(int level, char *format, ...)
{
	char msgbuf[BUFSIZE];
	va_list ap;

	va_start(ap, format);
	vsnprintf(msgbuf, BUFSIZE, format, ap);
	va_end(ap);
	if (debug) {
		fprintf(stderr, "%s: %s\n", Machine, msgbuf);
		fflush(stderr);
	}
	syslog(level, "%s: %s\n", Machine, msgbuf);
}

void
quit(int sig)
{
	cleanup();
	// This used to be an exit(1). Lets use 15 instead, so we can run
	// this from daemon_wrapper, which now looks for this exit code,
	// since it will not otherwise know this was a TERM exit.
	exit(15);
}

void
cleanup(void)
{
	dolog(LOG_NOTICE, "exiting");
#ifdef TWOPROCESS
	if (pid)
		(void) kill(pid, SIGTERM);
#endif
	(void) unlink(Pidname);
#ifdef USESOCKETS
	(void) unlink(Aclname);
#endif
}

char *
newstr(char *str)
{
	char *np;

	if ((np = malloc((unsigned) strlen(str) + 1)) == NULL)
		die("malloc: out of memory");

	return(strcpy(np, str));
}

/*
 * Open up PID file and write our pid into it.
 */
void
writepid(void)
{
	int fd;
	char buf[8];

	if (relay_snd)
		return;
	
	if ((fd = open(Pidname, O_WRONLY|O_CREAT|O_TRUNC, 0644)) < 0)
		die("%s: open: %s", Pidname, geterr(errno));

	if (chmod(Pidname, 0644) < 0)
		die("%s: chmod: %s", Pidname, geterr(errno));
	
	(void) snprintf(buf, sizeof(buf), "%d\n", getpid());
	
	if (write(fd, buf, strlen(buf)) < 0)
		die("%s: write: %s", Pidname, geterr(errno));
	
	(void) close(fd);
}

int
powermonmode(void)
{
	struct termios serial_opts;
	int old_tiocm, status;
	
	// get copy of other current serial port settings to restore later
	if(ioctl(devfd, TIOCMGET, &old_tiocm) == -1)
		return -1;

	// get current serial port settings (must modify existing settings)
	if(tcgetattr(devfd, &serial_opts) == -1)
		return -1;
	
	// clear out settings
	serial_opts.c_cflag = 0;
	serial_opts.c_iflag = 0;
	serial_opts.c_lflag = 0;
	serial_opts.c_oflag = 0;
	
	// set baud rate
	if(cfsetispeed(&serial_opts, speed) == -1)
		return -1;
	if(cfsetospeed(&serial_opts, speed) == -1)
		return -1;
	
	// no parity
	serial_opts.c_cflag &= ~PARENB;
	serial_opts.c_iflag &= ~INPCK;
	
	// apply settings and check for error
	// this is done because tcsetattr() would return success if *any*
	// settings were set correctly; this way, more error checking is done
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;

	serial_opts.c_cflag &= ~CSTOPB; // 1 stop bit
	serial_opts.c_cflag &= ~CSIZE;  // reset byte size
	serial_opts.c_cflag |= CS8;     // 8 bits
	
	// apply settings and check for error
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;
	
	// disable hardware flow control
	serial_opts.c_cflag &= ~CRTSCTS;
	
	// apply settings and check for error
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;
	
	// disable software flow control
	serial_opts.c_iflag &= ~(IXON | IXOFF | IXANY);
	
	// apply settings and check for error
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;
	
	// raw I/O
	serial_opts.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
	serial_opts.c_oflag &= ~OPOST;
	
	// apply settings and check for error
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;
	
	// timeouts
	serial_opts.c_cc[VMIN] = 0;
	serial_opts.c_cc[VTIME] = 10;
	
	// apply settings and check for error
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;
	
	// misc. settings
	serial_opts.c_cflag |= HUPCL;
	serial_opts.c_cflag |= (CLOCAL | CREAD);

	// apply settings and check for error
	if(tcsetattr(devfd, TCSANOW, &serial_opts) == -1)
		return -1;
	
	status = old_tiocm; // get settings
	status |= TIOCM_DTR;  // turn on DTR and...
	status |= TIOCM_RTS;  // ...RTS lines to power up device
	// apply settings
	if(ioctl(devfd, TIOCMSET, &status) == -1)
		return -1;
	
	// wait for device to power up
	usleep(100000);
	
	tcflush(devfd, TCOFLUSH);
	return 0;
}

/*
 * Put the console line into raw mode.
 */
int
rawmode(char *devname, int speed)
{
	struct termios t;

	if ((devfd = open(devname, O_RDWR|O_NONBLOCK)) < 0) {
		warning("%s: open: %s", devname, geterr(errno));
		return -1;
	}
	
	if (ioctl(devfd, TIOCEXCL, 0) < 0)
		warning("TIOCEXCL %s: %s", Devname, geterr(errno));
	if (tcgetattr(devfd, &t) < 0) {
		warning("%s: tcgetattr: %s", Devname, geterr(errno));
		close(devfd);
		return -1;
	}
	(void) cfsetispeed(&t, speed);
	(void) cfsetospeed(&t, speed);
	cfmakeraw(&t);
	t.c_cflag |= CLOCAL;
	if (hwflow)
#ifdef __linux__
	        t.c_cflag |= CRTSCTS;
#else
		t.c_cflag |= CCTS_OFLOW | CRTS_IFLOW;
#endif
	t.c_cc[VSTART] = t.c_cc[VSTOP] = _POSIX_VDISABLE;
	if (tcsetattr(devfd, TCSAFLUSH, &t) < 0) {
		warning("%s: tcsetattr: %s", Devname, geterr(errno));
		close(devfd);
		return -1;
	}

	if (powermon && powermonmode() < 0)
		die("%s: powermonmode: %s", Devname, geterr(errno));

	return 0;
}

/*
 * The console line is really a socket on some node:port.
 */
#ifdef  USESOCKETS
int
netmode(int isrestart)
{
	struct sockaddr_in	sin;
	struct hostent		*he;
	char			*portstr, *protostr;
	int			port;
	char			hoststr[BUFSIZ];
	
	strcpy(hoststr, Devname);
	if ((portstr = strchr(hoststr, ':')) == NULL)
		die("%s: bad format, expecting 'host:port'", hoststr);
	*portstr++ = '\0';
	if ((protostr = strchr(portstr, ',')) != NULL) {
		*protostr++ = '\0';
		if (strcmp(protostr, "raw") == 0)
			Devproto = PROTO_RAW;
#ifdef WITH_TELNET
		else if (strcmp(protostr, "telnet") == 0)
			Devproto = PROTO_TELNET;
#endif
		else
			die("%s: bad protocol '%s'", Devname, protostr);
	} else
		Devproto = PROTO_RAW;
	if (sscanf(portstr, "%d", &port) != 1)
		die("%s: bad port number '%s'", Devname, portstr);
	he = gethostbyname(hoststr);
	if (he == 0) {
		warning("gethostbyname(%s): %s", hoststr, hstrerror(h_errno));
		return -1;
	}
	bzero(&sin, sizeof(sin));
	memcpy ((char *)&sin.sin_addr, he->h_addr, he->h_length);
	sin.sin_family = AF_INET;
	sin.sin_port = htons(port);

	if ((devfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		warning("socket(): %s", geterr(errno));
		return -1;
	}
	if (connect(devfd, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
		warning("connect(): %s", geterr(errno));
		close(devfd);
		return -1;
	}
	if (fcntl(devfd, F_SETFL, O_NONBLOCK) < 0) {
		warning("%s: fcntl(O_NONBLOCK): %s", Devname, geterr(errno));
		close(devfd);
		return -1;
	}
#ifdef WITH_TELNET
	if (Devproto == PROTO_TELNET)
		proto_telnet_init();
#endif

	return 0;
}

/*
 * The console line is really a pipe connected to a program we start.
 */
int
progmode(int isrestart)
{
	int		pipefds[2];
	sigset_t	mask;
	int		rv = -1;
	static int	first = 1;

	/*
	 * Since we are all paranoid and close all possible file descriptors
	 * below, make sure the max per-process limit is not outrageous.
	 * On one machine, the default was 1.8M descriptors and it was taking
	 * five seconds of real time to close them all.
	 */
	if (first) {
		struct rlimit maxfd;
		maxfd.rlim_cur = maxfd.rlim_max = 1000;
		if (setrlimit(RLIMIT_NOFILE, &maxfd)) {
			warning("%s: could not lower file descriptor max",
				Devname);
		}
		first = 0;
	}

	/*
	 * Looks like select is woken up before the process winds up dead.
	 * Try waiting a fraction of a second to let that happen. We do
	 * this before blocking the signal so that it happens here rather
	 * than gratuitously after we have done waitpid below.
	 */
	if (isrestart && progpid > 0) {
		int i;
		for (i = 0; i < 10 && progpid > 0; i++)
			usleep(100000);
	}

	/* avoid races with deadchild */
	sigemptyset(&mask);
	sigaddset(&mask, SIGCHLD);
	sigprocmask(SIG_BLOCK, &mask, 0);

	/*
	 * Token attempt to clean up previous child. This should no
	 * longer be necessary after the wait above, but just in case...
	 */
	if (isrestart && progpid > 0) {
		warning("%s: old process (%d) is still with us!",
			Devname, progpid);
		deadchild(SIGCHLD);
	}

	if (socketpair(AF_UNIX, SOCK_STREAM, 0, pipefds) < 0) {
		warning("socketpair(): %s", geterr(errno));
		goto err;
	}

	if ((progpid = fork()) < 0) {
		warning("fork(): %s", geterr(errno));
		close(pipefds[0]);
		close(pipefds[1]);
		goto err;
	}
	if (progpid) {
		int status;

		/*
		 * Wait a short time and see if it dies right off the bat.
		 * Otherwise we will get into a fast respawn loop.
		 */
		usleep(2000000);
		if (waitpid(progpid, &status, WNOHANG) == progpid) {
			char buf[256];
			int cc;

			warning("%s: program (pid=%d) died immediately, "
				"status=0x%x",
				Devname, progpid, status);
			if (fcntl(pipefds[0], F_SETFL, O_NONBLOCK) == 0) {
				cc = read(pipefds[0], buf, sizeof(buf)-1);
				if (cc > 0) {
					buf[cc] = '\0';
					warning("  Output: %s ...", buf);
				}
			}
			close(pipefds[0]);
			close(pipefds[1]);
			/* don't confuse deadchild */
			progpid = -1;
			goto err;
		}
		close(pipefds[1]);
		devfd = pipefds[0];

		if (fcntl(devfd, F_SETFL, O_NONBLOCK) < 0) {
			warning("%s: fcntl(O_NONBLOCK): %s",
				Devname, geterr(errno));
			close(devfd);
			goto err;
		}
		rv = 0;
	}
	else {
		int	i, max;
		
		close(pipefds[0]);

		/*
		 * Change the childs descriptors over to the socket.
		 */
		close(0);
		close(1);
		close(2);
		if (dup(pipefds[1]) != 0 ||
		    dup(pipefds[1]) != 1 ||
		    dup(pipefds[1]) != 2)
			die("dup pooched it.");

		/*
		 * Close all other descriptors.
		 */
		max = getdtablesize();
		for (i = 3; i < max; i++)
			(void) close(i); 		

		sigprocmask(SIG_UNBLOCK, &mask, 0);
		execvp(programargv[1], &programargv[1]);
		exit(66);
	}
 err:
	if (rv) {
		if (++failures > maxfailures)
			die("sub-program failed to start %d consecutive times;"
			    " aborting.", maxfailures);
	} else
		failures = 0;
	sigprocmask(SIG_UNBLOCK, &mask, 0);

	return rv;
}

/*
 * Xenmode support from here on out.
 *
 * Note that we invoke Xen command line tools here. We could use native
 * library calls, but I don't want to have to link against Xen libraries.
 *
 * This is a prime example of a simple perl script written in C.
 */
#define XEN_XL	 "/usr/sbin/xl"
#define XEN_XSR	 "/usr/sbin/xenstore-read"
#define XEN_XSR2 "/usr/bin/xenstore-read"
#define XEN_XSW	 "/usr/sbin/xenstore-watch"
#define XEN_XSW2 "/usr/bin/xenstore-watch"

/*
 * Capture output from a shell command.
 */
static int
backtick(char *cmd, char *outbuf, int outlen)
{
	FILE *pfd;
	int rv, rv2, cc, len = outlen - 1;
	char tossbuf[128], *buf = outbuf;

	pfd = popen(cmd, "r");
	if (pfd == NULL) {
		warning("Could not execute command");
		return -1;
	}
	while (len > 0 && (cc = fread(buf, 1, len, pfd)) > 0) {
		len -= cc;
		buf += cc;
	}
	outbuf[outlen - len - 1] = '\0';
	if (cc) {
		while (fread(tossbuf, 1, sizeof(tossbuf), pfd) > 0)
			;
	}

	rv = ferror(pfd);
	rv2 = pclose(pfd);
	if (rv == 0) {
		rv = rv2;
		if (rv > 0)
			rv >>= 8;
		else if (rv < 0)
			rv = errno;
	}
	return rv;
}

static int
findproc(char *cmd)
{
	char buf[128], outbuf[128];
	int cpid = -1;

	snprintf(buf, sizeof(buf), "pgrep -f '^%s'", cmd);
	if (backtick(buf, outbuf, sizeof(outbuf)) == 0) {
		char *pstr, *estr;
		for (pstr = outbuf; *pstr && !isdigit(*pstr); pstr++)
			;
		for (estr = pstr; *estr && isdigit(*estr); estr++)
			;
		*estr = '\0';
		if (*pstr != '\0')
			cpid = atoi(pstr);
	}

	return cpid;
}

/*
 * My oh my this is awful.
 *
 * We fire off a copy of xenstore-watch via popen() and watch the file
 * descriptor in the select loop. If we see anything, we check and make
 * sure the pty hasn't changed.
 *
 * Since we have to watch a path which contains a domain ID, and the domain
 * changes whenever we reboot, we have to start a new xenstore-watch on
 * every reboot. Even better, the old xenstore-watch does not die when
 * the domain goes away and pclose won't kill it, so we have to figure out
 * the pid of the popen() process and kill it ourselves. Awesome!
 */
static int
xenwatch(int domid)
{
	static int lastdomid = 0;
	static int lastpid = -1;
	static FILE *xs = NULL;
	static char *watch = XEN_XSW;
	static int called;
	char buf[128];
	int flags, cc;

	if (!called) {
		struct stat sb;

		if (stat(XEN_XSW, &sb) < 0)
			watch = XEN_XSW2;
		called++;
	}
	if (domid != lastdomid && xsfd >= 0) {
		assert(fileno(xs) == xsfd);
		if (lastpid > 0) {
			kill(lastpid, SIGTERM);
			lastpid = -1;
		}
		pclose(xs);
		lastdomid = -1;
		xs = NULL;
		xsfd = -1;
	}
	if (xs == NULL) {
		assert(xsfd == -1);
		snprintf(buf, sizeof(buf),
			 "%s /local/domain/%d/console", watch, domid);
		xs = popen(buf, "r");
		if (xs == NULL) {
			warning("Could not start console watcher");
			return -1;
		}
		lastdomid = domid;
		xsfd = fileno(xs);
		flags = fcntl(xsfd, F_GETFL);
		if (flags != -1) {
			flags |= O_NONBLOCK;
			if (fcntl(xsfd, F_SETFL, flags) < 0)
				warning("Could not set non-blocking");
		}
		sleep(1);
		lastpid = findproc(buf);
		dolog(LOG_INFO, "watching Xen dom %d (pid %d)",
		      domid, lastpid);
	}

	/* flush whatever was readable */
	while ((cc = fread(buf, 1, sizeof(buf), xs)) > 0)
		if (debug) {
			buf[cc-1] = 0;
			fprintf(stderr, "watcher read: '%s'\n", buf);
		}

	return 0;
}

/*
 * The console line is a pty exported by xenconsoled. Look it up and open
 * it as devfd.
 *
 * Note that when using HVM, the pty device can change on when the VM is
 * rebooted (recreated). So we set up a hacky xenstore_watch to look for
 * changes.
 */
int
xenmode(int isrestart)
{
	char cmdbuf[128], outbuf[256], *cp, *pty = NULL;
	int domid = -1;
	static int called = 0;
	static char *reader = XEN_XSR;

	/* XXX make sure we have the necessary Xen tools */
	if (!called) {
		struct stat sb;
		if (stat(XEN_XSR, &sb) < 0)
			reader = XEN_XSR2;
		if (stat(XEN_XL, &sb) < 0 || stat(reader, &sb) < 0)
			die("%s or %s do not exist; not running Xen?",
			    XEN_XL, XEN_XSR);
		called++;
	}

	/* first convert name to domain id */
	snprintf(cmdbuf, sizeof(cmdbuf),
		 "%s domid %s 2>/dev/null", XEN_XL, xendomain);
	if (backtick(cmdbuf, outbuf, sizeof(outbuf)) || outbuf[0] == '\0') {
		warning("%s: no such domain", xendomain);
		return -1;
	}
	if ((cp = index(outbuf, '\n')) != 0)
		*cp = '\0';

	domid = strtol(outbuf, &cp, 0);
	if (domid <= 0 || outbuf[0] == '\0' || *cp != '\0')
		die("%s: could not parse 'xl domid' output:\n%s\n",
		    xendomain, outbuf);

	/* see if it is an HVM domain */
	snprintf(cmdbuf, sizeof(cmdbuf),
		 "%s /local/domain/%d/hvmloader >/dev/null 2>&1",
		 reader, domid);
	if (backtick(cmdbuf, outbuf, sizeof(outbuf)) == 0) {
		/* HVM: try looking for emulated uart */
		snprintf(cmdbuf, sizeof(cmdbuf),
			 "%s /local/domain/%d/serial/0/tty 2>/dev/null",
			 reader, domid);
		if (backtick(cmdbuf, outbuf, sizeof(outbuf)) == 0) {
			if ((cp = index(outbuf, '\n')) != 0)
				*cp = '\0';
			pty = outbuf;
		} else {
			sleep(2);
			if (backtick(cmdbuf, outbuf, sizeof(outbuf)) == 0) {
				if ((cp = index(outbuf, '\n')) != 0)
					*cp = '\0';
				pty = outbuf;
			} else {
				warning("%s: HVM with no serial device!",
					xendomain);
			}
		}
		if (pty && xenwatch(domid) != 0)
			warning("%s: could not start watcher", xendomain);
	}

	/* didn't find uart, try PV console */
	if (pty == NULL) {
		snprintf(cmdbuf, sizeof(cmdbuf),
			 "%s /local/domain/%d/console/tty 2>/dev/null",
			 reader, domid);
		if (backtick(cmdbuf, outbuf, sizeof(outbuf)) == 0) {
			if ((cp = index(outbuf, '\n')) != 0)
				*cp = '\0';
			pty = outbuf;
		}
	}
	if (pty == NULL) {
		warning("%s: could not find pty", xendomain);
		return -1;
	}

	if (Devname && strcmp(pty, Devname) != 0) {
		free(Devname);
		if (devfd >= 0)
			close(devfd);
		Devname = newstr(pty);
		if (rawmode(Devname, speed))
			return -1;
		dolog(LOG_INFO,
		      "%s (domid %d) using '%s' (%d)",
		      xendomain, domid, Devname, devfd);
	} else if (isrestart && Devname) {
		/* XXX devfd may have been closed before call, must reopen */
		if (devfd < 0 && rawmode(Devname, speed))
			return -1;
		dolog(LOG_INFO,
		      "%s (domid %d) re-using '%s' (%d)",
		      xendomain, domid, Devname, devfd);
	}

	return 0;
}
#endif

/*
 * From kgdbtunnel
 */
static struct speeds {
	int speed;		/* symbolic speed */
	int val;		/* numeric value */
} speeds[] = {
#ifdef B50
	{ B50,	50 },
#endif
#ifdef B75
	{ B75,	75 },
#endif
#ifdef B110
	{ B110,	110 },
#endif
#ifdef B134
	{ B134,	134 },
#endif
#ifdef B150
	{ B150,	150 },
#endif
#ifdef B200
	{ B200,	200 },
#endif
#ifdef B300
	{ B300,	300 },
#endif
#ifdef B600
	{ B600,	600 },
#endif
#ifdef B1200
	{ B1200, 1200 },
#endif
#ifdef B1800
	{ B1800, 1800 },
#endif
#ifdef B2400
	{ B2400, 2400 },
#endif
#ifdef B4800
	{ B4800, 4800 },
#endif
#ifdef B7200
	{ B7200, 7200 },
#endif
#ifdef B9600
	{ B9600, 9600 },
#endif
#ifdef B14400
	{ B14400, 14400 },
#endif
#ifdef B19200
	{ B19200, 19200 },
#endif
#ifdef B38400
	{ B38400, 38400 },
#endif
#ifdef B28800
	{ B28800, 28800 },
#endif
#ifdef B57600
	{ B57600, 57600 },
#endif
#ifdef B76800
	{ B76800, 76800 },
#endif
#ifdef B115200
	{ B115200, 115200 },
#endif
#ifdef B230400
	{ B230400, 230400 },
#endif
};
#define NSPEEDS (sizeof(speeds) / sizeof(speeds[0]))

int
val2speed(int val)
{
	int n;
	struct speeds *sp;

	for (sp = speeds, n = NSPEEDS; n > 0; ++sp, --n)
		if (val == sp->val)
			return (sp->speed);

	return (0);
}

#ifdef USESOCKETS
int
clientconnect(void)
{
	struct sockaddr_in sin;
	int		cc;
	unsigned int	length = sizeof(sin);
	int		newfd;
	secretkey_t     key;
	capret_t	capret;
#ifdef WITHSSL
	int             dorelay = 0, doupload = 0, dooptions = 0;
	int             newspeed = 0;
	speed_t         newsymspeed;
	int             opterr = 0;
	int             ret;
	SSL	       *newssl;
	struct termios  serial_opts;
	char           *caddr;
#endif

	newfd = accept(sockfd, (struct sockaddr *)&sin, &length);
	if (newfd < 0) {
		dolog(LOG_NOTICE, "accept()ing new client: %s", geterr(errno));
		return 1;
	}

	/*
	 * Read the first part to verify the key. We must get the
	 * proper bits or this is not a valid tip connection.
	 */
	if ((cc = read(newfd, &key, sizeof(key))) <= 0) {
		close(newfd);
		dolog(LOG_NOTICE, "%s connecting, error reading key",
		      inet_ntoa(sin.sin_addr));
		return 1;
	}

#ifdef WITHSSL
	if (cc == sizeof(key) && 
	    (0 == strncmp( key.key, "USESSL", 6 ) ||
	     (dorelay = (0 == strncmp( key.key, "RELAY", 5 ))) ||
	     (dooptions = (0 == strncmp( key.key, "OPTIONS", 7 ))) ||
	     (doupload = (0 == strncmp( key.key, "UPLOAD", 6 ))))) {
	  /* 
	     dolog(LOG_NOTICE, "Client %s wants to use SSL",
		inet_ntoa(sin.sin_addr) );
	  */

	  initializessl();
	  /*
	  if ( write( newfd, "OKAY", 4 ) <= 0) {
	    dolog( LOG_NOTICE, "Failed to send OKAY to client." );
	    close( newfd );
	    return 1;
	  }
	  */

	  newssl = SSL_new( ctx );
	  if (!newssl) {
	    dolog(LOG_NOTICE, "SSL_new failed.");
	    close(newfd);
	    return 1;
	  }	    
	    
	  if ((ret = SSL_set_fd( newssl, newfd )) <= 0) {
	    dolog(LOG_NOTICE, "SSL_set_fd failed.");
	    close(newfd);
	    return 1;
	  }

	  dolog(LOG_NOTICE, "going to accept" );

	  if ((ret = SSL_accept( newssl )) <= 0) {
	    dolog(LOG_NOTICE, "%s connecting, SSL_accept error.",
		  inet_ntoa(sin.sin_addr));
	    ERR_print_errors_fp( stderr );
	    SSL_free(newssl);
	    close(newfd);
	    return 1;
	  }

	  if (doupload) {
	    strcpy(uptmpnam, _PATH_TMP "capture.upload.XXXXXX");
	    if (upfd >= 0 || !relay_snd || !uploadCommand) {
	      dolog(LOG_NOTICE, "%s upload already connected.",
		    inet_ntoa(sin.sin_addr));
	      SSL_free(newssl);
	      close(newfd);
	      return 1;
	    }
	    else if (sslverify(newssl, "Capture Server")) {
	      SSL_free(newssl);
	      close(newfd);
	      return 1;
	    }
	    else if ((upfilefd = mkstemp(uptmpnam)) < 0) {
	      dolog(LOG_NOTICE, "failed to create upload file");
	      printf(" %s\n", uptmpnam);
	      perror("mkstemp");
	      SSL_free(newssl);
	      close(newfd);
	      return 1;
	    }
	    else {
	      upfd = newfd;
	      upfilesize = 0;
	      FD_SET(upfd, &sfds);
	      if (upfd >= fdcount) {
		fdcount = upfd + 1;
	      }
	      sslUpload = newssl;
	      if (fcntl(upfd, F_SETFL, O_NONBLOCK) < 0)
		die("fcntl(O_NONBLOCK): %s", geterr(errno));
	      return 0;
	    }
	  }
	  else if (dooptions) {
	      /*
	       * Just handle these quick inline -- then don't have to
	       * worry about multiple option changes cause they all
	       * happen "atomically" from the client point of view.
	       */

	      caddr = inet_ntoa(sin.sin_addr);
	      sscanf(key.key,"OPTIONS SPEED=%d",&newspeed);
	      newsymspeed = val2speed(newspeed);
	      dolog(LOG_NOTICE,"%s changing speed to %d.",
		    caddr,newspeed);
	      if (newspeed == 0) {
		  dolog(LOG_ERR,"%s invalid speed option %d.",
			caddr,newspeed);
		  opterr = 1;
	      }

	      if (opterr == 0 && tcgetattr(devfd,&serial_opts) == -1) {
		  dolog(LOG_ERR,"%s failed to get attrs before speed change: %s.",
			caddr,strerror(errno));
		  opterr = 1;
	      }

	      // XXX testing
	      //serial_opts.c_lflag |= ECHO | ECHONL;

	      if (opterr) {
	      }
	      else if (cfsetispeed(&serial_opts,newsymspeed) == -1) {
		  dolog(LOG_ERR,"%s cfsetispeed(%d) failed: %s.",
			caddr,newspeed,strerror(errno));
		  opterr = 1;
	      }
	      else if (cfsetospeed(&serial_opts,newsymspeed) == -1) {
		  dolog(LOG_ERR,"%s cfsetospeed(%d) failed: %s.",
			caddr,newspeed,strerror(errno));
		  opterr = 1;
	      }
	      else if (tcsetattr(devfd,TCSANOW,&serial_opts) == -1) {
		  dolog(LOG_ERR,"%s tcsetattr(%d) failed: %s.",
			caddr,newspeed,strerror(errno));
		  opterr = 1;
	      }

	      SSL_free(newssl);
	      shutdown(newfd, SHUT_RDWR);
	      close(newfd);
	      return opterr;
	  }
	  else if (dorelay) {
	    if (devfd >= 0) {
	      dolog(LOG_NOTICE, "%s relay already connected.",
		    inet_ntoa(sin.sin_addr));
	      SSL_free(newssl);
	      shutdown(newfd, SHUT_RDWR);
	      close(newfd);
	      return 1;
	    }
	    else if (memcmp(&relayaddr,
			    &sin.sin_addr,
			    sizeof(relayaddr)) != 0) {
	      dolog(LOG_NOTICE, "%s is not the relay host.",
		    inet_ntoa(sin.sin_addr));
	      SSL_free(newssl);
	      shutdown(newfd, SHUT_RDWR);
	      close(newfd);
	      return 1;
	    }
	    else {
	      relayclient = sin;
	      devfd = newfd;
	      sscanf(key.key, "RELAY %d", &upportnum);
	      FD_SET(devfd, &sfds);
	      if (devfd >= fdcount) {
		fdcount = devfd + 1;
	      }
	      sslRelay = newssl;
	      if (fcntl(devfd, F_SETFL, O_NONBLOCK) < 0)
		die("fcntl(O_NONBLOCK): %s", geterr(errno));
	      createkey();
	      return 0;
	    }
	  }
	  else if (!tipactive) {
	    sslCon = newssl;
	    tipclient = sin;
	    ptyfd = newfd;
	    dolog(LOG_NOTICE, "going to read key" );
	    if ((cc = SSL_read(newssl, (void *)&key, sizeof(key))) <= 0) {
	      ret = cc;
	      close(newfd);
	      dolog(LOG_NOTICE, "%s connecting, error reading capturekey.",
		    inet_ntoa(sin.sin_addr));
	      /*
		{
		FILE * foo = fopen("/tmp/err.txt", "w");
		ERR_print_errors_fp( foo );
		fclose( foo );
		}
	      */
	      close(ptyfd);
	      return 1;
	    }
	  }

	  dolog(LOG_NOTICE, "got key" );
	}
	else 
#endif /* WITHSSL */
	if (!tipactive) {
		tipclient = sin;
		ptyfd = newfd;
	}	

	/*
	 * Is there a better way to do this? I suppose we
	 * could shut the main socket down, and recreate
	 * it later when the client disconnects, but that
	 * sounds horribly brutish!
	 */
	if (tipactive) {
		capret = CAPBUSY;
		if ((cc = write(newfd, &capret, sizeof(capret))) <= 0) {
			dolog(LOG_NOTICE, "%s refusing. error writing status",
			      inet_ntoa(tipclient.sin_addr));
		}
		dolog(LOG_NOTICE, "%s connecting, but tip is active",
		      inet_ntoa(tipclient.sin_addr));
		
		close(newfd);
		return 1;
	}
	/* Verify size of the key is sane */
	if (cc != sizeof(key) ||
	    key.keylen != strlen(key.key) ||
	    strncmp(secretkey.key, key.key, key.keylen)) {
		/*
		 * Tell the other side that their key is bad.
		 */
		capret = CAPNOPERM;
#ifdef WITHSSL
		if (sslCon != NULL) {
		    if ((cc = SSL_write(sslCon, (void *)&capret, sizeof(capret))) <= 0) {
		        dolog(LOG_NOTICE, "%s connecting, error perm status",
			      inet_ntoa(tipclient.sin_addr));
		    }
		} else
#endif /* WITHSSL */
		{
		    if ((cc = write(ptyfd, &capret, sizeof(capret))) <= 0) {
		        dolog(LOG_NOTICE, "%s connecting, error perm status",
			      inet_ntoa(tipclient.sin_addr));
		    }
		}
		close(ptyfd);
		dolog(LOG_NOTICE,
		      "%s connecting, secret key does not match",
		      inet_ntoa(tipclient.sin_addr));
		return 1;
	}
#ifndef SAFEMODE
	/* Do not spit this out into a public log file */
	dolog(LOG_INFO, "Key: %d: %s",
	      secretkey.keylen, secretkey.key);
#endif

	/*
	 * Tell the other side that all is okay.
	 */
	capret = CAPOK;
#ifdef WITHSSL
	if (sslCon != NULL) {
	    if ((cc = SSL_write(sslCon, (void *)&capret, sizeof(capret))) <= 0) {
		close(ptyfd);
		dolog(LOG_NOTICE, "%s connecting, error writing status",
		      inet_ntoa(tipclient.sin_addr));
		return 1;
	    }
	} else
#endif /* WITHSSL */
	{
	    if ((cc = write(ptyfd, &capret, sizeof(capret))) <= 0) {
		close(ptyfd);
		dolog(LOG_NOTICE, "%s connecting, error writing status",
		      inet_ntoa(tipclient.sin_addr));
		return 1;
	    }
	}
	
	/*
	 * See Mike comments (use threads) above.
	 */
	if (fcntl(ptyfd, F_SETFL, O_NONBLOCK) < 0)
		die("fcntl(O_NONBLOCK): %s", geterr(errno));

	FD_SET(ptyfd, &sfds);
	if (ptyfd >= fdcount) {
		fdcount = ptyfd + 1;
	}
	tipactive = 1;
	if (docircbuf) {
		dumpcircbuf();
	}

	dolog(LOG_INFO, "%s connecting", inet_ntoa(tipclient.sin_addr));
	return 0;
}

int
handleupload(void)
{
	int		drop = 0, rc, retval = 0;
	char		buffer[BUFSIZE];

#ifdef WITHSSL
	rc = SSL_read(sslUpload, buffer, sizeof(buffer));
#else
	/* XXX no clue if this is correct */
	rc = read(upfd, buffer, sizeof(buffer));
#endif
	if (rc < 0) {
		if ((errno != EINTR) && (errno != EAGAIN)) {
			drop = 1;
		}
	}
	else if ((upfilesize + rc) > MAX_UPLOAD_SIZE) {
		dolog(LOG_NOTICE, "upload too large");
		drop = 1;
	}
	else if (rc == 0) {
		snprintf(buffer, sizeof(buffer), uploadCommand, uptmpnam);
		dolog(LOG_NOTICE, "upload done");
		drop = 1;
		close(devfd);
		/* XXX run uisp */
		if (system(buffer) != 0)
			warning("upload command failed");
		if (rawmode(Devname, speed))
			die("rawmode failed");
	}
	else {
		int wc;
		if ((wc = write(upfilefd, buffer, rc)) != rc)
			warning("upload short write");
		upfilesize += rc;
	}

	if (drop) {
#ifdef WITHSSL
		SSL_free(sslUpload);
		sslUpload = NULL;
#endif
		FD_CLR(upfd, &sfds);
		close(upfd);
		upfd = -1;
		close(upfilefd);
		upfilefd = -1;
		unlink(uptmpnam);
	}
	
	return retval;
}

/*
 * Generate our secret key and write out the file that local tip uses
 * to do a secure connect.
 */
void
createkey(void)
{
	int			cc, i, fd;
	unsigned char		buf[BUFSIZ];
	char			tmpname[BUFSIZE];
	FILE		       *fp;

	if (relay_snd)
		return;

	/*
	 * Generate the key. Should probably generate a random
	 * number of random bits ...
	 */
	if ((fd = open("/dev/urandom", O_RDONLY)) < 0) {
		syslog(LOG_ERR, "opening /dev/urandom: %m");
		exit(1);
	}
	
	if ((cc = read(fd, buf, DEFAULTKEYLEN)) != DEFAULTKEYLEN) {
		if (cc < 0)
			syslog(LOG_ERR, "Reading random bits: %m");
		else
			syslog(LOG_ERR, "Reading random bits");
		exit(1);
	}
	close(fd);
	
	/*
	 * Convert into ascii text string since that is easier to
	 * deal with all around.
	 */
	secretkey.key[0] = 0;
	for (i = 0; i < DEFAULTKEYLEN; i++) {
		int len = strlen(secretkey.key);
		
		snprintf(&secretkey.key[len],
			 sizeof(secretkey.key) - len,
			 "%x", (unsigned int) buf[i]);
	}
	secretkey.keylen = strlen(secretkey.key);

#ifndef SAFEMODE
	/* Do not spit this out into a public log file */
	dolog(LOG_INFO, "NewKey: %d: %s", secretkey.keylen, secretkey.key);
#endif
	
	/*
	 * First write out the info locally so local tip can connect.
	 * This is still secure in that we rely on unix permission, which
	 * is how most of our security is based anyway.
	 */

	/*
	 * We want to control the mode bits when this file is created.
	 * Sure, could change the umask, but I hate that function.
	 */
	(void) unlink(Aclname);

	/*
	 * Avoid race; open as different name and rename when done.
	 */
	(void) snprintf(tmpname, sizeof(tmpname), "%s.tmp", Aclname);
	
	if ((fd = open(tmpname, O_WRONLY|O_CREAT|O_TRUNC, 0600)) < 0)
		die("%s: open: %s", tmpname, geterr(errno));

	/*
	 * Set owner/group of the new run file. Avoid race in which a
	 * user can get the new file before the chmod, by creating 0600
	 * and doing the chmod after.
	 */
	if (fchown(fd, tipuid, tipgid) < 0)
		die("%s: fchown: %s", Runname, geterr(errno));
	if (fchmod(fd, 0640) < 0)
		die("%s: fchmod: %s", Runname, geterr(errno));
	
	if ((fp = fdopen(fd, "w")) == NULL)
		die("fdopen(%s)", tmpname, geterr(errno));

	fprintf(fp, "host:   %s\n", (insecure ? "localhost" : ourhostname));
	fprintf(fp, "port:   %d\n", portnum);
	if (upportnum > 0) {
		fprintf(fp, "uphost: %s\n", inet_ntoa(relayaddr));
		fprintf(fp, "upport: %d\n", upportnum);
	}
	fprintf(fp, "keylen: %d\n", secretkey.keylen);
	fprintf(fp, "key:    %s\n", secretkey.key);
	fclose(fp);
	if (rename(tmpname, Aclname)) {
		die("%s: rename: %s", Aclname, geterr(errno));
	}

	/*
	 * Send the info over.
	 */
	(void) handshake();
}

/*
 * Contact the boss node and tell it our local port number and the secret
 * key we are using.
 */
static	jmp_buf deadline;
static	int	deadbossflag;

void
deadboss(int sig)
{
	deadbossflag = 1;
	longjmp(deadline, 1);
}

/*
 * Tell the capserver our new secret key, and receive the setup info
 * back (owner/group of the tty/acl/run file). The handshake might be
 * delayed, so we continue to operate, and when we do handshake, set
 * the files properly.
 */
int
handshake(void)
{
	int			sock, cc, err = 0;
	whoami_t		whoami;
	tipowner_t		tipown;

	/*
	 * In standalone, do not contact the capserver.
	 */
	if (standalone || relay_snd)
		return err;

	/*
	 * Global. If we fail, we keep trying from the main loop. This
	 * allows local tip to operate while still trying to contact the
	 * server periodically so remote tip can connect.
	 */
	needshake = 1;

	/*
	 * Don't do this if a local tip session is active. Typically, it
	 * means something is wrong, and that it would be a bad idea to
	 * interrupt a tip session without a potentially blocking operation,
	 * as that would really annoy the user. When the tip goes inactive,
	 * we will try again normally. 
	 */
	if (tipactive)
	    return 0;

	/* Our whoami info. */
	strcpy(whoami.name, Machine);
	whoami.portnum = portnum;
	memcpy(&whoami.key, &secretkey, sizeof(secretkey));

	sock = socket(AF_INET, SOCK_STREAM, 0);
	if (sock < 0) {
		die("socket(): %s", geterr(errno));
	}

	/*
	 * Bind to a reserved port so that capserver can verify integrity
	 * of the sender by looking at the port number. The actual port
	 * number does not matter.
	 */
	if (bindresvport(sock, NULL) < 0) {
		warning("Could not bind reserved port");
		close(sock);
		return -1;
	}

	/* For alarm. */
	deadbossflag = 0;
	signal(SIGALRM, deadboss);
	if (setjmp(deadline)) {
		alarm(0);
		signal(SIGALRM, SIG_DFL);
		warning("Timed out connecting to %s", Bossnode);
		close(sock);
		return -1;
	}
	alarm(5);

	if (connect(sock, (struct sockaddr *)&Bossaddr, sizeof(Bossaddr)) < 0){
		warning("connect(%s): %s", Bossnode, geterr(errno));
		err = -1;
		close(sock);
		goto done;
	}

	if ((cc = write(sock, &whoami, sizeof(whoami))) != sizeof(whoami)) {
		if (cc < 0)
			warning("write(%s): %s", Bossnode, geterr(errno));
		else
			warning("write(%s): Failed", Bossnode);
		err = -1;
		close(sock);
		goto done;
	}
	
	if ((cc = read(sock, &tipown, sizeof(tipown))) != sizeof(tipown)) {
		if (cc < 0)
			warning("read(%s): %s", Bossnode, geterr(errno));
		else
			warning("read(%s): Failed", Bossnode);
		err = -1;
		close(sock);
		goto done;
	}
	close(sock);

	/*
	 * Now that we have owner/group info, set the runfile and aclfile.
	 */
	tipuid = tipown.uid;
	tipgid = tipown.gid;

	/*
	 * Watch for bogus values, I have seen this happen and it throws
	 * everything out of whack. I have a theory, but its too sketchy
	 * to even mention.
	 */
	if ((int)tipuid < 0 || (int)tipuid > 0x1000 * 128) {
		warning("Whacky value for Owner: %d", tipuid);
		tipuid = tipgid = 0;
		err = -1;
		close(sock);
		goto done;
	}
	if ((int)tipgid < 0 || (int)tipgid > 0x1000 * 128) {
		warning("Whacky value for Group: %d", tipgid);
		tipuid = tipgid = 0;
		err = -1;
		close(sock);
		goto done;
	}
	
	if (runfile && chown(Runname, tipuid, tipgid) < 0)
		die("%s: chown: %s", Runname, geterr(errno));

	if (chown(Aclname, tipuid, tipgid) < 0)
		die("%s: chown: %s", Aclname, geterr(errno));

	dolog(LOG_INFO,
	      "Handshake complete. Owner %d, Group %d", tipuid, tipgid);
	needshake = 0;

 done:
	alarm(0);
	signal(SIGALRM, SIG_DFL);
	return err;
}

#ifdef WITH_TELNET
#include <libtelnet.h>

/* XXX from telnet-client, no clue if this is the right set, will find out */
static const telnet_telopt_t telopts[] = {
        { TELNET_TELOPT_ECHO,           TELNET_WONT, TELNET_DONT },
        { TELNET_TELOPT_TTYPE,          TELNET_WONT, TELNET_DONT },
        { TELNET_TELOPT_COMPRESS2,      TELNET_WONT, TELNET_DONT },
        { TELNET_TELOPT_MSSP,           TELNET_WONT, TELNET_DONT },
        { -1, 0, 0 }
};
static telnet_t *telnet;

static void
proto_telnet_callback(telnet_t *telnet, telnet_event_t *ev, void *data)
{
	if (debug > 1)
		fprintf(stderr, "%s: telnet: got event %d\n",
			Machine, ev->type);
	switch (ev->type) {
	/* got data from remote server, send to user and logfile */
	case TELNET_EV_DATA:
		if (tipactive) {
			if (debug > 1)
				fprintf(stderr, "%s: telnet: "
					"sending %d bytes to client\n",
					Machine, ev->data.size);
			send_to_client(ev->data.buffer, ev->data.size);
		}
		send_to_logfile(ev->data.buffer, ev->data.size);
		break;
	/* got data from user, send to remote server */
	case TELNET_EV_SEND:
		if (debug > 1)
			fprintf(stderr, "%s: telnet: "
				"sending %d bytes to server\n",
				Machine, ev->data.size);
		send_to_device(ev->data.buffer, ev->data.size);
		break;

	case TELNET_EV_WILL:
	case TELNET_EV_WONT:
	case TELNET_EV_DO:
	case TELNET_EV_DONT:
	case TELNET_EV_TTYPE:
	case TELNET_EV_SUBNEGOTIATION:
		if (debug > 1)
			fprintf(stderr, "%s: telnet: "
				"ignoring telnet event %d\n",
				Machine, ev->type);
		break;

	/* error */
	case TELNET_EV_ERROR:
		die("%s: telnet: %s", Machine, ev->error.msg);
		break;

	default:
		die("%s: telnet: got unknown telnet event %d",
		    Machine, ev->type);
		break;
	}
}

static inline void
proto_telnet_send_to_client(char *buf, int cc)
{
	telnet_recv(telnet, buf, cc);
}

static inline void
proto_telnet_send_to_device(char *buf, int cc)
{
	telnet_send(telnet, buf, cc);
}

static void
proto_telnet_init(void)
{
	telnet = telnet_init(telopts, proto_telnet_callback, 0, NULL);
	if (telnet == NULL)
		die("no memory for telnet struct");
	if (debug)
		fprintf(stderr,
			"%s: connected to telnet-based server at %s\n",
			Machine, Devname);
}

#endif

/*
 * Store last output in a circular buffer so we can return it
 * at connect. Nice to provide some context. But we simplify this
 * by not storing any data when there is a connection, only when
 * no one is listening. Then on connection, dump the contents of
 * the buffer and reset back to the beginning. 
 */
#define CIRCBUFSIZE (8 * 1024)
char *circp;    // Next place to write.
int  circcount; // How much in the buffer.
char *circbuf;

void
initcircbuf()
{
	circbuf = calloc(1, CIRCBUFSIZE);
	if (! circbuf) {
		die("Could not allocate circbuf");
	}
	circp = circbuf;
}

void
clearcircbuf()
{
	circp = circbuf;
	circcount = 0;
}

void
addtocircbuf(const char *bp, int cc)
{
	char	*ep = circbuf + CIRCBUFSIZE;

	if (!docircbuf)
		return;
	
	while (cc) {
		*circp++ = *bp++;
		if (circp == ep) {
			circp = circbuf;
		}
		if (circcount < CIRCBUFSIZE) {
			circcount++;
		}
		cc--;
	}
}

void
dumpcircbuf()
{
	if (! (circcount && docircbuf))
		return;
	
	if (circcount < CIRCBUFSIZE) {
		send_to_client(circbuf, circcount);
	}
	else {
		int cc = CIRCBUFSIZE - (circp - circbuf);
		send_to_client(circp, cc);
		send_to_client(circbuf, circcount - cc);
	}
	// Reset to empty for next time we disconnect.
	clearcircbuf();
}
#endif /* USESOCKBUF */
