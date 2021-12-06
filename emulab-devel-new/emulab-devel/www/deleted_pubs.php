<?php
#
# Copyright (c) 2007 University of Utah and the Flux Group.
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
include("pub_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid_idx   = $this_user->uid_idx();
$isadmin   = ISADMIN();
$optargs   = OptionalPageArguments("showdeleted", PAGEARG_BOOLEAN);

PAGEHEADER("Deleted Publications");
?>

<p>To undelete a publication simply edit it again and unclick "Mark As Deleted"</p>

<?php

$where_clause = '';
$deleted_clause = '`deleted`';

if ($isadmin) {
  $where_clause = '1';
} else {
  $where_clause = "(`owner` = $uid_idx or `last_edit_by` = $uid_idx)";
}

$query_result = GetPubs($where_clause, $deleted_clause);
echo MakeBibList($this_user, $isadmin, $query_result);

PAGEFOOTER();
?>
