/*
 * Copyright (c) 2010-2018 University of Utah and the Flux Group.
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
 * Client-side program for uploading a file/image via the
 * frisbee master server.
 */
#include <sys/types.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <setjmp.h>
#include "decls.h"
#include "utils.h"
#include "uploadio.h"

static char *mshost = "boss";
static struct in_addr msip;
static in_port_t msport = MS_PORTNUM;

static struct in_addr serverip;
static char *imageid;
static int askonly;
static char *uploadpath;
static uint64_t filesize;
static uint32_t mtime;
static int bufsize = (64 * 1024);;
static int timeout = -1;
static int idletimeout = 0;
static int usessl = 0;
static int verify = 1;
static in_addr_t proxyip = 0;
static int dots = 0;

/* Globals */
int debug = 0;
int portnum;
int sockbufsize = SOCKBUFSIZE;

/* XXX not used but needed by network.c */
struct in_addr	mcastaddr;
struct in_addr	mcastif;

static void usage(void);
static void parse_args(int argc, char **argv);
static int send_file(void);

int
main(int argc, char **argv)
{
	PutReply reply;
	int timo, rv;

	parse_args(argc, argv);
	ClientLogInit();

	/*
	 * Set a timeout for talking to the master server.
	 * Use the idletimout if explicitly set (>0),
	 * otherwise use the overall timeout if explicitly set (>0),
	 * otherwise the overall timeout is based on image size and
	 *   we may not know that, so just pick a big number!
	 *
	 * XXX The current master server is single-threaded and waits for a
	 * couple of seconds after spawning a worker process to see if it
	 * dies immediately. So what might seem like a reasonable delay of 5
	 * seconds really isn't if there are even three requests in the
	 * master server queue ahead of us!
	 */
	if (idletimeout > 0)
		timo = idletimeout;
	else if (timeout > 0)
		timo = timeout;
	else
		timo = 60; /* XXX */

	/* Special case: streaming from stdin */
	if (strcmp(uploadpath, "-") == 0) {
		filesize = 0;
		mtime = 0;
		if (timeout == -1)
			timeout = 0;
		/*
		 * Even more special:
		 *
		 * If we are piping in from an imagezip, it can take
		 * considerable time to start cranking out the image,
		 * in particular if we are checking/computing a signature.
		 * So don't start the server timeout ticking until we have
		 * some data to send.
		 *
		 * But first we do make an immediate query of the image to
		 * ensure it is accessible and attempt to prevent the writer
		 * of the pipe from doing a whole lotta work and then finding
		 * out it was all for naught. Note however that for this to
		 * work, we have to actively inform (i.e., signal) the other
		 * process. Just exiting is not enough since the writer won't
		 * notice that we have exited until it tries to write the
		 * pipe; i.e., until it has done all that work we were trying
		 * to have it avoid!
		 *
		 * So we make the query, sending a SIGPIPE to our process
		 * group if there is an error. We then select on the pipe
		 * and wait til it has something to offer. Only then will
		 * we continue and make the official PUT request and start
		 * the server timeout ticking.
		 */
		if (imageid && !askonly) {
			fd_set set;

			if (!ClientNetPutRequest(ntohl(msip.s_addr), msport,
						 proxyip, imageid, filesize, mtime,
						 0, 1, timo, &reply))
				FrisFatal("Could not get upload info for '%s'",
					  imageid);
			if (reply.error) {
#if 0	/* XXX bad idea as this will kill any wrapper script too */
				/*
				 * Try SIGPIPE-ing our process group to
				 * see if we can actively kill off the
				 * writer (who otherwise won't notice we
				 * have exited until it goes to write the
				 * pipe. This may fail if we are not running
				 * as root and the writer is running as
				 * another uid.
				 */
				signal(SIGPIPE, SIG_IGN);
				kill(0, SIGPIPE);
#endif
				FrisFatal("%s: server returned error: %s",
					  imageid, GetMSError(reply.error));
			}

			fprintf(stderr, "Upload from stdin, "
				"waiting for data availability...\n");
			FD_ZERO(&set);
			FD_SET(STDIN_FILENO, &set);
			(void) select(1, &set, NULL, NULL, NULL);
			fprintf(stderr, "...data ready, continuing.\n");
		}
	}
	/* otherwise make sure file exists and see how big it is */
	else {
		struct stat sb;

		if (stat(uploadpath, &sb))
			FrisPfatal(uploadpath);
		if (!S_ISREG(sb.st_mode))
			FrisFatal("%s: not a regular file\n", uploadpath);
		filesize = sb.st_size;
		mtime = (uint32_t)sb.st_mtime;

		/* overall timeout is a function of file size */
		if (timeout == -1) {
			timeout = (int)(filesize / MIN_UPLOAD_RATE);
			/* file is stupid-huge, no timeout */
			if (timeout < 0)
				timeout = 0;
			/* impose a minimum reasonable time */
			else if (timeout < 10)
				timeout = 10;
		}
	}

	/*
	 * No need for connection timeout if it is >= overall timeout.
	 */
	if (idletimeout >= timeout)
		idletimeout = 0;

	if (imageid) {
		int retries = 2;

	again:
		if (!ClientNetPutRequest(ntohl(msip.s_addr), msport, proxyip,
					 imageid, filesize, mtime, timeout,
					 askonly, timo, &reply))
			FrisFatal("Could not get upload info for '%s'",
				  imageid);

		if (askonly) {
			PrintPutInfo(imageid, &reply, 1);
			exit(0);
		}
		if (reply.error) {
			/*
			 * XXX right now the master server returns this if
			 * the uploader dies immediately for any reason;
			 * so we don't know if it is really a transient
			 * condition. So, we give it a couple of retries.
			 * Note that the server will have waited two seconds
			 * before replying to us, so we only wait a couple
			 * of additional seconds.
			 */
			if (reply.error == MS_ERROR_TRYAGAIN && retries > 0) {
				FrisWarning("%s: retrying put...", imageid);
				retries--;
				sleep(2);
				goto again;
			}

			/*
			 * XXX this is a bit of a hack: MS_ERROR_TOOBIG
			 * returns the max allowed size as a courtesy so
			 * we don't have to make a second, status-only call
			 * to find out the max.
			 */
			if (reply.error == MS_ERROR_TOOBIG) {
				uint64_t maxsize;

				maxsize = ((uint64_t)reply.himaxsize << 32) |
					reply.lomaxsize;
				FrisFatal("%s: file too large for server"
					  " (%llu > %llu)",
					  imageid, filesize, maxsize);
			} else
				FrisFatal("%s: server returned error: %s",
					  imageid, GetMSError(reply.error));
		}

		serverip.s_addr = htonl(reply.addr);
		portnum = reply.port;
	} else {
		/*
		 * XXX hack: if no image id, treat -S/-p as address of
		 * image upload server and not the frisbee master server.
		 */
		serverip = msip;
		portnum = msport;

		imageid = "<NONE>";
		verify = 0;
	}
		
	FrisLog("%s: upload to %s:%d from %s",
		imageid, inet_ntoa(serverip), portnum, uploadpath);
	if (idletimeout || timeout)
		FrisLog("%s: using idletimeout=%ds, timeout=%ds\n",
			imageid, idletimeout, timeout);

	rv = send_file();
	
	if (rv == 0 && verify) {
		uint64_t isize = 0;
		uint32_t mt = 0;
		int retries = 3;
		int bad = 1;

		/*
		 * Try a few times to get status.
		 * We sleep first to give the uploader a chance to finish
		 * and get reaped before we ask.
		 */
		while (1) {
			sleep(1);
			if (!ClientNetPutRequest(ntohl(msip.s_addr), msport,
						 proxyip, imageid, 0, 0, 0, 1, timo,
						 &reply)) {
				FrisWarning("%s: status request failed",
					    imageid);
				goto vdone;
			}
			if (reply.error == 0)
				break;

			if (reply.error &&
			    (reply.error != MS_ERROR_TRYAGAIN ||
			     --retries == 0)) {
				FrisWarning("%s: status returned error %s",
					    imageid, GetMSError(reply.error));
				goto vdone;
			}
		}

		/* dpes it exist? */
		if (!reply.exists) {
			FrisWarning("%s: uploaded file does not exist?!",
				    imageid);
			goto vdone;
		}

		/* is it the right size? */
		isize = ((uint64_t)reply.hisize << 32) | reply.losize;
		if (filesize && isize != filesize) {
			FrisWarning("%s: uploaded file is the wrong size: "
				    "%llu bytes but should be %llu bytes",
				    imageid, isize, filesize);
			goto vdone;
		}

		/* signature okay? */
		switch (reply.sigtype) {
		case MS_SIGTYPE_MTIME:
			mt = *(uint32_t *)reply.signature;
			if (mtime && mt != mtime) {
				FrisWarning("%s: uploaded file has wrong mtime: "
					    "%u but should be %u",
					    imageid, mt, mtime);
				goto vdone;
			}
			break;
		default:
			break;
		}

		bad = 0;

	vdone:
		if (bad)
			FrisWarning("%s: uploaded image did not verify!",
				    imageid);
	}

	exit(rv);
}

