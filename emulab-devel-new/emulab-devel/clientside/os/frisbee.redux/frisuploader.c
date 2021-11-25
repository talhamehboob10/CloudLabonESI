/*
 * Copyright (c) 2010-2020 University of Utah and the Flux Group.
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
 * Server-side for uploading of frisbee images.
 * Invoked by the frisbee master server.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/time.h>
#include <setjmp.h>
#include "decls.h"
#include "uploadio.h"

static struct in_addr clientip;
static struct in_addr clientif;
static char *path;
static uint64_t maxsize = 0;
static int bufsize = (64 * 1024);;
static int timeout = 0;
static int idletimeout = 0;
static int sock = -1;
static char *addrfilename;

/* Globals */
int debug = 0;
int portlo = -1;
int porthi;
int portnum;
int sockbufsize = SOCKBUFSIZE;

static void usage(void);
static void parse_args(int argc, char **argv);
static void net_init(void);
static int recv_file(void);

int
main(int argc, char **argv)
{
	int rv;

	parse_args(argc, argv);
	UploadLogInit();

	net_init();

	FrisLog("%s: listening as %d/%d on port %d for image data from %s (max of %llu bytes)",
		path, geteuid(), getegid(), portnum, inet_ntoa(clientip), maxsize);
	if (idletimeout || timeout)
		FrisLog("%s: using idletimeout=%ds, timeout=%ds",
			path, idletimeout, timeout);

	rv = recv_file();
	close(sock);

	exit(rv);
}

static void
parse_args(int argc, char **argv)
{
	int ch, mem;

	while ((ch = getopt(argc, argv, "m:p:i:b:I:T:s:A:dk:")) != -1) {
		switch (ch) {
		case 'd':
			debug++;
			break;
		case 'm':
			if (!inet_aton(optarg, &clientip)) {
				fprintf(stderr, "Invalid client IP '%s'\n",
					optarg);
				exit(1);
			}
			break;
		case 'k':
			mem = atoi(optarg);
			if (mem <= 0 || (mem * 1024) > MAXSOCKBUFSIZE)
				sockbufsize = MAXSOCKBUFSIZE;
			else
				sockbufsize = mem * 1024;
			break;
		case 'p':
			if (strchr(optarg, '-')) {
				char *h = strchr(optarg, '-');
				*h = '\0';
				portlo = atoi(optarg);
				porthi = atoi(h+1);
				*h = '-';
				if (portlo < 0 || portlo > 65535 ||
				    porthi < 0 || porthi > 65535 ||
				    portlo > porthi)
					usage();
			} else {
				portlo = atoi(optarg);
				porthi = portlo;
				if (portlo < 0 || portlo > 65535)
					usage();
			}
			break;
		case 'i':
			if (!inet_aton(optarg, &clientif)) {
				fprintf(stderr, "Invalid client iface IP '%s'\n",
					optarg);
				exit(1);
			}
			break;
		case 'b':
			bufsize = atoi(optarg);
			if (bufsize < 0 || bufsize > MAX_BUFSIZE) {
				fprintf(stderr, "Invalid buffer size %d\n",
					bufsize);
				exit(1);
			}
			break;
		case 'I':
			idletimeout = atoi(optarg);
			if (idletimeout < 0 || idletimeout > (24 * 60 * 60)) {
				fprintf(stderr, "Invalid idle timeout %d\n",
					idletimeout);
				exit(1);
			}
			break;
		case 'T':
			timeout = atoi(optarg);
			if (timeout < 0 || timeout > (24 * 60 * 60)) {
				fprintf(stderr, "Invalid timeout %d\n",
					timeout);
				exit(1);
			}
			break;
		case 's':
			maxsize = strtoull(optarg, NULL, 0);
			break;
		case 'A':
			addrfilename = optarg;
			break;
		default:
			break;
		}
	}
	argc -= optind;
	argv += optind;

	if (clientip.s_addr == 0 || portlo < 0 || argc < 1)
		usage();
	/*
	 * If both timeouts are set, make sure they play nice
	 */
	if (idletimeout > 0 && timeout > 0) {
		/* idletimeout should be <= timeout */
		if (idletimeout > timeout)
			idletimeout = timeout;
		/* if the are equal, no need for the idletimeout */
		if (idletimeout == timeout)
			idletimeout = 0;
	}

	path = argv[0];
}

