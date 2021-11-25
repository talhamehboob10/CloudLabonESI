<?php
#
# Copyright (c) 2000-2011 University of Utah and the Flux Group.
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

#
# Standard Testbed Header is sent below.
#
$optargs = OptionalPageArguments("show_archived",   PAGEARG_BOOLEAN,
				 "archive",         PAGEARG_STRING,
				 "single",          PAGEARG_BOOLEAN,
				 "restore",         PAGEARG_STRING,
				 "delete" ,         PAGEARG_STRING,
				 "delete_confirm",  PAGEARG_STRING,
				 "add",             PAGEARG_STRING,
				 "addnew",          PAGEARG_STRING,
				 "edit",            PAGEARG_STRING,
				 "subject",         PAGEARG_STRING,
				 "author",          PAGEARG_STRING,
				 "author_idx",      PAGEARG_INTEGER,
				 "bodyfile",        PAGEARG_STRING,
				 "body",            PAGEARG_ANYTHING,
				 "msgid",           PAGEARG_STRING,
				 "date",            PAGEARG_STRING,
				 "protogeni",       PAGEARG_BOOLEAN);

#
# If user is an admin, present edit options.
#
$this_user = CheckLogin($check_status);

if (! isset($show_archived)) {
    $show_archived = 0;
}
if (! isset($protogeni) || !$protogeni) {
    $protogeni = 0;
}
else {
    $protogeni = 1;
}
$show_archived = ($show_archived ? 1 : 0);
$db_table = "webnews";

$view = NULL;
if ($protogeni) {
    $view['hide_banner']  = 1;
    $view['hide_sidebar'] = 1;
    $view['hide_title']   = 1;
    $view['hide_versioninfo'] = 1;
    $view['show_protogeni']   = 1;
    $db_table = "webnews_protogeni";
}

if ($this_user) {
    $uid     = $this_user->uid();
    $uid_idx = $this_user->uid_idx();
    $isadmin = ISADMIN();
}
else {
    $isadmin = 0;
}

