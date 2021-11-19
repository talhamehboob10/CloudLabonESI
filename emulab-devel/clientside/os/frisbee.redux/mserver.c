/*
 * Copyright (c) 2010-2021 University of Utah and the Flux Group.
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
 * Frisbee master server.  Listen for GET/PUT requests and fork off
 * handler processes.
 * 
 * TODO:
 * - timeouts for child frisbee processes
 * - record the state of running frisbeeds in persistant store so that
 *   they can be restarted if we die and restart
 * - related: make sure we don't leave orphans when we die!
 * - handle signals: INT/TERM should kill all frisbeeds and remove our pid
 */
#include <paths.h>
#include <sys/stat.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <syslog.h>
#include <sys/wait.h>
#include <errno.h>
#include <signal.h>
#include <assert.h>
#ifdef WITH_IGMP
#include <sys/time.h>
#endif
#include "decls.h"
#include "utils.h"
#include "configdefs.h"

#define FRISBEE_SERVER	"/usr/testbed/sbin/frisbeed"
#define FRISBEE_CLIENT	"/usr/testbed/sbin/frisbee"
#define FRISBEE_UPLOAD	"/usr/testbed/sbin/frisuploadd"

/*
 * Given that we use port ranges when invoking the server, and given the
 * way those ranges are calculated, there is no reason to retry more than
 * once to try all possible ports.
 */
#define FRISBEE_RETRIES	1

static void	get_options(int argc, char **argv);
static int	makesocket(int portnum, struct in_addr *ifip, int *tcpsockp);
static void	handle_request(int sock);
static int	reapchildren(int apid, int *status);
#ifdef WITH_IGMP
static void	handle_igmp(void);
#endif
static char *	gidstr(int ngids, gid_t gids[]);

static int	daemonize = 1;
int		debug = 0;
static int	dumpconfig = 0;
static int	onlyrequests = MS_REQUEST_ANY;
static int	onlymethods = (MS_METHOD_UNICAST|MS_METHOD_MULTICAST);
static int	parentmethods = (MS_METHOD_UNICAST|MS_METHOD_MULTICAST);
static int	myuid = NOUID;
static int	mygid = NOUID;

/*
 * For recursively GETing images:
 *   parentip/parentport  address of a parent master server (-S,-P)
 *   fetchfromabove       true if a parent has been specified
 *   canredirect          if true, redirect our clients to our parent (-R)
 *   usechildauth         if true, pass client's authinfo to our parent (-A)
 */
static struct in_addr parentip;
static int	parentport = MS_PORTNUM;
static int	fetchfromabove = 0;
static int	canredirect = 0;
static int	usechildauth = 0;
static int	mirrormode = 0;
static char     *configstyle = "null";
static char	*configopts = "";
static struct in_addr ifaceip;
static int	igmpqueryinterval = 0;

/* XXX the following just keep network.c happy */
int		portnum = MS_PORTNUM;
int		sockbufsize = SOCKBUFSIZE;
struct in_addr	mcastaddr;
struct in_addr	mcastif;

int
main(int argc, char **argv)
{
	int			tcpsock;
	FILE			*fp;
	char			buf[BUFSIZ];
	char			*pidfile = (char *) NULL;
	struct timeval		tv;
	fd_set			ready;
#ifdef USE_LOCALHOST_PROXY
	int			localsock = -1;
#endif

	get_options(argc, argv);

	myuid = geteuid();
	mygid = getegid();

	if (daemonize && debug) {
		int odebug = debug;
		debug = 0;
		MasterServerLogInit();
		debug = odebug;
	} else
		MasterServerLogInit();

	FrisLog("mfrisbeed daemon starting as %d/%d, methods=%s (debug level %d)",
		myuid, mygid, GetMSMethods(onlymethods), debug);
	if (fetchfromabove)
		FrisLog("  using parent %s:%d%s, methods=%s",
			inet_ntoa(parentip), parentport,
			mirrormode ? " in mirror mode" : "",
			GetMSMethods(parentmethods));
#ifdef WITH_IGMP
	if (igmpqueryinterval)
		FrisLog("  acting as IGMP querier on %s with %d second interval",
			inet_ntoa(ifaceip), igmpqueryinterval);
#endif
	config_init(configstyle, 1, configopts);

	/* Just dump the config to stdout in human readable form and exit. */
	if (dumpconfig) {
		config_dump(stdout);
		exit(0);
	}

	/*
	 * Create TCP server.
	 */
	if (makesocket(portnum, &ifaceip, &tcpsock) < 0) {
		FrisError("Could not make primary tcp socket!");
		exit(1);
	}
#ifdef USE_LOCALHOST_PROXY
	/*
	 * Listen on localhost too for proxy requests.
	 */
	if (ifaceip.s_addr != htonl(INADDR_ANY) &&
	    ifaceip.s_addr != htonl(INADDR_LOOPBACK)) {
		struct in_addr localip;
		localip.s_addr = htonl(INADDR_LOOPBACK);
		if (makesocket(portnum, &localip, &localsock) < 0) {
			FrisError("Could not create localhost tcp socket!");
			exit(1);
		}
	}
#endif
#ifdef WITH_IGMP
	if (igmpqueryinterval)
		IGMPInit(&ifaceip, NULL);
#endif

	/* Now become a daemon */
	if (daemonize)
		daemon(0, 0);

	/*
	 * Stash the pid away.
	 */
	if (!geteuid()) {
		if (!pidfile) {
			sprintf(buf, "%s/mfrisbeed.pid", _PATH_VARRUN);
			pidfile = buf;
		}
		fp = fopen(pidfile, "w");
		if (fp != NULL) {
			fprintf(fp, "%d\n", getpid());
			(void) fclose(fp);
		}
	}

	/*
	 * Handle connections
	 */
	FD_ZERO(&ready);
	while (1) {
		struct sockaddr_in client;
		socklen_t length;
		int newsock, rv, maxsock = 0;

#ifdef WITH_IGMP
		/* Do the querier thing */
		if (igmpqueryinterval)
			handle_igmp();
#endif

		FD_SET(tcpsock, &ready);
		maxsock = tcpsock + 1;
#ifdef USE_LOCALHOST_PROXY
		if (localsock >= 0) {
			FD_SET(localsock, &ready);
			if (localsock > tcpsock)
				maxsock = localsock + 1;
		}
#endif
		tv.tv_sec = 0;
		tv.tv_usec = 100000;
		rv = select(maxsock, &ready, NULL, NULL, &tv);
		if (rv < 0) {
			if (errno == EINTR)
				continue;
			FrisPfatal("select failed");
		}
		if (rv) {
			int sock = tcpsock;
#ifdef USE_LOCALHOST_PROXY
			if (localsock >= 0 && FD_ISSET(localsock, &ready))
				sock = localsock;
#endif
			length  = sizeof(client);
			newsock = accept(sock, (struct sockaddr *)&client,
					 &length);
			if (newsock < 0)
				FrisPwarning("accepting TCP connection");
			else {
				fcntl(newsock, F_SETFD, FD_CLOEXEC);
				handle_request(newsock);
				close(newsock);
			}
		}
		(void) reapchildren(0, NULL);
	}
	close(tcpsock);
#ifdef USE_LOCALHOST_PROXY
	if (localsock >= 0)
		close(localsock);
#endif
	FrisLog("daemon terminating");
	exit(0);
}

struct childinfo {
	struct childinfo *next;
	struct config_imageinfo *imageinfo;
	int ptype;
	int method;
	int pid;
	char *pidfile;
	int uid;		/* UID to run child as */
	gid_t gids[MAXGIDS];	/* GID to run child as */
	int ngids;		/* number of GIDs */
	int retries;		/* # times to try starting up child */
	int timeout;		/* max runtime (sec) for child */
	in_addr_t servaddr;	/* -S arg */
	in_addr_t ifaceaddr;	/* -i arg */
	in_addr_t addr;		/* -m arg */
	in_port_t loport, hiport; /* to construct -p arg */
	void (*done)(struct childinfo *, int);
	void *extra;
};
#define PTYPE_CLIENT	1
#define PTYPE_SERVER	2
#define PTYPE_UPLOADER	4

struct clientextra {
	char *realname;
	char *resolvedname;
	/* info from our parent */
	uint16_t sigtype;
	uint8_t signature[MS_MAXSIGLEN];
	uint32_t hisize;
	uint32_t losize;
};

struct uploadextra {
	char *realname;
	uint64_t isize;
	uint32_t mtime;
	int itimeout;
	uint32_t hostip;
};

static int killchild(struct childinfo *);
static struct childinfo *findchild(char *, int, int);
static int getaddrchild(struct childinfo *);
static int startchild(struct childinfo *);
static struct childinfo *startserver(struct config_imageinfo *,
				     in_addr_t, in_addr_t, int, int *);
static struct childinfo *startclient(struct config_imageinfo *,
				     in_addr_t, in_addr_t, in_addr_t,
				     in_port_t, int, int *);
static struct childinfo *startuploader(struct config_imageinfo *,
				       in_addr_t, in_addr_t, uint64_t,
				       uint32_t, int, uint32_t, int *);

static void
free_imageinfo(struct config_imageinfo *ii)
{
	if (ii) {
		if (ii->imageid)
			free(ii->imageid);
		if (ii->dir)
			free(ii->dir);
		if (ii->path)
			free(ii->path);
		if (ii->sig)
			free(ii->sig);
		if (ii->get_options)
			free(ii->get_options);
		if (ii->put_options)
			free(ii->put_options);
		if (ii->put_oldversion)
			free(ii->put_oldversion);
		if (ii->pget_options)
			free(ii->pget_options);
		if (ii->extra)
			free(ii->extra);
		free(ii);
	}
}

/*
 * (Deep) copy an imageinfo structure.
 * Returns pointer or null on error.
 */
