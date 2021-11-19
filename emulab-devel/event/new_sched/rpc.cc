/*
 * Copyright (c) 2004-2017 University of Utah and the Flux Group.
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

#include "config.h"

#include <unistd.h>
#include <sys/param.h>

#include <math.h>
#include <limits.h>
#include <sys/types.h>
#include <assert.h>
#include <pwd.h>

#include <string>
#include <cstring>
#include <sstream>
#include <set>
using namespace std;

#include "log.h"
#include "rpc.h"

/**
 * We cache the connection to the server until all of the RPCs have completed
 * so we do not have to reconnect.
 */
struct r_rpc_data rpc_data = {
	NULL,
	BOSSNODE,
	DEFAULT_RPC_PORT,
	-1,
	NULL,
	PTHREAD_MUTEX_INITIALIZER
};

const char *topography_name;

int RPC_init(const char *certpath, const char *host, unsigned short port)
{
	struct passwd *pwd;
	int retval;

	assert(host != NULL);
	assert(strlen(host) > 0);
	
	if ((pwd = getpwuid(getuid())) == NULL) {
		error("uid %d does not exist", getuid());
		retval = -1;
	}
	else if ((retval = pthread_mutex_init(&rpc_data.mutex, NULL)) != 0) {
		error("could not initialize mutex");
		retval = -1;
	}
	else {
		if (certpath == NULL) {
			char buf[BUFSIZ];
			
			snprintf(buf,
				 sizeof(buf),
				 "%s/.ssl/emulab.pem",
				 pwd->pw_dir);
			rpc_data.certpath = strdup(buf);
		}
		if (host != NULL)
			rpc_data.host = host;
		if (port > 0)
			rpc_data.port = port;
		rpc_data.refcount = 0;

		retval = 0;
	}
	
	return retval;
}

int RPC_grab(void)
{
	int retval = 0;

	if (pthread_mutex_lock(&rpc_data.mutex) != 0)
		assert(0);
	
	assert(rpc_data.refcount >= 0);
	
	rpc_data.refcount += 1;
	
	if (pthread_mutex_unlock(&rpc_data.mutex) != 0)
		assert(0);
	
	return retval;
}

void RPC_drop(void)
{
	if (pthread_mutex_lock(&rpc_data.mutex) != 0)
		assert(0);
	
	assert(rpc_data.refcount > 0);

	rpc_data.refcount -= 1;
	if (rpc_data.refcount == 0) {
		if (rpc_data.transport != NULL) {
			delete rpc_data.transport;
			rpc_data.transport = NULL;
		}
	}
	
	if (pthread_mutex_unlock(&rpc_data.mutex) != 0)
		assert(0);
}

static int
RPC_connect(xmlrpc_c::clientXmlTransport **transport)
{
	int retval = 0;
	
	assert(transport != NULL);

	if (pthread_mutex_lock(&rpc_data.mutex) != 0)
		assert(0);
	
	if (rpc_data.transport != NULL) {
		*transport = rpc_data.transport;
		rpc_data.transport = NULL;
	}
	else {
		*transport = new xmlrpc_c::clientXmlTransport_curl(
			xmlrpc_c::clientXmlTransport_curl::constrOpt()
			.sslcertpasswd("")
			.ssl_cert(rpc_data.certpath)
			.sslkey(rpc_data.certpath)
			.no_ssl_verifyhost(true)
			.no_ssl_verifypeer(true)
//			.timeout(30 * 60 * 1000)
			);
	}
	
	if (pthread_mutex_unlock(&rpc_data.mutex) != 0)
		assert(0);

	return retval;
}

static void
RPC_disconnect(xmlrpc_c::clientXmlTransport **transport)
{
	assert(transport != NULL);
	
	if (pthread_mutex_lock(&rpc_data.mutex) != 0)
		assert(0);

	if (rpc_data.transport == NULL) {
		rpc_data.transport = *transport;
	}
	else {
		delete *transport;
	}
	
	if (pthread_mutex_unlock(&rpc_data.mutex) != 0)
		assert(0);
}

int
RPC_invoke(char const *method,
	   emulab::EmulabResponse *er_out,
	   emulab::spa_attr_t tag,
	   ...)
{
	int retval = 0;
	va_list args;
	xmlrpc_c::clientXmlTransport *transport = NULL;

	cout << "Beginning call to " << method << std::endl;
	RPC_connect(&transport);

	va_start(args, tag);
	try
	{
		ostringstream buffer;
		string url;
		
		buffer << "https://" << rpc_data.host << ':'
		       << rpc_data.port << XMLRPC_ROOT;
		url = buffer.str();
		
		emulab::ServerProxy proxy(transport, false, url.c_str());
		
		*er_out = proxy.invoke(method, tag, args);
		
		if (!er_out->isSuccess()){
			cerr << "RPC_invoke failed: "
			     << method
			     << " "
			     << (string)(er_out->getOutput())
			     << std::endl;
			retval = -1;
		}
	}
	catch(girerr::error &ex)
	{
		cout << "Error occured: " <<
			ex.what() << std::endl;
		retval = -1;
	}
	catch(...)
	{
		cout << "unknown Error occured.\n";
		retval = -1;
	}
	va_end(args);
	
	RPC_disconnect(&transport);

	cout << "Finished with call to " << method << std::endl;
	return retval;
}