if ($isadmin) {
    if (isset($delete_confirm)) {
	$safeid = addslashes($delete_confirm);

	DBQueryFatal("DELETE FROM $db_table WHERE msgid='$safeid'");

	header("Location: news.php3?show_archived=$show_archived".
	       "&protogeni=$protogeni");
	return;
    }
    if (isset($archive)) {
	$safeid = addslashes($archive);

	DBQueryFatal("update $db_table set archived=1,archived_date=now() ".
		     "where msgid='$safeid'");

	header("Location: news.php3?show_archived=$show_archived".
	       "&protogeni=$protogeni");
	return;
    }
    if (isset($restore)) {
	$safeid = addslashes($restore);

	DBQueryFatal("update $db_table set archived=0,archived_date=NULL ".
		     "where msgid='$safeid'");

	header("Location: news.php3?show_archived=$show_archived".
	       "&protogeni=$protogeni");
	return;
    }

    PAGEHEADER("News", $view,
	       ($protogeni ? $RSS_HEADER_PGENINEWS : $RSS_HEADER_NEWS));
    
    if (isset($delete)) {
	$delete = addslashes($delete);
	echo "<center>";
	echo "<h2>Are you sure you want to delete message #$delete?</h2>";
	echo "<form action='news.php3' method='post'>\n";
	echo "<input type='hidden' name=protogeni value='$protogeni'>";
	echo "<button name='delete_confirm' value='$delete'>Yes</button>\n";
	echo "&nbsp;&nbsp;";
	echo "<button name='nothin'>No</button>\n";
	echo "</form>";
	echo "</center>";
	PAGEFOOTER();
	die("");
    }

    if (isset($add)) {
	if (!isset($subject) || !strcmp($subject,"") ) {
	    # USERERROR("No subject!",1);
	    $subject = "Testbed News";
	} 
	if (!isset($author_idx) || !strcmp($author_idx,"") ) {
	    USERERROR("No author!",1);
	} 

	if (isset($bodyfile) && 
	    strcmp($bodyfile,"") &&
	    strcmp($bodyfile,"none")) {
	    $bodyfile = addslashes($bodyfile);
	    $handle = @fopen($bodyfile,"r");
	    if ($handle) {
		$body = fread($handle, filesize($bodyfile));
		fclose($handle);
	    } else {
		USERERROR("Couldn't open uploaded file!",1);
	    }
	}

	if (!isset($body) || !strcmp($body,"")) {
	    USERERROR("No message body!",1);
	} 

	$subject    = addslashes($subject);
	$author     = addslashes($author);
	$author_idx = addslashes($author_idx);
	$body       = addslashes($body);

	if (isset($msgid)) {
	    $msgid = addslashes($msgid);
	    if (!isset($date) || !strcmp($date,"") ) {
		USERERROR("No date!",1);
	    }
	    $date = addslashes($date);
	    DBQueryFatal("UPDATE $db_table SET ".
			 "subject='$subject', ".
			 "author='$author', ".
			 "author_idx='$author_idx', ".
			 "date='$date', ".
			 "body='$body' ".			
			 "WHERE msgid='$msgid'");
	    echo "<h3>Updated message with subject '$subject'.</h3><br />";
	} else {	    
	    DBQueryFatal("INSERT INTO $db_table ".
			 "  (subject, date, author, author_idx, body) ".
			 "VALUES ('$subject', NOW(), ".
			 "        '$author', '$author_idx', '$body')");
	    echo "<h3>Posted message with subject '$subject'.</h3><br />";
	}
	flush();
	sleep(1);
	PAGEREPLACE("news.php3?protogeni=$protogeni");
	PAGEFOOTER();
	die("");
    }

    if (isset($edit)) {
	$edit = addslashes($edit);
	$query_result = 
	    DBQueryFatal("SELECT subject, author, author_idx, body,msgid,date ".
			 "FROM $db_table ".
		         "WHERE msgid='$edit'" );

	if (!mysql_num_rows($query_result)) {
	    USERERROR("No message with msgid '$edit'!",1);
	} 

	$row = mysql_fetch_array($query_result);
	$subject = htmlspecialchars($row["subject"], ENT_QUOTES);
	$date    = htmlspecialchars($row["date"],    ENT_QUOTES);
	$author  = htmlspecialchars($row["author"],  ENT_QUOTES);
	$author_idx = htmlspecialchars($row["author_idx"],  ENT_QUOTES);
	$body    = htmlspecialchars($row["body"],    ENT_QUOTES);
	$msgid   = htmlspecialchars($row["msgid"],   ENT_QUOTES);
    }

    if (isset($edit) || isset($addnew)) {	
	if (isset($addnew)) {
	    $author = $uid;
	    $author_idx = $uid_idx;
	    echo "<h3>Add new message:</h3>\n";
	} else {
	    echo "<h3>Edit message:</h3>\n";
	}

	echo "<form action='news.php3' ".
             "enctype='multipart/form-data' ".
             "method='post'>\n";

	if (isset($msgid)) {
	    echo "<input type='hidden' name='msgid' value='$msgid' />";
	}
	echo "<input type='hidden' name=protogeni value='$protogeni'>";
	echo "<input type='hidden' name=author_idx value='$author_idx'>";
	
	if (!isset($subject)) {
	    $subject = "";
	}
	
	echo "<b>Subject:</b><br />".
	     "<input type='text' name='subject' size='50' value='$subject'>".
	     "</input><br /><br />\n";
	if (isset($date)) {
	    echo "<b>Date:</b><br />".
	         "<input type='text' name='date' size='50' value='$date'>".
		 "</input><br /><br />\n";
	}
	echo "<b>Posted by:</b><br />". 
	     "<input type='text' name='author' size='50' value='$author'>".
	     "</input><br /><br />\n". 
	     "<b>Body (HTML):</b><br />".
       	     "<textarea cols='60' rows='25' name='body'>";

	if (isset($addnew)) {
	    echo "&lt;p&gt;\n&lt;!-- ".
		 "place message between 'p' elements ".
		 "--&gt;\n\n&lt;/p&gt;";
	} else {
	    echo $body;
	}
	echo "</textarea><br /><br />";
	echo "<b>or Upload Body File:</b><br />";
	echo "<input type='file' name='bodyfile' size='50'>";
	echo "</input>";
	echo "<br /><br />\n";
	if (isset($addnew)) {
	    echo "<button name='add'>Add</button>\n";
	} else {
	    echo "<button name='add'>Edit</button>\n";
	}
	echo "&nbsp;&nbsp;<button name='nothin'>Cancel</button>\n";
	echo "</form>";
	PAGEFOOTER();
	die("");
    } else {
	echo "<form action='news.php3' method='post'>\n";
	echo "<input type='hidden' name=protogeni value='$protogeni'>";
	echo "<button name='addnew'>Add a new message</button>\n";
	echo "</form>";
    }
}
else {
    PAGEHEADER("News", $view,
	       ($protogeni ? $RSS_HEADER_PGENINEWS : $RSS_HEADER_NEWS));
}

