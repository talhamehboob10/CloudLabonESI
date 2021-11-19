/*
 * Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
 * agent-callback.c --
 *
 *      Delay node agent callback handling.
 *
 */


/******************************* INCLUDES **************************/
#include "main.h"
/******************************* INCLUDES **************************/


/******************************* EXTERNS **************************/
extern structlink_map link_map[MAX_LINKS];
extern int link_index;
extern int s_dummy; 
extern int debug;
/******************************* EXTERNS **************************/


/********************************FUNCTION DEFS *******************/


/*************************** agent_callback **********************
 This function is called from the event system when an event
 notification is recd. from the server. It checks whether the 
 notification is valid (sanity check). If not print a warning,else
 call handle_pipes which does the rest of thejob
 *************************** agent_callback **********************/

void agent_callback(event_handle_t handle,
		    event_notification_t notification, void *data)
{
  #define MAX_LEN 50

  char objname[MAX_LEN];
  char eventtype[MAX_LEN];
  int i;

    /* get the name of the object, eg. link0 or link1*/
  if(event_notification_get_string(handle,
                                   notification,
                                   "OBJNAME", objname, MAX_LEN) == 0){
    error("could not get the objname \n");
    return;
  }

  /* get the eventtype, eg up/down/modify*/
  if(event_notification_get_string(handle,
                                   notification,
                                   "EVENTTYPE", eventtype, MAX_LEN) == 0){
    error("could not get the eventtype \n");
    return;
  }

  /*
   * We could be an agent for several nodes on the same lan, so need to
   * loop over the pipe sets and possibly repeat all the work multiple
   * times. Sigh.
   */
  for(i = 0; i < link_index; i++){
    if(!strcmp(link_map[i].linkname, objname) ||
       !strcmp(link_map[i].linkvnodes[0], objname) ||
       !strcmp(link_map[i].linkvnodes[1], objname))
      handle_pipes(objname, eventtype, notification, handle, i);
  }
}

/******************** handle_pipes ***************************************
This dispatch function checks the event type and dispatches to the appropriate
routine to handle
 ******************** handle_pipes ***************************************/

void handle_pipes (char *objname, char *eventtype,
		   event_notification_t notification, event_handle_t handle,
		   int l_index)
{
  
  /*link_map[index] contains the relevant info*/

  if(strcmp(eventtype, TBDB_EVENTTYPE_UP) == 0){
    handle_link_up(objname, l_index);
  }
  else if(strcmp(eventtype, TBDB_EVENTTYPE_DOWN) == 0){
    handle_link_down(objname, l_index);
  }
  else if(strcmp(eventtype, TBDB_EVENTTYPE_MODIFY) == 0){
    handle_link_modify(objname, l_index, handle, notification);
  }
  else error("unknown link event type\n");

  if(debug){
#ifdef linux
#else
    system("ipfw pipe show");
#endif
  }
}

/******************* handle_link_up **************************
This handles the link_up event. If link is already up, it returns
without doing anything. If link is down, it calls set_link_params
for looking up the link params in the link_table and configuring 
them into dummynet
 ******************* handle_link_up ***************************/

void handle_link_up(char * linkname, int l_index)
{
  /* get the pipe params from the params field of the
     link_map table. Set the pipe params in dummynet
   */
  info("==========================================\n");
  info("recd. UP event for link = %s\n", linkname);

  /* no need to do anything if link is already up*/
  if(link_map[l_index].stat == LINK_UP)
    return;

  link_map[l_index].stat = LINK_UP;
  set_link_params(l_index, 0, -1);
}

/******************* handle_link_down **************************
This handles the link_down event. If link is already down, it returns
without doing anything. If link is up, it calls get_link_params
to populate the link_map table with current params. It then calls
set_link_params to write back the pipe params, but with plr = 1.0,
so that the link goes down
 ******************* handle_link_down***************************/

void handle_link_down(char * linkname, int l_index)
{
  /* get the pipe params from dummynet
   * Store them in the params field of the link_map table.
   * Change the pipe config so that plr = 1.0
   * so that packets are blackholed
   */
  info("==========================================\n");
  info("recd. DOWN event for link = %s\n", linkname);

  if(link_map[l_index].stat == LINK_DOWN)
    return;

  if(get_link_params(l_index) == 1){
    link_map[l_index].stat = LINK_DOWN;
    set_link_params(l_index, 1, -1);
  }
  else error("could not get params\n");
}

/*********** handle_link_modify *****************************
It gets the new link params from the notification and updates
the link_map table with these params. If the link is down,
it just returns. IF the link is up, then it calls set_link_params
to set the new params
 *********** handle_link_modify *****************************/