static void
parse_args(int argc, char **argv)
{
	int ch, mem;

	while ((ch = getopt(argc, argv, "S:p:F:Q:sb:I:T:NP:odk:")) != -1) {
		switch (ch) {
		case 'd':
			debug++;
			break;
		case 'k':
			mem = atoi(optarg);
			if (mem <= 0 || (mem * 1024) > MAXSOCKBUFSIZE)
				sockbufsize = MAXSOCKBUFSIZE;
			else
				sockbufsize = mem * 1024;
			break;
		case 'S':
			mshost = optarg;
			break;
		case 'p':
			msport = atoi(optarg);
			break;
		case 'F':
			imageid = optarg;
			break;
		case 'Q':
			imageid = optarg;
			askonly = 1;
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
			usessl = 1;
			break;
		case 'N':
			verify = 0;
			break;
		case 'P':
		{
			struct in_addr in;

			if (!GetIP(optarg, &in)) {
				fprintf(stderr,
					"Invalid node name '%s' for -P\n",
					optarg);
				exit(1);
			}
			proxyip = ntohl(in.s_addr);
			break;
		}
		case 'o':
			dots++;
			break;
		default:
			break;
		}
	}
	argc -= optind;
	argv += optind;

	if (argc < 1)
		usage();
	uploadpath = argv[0];

	if (!GetIP(mshost, &msip)) {
		fprintf(stderr, "Invalid server name '%s'\n", mshost);
		exit(1);
	}
}