?>
<table align=center class=stealth border=0>
<tr><td class=stealth align=center><h1>News</h1></td></tr>
<?php
if ($TBMAINSITE && !$ISALTDOMAIN && ! (isset($single) && $single) && !$protogeni) {
    echo "<tr><td class=stealth align=center>
                  <a href = 'doc/changelog.php3'>
                     (Changelog/Technical Details)</a></td></tr>\n";
}
if (!isset($single) || !$single) {
    echo "<tr><td class=stealth align=center>
                  <a href = '$TBDOCBASE/news-rss.php3?protogeni=$protogeni'>
                  <img src='rss.png' width=27 height=14 border=0>
                  RSS Feed
                  </a></td></tr>";
}
echo "</table>
      <br />\n";

# Allow admin caller to flip the archive bit. 
$show_archive_clause = "archived=0";
if ($isadmin) {
    if ($show_archived) {
	$show_archive_clause = "1";
	echo "<a href='news.php3?show_archived=0&protogeni=$protogeni'>".
	    "Hide Archived Messages</a>\n";
    }
    else {
	echo "<a href='news.php3?show_archived=1&protogeni=$protogeni'>".
	    "Show Archived Messages</a>\n";
    }
}

# Allow users to view a single message
$which_msgid_clause = "1"; # MySQL will optimize this out
if (isset($single)) {
    $single = addslashes($single);    
    $which_msgid_clause = "msgid='$single'";
    $show_archive_clause = 1;
}

$query_result=
    DBQueryFatal("SELECT subject, author, author_idx, body, msgid, ".
		 "DATE_FORMAT(date,'%W, %M %e, %Y, %l:%i%p') as prettydate, ".
		 "(TO_DAYS(NOW()) - TO_DAYS(date)) as age, ".
		 "archived, ".
		 "DATE_FORMAT(archived_date,'%W, %M %e, %Y, %l:%i%p') as ".
		 "  archived_date ".
		 "FROM $db_table ".
                 "WHERE " .
                 "$show_archive_clause " .
                 "AND " .
		 "$which_msgid_clause ".
		 "ORDER BY date DESC" );

if (!mysql_num_rows($query_result)) {
    echo "<h4>No messages.</h4>";
} else {

    if ($isadmin) {
	echo "<form action='news.php3' method='post'>";
	echo "<input type='hidden' name=show_archived value='$show_archived'>";
    }
    echo "<input type='hidden' name=protogeni value='$protogeni'>";

    while ($row = mysql_fetch_array($query_result)) {
	$subject = $row["subject"];
	$date    = $row["prettydate"];
	$author  = $row["author"];
	$author_idx= $row["author_idx"];
	$body    = $row["body"];
	$msgid   = $row["msgid"];
	$age     = $row["age"];
	$archived = $row["archived"];
	$archived_date = $row["archived_date"];

	echo "<a name=\"$msgid\"></a>\n";
	echo "<table class='nogrid' 
                     cellpadding=0 
                     cellspacing=0 
                     border=0 width='100%'>";

	echo "<tr><th style='padding: 4px;'><font size=+1>$subject</font>";

	if ($age < 7) {
	    echo "&nbsp;<img border=0 src='new.gif' />";
	}

	echo "</th></tr>\n".
	     "<tr><td style='padding: 4px; padding-top: 2px;'><font size=-1>";
	echo "<b>$date</b>; posted by <b>$author ($author_idx)</b>.";
	if ($archived) {
	    echo "<font color=red> Archived on <b>$archived_date</b></font>.\n";
	}

	if ($isadmin) {
	    echo " (Message <b>#$msgid</b>)";
	}

	echo "</font></td></tr>";

	if ($isadmin) {
	    echo "<tr><td>";
	    echo "<button name='edit' value='$msgid'>".
		 "Edit</button>".
	         "<button name='delete' value='$msgid'>".
		 "Delete</button>";
	    if ($archived)
		echo "<button name='restore' value='$msgid'>".
		     "Restore</button>";
	    else
		echo "<button name='archive' value='$msgid'>".
		     "Archive</button>";
	    echo "</td></tr>\n";
	}

	echo "<tr><td style='padding: 4px; padding-top: 2px;'>".
	     "<div style='background-color: #FFFFF2; ".
	     "border: 1px solid #AAAAAA; ".
      	     "padding: 6px'>".
	     $body.
	     "</div>".
	     "</td></tr>\n";

	echo "<!-- ' \" > IF YOU CAN READ THIS, YOU FORGOT AN ENDQUOTE -->\n";

	echo "</table><br />";
    } 

    if ($isadmin) { 
	echo "</form>\n"; 
    }
}		  

PAGEFOOTER();
?>

