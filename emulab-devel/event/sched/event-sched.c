/*
 * Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
 * event-sched.c --
 *
 *      Testbed event scheduler.
 *
 *      The event scheduler is an event system client; it operates by
 *      subscribing to the EVENT_SCHEDULE event, enqueuing the event
 *      notifications it receives, and resending the notifications at
 *      the indicated times.
 *
 */

#include "config.h"

#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/param.h>
#include <time.h>
#include <unistd.h>
#include <math.h>
#include <ctype.h>
#include <pwd.h>
#include <pthread.h>
#include <assert.h>
#include <paths.h>

#include "event-sched.h"
#include "error-record.h"
#include "log.h"
#include "tbdefs.h"
#include "rpc.h"
#include "popenf.h"
#include "systemf.h"

#include "simulator-agent.h"
#include "group-agent.h"
#include "node-agent.h"
#include "console-agent.h"
#include "timeline-agent.h"

#define EVENT_SCHED_PATH_ENV \
	"/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:" BINDIR ":" SBINDIR

static void enqueue(event_handle_t handle,
		    event_notification_t notification,
		    void *data);
static void dequeue(event_handle_t handle);
static int  handle_completeevent(event_handle_t handle, sched_event_t *eventp);
static void RecordEvent(sched_event_t *eventp, char *eventtype,
			char *parent, char *arguments);

static char	*progname;
char	pideid[BUFSIZ];
char	*pid, *eid;
static int	get_static_events(event_handle_t handle);
int	debug;
const char *XMLRPC_ROOT = TBROOT;

/* Dynamic event recording */
static int	recordevents;
static char	*recordevents_filename;
static void	RecordEventsInit(void);


expt_state_t expt_state;

struct lnList agents;

static struct lnList timelines;
static struct lnList sequences;
static struct lnList groups;

int32_t next_token;

simulator_agent_t primary_simulator_agent;

static pid_t emcd_pid = -1;
static pid_t vmcd_pid = -1;
static pid_t rmcd_pid = -1;

static struct agent ns_sequence_agent; /* Used for list of things to do right after swapin */
static timeline_agent_t ns_sequence;
static struct agent ns_teardown_agent; /* Used during experiment teardown */
static timeline_agent_t ns_teardown;
static struct agent ns_swapout_agent; /* Used during experiment swapout */
static timeline_agent_t ns_swapout;
static struct agent ns_timeline_agent; /* Used for timeline in the experiment */
static timeline_agent_t ns_timeline;

static void sigpass(int sig)
{
	info("event-sched[%d]: received signal %d, exiting\n", getpid(), sig);
	
	if (emcd_pid != -1)
		kill(emcd_pid, sig);
	if (vmcd_pid != -1)
		kill(vmcd_pid, sig);
	if (rmcd_pid != -1)
		kill(rmcd_pid, sig);

	exit(0);
}

static void sigpanic(int sig)
{
	info("event-sched[%d]: sigpanic %d\n", getpid(), sig);

	abort();
}

static void sigchld(int sig)
{
	int status;
	
	if (vmcd_pid != -1) {
		if (waitpid(vmcd_pid, &status, WNOHANG) != -1) {
			vmcd_pid = -1;
		}
	}
	if (rmcd_pid != -1) {
		if (waitpid(rmcd_pid, &status, WNOHANG) != -1) {
			rmcd_pid = -1;
			if (vmcd_pid != -1)
				kill(vmcd_pid, SIGTERM);
		}
	}

}

static char emc_path[256];

static void sighup(int sig)
{
	if (emc_path[0] == '\0')
		return;
	
	rmcd_pid = fork();
	switch (rmcd_pid) {
	case -1:
		fatal("could not start rmcd");
		break;
	case 0:
		execlp("rmcd",
		       "rmcd",
		       "-dd",
		       "-l",
		       "logs/rmcd.log",
		       "-U",
		       emc_path,
		       NULL);
		exit(0);
		break;
	default:
		break;
	}
	
	vmcd_pid = fork();
	switch (vmcd_pid) {
	case -1:
		fatal("could not start vmcd");
		break;
	case 0:
		sleep(1);
		execlp("vmcd",
		       "vmcd",
		       "-d",
		       "-S",
		       "-w",
		       "5",
		       "-l",
		       "logs/vmcd.log",
		       "-U",
		       emc_path,
		       NULL);
		exit(0);
		break;
	default:
		break;
	}
}

void
usage(void)
{
	fprintf(stderr,
		"Usage: %s [-hVd] [OPTIONS] <pid> <eid>\n"
		"\n"
		"Optional arguments:\n"
		"  -h          Print this message\n"
		"  -V          Print version information\n"
		"  -d          Turn on debugging\n"
		"  -t filename Record dynamic events to file as they arrive\n"
		"  -s server   Specify location of elvind server. "
		"(Default: localhost)\n"
		"  -r          Use the standard RPC path. (Current: %s)\n"
		"  -p port     Specify port number of elvind server\n"
		"  -l logfile  Specify logfile to direct output\n"
		"  -k keyfile  Specify keyfile name\n"
		"\n"
		"Required arguments:\n"
		"  pid         The project ID of the experiment\n"
		"  eid         The experiment ID\n",
		progname,
		TBROOT);
	exit(-1);
}