static struct config_imageinfo *
copy_imageinfo(struct config_imageinfo *ii)
{
	struct config_imageinfo *nii;
	int i;

	if ((nii = calloc(1, sizeof *nii)) == NULL)
		goto fail;
	if (ii->imageid && (nii->imageid = strdup(ii->imageid)) == NULL)
		goto fail;
	if (ii->dir && (nii->dir = strdup(ii->dir)) == NULL)
		goto fail;
	if (ii->path && (nii->path = strdup(ii->path)) == NULL)
		goto fail;
	if (ii->sig) {
		int sz = 0;
		if (ii->flags & CONFIG_SIG_ISMTIME)
			sz = sizeof(time_t);
		if (sz) {
			if ((nii->sig = malloc(sz)) == NULL)
				goto fail;
		}
		if (nii->sig)
			memcpy(nii->sig, ii->sig, sz);
	}
	nii->flags = ii->flags;
	nii->uid = ii->uid;
	for (i = 0; i < ii->ngids; i++)
		nii->gids[i] = ii->gids[i];
	nii->ngids = ii->ngids;
	if (ii->get_options &&
	    (nii->get_options = strdup(ii->get_options)) == NULL)
		goto fail;
	nii->get_methods = ii->get_methods;
	nii->get_timeout = ii->get_timeout;
	if (ii->put_options &&
	    (nii->put_options = strdup(ii->put_options)) == NULL)
		goto fail;
	nii->put_maxsize = ii->put_maxsize;
	nii->put_timeout = ii->put_timeout;
	nii->put_itimeout = ii->put_itimeout;
	if (ii->put_oldversion &&
	    (nii->put_oldversion = strdup(ii->put_oldversion)) == NULL)
		goto fail;
	if (ii->pget_options &&
	    (nii->pget_options = strdup(ii->pget_options)) == NULL)
		goto fail;
	/* XXX don't care about extra right now */
	return nii;

 fail:
	free_imageinfo(nii);
	return NULL;
}

/*
 * Fetch an image from our parent by getting image info from it and firing
 * off a frisbee.  If canredirect is non-zero, we also hook our child up
 * directly with our parent so that it can fetch in parallel.  If statusonly
 * is non-zero, we just request info from our parent and return that.
 * Returns zero if Reply struct contains the desired info, TRYAGAIN if we
 * have started up a frisbee to fetch from our parent, or an error otherwise.
 * Status is returned in host order.
 */
int
fetch_parent(struct in_addr *myip, struct in_addr *hostip,
	     struct in_addr *pip, in_port_t pport,
	     struct config_imageinfo *ii, int statusonly, GetReply *replyp)
{
	struct childinfo *ci;
	struct clientextra *ce;
	struct in_addr pif;
	in_addr_t authip;
	GetReply reply;
	int rv, methods;

	/*
	 * If usechildauth is set, we pass the child host IP to our parent
	 * for authentication, otherwise we use our own.
	 */
	authip = usechildauth ? ntohl(hostip->s_addr) : 0;

	/*
	 * Allowed image methods are constrained by any parent methods
	 */
	methods = ii->get_methods & parentmethods;
	if (methods == 0)
		return MS_ERROR_NOMETHOD;

	/*
	 * See if a fetch is already in progress.
	 * If so we will either return "try again later" or point them to
	 * our parent.
	 */
	ci = findchild(ii->imageid, PTYPE_CLIENT, methods);
	if (ci != NULL) {
		if (debug)
			FrisInfo("%s: fetch from %s in progress",
				 ii->imageid, inet_ntoa(*pip));

		/*
		 * Since a download is in progress we don't normally need
		 * to revalidate since we wouldn't be downloading the image
		 * if we didn't have access.
		 *
		 * However, when acting for a child, we do need to validate
		 * every time since the child making the current request
		 * might not have the same access as the child we are
		 * currently downloading for.
		 */
		if (authip) {
			if (!ClientNetFindServer(ntohl(pip->s_addr),
						 pport, authip, ii->imageid,
						 methods, 1, 5,
						 &reply, &pif))
				return MS_ERROR_NOIMAGE;
			if (reply.error)
				return reply.error;
		}
		/*
		 * We return the info we got from our parent.
		 */
		assert(ci->extra != NULL);
		ce = ci->extra;

		memset(replyp, 0, sizeof *replyp);
		replyp->sigtype = ce->sigtype;
		memcpy(replyp->signature, ce->signature, MS_MAXSIGLEN);
		replyp->hisize = ce->hisize;
		replyp->losize = ce->losize;
		if (statusonly) {
			if (debug)
				FrisInfo("%s: parent status: "
					 "sigtype=%d, sig=0x%08x..., size=%x/%x",
					 ii->imageid,
					 ce->sigtype, *(uint32_t *)ce->signature,
					 ce->hisize, ce->losize);
			return 0;
		}

		/*
		 * A real get request.
		 * We either tell them to try again later or redirect them
		 * to our parent.
		 */
		goto done;
	}

	if (debug)
		FrisInfo("%s: requesting %simage from %s:%d",
			 ii->imageid, (statusonly ? "status of ": ""),
			 inet_ntoa(*pip), pport);

	/*
	 * Image fetch is not in progress.
	 * Send our parent a GET request and see what it says.
	 */
	if (!ClientNetFindServer(ntohl(pip->s_addr), pport, authip,
				 ii->imageid, methods, statusonly, 5,
				 &reply, &pif))
		return MS_ERROR_NOIMAGE;
	if (reply.error)
		return reply.error;

	/*
	 * Return the image size and signature from our parent
	 */
	memset(replyp, 0, sizeof *replyp);
	replyp->sigtype = reply.sigtype;
	memcpy(replyp->signature, reply.signature, MS_MAXSIGLEN);
	replyp->hisize = reply.hisize;
	replyp->losize = reply.losize;
	if (statusonly) {
		if (debug)
			FrisInfo("%s: parent status: "
				 "sigtype=%d, sig=0x%08x..., size=%x/%x",
				 ii->imageid,
				 reply.sigtype, *(uint32_t *)reply.signature,
				 reply.hisize, reply.losize);
		return 0;
	}

	/*
	 * Parent has started up a frisbeed, spawn a frisbee to capture it.
	 *
	 * Note that servaddr from the reply might not be our parent (pip),
	 * if our parent in turn had to ask its parent and redirect was in
	 * effect.  Unfortunately, in this case, 'pif' might not be correct
	 * since it is always the interface from which our parent responded.
	 * It will work as long as our parent's ancestor(s) reach us via
	 * the same interface.
	 */
	ci = startclient(ii, ntohl(pif.s_addr), reply.servaddr,
			 reply.addr, reply.port, reply.method, &rv);
	if (ci == NULL)
		return rv;

	/*
	 * Cache the size/signature info for use in future calls when
	 * we are busy (the case above).
	 */
	assert(ci->extra != NULL);
	ce = ci->extra;
	ce->sigtype = replyp->sigtype;
	memcpy(ce->signature, replyp->signature, MS_MAXSIGLEN);
	ce->hisize = replyp->hisize;
	ce->losize = replyp->losize;
	if (debug)
		FrisInfo("%s cache status: "
			 "sigtype=%d, sig=0x%08x..., size=%x/%x",
			 ii->imageid,
			 ce->sigtype, *(uint32_t *)ce->signature,
			 ce->hisize, ce->losize);

 done:
	if (!canredirect)
		return MS_ERROR_TRYAGAIN;

	/*
	 * XXX more unicast "fer now" hackary...if we are talking unicast with
	 * our parent, we cannot redirect the child there as well.
	 */
	if (ci->method == MS_METHOD_UNICAST)
		return MS_ERROR_TRYAGAIN;

	memset(replyp, 0, sizeof *replyp);
	replyp->method = ci->method;
	replyp->servaddr = ci->servaddr;
	replyp->addr = ci->addr;
	replyp->port = ci->loport;
	return 0;
}

/*
 * Handle a GET request.
 *
 * This can be either a request to get the actual image (status==0)
 * or a request to get just the status of the image (status==1).
 *
 * A request for the actual image causes us to start up a frisbee server
 * for the image if one is not already running.  If we are configured with
 * a parent, we may need to first fetch the image from our parent with a
 * GET request.  In this case, we may return a TRYAGAIN status while the
 * image transfer is in progress. Alternatively, if we are configured to
 * allow redirection, we could just point our client to our parent and allow
 * them to download the image along side us.
 *
 * A request for status will not fire up a server, but may require a status
 * call on our parent.  A status call will never return TRYAGAIN, it will
 * always return the most recent status for an image or some other error.
 * If we have a parent, we will always get its status for the image and
 * return that if "newer" than ours. Thus status is a synchronous call that
 * will return the attributes of the image that will ultimately be transferred
 * to the client upon a GET request.
 */
