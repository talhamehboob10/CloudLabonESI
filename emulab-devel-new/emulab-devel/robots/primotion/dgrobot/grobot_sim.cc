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

#include "config.h"

#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>

#define GROBOT_SIM

#include "grobot.h"

grobot::grobot()
{
    dx_est = 0.0f;
    dy_est = 0.0f;
}

grobot::~grobot()
{
}

void grobot::estop()
{
}

void grobot::setWheels(float Vl, float Vr)
{
}

void grobot::setvPath(float Wv, float Wr)
{
}

void grobot::pbMove(float mdisplacement)
{
    
}

void grobot::pbPivot(float pangle)
{
}

void grobot::dgoto(float Dx, float Dy, float Rf)
{
    printf("goto %f, %f, %f\n", Dx, Dy, Rf);

    this->dx_est = Dx;
    this->dy_est = Dy;
    this->gotocomplete = 1;
}

void grobot::resetPosition()
{
    this->dx_est = 0;
    this->dy_est = 0;
}

void grobot::updatePosition()
{
}

float grobot::getArclen()
{
    return 0.0f;
}

void grobot::getDisplacement(float &dxtemp, float &dytemp)
{
    dxtemp = this->dx_est;
    dytemp = this->dy_est;
}

int grobot::getGstatus()
{
    return 0;
}

int grobot::getGOTOstatus()
{
    int retval = this->gotocomplete;

    this->gotocomplete = 0;
    return retval;
}

void grobot::sleepy()
{
    struct timeval tv = { 0, 100 };

    select(0, NULL, NULL, NULL, &tv);
}

void grobot::setCBexec(int id)
{
}

void grobot::setCBstatus(int id, int status, cb_type_t cbt)
{
}

void grobot::createNULLbehavior()
{
}

void grobot::createPRIMbehavior(cb_type_t cbt)
{
}

void grobot::set_gotocomplete()
{
}