int
main(int argc, char *argv[])
{
	address_tuple_t tuple;
	event_handle_t handle;
	char *server = NULL;
	char *port = NULL;
	char *log = NULL;
	char *keyfile = NULL;
	char buf[BUFSIZ];
	int c;

	// sleep(600);

	setenv("PATH", EVENT_SCHED_PATH_ENV, 1);
	
	progname = argv[0];

	/* Initialize event queue semaphores: */
	sched_event_init();

	lnNewList(&agents);
	lnNewList(&timelines);
	lnNewList(&sequences);
	lnNewList(&groups);

	if ((primary_simulator_agent = create_simulator_agent()) == NULL)
		fatal("cannot allocate simulator agent");

	while ((c = getopt(argc, argv, "hVrs:p:dl:k:t:")) != -1) {
		switch (c) {
		case 'h':
			usage();
			break;
		case 'V':
			printf("%s\n", build_info);
			exit(0);
			break;
		case 'd':
			debug++;
			break;
		case 'r':
			XMLRPC_ROOT = "/usr/testbed";
			break;
		case 's':
			server = optarg;
			break;
		case 'p':
			port = optarg;
			break;
		case 'l':
			log = optarg;
			break;
		case 'k':
			keyfile = optarg;
			break;
		case 't':
			recordevents = 1;
			recordevents_filename = optarg;
			break;
		default:
			usage();
			break;
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 2) {
		fprintf(stderr, "error: required arguments are missing.\n");
		usage();
	}

	if (keyfile == NULL)
		keyfile = "tbdata/eventkey";
	
	pid = argv[0];
	eid = argv[1];
	sprintf(pideid, "%s/%s", pid, eid);

	if (RPC_init(NULL, BOSSNODE, 0)) {
		fatal("could not initialize rpc code");
	}

	if (RPC_grab()) {
		fatal("could not connect to rpc server");
	}
	
	setenv("LOGDIR", LOGDIR, 1);
	setenv("PID", pid, 1);
	setenv("EID", eid, 1);

	if (RPC_metadata(pid, eid)) {
		fatal("could not get experiment metadata");
	}

	if (recordevents) {
		RecordEventsInit();
	}

	/*
	 * Okay this is more complicated than it probably needs to be. We do
	 * not want to run anything on ops that is linked against the event
	 * system as root, even if its just to write out a pid file. This
	 * may be overly paranoid, but so be it. As a result, we do not
	 * want to use the usual daemon function, but rather depend on the
	 * caller (a perl script) to set the pid file then exec this
	 * program. The caller will also handle setting up stdout/stderr to
	 * write to the log file, and will close our stdin. The reason for
	 * writing the pid file in the caller is in order to kill the event
	 * scheduler, it must be done as root since the person swapping the
	 * experiment out might be different then the person who swapped it in
	 * (the scheduler runs as the person who swapped it in). Since the
	 * signal is sent as root, the pid file must not be in a place that
	 * is writable by mere user. 
	 */
	if (log)
		loginit(0, log);

	signal(SIGTERM, sigpass);
	signal(SIGINT, sigpass);
	signal(SIGQUIT, sigpass);
	
	signal(SIGSEGV, sigpanic);
	signal(SIGBUS, sigpanic);
	
	signal(SIGCHLD, sigchld);
	signal(SIGHUP, sighup);
	
	/*
	 * Convert server/port to elvin thing.
	 *
	 * XXX This elvin string stuff should be moved down a layer. 
	 */
	if (!server)
		server = "localhost";
	
	snprintf(buf, sizeof(buf), "elvin://%s%s%s",
		 server,
		 (port ? ":"  : ""),
		 (port ? port : ""));
	server = buf;

	/* Register with the event system: */
	handle = event_register_withkeyfile(server, 1, keyfile);
	if (handle == NULL) {
		fatal("could not register with event system");
	}

	/* Make a (not yet populated) list of things to do after initial swapin */
	ns_sequence = create_timeline_agent(TA_SEQUENCE);
	ns_sequence->ta_local_agent.la_link.ln_Name = ns_sequence_agent.name;
	ns_sequence->ta_local_agent.la_handle = handle;
	ns_sequence->ta_local_agent.la_agent = &ns_sequence_agent;
	ns_sequence_agent.link.ln_Name = ns_sequence_agent.name;
	strcpy(ns_sequence_agent.name, "__ns_sequence");
	strcpy(ns_sequence_agent.nodeid, "*");
	strcpy(ns_sequence_agent.vnode, "*");
	strcpy(ns_sequence_agent.objtype, TBDB_OBJECTTYPE_SEQUENCE);
	strcpy(ns_sequence_agent.ipaddr, "*");
	ns_sequence_agent.handler = &ns_sequence->ta_local_agent;
	lnAddTail(&sequences, &ns_sequence->ta_local_agent.la_link);
	lnAddTail(&agents, &ns_sequence_agent.link);

	/* Make a (not yet populated) list of things to do during teardown */
	ns_teardown = create_timeline_agent(TA_SEQUENCE);
	ns_teardown->ta_local_agent.la_link.ln_Name = ns_teardown_agent.name;
	ns_teardown->ta_local_agent.la_handle = handle;
	ns_teardown->ta_local_agent.la_agent = &ns_teardown_agent;
	ns_teardown_agent.link.ln_Name = ns_teardown_agent.name;
	strcpy(ns_teardown_agent.name, "__ns_teardown");
	strcpy(ns_teardown_agent.nodeid, "*");
	strcpy(ns_teardown_agent.vnode, "*");
	strcpy(ns_teardown_agent.objtype, TBDB_OBJECTTYPE_SEQUENCE);
	strcpy(ns_teardown_agent.ipaddr, "*");
	ns_teardown_agent.handler = &ns_teardown->ta_local_agent;
	lnAddTail(&sequences, &ns_teardown->ta_local_agent.la_link);
	lnAddTail(&agents, &ns_teardown_agent.link);

	/* Make a (not yet populated) list of things to do during swapout, "at swapout" events go into here */
	ns_swapout = create_timeline_agent(TA_SEQUENCE);
	ns_swapout->ta_local_agent.la_link.ln_Name = ns_swapout_agent.name;
	ns_swapout->ta_local_agent.la_handle = handle;
	ns_swapout->ta_local_agent.la_agent = &ns_swapout_agent;
	ns_swapout_agent.link.ln_Name = ns_swapout_agent.name;
	strcpy(ns_swapout_agent.name, "__ns_swapout");
	strcpy(ns_swapout_agent.nodeid, "*");
	strcpy(ns_swapout_agent.vnode, "*");
	strcpy(ns_swapout_agent.objtype, TBDB_OBJECTTYPE_SEQUENCE);
	strcpy(ns_swapout_agent.ipaddr, "*");
	ns_swapout_agent.handler = &ns_swapout->ta_local_agent;
	lnAddTail(&sequences, &ns_swapout->ta_local_agent.la_link);
	lnAddTail(&agents, &ns_swapout_agent.link);

	/* Make a (not yet populated) timeline for the experiment. "at" events go into here */	
	ns_timeline = create_timeline_agent(TA_TIMELINE);
	ns_timeline->ta_local_agent.la_link.ln_Name = ns_timeline_agent.name;
	ns_timeline->ta_local_agent.la_handle = handle;
	ns_timeline->ta_local_agent.la_agent = &ns_timeline_agent;
	ns_timeline_agent.link.ln_Name = ns_timeline_agent.name;
	strcpy(ns_timeline_agent.name, "__ns_timeline");
	strcpy(ns_timeline_agent.nodeid, "*");
	strcpy(ns_timeline_agent.vnode, "*");
	strcpy(ns_timeline_agent.objtype, TBDB_OBJECTTYPE_TIMELINE);
	strcpy(ns_timeline_agent.ipaddr, "*");
	ns_timeline_agent.handler = &ns_timeline->ta_local_agent;
	lnAddTail(&timelines, &ns_timeline->ta_local_agent.la_link);
	lnAddTail(&agents, &ns_timeline_agent.link);

	/*
	 * Construct an address tuple for event subscription. We set the 
	 * scheduler flag to indicate we want to capture those notifications.
	 */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		fatal("could not allocate an address tuple");
	}
	
	tuple->scheduler = 1;
	tuple->expt      = pideid;

	if (event_subscribe(handle, enqueue, tuple, NULL) == NULL) {
		fatal("could not subscribe to EVENT_SCHEDULE event");
	}

	expt_state = RPC_expt_state(pid, eid);

	if (expt_state == ES_UNKNOWN)
		fatal("Experiment is not activating or active\n");
	
	if (RPC_agentlist(handle, pid, eid))
		fatal("Could not get agentlist from RPC server\n");

	if (RPC_waitforrobots(handle, pid, eid))
		fatal("waitforrobots: RPC failed!");

	if (access("tbdata/emcd.config", R_OK) == 0) {

		systemf("echo %d > tmp/event-sched.pid", getpid());
		snprintf(emc_path,
			 sizeof(emc_path),
			 "%s/%s.%s.emcd",
			 _PATH_TMP,
			 pid,
			 eid);
		
		emcd_pid = fork();
		switch (emcd_pid) {
		case -1:
			fatal("could not start emcd");
			break;
		case 0:
			execlp("emcd",
			       "emcd",
			       "-d",
			       "-l",
			       "logs/emcd.log",
			       "-c",
			       "tbdata/emcd.config",
			       "-e",
			       pideid,
			       "-U",
			       emc_path,
			       NULL);
			exit(0);
			break;
		default:
			break;
		}
		
		sleep(2);

		rmcd_pid = fork();
		switch (rmcd_pid) {
		case -1:
			fatal("could not start rmcd");
			break;
		case 0:
			execlp("rmcd",
			       "rmcd",
			       "-dd",
			       "-l",
			       "logs/rmcd.log",
			       "-U",
			       emc_path,
			       NULL);
			exit(0);
			break;
		default:
			break;
		}
		
		sleep(2);

#if 1
		vmcd_pid = fork();
		switch (vmcd_pid) {
		case -1:
			fatal("could not start vmcd");
			break;
		case 0:
			execlp("vmcd",
			       "vmcd",
			       "-d",
			       "-S",
			       "-w",
			       "5",
			       "-l",
			       "logs/vmcd.log",
			       "-U",
			       emc_path,
			       NULL);
			exit(0);
			break;
		default:
			break;
		}
#else
		systemf("vmcd -d -l logs/vmcd.log -e localhost -p 2626 "
			"-c junk.flux.utah.edu -P 6969 &");
#endif
	}

	/*
	 * Read the static events list and schedule.
	 */
	if (get_static_events(handle) < 0) {
		fatal("could not get static event list");
	}

	/* Dequeue events and process them at the appropriate times: */
	dequeue(handle);

	/* Unregister with the event system: */
	if (event_unregister(handle) == 0) {
		fatal("could not unregister with event system");
	}

	info("Scheduler for %s/%s exiting\n", pid, eid);
	return 0;
}

