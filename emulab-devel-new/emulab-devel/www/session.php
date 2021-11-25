<?php
#
# Copyright (c) 2006-2021 University of Utah and the Flux Group.
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
# Store PHP sessions in out DB. This came off the php manual page,
# in one of the comments. There is some oddity below for $_SESSION,
# which will go away when we are running php 5.4.
#
# I am not really sure how we will be usng sessions yet, for now
# just experimenting with it.
#
class SessionSaveHandler {
    // session-lifetime 
    var $lifeTime; 
	
    public function __construct() {
	global $TBAUTHDOMAIN;

	# Enforce secure cookies, this domain only.
	session_set_cookie_params(600, "/", $TBAUTHDOMAIN, 1);
	
        session_set_save_handler(
            array($this, "open"),
            array($this, "close"),
            array($this, "read"),
            array($this, "write"),
            array($this, "destroy"),
            array($this, "gc")
        );
        register_shutdown_function('session_write_close');
    }

    function ValidSessionID($id) {
	if (preg_match("/^[-\w]+$/", $id)) {
	    return TRUE;
	}
	return FALSE;
    }

    // Note that we have a permanent connection to the database, so
    // we do not need to do open/close on it.
    public function open($savePath, $sessionName) {
       // get session-lifetime 
       $this->lifeTime = ini_get("session.gc_maxlifetime");
       return true; 
    }

    public function close() {
	$this->gc($this->lifeTime);
        return true;
    }

    public function read($id) {
	if (! $this->ValidSessionID($id)) {
	    return "";
	}

	$query_result =
	    DBQueryWarn("select session_data from web_sessions ".
			"where session_id='$id' and ".
			"      session_expires>now()");
	if (! ($query_result && mysql_num_rows($query_result))) {
	    return "";
	}
	$row  = mysql_fetch_array($query_result);
	$foo  = json_decode($row["session_data"]);

	foreach ($foo AS $key => $value) {
	    $_SESSION[$key] = $value;
	}
	return "";
    }

    public function write($id, $data) {
	if (! $this->ValidSessionID($id)) {
	    return "";
	}
        
        // new session-expire-time 
        $newExp = time() + $this->lifeTime;

	// Convert to JSON, but need to unserialize the data first.
	// We want the backend perl code to be able to use it.
	$safe_data = addslashes(json_encode($_SESSION));

        // is a session with this id in the database?
	$query_result =
		DBQueryFatal("select * FROM web_sessions ".
			     "where session_id = '$id'");
	
        if (mysql_num_rows($query_result)) {
            DBQueryFatal("update web_sessions set ".
                         "       session_expires=FROM_UNIXTIME($newExp), ".
                         "       session_data='$safe_data' ".
                         "where session_id='$id'");
        } 
        else { 
            // New session.
            DBQueryFatal("replace into web_sessions set ".
                         " session_id='$id', ".
                         "  session_expires=FROM_UNIXTIME($newExp), ".
                         " session_data='$safe_data'");
        }
        return true;
    } 

    public function destroy($id) {
	if (! $this->ValidSessionID($id)) {
	    return false;
	}
	$query_result =
	    DBQueryFatal("delete from web_sessions ".
                         "where session_id='$id'");
        return true;
    }

    public function gc($maxlifetime) {
        // delete old sessions
	DBQueryWarn("delete from web_sessions where session_expires<now()");
	
        // return affected rows 
        return DBAffectedRows();
    }
}
# Create once and we are done.
new SessionSaveHandler();
?>