void handle_link_modify(char * linkname, int l_index,
			event_handle_t handle,
			event_notification_t notification)
{
  /* Get the new pipe params from the notification, and then
     update the new set of params by setting the params in
     dummynet
   */
  int i, p_which = -1;

  info("==========================================\n");
  info("recd. MODIFY event for link = %s\n", linkname);

  /*
   * As a convenience to the user, we create virt_agents entries
   * for each "link-vnode" so that users can talk to a specific
   * side of a duplex link, or a specific node in a lan (in which
   * case it refers to both pipes, not just one). Look at the
   * object name to determine ahead of time which pipe. Note that
   * for the lan node case, the virt agent entry exists strictly
   * to direct the event to this agent; there might be an actual
   * pipe spec inside the event if the user wants to one side
   * of the link (to the switch or from the switch).
   */
  if (!link_map[l_index].islan) {
    for (i = 0; i < link_map[l_index].numpipes; i++) {
      if(!strcmp(link_map[l_index].linkvnodes[i], linkname)) {
	p_which = i;
      }
    }
  }
  
  /* if the link is up, then get the params from dummynet,
     get the params from the notification and then merge
     and write back to dummynet
   */
  if(link_map[l_index].stat == LINK_UP){
    if(get_link_params(l_index) == 1)
      if(get_new_link_params(l_index, handle, notification, &p_which) == 1)
	set_link_params(l_index, 0, p_which);
  } else
    /* link is down, so just change in the link_map*/
    get_new_link_params(l_index, handle, notification, &p_which);
}

#ifdef USESOCKET
/* link field changed in 6.1 */
#if __FreeBSD_version >= 601000
#define DN_PIPE_NEXT(p)	((p)->next.sle_next)
#else
#define DN_PIPE_NEXT(p)	((p)->next)
#endif

/****************** get_link_params ***************************
for both the pipes of the duplex link, get the pipe params
sing getsockopt and store these params in the link map
table
****************** get_link_params ***************************/

int get_link_params(int l_index)
{
  struct dn_pipe *pipes;
  int fix_size;
  int num_bytes, num_alloc;
  void * data = NULL;
  int p_index = 0;
  int pipe_num;
  while( p_index < link_map[l_index].numpipes ){
    
    pipe_num = link_map[l_index].pipes[p_index];

    /* get the pipe structure from Dummynet, resizing the data
       as required
     */
    fix_size = sizeof(*pipes);
    num_alloc = fix_size;
    num_bytes = num_alloc;

    data = malloc(num_bytes);
    if(data == NULL){
      error("malloc: cant allocate memory\n");
      return 0;
    }
    
    while (num_bytes >= num_alloc) {
      num_alloc = num_alloc * 2 + 200;
      num_bytes = num_alloc ;
      if ((data = realloc(data, num_bytes)) == NULL){
	error("cant alloc memory\n");
	return 0;
      }
    
      if (getsockopt(s_dummy, IPPROTO_IP, IP_DUMMYNET_GET,
		     data, &num_bytes) < 0){
	error("error in getsockopt\n");
	return 0;
      }

    }

    /* now search the pipe list for the required pipe*/
    {

    void *next = data ;
    struct dn_pipe *p = (struct dn_pipe *) data;
    struct dn_flow_queue *q ;
    int l ;

    for ( ; num_bytes >= sizeof(*p) ; p = (struct dn_pipe *)next ) {
       
     
       if ( DN_PIPE_NEXT(p) != (struct dn_pipe *)DN_IS_PIPE )
	  break ;

       l = sizeof(*p) + p->fs.rq_elements * sizeof(*q) ;
       next = (void *)p  + l ;
       num_bytes -= l ;
       q = (struct dn_flow_queue *)(p+1) ;

       if (pipe_num != p->pipe_nr)
	   continue;

       /* grab pipe delay and bandwidth */
       link_map[l_index].params[p_index].delay = p->delay;
       link_map[l_index].params[p_index].bw = p->bandwidth;

       /* get flow set parameters*/
       get_flowset_params( &(p->fs), l_index, p_index);

       /* get dynamic queue parameters*/
       get_queue_params( &(p->fs), l_index, p_index);
     }
  }

    free(data);
    /* go for the next pipe in the duplex link*/
    p_index++; 
  }

  return 1;
}

/************ get_flowset_params ********************************
  get the flowset params from the dummnet pipe data structure
************** get_flowset_params ******************************/