static void
usage(void)
{
	char *usagestr =
    	"\nusage: frisuploader [-i iface] [-T timo] [-k size] [-s maxsize] -m IP -p port outfile\n"
        "Upload a file from client identified by <IP>:<port> and save to <outfile>.\n"
	"Options:\n"
        "<outfile>      File to save the uploaded data into.\n"
	"               Will be created or truncated as necessary.\n"
	"  -m <addr>    Unicast IP address of client to upload from.\n"
	"  -p <port>    TCP port number on which to listen for client.\n"

	"  -i <iface>   Interface on which to listen (specified by local IP).\n"
	"  -I <timo>    Max time (in seconds) to allow connect to be idle (no traffic from client).\n"
	"  -T <timo>    Max time (in seconds) to wait for upload to complete.\n"
    	"  -k <size>    Specify the socket buffer size to use (1M by default)\n"
    	"  -s <size>    Maximum amount of data (in bytes) to upload.\n"
    	"\n\n";
    	
    	fprintf(stderr, "Frisbee upload/download client%s", usagestr);
	exit(1);
}

static sigjmp_buf toenv;

static void
recv_timeout(int sig)
{
	siglongjmp(toenv, 1);
}

/*
 * Receive a file.
 * If 'maxsize' is 0, then we read til EOF. Otherwise it indicates the
 * maximum size we are willing to receive. Returns a designated UE_*
 * exit code.
 *
 * XXX multithread (socket read, file write)
 */
static int
recv_file()
{
	/* volatiles are for setjmp/longjmp */
	conn * volatile conn = NULL;
	char * volatile wbuf = NULL;
	volatile int fd = -1;
	volatile uint64_t remaining = maxsize;
	struct timeval st, et;
	int rv = UE_OTHER;
	char *stat;

	gettimeofday(&st, NULL);	/* XXX for early errors */

	/*
	 * If a maximum size was specified, allow us to read slightly more
	 * than that in order to correctly identify exceeding that limit.
	 */
	if (maxsize)
		remaining += 1;

	/*
	 * If we have an overall timeout (timeout > 0) then just set the
	 * alarm to that and we will longjmp if we hit it.
	 *
	 * Idletimeout are handled by the connection.
	 */
	if (timeout > 0) {
		struct itimerval it;

		if (sigsetjmp(toenv, 1)) {
			rv = UE_TOOLONG;
			goto done;
		}
		it.it_value.tv_sec = timeout;
		it.it_value.tv_usec = 0;
		it.it_interval.tv_sec = it.it_interval.tv_usec = 0;
		signal(SIGALRM, recv_timeout);
		setitimer(ITIMER_REAL, &it, NULL);
	}

	wbuf = malloc(bufsize);
	if (wbuf == NULL) {
		FrisError("Could not allocate %d byte buffer, try using -b",
			  bufsize);
		goto done;
	}

	if (strcmp(path, "-") == 0)
		fd = STDOUT_FILENO;
	else
		fd = open(path, O_WRONLY|O_CREAT|O_TRUNC, 0644);
	if (fd < 0) {
		FrisPwarning(path);
		rv = UE_FILEERR;
		goto done;
	}

	conn = conn_accept_tcp(sock, &clientip, idletimeout, idletimeout);
	if (conn == NULL) {
		FrisError("Error accepting from %s", inet_ntoa(clientip));
		rv = UE_CONNERR;
		goto done;
	}
	FrisLog("%s: upload from %s started", path, inet_ntoa(clientip));

	gettimeofday(&st, NULL);
	while (maxsize == 0 || remaining > 0) {
		ssize_t cc, ncc;

		if (maxsize == 0 || remaining > bufsize)
			cc = bufsize;
		else
			cc = remaining;
		ncc = conn_read(conn, wbuf, cc);
		if (ncc < 0) {
			FrisPwarning("socket read");
			rv = UE_CONNERR;
			goto done;
		}
		if (ncc == 0)
			break;

		cc = write(fd, wbuf, ncc);
		if (cc < 0) {
			FrisPwarning("file write");
			switch (errno) {
			case EFBIG:
			case ENOSPC:
			case EDQUOT:
				rv = UE_NOSPACE;
				break;
			default:
				rv = UE_FILEERR;
				break;
			}
			goto done;
		}
		remaining -= cc;
		if (cc != ncc) {
			FrisError("short write on file (%d != %d)", cc, ncc);
			rv = UE_FILEERR;
			goto done;
		}
	}
	/*
	 * If a maxsize was specified and remaining is zero, then we have
	 * read slightly more than was allowed and we signal a maxsize
	 * exceeded error.
	 */
	if (maxsize && remaining == 0)
		rv = UE_TOOBIG;
	/*
	 * Otherwise, coming up short (maxsize == 0 or remaining > 0)
	 * is not an error unless we timed out.
	 */
	else if (conn_timeout(conn))
		rv = UE_TOOLONG;
	else
		rv = UE_NOERROR;

 done:
	gettimeofday(&et, NULL);

	if (timeout) {
		struct itimerval it;

		it.it_value.tv_sec = it.it_value.tv_usec = 0;
		setitimer(ITIMER_REAL, &it, NULL);

	}
	if (conn != NULL)
		conn_close(conn);
	if (fd >= 0) {
		if (rv == 0 && fsync(fd) != 0) {
			perror(path);
			rv = UE_FILEERR;
		}
		close(fd);
	}
	if (wbuf != NULL)
		free(wbuf);

	timersub(&et, &st, &et);

	if (maxsize && remaining)
		remaining -= 1;

	switch (rv) {
	case UE_NOERROR:
		stat = "completed";
		break;
	case UE_OTHER:
		stat = "terminated";
		break;
	case UE_TOOLONG:
		stat = "timed-out";
		break;
	case UE_TOOBIG:
		stat = "exceeded max size";
		break;
	case UE_NOSPACE:
		stat = "exceeded quota";
		break;
	case UE_CONNERR:
		stat = "connection error";
		break;
	case UE_FILEERR:
		stat = "image file error";
		break;
	}
	if (maxsize && remaining)
		FrisLog("%s: upload %s after %llu (of max %llu) bytes "
			"in %d.%03d seconds",
			path, stat, maxsize-remaining, maxsize,
			et.tv_sec, et.tv_usec/1000);
	else
		FrisLog("%s: upload %s after %llu bytes in %d.%03d seconds",
			path, stat, maxsize-remaining,
			et.tv_sec, et.tv_usec/1000);

	/* XXX unlink file on error? */
	return rv;
}

