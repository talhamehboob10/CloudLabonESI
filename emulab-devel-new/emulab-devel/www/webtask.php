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
#
class WebTask {
    var	$webtask;
    var $decoded = null;

    #
    # Constructor by lookup on unique ID
    #
    function WebTask($task_id) {
	$safe_id = addslashes($task_id);

	$query_result =
	    DBQueryWarn("select * from web_tasks ".
			"where task_id='$safe_id'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->webtask = NULL;
	    return;
	}
	$this->webtask = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->webtask);
    }

    # Lookup by imageid
    function Lookup($id) {
	$foo = new WebTask($id);

	if (! $foo->IsValid())
	    return null;

	return $foo;
    }

    # Lookup by object.
    function LookupByObject($uuid) {
	$query_result =
	    DBQueryWarn("select task_id from web_tasks ".
			"where object_uuid='$uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	$idx = $row['task_id'];
	
	return WebTask::Lookup($idx);
    }

    #
    # Create an anonymous web task (not associated with an object). This
    # is useful when using a webtask to create a new object via a backend
    # script.
    #
    function CreateAnonymous() {
        $task_id = WebTask::GenerateID();

        $query_result = 
            DBQueryWarn("insert into web_tasks set task_id='$task_id', ".
                        "  created=now(), object_uuid='$task_id'");
        
	if (!$query_result) {
            return null;
        }
        return WebTask::Lookup($task_id);
    }
    #
    # And a normal webtask.
    #
    function Create($uuid) {
        $task_id = WebTask::GenerateID();

        $query_result = 
            DBQueryWarn("insert into web_tasks set task_id='$task_id', ".
                        "  created=now(), object_uuid='$uuid'");
        
	if (!$query_result) {
            return null;
        }
        return WebTask::Lookup($task_id);
    }

    function Refresh() {
	if (! $this->IsValid())
	    return -1;
        $task_id = $this->task_id();

	$query_result =
	    DBQueryWarn("select * from web_tasks ".
			"where task_id='$task_id'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->webtask = NULL;
	    return -1;
	}
	$this->webtask = mysql_fetch_array($query_result);
        $this->decoded = null;
        return 0;
    }

    # We delete from the web interface.
    function Delete() {
	$task_id = $this->task_id();
        if (!DBQueryWarn("delete from web_tasks where task_id='$task_id'")) {
            return -1;
        }
	return 0;
    }

    # Reset to clean state.
    function Reset() {
        $task_id = $this->task_id();

        DBQueryFatal("update web_tasks set ".
                     " exited=null,process_id=0,exitcode=0,task_data=''".
                     "where task_id='$task_id'");

        return $this->Refresh();
    }

    # Store.
    function Store() {
        if (!$this->decoded) {
            return;
        }
        $task_id = $this->task_id();
        $task_data = json_encode($this->decoded);
        $safe_data = addslashes($task_data);

        DBQueryFatal("update web_tasks set ".
                     " task_data='$safe_data' ".
                     "where task_id='$task_id'");

        return $this->Refresh();
    }

    # accessors
    function field($name) {
	return (is_null($this->webtask) ? -1 : $this->webtask[$name]);
    }
    function task_id()		{ return $this->field("task_id"); }
    function created()		{ return $this->field("created"); }
    function modified()		{ return $this->field("modified"); }
    function process_id()	{ return $this->field("process_id"); }
    function object_uuid()	{ return $this->field("object_uuid"); }
    function exitcode()		{ return $this->field("exitcode"); }
    function exited()		{ return $this->field("exited"); }
    function task_data()	{ return $this->field("task_data"); }

    function TaskDataObject() {
	if ($this->task_data()) {
	    return json_decode($this->task_data(), false);
	}
	else {
	    return new stdClass();
	}
    }

    #
    # Return the task data as a real object intead of JSON
    #
    function TaskData() {
	if ($this->task_data()) {
	    return json_decode($this->task_data(), true);
	}
	else {
	    return array();
	}
    }
    # Return a specific value from the data.
    function TaskValue($key) {
	if ($this->task_data()) {
	    if (! $this->decoded) {
		$this->decoded = json_decode($this->task_data(), true);
	    }
	    if (array_key_exists($key, $this->decoded)) {
		return $this->decoded[$key];
	    }
	}
	return null;
    }
    function SetTaskValue($key, $value) {
        if (! $this->decoded) {
            if ($this->task_data()) {
		$this->decoded = json_decode($this->task_data(), true);
	    }
            else {
                $this->decoded = array();
            }
        }
        $this->decoded[$key] = $value;
	return $value;
    }

    function ValidTaskID($id) {
	if (preg_match("/^[-\w]+$/", $id)) {
	    return TRUE;
	}
	return FALSE;
    }

    function GenerateID() {
	return md5(uniqid(rand(),1));
    }

    # convenience function
    function output($value = null) {
        if ($value) {
            return $this->SetTaskValue("output", $value);
        }
        return $this->TaskValue("output");
    }
    function code($value = null) {
        if ($value) {
            return $this->SetTaskValue("code", $value);
        }
        return $this->TaskValue("code");
    }
}
?>