void
handle_get(int sock, struct sockaddr_in *sip, struct sockaddr_in *cip,
	   MasterMsg_t *msg)
{
	struct in_addr host;
	char imageid[MS_MAXIDLEN+1], *cimageid;
	char clientip[sizeof("XXX.XXX.XXX.XXX")+1];
	int len;
	struct config_host_authinfo *ai;
	struct config_imageinfo *ii = NULL;
	struct childinfo *ci;
	struct stat sb;
	uint64_t isize;
	int rv, methods, wantstatus;
	int getfromparent;
	GetReply reply;
	char *op;

	/*
	 * If an explicit host was listed, use that as the host we are
	 * authenticating, otherwise use the caller's IP.  config_auth_by_IP
	 * will reject the former if the caller is not allowed to proxy for
	 * the node in question.
	 */
	if (msg->body.getrequest.hostip)
		host.s_addr = msg->body.getrequest.hostip;
	else
		host.s_addr = cip->sin_addr.s_addr;

	len = ntohs(msg->body.getrequest.idlen);
	memcpy(imageid, msg->body.getrequest.imageid, len);
	imageid[len] = '\0';
	cimageid = config_canonicalize_imageid(imageid);
	if (cimageid != NULL && strcmp(cimageid, imageid) == 0) {
		free(cimageid);
		cimageid = NULL;
	}
	methods = msg->body.getrequest.methods;
	wantstatus = msg->body.getrequest.status;
	op = wantstatus ? "GETSTATUS" : "GET";

	strncpy(clientip, inet_ntoa(cip->sin_addr), sizeof clientip);
	if (cimageid == NULL) {
		if (host.s_addr != cip->sin_addr.s_addr)
			FrisLog("%s: %s from %s (for %s), methods: 0x%x",
				imageid, op, clientip, inet_ntoa(host),
				methods);
		else
			FrisLog("%s: %s from %s, (methods: 0x%x)",
				imageid, op, clientip, methods);
	} else {
		if (host.s_addr != cip->sin_addr.s_addr)
			FrisLog("%s (%s): %s from %s (for %s), methods: 0x%x",
				imageid, cimageid, op, clientip,
				inet_ntoa(host), methods);
		else
			FrisLog("%s (%s): %s from %s, (methods: 0x%x)",
				imageid, cimageid, op, clientip, methods);
	}
	memset(msg, 0, sizeof *msg);
	msg->hdr.type = htonl(MS_MSGTYPE_GETREPLY);
	strncpy((char *)msg->hdr.version, MS_MSGVERS_1,
		sizeof(msg->hdr.version));

	/*
	 * This server only handles uploads.
	 * XXX maybe we should just drop these requests and not send reply?
	 */
	if ((onlyrequests & MS_REQUEST_GET) == 0) {
		FrisWarning("%s: %s from %s, rejected by PUT-only server",
			    imageid, op, clientip);
		msg->body.getreply.error = MS_ERROR_NOTIMPL;
		goto reply;
	}

	/*
	 * If they request a method we don't support, reject them before
	 * we do any other work.  XXX maybe the method should not matter
	 * for a status-only call?
	 */
	methods &= onlymethods;
	if (methods == 0)
		goto badmethod;

	/*
	 * Use the canonical name from here on out.
	 */
	if (cimageid != NULL) {
		strcpy(imageid, cimageid);
		free(cimageid);
		cimageid = NULL;
	}

	/*
	 * In mirrormode, we first validate access with our parent
	 * before doing anything locally.
	 */
	if (mirrormode) {
		struct in_addr pif;
		in_addr_t authip;

		authip = usechildauth ? ntohl(host.s_addr) : 0;
		if (!ClientNetFindServer(ntohl(parentip.s_addr),
					 parentport, authip, imageid,
					 methods, 1, 5,
					 &reply, &pif))
			reply.error = MS_ERROR_NOIMAGE;
		if (reply.error) {
			msg->body.getreply.error = reply.error;
			FrisLog("%s: client %s authentication with parent failed: %s",
				imageid, clientip, GetMSError(reply.error));
			goto reply;
		}
	}

#ifdef USE_LOCALHOST_PROXY
	/*
	 * XXX this is really an Emulab special case for a boss node.
	 *
	 * We allow localhost access to any image that has a daemon
	 * currently running.  This is a hack to allow localhost to get
	 * info for a running daemon so it can kill it.
	 *
	 * Perhaps localhost should be able to access ANY valid image
	 * or image directory (running or not), but I don't want to go
	 * there right now...
	 */
	if (wantstatus &&
	    cip->sin_addr.s_addr == htonl(INADDR_LOOPBACK) &&
	    host.s_addr == htonl(INADDR_LOOPBACK) &&
	    (ci = findchild(imageid, PTYPE_SERVER, methods)) != NULL) {
		/* XXX only fill in the info that the caller cares about */
		msg->body.getreply.method = ci->method;
		msg->body.getreply.isrunning = 1;
		msg->body.getreply.addr = htonl(ci->addr);
		msg->body.getreply.port = htons(ci->loport);
		goto reply;
	}
#endif

	/*
	 * See if node has access to the image.
	 * If not, return an error code immediately.
	 */
	rv = config_auth_by_IP(1, &cip->sin_addr, &host, imageid, &ai);
	if (rv) {
		FrisWarning("%s: client %s %s failed: %s",
			    imageid, clientip, op, GetMSError(rv));
		msg->body.getreply.error = rv;
		goto reply;
	}
	if (debug > 1)
		config_dump_host_authinfo(ai);
	if (ai->numimages > 1) {
		rv = MS_ERROR_INVALID;
		FrisWarning("%s: client %s %s failed: "
			    "lookup returned multiple (%d) images",
			    imageid, clientip, op, ai->numimages);
		msg->body.getreply.error = rv;
		goto reply;
	}
	ii = copy_imageinfo(&ai->imageinfo[0]);
	config_free_host_authinfo(ai);		
	assert((ii->flags & (CONFIG_PATH_ISFILE|CONFIG_PATH_ISSIGFILE)) != 0);

	/*
	 * If the image is currently being uploaded, return TRYAGAIN.
	 */
	if (findchild(ii->imageid, PTYPE_UPLOADER, MS_METHOD_UNICAST)) {
		rv = MS_ERROR_TRYAGAIN;
		FrisLog("%s: %s currently being uploaded", imageid, op);
		msg->body.getreply.error = rv;
		goto reply;
	}

	/*
	 * See if image actually exists.
	 *
	 * If the file exists but is not a regular file, we return an error.
	 *
	 * If the file does not exist (it is possible to request an image
	 * that doesn't exist if the authentication check allows access to
	 * the containing directory) and we have a parent, we request it
	 * from the parent.
	 *
	 * Otherwise we just fail.
	 */
	isize = 0;
	getfromparent = 0;
	if ((ii->flags & CONFIG_PATH_EXISTS) != 0 &&
	    stat(ii->path, &sb) == 0) {
		if (!S_ISREG(sb.st_mode)) {
			rv = MS_ERROR_INVALID;
			FrisWarning("%s: client %s %s failed: "
				    "not a regular file",
				    imageid, clientip, op);
			msg->body.getreply.error = rv;
			goto reply;
		}
		isize = sb.st_size;

		/*
		 * If the file exists and we have a parent, get the signature
		 * from the parent and see if we need to update our copy.
		 * We only do this for mirror mode.
		 */
		if (mirrormode) {
			FrisLog("%s: have local copy", imageid);

			/*
			 * See if the signature is out of date.
			 * Since this is mirror mode, we can use the status
			 * info we got from the earlier call.
			 *
			 * Note that we actually check for a different date,
			 * not just a newer date. People often roll back
			 * faulty images to previous versions.
			 *
			 * XXX need checks for other signature types.
			 */
			if ((reply.sigtype == MS_SIGTYPE_MTIME &&
			     *(time_t *)reply.signature != sb.st_mtime)) {
				uint32_t mt = *(uint32_t *)reply.signature;

				msg->body.getreply.sigtype =
					htons(reply.sigtype);
				if (reply.sigtype == MS_SIGTYPE_MTIME)
					*(uint32_t *)reply.signature =
						htonl(mt);
				memcpy(msg->body.getreply.signature,
				       reply.signature, MS_MAXSIGLEN);
				msg->body.getreply.hisize =
					htonl(reply.hisize);
				msg->body.getreply.losize =
					htonl(reply.losize);

				if (wantstatus)
					goto reply;

				FrisLog("%s: local copy (sig=%x) "
					"is out of date (sig=%x), GET from parent",
					imageid, sb.st_mtime, mt);
				getfromparent = 1;
			}
		}
	} else if (fetchfromabove) {
		FrisLog("%s: no local copy, %s from parent", imageid, op);

		/*
		 * We don't have the image, but we have a parent,
		 * request the status as we did above. Again, in mirrormode,
		 * we have already fetched the status so no additional call
		 * is needed.
		 *
		 * Any error is reflected to our caller.
		 */
		if (!mirrormode) {
			rv = fetch_parent(&sip->sin_addr, &host, &parentip,
					  parentport, ii, 1, &reply);
			if (rv) {
				FrisLog("%s: failed getting parent status: %s, "
					"failing",
					imageid, GetMSError(rv));
				msg->body.getreply.error = rv;
				goto reply;
			}
		}
		/*
		 * And we must always fetch from the parent.
		 * Return the attributes we got via the check above.
		 */
		msg->body.getreply.sigtype = htons(reply.sigtype);
		if (reply.sigtype == MS_SIGTYPE_MTIME) {
			uint32_t mt;
			mt = *(uint32_t *)reply.signature;
			*(uint32_t *)reply.signature = htonl(mt);
		}
		memcpy(msg->body.getreply.signature, reply.signature,
		       MS_MAXSIGLEN);
		msg->body.getreply.hisize = htonl(reply.hisize);
		msg->body.getreply.losize = htonl(reply.losize);

		if (wantstatus)
			goto reply;
		getfromparent = 1;
	} else {
		/*
		 * XXX If the config module says the path does not exist,
		 * we stat again so that we can differentiate a file that
		 * does not exist from a project directory that is not mounted
		 * or something else.
		 */
		if ((ii->flags & CONFIG_PATH_EXISTS) == 0)
			stat(ii->path, &sb);

		/* Image file does not exist */
		if (errno == ENOENT)
			rv = MS_ERROR_NOIMAGE;
		/* Automounter (autofs) error */
		else if (errno == EIO)
			rv = MS_ERROR_INVALID;
		/* Huh? The file reappeared, have them try again. */
		else if (errno == 0)
			rv = MS_ERROR_TRYAGAIN;
		/* Something inexplicible */
		else
			rv = MS_ERROR_INVALID;
		FrisWarning("%s: client %s %s failed: %s",
			    imageid, clientip, op, GetMSError(rv));
		msg->body.getreply.error = rv;
		goto reply;
	}

	/*
	 * Either we did not have the image or our copy is out of date,
	 * attempt to fetch from our parent.
	 */
	if (getfromparent) {
		rv = fetch_parent(&sip->sin_addr, &host,
				  &parentip, parentport, ii, 0, &reply);
		/*
		 * Redirecting to parent.
		 * Can only do this if our parents method is compatible
		 * with the client's request.
		 */
		if (rv == 0) {
			if ((reply.method & methods) != 0) {
				msg->body.getreply.method = reply.method;
				msg->body.getreply.isrunning = 1;
				msg->body.getreply.servaddr =
					htonl(reply.servaddr);
				msg->body.getreply.addr =
					htonl(reply.addr);
				msg->body.getreply.port =
					htons(reply.port);
				FrisLog("%s: redirecting %s to our parent",
					imageid, clientip);
				goto reply;
			}
			FrisLog("%s: cannot redirect %s to parent; "
				"incompatible transfer methods",
				imageid, clientip);
			rv = MS_ERROR_TRYAGAIN;
		}
		/*
		 * If parent callout failed, but we have a copy
		 * use our stale version.
		 */
		if (rv != MS_ERROR_TRYAGAIN && isize > 0) {
			FrisWarning("%s: client %s %s from parent failed: %s, "
				    "using our stale copy",
				    imageid, clientip, op, GetMSError(rv));
		}
		/*
		 * Otherwise, we are busy fetching the new copy (TRYAGAIN),
		 * or we had a real failure and we don't have a copy.
		 */
		else {
			FrisWarning("%s: client %s %s from parent failed: %s",
				    imageid, clientip, op, GetMSError(rv));
			msg->body.getreply.error = rv;
			goto reply;
		}
	}

	/*
	 * Figure out what transfer method to use.
	 */
	if (debug)
		FrisInfo("  request methods: 0x%x, image methods: 0x%x",
			 methods, ii->get_methods);
	methods &= ii->get_methods;
	if (methods == 0) {
	badmethod:
		rv = MS_ERROR_NOMETHOD;
		FrisWarning("%s: client %s %s failed: %s",
			    imageid, clientip, op, GetMSError(rv));
		msg->body.getreply.error = rv;
		goto reply;
	}

	/*
	 * Otherwise see if there is a frisbeed already running, starting
	 * one if not.  Then construct a reply with the available info.
	 */
	ci = findchild(ii->imageid, PTYPE_SERVER, methods);

	/*
	 * XXX right now frisbeed doesn't support mutiple clients
	 * on the same unicast address.  We could do multiple servers
	 * for the same image, but we don't.
	 */
	if (!wantstatus && ci != NULL && ci->method == MS_METHOD_UNICAST) {
		FrisWarning("%s: client %s %s failed: "
			    "unicast server already running",
			    imageid, clientip, op);
		msg->body.getreply.error = MS_ERROR_TRYAGAIN;
		goto reply;
	}

	if (ci == NULL) {
		struct in_addr in;
		in_addr_t myaddr;
		int stat;

		if (ii->sig != NULL) {
			int32_t mt = *(int32_t *)ii->sig;
			assert((ii->flags & CONFIG_SIG_ISMTIME) != 0);

			msg->body.getreply.sigtype = htons(MS_SIGTYPE_MTIME);
			*(int32_t *)msg->body.getreply.signature = htonl(mt);
		}
		if (wantstatus) {
			msg->body.getreply.method = methods;
			msg->body.getreply.isrunning = 0;
			msg->body.getreply.hisize = htonl(isize >> 32);
			msg->body.getreply.losize = htonl(isize);
			FrisLog("%s: STATUS is not running", imageid);
			goto reply;
		}
		myaddr = ntohl(sip->sin_addr.s_addr);
#ifdef USE_LOCALHOST_PROXY
		/*
		 * If this was a proxy request from localhost,
		 * we need to start the server on the real interface
		 * instead.  If none was specified, we don't know what
		 * interface to use, so just fail.
		 */
		if (myaddr == INADDR_LOOPBACK) {
			myaddr = ntohl(ifaceip.s_addr);
			if (myaddr == INADDR_ANY) {
				FrisWarning("%s: cannot start server on behalf "
					    "of %s", imageid, clientip);
				msg->body.getreply.error = MS_ERROR_FAILED;
				goto reply;
			}
		}
#endif
		ci = startserver(ii, myaddr, ntohl(cip->sin_addr.s_addr),
				 methods, &rv);
		if (ci == NULL) {
			msg->body.getreply.error = rv;
			goto reply;
		}

		in.s_addr = htonl(ci->addr);
		FrisLog("%s: started %s server on %s:%d (pid %d, timo %ds)",
			imageid, GetMSMethods(ci->method),
			inet_ntoa(in), ci->loport, ci->pid, ci->timeout);
		if (debug) {
			FrisLog("  uid: %d, gids: %s",
				ci->uid, gidstr(ci->ngids, ci->gids));
		}

		/*
		 * Watch for an immediate death so we don't tell our client
		 * a server is running when it really isn't.
		 *
		 * XXX what is the right response? Right now we just tell
		 * them to try again and hope the problem is transient.
		 */
		sleep(2);
		if (reapchildren(ci->pid, &stat)) {
			msg->body.getreply.error = MS_ERROR_TRYAGAIN;
			FrisLog("%s: server immediately exited (stat=0x%x), "
				"telling client to try again!",
				imageid, stat);
			goto reply;
		}
		/*
		 * Get the port chosen by the server
		 */
		if ((ci->loport == 0 || ci->loport != ci->hiport) &&
		    getaddrchild(ci)) {
			killchild(ci);
			msg->body.getreply.error = MS_ERROR_TRYAGAIN;
			FrisLog("%s: server did not report address info, "
				"telling client to try again!", imageid);
			goto reply;
		}
	} else {
		struct in_addr in;

		if (ii->sig != NULL) {
			int32_t mt = *(int32_t *)ii->sig;
			assert((ii->flags & CONFIG_SIG_ISMTIME) != 0);

			msg->body.getreply.sigtype = htons(MS_SIGTYPE_MTIME);
			*(int32_t *)msg->body.getreply.signature = htonl(mt);
		}
		in.s_addr = htonl(ci->addr);
		if (wantstatus)
			FrisLog("%s: STATUS is running %s on %s:%d (pid %d)",
				imageid, GetMSMethods(ci->method),
				inet_ntoa(in), ci->loport, ci->pid);
		else
			FrisLog("%s: %s server already running on %s:%d (pid %d)",
				imageid, GetMSMethods(ci->method),
				inet_ntoa(in), ci->loport, ci->pid);
		if (debug)
			FrisLog("  uid: %d, gids: %s",
				ci->uid, gidstr(ci->ngids, ci->gids));
	}

	msg->body.getreply.hisize = htonl(isize >> 32);
	msg->body.getreply.losize = htonl(isize);
	msg->body.getreply.method = ci->method;
	msg->body.getreply.isrunning = 1;
	msg->body.getreply.servaddr = htonl(ci->servaddr);
	/*
	 * XXX tmp hack.  Currently, if we are unicasting, startserver
	 * returns the addr field set to the address of the client
	 * (see the XXX there for details).  However, we need to return our
	 * address to the client.
	 *
	 * When frisbeed is changed to support more than one unicast client,
	 * this will change.
	 */
	if (ci->method == MS_METHOD_UNICAST)
		msg->body.getreply.addr = msg->body.getreply.servaddr;
	else
		msg->body.getreply.addr = htonl(ci->addr);
	msg->body.getreply.port = htons(ci->loport);

 reply:
	msg->body.getreply.error = htons(msg->body.getreply.error);
	if (debug) {
		FrisInfo("%s reply: sigtype=%d, sig=0x%08x..., size=%x/%x",
			 op, ntohs(msg->body.getreply.sigtype),
			 ntohl(*(uint32_t *)msg->body.getreply.signature),
			 ntohl(msg->body.getreply.hisize),
			 ntohl(msg->body.getreply.losize));
	}
	len = sizeof msg->hdr + sizeof msg->body.getreply;
	if (!MsgSend(sock, msg, len, 10))
		FrisError("%s: could not send reply",
			  inet_ntoa(cip->sin_addr));
	if (ii)
		free_imageinfo(ii);
}