int
RPC_invoke(char *pid, char *eid, char const *method, emulab::EmulabResponse *er)
{
	int retval = 0;
	xmlrpc_c::clientXmlTransport *transport;

	assert(pid != NULL);
	assert(eid != NULL);
	assert(method != NULL);
	assert(er != NULL);

	transport = NULL;
	
	cout << "Beginning call to " << method << std::endl;
	RPC_connect(&transport);
	
	try
	{
		ostringstream buffer;
		string url;
		
		buffer << "https://" << rpc_data.host << ':'
		       << rpc_data.port << XMLRPC_ROOT;
		url = buffer.str();
		
		emulab::ServerProxy proxy(transport, false, url.c_str());
		
		*er = proxy.invoke(method,
				   emulab::SPA_String, "proj", pid,
				   emulab::SPA_String, "exp", eid,
				   emulab::SPA_TAG_DONE);
		
		if (! er->isSuccess()){
			cerr << "RPC_invoke failed: "
			     << method
			     << " "
			     << (string)er->getOutput()
			     << std::endl;
			retval = -1;
		}
	}
	catch(girerr::error &ex)
	{
		cout << "Error occured: " <<
			ex.what() << std::endl;
		retval = -1;
	}
	catch(...)
	{
		cout << "unknown Error occured.\n";
		retval = -1;
	}

	RPC_disconnect(&transport);
	cout << "Finished with call to " << method << std::endl;

	return retval;
}

int
RPC_metadata(char *pid, char *eid)
{
	emulab::EmulabResponse er;
	int retval;

	assert(pid != NULL);
	assert(eid != NULL);

	if ((retval = RPC_invoke(pid, eid, "experiment.metadata", &er)) == 0) {
		string path;
		vector<xmlrpc_c::value> userenv;
		map <string, xmlrpc_c::value> md;

		md = (xmlrpc_c::value_struct)er.getValue();
		path = (xmlrpc_c::value_string)md["path"];
		SetExpPath(((string)path).c_str());

		userenv = ((xmlrpc_c::value_array)md["user_environment"]).vectorValueValue();
		
		if (userenv.size() > 0) {
			int lpc;

			for (lpc = 0; lpc < userenv.size(); lpc++) {
				string name, value;
				map<string, xmlrpc_c::value> ue;
				
				ue = (xmlrpc_c::value_struct)userenv[lpc];
				name = (xmlrpc_c::value_string)ue["name"];
				value = (xmlrpc_c::value_string)ue["value"];

				if ((retval = AddUserEnv(name.c_str(),
				                         value.c_str())) != 0)
					return retval;
			}
		}
	}

	return retval;
}

expt_state_t
RPC_expt_state(char *pid, char *eid)
{
	expt_state_t retval = ES_UNKNOWN;
	emulab::EmulabResponse er;

	assert(pid != NULL);
	assert(strlen(pid) > 0);
	assert(eid != NULL);
	assert(strlen(eid) > 0);

	if (RPC_invoke(pid, eid, "experiment.state", &er) == 0) {
		const char *state;
		string tmp;

		tmp = (string)(xmlrpc_c::value_string)er.getValue();
		state = tmp.c_str();
		if (strcmp(state, "activating") == 0)
			retval = ES_ACTIVATING;
		else if (strcmp(state, "active") == 0)
			retval = ES_ACTIVE;
		else if (strcmp(state, "modify_reswap") == 0)
			retval = ES_MODIFY_RESWAP;
	}

	return retval;
}

int RPC_notifystart(char *pid, char *eid, char *timeline, int set_or_clear)
{
	emulab::EmulabResponse er;
	double time_start = 0.0;
	
	assert(pid != NULL);
	assert(strlen(pid) > 0);
	assert(eid != NULL);
	assert(strlen(eid) > 0);
	assert(timeline != NULL);

	if (set_or_clear) {
		struct timeval tv;
		
		gettimeofday(&tv, NULL);
		time_start = tv.tv_sec + ((double)tv.tv_usec) / 1000000;
	}
	
	return RPC_invoke("experiment.event_time_start",
			  &er,
			  emulab::SPA_String, "pid", pid,
			  emulab::SPA_String, "eid", eid,
			  emulab::SPA_String, "timeline", timeline,
			  emulab::SPA_Double, "time", time_start,
			  emulab::SPA_TAG_DONE);
}

