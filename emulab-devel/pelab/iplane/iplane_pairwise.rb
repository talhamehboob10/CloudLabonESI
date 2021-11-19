#!/usr/bin/ruby
#
# Copyright (c) 2006 University of Utah and the Flux Group.
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

#
# Get pairwise predictions from iplane
#
# To run:
# iplane_query_client iplane.cs.washington.edu 1 iplane_pairwise.rb
#     'space seperated list of IP addresses'
#

require 'iplane'

#
# Get pairwise information for all nodes passed on the command line
#
nodes = ARGV

iplane = IPlane.new

#
# For now, query one-way only - the upper right corner of the NxN matrix
#
nodes.each_index{ |n1|
    (n1 + 1 .. nodes.length() - 1).each{ |n2| 
#        puts "Adding path #{nodes[n1]} to #{nodes[n2]}"
        iplane.addPath(nodes[n1],nodes[n2])
    }
}

#
# Run the query on iplane
#
#puts "Getting responses..."
responses = iplane.queryPendingPaths
#puts "Got Respnses!"

#
# And, simply print the data we care about from the responses
#
responses.each{ |r|
    puts "source=#{r.src} dest=#{r.dst} latency=#{r.lat}"
#"predicted?=#{r.predicted_flag}"
}
