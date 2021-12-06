/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
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
 * @file dashboard.hh
 *
 * Header file for the dashboard class.
 */

#ifndef _dashboard_hh
#define _dashboard_hh

#include <math.h>
#include <stdio.h>
#include <sys/time.h>

#include "acpGarcia.h"

#include "mtp.h"
#include "ledManager.hh"
#include "buttonManager.hh"
#include "faultDetection.hh"

/**
 * LED priority for an acknowledgment of user input.
 */
const int LED_PRI_USER = 128;

/**
 * LED priority for motion.
 */
const int LED_PRI_MOVE = 0;

/**
 * LED priority for an error.
 */
const int LED_PRI_ERROR = -1;

/**
 * LED priority for a battery warning.
 */
const int LED_PRI_BATTERY = -128;

/**
 * LED pattern that signifies an error condition.
 */
#define LED_PATTERN_ERROR		ledClient::LMP_FAST_DOT

/**
 * LED pattern that signifies an acknowledgment of user input.
 */
#define LED_PATTERN_ACK			ledClient::LMP_DOT

/**
 * LED pattern that signifies the robot has entered "command" mode.
 */
#define LED_PATTERN_COMMAND_MODE	ledClient::LMP_DASH

/**
 * LED pattern that signifies the robot is moving.
 */
#define LED_PATTERN_MOVING		ledClient::LMP_DASH_DOT

/**
 * LED pattern that signifies the battery is low.
 */
#define LED_PATTERN_BATTERY		ledClient::LMP_LINE

/**
 * The dashboard class tracks the robots movement and manages any LEDs or
 * buttons.
 */
class dashboard : public pollCallback
{

public:

    /**
     * Low battery level threshold, in percent points.
     */
    static const float BATTERY_LOW_THRESHOLD = 15.0f;

    /**
     * High battery level threshold, in percent points.
     */
    static const float BATTERY_HIGH_THRESHOLD = 20.0f;
    
    /**
     * The length of time between "short" updates, which record the readings on
     * the various sensors.
     */
    static const int SHORT_UPDATE_INTERVAL = 1000;

    /**
     * The length of time between "long" updates, which record battery levels
     * and other infrequently changing attributes.
     */
    static const int LONG_UPDATE_INTERVAL = 60 * 1000;

    /**
     * Construct a dashboard for the given garcia.
     *
     * @param garcia The garcia to manage.
     * @param battery_log File object where battery log data should be dumped.
     */
    dashboard(acpGarcia &garcia, FILE *battery_log);

    /**
     * Destructor.
     */
    virtual ~dashboard();

    /**
     * Add a ledClient to the "user-led" ledManager.
     *
     * @param lc The ledClient to add.
     */
    void addUserLEDClient(ledClient *lc) { this->db_user_led.addClient(lc); };

    /**
     * Remove a ledClient from the "user-led" ledManager.
     *
     * @param lc The ledClient to add.
     */
    void remUserLEDClient(ledClient *lc) { this->db_user_led.remClient(lc); };

    /**
     * Set the callback for the "user-button".
     *
     * @param bc The new callback.
     */
    void setUserButtonCallback(buttonCallback *bc)
    { this->db_user_button.setCallback(bc); };

    void setFaultCallback(faultCallback *fc)
    { this->db_fault.setCallback(fc); };

    void setDistanceLimit(float limit)
    { this->db_fault.setDistanceLimit(limit); };
    
    void setVelocityLimit(float limit)
    { this->db_fault.setVelocityLimit(limit); };

    /**
     * Signal the start of a movement.
     */
    void startMove();

    /**
     * Signal the end of a movement and update the odometers accordingly.
     *
     * @param left_odometer Set to the distance the left wheel moved.
     * @param right_odometer Set to the distance the right wheel moved.
     */
    void endMove(float &left_odometer, float &right_odometer);

    /**
     * @return True if the battery level is below the threshold.
     */
    bool isBatteryLow(void) { return (this->db_battery_warning != NULL); };

    /**
     * @return The telemetry structure maintained by this dashboard.
     */
    struct mtp_garcia_telemetry *getTelemetry()
    { return &this->db_telemetry; };

    /**
     * @return True if the telemetry was updated in the last tick.
     */
    bool wasTelemetryUpdated()
    {
	bool retval = this->db_telemetry_updated;

	this->db_telemetry_updated = false;
	return retval;
    };

    /**
     * Dump a formatted view of the telemetry to the given file.
     *
     * @param file The output file to write the telemetry to.
     */
    void dump(FILE *file);

    /**
     * Periodic callback used to update telemetry, the "user-led", and the
     * "user-button".
     *
     * @param now The current time in milliseconds.
     * @return True if the outer loop should continue, false otherwise.
     */
    bool update(unsigned long now);

private:

    /**
     * The garcia being managed.
     */
    acpGarcia &db_garcia;

    /**
     * File where battery log data should be dumped.
     */
    FILE *db_battery_log;

    enum {
	DBC_USER_LED,	 /*< Index of db_user_led in db_poll_callbacks. */
	DBC_USER_BUTTON, /*< Index of db_user_button in db_poll_callbacks. */
	// DBC_FAULT,	 /*< Index of db_fault in db_poll_callbacks. */

	DBC_MAX		 /*< Maximum number of objects in db_poll_callbacks. */
    };

    /**
     * Array of pollCallbacks to be traversed during an update.
     */
    pollCallback *db_poll_callbacks[DBC_MAX];

    /**
     * The manager for the "user-led" property.
     */
    ledManager db_user_led;

    /**
     * The manager for the "user-button" property.
     */
    buttonManager db_user_button;
    
    faultDetection db_fault;

    /**
     * The current telemetry for this object, most of the fields are updated
     * about every second in the update method.
     */
    struct mtp_garcia_telemetry db_telemetry;

    /**
     * True if the telemetry was updated in the last tick, which should happen
     * about every second.
     */
    bool db_telemetry_updated;

    bool db_update_velocity;

    /**
     * The last value read from the left wheel's odometer, used to update the
     * velocity measure.
     */
    double db_last_left_odometer;

    /**
     * The last value read from the right wheel's odometer, used to update the
     * velocity measure.
     */
    double db_last_right_odometer;

    /**
     * The time when a move was started.
     */
    struct timeval db_move_start_time;

    /**
     * Pointer to the ledClient that displays the battery warning pattern on
     * the user LED.
     */
    ledClient *db_battery_warning;

    unsigned long db_last_tick;

    /**
     * The next time the telemetry should be updated, in milliseconds.
     */
    unsigned long db_next_short_tick;

    /**
     * The next time the battery levels should be updated, in milliseconds.
     */
    unsigned long db_next_long_tick;
    
};

#endif