void
handle_put(int sock, struct sockaddr_in *sip, struct sockaddr_in *cip,
	   MasterMsg_t *msg)
{
	struct in_addr host, in;
	in_addr_t myaddr;
	char imageid[MS_MAXIDLEN+1], *cimageid;
	char clientip[sizeof("XXX.XXX.XXX.XXX")+1];
	int len;
	struct config_host_authinfo *ai;
	struct config_imageinfo *ii = NULL;
	struct childinfo *ci;
	struct stat sb;
	uint64_t isize;
	uint32_t mtime, timo;
	int rv, wantstatus, childexitstatus;
	PutReply reply;
	char *op;

	/*
	 * If an explicit host was listed, use that as the host we are
	 * authenticating, otherwise use the caller's IP.  config_auth_by_IP
	 * will reject the former if the caller is not allowed to proxy for
	 * the node in question.
	 */
	if (msg->body.putrequest.hostip)
		host.s_addr = msg->body.putrequest.hostip;
	else
		host.s_addr = cip->sin_addr.s_addr;

	len = ntohs(msg->body.putrequest.idlen);
	memcpy(imageid, msg->body.putrequest.imageid, len);
	imageid[len] = '\0';
	cimageid = config_canonicalize_imageid(imageid);
	if (cimageid != NULL && strcmp(cimageid, imageid) == 0) {
		free(cimageid);
		cimageid = NULL;
	}
	wantstatus = msg->body.putrequest.status;

	/*
	 * XXX oh my, a value of 100 or greater indicates a child
	 * PUT-only server reporting the status of an upload for an
	 * image that we serve GETs for. We need to record this exit
	 * status (assuming everything else about the request checks out).
	 */
	if (wantstatus >= 100) {
		childexitstatus = wantstatus - 100;
		wantstatus = 1;
	} else
		childexitstatus = -1;

	op = wantstatus ? "PUTSTATUS" : "PUT";
	isize = ((uint64_t)ntohl(msg->body.putrequest.hisize) << 32) |
		ntohl(msg->body.putrequest.losize);
	mtime = ntohl(msg->body.putrequest.mtime);
	timo = ntohl(msg->body.putrequest.timeout);

	strncpy(clientip, inet_ntoa(cip->sin_addr), sizeof clientip);
	if (cimageid == NULL) {
		if (host.s_addr != cip->sin_addr.s_addr)
			FrisLog("%s: %s from %s (for %s), size=%llu",
				imageid, op, clientip, inet_ntoa(host), isize);
		else
			FrisLog("%s: %s from %s, size=%llu",
				imageid, op, clientip, isize);
	} else {
		if (host.s_addr != cip->sin_addr.s_addr)
			FrisLog("%s (%s): %s from %s (for %s), size=%llu",
				imageid, cimageid, op, clientip,
				inet_ntoa(host), isize);
		else
			FrisLog("%s (%s): %s from %s, size=%llu",
				imageid, cimageid, op, clientip,
				isize);
	}

	memset(msg, 0, sizeof *msg);
	msg->hdr.type = htonl(MS_MSGTYPE_PUTREPLY);
	strncpy((char *)msg->hdr.version, MS_MSGVERS_1,
		sizeof(msg->hdr.version));

	/*
	 * This server only handles downloads.
	 * XXX maybe we should just drop these requests and not send reply?
	 */
	if ((onlyrequests & MS_REQUEST_PUT) == 0) {
		FrisWarning("%s: %s from %s, rejected by GET-only server",
			    imageid, op, clientip);
		msg->body.getreply.error = MS_ERROR_NOTIMPL;
		goto reply;
	}

	/*
	 * Use the canonical name from here on out.
	 */
	if (cimageid != NULL) {
		strcpy(imageid, cimageid);
		free(cimageid);
		cimageid = NULL;
	}

	/*
	 * XXX mirror mode on PUT means that we check with our parent to
	 * make sure that the upload would be legal, and then upload it to
	 * a local filesystem. We do not actually propogate it to our parent,
	 * so there is no real "mirroring" going on. This is just a hack so
	 * we can upload Emulab images on ops directly, while still relying
	 * on boss (the parent) to authenticate the upload.
	 */
	if (mirrormode) {
		in_addr_t authip;

		authip = usechildauth ? ntohl(host.s_addr) : 0;
		if (!ClientNetPutRequest(ntohl(parentip.s_addr), parentport,
					 authip, imageid, isize, mtime, timo,
					 1, 5, &reply))
			reply.error = MS_ERROR_FAILED;
		if (debug) {
			FrisLog("Parent PUT%s returns:", wantstatus? "STATUS" : "");
			PrintPutInfo(imageid, &reply, 1);
		}
		if (reply.error) {
			msg->body.putreply.error = reply.error;
			FrisLog("%s: client %s authentication with parent failed: %s",
				imageid, clientip, GetMSError(reply.error));
			goto reply;
		}
	}

	/*
	 * See if node has access to the image.
	 * If not, return an error code immediately.
	 */
	rv = config_auth_by_IP(0, &cip->sin_addr, &host, imageid, &ai);
	if (rv) {
		FrisWarning("%s: client %s %s failed: %s",
			    imageid, clientip, op, GetMSError(rv));
		msg->body.putreply.error = rv;
		goto reply;
	}
	if (debug > 1)
		config_dump_host_authinfo(ai);
	if (ai->numimages > 1) {
		rv = MS_ERROR_INVALID;
		FrisWarning("%s: client %s %s failed: "
			    "lookup returned multiple (%d) images",
			    imageid, clientip, op, ai->numimages);
		msg->body.putreply.error = rv;
		goto reply;
	}
	ii = copy_imageinfo(&ai->imageinfo[0]);
	config_free_host_authinfo(ai);		
	assert((ii->flags & (CONFIG_PATH_ISFILE|CONFIG_PATH_ISSIGFILE)) != 0);

	/*
	 * Use values returned by parent where appropriate.
	 *
	 * XXX note that we use local values for size and signature.
	 * In our only use of PUT mirrormode, the parent will be returning
	 * the same info as we see locally since they are the same files.
	 */
	if (mirrormode) {
		uint64_t pmaxsize;

		pmaxsize = ((uint64_t)reply.himaxsize << 32) | reply.lomaxsize;
		if (debug)
			FrisLog("%s: replace local maxsize %llu with parent %llu",
				imageid, ii->put_maxsize, pmaxsize);
		ii->put_maxsize = pmaxsize;
	}
	
	/*
	 * If they gave us a size and it exceeds the maxsize, return an error.
	 * We do this even for a status-only request; they can specify a size
	 * of zero if they want to get all the image attributes.
	 */
	if (isize > ii->put_maxsize) {
		rv = MS_ERROR_TOOBIG;
		FrisWarning("%s: client %s %s failed: "
			    "upload size (%llu) exceeds maximum for image (%llu)",
			    imageid, clientip, op, isize, ii->put_maxsize);

		/*
		 * We return the max size here along with the error so that
		 * the client doesn't have to make a second, wantstatus call.
		 */
		msg->body.putreply.himaxsize = htonl(ii->put_maxsize >> 32);
		msg->body.putreply.lomaxsize = htonl(ii->put_maxsize);

		msg->body.putreply.error = rv;
		goto reply;
	}

	/*
	 * They gave us an mtime and it is "bad", return an error.
	 * XXX somewhat arbitrary: cannot set a time in the future.
	 * XXX cut them some slack on the future time thing, up to 10s okay.
	 * XXX even more slack, just warn and set time to our current time.
	 */
	if (mtime) {
		struct timeval now;

		gettimeofday(&now, NULL);
		if (mtime > (now.tv_sec + 10)) {
#if 1
			FrisWarning("%s: attempt to set mtime in the future "
				    "(%u > %u), setting to current time\n",
				    imageid, mtime, now.tv_sec);
			mtime = 0;
#else
			rv = MS_ERROR_BADMTIME;
			FrisWarning("%s: client %s %s failed: "
				    "attempt to set mtime in the future "
				    "(%u > %u)\n",
				    imageid, clientip, op, mtime, now.tv_sec);
			msg->body.putreply.error = rv;
			goto reply;
#endif
		}
	}

	/*
	 * If the image is being served, fetched from our parent,
	 * or uploaded--return TRYAGAIN.
	 */
	if ((ci = findchild(ii->imageid, PTYPE_SERVER, onlymethods)) ||
	    (ci = findchild(ii->imageid, PTYPE_CLIENT, onlymethods)) ||
	    (ci = findchild(ii->imageid, PTYPE_UPLOADER, MS_METHOD_UNICAST))) {
		msg->body.putreply.error = MS_ERROR_TRYAGAIN;
		FrisLog("%s: %s currently being %s", imageid, op,
			(ci->ptype == PTYPE_SERVER) ? "served" :
			(ci->ptype == PTYPE_CLIENT) ? "downloaded from parent" :
			"uploaded");
		goto reply;
	}

	/*
	 * See if image actually exists.
	 *
	 * If the file exists but is not a regular file, we return an error.
	 * (maybe we should just remove it?)
	 *
	 * If it is a regular file, we return its current signature.
	 *
	 * If the file does not exist, that is okay (the authentication check
	 * has verified that the node can create the image).
	 */
	if ((ii->flags & CONFIG_PATH_EXISTS) != 0 &&
	    stat(ii->path, &sb) == 0) {
		if (!S_ISREG(sb.st_mode)) {
			rv = MS_ERROR_INVALID;
			FrisWarning("%s: client %s %s failed: "
				    "existing target (%s) is not a regular file",
				    imageid, clientip, op, ii->path);
			msg->body.putreply.error = rv;
			goto reply;
		}
		msg->body.putreply.exists = 1;

		/*
		 * Return the current size and signature info
		 */
		msg->body.putreply.hisize = htonl((uint64_t)sb.st_size >> 32);
		msg->body.putreply.losize = htonl(sb.st_size);

		if (ii->sig != NULL) {
			int32_t mt = *(int32_t *)ii->sig;

			assert((ii->flags & CONFIG_SIG_ISMTIME) != 0);
			msg->body.putreply.sigtype = htons(MS_SIGTYPE_MTIME);
			*(int32_t *)msg->body.putreply.signature = htonl(mt);
		}
	} else {
		msg->body.putreply.exists = 0;
	}

	/*
	 * At this point we know that there is no conflicting use of the
	 * image in progress, so either return status or fire off an uploader
	 * and return the contact info to the client.
	 */
	msg->body.putreply.himaxsize = htonl(ii->put_maxsize >> 32);
	msg->body.putreply.lomaxsize = htonl(ii->put_maxsize);

	if (wantstatus) {
		FrisLog("%s: PUTSTATUS upload allowed", imageid);
		goto reply;
	}
	myaddr = ntohl(sip->sin_addr.s_addr);
	ci = startuploader(ii, myaddr, ntohl(cip->sin_addr.s_addr),
			   isize, mtime, (int)timo, host.s_addr, &rv);
	if (ci == NULL) {
		FrisLog("%s: could not start uploader: %s",
			imageid, GetMSError(rv));
		msg->body.putreply.error = rv;
		goto reply;
	}

	in.s_addr = htonl(ci->addr);
	FrisLog("%s: started uploader on %s:%d (pid %d, timo %ds)",
		imageid, inet_ntoa(in), ci->loport, ci->pid, ci->timeout);
	if (debug)
		FrisLog("  uid: %d, gids: %s",
			ci->uid, gidstr(ci->ngids, ci->gids));

	/*
	 * Watch for an immediate death so we don't tell our client
	 * an uploader is running when it really isn't.
	 *
	 * XXX what is the right response? Right now we just tell
	 * them to try again and hope the problem is transient.
	 */
	sleep(2);
	if (reapchildren(ci->pid, &rv)) {
		msg->body.putreply.error = MS_ERROR_TRYAGAIN;
		FrisLog("%s: uploader immediately exited (stat=0x%x), "
			"telling client to try again!",
			imageid, rv);
		goto reply;
	}
	/*
	 * Get the port chosen by the uploader
	 */
	if ((ci->loport == 0 || ci->loport != ci->hiport) &&
	    getaddrchild(ci)) {
		killchild(ci);
		msg->body.getreply.error = MS_ERROR_TRYAGAIN;
		FrisLog("%s: uploader did not report address info, "
			"telling client to try again!", imageid);
		goto reply;
	}

	msg->body.putreply.addr = htonl(ci->servaddr);
	msg->body.putreply.port = htons(ci->loport);

 reply:
	/*
	 * XXX a child PUT-only server is reporting an exit status.
	 * If we have successfully looked up the image, record the status.
	 */
	if (ii && childexitstatus >= 0 &&
	    config_set_upload_status(ii, childexitstatus)) {
		FrisLog("%s: could not record PUT server exit status",
			imageid);
	}
	
	msg->body.putreply.error = htons(msg->body.putreply.error);
	if (debug) {
		FrisInfo("%s reply: sigtype=%d, sig=0x%08x..., "
			 "size=%x/%x, maxsize=%x/%x",
			 op, ntohs(msg->body.putreply.sigtype),
			 ntohl(*(uint32_t *)msg->body.putreply.signature),
			 ntohl(msg->body.putreply.hisize),
			 ntohl(msg->body.putreply.losize),
			 ntohl(msg->body.putreply.himaxsize),
			 ntohl(msg->body.putreply.lomaxsize));
	}
	len = sizeof msg->hdr + sizeof msg->body.putreply;
	if (!MsgSend(sock, msg, len, 10))
		FrisError("%s: could not send reply",
			  inet_ntoa(cip->sin_addr));
	if (ii)
		free_imageinfo(ii);
}

