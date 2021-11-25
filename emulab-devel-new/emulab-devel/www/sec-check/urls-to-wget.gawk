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
# urls-to-wget - Generate a wget script for a set of URL's.  The script
# assumes you are already logged in to Emulab, with a valid cookies.txt file.
#
#   Input is a set of page URL's including appended ?args, from sep-urls.gawk .
#   Interspersed action lines for setup and teardown may be prefixed by a
#   "!" or "-".  Further description of these action lines is below.
#
#   Output is a csh script containing "wget" statements to simulate submitting
#   HTML forms responses to drive the web site, interspersed with other state
#   query and control structure lines.  You may run the whole thing en masse,
#   or copy-paste individual commands into an interactive c-shell.
#
#   The GET arg method is default, including action= args for a POSTed form.
#   A POST argument string follows a "?post:" separator after the other ?args.
#
#   A -v COOKIES= awk arg gives the path to an alternate cookies.txt file.
#   A -v OUTDIR= awk arg gives the path to an alternate output directory.
#        (Otherwise, .html output files go into the current directory.)
#   A -v SRCDIR= awk arg gives the path to the script source directory.
#   A -v FAILFILE=failure.txt awk arg enables generation of conditional
#        probe inverse "-" action lines.  See below.
#
#   Action lines in the input stream may be prefixed by a "!" or a "-".
#   . "!" lines are just put into the output script among the wget lines.
#   .  "-" lines are *conditional undo* (inverse) actions for probing.
#
#   A conditional undo action line immediately follows a /filename line in the
#   file list.  It gives a corresponding "inverse action" to conditionally
#   undo the action of the probed page when its execution *DOESN'T FAIL*.
#   This is useful when the probe value given for a specific input field is
#   ignored.  For example, the first beginexp probe that succeeds uses up the
#   experiment name and blocks all other probes, so the experiment has to be
#   deleted again by the inverse action before the next probe is done.
#
#   Undo action "-" lines are wrapped in an "if" test in the generated script
#   so they only run if the preceding probe wget output file DOES NOT match
#   any grep pattern in failure.txt .  NOTE: This will only work reliably with
#   a completed failure.txt pattern file, i.e. there are no remaining
#   "UNKNOWN" entries in the analyze_output.txt file.
#
#   -wget lines will have the rest of the URL and option arguments filled in.
#   !sql or -sql lines are quoted queries that are passed to the inner boss tbdb.
#   !varnm=sql is a variant for getting stuff from the DB into a shell variable.
#   Other "-" or "!" action lines are put into the shell script verbatim.

BEGIN{
    verbose = "-S ";

    if ( COOKIES == "" ) COOKIES = "cookies.txt";
    ld_cookies	= "--load-cookies " COOKIES;

    outpath = OUTDIR;
    if ( length(outpath) && !match(outpath, "/$") ) outpath = outpath "/";

    # Don't get prerequisites (-p) so we can redirect the output page (-O).
    wget_args	= verbose "-k --keep-session-cookies --no-check-certificate"
}

# Action lines.
/^!/ || /^-/ {
    type = substr($0, 1, 1);
    if ( $0 ~ /^.wget / ) {
	process_url(last_prefix "/" $2); # Sets url, url_args, post_args.
        # Put the undo output into a separate subdir to avoid confusion.
	file_args = "-O " outpath "undo/" last_file;
	cmd = sprintf("wget %s %s %s%s %s", 
		      wget_args, ld_cookies, file_args, post_args, url_args);
    }
    else if ( $0 ~ /^.sql / ) \
	cmd = "echo " substr($0, 5) "| ssh $MYBOSS mysql tbdb";
    else if ( match($0, /^.(\w+)=sql (.*)/, s ) ) \
	cmd = "set " s[1] "=`echo " s[2] "| ssh $MYBOSS mysql tbdb | tail +2`" \
	      "; echo \"    " s[1] " = $" s[1] "\""; # Show the value too.
    else cmd = substr($0, 2);

    # Unconditional action lines start with an exclamation point.
    if ( type == "!" ) { print "    " cmd; }

    # Conditional "inverse action" lines start with a dash.
    # Only need to undo when probing, and only after lines containing a probe.
    # (The others are the real setup/teardown actions that allow continuing.)
    if ( type == "-" && length(FAILFILE) && last_url_was_probe ) {
	# Do the undo only when the thing being undone didn't fail.
	printf "if ( ! { grep -q -f %s/%s %s%s } ) then\n    %s\nendif\n",
	    SRCDIR, FAILFILE, outpath, last_file, cmd;
    }
    next;
}	

function process_url(u) {	# Sets url, url_args, post_args.
    # Encode a few characters as %escapes.
    gsub(" ", "%20");
    gsub("!", "%21");
    gsub("\"", "%22");
    gsub("#", "%23");
    gsub("\\$", "%24");
    ###gsub("/", "%2F");

    # Separate off a "?post:" argument string at the end of the URL.
    url = u;
    if ( post = match(url, "?post:") != 0 ) {
	post_args = sprintf(" --post-data \"%s\"", substr(url, RSTART+6));
	url = substr(url, 1, RSTART-1);
	##printf "URL %s, POST_ARGS %s\n", url, post_args;
    }
    else post_args = "";
    url_args = sprintf("\"%s\"", url);
}

# URL lines.
{
    process_url($0);

    # Parse the URL string into the host/filename, ignoring optional ?GETargs.
    # "?GETargs" could be in a simple pattern, except for slashes in the values.
    u = url; g = "";
    if ( q = index(u, "?") ) {
	u = substr(url, 1, q-1);
	g = substr(url, q+1);
    }
    match(u, "^(http.*)/(.*)", p);
    ##printf "URL: [1-host] %s, [2-file] %s, [3-GETargs] %s\n", p[1], p[2], g;

    # Make a local destination file, with a numeric suffix if needed.
    # (We may hit the same page many times when probing.)
    prefix = last_prefix = p[1];
    file = p[2];
    suffix = files[file];	# Null string initially, then 1, 2, 3...
    files[file]++;		# Increment for next time.
    if ( suffix ) file = file "." suffix;
    file = last_file = file ".html";	# html suffix for web browser.
    file_args = "-O " outpath file;

    print "wget", wget_args, ld_cookies, file_args post_args, url_args;

    # Remember whether this was a probing URL or an setup/teardown action URL.
    last_url_was_probe = index(post_args url_args, "**{")
}