void get_flowset_params(struct dn_flow_set *fs, int l_index,
			int p_index)
{
  
  /* grab pointer to the params structure of the pipe in the
     link_map table
   */
    structpipe_params *p_params
      = &(link_map[l_index].params[p_index]);


  /* q size*/
    p_params->q_size = fs->qsize;

    /* initialise flags */
    p_params->flags_p = 0;

    /* q unit */
    if (fs->flags_fs & DN_QSIZE_IS_BYTES)
      p_params->flags_p |= PIPE_QSIZE_IN_BYTES;

    /* q plr*/
   #if 0 
    p_params->plr = fs->plr;
   #endif

    p_params->plr = 1.0*fs->plr/(double)(0x7fffffff);
    
    /* hash table/bucket size */
    p_params->buckets = fs->rq_size;

#if 0
    /* number of queues in the pipe */
    p_params->n_qs = fs->rq_elements;
#endif
    
    /* q type and corresponding parameters*/

    /* internally dummynet sets DN_IS_RED (only) if the queue is RED and
       sets DN_IS_RED and DN_IS_GENTLE_RED(both) if queue is GRED*/

    if (fs->flags_fs & DN_IS_RED) {
      /* get GRED/RED params */

      p_params->red_gred_params.w_q =  1.0*fs->w_q/(double)(1 << SCALE_RED);
      p_params->red_gred_params.max_p = 1.0*fs->max_p/(double)(1 << SCALE_RED);
      p_params->red_gred_params.min_th = SCALE_VAL(fs->min_th);
      p_params->red_gred_params.max_th = SCALE_VAL(fs->max_th);

      if(fs->flags_fs & DN_IS_GENTLE_RED) 
	p_params->flags_p |= PIPE_Q_IS_GRED;
      else
	p_params->flags_p |= PIPE_Q_IS_RED;
      
    }
    /* else droptail*/

  }

/********* get_queue_params ******************************
 get the queue specific params like the pipe flow mask 
 which is used to create dynamic queues as new flows are
 formed
 ********* get_queue_params ******************************/

void get_queue_params(struct dn_flow_set *fs,
		      int l_index, int p_index)
{
  /* grab the queue mask. Actually a pipe can have multiple masks,
     HANDLE THIS LATER
   */
  
  structpipe_params *p_params
    = &(link_map[l_index].params[p_index]);
  
  
  if(fs->flags_fs & DN_HAVE_FLOW_MASK){
    p_params->flags_p    |= PIPE_HAS_FLOW_MASK;
    p_params->id.proto     = fs->flow_mask.proto;
    p_params->id.src_ip    = fs->flow_mask.src_ip;
    p_params->id.src_port  = fs->flow_mask.src_port;
    p_params->id.dst_ip    = fs->flow_mask.dst_ip;
    p_params->id.dst_port  = fs->flow_mask.dst_port;
  }

  return;
}

/****************** set_link_params ***************************
for both the pipes of the duplex link, set the pipe params
sing setsockopt getting the param values from the link_map table
**************************************************************/