static void
handle_request(int sock)
{
	MasterMsg_t msg;
	int cc;
	struct sockaddr_in me, you;
	socklen_t len;

	len = sizeof me;
	if (getsockname(sock, (struct sockaddr *)&me, &len) < 0) {
		perror("getsockname");
		return;
	}
	len = sizeof you;
	if (getpeername(sock, (struct sockaddr *)&you, &len) < 0) {
		perror("getpeername");
		return;
	}

	cc = read(sock, &msg, sizeof msg);
	if (cc < sizeof msg.hdr) {
		if (cc < 0)
			perror("request message failed");
		else
			FrisError("request message too small");
		return;
	}
	if (strncmp((char *)msg.hdr.version, MS_MSGVERS_1,
		    sizeof(msg.hdr.version))) {
		FrisError("incorrect version in request message");
		return;
	}

	switch (ntohl(msg.hdr.type)) {
	case MS_MSGTYPE_GETREQUEST:
		if (cc < sizeof msg.hdr + sizeof msg.body.getrequest)
			FrisError("GET request message too small");
		else if (ntohs(msg.body.getrequest.idlen) > MS_MAXIDLEN)
			FrisError("GET request idlen too long");
		else
			handle_get(sock, &me, &you, &msg);
		break;
	case MS_MSGTYPE_PUTREQUEST:
		if (cc < sizeof msg.hdr + sizeof msg.body.putrequest)
			FrisError("PUT request message too small");
		else if (ntohs(msg.body.putrequest.idlen) > MS_MAXIDLEN)
			FrisError("PUT request idlen too long");
		else
			handle_put(sock, &me, &you, &msg);
		break;
	default:
		FrisError("unrecognized message type %d", ntohl(msg.hdr.type));
		break;
	}
}

