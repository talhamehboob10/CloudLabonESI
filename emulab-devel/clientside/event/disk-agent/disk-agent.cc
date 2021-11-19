/*
 * Copyright (c) 2010-2012 University of Utah and the Flux Group.
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

/* This program implements the Disk agent for Emulab.
 * It listens to objtype "disk" and creates/modifies/ device mapper(DM)
 * disks. Also, we can inject errors of various types on these DM disks.
 */

#include <cassert>
#include <cmath>
#include <ctime>
#include <string>
#include <map>
#include <list>
#include <vector>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <fstream>
#include <paths.h>
#include <fcntl.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/resource.h>
#include <cerrno>
#include "log.h"
#include <cstdio>
#include <algorithm>
#include <dirent.h>
#include <ctype.h>
extern "C" {
	#include "libdevmapper.h"
	#include "be_user.h" 
}

#ifdef HAVE_ELVIN
#include <elvin/elvin.h>
#endif

#include <sys/time.h>

using namespace std;

// For getopt
#include <unistd.h>

#include "event.h"
#include "tbdefs.h"
#define LINE_SIZE 4096
#define MAX_BUFFER 4096
#define err(msg, x...) fprintf(stderr, msg "\n", ##x)

/* Hard coding the number of disks we allow for now to keep things simpler */
#define MAX_DISKS 10

/* A flag to init vols only when required */
int done_init_vols = 0;

/**
 * Structure used to track individual agents.
 */
struct diskinfo {
    char        name[TBDB_FLEN_EVOBJNAME];

    char           *initial_cmdline;
    char           *cmdline;
	char 		   *type;
	char 		   *initial_type;
	char		   *mountpoint;
	char		   *initial_mountpoint;
	char		   *parameters;
	char		   *initial_parameters;	
	char		   *volname;
	unsigned long   size;
    int     pid;
	unsigned long   token;
    struct diskinfo *next;
};

/*
 * Refers to the head of the agent list.
 */
static struct diskinfo *diskinfos;


/*
 * The name of the token file, which holds a completion token.
 */
static char  *tokenfile;

/*
 * Our vnode name, for subscribing to events for the program agent itself.
 */
static char             *vnode;


/* Maximum allowed disks */
static int numdisks;

/* Maximum allowed disk partitions */
static int volindex = 0;

static char *LOGDIR = "/local/logs";

char * _table = NULL;

enum { EVENT_BUFFER_SIZE = 5000 };

namespace g
{
  std::string experimentName;
  bool debug = false;
}

vector<string> device_params;

void readArgs(int argc, char * argv[]);
void usage(char * name);

/**
 * Parse the configuration file containing the list of agents and their initial
 * settings.
 *
 * @param filename The name of the config file.
 * @return Zero on success, -1 otherwise.
 */
static int  parse_configfile(char *filename);
static void set_disk(struct diskinfo *dinfo, char *args);



// Reads the map file, initializes the pipe and pipeVault data
// structure, and sets up the two subscription strings for events.
void writePidFile(string const & pidFile);
void initEvents(string const & server, string const & port,
                string const & keyFile, string const & subscription,
                string const & group);
void subscribe(event_handle_t handle, address_tuple_t eventTuple,
               string const & subscription, string const & group);
void callback(event_handle_t handle,
              event_notification_t notification, void *data);

/**
 * Handler for the TIME start event.  This callback will stop all running
 * disks, reset the disk agent configuration to the original version specified in
 * the config file, and delete all the files in the log directory.
 *
 * @param handle The connection to the event system.
 * @param notification The start event.
 * @param data NULL
 */
static void start_callback(event_handle_t handle,
                   event_notification_t notification,
                   void *data);


//DM Device routines
int create_dm_device(struct diskinfo *dinfo, unsigned long   token, char *);
int run_dm_device(struct diskinfo *dinfo, unsigned long   token, char *);
int modify_dm_device(struct diskinfo *dinfo, unsigned long   token, char *);
int resume_dm_device(char *);
static int _device_info(char *);
static int _parse_line(struct dm_task *, char *, const char *,int);
static int _parse_file(struct dm_task *, const char *);
static void _display_info_long(struct dm_task *,  struct dm_info *);
int _get_device_params(const char *);
string exec_output(string);
string itos(int );

/* Initialize the partitions that will be used by disk-agent.
 * LVM is being used to make logical volumes to ease the pain
 * instead of having to deal with physical volumes.
 * We allow 10 disks as of now. Maybe we should change this in
 * the future.
 */
void init_volumes(void)
{
        string cmd;
		stringstream vol_list;
		struct diskinfo *pi;

        /* Since creating partitions on real disk is painful, we
         * make use of lvm and give logical volumes to host disks.
         * mkextrafs script which will create logical volumes of 
		 * specified size.
         */
        cout << "Creating the disk partition ..." << endl;
        for (pi = diskinfos; pi != NULL; pi = pi->next) {
               vol_list << (pi->volname) << ",";
        }
        vol_list << " -z ";
        for (pi = diskinfos; pi != NULL; pi = pi->next) {
                vol_list << (pi->size) << ",";
        }

        cout << "Volume list and size list" <<endl;
        cout << vol_list.str() <<endl;
        cmd = "/usr/testbed/bin/mkextrafs -f -q -l -m "+vol_list.str();

        int i = system(const_cast<char *>(cmd.c_str()));
        if(i)
        {
                cerr << "Failed to init logical vols" <<endl;
                exit(1);
        }

}


/**
 * Dump the diskinfos list to standard out.
 */
static void
dump_diskinfos(void)
{
    struct diskinfo *pi;

    for (pi = diskinfos; pi != NULL; pi = pi->next) {
        printf(
               "  Name: %s\n"
               "  type: %s\n"
               "  mountpoint: %s\n"
               "  parameters: %s\n"
               "  command: %s\n"
			   "  vol_name: %s\n"
			   "  vol_size: %lu MB\n",	
               pi->name ? pi->name : "(not set)",
               pi->type ? pi->type : "(not set)",
               pi->mountpoint ? pi->mountpoint : "(not set)",
               pi->parameters ? pi->parameters : "(not set)",
               pi->cmdline ? pi->cmdline : "(not set)",
			   pi->volname ? pi->volname : "(not set)",
			   pi->size ? pi->size : 0
               );
    }
}

