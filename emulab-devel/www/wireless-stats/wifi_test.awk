#/bin/nawk

#
# Copyright (c) 2005-2006 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

# wifi_test.awk
# Generate test data file from the positions, ramp connectivity by distance & power.

BEGIN{ nlevels = split("2 8 15 64 128 192 255", power); }

# Load position data.
{
	nodes++;
	x[nodes] = $2; y[nodes] = $3; z[nodes] = ( $4 == 3 ? 0 : 10 );
	match($1, "[0-9]+"); id[nodes] = substr($1, RSTART, RLENGTH);
	print "added phs for wifi id", id[nodes]; 
}

END {
	for ( p = 1; p <= nlevels; p++ ) {
		pow = power[p];
		printf "Data for power level 0x%x\n", pow;
		for ( i = 1; i <= nodes; i++ ) {
			for ( j = 1; j <= nodes; j++ ) {
				if ( i == j ) continue;

				# Distance between nodes in meters.
				xd = x[i] - x[j]; yd = y[i] - y[j]; zd = z[i] - z[j];
				dist = sqrt((xd*xd) + (yd*yd) + (zd*zd));
				# 10.77 pixels/meter on the 1.5-scale images.
				meters = dist/10.77;

				# Pretend range is 50 meters at full power, degrade linearly.
				range = 50 * (pow/255);
				if ( meters >= range ) rate = 0;
				else rate = int( ( (range - meters) / range) * 100 );

				printf "(%d) <- (%d): pkts(%d/100,%d.0%%) %s\n",
					id[j], id[i], rate, rate, "rssi(0.0,0.0,0.0,0.0)";
				#printf "%d (%d %d %d), %d (%d %d %d), [%f %f %f] %f %f %f\n",
				#	 j, x[j], y[j], z[j], i, x[i], y[i], z[i],
				#	 xd, yd, zd, dist, meters, range;
			}
		}
		printf "\n";
	}
}