static void
usage(void)
{
	fprintf(stderr, "mfrisbeed [-ADRd] [-X method] [-I imagedir] [-S parentIP] [-P parentport] [-p port]\n");
	fprintf(stderr, "Basic:\n");
	fprintf(stderr, "  -C <style>  configuration style: emulab, upload-only, or null\n");
	fprintf(stderr, "  -O <str>    configuration options, style-specific\n");
	fprintf(stderr, "  -I <dir>    default directory where images are stored\n");
	fprintf(stderr, "  -r <req>    type of requests to serve: get, put or any\n");
	fprintf(stderr, "  -x <methods> transfer methods to allow from clients: ucast, mcast, bcast or any\n");
	fprintf(stderr, "  -X <method> transfer method to request from parent\n");
	fprintf(stderr, "  -p <port>   port to listen on\n");
	fprintf(stderr, "Debug:\n");
	fprintf(stderr, "  -d          debug mode; does not daemonize\n");
	fprintf(stderr, "  -D          force daemonizing even with debug\n");
	fprintf(stderr, "Proxying:\n");
	fprintf(stderr, "  -S <parent> parent name or IP\n");
	fprintf(stderr, "  -P <pport>  parent port to contact\n");
	fprintf(stderr, "  -A          pass on authentication info from our child to parent\n");
	fprintf(stderr, "  -M          act as a strict mirror for our parent\n");
	fprintf(stderr, "  -R          redirect child to parent if local image not available\n");
	exit(-1);
}

static void
get_options(int argc, char **argv)
{
	int ch;
	int forcedaemonize = 0;

	while ((ch = getopt(argc, argv, "AC:O:DI:MRX:x:S:P:p:i:dhQ:r:")) != -1)
		switch(ch) {
		case 'A':
			usechildauth = 1;
			break;
		case 'C':
			if (strcmp(optarg, "emulab") == 0 ||
			    strcmp(optarg, "upload-only") == 0 ||
			    strcmp(optarg, "null") == 0)
				configstyle = optarg;
			else {
				fprintf(stderr,
					"-C should specify one: "
					"'emulab', 'upload-only', 'null'\n");
				exit(1);
			}
			break;
		case 'O':
			configopts = optarg;
			break;
		case 'r':
		{
			char *ostr, *str, *cp;
			int nm = 0;

			str = ostr = strdup(optarg);
			while ((cp = strsep(&str, ",")) != NULL) {
				if (strcmp(cp, "get") == 0)
					nm |= MS_REQUEST_GET;
				else if (strcmp(cp, "put") == 0)
					nm |= MS_REQUEST_PUT;
				else if (strcmp(cp, "any") == 0)
					nm = MS_REQUEST_ANY;
			}
			free(ostr);
			if (nm == 0) {
				fprintf(stderr,
					"-%c should specify one or more of: "
					"'get', 'put', 'any'\n",
					ch);
				exit(1);
			}
			onlyrequests = nm;
			break;
		}
		case 'x':
		case 'X':
		{
			char *ostr, *str, *cp;
			int nm = 0;

			str = ostr = strdup(optarg);
			while ((cp = strsep(&str, ",")) != NULL) {
				if (strcmp(cp, "ucast") == 0)
					nm |= MS_METHOD_UNICAST;
				else if (strcmp(cp, "mcast") == 0)
					nm |= MS_METHOD_MULTICAST;
				else if (strcmp(cp, "bcast") == 0)
					nm |= MS_METHOD_BROADCAST;
				else if (strcmp(cp, "any") == 0)
					nm = MS_METHOD_ANY;
			}
			free(ostr);
			if (nm == 0) {
				fprintf(stderr,
					"-%c should specify one or more of: "
					"'ucast', 'mcast', 'bcast', 'any'\n",
					ch);
				exit(1);
			}
			if (ch == 'x')
				onlymethods = nm;
			else
				parentmethods = nm;
			break;
		}
		case 'd':
			daemonize = 0;
			debug++;
			break;
		case 'D':
			forcedaemonize = 1;
			break;
		case 'I':
		{
			extern char *imagedir;
			imagedir = optarg;
			break;
		}
		case 'M':
			mirrormode = 1;
			break;
		case 'R':
			canredirect = 1;
			break;
		case 'S':
			if (!GetIP(optarg, &parentip)) {
				fprintf(stderr, "Invalid server IP `%s'\n",
					optarg);
				exit(1);
			}
			fetchfromabove = 1;
			break;
		case 'P':
			parentport = atoi(optarg);
			break;
		case 'p':
			portnum = atoi(optarg);
			break;
		case 'i':
			if (!GetIP(optarg, &ifaceip)) {
				fprintf(stderr, "Invalid interface IP `%s'\n",
					optarg);
				exit(1);
			}
			break;
		case 'Q':
#ifdef WITH_IGMP
			igmpqueryinterval = atoi(optarg);
			if (igmpqueryinterval <= 0) {
				fprintf(stderr,
					"Invalid IGMP querier interval '%s'\n",
					optarg);
				exit(1);
			}
#else
			fprintf(stderr, "IGMP querier mode not supported\n");
			exit(1);
#endif
			break;
		case 'h':
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (argc) {
		fprintf(stderr,
			"Error: Unrecognized command line arguments: %s ...\n",
			argv[0]);
		usage();
	}

	if (mirrormode && !fetchfromabove) {
		fprintf(stderr,
			"Error: Must specify a parent (-S) in mirror mode\n");
		usage();
	}

	if (forcedaemonize)
		daemonize = 1;
}

/*
 * Create socket on specified port.
 */
static int
makesocket(int port, struct in_addr *ifip, int *tcpsockp)
{
	struct sockaddr_in	name;
	int			i, sock;
	socklen_t		length;

	/*
	 * Setup TCP socket for incoming connections.
	 */

	/* Create socket from which to read. */
	sock = socket(AF_INET, SOCK_STREAM, 0);
	if (sock < 0) {
		FrisPfatal("opening stream socket");
	}
	fcntl(sock, F_SETFD, FD_CLOEXEC);

	i = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,
		       (char *)&i, sizeof(i)) < 0)
		FrisPwarning("setsockopt(SO_REUSEADDR)");
	
	/* Create name. */
	name.sin_family = AF_INET;
	name.sin_addr.s_addr = ifip->s_addr;
	name.sin_port = htons((u_short) port);
	if (bind(sock, (struct sockaddr *) &name, sizeof(name))) {
		FrisPfatal("binding stream socket");
	}
	/* Find assigned port value and print it out. */
	length = sizeof(name);
	if (getsockname(sock, (struct sockaddr *) &name, &length)) {
		FrisPfatal("getsockname");
	}
	if (listen(sock, 128) < 0) {
		FrisPfatal("listen");
	}
	*tcpsockp = sock;
	FrisLog("listening on TCP %s:%d",
		inet_ntoa(*ifip), ntohs(name.sin_port));
	
	return 0;
}

static struct childinfo *children;
static int nchildren;

static struct childinfo *
findchild(char *imageid, int ptype, int methods)
{
	struct childinfo *ci, *bestci;
	assert(ptype == PTYPE_UPLOADER || (methods & ~onlymethods) == 0);

	bestci = NULL;
	for (ci = children; ci != NULL; ci = ci->next)
		if (ci->ptype == ptype && (ci->method & methods) != 0 &&
		    !strcmp(ci->imageinfo->imageid, imageid)) {
			if (bestci == NULL)
				bestci = ci;
			else if (ci->method == MS_METHOD_BROADCAST)
				bestci = ci;
			else if (ci->method == MS_METHOD_MULTICAST &&
				 bestci->method == MS_METHOD_UNICAST)
				bestci = ci;
			else if (ci->method == MS_METHOD_UNICAST &&
				 bestci->method == MS_METHOD_MULTICAST)
				/* do nothing */;
			else
				FrisPfatal("multiple unicast servers for %s",
					   imageid);
		}

	return bestci;
}

/*
 * See if the indicated child has written out its address info.
 * We extract the port info from this if necessary.
 * Return zero on success, an error code on failure.
 */
static int
getaddrchild(struct childinfo *ci)
{
	char afile[sizeof("/tmp/TT.NNNNNN")+1];
	int a, b, c, d, p, rv = 1;
	FILE *fd;

	if (ci->ptype != PTYPE_CLIENT) {
		snprintf(afile, sizeof(afile), "/tmp/%2s.%06u",
			 ci->ptype == PTYPE_SERVER ? "dl" : "ul", ci->pid);
		if ((fd = fopen(afile, "r")) != NULL &&
		    fscanf(fd, "%d.%d.%d.%d:%d", &a, &b, &c, &d, &p) == 5) {
			if (p > 0) {
				FrisLog("%s chose port %u",
					ci->ptype == PTYPE_SERVER ?
					"server" : "uploader", p);
				ci->loport = ci->hiport = p;
				rv = 0;
			}
		}
		if (fd != NULL) {
			fclose(fd);
			unlink(afile);
		}
	}

	return rv;
}

/*
 * Fire off a frisbee server or client process to serve or download an image.
 * Return zero on success, an error code on failure.
 */