/*
 * Open a new log file for a disk agent and update the symlink used to refer
 * to the latest invocation of the agent.
 *
 * @param dinfo The dinfo we are opening the logs for.
 * @param type The log type: "out" for standard out and "err" for standard
 * error.
 * @return The new file descriptor or -1 if there was a failure.
 */
static int
open_logfile(struct diskinfo *dinfo, const char *type)
{
    char buf[BUFSIZ], buf2[BUFSIZ];
    int error = 0, retval;

    assert(dinfo != NULL);
    assert(type != NULL);
    assert((strcmp(type, "out") == 0) || (strcmp(type, "err") == 0));

    /*
     * Construct the name of the log file, which is made up of the program
     * agent name, the event token, and the type (e.g. out, err).
     */
    snprintf(buf, sizeof(buf),
         "%s/%s.%s.%lu",
         LOGDIR, dinfo->name, type, dinfo->token);
    if ((retval = open(buf, O_WRONLY|O_CREAT|O_TRUNC, 0640)) < 0) {
        errorc("could not create log file %s\n", buf);
    }
    else {
        /*
         * We've successfully created the file, now create the
         * symlinks to that refer to the last run and a tagged run.
         */
        snprintf(buf, sizeof(buf),
             "./%s.%s.%lu",
             dinfo->name, type, dinfo->token);
        snprintf(buf2, sizeof(buf2),
             "%s/%s.%s",
             LOGDIR, dinfo->name, type);
        if ((unlink(buf2) < 0) && (errno != ENOENT)) {
            error = 1;
            errorc("could not unlink old last run link %s\n",
                   buf2);
        }
        else if (symlink(buf, buf2) < 0) {
            error = 1;
            errorc("could not symlink last run %s\n", buf);
        }
        #if 0
        if (dinfo->tag != NULL) {
            snprintf(buf2, sizeof(buf2),
                 "%s/%s.%s.%s",
                 LOGDIR, dinfo->name, dinfo->tag, type);
            if ((unlink(buf2) < 0) && (errno != ENOENT)) {
                error = 1;
                errorc("could not unlink old tag link %s\n",
                       buf2);
            }
            else if (symlink(buf, buf2) < 0) {
                error = 1;
                errorc("could not symlink tagged run %s\n",
                       buf);
            }
        }
        #endif

    }

    if (error) {
        close(retval);
        retval = -1;
    }

    return retval;
}

/*
 * Returns the disk agent structure given the disk name
 */
static struct diskinfo *
find_agent(char *name)
{
    struct diskinfo *dinfo, *retval = NULL;

    dinfo = diskinfos;
    while (dinfo) {
        if (! strcmp(dinfo->name, name)) {
            retval = dinfo;
            break;
        }
        dinfo = dinfo->next;
    }

    return retval;
}

int main(int argc, char * argv[])
{
  cout << "Beginning program" << endl;
  readArgs(argc, argv);
  return 0;
}

/*
 * Parse the command line arguments and initialize the event system
 */
void readArgs(int argc, char * argv[])
{
  cout << "Processing arguments" << endl;
  string server;
  string port;
  char *logfile = NULL;
  char *pidfile = NULL;
  char *configfile;
  string keyFile;
  string subscription;
  string group;
  string user;
  char buf[MAX_BUFFER];
  FILE *fp;

  // Prevent getopt from printing an error message.
  opterr = 0;

  /* get params from the optstring */
  char const * argstring = "hds:p:l:u:i:e:c:k:o:g:v:t:U:";
  int option = getopt(argc, argv, argstring);
  while (option != -1)
  {
    switch (option)
    {
	case 'h':
	  usage(argv[0]);
	  break;
    case 'd':
      g::debug = true;
      pubsub_debug = 1;
      break;
    case 's':
      server = optarg;
      break;
    case 'p':
      port = optarg;
      break;
	case 'l':
	  logfile = optarg;
	  break;
	case 'c':
	  configfile = optarg;
	  break;
    case 'e':
      g::experimentName = optarg;
      break;
    case 'k':
      keyFile = optarg;
      break;
    case 'u':
      subscription = optarg;
      break;
	case 'o':
	  LOGDIR = optarg;
	  break;
	case 'i':
	  pidfile = optarg;
	  break;
	case 't':
	  tokenfile = optarg;
	  break;
	case 'v':
	  vnode = optarg;
	  break;
    case 'g':
      group = optarg;
      break;
    case 'U':
      user = optarg;
      break;
    default:
      usage(argv[0]);
      break;
    }
    option = getopt(argc, argv, argstring);
  }

  /*Check if all params are specified, otherwise, print usage and exit*/
  if(server == "" || user == "" || g::experimentName == "")
      usage(argv[0]);

  /*
   * Write out a pidfile if root.
   */
  if (!getuid()) {
		if (pidfile)
            strcpy(buf, pidfile);
        else
            sprintf(buf, "%s/diskagent.pid", _PATH_VARRUN);
        fp = fopen(buf, "w");
        if (fp != NULL) {
            fprintf(fp, "%d\n", getpid());
            (void) fclose(fp);
        }
  }

  be_user(const_cast<char *>(user.c_str()));

  if(g::debug)
	loginit(0, logfile);
  else {
	if(logfile)
		loginit(0, logfile);
	else
		loginit(1, "disk-agent");
  }
	
  if (parse_configfile(configfile) != 0)
  {
      cerr << "Error while parsing config file" <<endl;
      exit(1);
  }


  initEvents(server, port, keyFile, subscription, group);
}

void usage(char * name)
{
  cerr << "Usage: " << name << " -e proj/exp -s server -U user [-h][-d] [-p port] "
       << "[-l logfile] [-c config file] [-i pidFile] [-k keyFile] [-u subscription] [-g group]" << endl;
  exit(-1);
}

/*
 * Initialize the event system and listen for notifications
 */