static void
usage(void)
{
	char *usagestr =
    	"usage: upload [options] -F <fileid> <file-to-upload>\n"
        "Upload a file via the frisbee master server.\n"
        "  <fileid> identifies the file/image at the server.\n"
        "  <file-to-upload> is the local path of the file to upload.\n"
	"Options:\n"
	"  -S <IP>      Specify the IP address of the master server.\n"
	"  -p <port>    Specify the port number of the master server.\n"
        "  -b <size>    Specify the IO buffer size to use (64K by default)\n"
        "  -k <size>    Specify the socket buffer size to use (1M by default)\n"
        "  -T <timeout> Time in seconds to wait for the upload to finish.\n"
	"  -Q <fileid>  Use in place of -F to just ask the server about\n"
        "               the indicated file (image). Tells whether the\n"
        "               image location is accessible by the caller.\n"
        "  -N           Do not attempt to verify the upload.\n"
    	"  -s           Use encryption.\n\n"
        "or:\n\n"
        "upload [options] -S <server> -p <port> <file-to-upload>\n"
        "Upload without using the master server. Here -S and -p identify\n"
        "the actual upload daemon rather than the master server.\n"
        "That daemon must be started manually in advance.\n"
	"Options:\n"
        "  -b <size>    Specify the IO buffer size to use (64K by default)\n"
        "  -k <size>    Specify the socket buffer size to use (1M by default)\n"
        "  -T <timeout> Time in seconds to wait for the upload to finish.\n"
    	"  -s           Use encryption.\n\n"
    	"\n\n";
    	fprintf(stderr, "Frisbee upload/download client\n%s", usagestr);
	exit(1);
}

static struct timeval sstamp;

static void
dodots(ssize_t cc)
{
	static uint64_t total;
	static int lastmb, dotcol;
	struct timeval estamp;
	int count, newmb;

	if (cc < 0) {
		while (dotcol++ <= 66)
			fputc(' ', stderr);

		gettimeofday(&estamp, 0);
		estamp.tv_sec -= sstamp.tv_sec;
		fprintf(stderr, "%4ld %6u\n",
			(long)estamp.tv_sec, (unsigned)(total / 1000000));
	}

	total += cc;
	newmb = (total + cc) / 1000000;
	if ((count = newmb - lastmb) <= 0)
		return;
	lastmb = newmb;

	while (count-- > 0) {
		fputc('.', stderr);
		if (dotcol++ > 65) {
			gettimeofday(&estamp, 0);
			estamp.tv_sec -= sstamp.tv_sec;
			fprintf(stderr, "%4ld %6u\n",
				(long)estamp.tv_sec,
				(unsigned)(total / 1000000));
			dotcol = 0;
		}
	}

}

static sigjmp_buf toenv, bpenv;