void set_link_params(int l_index, int blackhole, int p_which)
{
  /* Grab the pipe params from the link_map table and then
     set them into dummynet by calling setsockopt
   */
  int p_index;

  for (p_index = 0; p_index < link_map[l_index].numpipes; p_index++) {
      /*
       * Want to do all the pipes, or just the one pipe that was
       * specified.
       */
       if(p_which == -1 || p_which == p_index) {
	    struct dn_pipe pipe;
	    /* get the params stored in the link table*/
	    structpipe_params *p_params
	      = &(link_map[l_index].params[p_index]);

	    if (debug)
	      info("entered the loop, pindex=%d, pipe=%d\n",
		   p_index, link_map[l_index].pipes[p_index]);
	
	    memset(&pipe, 0, sizeof pipe);

	    /* set the bandwidth and delay*/
	    pipe.bandwidth = p_params->bw;
	    pipe.delay = p_params->delay;

#ifdef DN_HAVE_BACKFILL
	    pipe.backfill = p_params->backfill;
#endif

	    /* set the pipe number*/
	    pipe.pipe_nr = link_map[l_index].pipes[p_index];

	    /* if we want to blackhole (in the case of EVENT_DOWN,
	       then we set all other pipe params same, but change the
	       plr to 1.0
	       */
	    {
	      double d = p_params->plr;

	      if (blackhole)
		d = 1.0;
	      
	      pipe.fs.plr = (int)(d*0x7fffffff);
	    }

	    /* set the queue size*/
	    pipe.fs.qsize = p_params->q_size;
	    /* set the number of buckets used for dynamic queues*/
	    pipe.fs.rq_size = p_params->buckets;
#if 0
	    pipe.fs.rq_elements = num_qs;
#endif
	    /* initialise pipe flags to zero */
	    pipe.fs.flags_fs = 0;

	    /* set if the q size is in slots or in bytes*/
	    if(p_params->flags_p & PIPE_QSIZE_IN_BYTES)
	      pipe.fs.flags_fs |= DN_QSIZE_IS_BYTES;
   
#if 0
	    pipe.fs.flow_mask.proto = 0;
	    pipe.fs.flow_mask.src_ip = 0;
	    pipe.fs.flow_mask.dst_ip = 0;
	    pipe.fs.flow_mask.src_port = 0;
	    pipe.fs.flow_mask.dst_port = 0;

#endif

	    /* set if the pipe has a flow mask*/
	    if(p_params->flags_p & PIPE_HAS_FLOW_MASK){
	      pipe.fs.flags_fs |= DN_HAVE_FLOW_MASK;

	      pipe.fs.flow_mask.proto = p_params->id.proto;
	      pipe.fs.flow_mask.src_ip = p_params->id.src_ip;
	      pipe.fs.flow_mask.dst_ip = p_params->id.dst_ip;
	      pipe.fs.flow_mask.src_port = p_params->id.src_port;
	      pipe.fs.flow_mask.dst_port = p_params->id.dst_port;
	    }
	    /* set the queing discipline and other relevant params*/

	    if(p_params->flags_p & (PIPE_Q_IS_GRED | PIPE_Q_IS_RED)){
	      /* set GRED params */
	      pipe.fs.flags_fs |= DN_IS_RED;
	      pipe.fs.max_th = p_params->red_gred_params.max_th;
	      pipe.fs.min_th = p_params->red_gred_params.min_th;
	      pipe.fs.w_q = (int) ( p_params->red_gred_params.w_q * (1 << SCALE_RED) ) ;
	      pipe.fs.max_p = (int) ( p_params->red_gred_params.max_p * (1 << SCALE_RED) );

	      if(p_params->flags_p & PIPE_Q_IS_GRED)
		pipe.fs.flags_fs |= DN_IS_GENTLE_RED;

	      if(pipe.bandwidth){
		size_t len ; 
		int lookup_depth, avg_pkt_size ;
		double s, idle, weight, w_q ;
		struct clockinfo clock ;
		int t ;

		len = sizeof(int) ;
		if (sysctlbyname("net.inet.ip.dummynet.red_lookup_depth", 
				 &lookup_depth, &len, NULL, 0) == -1){
		  error("cant get net.inet.ip.dummynet.red_lookup_depth");
		  return;
		}
		if (lookup_depth == 0) {
		  info("net.inet.ip.dummynet.red_lookup_depth must" 
			    "greater than zero") ;
		  return;
		}
	   
		len = sizeof(int) ;
		if (sysctlbyname("net.inet.ip.dummynet.red_avg_pkt_size", 
			&avg_pkt_size, &len, NULL, 0) == -1){

		  error("cant get net.inet.ip.dummynet.red_avg_pkt_size");
		  return;
		}
		if (avg_pkt_size == 0){
		  info("net.inet.ip.dummynet.red_avg_pkt_size must" 
				"greater than zero") ;
		  return;
		}

		len = sizeof(struct clockinfo) ;

		if (sysctlbyname("kern.clockrate", 
				 &clock, &len, NULL, 0) == -1) {
		  error("cant get kern.clockrate") ;
		  return;
		}
	   

		/* ticks needed for sending a medium-sized packet */
		s = clock.hz * avg_pkt_size * 8 / pipe.bandwidth;

		/*
		 * max idle time (in ticks) before avg queue size becomes 0. 
		 * NOTA:  (3/w_q) is approx the value x so that 
		 * (1-w_q)^x < 10^-3. 
		 */
		w_q = ((double) pipe.fs.w_q) / (1 << SCALE_RED) ; 
		idle = s * 3. / w_q ;
		pipe.fs.lookup_step = (int) idle / lookup_depth ;
		if (!pipe.fs.lookup_step) 
		  pipe.fs.lookup_step = 1 ;
		weight = 1 - w_q ;
		for ( t = pipe.fs.lookup_step ; t > 0 ; --t ) 
		  weight *= weight ;
		pipe.fs.lookup_weight = (int) (weight * (1 << SCALE_RED)) ;
	     
	      }
	 
	    }
	    /*  else DROPTAIL*/

		   
	    /* now call setsockopt*/
	    if (setsockopt(s_dummy,IPPROTO_IP, IP_DUMMYNET_CONFIGURE, &pipe,sizeof pipe)
		< 0)
	      error("IP_DUMMYNET_CONFIGURE setsockopt failed\n");
	  }
    }
}
#else
#if defined(linux)
int get_link_params(int l_index)
{
	char _buf[BUFSIZ], bwspec[16];
	char *linkname = link_map[l_index].linkname;
	FILE *cfd;
	int  delay, qlen, bw;
	float plr;
	bzero(bwspec, sizeof(bwspec));
	
	/*
	 * Call out to perl script to get the actual params.
	 */
	sprintf(_buf, "%s/%s %s", CLIENT_BINDIR, "getdelayinfo", linkname);

	if ((cfd = popen(_buf, "r")) == NULL) {
		error("Could not start getdelayinfo for link %s\n", linkname);
		return -1;
	}
	/*
	 * First line:
	 *
	 *  bw:1500000 kbit delay:10000 plr:0.0 qlen:50
	 */
	if (fgets(_buf, sizeof _buf, cfd) == NULL) {
		error("No first line from getdelayinfo for link %s\n",
		      linkname);
		return -1;
	}
	if (sscanf(_buf, "bw:%d %s delay:%d plr:%f qlen:%d",
		   &bw, bwspec, &delay, &plr, &qlen) != 5) {
		error("Could not parse '%s'\n", _buf);
		return -1;
	}
	/*
	 * Well this is funny; it will display "bit" but not accept "bit".
	 * But that is default, so just clear it.
	 */
	if (strcmp(bwspec, "bit") == 0) {
		strcpy(bwspec, "");
	}
	structpipe_params *p_params = &(link_map[l_index].params[0]);
	p_params->delay = delay;
	p_params->bw = bw;
	strcpy(p_params->bwspec, bwspec);
	p_params->plr = (double) plr;
	p_params->q_size = qlen;

	/*
	 * Second line will be the reverse params, if duplex.
	 */
	if (link_map[l_index].numpipes == 2) {
		structpipe_params *p_params = &(link_map[l_index].params[1]);
		bzero(bwspec, sizeof(bwspec));
		
		/*
		 * Second line:
		 *
		 *  rbw:1500000 kbit rdelay:10000 rplr:0.0
		 */
		if (fgets(_buf, sizeof _buf, cfd) == NULL) {
			error("No second line from getdelayinfo for link %s\n",
			      linkname);
			return -1;
		}
		if (sscanf(_buf, "rbw:%d %s rdelay:%d rplr:%f",
			   &bw, bwspec, &delay, &plr) != 4) {
			error("Could not parse '%s'\n", _buf);
			return -1;
		}
		/*
		 * Well this is funny; it will display "bit" but not
		 * accept "bit".  But that is default, so just clear
		 * it.
		 */
		if (strcmp(bwspec, "bit") == 0) {
			strcpy(bwspec, "");
		}
		p_params->delay = delay;
		p_params->bw = bw;
		strcpy(p_params->bwspec, bwspec);
		p_params->plr = (double) plr;
	}
	pclose(cfd);
	return 1;
}
void set_link_params(int l_index, int blackhole, int p_which)
{
	structpipe_params *p_params = &(link_map[l_index].params[0]);
	int pipeno = link_map[l_index].pipes[0];
	char *iface = link_map[l_index].interfaces[0];
	char cmd[BUFSIZ];

	// Qsize only on pipe1 (outgoing) side and only for slots.
	if (p_params->flags_p & PIPE_QSIZE_IN_BYTES) {
		error("Refusing to set qsize, since its in bytes not slots\n");
	}
	else {
		sprintf(cmd, "ifconfig %s txqueuelen %d",
			iface, p_params->q_size);
		if (debug)
			info("%s\n", cmd);
		if (system(cmd)) {
			error("tc failed: '%s'\n", cmd);
		}
	}

	// Bandwidth by itself.
	sprintf(cmd, "tc class change dev %s classid %d:1 htb "
		"rate %d%s ceil %d%s",
		iface, pipeno, (int) p_params->bw, p_params->bwspec,
		(int) p_params->bw, p_params->bwspec);
	
	if (debug)
		info("%s\n", cmd);
	if (system(cmd)) {
		error("tc failed: '%s'\n", cmd);
	}
	// Now loss and delay. loss is in percent.
	sprintf(cmd, "tc qdisc change "
		"dev %s handle %d netem drop %.2f delay %dms",
		iface, pipeno + 10,
		(blackhole ? 100.0 : p_params->plr * 100), p_params->delay);
	
	if (debug)
		info("%s\n", cmd);
	if (system(cmd)) {
		error("tc failed: '%s'\n", cmd);
	}
	// And the reverse pipe in duplex mode.
	if (link_map[l_index].numpipes == 2) {
		p_params = &(link_map[l_index].params[1]);
		pipeno = link_map[l_index].pipes[1];
		iface = link_map[l_index].interfaces[1];

		// Bandwidth by itself.
		sprintf(cmd, "tc class change dev %s classid 2:1 htb "
			"rate %d %s ceil %d %s",
			iface, (int) p_params->bw, p_params->bwspec,
			(int) p_params->bw, p_params->bwspec);
	
		if (debug)
			info("%s\n", cmd);
		if (system(cmd)) {
			error("tc failed: '%s'\n", cmd);
		}
		// Now loss and delay. loss is in percent.
		sprintf(cmd, "tc qdisc change "
			"dev %s handle 3 netem drop %.2f delay %dms",
			iface,
			(blackhole ? 100.0 : p_params->plr * 100),
			p_params->delay);
	
		if (debug)
			info("%s\n", cmd);
		if (system(cmd)) {
			error("tc failed: '%s'\n", cmd);
		}
	}
}
#else
int get_link_params(int l_index)
{
	int p_index = 0;
	int pipeno;
	char _buf[BUFSIZ], *cp;
	FILE *cfd;
	
	for (p_index = 0; p_index < link_map[l_index].numpipes; p_index++) {
		pipeno = link_map[l_index].pipes[p_index];
		structpipe_params *p_params =
			&(link_map[l_index].params[p_index]);

		sprintf(_buf, "%s pipe %d show", IPFW, pipeno);

		if ((cfd = popen(_buf, "r")) == NULL) {
			error("Could not start ipfw for pipe %d\n", pipeno);
			return -1;
		}
		/*
		 * The first line is bw/delay. It looks like:
		 *     60120: 100.000 bit/s     0 ms burst 0
		 * or
		 *     60120: unlimited     0 ms burst 0
		 */
		if (fgets(_buf, sizeof _buf, cfd) == NULL) {
			error("No first line from ipfw for pipe %d\n", pipeno);
			return -1;
		}
		int tpipeno, delay;
		float bw = 0.0;
		char bwspec[16], delayunits[10];
		bzero(bwspec, sizeof(bwspec));

		if (sscanf(_buf, "%d: unlimited %d %10s",
			   &tpipeno, &delay, delayunits) != 3 &&
		    sscanf(_buf, "%d: %f %16s %d %10s",
			   &tpipeno, &bw, bwspec, &delay, delayunits) != 5) {
			error("Could not parse '%s'\n", _buf);
			return -1;
		}
		if (tpipeno != pipeno) {
			error("Bad pipeno: %d!=%d\n", pipeno, tpipeno);
		}
		/*
		 * The second line has slot/plr info
		 */
		if (fgets(_buf, sizeof _buf, cfd) == NULL) {
			error("No second line from ipfw for pipe %d\n", pipeno);
			return -1;
		}
		int qsize;
		float plr;
		char qspec[16];
		
		if (sscanf(_buf, "q%d %d %16s %f",
			   &tpipeno, &qsize, qspec, &plr) != 4) {
			error("Could not parse '%s'\n", _buf);
			return -1;
		}
		if (strncmp(qspec, "KB", 2) && strncmp(qspec, "sl", 2)) {
			error("Could not parse slot type '%s'\n", qspec);
			return -1;
		}
		/* plr is optional, and there are no spaces after Q spec. */
		if (strstr(qspec, "plr") == NULL) {
			plr = 0.0;
		}
		/*
		 * Next line might be optional RED/GRED stuff.
		 */
		if (fgets(_buf, sizeof _buf, cfd) == NULL) {
			error("No third line from ipfw for pipe %d\n", pipeno);
			return -1;
		}
		if ((cp = strstr(_buf, "RED"))) {
			double w_q;
			int max_th;
			int min_th;
			double max_p;
			char *ccp = strchr(cp, ' ');
			*ccp = '\0';
			ccp++;

			if (sscanf(ccp, "w_q %lf min_th %d max_th %d max_p %lf",
				   &w_q, &min_th, &max_th, &max_p) != 4) {
				error("Could not parse RED '%s'\n", ccp);
				return -1;
			}
			if (strstr(_buf, "GRED")) {
				p_params->flags_p |= PIPE_Q_IS_GRED;
			}
			else {
				p_params->flags_p |= PIPE_Q_IS_RED;
			}
			p_params->red_gred_params.w_q    = w_q;
			p_params->red_gred_params.max_p  = max_p;
			p_params->red_gred_params.min_th = min_th;
			p_params->red_gred_params.max_th = max_th;
		}
		else {
			p_params->flags_p &= ~(PIPE_Q_IS_RED|PIPE_Q_IS_GRED);
		}

		pclose(cfd);
		p_params->delay = delay;
#if !defined(USESOCKET) && (__FreeBSD_version >= 800000 && __FreeBSD_version < 803000)
		/*
		 * Whacky hack for a bug in ipfw that results in the
		 * delay not being converted back into milliseconds.
		 */
		if (delay) {
			p_params->delay = p_params->delay * 1000 / kern_hz;
		}
#endif
		p_params->bw = bw;
		strcpy(p_params->bwspec, bwspec);
		p_params->plr = plr;
		p_params->q_size = qsize;
		if (strncmp(qspec, "KB", 2) == 0) {
			p_params->flags_p |= PIPE_QSIZE_IN_BYTES;
		}
		else {
			p_params->flags_p &= ~PIPE_QSIZE_IN_BYTES;
		}
	}
	return 1;
}
void set_link_params(int l_index, int blackhole, int p_which)
{
	int p_index;

	for (p_index = 0; p_index < link_map[l_index].numpipes; p_index++) {
		structpipe_params *p_params;
		int pipeno;
		char cmd[BUFSIZ];
		
		/*
		 * Want to do all the pipes, or just the one pipe that was
		 * specified.
		 */
		if (! (p_which == -1 || p_which == p_index))
			continue;
			
		/* get the params stored in the link table*/
		p_params = &(link_map[l_index].params[p_index]);
		pipeno   = link_map[l_index].pipes[p_index];

		if (debug)
			info("entered the loop, pindex=%d, pipe=%d\n",
			     p_index, pipeno);

		sprintf(cmd, "%s pipe %d config delay %dms bw %d%s plr %lf "
			"queue %d%s ",
			IPFW, pipeno, p_params->delay,
			(int) p_params->bw, p_params->bwspec,
			(blackhole ? 1.0 : p_params->plr),
			(p_params->flags_p &
			 PIPE_QSIZE_IN_BYTES ?
			 p_params->q_size / 1000 : p_params->q_size),
			(p_params->flags_p &
			 PIPE_QSIZE_IN_BYTES ? "KBytes" : ""));
			 
		if (p_params->flags_p & (PIPE_Q_IS_GRED|PIPE_Q_IS_RED)) {
			/* set GRED params */
			sprintf(cmd + strlen(cmd), " %s %lf/%d/%d/%lf ",
				(p_params->flags_p & PIPE_Q_IS_GRED ?
				 "gred" : "red"),
				p_params->red_gred_params.w_q,
				p_params->red_gred_params.min_th,
				p_params->red_gred_params.max_th,
				p_params->red_gred_params.max_p);
		}
		if (debug)
			info("%s\n", cmd);

		if (system(cmd)) {
			error("ipfw failed: '%s'\n", cmd);
		}
	}
}
#endif
#endif