void initEvents(string const & server, string const & port,
                string const & keyFile, string const & subscription,
                string const & group)
{
  cout << "Initializing event system" << endl;
  string serverString = "elvin://" + server;
  event_handle_t handle;
  if (port != "")
  {
    serverString += ":" + port;
  }
  cerr << "Server string: " << serverString << endl;
  if (keyFile != "")
  {
    handle = event_register_withkeyfile(const_cast<char *>(serverString.c_str()), 0,
                                        const_cast<char *>(keyFile.c_str()));
  }
  else
  {
    handle = event_register_withkeyfile(const_cast<char *>(serverString.c_str()), 0, NULL);
  }
  if (handle == NULL)
  {
    cerr << "Could not register with event system" << endl;
    exit(1);
  }

  address_tuple_t eventTuple = address_tuple_alloc();

  subscribe(handle, eventTuple, subscription, group);

  address_tuple_free(eventTuple);

  /* Completion Event support for disk-agent */
  if (tokenfile && access(tokenfile, R_OK) == 0) {
       FILE    *fp;
       unsigned long   token = ~0;
       string buf = vnode;
       buf = buf+"disk_agent";

        if ((fp = fopen(tokenfile, "r")) != NULL) {
                if (fscanf(fp, "%lu", &token) == 1) {
                        event_do(handle,
                                 EA_Experiment, const_cast<char *>(g::experimentName.c_str()),
                                 EA_Type, TBDB_OBJECTTYPE_DISK,
                                 EA_Name, const_cast<char *>(buf.c_str()),
                                 EA_Event, TBDB_EVENTTYPE_COMPLETE,
                                 EA_ArgInteger, "ERROR", 0,
                                 EA_ArgInteger, "CTOKEN", token,
                                 EA_TAG_DONE);
                  }
                  else {
                         printf("tokenfile could not be parsed!\n");
                  }
         }
         else {
                  printf("Could not open token file for reading!");
         }
    }


  /*
   * Begin the event loop, waiting to receive event notifications:
   */
 
  while(1) {
	if(event_main(handle) == 0)
		cerr << "Event main stopped!" << endl;
  }

}

/*
 * Subscribes to the events we want from the event system.
 */
void subscribe(event_handle_t handle, address_tuple_t eventTuple,
               string const & subscription, string const & group)
{
  char agentlist[MAX_BUFFER];
  bzero(agentlist, sizeof(agentlist));
  struct diskinfo *dinfo;

  string name = subscription;
  if (group != "")
  {
    name += "," + group;
  }
  /*
   * Cons up the agentlist for subscription below.
   */
  dinfo = diskinfos;
  while (dinfo) {

  	if (strlen(agentlist))
        strcat(agentlist, ",");
    	strcat(agentlist, dinfo->name);

        dinfo = dinfo->next;
  }

  eventTuple->objname = agentlist;
  eventTuple->objtype = TBDB_OBJECTTYPE_DISK;
  eventTuple->eventtype = 
				TBDB_EVENTTYPE_START ","
				TBDB_EVENTTYPE_RUN ","
				TBDB_EVENTTYPE_CREATE ","
				TBDB_EVENTTYPE_MODIFY;
  eventTuple->expt = const_cast<char *>(g::experimentName.c_str());
  eventTuple->host = ADDRESSTUPLE_ANY;
  eventTuple->site = ADDRESSTUPLE_ANY;
  eventTuple->group = ADDRESSTUPLE_ANY;
  if (event_subscribe(handle, callback, eventTuple, NULL) == NULL)
  {
    cerr << "Could not subscribe to " << eventTuple->eventtype << " event" << endl;

  }
  
    eventTuple->objtype   = TBDB_OBJECTTYPE_TIME;
    eventTuple->objname   = ADDRESSTUPLE_ANY;
    eventTuple->eventtype = TBDB_EVENTTYPE_START;

    /*
     * Subscribe to the TIME start event we specified above.
     */
    if (! event_subscribe(handle, start_callback, eventTuple, NULL)) {
        cerr << "could not subscribe to event" << endl;
    }

}

/*
 * Event handler:
 * Receives notification from the event system.
 * Calls appropriate event handler.
 */
void callback(event_handle_t handle,
              event_notification_t notification,
              void * data)
{
  char name[EVENT_BUFFER_SIZE];
  char type[EVENT_BUFFER_SIZE];
  char args[EVENT_BUFFER_SIZE];
  unsigned long   token = ~0;
  int pid, in_fd, out_fd = -1, err_fd = -1;
  
  struct diskinfo *dinfo;

  struct timeval basicTime;
  gettimeofday(&basicTime, NULL);
  map<string, int> eventtype;

  eventtype["CREATE"]  = 0;
  eventtype["MODIFY"]  = 1;
  eventtype["STOP"]    = 2;
  eventtype["RUN"]     = 3;
  eventtype["START"]   = 3;

  double floatTime = basicTime.tv_sec + basicTime.tv_usec/1000000.0;
  ostringstream timeStream;
  timeStream << setprecision(3) << setiosflags(ios::fixed | ios::showpoint);
  timeStream << floatTime;
  string timestamp = timeStream.str();


  if (event_notification_get_string(handle, notification, const_cast<char *>("OBJNAME"), name, EVENT_BUFFER_SIZE) == 0)
  {
    cerr << timestamp << ": ERROR: Could not get the object name" << endl;
    return;
  }


  if (event_notification_get_string(handle, notification, const_cast<char *>("EVENTTYPE"), type, EVENT_BUFFER_SIZE) == 0)
  {
    cerr << timestamp << ": ERROR: Could not get the event type" << endl;
    return;
  }
  string event = type;
	 
  event_notification_get_string(handle, notification,const_cast<char *>("ARGS"), args, EVENT_BUFFER_SIZE); 
  
 
  /* Find the agent and */
  dinfo = find_agent(name);
  if (!dinfo) {
      cout << "Invalid disk agent: "<< name <<endl;
      return;
  }

  event_notification_get_int32(handle, notification,
                     "TOKEN", (int32_t *)&token);

    /*
     * The command is going to be run via the shell.
     * We do not know anything about the command line, so we reinit
     * the log file so that any output goes into a different file. If
     * the user command line includes a redirection, that will get the
     * output since the sh will set up the descriptors appropriately.
     */
    if (((out_fd = open_logfile(dinfo, "out")) < 0) ||
        ((err_fd = open_logfile(dinfo, "err")) < 0)) {
        if (out_fd >= 0)
            close(out_fd);
        if (err_fd >= 0)
            close(err_fd);

        cerr << "could not setup log files" <<endl;
        exit(1);
    }

    if (out_fd != STDOUT_FILENO) {
        dup2(out_fd, STDOUT_FILENO);
        close(out_fd);
    }
    if (err_fd != STDERR_FILENO) {
        dup2(err_fd, STDERR_FILENO);
        close(err_fd);
    }

    close(STDIN_FILENO);
    if ((in_fd = open(_PATH_DEVNULL, O_RDONLY)) >= 0) {
        if (in_fd != STDIN_FILENO) {
            dup2(in_fd, STDIN_FILENO);
            close(in_fd);
        }
    }

  /* Call the event handler routine based on the event */
  switch(eventtype[event])
  {
	int ret;
	case 0:
		/* Avoid creating lvm partitions until needed
  		   done_init_flags is being used for this purpose
		 */
		if(!done_init_vols) {
			init_volumes();
			done_init_vols=1;
		}

		/* Create a dm device with the given command line */
        if(!(ret = create_dm_device(dinfo, token, args)))
			   cerr << "DM failed in create_dm_device()" << endl;

		/* Send completion event back to the event system */
	    event_do(handle,
				EA_Experiment, const_cast<char *>(g::experimentName.c_str()),
				EA_Type, TBDB_OBJECTTYPE_DISK,
				EA_Name, dinfo->name,
				EA_Event, TBDB_EVENTTYPE_COMPLETE,
				EA_ArgInteger, "ERROR", !ret,
				EA_ArgInteger, "CTOKEN", token,
				EA_TAG_DONE);

		event="";
		break;
  	case 1:
        /* Avoid creating lvm partitions until needed
           done_init_flags is being used for this purpose
         */
        if(!done_init_vols) {
            init_volumes();
            done_init_vols=1;
        }

		/* Modify the dm disk with the give command line */
		if(!(ret = modify_dm_device(dinfo, token, args)))
			cerr << "DM failed in modify_dm_device()" << endl;

		/* Send completion event back to the event system */
        event_do(handle,
                EA_Experiment, const_cast<char *>(g::experimentName.c_str()),
                EA_Type, TBDB_OBJECTTYPE_DISK,
                EA_Name, dinfo->name,
                EA_Event, TBDB_EVENTTYPE_COMPLETE,
                EA_ArgInteger, "ERROR", !ret,
                EA_ArgInteger, "CTOKEN", token,
                EA_TAG_DONE);
	
		event="";
	 	break;	
	case 2:
		break;
	case 3:
        /* Avoid creating lvm partitions until needed
           done_init_flags is being used for this purpose
         */
        if(!done_init_vols) {
            init_volumes();
            done_init_vols=1;
        }
		
		/* Run the dm device with the given args */
		if(!(ret = run_dm_device(dinfo, token, args)))
			 cerr << "DM failed in run_dm_device()" << endl;

		/* Send completion event back to the event system */
        event_do(handle,
                EA_Experiment, const_cast<char *>(g::experimentName.c_str()),
                EA_Type, TBDB_OBJECTTYPE_DISK,
                EA_Name, dinfo->name,
                EA_Event, TBDB_EVENTTYPE_COMPLETE,
                EA_ArgInteger, "ERROR", !ret,
                EA_ArgInteger, "CTOKEN", token,
                EA_TAG_DONE);


		event="";
		break;
	default:
		cerr << "Don't recognize the event type" << endl;
  }
 
}

