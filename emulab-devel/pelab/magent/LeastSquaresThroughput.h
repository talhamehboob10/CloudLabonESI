/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

// LeastSquaresThroughput.h

// Algorithm based on the equations at:
//   http://www.shodor.org/succeed/compchem/tools/llsalg.html

#ifndef LEAST_SQUARES_THROUGHPUT_H_STUB_2
#define LEAST_SQUARES_THROUGHPUT_H_STUB_2

#include "Sensor.h"

class TSThroughputSensor;
class DelaySensor;

class LeastSquaresThroughput : public Sensor
{
public:
  // The default max period to use.
  static const int DEFAULT_MAX_PERIOD = 500;
public:
  LeastSquaresThroughput(TSThroughputSensor const * newThroughput,
                         DelaySensor const * newDelay,
                         int newMaxPeriod = 0);
  virtual ~LeastSquaresThroughput();
protected:
  virtual void localSend(PacketInfo * packet);
  virtual void localAck(PacketInfo * packet);
private:
  struct Ack
  {
    Ack() : size(0), period(0), rtt(0) {}
    int size; // in bytes
    uint32_t period; // in milliseconds
    int rtt; // in milliseconds
  };
private:
  TSThroughputSensor const * throughput;
  DelaySensor const * delay;

  // The number of samples kept at any given time.
  static const int MAX_SAMPLE_COUNT = 100;
  // Circular buffer of the last MAX_SAMPLE_COUNT samples.
  Ack samples[MAX_SAMPLE_COUNT];
  // The maximum number of samples used for least squares analysis.
  static const int MAX_LEAST_SQUARES_SAMPLES = 5;

  // The index of the latest stored sample.
  int latest;
  // The total number of samples ever encountered.
  int totalSamples;
  // The maximum amount of time to look backwards in milliseconds. If
  // this number is <= 0 then all available samples are used.
  int maxPeriod;

  // The last number reported to the monitor in kbps.
  // Only send bandwidth if it is different than this number.
  // Only send throughput if it is > this number.
  int lastReport;
};

#endif