static void
send_signal(int sig)
{
	if (sig == SIGALRM)
		siglongjmp(toenv, 1);
	if (sig == SIGPIPE)
		siglongjmp(bpenv, 1);
}

/*
 * XXX multithread (file read, socket write)
 */
static int
send_file(void)
{
	/* volatiles are for setjmp/longjmp */
	conn * volatile conn = NULL;
	char * volatile rbuf = NULL;
	volatile int fd = -1;
	volatile uint64_t remaining = filesize;
	struct timeval et;
	int rv = 1;
	char *stat;

	gettimeofday(&sstamp, NULL);

	if (timeout > 0) {
		struct itimerval it;

		if (sigsetjmp(toenv, 1)) {
			signal(SIGALRM, SIG_DFL);
			rv = 2;
			goto done;
		}
		it.it_value.tv_sec = timeout;
		it.it_value.tv_usec = 0;
		it.it_interval.tv_sec = it.it_interval.tv_usec = 0;

		signal(SIGALRM, send_signal);
		setitimer(ITIMER_REAL, &it, NULL);
	}

	rbuf = malloc(bufsize);
	if (rbuf == NULL) {
		FrisError("Could not allocate %d byte buffer, try using -b",
			  bufsize);
		goto done;
	}

	if (strcmp(uploadpath, "-") == 0)
		fd = STDIN_FILENO;
	else
		fd = open(uploadpath, O_RDONLY);
	if (fd < 0) {
		FrisPwarning(uploadpath);
		goto done;
	}

	/*
	 * Catch broken pipe so we can report gracefully
	 */
	signal(SIGPIPE, send_signal);
	if (sigsetjmp(bpenv, 1)) {
		signal(SIGPIPE, SIG_DFL);
		rv = 3;
		goto done;
	}

	conn = conn_open(ntohl(serverip.s_addr), portnum, usessl,
			 idletimeout, idletimeout);
	if (conn == NULL) {
		FrisError("Could not open connection with server %s:%d",
			  inet_ntoa(serverip), portnum);
		goto done;
	}

	while (filesize == 0 || remaining > 0) {
		ssize_t cc, ncc;

		if (filesize == 0 || remaining > bufsize)
			cc = bufsize;
		else
			cc = remaining;
		ncc = read(fd, rbuf, cc);
		if (ncc < 0) {
			FrisPwarning("file read");
			goto done;
		}
		if (ncc == 0)
			break;

		cc = conn_write(conn, rbuf, ncc);
		if (cc < 0) {
			FrisPwarning("socket write");
			goto done;
		}
		remaining -= cc;
		if (dots)
			dodots(cc);
		if (cc != ncc) {
			if (conn_timeout(conn))
				FrisError("short write on socket (%d != %d) "
					  "due to write timeout",
					  cc, ncc);
			else
				FrisError("short write on socket (%d != %d)",
					  cc, ncc);
			goto done;
		}
	}
	if (filesize == 0 || remaining == 0)
		rv = 0;

 done:
	gettimeofday(&et, NULL);
	if (timeout) {
		struct itimerval it;

		it.it_value.tv_sec = it.it_value.tv_usec = 0;
		setitimer(ITIMER_REAL, &it, NULL);
		signal(SIGALRM, SIG_DFL);
	}
	signal(SIGPIPE, SIG_DFL);

	if (dots)
		dodots(-1);
	if (conn != NULL)
		conn_close(conn);
	if (fd >= 0)
		close(fd);
	if (rbuf != NULL)
		free(rbuf);

	timersub(&et, &sstamp, &et);

	switch (rv) {
	case 0:
		stat = "completed";
		break;
	case 1:
		stat = "terminated";
		break;
	case 2:
		stat = "timed-out";
		break;
	case 3:
		stat = "failed (server disconnected)";
		break;
	default:
		stat = "UNKNOWN";
		break;
	}

	/* Note that remaining will be negative if filesize==0 */
	if (filesize && remaining)
		FrisLog("%s: upload %s after %llu (of %llu) bytes "
			"in %d.%03d seconds",
			imageid, stat, filesize-remaining, filesize,
			et.tv_sec, et.tv_usec/1000);
	else
		FrisLog("%s: upload %s after %llu bytes in %d.%03d seconds",
			imageid, stat, filesize-remaining,
			et.tv_sec, et.tv_usec/1000);

	/* Set filesize to bytes written so verify has something to check */
	if (verify && rv == 0 && filesize == 0)
		filesize = filesize - remaining;

	return rv;
}