/*
 * Handles case where user specifies a disk type and a mountpoint.
 * This routine creates a new disk if it does not exist and mounts it.
 * If the disk already exists then it will simply change the parameters
 * specified by the user.
 */
int run_dm_device(struct diskinfo *dinfo,  unsigned long token, char *args)
{
	struct dm_task *dmt;

	set_disk(dinfo, args);

	/* Check if the required parameters for this event is supplied 
	 */
	if(!dinfo->type || !dinfo->mountpoint) 
	{
		cerr << "Disk type or mountpoint not specified" <<endl;
		return 0;
	}
		
	dinfo->token = token;

    /* DEBUG */
    cout <<"Event START/RUN"<<endl;
    dump_diskinfos();


	if (_device_info(dinfo->name)) {
		/* DM device exists so we'll reload it with params supplied */
		uint64_t start=0, length=0;
	    char *target_type=NULL, *params=NULL;
		
		string params_str="", diskname="";
		stringstream split;

	 	if (!(dmt = dm_task_create(DM_DEVICE_RELOAD))) {
            cout << "in dm task create"<<endl;
            return 0;
        }		
		if ( !dm_task_set_name(dmt, dinfo->name)){
			dm_task_destroy(dmt);
            return 0;
		}
	
		if (!(_get_device_params(dinfo->name))) {
			dm_task_destroy(dmt);
            return 0;
		}
		cout << device_params[0] << device_params[1] << device_params[2] << device_params[3] << device_params[4] << endl;
	
		start 		    = strtoul (device_params[0].c_str(),NULL,0);
		length 		    = strtoul (device_params[1].c_str(),NULL,0);
		target_type 	= dinfo->type;

		split		   << device_params[3];

		/* Get the diskname from dm parameters */
		getline(split,diskname,' ');
		
		if(dinfo->parameters == NULL)
			dinfo->parameters = " ";
	
		/* For error DM type, we might not the disk name.
		 * So we store the major:minor number in device_params[4].
		 * Useful for converting error disk back to linear.
		 */  
           	
		 if(diskname == "")
			diskname = device_params[4];

 		params_str 	= diskname + " " + "0 "+ dinfo->parameters;
		cout << "diskname after "<<params_str<<endl;
		params 		= const_cast<char *>(params_str.c_str());

		cout <<"start: "<<start<<" "<<"len: "<<length<<" "<<"target_type: "<<target_type<<"parameters: "<<params<<endl;	
		
		if (!dm_task_add_target(dmt, start, length, target_type, params)) {
				dm_task_destroy(dmt);
                return 0;
		}
		/* Now that we have the dm ready; Run it. */
		if (!dm_task_run(dmt)){
				dm_task_destroy(dmt);
                return 0;
		}
		/* After running dm_task_run, dm_devices would
			not appear in /dev/mapper. Need to call these
			routines to fix that.
		*/
		dm_udev_wait(0);
		dm_task_update_nodes();

		/* Resume this dm device for changes to take effect. */
		resume_dm_device(dinfo->name);
		dm_task_destroy(dmt);
		return 1;

	}	
 	else {
		char *ttype=NULL, *ptr=NULL;
		unsigned long long start, size;
		string str,cmd;

		/* DM device does not exist. So we'll create it. */
		if(!(dmt = dm_task_create(DM_DEVICE_CREATE))){
        	cout << "in dm task create"<<endl;
	        return 0;
       	}

		/* Set properties on the new dm device */
		string prefix = "/dev/mapper/";
		
		if(dinfo->name == NULL)
		{
			cerr << "Disk name not specified!" <<endl;
			return 0;
		}

		string dm_disk_name = prefix + dinfo->name;
		if (!dm_task_set_name(dmt, dinfo->name)) {
			cout << "in task set name"<<endl;
			dm_task_destroy(dmt);
			return 0;
		}

		/* Make a default ext3 filesystem on the lvm volume.
 		 * The lvm volume will have the size specified by
		 * the user. And therefore maintained in the dinfo
		 * structure. 
		 */
        cmd = dinfo->volname;
		cmd = "mkfs.ext3 /dev/emulab/"+cmd;
		int i = system(const_cast<char *>(cmd.c_str()));

		string disk = dinfo->volname;
		disk = "/dev/emulab/"+disk;

		/* So we have the new partition. Find out the
		 * size of partition to create the new dm disk.
		 */
		cmd = "blockdev --getsz "+disk;
		string str_size = exec_output(cmd);
		if (str_size == "") {
			dm_task_destroy(dmt);
            return 0;
		}
		
		cout << "Mapping the virtual disk " << dinfo->name << "on "<<disk<< endl; 
		/*
		 * Hardcoding all the values.
		 * Users need not to worry about the geometry of the disk such as the start
		 * sector, end sector, size etc.
		 */
		start = 0;
		size = strtoul(const_cast<char *>(str_size.c_str()), NULL, 0);
		ttype = dinfo->type;
		if (dinfo->parameters != NULL) {
			str = dinfo->parameters;
			str.erase(std::remove(str.begin(), str.end(), '\n'), str.end());
			string params = disk + " 0 " + str;
			params.erase(std::remove(params.begin(), params.end(), '\n'), params.end());
			ptr = const_cast<char *>(params.c_str());
			cout <<"PARAMETERS: "<<params<<endl;
		}
	
		else {
			string params = disk+" 0";
			params.erase(std::remove(params.begin(), params.end(), '\n'), params.end());
			ptr = const_cast<char *>(params.c_str());
			cout <<"PARAMETERS: "<<params<<endl;
		}

		cout <<start<<" "<<size<<" "<<ttype<<" "<<ptr<<endl;
		if (!dm_task_add_target(dmt, start, size, ttype, ptr)) {
			dm_task_destroy(dmt);
			return 0;
		}
		/* Now that we have the dm ready; Run it. */
		if (!dm_task_run(dmt)){
			cout <<"in task run"<<endl;
			dm_task_destroy(dmt);
			return 0;
		}

		dm_udev_wait(0);
        dm_task_update_nodes();

		dm_disk_name.erase(std::remove(dm_disk_name.begin(), dm_disk_name.end(), ' '), dm_disk_name.end());

		_device_info(const_cast<char *>(dm_disk_name.c_str()));
		if(dinfo->mountpoint == NULL)
		{
				cerr << "Mountpoint not specified!" << endl;
				dm_task_destroy(dmt);
				return 0;
		}
		str = dinfo->mountpoint;
		cmd = "mkdir -p "+str;
		i = system(const_cast<char *>(cmd.c_str()));
		if(i)
		{
				cerr << "Could not create mountpoint" <<endl;
				dm_task_destroy(dmt);
				return 0;
		}

		cmd = "mount -t ext3 "+dm_disk_name+" "+str;
		i = system(const_cast<char *>(cmd.c_str()));
		if(i)
		{
				--volindex;
				cerr << "mount failed " <<endl;
				dm_task_destroy(dmt);
				return 0;
		}
		cout << dinfo->name << " is mounted on " <<str <<endl;
		dm_task_destroy(dmt);
		return 1;
	}
	return 1;
}



