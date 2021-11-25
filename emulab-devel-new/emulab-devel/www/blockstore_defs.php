<?php
#
# Copyright (c) 2006-2014 University of Utah and the Flux Group.
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

class Blockstore
{
    var	$blockstore;

    #
    # Constructor by lookup on unique index.
    #
    function Blockstore($bsidx) {
	$safe_bsidx = addslashes($bsidx);

	$query_result =
	    DBQueryWarn("select * from blockstores ".
			"where bsidx='$safe_bsidx'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->blockstore = NULL;
	    return;
	}
	$this->blockstore = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->blockstore);
    }

    # Lookup by idx.
    function Lookup($bsidx) {
	$foo = new Blockstore($bsidx);

	if (! $foo->IsValid()) {
	    return null;
	}
	return $foo;
    }
    function LookupByLease($lease_idx) {
	$safe_idx = addslashes($lease_idx);
	
	$query_result =
	    DBQueryWarn("select bsidx from blockstores ".
			"where lease_idx='$safe_idx'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	$idx = $row['bsidx'];
	return Blockstore::Lookup($idx);
    }

    # accessors
    function field($name) {
	return (is_null($this->blockstore) ? -1 : $this->blockstore[$name]);
    }
    function bsidx()	     { return $this->field("bsidx"); }
    function node_id()       { return $this->field("node_id"); }
    function bs_id()	     { return $this->field("bs_id"); }
    function lease_idx()     { return $this->field("lease_idx"); }
    function type()	     { return $this->field("type"); }
    function role()          { return $this->field("role"); }
    function total_size()    { return $this->field("total_size"); }
    function exported()      { return $this->field("exported"); }
    function inception()     { return $this->field("inception"); }
}
?>
