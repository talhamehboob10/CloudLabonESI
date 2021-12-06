<?php
#
# Copyright (c) 2000-2008 University of Utah and the Flux Group.
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
include("defs.php3");

# Page arguments.
$optargs = OptionalPageArguments("idx",       PAGEARG_INTEGER,
				 "xref_tag",  PAGEARG_STRING);

if (isset($xref_tag) && $xref_tag != "") {
    if (! preg_match("/^[-\w]+$/", $xref_tag)) {
	PAGEARGERROR("Invalid characters in $xref_tag");
    }
    $query_result =
	DBQueryFatal("select * from knowledge_base_entries ".
		     "where xref_tag='$xref_tag'");
    if (! mysql_num_rows($query_result)) {
	USERERROR("No such knowledge_base entry: $xref_tag", 1, 
		  HTTP_404_NOT_FOUND);
    }
    $row = mysql_fetch_array($query_result);
    $idx = $row['idx'];
}
if (isset($idx)) {
    header("Location: $WIKIDOCURL/kb${idx}", TRUE, 301);
}
else {
    header("Location: $WIKIDOCURL/KnowledgeBase", TRUE, 301);
}    

?>