/********* get_new_link_params ***************************
  For a modify event, this function gets the parameters
  from the event notification
 ********************************************************/

int get_new_link_params(int l_index, event_handle_t handle,
			event_notification_t notification, int *pipe_which)
{
  /* get the params of the pipe that were sent in the notification and
     store those values into the link_map table
   */

  char argstring[256];
  char * argtype = NULL;
  char * argvalue = NULL;
  int p_num = 0;
  int gotpipe = 0;
  int islan = link_map[l_index].islan;
  char *temp = NULL;
  int gotqib = 0;

  /* Allow upper level to init the pipe */
  if (*pipe_which >= 0) {
      gotpipe = 1;
      p_num   = *pipe_which;
  }
  
  if(event_notification_get_string(handle, notification,
                                   "ARGS", argstring, sizeof(argstring)) != 0){
    info("ARGS = %s\n", argstring);
    temp = argstring;
    
    argtype = strsep(&temp,"=");
    
    while((argvalue = strsep(&temp," \n"))){

#ifdef DN_HAVE_BACKFILL
    /* Backfill parameters. */ 
    if(strcmp(argtype,"BACKFILL")== 0){
      link_map[l_index].params[p_num].backfill = atoi(argvalue) * 1000;
      if (! gotpipe) {
	link_map[l_index].params[1].backfill =
		link_map[l_index].params[0].backfill;
      }
    } else
#endif
    if(strcmp(argtype,"BANDWIDTH")== 0){
	int newbw = atoi(argvalue);
	char *rate = "Kbits/s";	
#ifdef USESOCKET
	/* Convert to bits/s */
	newbw = newbw * 1000;
#endif	    
	info("Bandwidth = %d\n", newbw);
#ifdef linux
	/*
	 * The BW is a pain cause tc uses Kbit to mean 1024 while
	 * we take it to mean 1000. So convert to bits. Overflow?
	 */
	rate = "";
	newbw = newbw * 1000;
#endif	
	link_map[l_index].params[p_num].bw = newbw;
	if (! gotpipe) {
	  link_map[l_index].params[1].bw = link_map[l_index].params[0].bw;
	}
#ifndef USESOCKET
	strcpy(link_map[l_index].params[p_num].bwspec, rate);
	if (! gotpipe) {
		strcpy(link_map[l_index].params[1].bwspec, rate);
	}
#endif
      }
      else if (strcmp(argtype,"DELAY")== 0){
	 info("Delay = %d\n", atoi(argvalue));
	 link_map[l_index].params[p_num].delay = atoi(argvalue);
	 if (! gotpipe) {
	   link_map[l_index].params[1].delay =
		   link_map[l_index].params[0].delay;
	 }
      }
      else if (strcmp(argtype,"PLR")== 0){
	 info("Plr = %f\n", atof(argvalue));
	 link_map[l_index].params[p_num].plr = atof(argvalue);
	 if (! gotpipe) {
	   link_map[l_index].params[1].plr = link_map[l_index].params[0].plr;
	 }
      }

       /* Queue parameters. Slightly different since we do not want
	  to set the queue params for a lan node in the from-switch
	  direction. Note, by convention the 0 pipe is to the switch
          and the 1 pipe is from the switch. */
       
       else if (strcmp(argtype,"LIMIT")== 0){
	 info("QSize/Limit = %d\n", atoi(argvalue));
	 /* set the PIPE_QSIZE_IN_BYTES flag to 0,
	    since we assume that limit is in slots/packets by default
	 */
	 link_map[l_index].params[p_num].q_size = atoi(argvalue);
	 if (!gotqib)
	   link_map[l_index].params[p_num].flags_p &= ~PIPE_QSIZE_IN_BYTES;
	 if (!gotpipe && !islan) {
	   link_map[l_index].params[1].q_size =
		   link_map[l_index].params[0].q_size;
	   link_map[l_index].params[1].flags_p =
		   link_map[l_index].params[0].flags_p;
	 }
       }

       else if (strcmp(argtype,"QUEUE-IN-BYTES")== 0){
	 int qsztype = atoi(argvalue);
	 if(qsztype == 0){
	   info("QSize in slots/packets");
	   link_map[l_index].params[p_num].flags_p &= ~PIPE_QSIZE_IN_BYTES;
	 }
	 else {
#ifdef linux
	   error("QSize in bytes is not supported on linux!\n");
#else
	   info("QSize in bytes\n");
#endif
	   link_map[l_index].params[p_num].flags_p |= PIPE_QSIZE_IN_BYTES;
	 }
	 gotqib = 1;
	 if (!gotpipe && !islan) {
	   link_map[l_index].params[1].flags_p =
		   link_map[l_index].params[0].flags_p;
	 }
       }
       else if(strcmp(argtype,"MAXTHRESH")== 0){
	 info("Maxthresh = %d \n", atoi(argvalue));
	 link_map[l_index].params[p_num].red_gred_params.max_th =
		 atoi(argvalue);
	 if (!gotpipe && !islan) {
	   link_map[l_index].params[1].red_gred_params.max_th =
		   link_map[l_index].params[0].red_gred_params.max_th;
	 }
       }
       else if(strcmp(argtype,"THRESH")== 0){
	 info("Thresh = %d \n", atoi(argvalue));
	 link_map[l_index].params[p_num].red_gred_params.min_th =
		 atoi(argvalue);
	 if (!gotpipe && !islan) {
	    link_map[l_index].params[1].red_gred_params.min_th =
		    link_map[l_index].params[0].red_gred_params.min_th;
	 }
       }
       else if(strcmp(argtype,"LINTERM")== 0){
	 info("Linterm = %f\n", 1.0 / atof(argvalue));
	 link_map[l_index].params[p_num].red_gred_params.max_p =
		 1.0 / atof(argvalue);
	 if (!gotpipe && !islan) {
	   link_map[l_index].params[1].red_gred_params.max_p =
		   link_map[l_index].params[0].red_gred_params.max_p;
	 }
       }
       else if(strcmp(argtype,"Q_WEIGHT")== 0){
	 info("Qweight = %f\n", atof(argvalue));
	 link_map[l_index].params[p_num].red_gred_params.w_q =
		 atof(argvalue);
	 if (!gotpipe && !islan) {
	   link_map[l_index].params[1].red_gred_params.w_q =
		   link_map[l_index].params[0].red_gred_params.w_q;
	 }
       }
       else if(strcmp(argtype,"PIPE")== 0){
	 info("PIPE = %s\n", argvalue);

	 gotpipe++;
	 if(strcmp(argvalue, "pipe0") == 0)
	   p_num = 0;
	 else if(strcmp(argvalue, "pipe1") == 0)
	   p_num = 1;
	 else if(isdigit(argvalue[0])) {
	   int pipeno = atoi(argvalue);

	   if(link_map[l_index].pipes[0] == pipeno)
	     p_num = 0;
	   else if(link_map[l_index].pipes[1] == pipeno)
	     p_num = 1;
	   else {
	     error("unrecognized pipe number\n");
	     return -1;
	   }
	 }
	 else {
	   error("unrecognized pipe argument\n");
	   return -1;
	 }
       }
       else {
	 error("unrecognized argument\n");
	 error("%s -> %s \n", argtype, argvalue);
       }
       argtype = strsep(&temp,"=");
     }
  }
  if (gotpipe)
    *pipe_which = p_num;
  
  return 1;
}
 /**************** get_link_info ****************************
  This builds up the initial link_map table's pipe params
   by getting the parameters from Dummynet
 **************** get_link_info ****************************/

int get_link_info(){
  int l_index = 0;
  while(l_index < link_index){
    if(get_link_params(l_index) == 0)
      return 0;
    if((int)(link_map[l_index].params[0].plr) == 1
       || (int)(link_map[l_index].params[1].plr) == 1)
      link_map[l_index].stat = LINK_DOWN;
    else
      link_map[l_index].stat = LINK_UP;
    l_index++;
  }
  return 1;
}
/********************************FUNCTION DEFS *******************/
