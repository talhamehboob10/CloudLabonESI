/*
 * Copyright (c) 2010 University of Utah and the Flux Group.
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

/* This program implements the Disk agent for Emulab Event System.
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
#include <cerrno>
#include <cstdio>
#include <algorithm>
#include <ctype.h>
extern "C" {
	#include <libdevmapper.h>
}

#include <sys/time.h>

using namespace std;

// For getopt
#include <unistd.h>

#include "event.h"
#include "tbdefs.h"
#define LINE_SIZE 4096
#define MAX_BUFFER 4096
#define err(msg, x...) fprintf(stderr, msg "\n", ##x)

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
void start(string);

//DM Device routines
map<string, string> dm_args;
int create_dm_device(char *);
int run_dm_device(char *);
int modify_dm_device(char *);
int resume_dm_device(char *);
static int _device_info(char *);
static int _parse_line(struct dm_task *, char *, const char *,int);
static int _parse_file(struct dm_task *, const char *);
static int _parse_args(char *);
static void _display_info_long(struct dm_task *,  struct dm_info *);
int _get_device_params(const char *);
string exec_output(string);
string itos(int );

//void mkextrafs(string , string);

int main(int argc, char * argv[])
{
  cerr << "Beginning program" << endl;
  readArgs(argc, argv);
  return 0;
}

void readArgs(int argc, char * argv[])
{
  cerr << "Processing arguments" << endl;
  string server;
  string port;
  string keyFile;
  string subscription;
  string group;

  // Prevent getopt from printing an error message.
  opterr = 0;

  /* get params from the optstring */
  char const * argstring = "s:p:dE:k:u:g:";
  int option = getopt(argc, argv, argstring);
  while (option != -1)
  {
    switch (option)
    {
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
    case 'E':
      g::experimentName = optarg;
      break;
    case 'k':
      keyFile = optarg;
      break;
    case 'u':
      subscription = optarg;
      break;
    case 'g':
      group = optarg;
      break;
    case '?':
    default:
      usage(argv[0]);
      break;
    }
    option = getopt(argc, argv, argstring);
  }

  /*Check if all params are specified, otherwise, print usage and exit*/
  if(server == "" || g::experimentName == "")
      usage(argv[0]);

  initEvents(server, port, keyFile, subscription, group);
}

void usage(char * name)
{
  cerr << "Usage: " << name << " -E proj/exp -s server [-d] [-p port] "
       << "[-i pidFile] [-k keyFile] [-u subscription] [-g group]" << endl;
  exit(-1);
}

void initEvents(string const & server, string const & port,
                string const & keyFile, string const & subscription,
                string const & group)
{
  cerr << "Initializing event system" << endl;
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

  event_main(handle);
}

void subscribe(event_handle_t handle, address_tuple_t eventTuple,
               string const & subscription, string const & group)
{
  string name = subscription;
  if (group != "")
  {
    name += "," + group;
  }
  cerr << "Link subscription names: " << name << endl;
  eventTuple->objname = const_cast<char *>(name.c_str());
//  eventTuple->objtype = TBDB_OBJECTTYPE_DISK;
  eventTuple->objtype = ADDRESSTUPLE_ANY;
//  eventTuple->eventtype = TBDB_EVENTTYPE_MODIFY;
  eventTuple->eventtype = ADDRESSTUPLE_ANY;
  eventTuple->expt = const_cast<char *>(g::experimentName.c_str());
  eventTuple->host = ADDRESSTUPLE_ANY;
  eventTuple->site = ADDRESSTUPLE_ANY;
  eventTuple->group = ADDRESSTUPLE_ANY;
  eventTuple->scheduler = 1;
  if (event_subscribe(handle, callback, eventTuple, NULL) == NULL)
  {
    cerr << "Could not subscribe to " << eventTuple->eventtype << " event" << endl;
    exit(1);
  }
}

