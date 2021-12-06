#!/usr/bin/python
import serial
import time
import datetime
import re
import sys
import os
from subprocess import *

TTYDEV = '/dev/ttyACM0'
STTY   = 'stty -F /dev/ttyACM0 -ixon -crtscts -ixon -ixoff -ixany -hupcl'

# When zero, we are a daemon
debug  = 0

if not debug:
    #
    # Daemonize. We redirect our output into a log file.
    #
    try:
        fp = open("/var/log/power.log", "a", 0);
        sys.stdout = fp
        sys.stderr = fp
        sys.stdin.close();
        pass
    except:
        print "Could not open log file"
        sys.exit(1);
        pass

    pid = os.fork()
    if pid:
        sys.exit(0)
        pass
    os.setsid();
    pass

while True:
    if os.path.exists(TTYDEV):
        now = datetime.datetime.now()
        print now

        os.system(STTY);

        try:
            arduino = serial.Serial(TTYDEV, 9600, timeout=1)
        except:
            print "Could not open arduino serial device."
            time.sleep(5)
            continue

        try:
            arduino.write("voltage\r");
        except:
            break
        
        while True:
            try:
                # The last bit gets rid of the newline            
                data = arduino.readline()[:-2]
            except:
                break

            if not data:
                break

            if data.find("Pin") >= 0:
                print data
                pass
            pass
        
        try:
            arduino.write("temp\r");
        except:
            break
        
        while True:
            try:
                # The last bit gets rid of the newline            
                data = arduino.readline()[:-2]
            except:
                break

            if not data:
                break

            print data
            pass
        if not debug:
            os.fsync(sys.stdout.fileno())
            pass
        arduino.close();
        pass
    time.sleep(5)
    pass

