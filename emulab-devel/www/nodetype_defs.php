<?php
#
# Copyright (c) 2006-2019 University of Utah and the Flux Group.
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
include_once("osinfo_defs.php");

class NodeType
{
    var	$nodetype;

    #
    # Constructor by lookup on unique index.
    #
    function NodeType($nodetype) {
	$safe_nodetype = addslashes($nodetype);

	$query_result =
	    DBQueryWarn("select * from node_types ".
                        "where type='$safe_nodetype'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->nodetype = NULL;
	    return;
	}
	$this->nodetype = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->nodetype);
    }

    # Lookup by type
    function Lookup($nodetype) {
        if (!TBvalid_node_type($nodetype)) {
	    return null;
        }
	$foo = new NodeType($nodetype);

	if (! $foo->IsValid())
	    return null;

	return $foo;
    }
    # accessors
    function field($name) {
	return (is_null($this->nodetype) ? -1 : $this->nodetype[$name]);
    }
    function type()             { return $this->field("type"); }
    function typeclass()        { return $this->field("class"); }
    function architecture()     { return $this->field("architecture"); }
    function isvirtnode()       { return $this->field("isvirtnode"); }
    function isjailed()         { return $this->field("isjailed"); }
    function isdynamic()        { return $this->field("isdynamic"); }
    function isremotenode()     { return $this->field("isremotenode"); }
    function issubnode()        { return $this->field("issubnode"); }
    function isswitch()         { return $this->field("isswitch"); }

    #
    # Is there hardware info for the type
    #
    function HasHardwareInfo()
    {
        $nodetype = $this->type();

        $query_result =
            DBQueryFatal("select updated from node_type_hardware ".
                         "where type='$nodetype'");
        
        return mysql_num_rows($query_result);
    }
}

?>