static int
startchild(struct childinfo *ci)
{
	/*
	 * Fork off the process
	 */
	ci->pid = fork();
	if (ci->pid < 0) {
		FrisPwarning("startchild");
		return MS_ERROR_FAILED;
	}
	if (ci->pid == 0) {
		static char argbuf[1024];
		char ifacestr[sizeof("XXX.XXX.XXX.XXX")+1];
		char servstr[sizeof("XXX.XXX.XXX.XXX")+1];
		char *argv[64], **ap, *args;
		int argc;
		struct in_addr in;
		char *pname, *opts;
		char portarg[sizeof("-p NNNNN-NNNNN -A /tmp/TT.NNNNNN")+1];

		if (myuid == 0) {
			assert(ci->ngids >= 1);
			if (setgroups(ci->ngids, ci->gids) != 0) {
				perror("child: setgroups");
				exit(-2);

			}
			if ((ci->gids[0] != mygid && setgid(ci->gids[0]) != 0) ||
			    (ci->uid != myuid && setuid(ci->uid) != 0)) {
				FrisError("child: could not setuid/gid to %d/%d",
					  ci->uid, ci->gids[0]);
				exit(-2);
			}
		}

		/*
		 * Now that we are running as the user, see if we need to
		 * resolve the path to catch permission problems, create
		 * intermediate directories, etc.
		 */
		if (ci->imageinfo->flags & CONFIG_PATH_RESOLVE) {
			char *rname;
			int mkdirs = 0;
			assert(ci->imageinfo->dir != NULL);

			if (ci->ptype == PTYPE_CLIENT ||
			    ci->ptype == PTYPE_UPLOADER)
				mkdirs = 1;
			rname = resolvepath(ci->imageinfo->path,
					    ci->imageinfo->dir, mkdirs);
			if (rname == NULL) {
				FrisError("child: could not resolve '%s'",
					  ci->imageinfo->path);
				exit(-4);
			}
			if (debug)
				FrisInfo("child: resolve '%s' to '%s'",
					 ci->imageinfo->path, rname);

			/*
			 * XXX right now we don't do anything with this path.
			 * We could pass it to the server instance in place
			 * of the user-provided string, to insure they don't
			 * mess with the latter between now and when the
			 * instance starts.
			 */
			free(rname);
		}

		in.s_addr = htonl(ci->ifaceaddr);
		strncpy(ifacestr, inet_ntoa(in), sizeof ifacestr);
		in.s_addr = htonl(ci->servaddr);
		strncpy(servstr, inet_ntoa(in), sizeof servstr);
		in.s_addr = htonl(ci->addr);

		/*
		 * Figure out the port arguments. If loport == 0 or we
		 * have a port range, then we need to pass -A to capture
		 * the chosen port. Otherwise, it is just the traditional
		 * port argument.
		 */
		if (ci->loport == 0) {
			assert(ci->ptype != PTYPE_CLIENT);
			snprintf(portarg, sizeof(portarg),
				 "-p 0 -A /tmp/%2s.%06u",
				 ci->ptype == PTYPE_SERVER ? "dl" : "ul",
				 getpid());
		} else if (ci->loport != ci->hiport) {
			assert(ci->ptype != PTYPE_CLIENT);
			snprintf(portarg, sizeof(portarg),
				 "-p %u-%u -A /tmp/%2s.%06u",
				 ci->loport, ci->hiport,
				 ci->ptype == PTYPE_SERVER ? "dl" : "ul",
				 getpid());
		} else
			snprintf(portarg, sizeof(portarg),
				 "-p %u", ci->loport);

		switch (ci->ptype) {
		case PTYPE_SERVER:
		{
			int timo = ci->timeout;

			/* XXX compensate for 2s sleep in handle_get */
			if (timo > 0)
				timo += 2;

			pname = FRISBEE_SERVER;
			opts = ci->imageinfo->get_options ?
				ci->imageinfo->get_options : "";
			snprintf(argbuf, sizeof argbuf,
				 "%s -i %s -T %d %s %s -m %s %s %s",
				 pname, ifacestr, timo, opts,
				 ci->method == CONFIG_IMAGE_BCAST ? "-b" : "",
				 inet_ntoa(in), portarg, ci->imageinfo->path);
			break;
		}
		case PTYPE_CLIENT:
			pname = FRISBEE_CLIENT;
			opts = ci->imageinfo->pget_options ?
				ci->imageinfo->pget_options : "";
			snprintf(argbuf, sizeof argbuf,
				 "%s -N -S %s -i %s %s %s %s -m %s %s %s",
				 pname, servstr, ifacestr, opts,
				 debug > 1 ? "" : "-q",
				 ci->method == CONFIG_IMAGE_UCAST ? "-O" :
				 (ci->method == CONFIG_IMAGE_BCAST ? "-b" : ""),
				 inet_ntoa(in), portarg, ci->imageinfo->path);
			break;
		case PTYPE_UPLOADER:
		{
			int timo = ci->timeout;
			int itimo =
				((struct uploadextra *)ci->extra)->itimeout;
			uint64_t isize =
				((struct uploadextra *)ci->extra)->isize;

			/* XXX compensate for 2s sleep in handle_put */
			if (timo)
				timo += 2;
			if (itimo)
				itimo += 2;

			pname = FRISBEE_UPLOAD;
			opts = ci->imageinfo->put_options ?
				ci->imageinfo->put_options : "";
			snprintf(argbuf, sizeof argbuf,
				 "%s -i %s -I %d -T %d %s -s %llu -m %s %s %s",
				 pname, ifacestr, itimo, timo, opts,
				 (unsigned long long)isize,
				 inet_ntoa(in), portarg, ci->imageinfo->path);
			break;
		}
		default:
			exit(-3);
		}
		if (debug)
			FrisInfo("execing: %s", argbuf);

		args = argbuf;
		argc = 0;
		for (ap = argv; (*ap = strsep(&args, " \t")) != 0; ) {
			if (**ap != '\0') {
				argc++;
				if (++ap >= &argv[64])
					break;
			}
		}
		argv[argc] = NULL;

		/* close descriptors, etc. */
		for (argc = getdtablesize() - 1; argc >= 3; argc--)
			close(argc);

		execv(pname, argv);
		exit(-1);
	}

	/* create a pid file */
	if (ci->ptype == PTYPE_SERVER) {
		char pidfile[128];
		struct in_addr in;
		FILE *fd;

		in.s_addr = htonl(ci->addr);
		snprintf(pidfile, sizeof pidfile, "%s/frisbeed-%s-%d.pid",
			 _PATH_VARRUN, inet_ntoa(in), ci->loport);
		fd = fopen(pidfile, "w");
		if (fd != NULL) {
			fprintf(fd, "%d\n", ci->pid);
			fclose(fd);
			ci->pidfile = strdup(pidfile);
		}
	}
	ci->next = children;
	children = ci;
	nchildren++;

	return 0;
}

static struct childinfo *
startserver(struct config_imageinfo *ii, in_addr_t meaddr, in_addr_t youaddr,
	    int methods, int *errorp)
{
	struct childinfo *ci;

	assert(findchild(ii->imageid, PTYPE_SERVER, methods) == NULL);
	assert(errorp != NULL);

	ci = calloc(1, sizeof(struct childinfo));
	if (ci == NULL) {
		*errorp = MS_ERROR_FAILED;
		return NULL;
	}

	/*
	 * Find the appropriate address, port and method to use.
	 */
	if (config_get_server_address(ii, methods, 1, &ci->addr,
				      &ci->loport, &ci->hiport, &ci->method)) {
		free(ci);
		*errorp = MS_ERROR_FAILED;
		return NULL;
	}

	/*
	 * XXX tmp hack.  Currently, if we are unicasting, the addr field
	 * (-m arg of frisbeed) needs to be the address of the client.
	 * When frisbeed is changed to support more than one unicast client,
	 * this will change.
	 */
	if (ci->method == MS_METHOD_UNICAST)
		ci->addr = youaddr;

	/*
	 * If we are running as root, prefer to run the frisbee server
	 * for the image as indicated in the imageinfo (if set).
	 * Otherwise just run it as our uid/gid.
	 */
	if (myuid == 0) {
		if (ii->uid != NOUID && myuid != ii->uid)
			ci->uid = ii->uid;
		else
			ci->uid = myuid;
		if (ii->ngids > 0) {
			int i;
			for (i = 0; i < ii->ngids; i++)
				ci->gids[i] = ii->gids[i];
			ci->ngids = ii->ngids;
		} else {
			ci->gids[0] = mygid;
			ci->ngids = 1;
		}
	}

	ci->timeout = ii->get_timeout;
	ci->servaddr = meaddr;
	ci->ifaceaddr = meaddr;
	ci->imageinfo = copy_imageinfo(ii);
	ci->ptype = PTYPE_SERVER;
	ci->retries = FRISBEE_RETRIES;
	if ((*errorp = startchild(ci)) != 0) {
		free_imageinfo(ci->imageinfo);
		free(ci);
		return NULL;
	}

	return ci;
}

static void
finishclient(struct childinfo *ci, int status)
{
	char *bakname, *tmpname, *realname;
	int len, didbackup;
	struct clientextra *ce;
	time_t mtime = 0;

	assert(ci->extra != NULL);
	ce = ci->extra;
	realname = ce->realname;
	if (ce->sigtype == MS_SIGTYPE_MTIME)
		mtime = *(time_t *)ce->signature;
	free(ci->extra);
	ci->extra = NULL;
	tmpname = ci->imageinfo->path;
	ci->imageinfo->path = realname;

	if (status != 0) {
		FrisError("%s: download failed, removing tmpfile %s",
			  realname, tmpname);
		unlink(tmpname);
		free(tmpname);
		return;
	}

	if (mtime > 0) {
		struct timeval tv[2];
		gettimeofday(&tv[0], NULL);
		tv[1].tv_sec = mtime;
		tv[1].tv_usec = 0;
		if (utimes(tmpname, tv) < 0)
			FrisWarning("%s: failed to set mtime", tmpname);
	}

	len = strlen(realname) + 5;
	bakname = malloc(len);
	snprintf(bakname, len, "%s.bak", realname);
	didbackup = 1;
	if (rename(realname, bakname) < 0)
		didbackup = 0;
	if (rename(tmpname, realname) < 0) {
		FrisError("%s: failed to install new version, leaving as %s",
			  realname, tmpname);
		if (didbackup)
			rename(bakname, realname);
	}
	free(tmpname);
	free(bakname);
	FrisLog("%s: download complete", realname);
}

static struct childinfo *
startclient(struct config_imageinfo *ii, in_addr_t meaddr, in_addr_t youaddr,
	    in_addr_t addr, in_port_t port, int methods, int *errorp)
{
	struct childinfo *ci;
	struct clientextra *ce;
	char *tmpname;
	int len;

	assert(findchild(ii->imageid, PTYPE_CLIENT, methods) == NULL);
	assert(errorp != NULL);

	ci = calloc(1, sizeof(struct childinfo));
	if (ci == NULL)
		goto fail;

	ci->servaddr = youaddr;
	ci->ifaceaddr = meaddr;
	ci->addr = addr;
	ci->loport = ci->hiport = port;
	ci->method = methods;
	ci->imageinfo = copy_imageinfo(ii);
	ci->ptype = PTYPE_CLIENT;

	/* For now, we just run the client as us */
	ci->uid = myuid;
	ci->gids[0] = mygid;
	ci->ngids = 1;

	ce = ci->extra = calloc(1, sizeof(struct clientextra));
	if (ce == NULL)
		goto fail;

	/*
	 * Arrange to download the image as <path>.tmp and then
	 * rename it into place when done.
	 */
	len = strlen(ci->imageinfo->path) + 5;
	if ((tmpname = malloc(len)) == NULL)
		goto fail;

	ce->realname = ci->imageinfo->path;
	snprintf(tmpname, len, "%s.tmp", ce->realname);
	ci->imageinfo->path = tmpname;
	ci->done = finishclient;

	if ((*errorp = startchild(ci)) != 0) {
		free(ce->realname);
		goto fail;
	}

	return ci;

 fail:
	if (ci) {
		if (ci->extra)
			free(ci->extra);
		if (ci->imageinfo)
			free_imageinfo(ci->imageinfo);
		free(ci);
	}
	*errorp = MS_ERROR_FAILED;
	return NULL;
}

