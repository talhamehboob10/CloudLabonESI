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

# Top-level targets:
# "activate" isn't in "all" because it's a setup task that shouldn't be repeated.
all_tasks = src_forms spider forms_coverage input_coverage normal probe
# Stats from the top-level tasks:
msgs_tasks = src_msg site_msg forms_msg input_msg analyze probes_msg
.PHONY: activate all $(all_tasks) msgs $(msgs_tasks)

# See README-howto.txt for usage details.
all: $(all_tasks)
msgs: $(msgs_tasks)

# Notice that the output lists are put into the results subdir of the source dir.
# Spidered HTML pages go in (subdirs of) the obj dir.
#

SRCDIR		= ../../../www/sec-check
RESDIR		= $(SRCDIR)/results

TESTBED_SRCDIR	= ../../..

OBJDIR		= ../..
SUBDIR		= www/sec-check
SRCWWW		= $(TESTBED_SRCDIR)/www

OURDOMAIN       = cloudlab.umass.edu

include $(TESTBED_SRCDIR)/GNUmakerules

# Delete a target file if the command fails in the middle of changing it.
.DELETE_ON_ERROR:

#================================================================
# src_forms: Grep the sources for <form and make up a list of php form files.
#
src_forms: src_list src_msg

SRC_FORMS	= $(RESDIR)/src_forms.list
SRC_FILES	= $(RESDIR)/src_files.list
src_list: $(SRC_FORMS) $(SRC_FILES)

# All of the forms lines.
$(SRC_FORMS):
	# Ignore any Emacs backup files with tilde's in the filenames.
	(cd $(SRCWWW); \
	  find . -maxdepth 1 -name '*.php*' -print0 | \
	    xargs -0 grep -n '<form' | fgrep -v /save/ | \
	    sed '/^[^:]*~/d' ) | sort > $(SRC_FORMS)

# Just the files list.
$(SRC_FILES): $(SRC_FORMS)
	# Just filenames; get rid of the "./" prefix and ":<lnum>: <form" suffix.
	sed -e 's|^[^:]*/||' -e 's|:.*||' $(SRC_FORMS) | uniq > $(SRC_FILES)

# Dump a stats message.
src_msg: src_list
	@echo "** Sources: `wc -l < $(SRC_FORMS)` separate forms" \
	     "are on `wc -l < $(SRC_FILES)` code pages. **" | tr -s " "
	@echo "** (See $(notdir $(SRC_FORMS)) and $(notdir $(SRC_FILES))"
	@echo "**  in $(RESDIR) .) **"
	@echo "**"

#================================================================
# Lots of common stuff for wget.
#
.PHONY: login admin logout

# Need an Emulab-in-Emulab experiment running, e.g. vulnElab.ns .
EinE_proj	= testbed
EinE_exp	= vulnElab
EinE_boss	= myboss
EinE_ops	= myops

# Login info for the inner Emulab.
uid		= $(USER)
### It's better to log in a browser and change your password in Edit Profile
### in the inner Elab to this string, than to put a real password here!
pswd		= EinE_tmp

# Real email address for confirmation messages.
email_dest	= flux.utah.edu
real_email	= $(uid)@$(email_dest)
# Another one, because they have to be unique in the inner Elab now.
email_dest2	= cs.utah.edu
real_email2	= $(uid)@$(email_dest2)

# Machine paths.
dom		= $(EinE_proj).$(OURDOMAIN)
boss		= $(EinE_boss).$(EinE_exp).$(dom)
ops		= $(EinE_ops).$(EinE_exp).$(dom)
root		= http://$(boss)
sroot		= https://$(boss)

# Cookie state stuff for wget.
COOKIES		= cookies.txt
sv_cookies	= --save-cookies $(COOKIES)
ld_cookies	= --load-cookies $(COOKIES)
ld_cookies_subdir = --load-cookies ../$(COOKIES)
cookie_args	= --keep-session-cookies --no-check-certificate
wget_args	= -S -k $(cookie_args) $(ld_cookies)
wget_args_subdir= -S -k $(cookie_args) $(ld_cookies_subdir)

# Patterns to categorize the HTML result.
analysis_patterns = $(SRCDIR)/success.txt $(SRCDIR)/failure.txt $(SRCDIR)/problem.txt
success_cmd = grep -f $(SRCDIR)/success.txt
FAIL_FILE = failure.txt
failure_cmd = grep -f $(SRCDIR)/$(FAIL_FILE)

# Log in and create a current cookies.txt file.
# Args are uid and password.  The password must match your login (see above.)
logindir = logins
login_user = @ echo ==== Logging in as $(1) ; \
	if [ ! -d $(logindir) ]; then mkdir $(logindir); fi; \
	wget -S -dv $(cookie_args) $(sv_cookies) \
	-o $(logindir)/login.log -O $(logindir)/login_$(1).html \
	--post-data "uid=$(1)&password=$(2)&login=Login" \
	$(sroot)/login.php3; \
	if $(failure_cmd) $(logindir)/login_$(1).html; then \
	      (echo "*** LOGIN FAILURE"; exit 1); \
	fi
login_sys := $(call login_user,$(uid),$(pswd))
login: logout
	$(login_sys)

# Log in above, then use this to toggle the admin bit on.
admin_cmd = @ echo ==== Turning on admin privs; \
	if [ ! -d $(logindir) ]; then mkdir $(logindir); fi; \
	wget -S -dv $(cookie_args) $(ld_cookies) \
	-o $(logindir)/admin.log -O $(logindir)/admin.html \
	"$(sroot)/toggle.php?target_uid=$(uid)&type=adminon&value=1"; \
	if $(failure_cmd) $(logindir)/admin.html; then \
	      (echo "*** ADMIN FAILURE"; exit 1); \
	fi 
admin: login
	$(admin_cmd)

# Must be logged out to see the public view.
logout_cmd = @ echo ==== Logging out; \
	if [ ! -d $(logindir) ]; then mkdir $(logindir); fi; \
	wget -S -dv $(cookie_args) $(ld_cookies)\
	-o $(logindir)/logout.log -O $(logindir)/logout.html \
	"$(sroot)/logout.php3?target_uid=$(uid)"