int agent_invariant(struct agent *agent)
{
	assert(strlen(agent->name) > 0);
	assert(strlen(agent->vnode) > 0);
	assert(strlen(agent->objtype) > 0);
	if (agent->handler != NULL) // Don't know about this.
		assert(local_agent_invariant(agent->handler));
	
	return 1;
}

int sends_complete(struct agent *agent, const char *evtype)
{
	static char *run_completes[] = {
		TBDB_EVENTTYPE_RUN,
		TBDB_EVENTTYPE_HALT,
		TBDB_EVENTTYPE_RELOAD,
		NULL
	};

	static char *start_completes[] = {
		TBDB_EVENTTYPE_START,
		NULL
	};

	static char *simulator_completes[] = {
		TBDB_EVENTTYPE_RESET,
		TBDB_EVENTTYPE_REPORT,
		TBDB_EVENTTYPE_MODIFY,
		TBDB_EVENTTYPE_SNAPSHOT,
		TBDB_EVENTTYPE_LOG,
		NULL
	};

	static char *linktrace_completes[] = {
		TBDB_EVENTTYPE_SNAPSHOT,
		NULL
	};

	static char *link_completes[] = {
		TBDB_EVENTTYPE_RESET,
		NULL
	};

	static char *node_completes[] = {
		TBDB_EVENTTYPE_REBOOT,
		TBDB_EVENTTYPE_RELOAD,
		TBDB_EVENTTYPE_SETDEST,
		TBDB_EVENTTYPE_SNAPSHOT,
		NULL
	};

	/*
	 * Map of object types to events that send back COMPLETEs.  If no
	 * events send a COMPLETE, just use a NULL for the evtypes slot.
	 */
	static struct {
		char *objtype;
		char **evtypes;
	} objtype2complete[] = {
		{ TBDB_OBJECTTYPE_LINK, link_completes },
		{ TBDB_OBJECTTYPE_TRAFGEN, NULL },
		{ TBDB_OBJECTTYPE_TIME, NULL },
		{ TBDB_OBJECTTYPE_PROGRAM, run_completes },
		{ TBDB_OBJECTTYPE_SIMULATOR, simulator_completes },
		{ TBDB_OBJECTTYPE_LINKTEST, start_completes },
		{ TBDB_OBJECTTYPE_NSE, NULL },
		{ TBDB_OBJECTTYPE_CANARYD, NULL },
		{ "SLOTHD", NULL }, // XXX
		{ TBDB_OBJECTTYPE_NODE, node_completes },
		{ TBDB_OBJECTTYPE_TIMELINE, run_completes },
		{ TBDB_OBJECTTYPE_SEQUENCE, run_completes },
		{ TBDB_OBJECTTYPE_CONSOLE, NULL },
		{ TBDB_OBJECTTYPE_TOPOGRAPHY, NULL },
		{ TBDB_OBJECTTYPE_LINKTRACE, linktrace_completes },
		{ TBDB_OBJECTTYPE_EVPROXY, NULL },
		{ TBDB_OBJECTTYPE_BGMON, NULL },
		{ TBDB_OBJECTTYPE_DISK, NULL },
		{ TBDB_OBJECTTYPE_CUSTOM, NULL },
		{ TBDB_OBJECTTYPE_BSTORE, NULL },
		{ NULL, NULL }
	};

	const char *objtype;
	int lpc, retval = 0;
	
	assert(agent != NULL);
	assert(evtype != NULL);

	if (strcmp(agent->objtype, TBDB_OBJECTTYPE_GROUP) == 0) {
		group_agent_t ga = (group_agent_t)agent->handler;
		
		objtype = ga->ga_agents[1]->objtype;
	}
	else {
		objtype = agent->objtype;
	}
	
	for (lpc = 0; objtype2complete[lpc].objtype != NULL; lpc++ ) {
		if (strcmp(objtype2complete[lpc].objtype, objtype) == 0) {
			char **ec;
			
			if ((ec = objtype2complete[lpc].evtypes) == NULL) {
				retval = 0;
				break;
			}
			else {
				int lpc2;

				retval = 0;
				for (lpc2 = 0; ec[lpc2] != NULL; lpc2++) {
					if (strcmp(ec[lpc2], evtype) == 0) {
						retval = 1;
						break;
					}
				}
				break;
			}
		}
	}

	if (objtype2complete[lpc].objtype == NULL) {
		error("Unknown object type %s\n", objtype);
		assert(0);
	}

	return retval;
}