/* This routine will create a device mapper(DM) device.
* It takes the arguments through the buffer and
* name specifies the name of the DM device.
*/
int create_dm_device(struct diskinfo *dinfo, unsigned long token, char *args)
{
	struct dm_task *dmt;
	string str="";
	int r=0;

	set_disk(dinfo, args);

	dinfo->token = token;

    /* DEBUG */
    cout <<"Event CREATE"<<endl;
    dump_diskinfos();

    if(dinfo->cmdline == NULL) {
        cerr << "Cmdline is empty!" << endl;
        return 0;
    }

	/* Create a new dm device */
	if(!(dmt = dm_task_create(DM_DEVICE_CREATE))){
		cout << "in dm task create"<<endl;
		return 0;
	}

    /* Set properties on the new dm device */
	if (!dm_task_set_name(dmt, dinfo->name))
        goto out;

	/* Tokenize the command line */ 
	if(!_parse_line(dmt, dinfo->cmdline, "", 0)) {
		cout<<"in parse_line"<<endl;
		goto out;	
	}
	
	
	/* Now that we have the dm ready; Run it. */
    if (!dm_task_run(dmt)){
		cout <<"in task run"<<endl;
		goto out;
	}
	
	dm_udev_wait(0);
    dm_task_update_nodes();        

	if (!_device_info(dinfo->name)) {
		goto out;
	}

	r=1;
	out:
       dm_task_destroy(dmt);
	   return r; 
}

/* This routine modifies the properties of a DM device.
 * The new argumenets are specified through the buffer.
 * name specifies the DM deive name.
 */
int modify_dm_device(struct diskinfo *dinfo, unsigned long token, char *args)
{
	struct dm_task *dmt;
	int r=0;

	set_disk(dinfo, args);

	dinfo->token = token;

    /* DEBUG */
    cout <<"Event MODIFY"<<endl;
    dump_diskinfos();


	if(dinfo->cmdline == NULL) {
		cout << "Cmdline is empty!" << endl;
		return 0;
	}

    /* Create a new dm device */
    if(!(dmt = dm_task_create(DM_DEVICE_RELOAD)))
        return 0;

    /* Set properties on the new dm device */
    if (!dm_task_set_name(dmt, dinfo->name))
        goto out;

	/* Tokenize the cmdline */
    if(!_parse_line(dmt, dinfo->cmdline, "", 0))
        goto out;
    

    /* Now that we have the dm ready; Run it. */
    if (!dm_task_run(dmt))
        goto out;

    dm_udev_wait(0);
    dm_task_update_nodes();

    if (!_device_info(dinfo->name)) 
        goto out;
	
 
	/* Resume this dm device for changes to take effect. */
	resume_dm_device(dinfo->name);
        
	r=1;
    out:
       dm_task_destroy(dmt);
       return r;
}


/* This routine MUST be called whenever we modify properties
 * of a DM device. Once this routine returns the modified
 * properties of the DM device is made alive.
 */