logout:
	$(logout_cmd)

#================================================================
# Factored-out commands for the "call" function.

# Format html args separated by a single space into an argument string with &'s.
# Putting them on separate lines with a backslash also results in a single space.
#
# The $(empty) var trick allows a subst arg of " " (a single space.)
# Found in the GNU make info node for Syntax of Functions.
empty :=
# Encode backslashed spaces in strings as %20, and double-quotes as %22.
fmt_html_args = $(subst $(empty) ,&,$(subst \ ,%20,$(subst \",%22,$(strip $(1)))))

# Post a form via wget and check the returned page.
# Args are [root],php_infile,[html_outfile],html_args,[run_time_args] .
# root defaults to $(sroot) .  html_outfile defaults to php_infile.html .
# The run_time_args are good for e.g. a repeatedly referenced db item.
outdir = activate.wget
define wget_post
	@ if [ ! -d $(outdir) ]; then mkdir $(outdir); fi
	@ root_dir=$(strip $(1)); \
	  php_infile=$(strip $(2)); \
	  html_outfile=$(strip $(3)); \
	  $(if $(5),$(5);) \
	  post_args="$(call fmt_html_args, $(4))"; \
	  echo "==== $(outdir) $${root_dir} $${php_infile}" \
		    "$${html_outfile:=$(2).html} ===="; \
	  echo "cd $(outdir); wget $(wget_args_subdir) \
	    -O $${html_outfile} \
	    -o $${html_outfile}.log \
	    --post-data '$${post_args}' \
	    $${root_dir:-$(sroot)}/$${php_infile}" \
	    > $(outdir)/$${html_outfile}.cmd; \
	  sh $(outdir)/$${html_outfile}.cmd; \
	  if $(failure_cmd) $(outdir)/$${html_outfile}; then \
	      (echo "*** FAILURE"; exit 1); \
	  elif $(success_cmd) $(outdir)/$${html_outfile}; then \
	      echo "* SUCCESS"; \
	  else echo "*** UNKNOWN RESULT"; \
	  fi
endef

# Send an SQL command to myboss.  The value is the last line if more than one.
# Commas separate "$(call" args.  Embed them into an arg with a variable $(comma).
comma := ,
boss_sql = echo "$(strip $(1))" | ssh $(boss) mysql tbdb | tail -1

#================================================================
# activate: Set up the newly swapped-in EinE site to turn on as many forms as we can.
#
### Don't forget to first log in a browser and change your password in Edit Profile
### in the inner Elab to match the string given above as $(pswd).
#
activate_tasks = fix_emails new_proj1 new_proj2 approve_proj new_group \
	  new_user1 confirm_user1 approve_user1 \
	  new_user2 confirm_user2 \
	  new_exp2 new_exp1 mod_exp2 \
	  new_nodetype new_osid new_imageid
.PHONY:   $(activate_tasks)
#
activate: activate.wget $(activate_tasks) analyze_activate

activate.wget:
	- rm -rf activate.wget.prev
	- mv -f activate.wget activate.wget.prev
	mkdir activate.wget

proj_common = $(call fmt_html_args,\
	    formfields[proj_URL]=$(root)\
	    formfields[proj_funders]=none\
	    formfields[proj_linked]=checked\
	    formfields[proj_members]=1\
	    formfields[proj_pcs]=3\
	    formfields[proj_public]=checked\
	    formfields[proj_why]=Test\ for\ injection.\
	    formfields[proj_whynotpublic]=\
	    submit=Submit)

# Also change all user e-mail addresses to me so I get the editgroup, etc. e-mail
# instead of bothering everybody else on testbed-ops.  This is *not* the primary
# e-mail address used as my login to Emulab $(real_email), which *has to be unique*!
fix_emails:
	@echo ==== Fixing email addresses ====
	echo "select uid, usr_email from users where usr_email not like '%@myops%'; \
	      update users set usr_email='$(real_email2)' \
	        where uid != '$(uid)' and usr_email not like '%@myops%'; \
	      select uid, usr_email from users where usr_email not like '%@myops%';" | \
	    ssh $(boss) mysql --table tbdb

# Start *two* test projects.
# Leave testproj2 unapproved so approveproject_form.php3 remains active.
proj1 = testproj
new_proj1: admin
	$(call wget_post,,newproject.php3,newproj1.html,\
	    formfields[pid]=$(proj1)\
	    formfields[proj_name]=$(proj1)\ description.\
	    $(proj_common))
# Assume we stay logged in and toggled to admin.
# Otherwise, each time looks like a separate browser login in the session DB.
proj2 = testproj2
new_proj2:
	$(call wget_post,,newproject.php3,newproj2.html,\
	    formfields[pid]=$(proj2)\
	    formfields[proj_name]=$(proj2)\ description.\
	    $(proj_common))

# Approve one test project.  (Takes a couple of minutes to run.)
approve_proj:
	$(call wget_post,,approveproject.php3,,\
	    pid=$(proj1) approval=approve OK=Submit\
	    head_uid= user_interface=emulab pcplab_okay=Yep ron_okay=Yep message=)

# Create a subgroup of the test project.  (Takes a few seconds to run.)
grp1 = testgroup
new_group:
	$(call wget_post,,newgroup.php3,,\
	    project=$(proj1)\
	    formfields[group_id]=$(grp1)\
	    formfields[group_leader]=$(uid)\
	    formfields[group_description]=$(proj1)\ subgroup.\
	    submit=Submit)

user_common = $(call fmt_html_args,\
	    formfields[usr_title]=Tester\
	    formfields[usr_affil]=Emulab\ Scripts\
	    formfields[usr_URL]=http://www.emulab.net\
	    formfields[usr_addr]=Silly\
	    formfields[usr_addr2]=Address\
	    formfields[usr_city]=Salt\ Lake\ Silly\
	    formfields[usr_state]=UT\
	    formfields[usr_zip]=12345\
	    formfields[usr_country]=USA\
	    formfields[usr_phone]=(801)\ 123-4567\
	    formfields[password1]=user_pswd\
	    formfields[password2]=user_pswd\
	    formfields[pid]=$(proj1)\
	    formfields[gid]=\
	    submit=Submit)

# Make new users.  (Use http, not https; not logged in, join a project.)
# Do testuser and testusr2.
# Leave testusr2 unapproved (but confirmed) so approveuser_form.php3 is active.
usr1 = testuser
name1 = Test User 1
new_user1: ###logout
	$(logout_cmd)
	$(call wget_post,$(root),joinproject.php3,newuser1.html,\
	    formfields[joining_uid]=$(usr1)\
	    formfields[usr_name]=$(subst $(empty) ,\ ,$(name1))\
	    formfields[wikiname]=$(subst $(empty) ,,$(name1))\
	    formfields[usr_email]=$(subst $(empty) ,,$(name1))@$(email_dest)\
	    $(user_common))
	$(login_sys)
	$(admin_cmd)
# Pretend the user sent in his e-mail confirmation.
confirm_user1:
	$(call boss_sql,\
	    update users set status='unapproved' where uid='$(usr1)')
query_user1:
	$(call boss_sql,\
	    select uid$(comma) uid_idx$(comma) usr_name$(comma) status \
	      from users where uid='$(usr1)')
usr2 = testusr2
name2 = Test User 2
new_user2: ###logout
	$(logout_cmd)
	$(call wget_post,,joinproject.php3,newuser2.html,\
	    formfields[joining_uid]=$(usr2)\
	    formfields[usr_name]=$(subst $(empty) ,\ ,$(name2))\
	    formfields[wikiname]=$(subst $(empty) ,,$(name2))\
	    formfields[usr_email]=never.approve@nowhere.net\
	    $(user_common))
	$(login_sys)
	$(admin_cmd)
# Pretend the user sent in his e-mail confirmation.
confirm_user2:
	$(call boss_sql,\
	    update users set status='unapproved' where uid='$(usr2)')
query_user2:
	$(call boss_sql,\
	    select uid$(comma) uid_idx$(comma) usr_name$(comma) status \
	      from users where uid='$(usr2)')

# Approve a new user, Takes a couple of minutes to run.  %24 is "$", %2F is "/".
# Get the uid_idx for the user from the db on the inner boss at run time.
usr1_sql = $(call boss_sql, select uid_idx from users where uid='$(usr1)')
# Gotta log back in after being logged out above.
approve_user1:
	$(call wget_post,,approveuser.php3,appusr1.html,\
	    U$$usr1_idx%24%24approval-$(proj1)%2F$(proj1)=approve\
	    U$$usr1_idx%24%24trust-$(proj1)%2F$(proj1)=local_root\
	    OK=Submit,\
	    usr1_idx=`$(usr1_sql)`)

exp_common =  $(call fmt_html_args,\
	    beginexp=Submit\
	    formfields[exp_pid]=$(EinE_proj)\
	    formfields[exp_gid]=\
	    MAX_FILE_SIZE=512000\
	    formfields[exp_localnsfile]=/users/$(USER)/shaped-2-nodes.ns\
	    formfields[exp_swappable]=1\
	    formfields[exp_noswap_reason]=\
	    formfields[exp_idleswap]=0\
	    formfields[exp_idleswap_timeout]=4\
	    formfields[exp_noidleswap_reason]=Because\
	    formfields[exp_autoswap]=0\
	    formfields[exp_autoswap_timeout]=16\
	    formfields[exp_linktest]=0)

# Make an experiment via ssh and leave it not swapped in.
# (Do exp2 before exp1 so exp2 can finish creating before we do modifyexp on it.)
exp2 = testexp2
new_exp2:
	@echo ==== Creating $(exp2) ====
	scp -p $(SRCDIR)/shaped-2-nodes.ns $(ops):
	ssh $(ops) 'startexp -w -f -E "$(exp2) experiment." \
	    -p $(EinE_proj) -e $(exp2) shaped-2-nodes.ns'

# Make another new experiment.  Takes a few minutes to swap in.
# Must have at least one delay node for Traffic Shaping and Link Tracing pages.
exp1 = testexp1
new_exp1:
	scp -p $(SRCDIR)/shaped-2-nodes.ns $(ops):
	$(call wget_post,,beginexp_html.php3,newexp1.html,\
	    formfields[exp_id]=$(exp1)\
	    formfields[exp_description]=$(exp1)\ experiment.\
	    $(exp_common))

# Modify an experiment (first time creates an archive.)
mod_exp2:
	$(call wget_post,,modifyexp.php3,modexp2.html,\
	    pid=$(EinE_proj) eid=$(exp2) go=1\
	    MAX_FILE_SIZE=512000\
	    exp_localnsfile=/users/$(USER)/shaped-2-nodes.ns\
	    reboot=1\
	    eventrestart=1)

# Create a nodetype to edit.
new_nodetype:
	-$(call boss_sql, \
	    delete from node_types where type like 'pc%test')
	-$(call boss_sql, \
	    delete from node_type_attributes where type like 'pc%test')
	-$(call boss_sql, \
	    delete from node_types_auxtypes where auxtype like 'pc%test')
	$(call wget_post,,editnodetype.php3,newnodetype.html,\
	    new_type=1\
	    node_type=pctest\
	    formfields[class]=pc\
	    formfields[isdynamic]=0\
	    formfields[issubnode]=0\
	    formfields[isplabdslice]=0\
	    formfields[isjailed]=0\
	    formfields[isremotenode]=0\
	    formfields[isvirtnode]=0\
	    formfields[issimnode]=0\
	    newattribute_name=testattr\
	    newattribute_type=integer\
	    newattribute_value=42\
	    submit=Submit)

# Create OS and image ID's to edit.
os1 = testosid
new_osid:
	$(call wget_post,,newosid.php3,newosid.html,\
	    formfields[pid]=$(proj1)\
	    formfields[osname]=$(os1)\
	    formfields[os_feature_isup]=checked\
	    formfields[magic]=\
	    formfields[path]=\
	    formfields[version]=666\
	    formfields[nextosid]=\
	    formfields[os_feature_veths]=checked\
	    formfields[os_feature_ping]=checked\
	    formfields[os_feature_ipod]=checked\
	    formfields[OS]=FreeBSD\
	    formfields[os_feature_linktest]=checked\
	    formfields[os_feature_mlinks]=checked\
	    formfields[mustclean]=1\
	    formfields[op_mode]=NORMALv2\
	    formfields[description]=Test OS description.\
	    formfields[reboot_waittime]=150\
	    formfields[shared]=1\
	    formfields[os_feature_linkdelays]=checked\
	    formfields[os_feature_ssh]=checked\
	    submit=Submit)
os1_osid_sql = $(call boss_sql, \
	select osid from os_info where pid='$(proj1)' and osname='$(os1)')
show_os1_osid:
	echo `$(os1_osid_sql)`
img1 = testimg
new_imageid:
	$(call wget_post,,newimageid.php3,newimageid.html,\
	    formfields[imagename]=$(img1)\
	    formfields[pid]=$(proj1)\
	    formfields[gid]=\
	    formfields[path]=/proj/testbed/images/$(img1).ndz\
	    formfields[loadlength]=1\
	    formfields[default_osid]=$$os1_osid\
	    formfields[part1_osid]=$$os1_osid\
	    formfields[mtype_pc600]=Yep\
	    formfields[mtype_pc850]=Yep\
	    formfields[makedefault]=Yep\
	    formfields[loadpart]=1\
	    formfields[node]=\
	    formfields[description]=Descriptive text.\
	    submit=Submit,\
	    os1_osid=`$(os1_osid_sql)`)

# Re-use the analysis action, running it in the activate.wget subdirectory.
analyze_activate: $(analysis_patterns)
	@cd activate.wget && $(MAKE) -f ../GNUmakefile --no-print-directory \
	    analysis_kind=Activation analyze_output=../$(ACTIVATE_ANALYSIS) \
	    SRCDIR=../$(SRCDIR) TESTBED_SRCDIR=../$(TESTBED_SRCDIR) \
	    analyze_msg
ACTIVATE_ANALYSIS = $(RESDIR)/analyze_activate.txt

#================================================================
# spider: Recursively a copy of the EinE site with wget and extract its forms list.
#
# Actually, spider it twice, once not logged in for the public view,
# and again, logged in and with administrative privileges, for the private view.
#
# The object here is to find and scan the forms, not execute them yet.
#
spider_tasks = clear_wget_dirs do_spider site_list site_msg
.PHONY: $(spider_tasks)
#
spider: $(spider_tasks)

# Login/admin mode changes are handled explicitly in the "activate:" target, and
# as "!actions" in the {setup,teardown}_forms.list specs controlling sep-urls.gawk .
#
# Don't follow page links that change the login/admin state here.
# Also reject other links to pages which don't have any input fields, and don't ask
# for confirmation before taking actions.  These must be tested specially.
top_links	= login.php3,logout.php3,toggle.php,pagenotworking.php
user_links	= suuser.php,sendtestmsg.php3
exp_links	= showlogfile.php3,request_idleinfo.php3,request_swapexp.php3
node_links	= nodetipacl.php3,showconlog.php3,nodessh.php3
linkmon_links	= spewevents.php,linkmon_mon.php3 
rej_links	= \
	.txt,$(top_links),$(user_links),$(exp_links),$(node_links),$(linkmon_links)

# Clear out wget subdirectories so we aren't confused by results of old runs.
wget_dirs	= public.wget admin.wget probes.wget
.PHONY: $(wget_dirs)
#
clear_wget_dirs: $(wget_dirs)

public.wget:
	- rm -rf public.wget.prev
	- mv -f public.wget public.wget.prev
	mkdir public.wget
admin.wget:
	- rm -rf admin.wget.prev
	- mv -f admin.wget admin.wget.prev
	mkdir admin.wget
probes.wget:
	- rm -rf probes.wget.prev
	- mv -f probes.wget probes.wget.prev
	mkdir -p probes.wget/undo

# Finally ready to grab the whole site.
.PHONY:    public_spider admin_spider
do_spider: public_spider admin_spider

public_spider: public.wget/public.log
public.wget/public.log: 
	$(logout_cmd)
	@ echo ==== Spidering the public interface.
	cd public.wget; \
	wget -r -S $(cookie_args) $(ld_cookies_subdir) -o public.log \
	     -k -D $(dom) -R $(rej_links) -X /downloads,/gallery $(sroot)
	du -s public.wget

admin_spider: admin.wget/admin.log
admin.wget/admin.log:
	$(login_sys)
	$(admin_cmd)
	@ echo ==== Spidering the private "(logged in, admin)" interface.
	@echo "** Be patient, spidering will take at least 10 minutes. **"
	cd admin.wget; \
	wget -r -S $(cookie_args) $(ld_cookies_subdir) -o admin.log \
	     -k -D $(dom) -R $(rej_links) -X /downloads,/gallery $(sroot)
	du -s admin.wget

# Extract a list of the active forms in the site.
SITE_FORMS	= $(RESDIR)/site_forms.list
SITE_FILES	= $(RESDIR)/site_files.list
site_list: $(SITE_FORMS) $(SITE_FILES)

# Ignore flyspray and Twiki for now.
# Ignore the search box form on every page, we'll treat it separately.
forms_cmd = find . \( -name distributions -prune \) \
		-o \( -name flyspray -prune \) \
		-o \( -name twiki -prune \) \
		-o -type f -print0 | xargs -0 grep -n '<form ' | \
	    fgrep -v /search.php3 ) | sort -u
# Filenames - Remove directory prefix and "Get" arg lists after the filename.
# Kill suffix after filename first: .../archive_view.php3/9/trunk?exptidx=9
files_cmd = sed -e 's|\(php3*\).*|\1|' -e 's|^[^:]*/||' 

PUBLIC_FORMS	= $(RESDIR)/public_forms.list
PUBLIC_FILES	= $(RESDIR)/public_files.list
public_list: $(PUBLIC_FORMS) $(PUBLIC_FILES)

$(PUBLIC_FORMS): public.wget/public.log
	(cd public.wget; $(forms_cmd) > $(PUBLIC_FORMS)
$(PUBLIC_FILES): $(PUBLIC_FORMS)
	$(files_cmd) $(PUBLIC_FORMS) | uniq > $(PUBLIC_FILES)

ADMIN_FORMS	= $(RESDIR)/admin_forms.list
ADMIN_FILES	= $(RESDIR)/admin_files.list
admin_list: $(ADMIN_FORMS) $(ADMIN_FILES)

$(ADMIN_FORMS): admin.wget/admin.log
	(cd admin.wget; $(forms_cmd) > $(ADMIN_FORMS)
$(ADMIN_FILES): $(ADMIN_FORMS)
	$(files_cmd) $(ADMIN_FORMS) | uniq > $(ADMIN_FILES)

$(SITE_FORMS): $(PUBLIC_FORMS) $(ADMIN_FORMS)
	cat $(PUBLIC_FORMS) $(ADMIN_FORMS) | sort -u > $(SITE_FORMS)

# The <forms under index.html are actually in menu.php3 via defs.php3.in .
# Ditto beginexp_{html,form}.php3 .
$(SITE_FILES): $(PUBLIC_FILES) $(ADMIN_FILES)
	cat $(PUBLIC_FILES) $(ADMIN_FILES) | \
	    sed -e 's/index\.html/menu.php3/' \
		-e 's/beginexp_html/beginexp_form/' | sort -u > $(SITE_FILES)

# Dump a stats message.
site_msg: site_list public_list admin_list
	@echo "** Spider: `wc -l < $(SITE_FORMS)` (`wc -l < $(PUBLIC_FORMS)` +" \
	      "`wc -l < $(ADMIN_FORMS)` ) forms instances" \
	      "are in `wc -l < $(SITE_FILES)` (` wc -l < $(PUBLIC_FILES)` +" \
	      "`wc -l < $(ADMIN_FILES)` ) web pages. **" | tr -s " "
	@echo "** (See *_{forms,files}.list in $(RESDIR) .) **"
	@echo "**"

#================================================================
# forms_coverage: Compare the two lists to find uncovered (unlinked) forms.
#
.PHONY:         files_missing forms_msg
forms_coverage: files_missing forms_msg

FILES_MISSING = $(RESDIR)/files_missing.list
files_missing: $(FILES_MISSING)
$(FILES_MISSING): $(SRC_FILES) $(SITE_FILES)
	diff $(SRC_FILES) $(SITE_FILES) | grep '^[<>] [^.]' > $(FILES_MISSING)

# Dump a stats message.
forms_msg: files_missing src_msg site_msg
	@echo "** Forms: `wc -l < $(FILES_MISSING)`" \
	    "out of `wc -l < $(SRC_FILES)`" \
	    "forms files are not covered. **" | tr -s " "
	@echo "** (See $(FILES_MISSING) .) **"
	@echo "**"

# Look at files_missing.list and see README-howto.txt for the
# procedure to activate coverage of more forms.

#================================================================
# input_coverage: Grep spidered forms for <input definitions, make values dictionary.
#
.PHONY:         input_list input_msg
input_coverage: input_list input_msg

SITE_INPUTS     = $(RESDIR)/site_inputs.list
INPUT_NAMES	= $(RESDIR)/input_names.list
input_list: $(SITE_INPUTS) $(INPUT_NAMES)

PUBLIC_INPUTS   = $(RESDIR)/public_inputs.list
ADMIN_INPUTS    = $(RESDIR)/admin_inputs.list
# XXX kluge to make imageid mtype checked by default since at least one is required.
# XXX Set a default newattribute_type radio button; nothing is clicked by default.
# XXX Clear node reservations instead of setting them.
$(SITE_INPUTS): $(PUBLIC_INPUTS) $(ADMIN_INPUTS)
	cat $(PUBLIC_INPUTS) $(ADMIN_INPUTS) | \
	   gawk '(/formfields\[mtype/ || /newattribute_type.*integer/) && !/checked/ \
		     { sub(" *>$$", " checked >"); } \
	         { print; } \
		 /action="prereserve_node.php3/ \
		     { print "<input type=\"hidden\" name=\"clear\" value=\"1\" >"; }' \
		 > $(SITE_INPUTS)

# Extract input fields and context from the html form files in the wget subdirs.
# Output sections terminated by a blank line contain: filename, <form, <input* .
# Canonicalize and reorder <input fields: <input type="..." name="..." value=... ...>
#
# inputs_cmd is parameterized by directory: {public,admin}.
# Input comes from $(dir)_forms.list ; output goes into $(dir)_inputs.list .
# Run the awk command on a long list of forms file names using xargs.
# Expand it in the shell so gmake -n output doesn't swamp us.
inputs_cmd = @echo "form-inputs from files in $(1)_forms.list to $(1)_inputs.list"; \
   (cd $(1).wget && \
    sed -e 's/:[0-9][0-9]*:.*//' ../$(RESDIR)/$(1)_forms.list | \
    xargs gawk -f ../$(SRCDIR)/form-input.gawk $$f ) > $(RESDIR)/$(1)_inputs.list
$(PUBLIC_INPUTS): $(PUBLIC_FORMS) $(SRCDIR)/form-input.gawk
	$(call inputs_cmd,public)
$(ADMIN_INPUTS): $(ADMIN_FORMS) $(SRCDIR)/form-input.gawk
	$(call inputs_cmd,admin)

# Get unique input field names: text(area), hidden, checkbox, select, radio/checked.
$(INPUT_NAMES): $(SITE_INPUTS)
	gawk '/type="(text|hidden|checkbox|select)/ || /\<checked\>/ \
		  { print $$3; }' $(SITE_INPUTS) | sort -u > $(INPUT_NAMES)

# Dump a stats message.
input_msg: input_list
	@echo "** Inputs: `grep -c '<input' $(SITE_INPUTS)` input fields," \
	    "`wc -l < $(INPUT_NAMES)` unique," \
	    "`wc -l < $(INPUT_VALUES)`  over-ridden. **" | tr -s " "
	@echo "** (See $(notdir $(SITE_INPUTS)) and $(notdir $(INPUT_NAMES))"
	@echo "**  in $(RESDIR),"
	@echo "** and $(notdir $(INPUT_VALUES)) in $(SRCDIR) .) **"
	@echo "**"

# Copy relevant name= lines from results/input_names.list to input_values.list .
# Add a space and default value onto the ends of the lines for auto-form-fill-in.
INPUT_VALUES_SRC = $(SRCDIR)/input_values.list

# Subst configure names of activate objs for @keyword@ in the values dictionary.
INPUT_VALUES = input_values.list
$(INPUT_VALUES): $(INPUT_VALUES_SRC) activate.wget
	sed -e "s/@uid@/$(uid)/" \
	    -e "s/@email@/$(real_email2)/" \
	    -e "s/@pcnode@/`$(node_sql)`/" \
	    -e "s/@usridx@/`$(usridx_sql)`/" \
	    -e "s/@exptidx@/`$(exptidx_sql)`/" \
	    $(INPUT_VALUES_SRC) > $(INPUT_VALUES)
node_sql = $(call boss_sql, select phys_nodeid from nodes where type like 'pc%')
show_node:
	echo `$(node_sql)`
usridx_sql = $(call boss_sql, select uid_idx from users where uid='$(usr1)')
show_usridx:
	echo `$(usridx_sql)`
exptidx_sql = $(call boss_sql, select idx from experiments where eid='$(exp1)')
show_exptidx:
	echo `$(exptidx_sql)`

#================================================================
# normal: Create, run, and categorize "normal operations" test cases.
#
# Convert the input list to normal test cases with input field values.
# Test until "normal" input tests work properly on all forms.
# Cases are divided into setup, show, and teardown subsets.
# 
gen_tasks = gen_setup gen_show gen_teardown
run_tasks = run_setup run_show run_teardown analyze
.PHONY: normal gen_all run_all $(gen_tasks) $(run_tasks)
#
normal: gen_all run_all
gen_all: $(gen_tasks)
# Analyze partial results in between run tasks.
run_all: run_setup analyze run_show analyze run_teardown analyze

URLS		= $(SHOW_URLS) $(SETUP_URLS) $(TEARDOWN_URLS)

# The "show" actions don't change persistent state.
SHOW_URLS	= $(RESDIR)/show_cases.urls
SHOW_WGET	= $(RESDIR)/show_cases.wget
SHOW_XML	= $(RESDIR)/show_cases.xml
gen_show: $(SHOW_URLS) $(SHOW_WGET) ###$(SHOW_XML)

# Separate out the setup and teardown URL's from the "show" ones.
SETUP_URLS	= $(RESDIR)/setup_cases.urls
SETUP_WGET	= $(RESDIR)/setup_cases.wget
SETUP_XML	= $(RESDIR)/setup_cases.xml
gen_setup: $(SETUP_URLS) $(SETUP_WGET) ###$(SETUP_XML)

TEARDOWN_URLS	= $(RESDIR)/teardown_cases.urls
TEARDOWN_WGET	= $(RESDIR)/teardown_cases.wget
TEARDOWN_XML	= $(RESDIR)/teardown_cases.xml
gen_teardown: $(TEARDOWN_URLS) $(TEARDOWN_WGET) ###$(TEARDOWN_XML)

sep_src		= $(SRCDIR)/sep-urls.gawk
sep_cmd		= gawk -f $(sep_src) -v SYSADMIN=$(uid)
f2u_src		= $(SRCDIR)/forms-to-urls.gawk
u2w_src		= $(SRCDIR)/urls-to-wget.gawk
u2w_cmd		= gawk -f $(u2w_src) -v SRCDIR=$(SRCDIR)
URL_PREREQS	= $(f2u_src) $(SITE_INPUTS) $(INPUT_NAMES) $(INPUT_VALUES) \
		  $(sep_src) $(SETUP_FORMS) $(TEARDOWN_FORMS)
SETUP_FORMS	= $(SRCDIR)/setup_forms.list
TEARDOWN_FORMS	= $(SRCDIR)/teardown_forms.list

# All of the URL's (setup, show, teardown) are mixed together at first.
tmp_urls: $(URL_PREREQS)
	gawk -f $(f2u_src) -v VALUES=$(INPUT_VALUES) $(SITE_INPUTS) > tmp_urls
# These are the forms covered by setup and teardown.  Everything else is "show".
tmp_form_files:
	sed -n '/^[ 	]*\//s||/|p' $(SETUP_FORMS) $(TEARDOWN_FORMS) > tmp_form_files

# Show action is the default for those that are neither setup nor teardown.
$(SHOW_URLS): tmp_form_files tmp_urls 
	fgrep -v -f tmp_form_files tmp_urls > $(SHOW_URLS)

# The setup and teardown actions are ordered: separated out and hacked by a script.
$(SETUP_URLS): tmp_urls
	$(sep_cmd) $(SETUP_FORMS) tmp_urls > $(SETUP_URLS)
$(TEARDOWN_URLS): tmp_urls
	$(sep_cmd) $(TEARDOWN_FORMS) tmp_urls > $(TEARDOWN_URLS)

# A little helper script to wait for the experiment to be active; run on Boss via ssh.
# Inserted between all "show" commands, but also used by the setup/teardown scripts.
waitexp_cmd = ssh $(boss) ./waitexp $(EinE_proj) $(exp1)
add_waitexp_cmds = gawk '{ print "$(waitexp_cmd)\n" $$0 }'
update_waitexp:
	scp $(SRCDIR)/waitexp $(boss):

# WebInject doesn't store the returned pages or keep login cookie state.
# Use wget instead and browse the html files to dig into what happened.
$(SHOW_WGET): $(SHOW_URLS) $(u2w_src)
	$(u2w_cmd) $(SHOW_URLS) | $(add_waitexp_cmds) > $(SHOW_WGET)
$(SETUP_WGET): $(SETUP_URLS) $(u2w_src)
	$(u2w_cmd) $(SETUP_URLS) > $(SETUP_WGET)
$(TEARDOWN_WGET): $(TEARDOWN_URLS) $(u2w_src)
	$(u2w_cmd) $(TEARDOWN_URLS) > $(TEARDOWN_WGET)

# XML test cases for WebInject.
$(SHOW_XML): $(SHOW_URLS) $(SRCDIR)/urls-to-webinject.gawk
	gawk -f $(SRCDIR)/urls-to-webinject.gawk $(SHOW_URLS) > $(SHOW_XML)

# Test until "normal" input test cases work properly in all forms.
RUN_ENV = MYBOSS=$(boss) MYOPS=$(ops) SRCDIR=$(SRCDIR)

run_setup: $(SETUP_WGET) update_waitexp
	@echo ================ Running setup ================
	$(RUN_ENV) csh -f $(SETUP_WGET)
# "Show" commands depend on activation object state, not setup/teardown.
run_show: $(SHOW_WGET) admin update_waitexp
	@echo ================ Running show ================
	scp $(SRCDIR)/waitexp $(boss):
	$(RUN_ENV) csh -f $(SHOW_WGET)
run_teardown: $(TEARDOWN_WGET) update_waitexp
	@echo ================ Running teardown ================
	scp $(SRCDIR)/waitexp $(boss):
	$(RUN_ENV) csh -f $(TEARDOWN_WGET)

#================================================================
# Analyze: Categorize the html results returned from wget actions.
#
.PHONY: analyze analyze_make analyze_msg
# These are over-ridden in a subdir analysis.
analyze_output = $(RESDIR)/analyze_output.txt
analysis_kind = Run
#
analyze: analyze_make analyze_msg
#
# Have to do this in a recursive make so the html file list is expanded *after* running.
analyze_make:
	@$(MAKE) --no-print-directory $(analyze_output)
$(analyze_output): $(analysis_patterns) *.html
	truncate -s 0 $(matches) $(analyze_output)
	$(call analyze_hdr,success)
	-$(call analyze_cmd,success.txt)
	$(call analyze_hdr,failure)
	-$(call analyze_cmd,failure.txt)
	$(call analyze_hdr,problem)
	-$(call analyze_cmd,problem.txt)
	$(call analyze_hdr,UNKNOWN)
	sed -n 's/:.*//p' $(matches) | sort -u > recognized_output.files
	ls *.html | fgrep -v -f recognized_output.files $(tee)
analyze_msg: $(analyze_output) 
	@echo -n "** $(analysis_kind) analysis: "
	@gawk '/^==/{if (type!="") printf "%s %s, ", type, count; type=$$2; count=0; next}\
	     /^[^ ]/{count++} END{printf "%s %s **\n", type, count;}' $(analyze_output)
	@echo "** (See $(notdir $(analyze_output)) in $(RESDIR) .) **"
	@echo "**"

matches = match_success.txt match_failure.txt match_problem.txt
tee = | tee >> $(analyze_output)
##cut = | cut -c -80
analyze_hdr = echo ================  $(1)  ================ $(tee)

# Group the match lines to improve comprehension.
# Output has filenames on a line by themselves, with match lines indented below.
analyze_cmd = grep -H -i -f $(SRCDIR)/$(1) *.html | tr -s " " >> match_$(1); \
	      gawk '{ cl = index($$0, ":"); fn = substr($$0, 1, cl-1); \
		      if ( file != fn ) { file = fn; print file; }; \
		      print "    ", substr($$0, cl+1); }' match_$(1) $(cut) $(tee)

SHOW_OUTPUT	= $(RESDIR)/show_output.xml
run_webinject: $(SHOW_OUTPUT)
$(SHOW_OUTPUT): $(SHOW_XML)
	(cd $(SRCDIR)/webinject;
	    webinject.pl ../$(SHOW_XML);
	    mv results.xml ../$(SHOW_OUTPUT)

#================================================================
# probe: Create and run probes to test the checking code of all input fields.
#
.PHONY: probe gen_probes probe_all run_probes
probe:  gen_probes probe_all ##run_probes

# These also need to be separated into setup, show, and teardown subsets,
# because of unrepeatable operations being caught by checking code, e.g. can't
# ask it to create a project when it already exists...  So the setup probing
# has to be done in the teardown state, and vice versa.
#
PROBE_URLS	= $(PROBE_SETUP_URLS) $(PROBE_SHOW_URLS) $(PROBE_TEARDOWN_URLS)
PROBE_SETUP_URLS = $(RESDIR)/setup_probe.urls
PROBE_SHOW_URLS = $(RESDIR)/show_probe.urls
PROBE_TEARDOWN_URLS = $(RESDIR)/teardown_probe.urls
#
PROBE_WGET	= $(PROBE_SETUP_WGET) $(PROBE_SHOW_WGET) $(PROBE_TEARDOWN_WGET)
PROBE_SETUP_WGET = $(RESDIR)/setup_probe.wget
PROBE_SHOW_WGET = $(RESDIR)/show_probe.wget
PROBE_TEARDOWN_WGET = $(RESDIR)/teardown_probe.wget

# Generate labeled mock SQL injection probes in individual fields.
# Probe strings are labeled with the form and field names that caused the hole.
gen_probes: $(PROBE_URLS) $(PROBE_WGET)

# Generate mixed together, then use the forms lists to separate and order.
tmp_probe_urls: $(URL_PREREQS)
	gawk -f $(f2u_src) -v PROBE=1 -v VALUES=$(INPUT_VALUES) \
	    $(SITE_INPUTS) > tmp_probe_urls
$(PROBE_SETUP_URLS): tmp_probe_urls
	$(sep_cmd) $(SETUP_FORMS) tmp_probe_urls > $(PROBE_SETUP_URLS)
$(PROBE_SHOW_URLS): tmp_form_files tmp_probe_urls
	fgrep -v -f tmp_form_files tmp_probe_urls > $(PROBE_SHOW_URLS)
$(PROBE_TEARDOWN_URLS): tmp_probe_urls
	$(sep_cmd) $(TEARDOWN_FORMS) tmp_probe_urls > $(PROBE_TEARDOWN_URLS)

# Output pages go to a subdir, using the cookies.txt file in the current dir.
U2W_ARG = -v FAILFILE=$(FAIL_FILE) -v OUTDIR=probes.wget
$(PROBE_SETUP_WGET): $(PROBE_SETUP_URLS) $(u2w_src)
	$(u2w_cmd) $(U2W_ARG) $(PROBE_SETUP_URLS) > $(PROBE_SETUP_WGET)
$(PROBE_SHOW_WGET): $(PROBE_SHOW_URLS) $(u2w_src)
	$(u2w_cmd) $(U2W_ARG) $(PROBE_SHOW_URLS) \
	| $(add_waitexp_cmds) > $(PROBE_SHOW_WGET)
$(PROBE_TEARDOWN_WGET): $(PROBE_TEARDOWN_URLS) $(u2w_src)
	$(u2w_cmd) $(U2W_ARG) $(PROBE_TEARDOWN_URLS) > $(PROBE_TEARDOWN_WGET)

probe_tasks = probe_setup probe_show probe_teardown probe_hdr probes_msg
.PHONY: $(probe_tasks) analyze_probes
probe_all: gen_probes probes.wget $(probe_tasks)

probe_setup: $(PROBE_SETUP_WGET) update_waitexp run_teardown
	@echo ================ Probing setup ================
	$(RUN_ENV) csh -f $(PROBE_SETUP_WGET)
# "Show" commands depend on activation object state, not setup/teardown.
probe_show: $(PROBE_SHOW_WGET) admin update_waitexp
	@echo ================ Probing show ================
	csh -f $(PROBE_SHOW_WGET)
probe_teardown: $(PROBE_TEARDOWN_WGET) update_waitexp run_setup
	@echo ================ Probing teardown ================
	$(RUN_ENV) csh -f $(PROBE_TEARDOWN_WGET)
probe_hdr:
	@echo ================ Analyzing probes ================

# Re-use the "analyze" action, running it in the probes.wget subdirectory.
analyze_probes:
	@cd probes.wget && $(MAKE) -f ../GNUmakefile --no-print-directory \
	    analysis_kind=Probe analyze_output=../$(PROBE_ANALYSIS) \
	    SRCDIR=../$(SRCDIR) TESTBED_SRCDIR=../$(TESTBED_SRCDIR) \
	    analyze_make
PROBE_ANALYSIS = $(RESDIR)/analyze_probes.txt

probe_outputs = $(PROBE_LABELS) $(UNCAUGHT_PROBES) $(UNCAUGHT_FILES)
PROBE_LABELS = $(RESDIR)/probe-labels.list
UNCAUGHT_PROBES = $(RESDIR)/uncaught-probes.list
UNCAUGHT_FILES = $(RESDIR)/uncaught-files.list

# Dump a stats message.
probes_msg $(probe_outputs): analyze_probes
	@echo -n "** Probe analysis: "
	@gawk '/^=/ { type = $$2; next; } # === success, failure, or UNKNOWN. \
	       /^[a-z]/ { 		  # Probe output file lines. \
		 # When both match, failure supercedes success; . \
		 if ( types[$$1] == "" ) { types[$$1]=type; n[type]++; nprobes++; } \
		 else if ( types[$$1] == "success" && type == "failure" ) { \
		     dups++; types[$$1]=type; n[type]++; n["success"]--; } \
		 next; } \
	       END{ print nprobes, "probes", \
		    "out of '"`cat $(PROBE_WGET) | grep -c '^wget'`"' executed:", \
		    n["success"]+0, "showed success,\n**    ", \
		    n["failure"]+0, "failure (or probes caught),", \
		    dups+0, "dups,", n["UNKNOWN"]+0, "UNKNOWN."; }' $(PROBE_ANALYSIS)
	@cat probes.wget/*.html | fgrep 'Probe label:' > $(PROBE_LABELS)
	@fgrep ": '" < $(PROBE_LABELS) | sort > $(UNCAUGHT_PROBES)
	@sed 's/.*{\([^:]*\).*/\1/' $(UNCAUGHT_PROBES) | uniq > $(UNCAUGHT_FILES)
	@echo "** Probes to" \
	    ` grep '^http' $(URLS) | sed 's/?.*//' | sort -u | wc -l`" pages gave" \
	    `wc -l < $(PROBE_LABELS)`" hits: " \
	    `fgrep -c ': \' < $(PROBE_LABELS)`" backslashed, " \
	    `wc -l < $(UNCAUGHT_PROBES)`" UNCAUGHT in " \
	    `wc -l < $(UNCAUGHT_FILES)`" pages." | tr -s " "
	@echo "** (See $(notdir $(PROBE_LABELS)) and $(notdir $(UNCAUGHT_FILES))"
	@echo "**  in $(RESDIR) .) **"
	@echo "**"

# Run the probes through webinject.
# Successfully caught cases should produce "invalid input" warnings.
# Potential penetrations will log SQL errors with the form/field name.
PROBE_OUTPUT = $(RESDIR)/probe_output.xml
###run_probes: $(PROBE_OUTPUT)
$(PROBE_OUTPUT): $(PROBE_XML)
	(cd $(SRCDIR)/webinject;
	   webinject.pl ../$(PROBE_XML);
	   mv results.xml ../$(PROBE_OUTPUT)
