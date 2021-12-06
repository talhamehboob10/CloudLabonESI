/*
 * Copyright (c) 2000-2016, 2018 University of Utah and the Flux Group.
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
 * event.h --
 *
 *      Definitions for the testbed event library.
 *
 */

#ifndef __EVENT_H__
#define __EVENT_H__

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <sys/time.h>
#include <pubsub/pubsub.h>

#define EVENT_LIBRARY_VERSION	"1.0"

#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 64
#endif /* MAXHOSTNAMELEN */

#ifdef __cplusplus
extern "C" {
#endif

/* Handle to the event server: */
struct event_handle {
    pubsub_handle_t *server;
    pubsub_error_t status;
    unsigned char *keydata;
    int keylen;
    int do_loop;
    int dossl;
    char *certfile;
    char *keyfile;
    /* API function pointers: */
    int (*connect)(char *server, int portnum, pubsub_handle_t **);
    int (*disconnect)(pubsub_handle_t *handle);
    int (*mainloop)(pubsub_handle_t *handle, int *go, pubsub_error_t *error);
    int (*notify)(pubsub_handle_t *handle, pubsub_notification_t *notification,
		  pubsub_error_t *error);
    pubsub_subscription_t *(*subscribe)(pubsub_handle_t *handle,
					char *expression,
					pubsub_notify_callback_t notify_cb,
					void *notify_arg,
					pubsub_error_t *error);
    int (*unsubscribe)(pubsub_handle_t *handle,
		       pubsub_subscription_t *subscription,
		       pubsub_error_t *error);
};
typedef struct event_handle * event_handle_t;

/* Event notification: */
struct event_notification {
	pubsub_notification_t *pubsub_notification;
	int		     has_hmac;
	
};
typedef struct event_notification *event_notification_t;

/* Event subscription: */
typedef pubsub_subscription_t *event_subscription_t;

/*
 * A tuple defines the target of the event, or if you are a subscriber,
 * what events you want to subscribe to.
 */
typedef struct _address_tuple {
	char		*site;		/* Which Emulab site. God only */
	char const	*expt;		/* Project and experiment IDs */
	char		*group;		/* User defined group of nodes */
	char const	*host;		/* A specific host */		
	char const	*objtype;	/* LINK, TRAFGEN, etc ... */
        char const	*objname;	/* link0, cbr0, cbr1, etc ... */
        char const	*eventtype;	/* START, STOP, UP, DOWN, etc ... */
	int		scheduler;	/* A dynamic event to schedule */
	char		*timeline;	/* The timeline to schedule under */
} address_tuple, *address_tuple_t;
#define ADDRESSTUPLE_ANY	NULL
#define ADDRESSTUPLE_ALL	"*"
#define OBJECTTYPE_TESTBED	"TBCONTROL"
#define OBJECTTYPE_TRAFGEN	"TRAFGEN"

address_tuple_t	address_tuple_alloc(void);
int		address_tuple_free(address_tuple_t);

#ifndef SWIG /* SWIG doesn't handle these, so we have to hide them from it */
#ifndef NO_EVENT_MACROS
#define event_notification_get_site(handle, note, buf, len) \
        event_notification_get_string(handle, note, "SITE", buf, len)
#define event_notification_put_site(handle, note, buf) \
        event_notification_put_string(handle, note, "SITE", buf)
#define event_notification_get_expt(handle, note, buf, len) \
        event_notification_get_string(handle, note, "EXPT", buf, len)
#define event_notification_get_group(handle, note, buf, len) \
        event_notification_get_string(handle, note, "GROUP", buf, len)
#define event_notification_get_host(handle, note, buf, len) \
        event_notification_get_string(handle, note, "HOST", buf, len)
#define event_notification_get_objtype(handle, note, buf, len) \
        event_notification_get_string(handle, note, "OBJTYPE", buf, len)
#define event_notification_get_objname(handle, note, buf, len) \
        event_notification_get_string(handle, note, "OBJNAME", buf, len)
#define event_notification_get_eventtype(handle, note, buf, len) \
        event_notification_get_string(handle, note, "EVENTTYPE", buf, len)
#define event_notification_get_arguments(handle, note, buf, len) \
        event_notification_get_string(handle, note, "ARGS", buf, len)
#define event_notification_set_arguments(handle, note, buf) \
        event_notification_put_string(handle, note, "ARGS", buf)
#define event_notification_get_timeline(handle, note, buf, len) \
        event_notification_get_string(handle, note, "TIMELINE", buf, len)

/*
 * For dynamic events.
 */
#define event_notification_clear_site(handle, note) \
	event_notification_remove(handle, note, "SITE")
#define event_notification_clear_host(handle, note) \
	event_notification_remove(handle, note, "HOST")
#define event_notification_set_host(handle, note, buf) \
        event_notification_put_string(handle, note, "HOST", buf)
#define event_notification_clear_objtype(handle, note) \
	event_notification_remove(handle, note, "OBJTYPE")
#define event_notification_set_objtype(handle, note, buf) \
        event_notification_put_string(handle, note, "OBJTYPE", buf)
#define event_notification_clear_objname(handle, note) \
	event_notification_remove(handle, note, "OBJNAME")
#define event_notification_set_objname(handle, note, buf) \
        event_notification_put_string(handle, note, "OBJNAME", buf)

/*
 * Event library sets this field. Holds the sender of the event, as 
 * determined by the library when it is initialized. 
 */
#define event_notification_get_sender(handle, note, buf, len) \
        event_notification_get_string(handle, note, "___SENDER___", buf, len)
#define event_notification_set_sender(handle, note, buf) \
        event_notification_put_string(handle, note, "___SENDER___", buf)
#define event_notification_clr_sender(handle, note) \
        event_notification_remove(handle, note, "___SENDER___")

#define event_notification_get_version(handle, note, buf, len) \
        event_notification_get_string(handle, note, "___VERSION___", buf, len)
#define event_notification_set_version(handle, note, buf) \
        event_notification_put_string(handle, note, "___VERSION___", buf)
#define event_notification_clr_version(handle, note) \
        event_notification_remove(handle, note, "___VERSION___")

#endif /* ifndef NO_EVENT_MACROS */
#endif /* ifndef SWIG */


/* The "any host" string: */
#define EVENT_HOST_ANY "*"

/* Supported event types: */
typedef enum {
    EVENT_NULL,
    EVENT_TEST,
    EVENT_SCHEDULE,
    EVENT_TRAFGEN_START,
    EVENT_TRAFGEN_STOP
} event_type_t;

/* Event notification callback function.  Passed to event_subscribe
   and called whenever the specified event is triggered.
   HANDLE is the handle to the event server, NOTIFICATION is the event
   notification itself, and DATA is an arbitrary value passed to
   event_subscribe (argument 4).
 */
typedef void (*event_notify_callback_t)(event_handle_t handle,
                                        event_notification_t notification,
                                        void *data);

typedef void (*event_subscription_callback_t)(event_handle_t handle,
					      int result,
					      event_subscription_t es,
					      void *data);

/*
 * Function prototypes:
 */

/* event.c */
event_handle_t event_register(char const *name, int threaded);
event_handle_t event_register_withssl(char const *name, int threaded,
				      char const *certfile, char const *keyfile);
event_handle_t event_register_withkeyfile(char const *name, int threaded,
					  char *keyfile);
event_handle_t event_register_withkeydata(char const *name, int threaded,
					  unsigned char *keydata, int len);
event_handle_t event_register_withkeyfile_withretry(char const *name, int threaded,
					  char *keyfile, int retrycount);
event_handle_t event_register_withkeydata_withretry(char const *name, int threaded,
					  unsigned char *keydata, int len,
					  int retrycount);
int event_unregister(event_handle_t handle);
int event_poll(event_handle_t handle);
int event_poll_blocking(event_handle_t handle, unsigned int timeout);
int event_main(event_handle_t handle);
int event_stop_main(event_handle_t handle);
int event_notify(event_handle_t handle, event_notification_t notification);
int event_schedule(event_handle_t handle, event_notification_t notification,
                   struct timeval *time);
event_notification_t event_notification_alloc(event_handle_t handle,
                                              address_tuple_t tuple);
int event_notification_free(event_handle_t handle,
                            event_notification_t notification);
event_notification_t event_notification_clone(event_handle_t handle,
					event_notification_t notification);
int event_notification_get_double(event_handle_t handle,
                                  event_notification_t notification,
                                  char const *name, double *value);
int event_notification_get_int32(event_handle_t handle,
                                 event_notification_t notification,
                                 char const *name, int32_t *value);
int event_notification_get_int64(event_handle_t handle,
                                 event_notification_t notification,
                                 char const *name, int64_t *value);
int event_notification_get_opaque_length(event_handle_t handle,
					 event_notification_t notification,
					 char const *name);
int event_notification_get_string_length(event_handle_t handle,
					 event_notification_t notification,
					 char const *name);
int event_notification_get_opaque(event_handle_t handle,
                                  event_notification_t notification,
                                  char const *name, void *buffer, int length);
int event_notification_get_string(event_handle_t handle,
                                  event_notification_t notification,
                                  char const *name, char *buffer, int length);
int event_notification_put_double(event_handle_t handle,
                                  event_notification_t notification,
                                  char const *name, double value);
int event_notification_put_int32(event_handle_t handle,
                                 event_notification_t notification,
                                 char const *name, int value);
int event_notification_put_int64(event_handle_t handle,
                                 event_notification_t notification,
                                 char const *name, int64_t value);
int event_notification_put_opaque(event_handle_t handle,
                                  event_notification_t notification,
                                  char const *name, void *buffer, int length);
int event_notification_put_string(event_handle_t handle,
                                  event_notification_t notification,
                                  char const *name, char const *value);
int event_notification_remove(event_handle_t handle,
                              event_notification_t notification, char const *name);
event_subscription_t event_subscribe(event_handle_t handle,
                                     event_notify_callback_t callback,
                                     address_tuple_t tuple, void *data);
event_subscription_t event_subscribe_auth(event_handle_t handle,
					  event_notify_callback_t callback,
					  address_tuple_t tuple, void *data,
					  int do_auth);
int event_async_subscribe(event_handle_t handle,
			  event_notify_callback_t callback,
			  address_tuple_t tuple, void *data,
			  event_subscription_callback_t scb,
			  void *scb_data,
			  int do_auth);
int event_unsubscribe(event_handle_t handle, event_subscription_t es);
int event_async_unsubscribe(event_handle_t handle, event_subscription_t es);
int event_notification_insert_hmac(event_handle_t handle,
				   event_notification_t notification);
#ifdef NOTYET
int event_notification_pack(event_handle_t handle,
			    event_notification_t notification,
			    unsigned char *data, int *len);
int event_notification_unpack(event_handle_t handle,
			    event_notification_t *notification,
			    unsigned char *data, int len);
#endif
int event_set_idle_period(event_handle_t handle, int seconds) ;
int event_set_failover(event_handle_t handle, int dofail) ;
int event_set_sockbufsizes(int, int);

int event_arg_get(char *args, char const *key, char **value);
int event_arg_dup(char *args, char const *key, char **value);

typedef enum {
    EA_TAG_DONE,
    EA_Site,
    EA_Experiment,
    EA_Group,
    EA_Host,
    EA_Type,
    EA_Name,
    EA_Event,
    EA_Arguments,
    EA_ArgInteger,
    EA_ArgFloat,
    EA_ArgString,
    EA_When,
} ea_tag_t;

event_notification_t event_notification_create_v(event_handle_t handle,
						 struct timeval **when_out,
						 ea_tag_t tag,
						 va_list args);
event_notification_t event_notification_create(event_handle_t handle,
					       ea_tag_t tag,
					       ...);
int event_do_v(event_handle_t handle, ea_tag_t tag, va_list args);
int event_do(event_handle_t handle, ea_tag_t tag, ...);

/* util.c */
void *xmalloc(int size);
void *xrealloc(void *p, int size);
void make_timestamp(char * buf, const struct timeval * t_timeval);

#ifdef __cplusplus
}
#endif

#endif /* __EVENT_H__ */