int resume_dm_device(char *name)
{
	/* dmt stores all information related to the device mapper */
	struct dm_task *dmt;
	int r=0;

	/* This creates a dm device to be RESUMED */
    if (!(dmt = dm_task_create(DM_DEVICE_RESUME)))
    	return 0;

	/* This sets up the name of dm device */
    if (!dm_task_set_name(dmt, name))
    	goto out;

	#if 0
	/* This adds the dm device node */
        if (!dm_task_set_add_node(dmt, DM_ADD_NODE_ON_RESUME))
                goto out;
	#endif
    /* Now that we have the dm device. Run it to make it alive. */
    if (!dm_task_run(dmt))
		goto out;

    dm_udev_wait(0);
    dm_task_update_nodes();

	/* DM disk is created; Query it. */
	r=1;
    out:
        dm_task_destroy(dmt);
        return r;
}

/*This routine basically sets the properties specified in the buffer
 *on the device mapper disk.
 */
static int _parse_line(struct dm_task *dmt, char *buffer, const char *file,
                       int line)
{
        char ttype[LINE_SIZE], *ptr;
        unsigned long long start, size;
        int n;

        /*trim trailing space */
        for (ptr = buffer + strlen(buffer) - 1; ptr >= buffer; ptr--)
                if (!isspace((int) *ptr))
                        break;
        ptr++;
        *ptr = '\0';

        /* trim leading space */
        for (ptr = buffer; *ptr && isspace((int) *ptr); ptr++)
                ;

        if (!*ptr || *ptr == '#')
                return 1;

        if (sscanf(ptr, "%llu %llu %s %n",
                   &start, &size, ttype, &n) < 3) {
                printf("Invalid format on line %d of table %s", line, file);
                return 0;
        }

        ptr += n;

        if (!dm_task_add_target(dmt, start, size, ttype, ptr))
                return 0;

        return 1;
}

/*This routine reads the file line by line and passes the line
 *to _parse_line routine to set the properties for the device
 *mapper disk.
 */
static int _parse_file(struct dm_task *dmt, const char *file)
{
        char *buffer = NULL;
        size_t buffer_size = 0;
        FILE *fp;
        int r = 0, line = 0;

        /* one-line table on cmdline */
//        if (_table)
//                return _parse_line(dmt, _table, "", ++line);

        /* OK for empty stdin */
        if (file) {
                if (!(fp = fopen(file, "r"))) {
                        err("Couldn't open '%s' for reading", file);
                        return 0;
                }
        } else
                fp = stdin;

#ifndef HAVE_GETLINE
        buffer_size = LINE_SIZE;
        if (!(buffer = (char *)dm_malloc(buffer_size))) {
                err("Failed to malloc line buffer.");
                return 0;
        }

        while (fgets(buffer, (int) buffer_size, fp))
#else
        while (getline(&buffer, &buffer_size, fp) > 0)
#endif
                if (!_parse_line(dmt, buffer, file ? : "on stdin", ++line))
                        goto out;

        r = 1;

      out:
        memset(buffer, 0, buffer_size);
#ifndef HAVE_GETLINE
        dm_free(buffer);
#else
        free(buffer);
#endif
        if (file && fclose(fp))
                fprintf(stderr, "%s: fclose failed: %s", file, strerror(errno));

        return r;
}

/*
 * Helper routine which executes a shell command
 * and returns the output. This comes in handy for
 * knowing the status of dm devices for example.
 */
string exec_output(string cmd)
{
	// setup
	string data;
	FILE *stream;
	char buffer[MAX_BUFFER];

	// do it
	if (!(stream = popen(cmd.c_str(), "r"))) {
		cerr << "Exec failed" << endl;
		data="";
		goto out;
	}
	while ( fgets(buffer, MAX_BUFFER, stream) != NULL )
		data.append(buffer);
	
	out:
	pclose(stream);
	return data;
}

/* Prints the status of DM device */
static int _device_info(char *name)
{
	struct dm_task *dmt;
	struct dm_info info;       

	if (!(dmt = dm_task_create(DM_DEVICE_INFO)))
                return 0;

	/* Set properties on the new dm device */
    if (!dm_task_set_name(dmt, name))
    	goto out;


	if (!dm_task_run(dmt))
        goto out;

	dm_udev_wait(0);
    dm_task_update_nodes();

    if (!dm_task_get_info(dmt, &info))
        goto out;
	
	if (info.exists)
		_display_info_long(dmt, &info);

	out:
		dm_task_destroy(dmt);
        	return info.exists ? 1 : 0;
}

/* Prints a detailed status of DM device */
static void _display_info_long(struct dm_task *dmt, struct dm_info *info)
{
        const char *uuid;
        uint32_t read_ahead;

        if (!info->exists) {
                printf("Device does not exist.\n");
                return;
        }

        printf("Name:              %s\n", dm_task_get_name(dmt));

        printf("State:             %s%s\n",
               info->suspended ? "SUSPENDED" : "ACTIVE",
               info->read_only ? " (READ-ONLY)" : "");

        /* FIXME Old value is being printed when it's being changed. */
        if (dm_task_get_read_ahead(dmt, &read_ahead))
                printf("Read Ahead:        %lu\n", read_ahead);

        if (!info->live_table && !info->inactive_table)
                printf("Tables present:    None\n");
        else
                printf("Tables present:    %s%s%s\n",
                       info->live_table ? "LIVE" : "",
                       info->live_table && info->inactive_table ? " & " : "",
                       info->inactive_table ? "INACTIVE" : "");
        if (dm_task_get_read_ahead(dmt, &read_ahead))
                printf("Read Ahead:        %lu\n", read_ahead);

        if (!info->live_table && !info->inactive_table)
                printf("Tables present:    None\n");
        else
                printf("Tables present:    %s%s%s\n",
                       info->live_table ? "LIVE" : "",
                       info->live_table && info->inactive_table ? " & " : "",
                       info->inactive_table ? "INACTIVE" : "");

        if (info->open_count != -1)
                printf("Open count:        %d\n", info->open_count);

        printf("Event number:      %lu\n", info->event_nr);
        printf("Major, minor:      %d, %d\n", info->major, info->minor);

        if (info->target_count != -1)
                printf("Number of targets: %d\n", info->target_count);

        if ((uuid = dm_task_get_uuid(dmt)) && *uuid)
                printf("UUID: %s\n", uuid);

        printf("\n");
}

/*
 * Extract the properties of existing DM device.
 * Useful when altering some properties of DM device.
 */