int
RPC_waitforactive(char *pid, char *eid)
{
	emulab::EmulabResponse er;

	assert(pid != NULL);
	assert(strlen(pid) > 0);
	assert(eid != NULL);
	assert(strlen(eid) > 0);

	return RPC_invoke(pid, eid, "experiment.waitforactive", &er);
}

int
RPC_agentlist(event_handle_t handle, char *pid, char *eid)
{
	emulab::EmulabResponse er;
	int i, foo = RPC_invoke(pid, eid, "experiment.event_agentlist", &er);
	
	if (foo)
		return foo;
	
	vector<xmlrpc_c::value> agents =
		((xmlrpc_c::value_array)er.getValue()).vectorValueValue();
	
	for (i = 0; i < agents.size(); i++) {
		string vname, vnode, nodeid, ipaddr, type;
		vector<xmlrpc_c::value>agent =
			((xmlrpc_c::value_array)agents[i]).vectorValueValue();
		
		vname = (xmlrpc_c::value_string)agent[0];
		vnode = (xmlrpc_c::value_string)agent[1];
		nodeid = (xmlrpc_c::value_string)agent[2];
		ipaddr = (xmlrpc_c::value_string)agent[3];
		type = (xmlrpc_c::value_string)agent[4];
		info("D: adding agent %s\n", (char *)vname.c_str());
		if (AddAgent(handle, vname.c_str(), vnode.c_str(),
		             nodeid.c_str(), ipaddr.c_str(), type.c_str()) < 0) {
			return -1;
		}
	}
  
	return 0;
}

int
RPC_grouplist(event_handle_t handle, char *pid, char *eid)
{
	emulab::EmulabResponse er;
	int i, foo = RPC_invoke(pid, eid, "experiment.event_grouplist", &er);
	
	if (foo)
		return foo;
	
	vector<xmlrpc_c::value> groups =
		((xmlrpc_c::value_array)er.getValue()).vectorValueValue();
	
	for (i = 0; i < groups.size(); i++) {
		string groupname, agentname;
		vector<xmlrpc_c::value> group =
			((xmlrpc_c::value_array)groups[i]).vectorValueValue();
		
		groupname = (xmlrpc_c::value_string)group[0];
		info("D: \tIn GroupList() parsed name %s\n",
		     (char *)groupname.c_str());
		agentname = (xmlrpc_c::value_string)group[1];
		info("D: \tIn GroupList() parsed agent %s\n",
		     (char *)agentname.c_str());
		
		if (AddGroup(handle, groupname.c_str(),
		             agentname.c_str()) != 0) {
			return -1;
		}
	}
	return 0;
}

int
RPC_eventlist(char *pid, char *eid,
	      event_handle_t handle, address_tuple_t tuple)
{ /* This function requests all the static events from boss using an RPC call, packing them into its
   * own data structures. */
	emulab::EmulabResponse er;
	int i, foo = RPC_invoke(pid, eid, "experiment.event_eventlist", &er);

// XXX
//	info("rpc.cc:RPC_eventlist(): Just called RPC_invoke()\n");
// XXX	
	if (foo)
		return foo;

// XXX
//	info("rpc.cc:RPC_eventlist(): calling getValue()\n");
// XXX
	vector<xmlrpc_c::value> events =
		((xmlrpc_c::value_array)er.getValue()).vectorValueValue();
	
// XXX
//	info("rpc.cc:RPC_eventlist(): Interating over invoke results\n");
// XXX	
	for (i = 0; i < events.size(); i++) {
		string exidx, extime, objname, objtype, evttype, exargs;
		string parent, triggertype;
		vector<xmlrpc_c::value> event =
			((xmlrpc_c::value_array)events[i]).vectorValueValue();

		exidx = (xmlrpc_c::value_string)event[0];
		extime = (xmlrpc_c::value_string)event[1];
		objname = (xmlrpc_c::value_string)event[2];
		objtype = (xmlrpc_c::value_string)event[3];
		evttype = (xmlrpc_c::value_string)event[4];
		exargs = (xmlrpc_c::value_string)event[5];
		parent = (xmlrpc_c::value_string)event[6];
		triggertype = (xmlrpc_c::value_string)event[7];
// XXX
//	info("rpc.cc:RPC_eventlist(): Adding an event\n");
// XXX 		
		if (AddEvent(handle, tuple, exidx.c_str(),
			     extime.c_str(), objname.c_str(),
		             exargs.c_str(), objtype.c_str(),
		             evttype.c_str(), parent.c_str(),
		             triggertype.c_str()) < 0) {
			return -1;
		}
	}
	return 0;
}

