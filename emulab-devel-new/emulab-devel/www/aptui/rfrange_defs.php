<?php
#
# Copyright (c) 2006-2020 University of Utah and the Flux Group.
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
include_once("resgroup_defs.php");

#
# RF Range support. This class is just a wrapper on a single range (row)
# from one of the rfrange tables.
#
class RFRange
{
    var $rfrange;
        
    #
    # Constructor.
    #
    function RFRange($row) {
        $this->rfrange = $row;
    }
    # accessors
    function field($name) {
	return (is_null($this->rfrange) ? -1 : $this->rfrange[$name]);
    }
    function idx()	    { return $this->field('idx'); }
    function pid()	    { return $this->field('pid'); }
    function pid_idx()      { return $this->field('pid_idx'); }
    function range_id()     { return $this->field('range_id'); }
    function freq_low()     { return $this->field('freq_low'); }
    function freq_high()    { return $this->field('freq_high'); }
    function disabled()     { return $this->field('disabled'); }
    function rawdata()      { return $this->rfrange; }
}

class ProjectRFRanges
{
    var $ranges;
    var $project;
    
    #
    # Constructor
    #
    function ProjectRFRanges($project) {
        $pid_idx = $project->pid_idx();

        $query_result =
            DBQueryFatal("select p.*,n.freq_low as named_low,".
                         "       n.freq_high as named_high ".
                         "  from apt_project_rfranges as p ".
                         "left join apt_named_rfranges as n on ".
                         "  p.range_id is not null and n.range_id=p.range_id ".
                         "where pid_idx='$pid_idx' and disabled=0 and ".
                         # Ignore named ranges that have no definition
                         "      not (p.range_id is not null and ".
                         "           n.range_id is null)");

        $pranges = array();
	while ($row = mysql_fetch_array($query_result)) {
            #
            # If this was an indirect (named) range, copy the frequencies over
            #
            if ($row['range_id'] && $row['named_low']) {
                $row['freq_low']  = $row['named_low'];
                $row['freq_high'] = $row['named_high'];
            }
            $range = new RFRange($row);
            $pranges[$range->idx()] = $range;
        }
        $this->project = $project;
	$this->ranges  = $pranges;
    }
    function Project()        { return $this->project; }
    function Count()          { return count($this->ranges); }
    function Ranges()         { return $this->ranges; }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->ranges);
    }
    
    function Lookup($project) {
	$foo = new ProjectRFRanges($project);
        if (!is_null($foo->ranges)) {
            return $foo;
        }
        return null;
    }
}

class GlobalRFRanges
{
    var $ranges;
    
    #
    # Constructor
    #
    function GlobalRFRanges() {
        $query_result =
            DBQueryFatal("select p.*,n.freq_low as named_low,".
                         "       n.freq_high as named_high ".
                         "  from apt_global_rfranges as p ".
                         "left join apt_named_rfranges as n on ".
                         "  p.range_id is not null and n.range_id=p.range_id ".
                         "where disabled=0 and ".
                         # Ignore named ranges that have no definition
                         "      not (p.range_id is not null and ".
                         "           n.range_id is null)");

        $ranges = array();
	while ($row = mysql_fetch_array($query_result)) {
            #
            # If this was an indirect (named) range, copy the frequencies over
            #
            if ($row['range_id'] && $row['named_low']) {
                $row['freq_low']  = $row['named_low'];
                $row['freq_high'] = $row['named_high'];
            }
            $range = new RFRange($row);
            $ranges[$range->idx()] = $range;
        }
	$this->ranges = $ranges;
    }
    function Count()          { return count($this->ranges); }
    function Ranges()         { return $this->ranges; }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->ranges);
    }
    
    function Lookup() {
	$foo = new GlobalRFRanges();
        if (!is_null($foo->ranges)) {
            return $foo;
        }
        return null;
    }
}

?>