int
sched_event_prepare(event_handle_t handle, sched_event_t *se)
{
	int retval;

	if (se->length > 1) {
		return 0;
	}
	
	if (se->agent.s == NULL) {
		event_notification_insert_hmac(handle, se->notification);
		return 0;
	}
	
	assert(se != NULL);
	assert(se->length == 1);

	if ((se->agent.s->handler != NULL) &&
	    (se->agent.s->handler->la_expand != NULL)) {
		local_agent_t la = se->agent.s->handler;

		retval = la->la_expand(la, se);
	}
	else {
		event_notification_clear_objtype(handle, se->notification);
		event_notification_set_objtype(handle,
					       se->notification,
					       se->agent.s->objtype);
		event_notification_insert_hmac(handle, se->notification);

		retval = 0;
	}
	
	return retval;
}

/* Enqueue event notifications as they arrive. */
static void
enqueue(event_handle_t handle, event_notification_t notification, void *data)
{
	sched_event_t		event;
	char			objname[TBDB_FLEN_EVOBJNAME];
	char			timeline[TBDB_FLEN_EVOBJNAME] = "";
	char			eventtype[TBDB_FLEN_EVEVENTTYPE];
	struct agent	       *agentp;
	timeline_agent_t	ta = NULL;
	int32_t			sec, usec, token;
	
	if (! event_notification_get_timeline(handle, notification,
						   timeline,
						   sizeof(timeline))) {
		warning("could not get timeline?\n");
		/* Not fatal since we have to deal with legacy systems. */
	}

	/*
	 * Get the event's firing time.
	 * Note that the timeval fields are not necessarily 32-bits,
	 * so we cannot just pass in addresses to tv_sec and tv_usec;
	 * assign to tmps instead.
	 */
	if (! event_notification_get_int32(handle, notification, "time_usec",
					   (int *) &usec) ||
	    ! event_notification_get_int32(handle, notification, "time_sec",
					   (int *) &sec)) {
		error("could not get time from notification %p\n",
		      notification);
	}
	else if (! event_notification_get_objname(handle, notification,
						  objname, sizeof(objname))) {
		error("could not get object name from notification %p\n",
		      notification);
	}
	else if (! event_notification_get_eventtype(handle, notification,
						    eventtype,
						    sizeof(eventtype))) {
		error("could not get event type from notification %p\n",
		      notification);
	}
	else  if ((agentp = (struct agent *)
		   lnFindName(&agents, objname)) == NULL) {
		error("%s\n", eventtype);
		error("Could not map object to an agent: %s\n", objname);
	}
	else if ((strlen(timeline) > 0) &&
		 (strcmp(timeline, ADDRESSTUPLE_ALL) != 0) &&
		 ((ta = (timeline_agent_t)
		   lnFindName(&timelines, timeline)) == NULL) &&
		 ((ta = (timeline_agent_t)
		   lnFindName(&sequences, timeline)) == NULL)) {
		error("Unknown timeline: %s\n", timeline);
	}
	else {
		event.agent.s = agentp;
		event.length = 1;
		event.flags = SEF_SINGLE_HANDLER;
		event.time.tv_sec = sec;
		event.time.tv_usec = usec;
		
		/*
		 * Clone the event notification, since we want the
		 * notification to live beyond the callback function:
		 */
		event.notification =
			event_notification_clone(handle, notification);
		
		if (!event.notification) {
			error("event_notification_clone failed!\n");
			return;
		}
		
		/*
		 * Clear the scheduler flag. Not allowed to do this above
		 * the loop cause the notification thats comes in is
		 * "read-only".
		 */
		if (! event_notification_remove(handle,
						event.notification,
						"SCHEDULER") ||
		    ! event_notification_put_int32(handle,
						    event.notification,
						    "SCHEDULER",
						    0)) {
			error("could not clear scheduler attribute of "
			      "notification %p\n", event.notification);
			return;
		}
		
		if (! notification->has_hmac &&
		    (! event_notification_remove(handle,
						 event.notification,
						 "EXPT") ||
		     ! event_notification_put_string(handle,
						     event.notification,
						     "EXPT",
						     pideid))) {
			error("could not clear expt attribute of "
			      "notification %p\n", event.notification);
			return;
		}
		
		if (debug) {
		        char time_buf_1[24], time_buf_2[24];
			struct timeval now;
		    
			gettimeofday(&now, NULL);

			make_timestamp(time_buf_1, &event.time);
			make_timestamp(time_buf_2, &now);

			info("Sched: "
			     "note:%p at:%s now:%s agent:%s %s\n",
			     event.notification,
			     time_buf_1, time_buf_2,
			     agentp->name,
			     eventtype);
		}
		
		if (strcmp(eventtype, TBDB_EVENTTYPE_COMPLETE) == 0) {
			event.flags |= SEF_COMPLETE_EVENT;
			sched_event_enqueue(event);
			return;
		}

		if (sends_complete(agentp, eventtype))
			event.flags |= SEF_SENDS_COMPLETE;
		
		event_notification_clear_host(handle, event.notification);
		event_notification_set_host(handle,
					    event.notification,
					    agentp->ipaddr);

		/*
		 * Do not override token.
		 */
		if (! event_notification_get_int32(handle,
						   event.notification,
						   "TOKEN",
						   &token)) {
			event_notification_put_int32(handle,
						     event.notification,
						     "TOKEN",
						     next_token);
			next_token += 1;
		}

		if (recordevents) {
			char	argsbuf[BUFSIZ] = "";
			event_notification_get_arguments(handle,
							 event.notification,
							 argsbuf,
							 sizeof(argsbuf));
			
			RecordEvent(&event, eventtype, timeline, argsbuf);
		}

		/*
		 * Enqueue the event notification for resending at the
		 * indicated time:
		 */
		sched_event_prepare(handle, &event);
		if (ta != NULL)
			timeline_agent_append(ta, &event);
		else
			sched_event_enqueue(event);
	}
}