void callback(event_handle_t handle,
              event_notification_t notification,
              void * data)
{
  char name[EVENT_BUFFER_SIZE];
  char type[EVENT_BUFFER_SIZE];
  char args[EVENT_BUFFER_SIZE];
  
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
  
  if (event_notification_get_string(handle, notification,const_cast<char *>("ARGS"), args, EVENT_BUFFER_SIZE) == 0)
  {
	cerr << timestamp << ": ERROR: Could not get event arguments" << endl;
        return;
  }


  /* Call the event handler routine based on the event */
  switch(eventtype[event])
  {
	case 0:
		/* Event is to create a dm disk */	
		if(!create_dm_device(args))
			cout << "DM failed" << endl;
		event="";
		break;
  	case 1:
		/* Event is to modify the dm disk */
		if(!modify_dm_device(args))
			cout << "DM failed" << endl;
		event="";
	 	break;	
	case 2:
		break;
	case 3:
		if(!run_dm_device(args))
			 cout << "DM failed" << endl;
		event="";
		break;
	default:
		cout << "Don't recognize the event type" << endl;
  }
 
}

int run_dm_device(char *args)
{
	struct dm_task *dmt;

	if (!(_parse_args(args))) {
		cout << "Arguments are invalid" <<endl;
                return 0;
        }

	if (_device_info(const_cast<char *>(dm_args["NAME"].c_str()))) {
		/* DM device exists so we'll reload it with params supplied */
		int r=0;
		uint64_t start=0, length=0;
	    char *target_type=NULL, *params=NULL;
		
		string params_str="", diskname="";
		stringstream split;

	 	if (!(dmt = dm_task_create(DM_DEVICE_RELOAD))) {
            cout << "in dm task create"<<endl;
            return 0;
        }		
		if ( !dm_task_set_name(dmt, const_cast<char *>(dm_args["NAME"].c_str()))){
			dm_task_destroy(dmt);
            return 0;
		}
	
		if (!(_get_device_params(dm_args["NAME"].c_str()))) {
			dm_task_destroy(dmt);
            return 0;
		}
		cout << device_params[0] << device_params[1] << device_params[2] << device_params[3] << endl;
	
		start 		    = strtoul (device_params[0].c_str(),NULL,0);
		length 		    = strtoul (device_params[1].c_str(),NULL,0);
		target_type 	= const_cast<char *>(dm_args["TYPE"].c_str());

		split		   << device_params[3];

		getline(split,diskname,' ');
 		params_str 	= diskname + " " + "0 "+ dm_args["PARAMS"];
		cout << "diskname after "<<params_str<<endl;
		params 		= const_cast<char *>(params_str.c_str());

		cout <<start<<" "<<length<<" "<<target_type<<" "<<params<<endl;;	
		
		if (!dm_task_add_target(dmt, start, length, target_type, params)) {
 			dm_task_destroy(dmt);
                        return 0;
		}
		/* Now that we have the dm ready; Run it. */
		if (!dm_task_run(dmt)){
			 dm_task_destroy(dmt);
                        return 0;
		}

		/* Resume this dm device for changes to take effect. */
		resume_dm_device(const_cast<char *>(dm_args["NAME"].c_str()));
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
		string dm_disk_name = "/dev/mapper/"+dm_args["NAME"];
		if (dm_args["NAME"] != "" and !dm_task_set_name(dmt, const_cast<char *>(dm_args["NAME"].c_str()))) {
			cout << "in task set name"<<endl;
			dm_task_destroy(dmt);
			return 0;
		}
		/* Making use of mkextrafs script which will create a new partition.
		 * Using this partition we'll create the dm disk on top of it.
		 */
		cout << "Creating the disk partition ..." << endl;
		cmd = "sudo ./mkextrafs -f "+dm_args["MOUNTPOINT"];  //This returns the newly partitioned disk name
		string disk = exec_output(cmd);           //exec_output will return the output from shell
		if (disk == "") {
			 dm_task_destroy(dmt);
                        return 0;
		}	
		cout << "Disk partition: " << disk <<endl;
		/* So we have the new partition. Find out the
		 * size of partition to create the new dm disk.
		 */
		cmd = "sudo blockdev --getsz "+disk;
		string str_size = exec_output(cmd);
		if (str_size == "") {
			dm_task_destroy(dmt);
                        return 0;
		}
		
		cout << "Mapping the virtual disk " <<dm_args["NAME"] << "on "<<disk<< endl; 
		/* Hardcoding all the values.
		 * Users not to worry about the geometry of the disk such as the start
		 * sector, end sector, size etc
		 */
		start = 0;
		size = strtoul(const_cast<char *>(str_size.c_str()), NULL, 0);
		ttype = const_cast<char *>(dm_args["TYPE"].c_str());
		if (dm_args["PARAMS"] != "") {
			str = dm_args["PARAMS"].c_str();
			str.erase(std::remove(str.begin(), str.end(), '\n'), str.end());
			string params = disk + " 0 " + str;
			params.erase(std::remove(params.begin(), params.end(), '\n'), params.end());
			ptr = const_cast<char *>(params.c_str());
			cout <<"PARAMS: "<<params<<endl;
		}
	
		else {
			string params = disk+" 0";
			params.erase(std::remove(params.begin(), params.end(), '\n'), params.end());
			ptr = const_cast<char *>(params.c_str());
			cout <<"PARAMS: "<<params<<endl;
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

		sleep(1);

		str = dm_args["MOUNTPOINT"];
		cmd = "sudo mount "+dm_disk_name+" "+str;
		system(const_cast<char *>(cmd.c_str()));
		cout << dm_args["NAME"] << " is mounted on " <<str <<endl;

		dm_task_destroy(dmt);
		return 1;
	}

}



/* This routine will create a device mapper(DM) device.
* It takes the arguments through the buffer and
* name specifies the name of the DM device.
*/
int create_dm_device(char *args)
{
	struct dm_task *dmt;
	char *file = NULL;
	char *_table = NULL;
	string str="";
	int r=0;

	string buf;
	vector<string> tokens;
	stringstream stream(args);

	while(stream >> buf)
		tokens.push_back(buf);

	if(tokens.size() <= 1) {
		cout << "ERROR: No arguments" << endl;
		return 0;
	}

	/* Create a new dm device */
	if(!(dmt = dm_task_create(DM_DEVICE_CREATE))){
		cout << "in dm task create"<<endl;
		return 0;
	}

	char *disk_name = const_cast<char *>(tokens[0].c_str());
        /* Set properties on the new dm device */
        if (!dm_task_set_name(dmt, disk_name))
                goto out;

	/* If only the name and file are given as input */
	if(tokens.size() == 2) {
		file = const_cast<char *>(tokens[1].c_str());
		if(!_parse_file(dmt,file)) {
			cout << "in parse file"<<endl;
			goto out;
		}
	}
	
	if(tokens.size() > 2) {
		int line=0;
		stringstream ss;
		for(size_t i=1; i<tokens.size(); i++) {
			ss << tokens[i] <<" ";
		}
		string s = ss.str();
		_table = const_cast<char *>(s.c_str());
		if(!_parse_line(dmt, _table, "", ++line)) {
			cout<<"in parse_line"<<endl;
			goto out;	
		}
	}
	
	/* add the dm device */

//	if (!dm_task_add_target(dmt, start, size, ttype, ptr))
//        	return 0;
		
	/* Now that we have the dm ready; Run it. */
        if (!dm_task_run(dmt)){
		cout <<"in task run"<<endl;
		goto out;
	}
        
	if (!_device_info(disk_name)) {
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
int modify_dm_device(char *args)
{
        struct dm_task *dmt;
	int r=0;
        char *file = NULL;
        char *_table = NULL;

        string buf;
        vector<string> tokens;
        stringstream stream(args);

        while(stream >> buf)
                tokens.push_back(buf);

        if(tokens.size() <= 1) {
                cout << "ERROR: No arguments" << endl;
                return 0;
        }

        /* Create a new dm device */
        if(!(dmt = dm_task_create(DM_DEVICE_RELOAD)))
                return 0;

	char *disk_name = const_cast<char *>(tokens[0].c_str());
        /* Set properties on the new dm device */
        if (!dm_task_set_name(dmt, disk_name))
                goto out;

        if(tokens.size() == 2) {
                file = const_cast<char *>(tokens[1].c_str());
                if(!_parse_file(dmt,file))
                        goto out;
        }

        if(tokens.size() > 2) {
                int line=0;
                stringstream ss;
                for(size_t i=1; i<tokens.size(); i++) {
                        ss << tokens[i] <<" ";
                }
                string s = ss.str();
                _table = const_cast<char *>(s.c_str());
                if(!_parse_line(dmt, _table, "", ++line))
                        goto out;
        }

	/* Add the dm device */
//	if (!dm_task_add_target(dmt, start, size, ttype, ptr))
//                return 0;

        /* Now that we have the dm ready; Run it. */
        if (!dm_task_run(dmt))
                goto out;

        /* DM disk is created; Query it. */
        //printf("DM Disk: %s\n", dm_task_get_name(dmt));

        if (!_device_info(disk_name)) {
                goto out;
	}
 
	/* Resume this dm device for changes to take effect. */
	resume_dm_device(const_cast<char *>(tokens[0].c_str()));
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

	/* This adds the dm device node */
        if (!dm_task_set_add_node(dmt, DM_ADD_NODE_ON_RESUME))
                goto out;

         /* Now that we have the dm device. Run it to make it alive. */
        if (!dm_task_run(dmt))
                goto out;

        /* DM disk is created; Query it. */
        //printf("Name: %s\n", dm_task_get_name(dmt));
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
                err("Invalid format on line %d of table %s", line, file);
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

int _parse_args(char *args)
{
	char *value;
 	string str; 
	cout <<"Args: "<<args<<endl;
	dm_args.clear();
	if(args && (strlen(args) > 0)) {
        	char *value;
	        int rc;
        	if ((rc = event_arg_dup(args, "NAME", &value)) >= 0) {
                	cout << "Arg:name"<<" Value:" <<value <<endl;
			str=value;
			dm_args["NAME"]=str;
                	value = NULL;
        	}
        
        	if ((rc = event_arg_dup(args, "MOUNTPOINT", &value)) >= 0) {
                	cout << "Arg:mountpoint"<<" Value:" <<value<<endl;
			str=value;
			dm_args["MOUNTPOINT"]=value;
	                value = NULL;
        	}
	        if ((rc = event_arg_dup(args, "TYPE", &value)) >= 0) {
        	        cout << "Arg:type"<<" Value:" <<value<<endl;
			str=value;
			dm_args["TYPE"]=value;			
	                value = NULL;
        	}
        	if ((rc = event_arg_dup(args, "PARAMS", &value)) >= 0) {
			str=value;
			cout << "Arg:params"<<" Value:" <<value<<endl;
			dm_args["PARAMS"]=value;
                	value = NULL;
        	}

  	}
	
	/* If the key-value pairs are not found then indicate it by a failure. */
	if (dm_args["NAME"] == "" || dm_args["MOUNTPOINT"] == "" || dm_args["TYPE"] == "")
		return 0;
	
	return 1;
}	

string exec_output(string cmd)
{
	// setup
	string data;
	FILE *stream;
	char buffer[MAX_BUFFER];

	// do it
	if (!(stream = popen(cmd.c_str(), "r"))) {
		cout << "Exec failed" << endl;
		data="";
		goto out;
	}
	while ( fgets(buffer, MAX_BUFFER, stream) != NULL )
		data.append(buffer);
	
	out:
	pclose(stream);
	return data;
}

static int _device_info(char *name)
{
	struct dm_task *dmt;
	int r=0;
	struct dm_info info;       

	if (!(dmt = dm_task_create(DM_DEVICE_INFO)))
                return 0;

        /* Set properties on the new dm device */
        if (!dm_task_set_name(dmt, name))
                goto out;


        if (!dm_task_run(dmt))
                goto out;


        if (!dm_task_get_info(dmt, &info))
                goto out;
	
	if (info.exists)
		_display_info_long(dmt, &info);

	out:
		dm_task_destroy(dmt);
        	return info.exists ? 1 : 0;
}

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

int _get_device_params(const char *name)
{
        struct dm_info info;
        struct dm_task *dmt;
	uint64_t start, length;
	char *target_type, *params;

        void *next = NULL;
	int r=0;
	unsigned long long size;
	
	device_params.clear();
        if (!(dmt = dm_task_create(DM_DEVICE_TABLE)))
                return 0;

        if (!dm_task_set_name(dmt,name))
                goto out;

        if (!dm_task_run(dmt))
                goto out;

        if (!dm_task_get_info(dmt, &info) || !info.exists)
                goto out;

        do {
                next = dm_get_next_target(dmt, next, &start, &length,
                                          &target_type, &params);
                size += length;
		
		device_params.push_back(itos(start));
		device_params.push_back(itos(length));
		device_params.push_back(target_type);
		device_params.push_back(params);
	

        } while (next);

      r=1;
      out:
        dm_task_destroy(dmt);
        return r;
}

string itos(int i)	// convert int to string
{
	stringstream s;
	s << i;
	return s.str();
}
