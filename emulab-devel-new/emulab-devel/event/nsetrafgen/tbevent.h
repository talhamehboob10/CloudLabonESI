/*
 * Copyright (c) 2000-2002 University of Utah and the Flux Group.
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

#ifndef TBEVENT_H
#define TBEVENT_H

/* NSE includes */
#include "config.h"

/* event library stuff */
#ifdef __cplusplus
extern "C" {
#endif

#include <sys/param.h>
#include "tbdefs.h"
#include "log.h"
#include "event.h"

#ifdef __cplusplus
}
#endif

class TbEventSink : public TclObject {
public:
	TbEventSink() : gotevent(0), ehandle(0) {
	  bzero(ipaddr, sizeof(ipaddr));
	  bzero(server, sizeof(server));
	  bzero(objnamelist, sizeof(objnamelist));
	  bzero(logfile, sizeof(logfile));
	  bzero(nseswap_cmdline, sizeof(nseswap_cmdline));
	}
	~TbEventSink();
	virtual int command(int argc, const char*const* argv);

	void init();
	void subscribe();
	int poll();
	void send_nseswap();


private:
	char  server[BUFSIZ];
	int   gotevent;
	event_handle_t	ehandle;
	char ipaddr[BUFSIZ];
	char  objnamelist[BUFSIZ];
	char  logfile[MAXPATHLEN];
	char  nseswap_cmdline[MAXPATHLEN]; 

	static void
	  callback(event_handle_t handle,
		   event_notification_t notification, void *data);
};

class TbResolver : public TclObject {
 public:
  virtual int command(int argc, const char*const* argv);
};

#endif