static void
handle_event(event_handle_t handle, sched_event_t *se)
{
	assert(handle != NULL);
	assert(se != NULL);
	assert(se->length == 1);

	if ((se->agent.s != NULL) &&
	    (se->agent.s->handler != NULL)) {
		local_agent_queue(se->agent.s->handler, se);
	}
	else if (event_notify(handle, se->notification) == 0) {
		error("could not fire event\n");
		return;
	}
	else if (se->flags & SEF_TIME_START) {
		static int did_start = 0;

		if (!did_start) {
			gettimeofday(&primary_simulator_agent->sa_time_start,
				     NULL);
			primary_simulator_agent->sa_flags |= SAF_TIME_STARTED;
			RPC_notifystart(pid, eid, "", 1);
			RPC_drop();

			did_start = 1;
		}
	}
}

/* Dequeue events from the event queue and fire them at the
   appropriate time.  Runs in a separate thread. */
static void
dequeue(event_handle_t handle)
{
	sched_event_t next_event;
	struct timeval now;
	char time_buf_1[24], time_buf_2[24];

// XXX
//	info("event-sched.c: in dequeue(), about to enter event loop\n");
// XXX
	while (1) {
//		info("event-sched.c: Event loop loops\n");
		if (sched_event_dequeue(&next_event, 1) < 0)
			break;
//		info("event-sched.c: Dequeued another event\n");
		
		/* Fire event. */
		if (debug)
			gettimeofday(&now, NULL);

		if (debug) {
			make_timestamp(time_buf_1, &next_event.time);
			make_timestamp(time_buf_2, &now);
			info("Fire:  note:%p at:%s now:%s agent:%s\n",
			     next_event.notification,
			     time_buf_1, time_buf_2,
			     next_event.agent.s ?
			     (next_event.length == 1 ?
			      next_event.agent.s->name :
			      next_event.agent.m[0]->name) : "*");
		}
		
		if (next_event.flags & SEF_COMPLETE_EVENT) {
			assert(next_event.length == 1);
			
			handle_completeevent(handle, &next_event);
		}
		else if (next_event.length == 1) {
			handle_event(handle, &next_event);
		}
		else if ((next_event.flags & SEF_SINGLE_HANDLER) &&
			 (next_event.agent.m[0]->handler != NULL)) {
			local_agent_queue(next_event.agent.m[0]->handler,
					  &next_event);
		}
		else {
			sched_event_t se_tmp;
			int lpc;

			se_tmp = next_event;
			se_tmp.length = 1;
			for (lpc = 0; lpc < next_event.length; lpc++) {
				se_tmp.agent.s = next_event.agent.m[lpc];
				handle_event(handle, &se_tmp);
			}
		}

		sched_event_free(handle, &next_event);
	}
// XXX
//	info("event-sched.c: in dequeue(), just left event loop\n");
// XXX
}

int
SetExpPath(const char *path)
{
	struct stat st;
	int retval;
	
	setenv("EXPDIR", path, 1);
	retval = chdir(path);

	if (stat("logs", &st) == -1)
		mkdir("logs", 0770);

	return retval;
}

int
AddUserEnv(char *name, char *path)
{
	int retval = 0;
	FILE *file;
	
	/* XXX Kind of a stupid way to eval any variables. */
	if ((file = popenf("echo %s=%s", "r", name, path)) == NULL) {
		retval = -1;
	}
	else {
		char buf[BUFSIZ];

		if (fgets(buf, sizeof(buf), file) != NULL) {
			char *idx;
			
			if ((idx = strchr(buf, '\n')) != NULL)
				*idx = '\0';
			if ((idx = strchr(buf, '=')) != NULL) {
				add_report_data(primary_simulator_agent,
						SA_RDK_CONFIG,
						"  ",
						0);
				add_report_data(primary_simulator_agent,
						SA_RDK_CONFIG,
						buf,
						1);
				*idx = '\0';
				retval = setenv(strdup(buf), idx + 1, 1);
			}
		}
		pclose(file);
		file = NULL;
	}
	
	return 0;
}

/*
 * Stuff to get the event list.
 */
/*
 * Add an agent to the list.
 */
