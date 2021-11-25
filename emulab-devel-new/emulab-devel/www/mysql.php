<?php
#
# Copyright (c) 2019 University of Utah and the Flux Group.
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
# Map mysql_* calls to mysqli_* calls
#

#
# New interface returns an object instead of a linkid. Ick.
#
$_mysqli_links   = array();
$_mysqli_nextid  = 0;

function _mysqli_addlink($link)
{
    global $_mysqli_nextid, $_mysqli_links;
    $linkid = $_mysqli_nextid;
    $_mysqli_nextid++;
    
    $_mysqli_links[$linkid] = $link;
    return $linkid;

}
function _mysqli_link($linkid)
{
    global $_mysqli_links;

    return $_mysqli_links[$linkid];
}

function mysql_connect($host, $user, $pswd = "none",
                       $newlink = FALSE, $flags = 0)
{
    $link = mysqli_connect($host, $user, $pswd);
    if (!$link) {
        return false;
    }
    $linkid = _mysqli_addlink($link);
    return $linkid;
}

function mysql_select_db($dbname, $linkid = NULL)
{
    if (is_null($linkid)) {
	TBERROR("mysql_select_db: must specify linkid!", 1);
    }
    $link = _mysqli_link($linkid);
    return mysqli_select_db($link, $dbname);
}

function mysql_query($query, $linkid = NULL)
{
    $link = is_null($linkid) ? _mysqli_link(0) : _mysqli_link($linkid);
    return mysqli_query($link, $query);
}

function mysql_num_rows($result)
{
    return mysqli_num_rows($result);
}

function mysql_fetch_array($result, $rtype = MYSQLI_BOTH)
{
    return mysqli_fetch_array($result, $rtype);
}

function mysql_fetch_assoc($result)
{
    return mysqli_fetch_assoc($result);
}

function mysql_fetch_row($result)
{
    return mysqli_fetch_row($result);
}

function mysql_escape_string($stuff)
{
    $link = _mysqli_link(0);

    # XXX is this really the same? There is some doubt:
    # https://www.php.net/manual/en/function.mysqli-escape-string.php
    return mysqli_escape_string($link, $stuff);
}

function mysql_insert_id($linkid = NULL)
{
    $link = is_null($linkid) ? _mysqli_link(0) : _mysqli_link($linkid);
    return mysqli_insert_id($link);
}

function mysql_data_seek($result, $rownum)
{
    return mysqli_data_seek($result, $rownum);
}

function mysql_error($linkid)
{
    $link = is_null($linkid) ? _mysqli_link(0) : _mysqli_link($linkid);
    return mysqli_error($link);
}

function mysql_errno($linkid)
{
    $link = is_null($linkid) ? _mysqli_link(0) : _mysqli_link($linkid);
    return mysqli_errno($link);
}

function mysql_affected_rows($linkid = NULL)
{
    if (is_null($linkid)) {
	TBERROR("mysql_affected_rows: must specify linkid!", 1);
    }
    $link = _mysqli_link($linkid);
    
    return mysqli_affected_rows($link);
}

function mysql_real_escape_string($stuff, $linkid = NULL)
{
    if (is_null($linkid)) {
	TBERROR("mysql_real_escape_string: must specify linkid!", 1);
    }
    $link = _mysqli_link($linkid);
    
    return mysqli_real_escape_string($link, $stuff);
}

?>
