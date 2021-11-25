#! /usr/bin/gawk -f
#
# Copyright (c) 2000-2006 University of Utah and the Flux Group.
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
# form-input.gawk - Scan a lot of spidered HTML files, extracting forms.
#
# Output format:
# - Spidered filename lines are from wget: ./host.path/page.php?getargs
# - Files may have multiple form sections, terminated by blank lines.
# - Each form section has one <form line, possibly many <input lines.
# - Attributes of <input tags are canonicalized and reordered, e.g.:
#     <input type="..." name="..." value=... ...>
# - <textarea tags become <input type="textarea" for uniformity.
# - <select tags become <input type="select" for uniformity.

# Beginning of file.
FNR == 1 {
    end_form();			# In case we missed a </form>.
    form=0;

    # Exempt forms in twik and flyspray files.  Can't get to the DB.
    if ( FILENAME ~ "/(twiki|flyspray)/" ) nextfile;

    print FILENAME;
}

{ gsub("<textarea", "<input type=textarea"); }
{ gsub("<select", "<input type=select"); }

# Rarely, a mix of <input and <form elements on a single line within a form.
form && /<input.*<form/ {
    while ( $0 ~ "<input.*<form" || $0 ~ "</form.*<form" ) {
	if ( index($0, "<input") < index($0, "<form") ) {
	##print "  INPUT/FORM '" $0 "'";
	    if ( index($0, "</form") < index($0, "<input") ) end_form();
	    do_input();
	}
	else {
	##print "  FORM/INPUT '" $0 "'";
	    if ( index($0, "</form") < index($0, "<form") ) end_form();
	    do_form();
	}
    }
}

# Start of form.
/<form/ && ! form { do_form(); }
function do_form() {
    # Handle the searchbox form that's on every page, elsewhere.
    if ( $0 ~ "action=[^ ]*\\/search.php3" ) return
    form=1;

    $0 = substr($0, index($0, "<form") ); # Put <form at beginning of line.
    while ( $0 !~ ">" ) {	# Multi-line <form elements.
	sub("[ \t]*$", " ");	# Single space at end of line.
	getline ln;
	sub("^[ \t]*", "", ln); # No space on start of new line.
	$0 = $0 ln;
    }

    # Skip Javascript "on...=..." and "style=...".
    sub("[ \t]on[a-zA-Z]+=('[^']+'|\"[^\"]+\")", "", $0 );
    sub("[ \t]style=('[^']+'|\"[^\"]+\")", "", $0 );

    end = index($0, ">");
    rest = substr($0, end+1);	# Save rest of line.
    $0 = substr($0, 1, end);	# Leave only <form ... > on the line.
    ##print "  FORM ONLY '" $0 "'\n  REST '" rest "'";

    # Canonicalize.
    # Convert single-quoted action and method values to double quotes.
    $0 = gensub("(method|action)='([^']+)'", "\\1=\"\\2\"", "g");
    # Quote unquoted values.
    $0 = gensub("(method|action)=([^'\"][^ >]+)", "\\1=\"\\2\"", "g");

    print;

    # May have more elements on the same line.
    $0 = rest;
}

form && /<input/ { while ( $0 ~ "<input" ) do_input(); }
# May be multiple <input elements on a line.
function do_input() {

    ##print "  INPUT '" $0 "'";
    $0 = substr($0, index($0, "<input")); # Put <input at beginning of line.
    sub("[ \t]on[a-zA-Z]+=.*['\"]", "", $0 ); # Skip Javascript.

    # Collect multi-line <input elements.
    while ( $0 !~ ">" || 
	    # <select blocks need a value from an <option.
	    $0 ~ "type=select" && $0 !~ "value=" ) {
	sub("[ \t]*$", " ");	# Single space at end of line.
	getline ln;
	sub("[ \t]on[a-zA-Z]+=.*['\"]", "", ln ); # Skip Javascript.

	sub("^[ \t]*", "", ln); # No space on start of new line.
	$0 = $0 ln;
    }

    # <select blocks need a value from an <option.
    $0 = gensub("(<input type=select.*name=[^ >]+).*(value=[^ >]+).*>",
		"\\1 \\2>", 1);

    ##print "    FULL INPUT '" $0 "'" ;
    
    end = index($0, ">");
    rest = substr($0, end+1);	# Save rest of line.
    $0 = substr($0, 1, end);	# Leave only <input ... > on the line.
    ##print "    INPUT ONLY '" $0 "'\n    REST '" rest "'";

    # Canonicalize.
    sub("type=readonly", "type=text"); # There is no readonly type, text is default.
    # Convert single-quoted type and name values to double quotes.
    $0 = gensub("(name|type)='([^']+)'", "\\1=\"\\2\"", "g");
    # Quote unquoted values.
    $0 = gensub("(name|type|value)=([^'\"][^ >]*)", "\\1=\"\\2\"", "g");
    # Reorder: <input type=.* name=.* value=.* .*>
    $0 = gensub("<input (.*)value=('[^']+'|\"[^\"]+\")", "<input value=\\2 \\1", 1);
    $0 = gensub("<input (.*)name=('[^']+'|\"[^\"]+\")", "<input name=\\2 \\1", 1);
    $0 = gensub("<input (.*)type=('[^']+'|\"[^\"]+\")", "<input type=\\2 \\1", 1);
    gsub("  *", " ");		# Collapse extra spaces.

    # Filter out Delay Control entries.
    if ( $0 !~ "DC::" )
	print;

    # May have more elements on the same line.
    $0 = rest;
}

/<\/form/ {			# End of form.
    end_form();
}

function end_form() {
    # Output a blank-line terminator after each form section.
    if ( form ) {
	match($0, "</form>");
	rest = substr($0, RSTART+RLENGTH); # Save rest of line.
	##print "    FORM END '" $0 "'\n    REST '" rest "'";
	$0 = rest; 
	printf "\n";
    }
    form = 0;
}

{next}