/*
 * It would be nice to use some of the infrastructure in network.c,
 * but ServerNetInit only sets up UDP sockets. Maybe when we revisit
 * and refactor...
 */
#define MAXBINDATTEMPTS 1

/*
 * This is straight out of network.c
 *
 * Bind one port from the given range.
 * If lo == hi == 0, then we let the kernel choose.
 * If lo == hi != 0, then we must get that port.
 * Otherwise we loop over the range til we get one.
 * Returns the port bound or 0 if unsuccessful.
 */
static in_port_t
BindPort(in_addr_t addr, in_port_t portlo, in_port_t porthi)
{
	int i;
	struct sockaddr_in name;
	socklen_t sl = sizeof(name);

	name.sin_family      = AF_INET;
	name.sin_addr.s_addr = htonl(addr);
	name.sin_port        = htons(portlo);

	/*
	 * Let the kernel choose.
	 */
	if (portlo == 0) {
		if (bind(sock, (struct sockaddr *)&name, sl) != 0)
			return 0;

		if (getsockname(sock, (struct sockaddr *)&name, &sl) < 0)
			FrisPfatal("could not determine bound port");
		return(ntohs(name.sin_port));
	}
	
	/*
	 * Specific port. Try a few times to get it.
	 */
	if (portlo == porthi) {
		i = MAXBINDATTEMPTS;

		while (i) {
			if (bind(sock, (struct sockaddr *)&name, sl) == 0)
				return portlo;

			if (--i) {
				FrisPwarning("Bind to %s:%d failed. "
					     "Will try %d more times!",
					     inet_ntoa(name.sin_addr),
					     portlo, i);
				sleep(5);
			}
		}
		return 0;
	}

	/*
	 * Port range, gotta loop through trying to grab one.
	 */
	while (portlo <= porthi) {
		name.sin_port = htons(portlo);
		if (bind(sock, (struct sockaddr *)&name, sl) == 0)
			return portlo;
		portlo++;
	}

	return 0;
}


static void
net_init(void)
{
	if ((sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0)
		FrisPfatal("Could not allocate socket");

	portnum = BindPort(ntohl(clientif.s_addr), portlo, porthi);
	if (portnum == 0) {
		FrisError("Could not bind to %s:%u",
			  inet_ntoa(clientif), portlo);
		close(sock);
		/*
		 * We reproduce ServerNetInit behavior here: if we cannot
		 * bind to the indicated port we exit with a special status
		 * so that the master server which invoked us can pick
		 * another.
		 */
		exit(portlo ? EADDRINUSE : -1);
	}
	if (listen(sock, 128) < 0) {
		close(sock);
		FrisPfatal("Could not listen on socket");
	}

	if (addrfilename) {
		/* long enough for XXX.XXX.XXX.XXX:DDDDD\n\0 */
		char ainfo[24];
		int afd, len;

		snprintf(ainfo, sizeof(ainfo), "%s:%u\n",
			 inet_ntoa(clientif), (unsigned)portnum);
		afd = open(addrfilename, O_WRONLY|O_CREAT|O_TRUNC, 0644);
		if (afd < 0)
			FrisPfatal(addrfilename);
		len = strlen(ainfo) + 1;
		if (write(afd, ainfo, len) != len) {
			close(afd);
			unlink(addrfilename);
			FrisFatal("%s: could not write address info\n",
				  addrfilename);
		}
		close(afd);
	}
}