int _get_device_params(const char *name)
{
        struct dm_info info;
        struct dm_task *dmt;
		uint64_t start, length;
		char *target_type, *params;
		string diskname;

		void *next = NULL;
		int r=0;
		unsigned long long size;
		int minor_number;
	
		device_params.clear();
		if (!(dmt = dm_task_create(DM_DEVICE_TABLE)))
		return 0;

		if (!dm_task_set_name(dmt,name))
				goto out;

		if (!dm_task_run(dmt))
				goto out;

	    dm_udev_wait(0);
    	dm_task_update_nodes();

		if (!dm_task_get_info(dmt, &info) || !info.exists)
                goto out;

		/* This is a hack for now to make things work with lvm vols
         * numdisks keeps track of the total disks created.
		 * To determine the minor number of the dm disk, I'm subtracting
		 * it with numdisks. This is a side effect of the way device
		 * mapper manages dm disks when we are mapping disks on top
		 * of lvm volume.
		 */

		minor_number = info.minor - (numdisks+1);
		diskname = itos(info.major)+":"+itos(info.minor);
		
        do {
                next = dm_get_next_target(dmt, next, &start, &length,
                                          &target_type, &params);
                size += length;
		
				device_params.push_back(itos(start));
				device_params.push_back(itos(length));
				device_params.push_back(target_type);
				device_params.push_back(params);
				device_params.push_back(diskname);	

        } while (next);

		r=1;
		out:
		dm_task_destroy(dmt);
        return r;
}

/* convert int to string */
string itos(int i)	
{
	stringstream s;
	s << i;
	return s.str();
}

/* 
 * Parse the config file which lists the initial 
 * disk configuration of disk agents.
 */
static int
parse_configfile(char *filename)
{
    FILE    *fp;
    char    buf[BUFSIZ];
	struct diskinfo *dinfo;
	int count = 0;
	char volstr[10];

    assert(filename != NULL);
    assert(strlen(filename) > 0);

    if ((fp = fopen(filename, "r")) == NULL) {
        cerr << "could not open configfile "<< filename <<endl;
        return -1;
    }

    while (fgets(buf, sizeof(buf), fp)) {
        int cc = strlen(buf);
        if (buf[cc-1] == '\n')
            buf[cc-1] = '\0';

		if(!strncmp(buf, "DISK", 4)) {
			char *value;
			int rc;
		
			dinfo = (struct diskinfo *) calloc(1, sizeof(*dinfo));
		
			if(!dinfo) {
				cerr << "parse_configfile: out of memory" <<endl;
				goto bad;
			}

            if ((rc = event_arg_get(buf, "DISKNAME", &value)) <= 0) {
                cerr << "parse_configfile: bad agent name" << endl;
                goto bad;
            }
            else if (rc >= sizeof(dinfo->name)) {
                cerr << "parse_configfile: agent name is too long" << endl; 
                goto bad;
            }
            strncpy(dinfo->name, value, rc);
            dinfo->name[rc] = '\0';

            if ((rc = event_arg_get(buf,
                        "COMMAND",
                        &dinfo->cmdline)) >= 0) {
                dinfo->cmdline[strlen(dinfo->cmdline) - 1] =
                    '\0'; // remove trailing single quote
                /* Prepend exec to replace the 'csh' */
                asprintf(&dinfo->cmdline,
                     "%s",
                     dinfo->cmdline);
            }
            dinfo->initial_cmdline = dinfo->cmdline;


            if ((rc = event_arg_get(buf,
                         "PARAMETERS",
                         &dinfo->parameters)) >= 0) {

				/* Since event_arg_get simply returns the entire string,
				   we need to prune out foreign chars */
				char *ptr = strstr(dinfo->parameters, "COMMAND=");
				if(*ptr != NULL)
						*(ptr-1) = '\0';

				dinfo->parameters[strlen(dinfo->parameters) - 1] =
						'\0';

				asprintf(&dinfo->parameters,
                     "%s",
                     dinfo->parameters);
            }
            dinfo->initial_parameters = dinfo->parameters;

            if ((rc = event_arg_dup(buf, "DISKTYPE", &dinfo->type)) == 0) {
            	free(dinfo->type);
				dinfo->type = NULL;			    
            }
			dinfo->initial_type = dinfo->type;			

			if (((rc = event_arg_get(buf, "DISKSIZE", &value)) > 0)) {
				if (sscanf(value, "%d", &dinfo->size) != 1) {
					printf("parse_configfile: "
							"malformed command: %s\n",
							buf);
					 goto bad;
				}
			}
			else
				dinfo->size = 0;

            if ((rc = event_arg_dup(buf, "MOUNTPOINT", &dinfo->mountpoint)) == 0) {
                free(dinfo->mountpoint);
                dinfo->mountpoint = NULL;
            }
			dinfo->initial_mountpoint = dinfo->mountpoint;
		
			/* Convert the count from int to string.
			 * This is to name the lvm volumes.
			 */
			stringstream countstr;
			countstr << count;
			string tmp = "vol"+countstr.str();
			asprintf(&dinfo->volname,"%s", const_cast<char *>(tmp.c_str()));
			numdisks++;
			count++;

			dinfo->next = diskinfos;
			diskinfos   = dinfo;
			continue;
		}
	}
    cout <<"After parse_config "<<endl;
    dump_diskinfos();

    fclose(fp);
    return 0;
bad:
	fclose(fp);
	return -1;		
}		
		
/*
 * Helper routine to populate the disk agent list
 * in memory. 
 */