int
AddAgent(event_handle_t handle,
	 char *vname, char *vnode, char *nodeid, char *ipaddr, char *type)
{
	struct agent *agentp;

	info("D:\t\tAddAgent asked to add agent %s\n", vname);		
	if ((agentp = calloc(sizeof(struct agent), 1)) == NULL) {
		error("AddAgent: Out of memory\n");
		return -1;
	}

	strcpy(agentp->name, vname);
	agentp->link.ln_Name = agentp->name;
	
	strcpy(agentp->vnode, vnode);
	strcpy(agentp->objtype, type);

	/*
	 * Look for a wildcard in the vnode slot. As a result
	 * the node_id will come back null from the reserved
	 * table.
	 */
	if (strcmp("*", vnode)) {
		/*
		 * Event goes to specific node.
		 */
		strcpy(agentp->nodeid, nodeid);
		strcpy(agentp->ipaddr, ipaddr);
	}
	else {
		/*
		 * Force events to all nodes. The agents will
		 * need to discriminate on stuff inside the event.
		 */
		strcpy(agentp->nodeid, ADDRESSTUPLE_ALL);
		strcpy(agentp->ipaddr, ADDRESSTUPLE_ALL);
	}
	
	if (strcmp(type, TBDB_OBJECTTYPE_SIMULATOR) == 0) {
		primary_simulator_agent->sa_local_agent.la_link.ln_Name =
			agentp->name;
		primary_simulator_agent->sa_local_agent.la_agent =agentp;
		agentp->handler = &primary_simulator_agent->sa_local_agent;
	}
	else if (strcmp(type, TBDB_OBJECTTYPE_EVPROXY) == 0) {
		static int evproxy_subscribed = 0;

		if (!evproxy_subscribed) {
			address_tuple_t tuple = address_tuple_alloc();
			
			if (tuple == NULL) {
				fatal("could not allocate an address tuple");
			}
			tuple->scheduler = 1;
			tuple->objtype = TBDB_OBJECTTYPE_EVPROXY;
			tuple->eventtype = TBDB_EVENTTYPE_UPDATE;
			
			if (event_subscribe_auth(handle, enqueue,
						 tuple, NULL, 0) == NULL) {
				fatal("could not subscribe to EVENT_SCHEDULE "
				      "event");
			}
			
			evproxy_subscribed = 1;
		}
	}
	else if ((strcmp(type, TBDB_OBJECTTYPE_TIMELINE) == 0) ||
		 (strcmp(type, TBDB_OBJECTTYPE_SEQUENCE) == 0)) {
		timeline_agent_t ta;
		ta_kind_t tk;

		tk = strcmp(type, TBDB_OBJECTTYPE_TIMELINE) == 0 ?
			TA_TIMELINE : TA_SEQUENCE;
		if ((ta = create_timeline_agent(tk)) != NULL) {
			switch (tk) {
			case TA_TIMELINE:
				lnAddTail(&timelines,
					  &ta->ta_local_agent.la_link);
				break;
			case TA_SEQUENCE:
				lnAddTail(&sequences,
					  &ta->ta_local_agent.la_link);
				break;
			default:
				assert(0);
				break;
			}
			ta->ta_local_agent.la_link.ln_Name = agentp->name;
			ta->ta_local_agent.la_agent = agentp;
			agentp->handler = &ta->ta_local_agent;
		}
	}
	else if (strcmp(type, TBDB_OBJECTTYPE_NODE) == 0) {
		node_agent_t na;
		
		if ((na = create_node_agent()) == NULL) {
		}
		else {
			na->na_local_agent.la_agent = agentp;
			agentp->handler = &na->na_local_agent;
		}
	}
	else if (strcmp(type, TBDB_OBJECTTYPE_CONSOLE) == 0) {
		console_agent_t ca;
		
		if ((ca = create_console_agent()) == NULL) {
		}
		else {
			ca->ca_local_agent.la_agent = agentp;
			agentp->handler = &ca->ca_local_agent;
		}
	}
	else if (strcmp(type, TBDB_OBJECTTYPE_TOPOGRAPHY) == 0) {
		topography_name = agentp->name;
	}

	if (agentp->handler != NULL) {
		agentp->handler->la_handle = handle;
	}
	
	assert(agent_invariant(agentp));
	assert(lnFindName(&agents, vname) == NULL);
	
	lnAddTail(&agents, &agentp->link);

	return 0;
}

/*
 * Add an agent group to the list.
 */
int
AddGroup(event_handle_t handle, char *groupname, char *agentname)
{
	struct agent *group = NULL, *agent;
	int retval = 0;

	assert(groupname != NULL);
	assert(strlen(groupname) > 0);
	assert(agentname != NULL);
	assert(strlen(agentname) > 0);

	if ((agent = (struct agent *)lnFindName(&agents, agentname)) == NULL) {
		error("unknown agent %s\n", agentname);
		
		retval = -1;
	}
	else if ((group = (struct agent *)lnFindName(&agents,
						     groupname)) == NULL) {
		group_agent_t ga;

		if ((group = calloc(sizeof(struct agent), 1)) == NULL) {
			// XXX delete_group_agent
			error("out of memory\n");
			
			retval = -1;
		}
		else if ((ga = create_group_agent(group)) == NULL) {
			errorc("cannot create group agent\n");
			
			free(group);
			group = NULL;
			
			retval = -1;
		}
		else {
			ga->ga_local_agent.la_handle = handle;
			
			strcpy(group->name, groupname);
			group->link.ln_Name = group->name;
			strcpy(group->nodeid, ADDRESSTUPLE_ALL);
			strcpy(group->vnode, ADDRESSTUPLE_ALL);
			strcpy(group->objtype, TBDB_OBJECTTYPE_GROUP);
			strcpy(group->ipaddr, ADDRESSTUPLE_ALL);
			group->handler = &ga->ga_local_agent;
			
			lnAddTail(&agents, &group->link);
			lnAddTail(&groups, &ga->ga_local_agent.la_link);
			
			assert(agent_invariant(group));
		}
	}

	if (retval == 0) {
		group_agent_t ga;
		
		ga = (group_agent_t)group->handler;
		if ((retval = group_agent_append(ga, agent)) < 0) {
			errorc("cannot append agent to group\n");
		}
	}

	return retval;
}

int
AddEvent(event_handle_t handle, address_tuple_t tuple,
	 char *exidx, char *ftime, char *objname, char *exargs,
	 char *objtype, char *evttype, char *parent, char *triggertype)
{
	timeline_agent_t     ta = NULL;
	sched_event_t	     event;
	double		     firetime = atof(ftime);
	struct agent	    *agentp = NULL;
	struct timeval	     time;

	info("D: AddEvent asked to add event %s\n", objname);
	if (strcmp(objtype, TBDB_OBJECTTYPE_TIME) == 0) {
		return 0;
	}

	if ((agentp = (struct agent *)lnFindName(&agents, objname)) == NULL) {
		error("AddEvent: Could not map event index %s\n", exidx);
		return -1;
	}
info("AddEvent called with event of triggertype %s\n", triggertype);
	if (strcmp(triggertype, "SWAPOUT")==0) { /* If it is of triggertype SWAPOUT,
						Divert to the ns_swapout sequence
						XXX I am not certain anything else in this function
						apart from timeline_agent_append() is needed, but
						let's assume it is.
						*/
	ta = ns_swapout;
	}
	else if (parent && strlen(parent) > 0) { /* If the event has a parent, we inherit its timeline-agent */
		if (((ta = (timeline_agent_t)lnFindName(&timelines,
							parent)) == NULL) &&
		    ((ta = (timeline_agent_t)lnFindName(&sequences,
							parent)) == NULL)) {
			error("AddEvent: Could not map parent %s\n", parent);
			return -1;
		}
	}
	else {
		ta = ns_timeline; /* It's on the main timeline? */
	}
	
	tuple->host      = agentp->ipaddr;
	tuple->objname   = objname;
	tuple->objtype   = objtype;
	tuple->eventtype = evttype;

	memset(&event, 0, sizeof(event));
	event.notification = event_notification_alloc(handle, tuple);
	if (! event.notification) {
		error("AddEvent: could not allocate notification\n");
		return -1;
	}
	event_notification_set_arguments(handle, event.notification, exargs);

	if (debug)
		info("%8s %10s %10s %10s %10s %10s %s %p\n",
		     ftime, objname, objtype,
		     evttype, agentp->ipaddr, 
		     exargs ? exargs : "",
		     parent,
		     event.notification);

	event_notification_insert_hmac(handle, event.notification);

	/* convert the event into a timeval */
	time.tv_sec  = (int)firetime;
	time.tv_usec = (int)((firetime - (floor(firetime))) * 1000000);
	if (time.tv_usec >= 1000000) {
		time.tv_sec  += 1;
		time.tv_usec -= 1000000;
	}
	event.time = time;
	event.agent.s = agentp;
	event.length = 1;
	event.flags = SEF_SINGLE_HANDLER;
	if (sends_complete(agentp, evttype))
		event.flags |= SEF_SENDS_COMPLETE;
	event_notification_put_int32(handle,
				     event.notification,
				     "TOKEN",
				     next_token);
	next_token += 1;
	
	sched_event_prepare(handle, &event);
	if (ta != NULL)
		timeline_agent_append(ta, &event);
	else
		sched_event_enqueue(event);
	
	return 0;
}

