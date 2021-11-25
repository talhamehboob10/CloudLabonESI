# -*- mode: text; indent-tabs-mode: nil -*-
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
sec-check/README-howto.txt - Details of running and incremental development.

See README-concepts.txt for a description of the design and methods employed.
See README-FIRST.txt for a top-level outline.


 - General

   . Directories

     - Sec-check is run via configure/gmake in an Emulab obj-devel/www/sec-check
       directory.  Below, it is assumed you're cd'ed there.

     - Control files come from testbed/www/sec-check in the user's source tree.

     - Generated intermediate files and output are checked into source subdir
       testbed/www/sec-check/results, so they can be compared over time with CVS
       as things change.

     - These variables, relative to obj-devel/www/sec-check, are used below:
         set tws=../../../testbed/www/sec-check
         set twsr=$tws/results

   . Inner Emulab-in-Emulab experiment
   
     You need an inner Elab swapped in to do almost everything below.  This is
     documented in https://www.emulab.net/tutorial/elabinelab.php3 .

     There is a simple ElabInElab experiment ns file in $tws/vulnElab.ns .

     Change EinE_proj and EinE_exp in the $tws/GNUmakefile.in to match the
     Emulab project and experiment names you create.  Edit the email addresses to
     match your mailers.  Notice that two *REAL* email addresses are required.


 - High-level targets

   . all: src_forms spider forms_coverage input_coverage normal probe

     Do everything after activation.  Ya gotta activate below first!

         gmake all |& tee all.log

   . msgs: src_msg site_msg forms_msg input_msg analyze probes_msg
     Show all of the summaries.

         gmake msgs

     - I log a copy of the results to CVS once in a while:

           gmake msgs | egrep -v gmake | tee $twsr/msgs.log


 - Stages of operation (makefile targets)

   ----------------
   . src_forms: src_list src_msg

     Grep the sources for <form and make up a list of php form files.

         gmake src_forms
         gmake src_msg

     - Output goes in $twsr/src_{forms,files}.list, bare filenames and raw
       <form grep lines respectively.

     - gmake src_msg reports something like:

       ** Sources: 107 separate forms are on 89 code pages. **
       ** (See src_forms.list and src_files.list
       **  in ../../../testbed/www/sec-check/results .) **
       **

   ----------------
   . activate: activate.wget $(activate_tasks) analyze_activate

     Sets up the newly swapped-in ElabInElab site in the makefile to create
     "one of everything" (or sometimes two in different states), thus turning
     on as many forms as we can for spidering.

     - Don't forget to first log in to the inner Elab in a web browser and
       change your password in Edit Profile in the inner Elab to match the
       string given in the GNUmakefile.in as $(pswd).  

       The initial password is your outer Elab password, imported into the
       inner Elab.  There's no reason to put your real Elab password into the
       makefile!  Don't do it!

       For me, the URL of the inner Elab apache httpd server on "myboss" is
       https://myboss.vulnelab.testbed.emulab.net .

       Check that it's working:

           gmake login
           gmake admin

       Browse to the logins/*.html files to see the results.  I use Opera for
       this purpose, since it doesn't get upset with constant changes to the
       security certificates as the inner Elab is swapped in and out over
       time.  Firefox doesn't like the certificate changes.

       Login cookies go stale after a while.  Nothing will work until you have
       logged in again as admin.  You'll have to repeat this when that happens:

           gmake admin

     - Run activate:

           gmake activate |& tee activate.wget/activate.log

     - Output of activate actions goes into an activate.wget directory as
         *.html - Pages from wget.
         *.html.cmd - The wget command that was executed.
         *.html.log - The wget log for that command.

       The activate.wget directory gets moved aside to activate.wget.prev .
       If you want more context than that, move them to numbered versions.

     - analyze_activate applies the success/failure pattern files after the run.
       Results go in $twsr/analyze_activate.txt .

           gmake analyze_activate
           ** Activation analysis: success 10, failure 1, problem 1, UNKNOWN 1 **
           ** (See analyze_activate.txt in ../../../../testbed/www/sec-check/results .) **
           **
     - The success/failure.txt pattern files are also used action-by-action to
       look at the html results in the wget_post makefile function.  When a
       failure occurs, the make stops.  This is a Good Thing, because there
       are a lot of dependencies in the activation sequence.  Most early
       objects must exist for later ones to be created.  When UNKNOWN results
       occur, browse to the file to see what was returned and update the patterns.

       There's no dependency sequence in the activation tasks in the makefile.
       If activate fails, fix the problem and make the remaining targets in the
       activate_tasks list.

     - You can browse to the .html files using File/Open, or pop up pages in
       your browser directly from Emacs using this handy keyboard macro:

           (fset 'browse-to-file
              [?\C-a ?\C-b ?\C-\M-s ?^ ?\\ ?w ?\C-a ?\C-c ?\C-o 
               ?\C-a ?\M-d ?\C-d ?\C-d ?\C-\M-y ?d return return ?\C-e ?\C-f])
           (global-set-key "" 'browse-to-file)
           (progn (switch-to-buffer "d") (kill-region (point-min) (point-max))
             (insert-string ; Or in the parent dir for setup/teardown.
               "file://localhost/home/fish/flux/obj-devel/www/sec-check/activate.wget"))
           (setq browse-url-generic-program "opera")
           (global-set-key "\^C\^O" 'browse-url-generic)

       To define it, select the above lines and type M-X eval-region .  It
       will take you to buffer "d", so just ^X-b (switch-to-buffer) to return.
       Remove the *.wget directory suffix if you are in the main directory
       (setup, show, and teardown actions below.)

       Usage: The file path to your current obj-devel directory containing
       html files is in buffer "d".  Put the cursor on a filename line in an
       analyze*.txt file and type ^C-^F to pop up the page in the current
       Opera tab.

       Notice that if the resulting .html file contains a javascript
       PageReplace, you will need to comment that out to see what was actually
       returned by PHP, adding "!--" and "--", like this:

           <!-- script type='text/javascript' language='javascript'>
           PageReplace('shownode.php3?node_id=pc120');
           </script -->

     - Debugging: You can gmake individual activation tasks when things are
       broken, working through the sequence by hand.  The actions should
       handle the dance of logging in and out and toggling admin privileges.

       Notice that since all of the integer object GUID's were added to the
       Emulab DB schema, there's a lot of ssh'ing mysql commands to myboss to
       fetch _idx values, that are substituted into later page arguments.
       This may be fragile if it keeps changing.

   ----------------
   . spider: clear_wget_dirs do_spider site_list site_msg

     Recursively wget a copy of the ElabInElab site and extract a <forms list.

     Logging in and out is handled automatically, to get both the public and
     the private (admin) versions of pages.  As with activate, .prev versions
     of the output directories are kept.

         gmake spider |& tee spider.log

     This takes a while to run, since it's getting multiple 10's of megabytes
     of stuff.  It isn't smart enough to get just one copy of forms that are
     linked in multiple times, and have GET arg lists that become part of the
     URL's and hence part of the output filenames as well.

     - HTML output goes into public.wget and admin.wget subtrees, with a log
       file at the top and a tree named for the server,
       myboss.vulnelab.testbed.emulab.net for me, underneath.  You can browse
       into those files as well.

     - Grepped forms lines go into $tws/{public,admin,site}_{forms,files}.list,
       similar to the src_forms output above.

     - gmake site_msg reports something like:

       ** Spider: 1814 ( 3 + 1811 ) forms instances are in 55 ( 3 + 55 ) web pages. **
       ** (See *_{forms,files}.list in ../../../testbed/www/sec-check/results .) **
       **


   ----------------
   . forms_coverage: files_missing forms_msg

     Compare the two lists to find uncovered (unlinked) forms.

         gmake forms_coverage

     - Output goes in $twsr/files_missing.list .

     - gmake forms_msg reports src_msg and site_msg, plus something like:

       ** Forms: 40 out of 89 forms files are not covered. **
       ** (See ../../../testbed/www/sec-check/results/files_missing.list .) **
       **

     - Generally, unlinked forms are a symptom of an object type (or state)
       that is not yet activated.  Iterate on the activation logic.

       . Look in the sources to find where the missing links should be.

       . Connect to the ElabInElab site from a browser through Spike Proxy.

       . Interactively create DB state that will elicit the uncovered forms.
         - Projects/users awaiting approval, 
         - Experiments swapped in with active nodes, and so on.

       . Capture a list of URL's along with Get or Post inputs for automation.

       . Add steps to the activate: list in the GNUmakefile.in .

       . Re-spider and compare until everything is covered (no more missing forms.)

   ----------------
   . input_coverage: input_list input_msg

     Extract <input fields from spidered forms.

         gmake input_coverage

     - This reports something like:

       ** Inputs: 10203 input fields, 331 unique, 127 over-ridden. **
       ** (See site_inputs.list and input_names.list
       **  in ../../../testbed/www/sec-check/results,
       ** and input_values.list in ../../../testbed/www/sec-check .) **
       **

     - This is automatic, but there are a few little special cases in the
       makefile.  It leads into iterating on the input_values.list dictionary.
       See the comments about this in README-concepts.txt .

     - Input is the spidered public.wget and admin.wget subtrees.

     - Output is $twsr/site_inputs.list and $twsr/input_names.list .

       . When the inputs to a form are changed (fields, names, or defaults) you can
         edit site_inputs.list rather than having to do another whole spider run.

       . input_names.list isn't used directly, but is a source for copying strings
         to add to the $tws/input_values.list control file.

       See the comments in $twsr/forms-to-urls.gawk about features controlled
       by special annotations on the input_values.list entries.

   ----------------
   . normal: gen_all run_all analyze

     Create, run, and categorize "normal operations" test cases.

         gmake normal |& tee normal.log

     - Subtasks:

       "run" subtasks drive the "gen" subtasks by dependencies.  You can
       also do the "gen"s to get the scripts they make.

       . Update the $twsr/{setup,show,teardown}_cases.{urls,wget} files.

             gmake gen_all
         or:
                 gmake gen_setup
                 gmake gen_show
                 gmake gen_teardown

         - Inputs are $twsr/site_inputs.list, $tws/input_values.list .
           $tws/{setup,teardown}_forms.list are used for separating out the
           setup and teardown case sequences.

         - There are a couple of files mentioned in the teardown_forms.list
           that aren't actually covered yet, so making teardown_cases.urls
           will complain a bit:
             *** Missing: 24 deleteimageid.php3
             *** Missing: 56 delmmlist.php3

       . Run the generated {setup,show,teardown}_cases.wget scripts.

         Setup/teardown are sequences creating/deleting ephemeral objects,
         typically with a "3" appended to their names.  Teardown undoes setup,
         and vice-versa of course.

         Show (everything else) is separate and works on the objects made by
         activation.

             gmake run_all |& tee run_all.log
         or:
                 gmake run_setup |& tee run_setup.log
                 gmake run_show |& tee run_show.log
                 gmake run_teardown |& tee run_teardown.log

       . HTML output goes into individual .html files in the top-level directory.

       . run_all does analyze after each sub-task.  Detailed output goes into
         the $twsr/analyze_output.txt file, and a summary is printed.

         When you edit the $tws/{success,failure,problem}.txt files, you can
         just update the analysis file.

             gmake analyze

         Output, for example, is:

             ** Run analysis: success 16, failure 3, problem 1, UNKNOWN 0 **
             ** (See analyze_output.txt in ../../../testbed/www/sec-check/results .) **
             **

         Look into failures and problems, of course.  See the description of
         browsing to the output files above in the "activate:" section.

       . Here, you pretty much iterate on the makefile and all of the scripts
         and control files until everything works smoothly.  (This is a goal
         that is asymptotically approached.)  

         See the comments in README-concepts.txt about what to change.

       . Debugging: It's often useful to regenerate the .wget files and
         copy-paste individual commands into a shell window to "single-step"
         the sequence.

         You can just refresh the browser window as the .html output changes.

         Except, when an Emulab "backgrounded" task finishes, the page gets a
         little bit of "PageReplace" Javascript to redirect to the "show"
         page.  You can edit the .html file to remove or comment out the
         PageReplace, adding "!--" and "--", like this:

           <!-- script type='text/javascript' language='javascript'>
           PageReplace('shownode.php3?node_id=pc120');
           </script -->

   ----------------
   . probe: gen_probes probe_all probes_msg

     Create and run probes to test the checking code of all input fields.

         gmake probe_all |& tee probe_all.log

     This can get really complicated, for reasons described in this section of
     README-concepts.txt .

     - Subtasks:

       . Update the $twsr/{setup,show,teardown}_probe.{urls,wget} files.

             gmake gen_probes

       . probe_setup first does run_teardown to make sure debris is cleaned up.

             gmake probe_setup |& tee probe_setup.log
             gmake probe_show |& tee probe_show.log
             gmake probe_teardown |& tee probe_teardown.log

       . Analysis

             gmake probes_msg