static void
set_disk(struct diskinfo *dinfo, char *args)
{
    assert(dinfo != NULL);
    assert(args != NULL);

	printf("Args in set_disk : %s\n",args);
    /*
     * The args string holds the command line to execute. We allow
     * this to be reset in dynamic events, but is optional; the cuurent
     * command will be used by default, which initially comes from tmcd.
     */
    if (args && (strlen(args) > 0)) {
        char *value;
        int rc;

        /*
         * COMMAND is special. For backward compat it can contain
         * whitespace but need not be quoted.  In fact, if the string
         * is quoted, we just pass the quotes through to the program.
         */
        if ((rc = event_arg_get(args, "COMMAND", &value)) > 0) {
			if (dinfo->cmdline != NULL) {
                if (dinfo->cmdline != dinfo->initial_cmdline) {
                    free(dinfo->cmdline);
                    dinfo->cmdline = NULL;
                }
            }
            /*
             * XXX event_arg_get will return a pointer beyond
             * any initial quote character.  We need to back the
             * pointer up if that is the case.
             */
            if (value[-1] == '\'' || value[-1] == '{')
                value--;
            /* Since event_arg_get simply returns the entire string,
               we need to prune out foreign chars */
            char *ptr;
            if(((ptr = strstr(value, "PARAMETERS=")) || (ptr = strstr(value, "DISKTYPE=")) || (ptr = strstr(value, "MOUNTPOINT="))) != NULL)
                *ptr = '\0';

            printf("COMMAND: %s\n",value);
            asprintf(&dinfo->cmdline, "%s", value);
            value = NULL;
        }

        if ((rc = event_arg_dup(args, "DISKTYPE", &value)) >= 0) {
			printf("DISKTYPE: %s\n",value);
            if (dinfo->type != NULL) {
                if (dinfo->type != dinfo->initial_type)
                    free(dinfo->type);
            }
			if(rc == 0) {
				dinfo->type = NULL;
				free(value);
			}
			else if (rc > 0) {
				dinfo->type = value;
			}
			else {
				assert(0);
			}
			value = NULL;
		}
        if ((rc = event_arg_dup(args, "MOUNTPOINT", &value)) >= 0) {
			printf("MOUNTPOINT: %s\n",value);
            if (dinfo->mountpoint != NULL) {
                if (dinfo->mountpoint != dinfo->initial_mountpoint)
                    free(dinfo->mountpoint);
            }
            if(rc == 0) {
                dinfo->mountpoint = NULL;
                free(value);
            }
            else if (rc > 0) {
                dinfo->mountpoint = value;
            }
            else {
                assert(0);
            }
            value = NULL;
        }
	    if ((rc = event_arg_get(args, "PARAMETERS", &value)) >= 0) {
			printf("PARAMETERS: %s\n",value);
			if (dinfo->parameters != NULL) {
                if (dinfo->parameters != dinfo->initial_parameters)
                    free(dinfo->parameters);
            }
			/* Since event_arg_get simply returns the entire string,
			   we need to prune out foreign chars */
			char *ptr;
			if(((ptr = strstr(value, "COMMAND=")) || (ptr = strstr(value, "DISKTYPE=")) || (ptr = strstr(value, "MOUNTPOINT="))) != NULL)
				*ptr = '\0';

			printf("PARAMETERS after pruning: %s\n",value);
			dinfo->parameters = value;
		   /*
			* XXX event_arg_get will return a pointer beyond
			* any initial quote character.  We need to back the
			* pointer up if that is the case.
			*/
			if (value[-1] == '\'' || value[-1] == '{')
				value--;
			asprintf(&dinfo->parameters, "%s", value);
			value = NULL;

		}
	}
	cout << "after set_disk "<<endl;
	dump_diskinfos();
}

/**
 * Find the file extension of the given path while ignoring any numerical
 * extensions.  For example, calling this function with "foo.zip.1" and
 * "foo.zip" will return a pointer to "zip.1" and "zip" respectively.
 *
 * @param path The path to search for a file extension within.
 * @return NULL if no extension could be found, otherwise a pointer to the
 * first character of the extension.
 */
static char *fileext(char *path)
{
    int has_token = 0, lpc, len;
    char *retval = NULL;

    assert(path != NULL);

    len = strlen(path);
    for (lpc = len - 1; (lpc > 0) && (retval == NULL); lpc--) {
        if (path[lpc] == '.') {
            int dummy;

            if (has_token)
                retval = &path[lpc + 1];
            else if (sscanf(&path[lpc + 1], "%d", &dummy) == 1)
                has_token = 1;
            else
                retval = &path[lpc + 1];
        }
    }

    return retval;
}

static void
start_callback(event_handle_t handle,
           event_notification_t notification,
           void *data)
{
    char        event[TBDB_FLEN_EVEVENTTYPE];

    assert(handle != NULL);
    assert(notification != NULL);
    assert(data == NULL);

    if (! event_notification_get_eventtype(handle, notification,
                           event, sizeof(event))) {
        cerr << "Could not get event from notification!\n" << endl;
        return;
    }
    if (strcmp(event, TBDB_EVENTTYPE_START) == 0) {
        struct diskinfo *dinfo;
        DIR *dir;

        for (dinfo = diskinfos; dinfo != NULL; dinfo = dinfo->next) {

            if (dinfo->cmdline != dinfo->initial_cmdline) {
                free(dinfo->cmdline);
                dinfo->cmdline = dinfo->initial_cmdline;
            }
            if (dinfo->type != dinfo->initial_type) {
                free(dinfo->type);
                dinfo->type = dinfo->initial_type;
            }
            if (dinfo->mountpoint != dinfo->initial_mountpoint) {
                free(dinfo->mountpoint);
                dinfo->mountpoint = dinfo->initial_mountpoint;
            }
            if (dinfo->parameters != dinfo->initial_parameters) {
                free(dinfo->parameters);
                dinfo->parameters = dinfo->initial_parameters;
            }

        }
        if ((dir = opendir(LOGDIR)) == NULL) {
            errorc("Cannot clean log directory: %s", dir);
        }
        else {
            struct dirent *de;

            while ((de = readdir(dir)) != NULL) {
                char *ext = NULL;
                char path[1024];
                int len = strlen(de->d_name);
                int got_path = 0, file_or_link = 0;
                if ((len > 0) && (len < sizeof(path)))
                    got_path = sscanf(de->d_name,
                              "%1024[^.].",
                              path) == 1;
#ifndef __CYGWIN__
                file_or_link = (de->d_type == DT_REG) ||
                  (de->d_type == DT_LNK);
#else  /* __CYGWIN__ */
                /* Cygwin struct dirent doesn't have d_type. */
                struct stat st;     /* Use stat instead. */
                file_or_link = got_path &&
                  (stat(path, &st) == 0) &&
                  ((st.st_mode == S_IFREG) ||
                    (st.st_mode == S_IFLNK));
#endif /* __CYGWIN__ */
                if ((file_or_link) &&
                    (find_agent(path) != NULL) &&
                    ((ext = fileext(de->d_name)) != NULL) &&
                    ((strncmp(ext, "out", 3) == 0) ||
                     (strncmp(ext, "err", 3) == 0) ||
                     (strncmp(ext, "status", 6) == 0))) {
                    snprintf(path,
                         sizeof(path),
                         "%s/%s",
                         LOGDIR,
                         de->d_name);
                    unlink(path);
                }
            }
            closedir(dir);
            dir = NULL;
        }
    }
}