int
AddRobot(event_handle_t handle,
	 struct agent *agent,
	 double init_x,
	 double init_y,
	 double init_o)
{
	sched_event_t se;
	int retval = 0;

	assert(agent != NULL);

	se.agent.s = agent;
	se.notification = event_notification_create(
		handle,
		EA_Experiment, pideid,
		EA_Type, TBDB_OBJECTTYPE_NODE,
		EA_Event, TBDB_EVENTTYPE_SETDEST,
		EA_Name, agent->name,
		EA_ArgFloat, "X", init_x,
		EA_ArgFloat, "Y", init_y,
		EA_ArgFloat, "ORIENTATION", init_o,
		EA_TAG_DONE);
	event_notification_put_int32(handle,
				     se.notification,
				     "TOKEN",
				     next_token);
	next_token += 1;
	
	memset(&se.time, 0, sizeof(se.time));
	se.length = 1;
	se.flags = SEF_SENDS_COMPLETE | SEF_SINGLE_HANDLER;
	
	sched_event_prepare(handle, &se);
	timeline_agent_append(ns_sequence, &se);
	
	return retval;
}

/*
 * Get the static event list from the DB and schedule according to
 * the relative time stamps.
 */
static int
get_static_events(event_handle_t handle)
{
	struct timeval	now;
	address_tuple_t tuple;
	event_notification_t notification;
	sched_event_t	event;

	/*
	 * Construct an address tuple for the notifications. We can reuse
	 * the same one over and over since the data is copied out.
	 */
	tuple = address_tuple_alloc();
	if (tuple == NULL) {
		error("could not allocate an address tuple\n");
		return -1;
	}
	tuple->expt = pideid;

	if (RPC_grouplist(handle, pid, eid)) {
		error("Could not get grouplist from RPC server\n");
		return -1;
	}
	
	if (debug) {
		struct agent *agentp = (struct agent *)agents.lh_Head;

		while (agentp->link.ln_Succ) {
			info("Agent: %15s  %10s %10s %8s %16s\n",
			     agentp->name, agentp->objtype,
			     agentp->vnode, agentp->nodeid,
			     agentp->ipaddr);

			agentp = (struct agent *)agentp->link.ln_Succ;
		}
	}

	sprintf(pideid, "%s/%s", pid, eid);
	gettimeofday(&now, NULL);
	info(" Getting event stream at: %lu:%d\n",  now.tv_sec, now.tv_usec);
	
	if (RPC_eventlist(pid, eid, handle, tuple)) {
		error("Could not get eventlist from RPC server\n");
		return -1;
	}

	event.agent.s = primary_simulator_agent->sa_local_agent.la_agent;
// XXX
info("Automatically scheduling the beginning and end of time\n");
// XXX
	if (event.agent.s != NULL) {
		// XXX emulab-ops experiments might not have a simulator agent

		/* Log when time has officially started. */
		event.notification = event_notification_create(
			handle,
			EA_Experiment, pideid,
			EA_Type, TBDB_OBJECTTYPE_SIMULATOR,
			EA_Event, TBDB_EVENTTYPE_LOG,
			EA_Name, event.agent.s->name,
			EA_Arguments, "Time started",
			EA_TAG_DONE);
		event.time.tv_sec = 1;
		event.time.tv_usec = 1;
		event.length = 1;
		event.flags = SEF_SINGLE_HANDLER;
		event_notification_put_int32(handle,
					     event.notification,
					     "TOKEN",
					     next_token);
		next_token += 1;
	
		sched_event_prepare(handle, &event);
		timeline_agent_append(ns_sequence, &event);
		
		/* Log when time has officially ended. */
		event.notification = event_notification_create(
			handle,
			EA_Experiment, pideid,
			EA_Type, TBDB_OBJECTTYPE_SIMULATOR,
			EA_Event, TBDB_EVENTTYPE_LOG,
			EA_Name, event.agent.s->name,
			EA_Arguments, "Time ended",
			EA_TAG_DONE);
		event.time.tv_sec = 0;
		event.time.tv_usec = 0;
		event.length = 1;
		event.flags = SEF_SINGLE_HANDLER;
		event_notification_put_int32(handle,
					     event.notification,
					     "TOKEN",
					     next_token);
		next_token += 1;
	
		sched_event_prepare(handle, &event);
		timeline_agent_append(ns_teardown, &event);

		/* Log when swapout events have officially started. */
		event.notification = event_notification_create(
			handle,
			EA_Experiment, pideid,
			EA_Type, TBDB_OBJECTTYPE_SIMULATOR,
			EA_Event, TBDB_EVENTTYPE_LOG,
			EA_Name, event.agent.s->name,
			EA_Arguments, "Swapout started",
			EA_TAG_DONE);
		event.time.tv_sec = 0;
		event.time.tv_usec = 0;
		event.length = 1;
		event.flags = SEF_SINGLE_HANDLER;
		event_notification_put_int32(handle,
					     event.notification,
					     "TOKEN",
					     next_token);
		next_token += 1;

		sched_event_prepare(handle, &event);
		timeline_agent_append(ns_swapout, &event);
	}
	
	/*
	 * Generate a TIME starts message.
	 */
	tuple->host      = ADDRESSTUPLE_ALL;
	tuple->objname   = ADDRESSTUPLE_ANY;
	tuple->objtype   = TBDB_OBJECTTYPE_TIME;
	tuple->eventtype = TBDB_EVENTTYPE_START;
	
	notification = event_notification_alloc(handle, tuple);
	if (! notification) {
		error("could not allocate notification\n");
		return -1;
	}
	event_notification_insert_hmac(handle, notification);
	event.notification = notification;
	event.time.tv_sec  = 0;
	event.time.tv_usec = 1;
	event.agent.s = NULL;
	event.length = 1;
	event.flags = SEF_TIME_START;
	event_notification_put_int32(handle,
				     event.notification,
				     "TOKEN",
				     next_token);
	next_token += 1;
	timeline_agent_append(ns_sequence, &event);

	/* Start the main timeline */
	event.agent.s = &ns_timeline_agent;
	event.notification = event_notification_create(
		handle,
		EA_Experiment, pideid,
		EA_Type, TBDB_OBJECTTYPE_TIMELINE,
		EA_Event, TBDB_EVENTTYPE_START,
		EA_Name, ns_timeline_agent.name,
		EA_TAG_DONE);
	event.time.tv_sec = 0;
	event.time.tv_usec = 1;
	event.length = 1;
	event.flags = SEF_SENDS_COMPLETE | SEF_SINGLE_HANDLER;
	event_notification_put_int32(handle,
				     event.notification,
				     "TOKEN",
				     next_token);
	next_token += 1;
	
	sched_event_prepare(handle, &event);
	timeline_agent_append(ns_sequence, &event);

	if (expt_state == ES_ACTIVE) {
		event_do(handle,
			 EA_Experiment, pideid,
			 EA_Type, TBDB_OBJECTTYPE_SEQUENCE,
			 EA_Event, TBDB_EVENTTYPE_START,
			 EA_Name, ns_sequence_agent.name,
			 EA_TAG_DONE);
	}
// XXX
// info("Returning from get_static_events()\n");	
// XXX
	return 0;
}