static void
finishupload(struct childinfo *ci, int status)
{
	char *bakname, *tmpname, *realname;
	int didbackup, ecode;
	struct uploadextra *ue;
	time_t mtime;

	assert(ci->extra != NULL);
	ue = ci->extra;
	realname = ue->realname;
	mtime = (time_t)ue->mtime;
	free(ci->extra);
	ci->extra = NULL;

	if (realname) {
		tmpname = ci->imageinfo->path;
		assert(tmpname != NULL);
		ci->imageinfo->path = realname;
		bakname = ci->imageinfo->put_oldversion;
		assert(bakname != NULL);
	} else {
		tmpname = bakname = NULL;
		realname = ci->imageinfo->path;
	}

	/*
	 * Record the status
	 */
	ecode = (unsigned int)status >> 8;
	if (config_set_upload_status(ci->imageinfo, ecode))
		FrisLog("%s: could not record upload exit status",
			ci->imageinfo->imageid);

	/*
	 * XXX in our special hack use of mirror mode, report the exit
	 * status to our parent as well.
	 */
	if (mirrormode) {
		in_addr_t authip;
		PutReply reply;

		authip = usechildauth ? ntohl(ue->hostip) : 0;
		if (!ClientNetPutRequest(ntohl(parentip.s_addr), parentport,
					 authip, ci->imageinfo->imageid,
					 0, 0, 0, ecode+100, 5, &reply))
			reply.error = MS_ERROR_FAILED;
		if (debug)
			FrisLog("Parent PUT exit status %d returns %d\n",
				status, reply.error);
		if (reply.error) {
			struct in_addr hostip;
			
			hostip.s_addr = ue->hostip;
			FrisLog("%s: client %s PUT exit status %d failed: %s",
				ci->imageinfo->imageid,
				inet_ntoa(hostip), status, GetMSError(reply.error));
		}
	}
	
	if (status != 0) {
		if (tmpname) {
			FrisError("%s: upload failed, removing tmpfile %s",
				  realname, tmpname);
			unlink(tmpname);
			free(tmpname);
		} else {
			FrisError("%s: upload failed, removing", realname);
			unlink(realname);
		}
		return;
	}

	if (mtime) {
		struct timeval tv[2];
		gettimeofday(&tv[0], NULL);
		tv[1].tv_sec = mtime;
		tv[1].tv_usec = 0;
		if (utimes(tmpname ? tmpname : realname, tv) < 0)
			FrisWarning("%s: failed to set mtime",
				    tmpname ? tmpname : realname);
	}

	/*
	 * If the configuration specified an explicit place for the
	 * old version, move it there now. Otherwise, we were saving
	 * directly to the specified path and there is nothing to backup.
	 */
	if (bakname) {
		didbackup = 1;
		if (rename(realname, bakname) < 0)
			didbackup = 0;
		if ((!didbackup && errno != ENOENT) ||
		    rename(tmpname, realname) < 0) {
			FrisError("%s: failed to install new version (%d),"
				  "leaving as %s", realname, errno, tmpname);
			if (didbackup)
				rename(bakname, realname);
		}
		free(tmpname);
	}

	FrisLog("%s: upload complete", realname);
}

/*
 * Start an image upload process
 */
static struct childinfo *
startuploader(struct config_imageinfo *ii, in_addr_t meaddr, in_addr_t youaddr,
	      uint64_t isize, uint32_t mtime, int timo, uint32_t hostip,
	      int *errorp)
{
	struct childinfo *ci;
	struct uploadextra *ue;
	int itimo = 0;

	assert(findchild(ii->imageid, PTYPE_UPLOADER, MS_METHOD_ANY) == NULL);
	assert(errorp != NULL);

	ci = calloc(1, sizeof(struct childinfo));
	if (ci == NULL) {
		*errorp = MS_ERROR_FAILED;
		return NULL;
	}

	/*
	 * Adjust the user supplied values for size and timeout if they
	 * exceed what the image allows.
	 */
	if (isize == 0 || isize > ii->put_maxsize)
		isize = ii->put_maxsize;
	if (timo == 0 || timo > ii->put_timeout)
		timo = ii->put_timeout;

	/*
	 * Add per-operation timeout if less than overall timeout.
	 */
	if (timo == 0 || ii->put_itimeout < timo)
		itimo = ii->put_itimeout;

	/*
	 * Find a port to use. Note that with MS_METHOD_UNICAST,
	 * get_server_address will return 0 as the addr, so we set it
	 * to the client's address afterward.
	 */
	if (config_get_server_address(ii, MS_METHOD_UNICAST, 1, &ci->addr,
				      &ci->loport, &ci->hiport, &ci->method)) {
		free(ci);
		*errorp = MS_ERROR_FAILED;
		return NULL;
	}
	ci->addr = youaddr;

	/*
	 * If we are running as root, prefer to run the frisbee uploader
	 * for the image as indicated in the imageinfo (if set).
	 * Otherwise just run it as our uid/gid.
	 */
	if (myuid == 0) {
		if (ii->uid != NOUID && myuid != ii->uid)
			ci->uid = ii->uid;
		else
			ci->uid = myuid;
		if (ii->ngids > 0) {
			int i;
			for (i = 0; i < ii->ngids; i++)
				ci->gids[i] = ii->gids[i];
			ci->ngids = ii->ngids;
		} else {
			ci->gids[0] = mygid;
			ci->ngids = 1;
		}
	}

	ci->timeout = timo;
	ci->servaddr = meaddr;
	ci->ifaceaddr = meaddr;
	ci->imageinfo = copy_imageinfo(ii);
	ci->ptype = PTYPE_UPLOADER;
	ci->retries = FRISBEE_RETRIES;

	ue = ci->extra = malloc(sizeof(struct uploadextra));
	if (ue == NULL) {
		free(ci);
		*errorp = MS_ERROR_FAILED;
		return NULL;
	}
	memset(ue, 0, sizeof(*ue));
	ue->isize = isize;
	ue->mtime = mtime;
	ue->itimeout = itimo;
	ue->hostip = hostip;

	/*
	 * Arrange to upload the image as <path>.tmp and then
	 * rename it into place when done.
	 *
	 * XXX if put_oldversion is NULL, we assume that we are
	 * uploading to a temporary file in the first place.
	 * See config_emulab.c.
	 */
	if (ci->imageinfo->put_oldversion) {
		int len = strlen(ci->imageinfo->path) + 5;
		char *tmpname = malloc(len);
		if (tmpname != NULL) {
			ue->realname = ci->imageinfo->path;
			snprintf(tmpname, len, "%s.tmp", ci->imageinfo->path);
			ci->imageinfo->path = tmpname;
		}
	}
	ci->done = finishupload;

	if ((*errorp = startchild(ci)) != 0) {
		free_imageinfo(ci->imageinfo);
		free(ci);
		return NULL;
	}

	return ci;
}

static int
killchild(struct childinfo *ci)
{
	kill(ci->pid, SIGTERM);
	return 0;
}

/*
 * Cleanup zombies.
 * If pid is non-zero, we wait for that specific process.
 * Returns the number of children reaped.
 */
static int
reapchildren(int wpid, int *statusp)
{
	int pid, status;
	struct childinfo **cip, *ci;
	int corpses = 0;

	if (nchildren == 0) {
		assert(children == NULL);
		return 0;
	}

	while (1) {
		struct in_addr in;

		pid = waitpid(wpid, &status, WNOHANG);
		if (debug && wpid)
			FrisLog("wait for %d returns %d, status=%x",
				wpid, pid, pid > 0 ? status : 0);
		if (pid <= 0)
			return 0;
		for (cip = &children; *cip != NULL; cip = &(*cip)->next) {
			if ((*cip)->pid == pid)
				break;
		}
		ci = *cip;
		if (ci == NULL) {
			FrisError("Child died that was not ours!?");
			if (wpid)
				break;
			continue;
		}
		*cip = ci->next;
		if (ci->pidfile) {
			unlink(ci->pidfile);
			free(ci->pidfile);
			ci->pidfile = NULL;
		}
		nchildren--;
		in.s_addr = htonl(ci->addr);
		FrisLog("%s: %s process %d on %s:%d exited (status=0x%x)",
			ci->imageinfo->imageid,
			ci->ptype == PTYPE_SERVER ? "server" :
			ci->ptype == PTYPE_CLIENT ? "client" : "uploader",
			pid, inet_ntoa(in), ci->loport, status);

		/*
		 * Special case exit value.
		 * The program could not bind to the port we gave it.
		 * For the server (and uploader), we get a new address (port)
		 * and try again up to FRISBEE_RETRIES times.  For a client,
		 * we just fail right now.  Maybe we should sleep awhile and
		 * try again or reask our server?
		 */
		if (ci->retries > 0 && WEXITSTATUS(status) == EADDRINUSE) {
			ci->retries--;
			if (ci->ptype != PTYPE_CLIENT &&
			    !config_get_server_address(ci->imageinfo,
						       ci->method, 0,
						       &ci->addr,
						       &ci->loport, &ci->hiport,
						       &ci->method) &&
			    !startchild(ci)) {
				/* give it a chance to run, and check again */
				sleep(1);
				in.s_addr = htonl(ci->addr);
				FrisLog("%s: restarted %s process on %s:%d"
					" (pid %d)",
					ci->imageinfo->imageid,
					ci->ptype == PTYPE_SERVER ?
					"server" : "uploader",
					inet_ntoa(in), ci->loport, ci->pid);
				if (wpid)
					wpid = ci->pid;
				continue;
			}
		}
		if (ci->done)
			ci->done(ci, status);
		if (ci->extra)
			free(ci->extra);
		free_imageinfo(ci->imageinfo);
		free(ci);
		corpses++;
		if (wpid) {
			if (debug)
				FrisError("  process %d exited immediately",
					  wpid);
			if (statusp)
				*statusp = status;
			break;
		}
	}

	return corpses;
}

#ifdef WITH_IGMP
/*
 * If we are acting as an IGMP querier, see if we are due to send out a
 * general membership query. Maybe we should only send queries while we
 * have active MC servers running?
 *
 * Called from the main loop before returning to select to wait for more.
 */
static void
handle_igmp(void)
{
	static struct timeval lastquery;
	struct timeval now, delta;

	if (lastquery.tv_sec == 0)
		gettimeofday(&lastquery, NULL);

	gettimeofday(&now, NULL);
	timersub(&now, &lastquery, &delta);
	if (delta.tv_sec >= igmpqueryinterval) {
		if (debug)
			FrisLog("sending IGMP membership query after %d seconds",
				delta.tv_sec);
		if (IGMPSendQuery())
			FrisWarning("could not send IGMP membership query!");
		lastquery = now;
	}
}
#endif

/*
 * XXX debug
 */
static char *
gidstr(int ngids, gid_t gids[])
{
	static char str[MAXGIDS*6+1];
	char *cp = str;
	int i;

	assert(ngids > 0);
	for (i = 0; i < ngids; i++) {
		sprintf(cp, "%d%c", gids[i], (i == ngids-1) ? '\0' : '/');
		cp = &str[strlen(str)];
	}

	return str;
}
