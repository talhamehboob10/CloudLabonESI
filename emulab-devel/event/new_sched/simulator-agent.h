/*
 * Copyright (c) 2004, 2005 University of Utah and the Flux Group.
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

/**
 * @file simulator-agent.h
 *
 * Header file for the SIMULATOR agent.
 */

#ifndef _simulator_agent_h
#define _simulator_agent_h

#include "event-sched.h"
#include "local-agent.h"
#include "error-record.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Enumeration of the different categories of text in a report.
 */
typedef enum {
	SA_RDK_MESSAGE,	/*< Main message body, this is at the top of the report
			 and is intended for a plain english description of
			 the experiment. */
	SA_RDK_LOG,	/*< Log data for the tail of the report, used for
			  machine generated data mostly. */
	SA_RDK_CONFIG,	/*< Config data for the tail of the report. */

	SA_RDK_MAX	/*< The maximum number of message types. */
} sa_report_data_kind_t;

enum {
	SA_RDB_NEWLINE,
};

enum {
	SA_RDF_NEWLINE = (1L << SA_RDB_NEWLINE),
};

enum {
	SAB_TIME_STARTED,
	SAB_STABLE,
};

enum {
	SAF_TIME_STARTED = (1L << SAB_TIME_STARTED),
	SAF_STABLE = (1L << SAB_STABLE),
};

/**
 * A local agent structure for the NS Simulator object.
 */
struct _simulator_agent {
	struct _local_agent sa_local_agent;	/*< Local agent base. */
	unsigned long sa_flags;
	struct lnList sa_error_records;		/*< The error records that have
						  been collected over the
						  course of the experiment. */
	char *sa_report_data[SA_RDK_MAX];	/*< Different kinds of text to
						 include in the report. */
	struct timeval sa_time_start;		/*< */
};

/**
 * Pointer type for the _simulator_agent structure.
 */
typedef struct _simulator_agent *simulator_agent_t;

/**
 * Create a simulator agent and initialize it with the default values.
 *
 * @return An initialized simulator agent.
 */
simulator_agent_t create_simulator_agent(void);

/**
 * Check a simulator agent object against the following invariants:
 *
 * @li sa_local_agent is sane
 * @li sa_error_records is sane
 *
 * @param sa An initialized simulator agent object.
 * @return True.
 */
int simulator_agent_invariant(simulator_agent_t sa);

/**
 * Add some message/log data that should be included in the generated report
 * for this simulator.  The data is appended to any previous additions along
 * with a newline if it does not have one.
 *
 * @param sa The simulator agent object where the data is kept.
 * @param rdk The type of data being added.
 * @param data The data to add, should just be ASCII text.
 * @return Zero on success, -1 otherwise.
 *
 * @see send_report
 */
int add_report_data(simulator_agent_t sa,
		    sa_report_data_kind_t rdk,
		    char const *data,
		    unsigned long flags);

/**
 * Sends a summary report to the user via e-mail and also sort of marks the end
 * of a run of the experiment.  The content of the report is partially
 * generated by the user with the rest being automatically generated by the
 * testbed.  First, the function will sync the logholes so any data needed to
 * automatically generate parts of the report are readily available.  Then, the
 * body of the mail is constructed by appending any user provided messages and
 * log data with the digested error records.  Ideally, the user provided
 * messages should provide a human readable summary of the success/failure of
 * their experiment.  Any log data from the user should report any performance
 * metrics, warnings, or any other salient data.  Finally, the function will
 * iterate through the list of error records and append any available log files
 * or messages paired with those records.
 *
 * After sending the mail, the simulator object will be reset to a pristine
 * state so another experimental run can begin with a clean slate.
 *
 * @param sa The simulator agent object to summarize.
 * @param args The event arguments.
 * @return Zero on success, -1 otherwise.
 *
 * @see dump_error_records
 */
int send_report(simulator_agent_t sa, char *args);


/**
 * Send an "error" report.  Similar to send_report but doesn't create
 * a zip file or clear the logs directory.  Also avoids overwriting
 * the "report.mail" file by writing to "error-report.mail" instead.
 */
int send_error_report(simulator_agent_t sa, char *args);

#ifdef __cplusplus
}
#endif

#endif