int
sched_event_enqueue_copy(event_handle_t handle,
			 sched_event_t *se,
			 struct timeval *new_time)
{
	sched_event_t se_copy = *se;
	int retval = 0;

	assert(handle != NULL);
	assert(se != NULL);
	assert(se->length > 0);
	assert(new_time != NULL);

	se_copy.notification =
		event_notification_clone(handle, se->notification);
	if (new_time != NULL)
		se_copy.time = *new_time;
	sched_event_prepare(handle, se);
	sched_event_enqueue(se_copy);
	
	return retval;
}

void
sched_event_free(event_handle_t handle, sched_event_t *se)
{
	assert(handle != NULL);
	assert(se != NULL);

	if (se->length == 0) {
	}
	else {
		event_notification_free(handle, se->notification);
		se->notification = NULL;
	}
}

static int
handle_completeevent(event_handle_t handle, sched_event_t *eventp)
{
	char *value, argsbuf[BUFSIZ] = "";
	char objname[TBDB_FLEN_EVOBJNAME];
	char objtype[TBDB_FLEN_EVOBJTYPE];
	int rc, ctoken = ~0, agerror = 0, handled = 0;

	event_notification_insert_hmac(handle, eventp->notification);
	event_notify(handle, eventp->notification);

	event_notification_get_objname(handle, eventp->notification,
				       objname, sizeof(objname));

	event_notification_get_objtype(handle, eventp->notification,
				       objtype, sizeof(objtype));

	event_notification_get_arguments(handle, eventp->notification,
					 argsbuf, sizeof(argsbuf));
	
	if ((rc = event_arg_get(argsbuf, "ERROR", &value)) > 0) {
		if (sscanf(value, "%d", &agerror) != 1) {
			error("bad error value for complete: %s\n", argsbuf);
		}
	}
	else {
		warning("completion event is missing ERROR argument\n");
	}
	
	if ((rc = event_arg_get(argsbuf, "CTOKEN", &value)) > 0) {
		if (sscanf(value, "%d", &ctoken) != 1) {
			error("bad ctoken value for complete: %s\n", argsbuf);
		}
	}
	else {
		warning("completion event is missing CTOKEN argument\n");
	}

	if (debug) {
		char time_buf_1[24];
		struct timeval now;

		gettimeofday(&now, NULL);
		make_timestamp(time_buf_1, &now);
			
		info("Done:  now:%s CTOKEN=%d ERROR=%d\n",
		     time_buf_1, ctoken, agerror);
	}

	if (agerror != 0 && agerror != ~0) {
		error_record_t er;
		
		if ((er = create_error_record()) == NULL) {
			errorc("could not allocate error record");
		}
		else {
			er->er_agent = eventp->agent.s;
			er->er_token = ctoken;
			er->er_error = agerror;
			lnAddTail(&primary_simulator_agent->sa_error_records,
				  &er->er_link);
		}
	}

	handled = sequence_agent_handle_complete(handle,
						 &sequences,
						 eventp->agent.s,
						 ctoken,
						 agerror);

	handled += group_agent_handle_complete(handle,
					       &groups,
					       eventp->agent.s,
					       ctoken,
					       agerror);

	if ((strcmp(objtype, TBDB_OBJECTTYPE_TIMELINE) == 0) ||
	    (strcmp(objtype, TBDB_OBJECTTYPE_SEQUENCE) == 0)) {
		RPC_grab();
		RPC_notifystart(pid, eid, objname, 0);
		RPC_drop();

	}
	
	if ((primary_simulator_agent != NULL) &&
	    (agerror != 0) &&
	    ((strcmp(objtype, TBDB_OBJECTTYPE_SEQUENCE) == 0) ||
	     (strcmp(objtype, TBDB_OBJECTTYPE_GROUP) == 0)) &&
	    !handled) {
		send_error_report(primary_simulator_agent, "");
	}
	
	return 1;
}

/*
 * Record events to DB
 */
static FILE	*recordevents_fp;

static void
RecordEventsInit(void)
{
	/*
	 * Open up file and write a header that describes the format.
	 */
	if ((recordevents_fp = fopen(recordevents_filename, "w")) == NULL) {
		fatal("Could not open recordevents_filename for writing");
	}

	fprintf(recordevents_fp,
		"arrivaltime,firetime,vnode,objname,objecttype,eventtype,"
		"parent,arguments\n");
	fflush(recordevents_fp);
}

static void
RecordEvent(sched_event_t *eventp, char *eventtype, char *parent, char *args)
{
	struct timeval now;
	struct agent *agentp = eventp->agent.s;

	gettimeofday(&now, NULL);

	fprintf(recordevents_fp,
		"%ld:%ld,%ld:%ld,%s,%s,%s,%s,%s,%s\n",
		now.tv_sec, now.tv_usec,
		eventp->time.tv_sec, eventp->time.tv_usec,
		agentp->vnode, agentp->name, agentp->objtype, eventtype,
		parent, args);
	fflush(recordevents_fp);
}
