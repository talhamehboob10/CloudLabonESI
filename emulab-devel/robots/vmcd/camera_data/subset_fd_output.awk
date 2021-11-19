#! /usr/bin/awk -f
# 
#   Copyright (c) 2005 University of Utah and the Flux Group.
#   
#   {{{EMULAB-LICENSE
#   
#   This file is part of the Emulab network testbed software.
#   
#   This file is free software: you can redistribute it and/or modify it
#   under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or (at
#   your option) any later version.
#   
#   This file is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
#   License for more details.
#   
#   You should have received a copy of the GNU Affero General Public License
#   along with this file.  If not, see <http://www.gnu.org/licenses/>.
#   
#   }}}
# 
# subset_fd_output.awk - Extract a subset of points from file_dumper output.
# 
# Option vars, set with -v var=arg:
#  -v subset=input_* - REQUIRED.  This is a file_dumper point input file name.
# 
# std input : an output_camera* file from file_dumper.
#
# std output: A file_dumper output file containing the header fom the input,
#  and just the point sections listed in the subset file.

BEGIN {	
  getline < subset;		 # Read in the subset points.
  while ($0) {
    sections["section: "$0] = 1; # Remember selected section lines.
    $0="";			 # (getline doesn't clear $0 when it hits EOF.)
    getline < subset;
  }
  header = dumping = 1;		 # Start out by dumping the file header.
}

dumping { print }		 # Print selected lines.

/^+++/ {			 
  if ( selected ) print "";	 # After separator lines at end of selected section.
  dumping = selected = 0;	 # No output until next selected section.
}

/^section: / && sections[$0] {	 # Section line for a selected point.
  if ( !header ) print "+++";	 # Print the prefix separator and section line
  print;
  header = 0; selected = dumping = 1;
}
