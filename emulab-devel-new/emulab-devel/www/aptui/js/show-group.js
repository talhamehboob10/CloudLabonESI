$(function ()
{
  'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-group', 'experiment-list', 'member-list', 'group-profile', 'classic-explist', 'oops-modal', 'waitwait-modal']);
    var mainString = templates['show-group'];
    var experimentString = templates['experiment-list'];
    var memberString = templates['member-list'];
    var detailsString = templates['group-profile'];
    var classicString = templates['classic-explist'];
    var oopsString = templates['oops-modal'];
    var waitString = templates['waitwait-modal'];
  
    var mainTemplate    = _.template(mainString);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	
	// Generate the main template.
	var html = mainTemplate({
	    emulablink     : window.EMULAB_LINK,
	    isadmin        : window.ISADMIN,
	    target_project : window.TARGET_PROJECT,
	    target_group   : window.TARGET_GROUP,
	});
	$('#main-body').html(html);
	$('#waitwait_div').html(waitString);
	$('#oops_div').html(oopsString);

        // Javascript to enable link to tab
        var hash = document.location.hash;
        if (hash) {
            $('.nav-tabs a[href="'+hash+'"]').tab('show');
        }
        // Change hash for page-reload
        $('a[data-toggle="tab"]').on('show.bs.tab', function (e) {
	    history.replaceState('', '', e.target.hash);
        });
	// Set the correct tab when a user uses their back/forward button
        $(window).on('hashchange', function (e) {
	    var hash = window.location.hash;
	    if (hash == "") {
		hash = "#experiments";
	    }
	    $('.nav-tabs a[href="'+hash+'"]').tab('show');
	});

	LoadExperimentTab();
	LoadClassicExperiments();
	LoadMembersTab();
	LoadInfoTab();
    }

    function LoadExperimentTab()
    {
	var callback = function(json) {
	    console.info(json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		$('#experiments_loading').addClass("hidden");
		$('#experiments_noexperiments').removeClass("hidden");
		return;
	    }
	    var template = _.template(experimentString);

	    $('#experiments_content')
		.html(template({"experiments" : json.value,
				"showCreator" : true,
				"showProject" : false,
				"showPortal"  : false,
				"searchUUID"  : false,
				"showterminate" : false,
			       }));
	    
	    // Format dates with moment before display.
	    $('#experiments_table .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    var table = $('#experiments_table')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});
	}
	var xmlthing = sup.CallServerMethod(null,
					    "groups", "ExperimentList",
					    {"pid" : window.TARGET_PROJECT,
					     "gid" : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    function LoadClassicExperiments()
    {
	var callback = function(json) {
	    console.info("classic", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0)
		return;
	    
	    var template = _.template(classicString);

	    $('#classic_experiments_content')
		.html(template({"experiments" : json.value,
				"showCreator" : true,
				"showProject" : false,
				"asProfiles"  : false}));
	    
	    // Format dates with moment before display.
	    $('#classic_experiments_content .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    var table = $('#classic_experiments_content .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});
	};
	var xmlthing = sup.CallServerMethod(null,
					    "groups", "ClassicExperimentList",
					    {"pid" : window.TARGET_PROJECT,
					     "gid" : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    function ShowTopology(profile)
    {
	var index;

	var callback = function(json) {
	    if (json.code) {
		alert("Failed to get rspec for topology viewer: " + json.value);
		return;
	    }
	    sup.ShowModal("#quickvm_topomodal");
	    $("#quickvm_topomodal").one("shown.bs.modal", function () {
		sup.maketopmap('#showtopo_nopicker',
			       json.value.profile_rspec, false, !window.ISADMIN);
	    });
	};
	var $xmlthing = sup.CallServerMethod(null,
					     "show-profile",
					     "GetProfile",
				     	     {"uuid" : profile});
	$xmlthing.done(callback);
    }

    // We want to warn just once.
    var WarnedAboutUserPrivs = false;

    function LoadMembersTab()
    {
	// Watch for form modifications.
	var modified = false;

	// Kill previous handler.
	$(window).off('beforeunload.portal');

	// Warn user if they have not saved changes.
	$(window).on('beforeunload.portal', function() {
	    if (! modified)
		return undefined;
	    return "You have unsaved changes!";
	});
	
	var callback = function(json) {
	    console.info("members", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		return;
	    }
	    var template = _.template(memberString);

	    $('#members_content')
		.html(template({"members"    : json.value.members,
				"nonmembers" : json.value.nonmembers,
				"pid"        : window.TARGET_PROJECT,
				"gid"        : window.TARGET_GROUP,
				"canedit"    : window.CANEDIT,
				"canapprove" : window.CANAPPROVE,
				"canbestow"  : window.CANBESTOW}));
	    
	    // Format dates with moment before display.
	    $('#members_table .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    $('#members_table, #nonmembers_table')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra"],
		    headerTemplate : '{content} {icon}',
		});

	    // Do this after converting table.
	    $('[data-toggle="tooltip"]').tooltip({
		trigger: 'hover',
		placement: 'auto',
	    });
	    // Do this after converting table.
	    $('[data-toggle="popover"]').popover({
		trigger: 'hover',
		placement: 'auto',
	    });

	    // Bind edit privs selection
	    $('#members_table .editprivs')
		.on('focusin', function() {
		    // Remember trust before change.
		    $(this).data('val', $(this).val());
		})
		.change(function () {
		    if ($(this).val() == "user" && !WarnedAboutUserPrivs) {
			sup.ShowModal('#confirm-user-privs-modal');
			WarnedAboutUserPrivs = true;
			var which = $(this);
			$('#cancel-user-privs').click(function () {
			    $(which).val($(which).data('val'));
			});
			$('#confirm-user-privs').click(function () {
			    DoEditPrivs($(which).data("uid"), $(which).val());
			});
			return;
		    }
		    DoEditPrivs($(this).data("uid"), $(this).val());
		});

	    // Enable the remove button when users are selected.
	    $('#members_table .remove-checkbox').change(function () {
		$('#remove-users-button').removeAttr("disabled");
	    });
	    // Handler for the remove confirm button.
	    $('#confirm-remove-users').click(function () {
		sup.HideModal('#confirm-remove-users-modal');
		DoRemoveUsers();
	    });
	    // Enable the update button when permissions are changed.
	    $('#nonmembers_table .editprivs')
		.change(function () {
		    $('#add-users-button').removeAttr("disabled");
		    if ($(this).val() == "user" && !WarnedAboutUserPrivs) {
			sup.ShowModal('#confirm-user-privs-modal');
			WarnedAboutUserPrivs = true;
			var which = $(this);
			$('#cancel-user-privs').click(function () {
			    $(which).val("none");
			});
		    }
		});
	    // Handler for the add confirm button.
	    $('#confirm-add-users').click(function () {
		sup.HideModal('#confirm-add-users-modal');
		DoAddUsers();
	    });
	    // Watch for unsaved modifications.
	    $('#nonmembers_table .editprivs, #members_table .remove-checkbox')
		.change(function () {
		    console.info("changed");
		    modified = true;
		});
	}
	var xmlthing = sup.CallServerMethod(null,
					    "groups", "MemberList",
					    {"pid" : window.TARGET_PROJECT,
					     "gid" : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    // Approve or Deny.
    function DoApproval(uid, action)
    {
	console.info(uid, action);

	var callback = function(json) {
	    sup.HideWaitWait();

	    // Always reload.
	    LoadMembersTab();
	    
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	}
	sup.ShowWaitWait();
	var xmlthing =
	    sup.CallServerMethod(null, "groups", "EditMembership",
				 {"users"    : [uid],
				  "action"   : action,
                                  "pid"      : window.TARGET_PROJECT,
                                  "gid"      : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    // Edit privs
    function DoEditPrivs(uid, priv)
    {
	console.info(uid, priv);

	var callback = function(json) {
	    sup.HideWaitWait();

	    // Always reload.
	    LoadMembersTab();
	    
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	}
	sup.ShowWaitWait("We are modifying privs ... patience please");
	var xmlthing =
	    sup.CallServerMethod(null, "groups", "EditPrivs",
				 {"user_uid" : uid,
				  "priv"     : priv,
                                  "pid"      : window.TARGET_PROJECT,
                                  "gid"      : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    // Remove users.
    function DoRemoveUsers()
    {
	// Find list of selected users.
	var selected_users = {};

	$('.remove-checkbox').each(function () {
	    if ($(this).is(":checked")) {
		var uid = $(this).data("uid");
		
		selected_users[uid] = "none";
	    }
	});
	if (! Object.keys(selected_users).length) {
	    return;
	}
	var callback = function(json) {
	    sup.HideWaitWait();

	    // Always reload.
	    LoadMembersTab();
	    
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	}
	sup.ShowWaitWait("We are removing users from this group ... " +
			 "patience please");
	var xmlthing =
	    sup.CallServerMethod(null, "groups", "EditMembership",
				 {"users"  : selected_users,
				  "action" : "remove",
                                  "pid"    : window.TARGET_PROJECT,
                                  "gid"    : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    function DoAddUsers(checkonly)
    {
	// Find list of selected users.
	var selected_users = {};

	$('#nonmembers_table .editprivs').each(function () {
	    var uid  = $(this).data("uid");
	    var priv = $(this).val();

	    if (priv != "none") {
		selected_users[uid] = priv;
	    }
	});
	if (! Object.keys(selected_users).length) {
	    return 1;
	}
	console.info("addusers", selected_users);

	var callback = function(json) {
	    sup.HideWaitWait();

	    // Always reload.
	    LoadMembersTab();
	    
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	}
	sup.ShowWaitWait("We are adding users to this group ... " +
			 "patience please");
	var xmlthing =
	    sup.CallServerMethod(null, "groups", "EditMembership",
				 {"users"  : selected_users,
				  "action" : "add",
                                  "pid"    : window.TARGET_PROJECT,
                                  "gid"    : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    function LoadInfoTab()
    {
	var callback = function(json) {
	    console.info(json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		return;
	    }
	    var template = _.template(detailsString);

	    $('#info_content')
	    	.html(template({"fields"     : json.value,
				"candelete"  : window.CANDELETE}));
	    $('#admin_content')
		.html(template({"fields"     : json.value,
				"candelete"  : window.CANDELETE}));
	    
	    // Format dates with moment before display.
	    $('#profile_table .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    // Hook up the delete (confirm) button.
	    if (window.CANDELETE) {
		$('#confirm-delete-group')
		    .click(function () {
			DoDeleteGroup();
		    });
	    }
	}
	var xmlthing = sup.CallServerMethod(null,
					    "groups", "GroupProfile",
					    {"pid" : window.TARGET_PROJECT,
					     "gid" : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    function DoDeleteGroup()
    {
	var callback = function(json) {
	    sup.HideWaitWait();
	    if (json.code) {
		console.info(json.value);
		sup.SpitOops("oops", "Failed to delete group: " + json.value);
		return;
	    }
	    window.location.replace(json.value);
	}
	sup.HideModal("#confirm-delete-modal");
	sup.ShowWaitWait("Removing group, this will take a minute ... or two");
	var xmlthing = sup.CallServerMethod(null,
					    "groups", "Delete",
					    {"pid" : window.TARGET_PROJECT,
					     "gid" : window.TARGET_GROUP});
	xmlthing.done(callback);
    }

    $(document).ready(initialize);
});


