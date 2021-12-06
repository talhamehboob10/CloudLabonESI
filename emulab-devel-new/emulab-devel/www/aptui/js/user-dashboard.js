$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['user-dashboard',
	   'experiment-list', 'profile-list', 'project-list', 'dataset-list', 
	   'user-profile', 'oops-modal', 'waitwait-modal', 'classic-explist',
	   'conversion-help-modal','paramsets-list']);
    var mainString = templates['user-dashboard'];
    var experimentString = templates['experiment-list'];
    var profileListString = templates['profile-list'];
    var projectString = templates['project-list'];
    var datasetString = templates['dataset-list'];
    var profileString = templates['user-profile'];
    var oopsString = templates['oops-modal'];
    var waitwaitString = templates['waitwait-modal'];
    var classicString = templates['classic-explist'];
    var converterHelpTemplate = _.template(templates['conversion-help-modal']);
    var mainTemplate = _.template(mainString);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	// Generate the main template.
	var html = mainTemplate({
	    disabledset : window.UI_DISABLE_DATASETS,
	    disabledres : window.UI_DISABLE_RESERVATIONS,
	    emulablink  : window.EMULAB_LINK,
	    isadmin     : window.ISADMIN,
	    target_user : window.TARGET_USER,
	});
	$('#main-body').html(html);
	$('#oops_div').html(oopsString);
	$('#waitwait_div').html(waitwaitString);
	$('#conversion_help_div').html(converterHelpTemplate({}));

	// Focus on the search box when switching to these tabs.
        $('.nav-tabs a[href="#profiles"], ' +
	  '.nav-tabs a[href="#projectprofiles"]')
	    .on('shown.bs.tab', function (e) {
		var target = $(this).attr("href");
		var searchbox = $(target).find(".profile-search");
		if ($(searchbox)[0]) {
		    $(searchbox)[0].focus();
		}
	    });

        // Javascript to enable link to tab
        var hash = document.location.hash;
        if (hash) {
            $('.nav-tabs a[href="'+hash+'"]').tab('show');
        }
        // Change hash for page-reload
        $('a[data-toggle="tab"]').on('show.bs.tab', function (e) {
	    history.replaceState('', '', e.target.hash);

	    // GA reporting
	    var ganame = e.target.hash;
	    if (ganame == "") {
		ganame = "#experiments";
	    }
	    window.APT_OPTIONS.gaTabEvent("show", ganame);
        });
	// Set the correct tab when a user uses their back/forward button
        $(window).on('hashchange', function (e) {
	    var hash = window.location.hash;
	    if (hash == "") {
		hash = "#experiments";
	    }
	    $('.nav-tabs a[href="'+hash+'"]').tab('show');
	});

	LoadUsage();
	LoadExperimentTab();
	LoadClassicExperiments();
	// Should we do these on demand?
	LoadProfileListTab();
	LoadProjectProfiles();
	LoadClassicProfiles();
	LoadProjectsTab();
	LoadProfileTab();
	LoadDatasetTab();
	LoadResgroupTab();
	LoadParameterSetsTab();
	LoadClassicDatasets();

	/*
	 * Handlers for inline operations.
	 */
	$('#sendtestmessage').click(function () {
	    SendTestMessage();
	});
	$('#sendpasswordreset').click(function () {
	    SendPasswordReset();
	});
	$('#confirm-deleteuser').click(function () {
	    DeleteUser();
	});
    }

    // Call back for bulk delete to remove the row from both tables.
    function DeleteProfileRows(uuid, json)
    {
	// The profile will exist in two tables ...
	$('#profiles_content tr[data-uuid="' + uuid + '"]').remove();
	$('#projectprofiles_content tr[data-uuid="' + uuid + '"]').remove();
    }

    function LoadUsage()
    {
	var callback = function(json) {
	    console.info("LoadUsage", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    var blob = json.value;
	    var html = "";
	    if (!(blob.pnodes || blob.weekpnodes ||
		  blob.monthpnodes || blob.rank)) {
		$('#usage_nousage').removeClass("hidden");
		return;
	    }
	    if (blob.pnodes) {
		html = "<tr><td>Current Usage:</td><td>" +
		    blob.pnodes + " Node" + (blob.pnodes > 1 ? "s, " : ", ") +
		    blob.phours + " Node Hours</td></tr>";
	    }
	    if (blob.weekpnodes) {
		html = html + "<tr><td>Previous Week:</td><td>" +
		    blob.weekpnodes + " Node" +
		    (blob.weekpnodes > 1 ? "s, " : ", ") +
		    blob.weekphours + " Node Hours</td></tr>";
	    }
	    if (blob.monthpnodes) {
		html = html + "<tr><td>Previous Month:</td><td> " +
		    blob.monthpnodes + " Node" +
		    (blob.monthpnodes > 1 ? "s, " : ", ") +
		    blob.monthphours + " Node Hours</td></tr>";
	    }
	    if (blob.rank) {
		html = html +
		    "<tr><td>" + blob.rankdays + " Day Usage Ranking:</td><td>#" +
		    blob.rank + " of " + blob.ranktotal + " active users" +
		    "</td></tr>";
	    }
	    $('#usage_table tbody').html(html);
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "UsageSummary",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
	
    }

    function LoadExperimentTab()
    {
	var template = _.template(experimentString);
	
	var callback = function(json) {
	    console.info("experiments", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.user_experiments.length == 0) {
		$('#experiments_loading').addClass("hidden");
		$('#experiments_noexperiments').removeClass("hidden");
	    }
	    else {
		$('#experiments_content')
		    .html(template({"experiments" : json.value.user_experiments,
				    "showCreator" : false,
				    "showProject" : true,
				    "showPortal"  : false,
				    "searchUUID"  : false,
				    "showterminate" : true}));
	    }
	    if (json.value.project_experiments.length != 0) {
		$('#project_experiments_content')
		    .html("<div><h4 class='text-center'>" +
			  "Experiments in my Projects</h4>" +
			  template({"experiments" :
				        json.value.project_experiments,
				    "showCreator" : true,
				    "showProject" : true,
				    "showPortal"  : false,
				    "searchUUID"  : false,
				    "showterminate" : false}) +
			  "</div>");
	    }
	    // Format dates with moment before display.
	    $('#experiments_content .format-date, ' +
	      '#project_experiments_content .format-date')
		.each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    if (json.value.user_experiments.length != 0) {
		$('#experiments_content #experiments_table')
		    .tablesorter({
			theme : 'bootstrap',
			widgets : [ "uitheme" ],
			headerTemplate : '{content} {icon}',			
		    });
	    }
	    if (json.value.project_experiments.length != 0) {
		$('#project_experiments_content #experiments_table')
		    .tablesorter({
			theme : 'bootstrap',
			widgets : [ "uitheme", ],
			headerTemplate : '{content} {icon}',
		    });
	    }
	    // Terminate an experiment.
	    $('#experiments_content .terminate-button').click(function (event) {
		event.preventDefault();
		TerminateExperiment(this);
	    });
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "ExperimentList",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    // Terminate an experiment
    function TerminateExperiment(target)
    {
	console.info($(target), $(target).data("uuid"));
	var uuid = $(target).data("uuid");

	var callback = function(json) {
	    sup.HideWaitWait();
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Reload the experiments tab. Easier.
	    LoadExperimentTab();
	};
	// Bind the confirm button in the modal. 
	$('#terminate-modal #terminate-confirm').click(function () {
	    sup.HideModal('#terminate-modal', function () {
		sup.ShowModal('#waitwait-modal');
		var xmlthing = sup.CallServerMethod(null, "status",
						    "TerminateInstance",
						    {"uuid" : uuid});
		xmlthing.done(callback);
	    });
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#terminate-modal').on('hidden.bs.modal', function (e) {
	    $('#terminate-modal #terminate-confirm').unbind("click");
	    $('#terminate-modal').off('hidden.bs.modal');
	});
	sup.ShowModal("#terminate-modal");
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
				"showCreator" : false,
				"showProject" : true,
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
		    widgets : [ "uitheme", ],
		    headerTemplate : '{content} {icon}',
		});
	};
	var xmlthing = sup.CallServerMethod(null,
				    "user-dashboard", "ClassicExperimentList",
				    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadProfileListTab()
    {
	var callback = function(json) {
	    console.info("LoadProfileListTab", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		$('#profiles_noprofiles').removeClass("hidden");
		return;
	    }
	    var template = _.template(profileListString);

	    $('#profiles_content')
		.html(template({"profiles"    : json.value,
				"tablename"   : "user-profiles",
				"bulkdelete"  : true,
				"showCreator" : false,
				"showProject" : true,
				"showPrivacy" : true}));
	    
	    // Format dates with moment before display.
	    $('#user-profiles-table .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    // This activates the tooltip subsystem.
	    $('[data-toggle="tooltip"]').tooltip({
		delay: {"hide" : 100, "show" : 300},
		placement: 'auto',
	    });
	    // Display the topo.
	    $('.showtopo_modal_button').click(function (event) {
		event.preventDefault();
		ShowTopology($(this).data("profile"));
	    });
	    // Delete profile button
	    $('#profiles_content .delete-profile-button')
		.click(function (event) {
		    event.preventDefault();
		    var row = $(this).closest("tr");
		    var profile_uuid = $(row).data("uuid");
		    
		    profileSupport
			.Delete(profile_uuid, function () {
			    $(row).remove();
			});
		});

	    // If this is the active tab after loading, focus the searchbox
	    if ($('#profiles').hasClass("active")) {
		var searchbox = $('#profiles .profile-search')
		if ($(searchbox)[0]) {
		    $(searchbox)[0].focus();
		}
	    }
	    
	    var table = $('#' + 'user-profiles-table')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "filter"],
		    headerTemplate : '{content} {icon}',
		    widgetOptions: {
			// include child row content while filtering, if true
			filter_childRows  : true,
			// include all columns in the search.
			filter_anyMatch   : true,
			// class name applied to filter row and each input
			filter_cssFilter  : 'form-control input-sm',
			// search from beginning
			filter_startsWith : false,
			// Set this option to false for case sensitive search
			filter_ignoreCase : true,
			// Only one search box.
			filter_columnFilters : false,
			// Search as typing
			filter_liveSearch : true,
		    },
		});
	    $.tablesorter.filter.bindSearch(table,
					    $('#' + 'user-profiles-search'));

	    // Delete multiple profiles via the checkbox column.
	    $('#profiles_content .delete-selected-profiles')
		.click(function (event) {
		    event.preventDefault();
		    profileSupport
			.DeleteSelected('#profiles_content',
					function (uuid, json) {
					    DeleteProfileRows(uuid, json);
					});
		});
	    
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "ProfileList",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadProjectProfiles()
    {
	var callback = function(json) {
	    console.info("LoadProjectProfiles", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		return;
	    }
	    var template = _.template(profileListString);

	    $('#projectprofiles_content')
		.html(template({"profiles"    : json.value,
				"tablename"   : "project-profiles",
				"bulkdelete"  : false,
				"showCreator" : true,
				"showProject" : true,
				"showPrivacy" : true}));
	    
	    // Format dates with moment before display.
	    $('#project-profiles-table .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    // This activates the tooltip subsystem.
	    $('[data-toggle="tooltip"]').tooltip({
		delay: {"hide" : 100, "show" : 300},
		placement: 'auto',
	    });
	    // Display the topo.
	    $('.showtopo_modal_button').click(function (event) {
		event.preventDefault();
		ShowTopology($(this).data("profile"));
	    });
	    // Delete profile button
	    $('#projectprofiles_content .delete-profile-button')
		.click(function (event) {
		    event.preventDefault();
		    var row = $(this).closest("tr");
		    var profile_uuid = $(row).data("uuid");
		    
		    profileSupport.Delete(profile_uuid, 
					  function (uuid, json) {
					      DeleteProfileRows(uuid, json);
					  });
		    
		});
	    // If this is the active tab after loading, focus the searchbox
	    if ($('#projectprofiles').hasClass("active")) {
		var searchbox = $('#projectprofiles .profile-search')
		if ($(searchbox)[0]) {
		    $(searchbox)[0].focus();
		}
	    }
	    
	    var table = $('#' + 'project-profiles-table')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "filter"],
		    headerTemplate : '{content} {icon}',
		    widgetOptions: {
			// include child row content while filtering, if true
			filter_childRows  : true,
			// include all columns in the search.
			filter_anyMatch   : true,
			// class name applied to filter row and each input
			filter_cssFilter  : 'form-control input-sm',
			// search from beginning
			filter_startsWith : false,
			// Set this option to false for case sensitive search
			filter_ignoreCase : true,
			// Only one search box.
			filter_columnFilters : false,
			// Search as typing
			filter_liveSearch : true,
		    },
		});
	    $.tablesorter.filter.bindSearch(table,
					    $('#' + 'project-profiles-search'));

	    // Lets not show this on the project profiles tab yet.
	    if (0) {
		// Delete multiple profiles via the checkbox column.
		$('#projectprofiles_content .delete-selected-profiles')
		    .click(function (event) {
			event.preventDefault();
			profileSupport
			    .DeleteSelected('#projectprofiles_content',
					    function (uuid, json) {
						DeleteProfileRows(uuid, json);
					    });
		    });
	    }
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard",
					    "ProjectProfileList",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadClassicProfiles()
    {
	var callback = function(json) {
	    console.info("classic profiles", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    var template = _.template(classicString);

	    $('#classic_profiles_content')
		.html(template({"experiments" : json.value,
				"showCreator" : false,
				"showProject" : true,
				"asProfiles"  : true}));
	    
	    $('#classic_profiles_content .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    var table = $('#classic_profiles_content .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme"],
		    headerTemplate : '{content} {icon}',
		});
	};
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "ClassicProfileList",
					    {"uid" : window.TARGET_USER});
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

    function LoadProjectsTab()
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
	    var template = _.template(projectString);

	    $('#membership_content')
		.html(template({"projects" : json.value}));

	    var table = $('#projects_table')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme"],
		    headerTemplate : '{content} {icon}',
		});
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "ProjectList",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    /*
     * We actually display two profile tabs, one for the non-admin view,
     * which is always the same. The other for the admin view. 
     */

    function LoadProfileTab()
    {
	var callback = function(json) {
	    console.info(json.value);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		return;
	    }
	    var template = _.template(profileString);

	    if (window.ISADMIN) {
		$('#admin_content')
		    .html(template({"fields"  : json.value,
				    "isadmin" : 1}));

		// Format dates with moment before display.
		$('#admin_content .format-date').each(function() {
		    var date = $.trim($(this).html());
		    if (date != "") {
			$(this).html(moment($(this).html()).format("ll"));
		    }
		});
		$('#admin_content .toggle').click(function() {
		    Toggle(this);
		});
		// Freeze or Thaw.
		if (json.value.status == "active" ||
		    json.value.status == "frozen") {
		    if (json.value.status == "active") {
			$('#admin_content .freeze').html("Freeze");
		    }
		    else {
			$('#admin_content .freeze').html("Thaw");
		    }
		    $('#admin_content .freezethaw').removeClass("hidden");
		    $('#admin_content .freeze').click(function (event) {
			FreezeOrThaw(json.value.status);
		    });
		}
	    }
	    $('#myprofile_content')
		.html(template({"fields"  : json.value,
				"isadmin" : 0}));
	    // Format dates with moment before display.
	    $('#myprofile_content .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "AccountDetails",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadDatasetTab()
    {
	var callback = function(json) {
	    console.info("datasets", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		$('#datasets_nodatasets').removeClass("hidden");
		return;
	    }
	    var template = _.template(datasetString);

	    $('#datasets_content')
		.html(template({"datasets"    : json.value,
				"showcluster" : true,
				"showuser"    : false,
				"showproject" : true}));
	    
	    // Format dates with moment before display.
	    $('#datasets_content .tablesorter .format-date').each(function(){
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    var table = $('#datasets_content .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme"],
		    headerTemplate : '{content} {icon}',
		});
	}
	var xmlthing =
	    sup.CallServerMethod(null,
				 "user-dashboard", "DatasetList",
				 {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadResgroupTab()
    {
	var callback = function(json) {
	    console.info("resgroup", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    var userlist = json.value.user;
	    var projlist = json.value.project;
	    
	    if (! (_.size(userlist) || _.size(projlist))) {
		return;
	    }
	    $(".resgroups-hidden").removeClass("hidden");
	    window.DrawResGroupList("#resgroups_content", userlist);
	    $("#resgroups_content .expando").trigger("click");

	    /*
	     * Prune out project reservations in the table above,
	     * and if any left, show those in another table below.
	     */
	    for (var uuid in userlist) {
		if (_.has(projlist, uuid)) {
		    delete projlist[uuid];
		}
	    }
	    if (! _.size(projlist)) {
		return;
	    }
	    $("#project_resgroups").removeClass("hidden");
	    console.info("new projlist", projlist);
	    window.DrawResGroupList("#project_resgroups_content", projlist);
	}
	var xmlthing =
	    sup.CallServerMethod(null,
				 "user-dashboard", "ResgroupList",
				 {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadParameterSetsTab()
    {
	var paramsets_table;
	
	var callback = function(json) {
	    console.info("paramsets", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (! json.value) {
		$('#paramsets_noparamsets').removeClass("hidden");
		return;
	    }
	    var template = _.template(templates["paramsets-list"]);

	    // Temporary until new geni-lib/ppwizard rolled out
	    $('.paramsets-hidden').removeClass("hidden");
	    
	    $('#paramsets_content')
		.html(template({"paramsets"   : json.value,
				"isadmin"     : window.ISADMIN}));

	    // Bind the delete button.
	    $('#paramsets_content #delete-paramset-button')
		.click(function (event) {
		    event.preventDefault();
		    var row = $(this).closest("tr");
		    var paramset_uuid = $(row).attr("data-uuid");

		    paramsets.InitDeleteParameterSet(window.TARGET_USER,
						     paramset_uuid,
			     function () {
				 $(row).remove();
				 paramsets_table.trigger('update');
			     });
		});

	    sup.addPopoverClip('#paramsets_content .paramset-share-button',
			       function (target) {
				   $(target).parent().popover('hide');
				   var url = $(target).attr("href");
				   return sup.popoverClipContent(url);
			       });
	    
	    
	    // Format dates with moment before display.
	    $('#paramsets_content table .format-date').each(function(){
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    // This activates the tooltip subsystem.
	    $('#paramsets_content [data-toggle="tooltip"]').tooltip({
		delay: {"hide" : 100, "show" : 300},
		placement: 'auto',
	    });
	    // This activates the popover subsystem.
	    $('#paramsets_content [data-toggle="popover"]').popover({
		placement: 'auto',
	    });
	    
	    paramsets_table = $('#paramsets_content .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme"],
		    headerTemplate : '{content} {icon}',
		});
	}
	var xmlthing =
	    sup.CallServerMethod(null,
				 "user-dashboard", "ListParameterSets",
				 {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function LoadClassicDatasets()
    {
	var callback = function(json) {
	    console.info("classic datasets", json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    if (json.value.length == 0) {
		return
	    }
	    $('#classic_datasets_content').removeClass("hidden");
	    var template = _.template(datasetString);

	    $('#classic_datasets_content_div')
		.html(template({"datasets"    : json.value,
				"showcluster" : false,
				"showuser"    : false,
				"showproject" : true}));
	    
	    $('#classic_datasets_content .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    var table = $('#classic_datasets_content .tablesorter')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme" ],
		    headerTemplate : '{content} {icon}',
		});
	};
	var xmlthing =
	    sup.CallServerMethod(null,
				 "user-dashboard", "ClassicDatasetList",
				 {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    //
    // Toggle flags.
    //
    function Toggle(item) {
	var name = item.dataset["name"];
	var wait = false;

	// These take longer to show the wait modal.
	if (name == "admin" || name == "inactive") {
	    sup.ShowWaitWait();
	    wait = true;
	}
	var callback = function(json) {
	    if (json.code) {
		if (wait) {
		    sup.HideWaitWait(function () {
			sup.SpitOops("oops", json.value);
		    });
		}
		else {
		    sup.SpitOops("oops", json.value);
		}
		return;
	    }
	    if (wait) {
		sup.HideWaitWait();
	    }
	    LoadProfileTab();
	};
	sup.CallServerMethod(null, "user-dashboard", "Toggle",
			     {"uid" : window.TARGET_USER,
			      "toggle" : name},
			     callback);
    }

    //
    // Freeze or Thaw
    //
    function FreezeOrThaw(status) {
	var tag = (status == "active" ? "Freeze" : "Thaw");

	console.info("FreezeOrThaw: ", status, tag);
	
	// Handler for hide modal to unbind the click handler.
	$('#confirm-freezethaw-modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm-freezethaw').unbind("click.freezethaw");
	});
	$('#confirm-freezethaw').bind("click.freezethaw", function (event) {
	    var callback = function(json) {
		sup.HideWaitWait();
	    
		if (json.code) {
		    sup.SpitOops("oops",
				 "Failed to " + tag + " user");
		    return;
		}
		LoadProfileTab();
	    };
	    var doit = function () {
		var args = {
		    "uid"   : window.TARGET_USER,
		    "which" : tag,
		};
		var message = $('#confirm-freezethaw-modal .user-message')
		    .val().trim();
		if (message != "") {
		    args["message"] = message;
		}
		sup.ShowWaitWait("This will take a minute. Patience please.");
		var xmlthing =
		    sup.CallServerMethod(null, "user-dashboard",
					 "FreezeOrThaw", args);
		xmlthing.done(callback);
	    };
	    sup.HideModal('#confirm-freezethaw-modal', doit);
	});
	$('#confirm-freezethaw-modal .which').html(tag);
	sup.ShowModal('#confirm-freezethaw-modal');
    }

    function SendTestMessage()
    {
	var callback = function(json) {
	    if (json.code) {
		alert("Test message could not be sent!");
		return;
	    }
	    alert("Test message has been sent");
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard", "SendTestMessage",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function SendPasswordReset()
    {
	var callback = function(json) {
	    if (json.code) {
		alert("Password reset could not be sent!");
		return;
	    }
	    alert("Password reset has has been sent");
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard",
					    "SendPasswordReset",
					    {"uid" : window.TARGET_USER});
	xmlthing.done(callback);
    }

    function DeleteUser()
    {
	var callback = function(json) {
	    if (json.code) {
		sup.HideWaitWait(function () {
		    sup.SpitOops("oops", json.value);
		});
		return;
	    }
	    window.location.replace("landing.php");
	}
	var xmlthing = sup.CallServerMethod(null,
					    "user-dashboard",
					    "DeleteUser",
					    {"uid" : window.TARGET_USER});
	
	sup.HideModal('#confirm-deleteuser-modal', function () {
	    sup.ShowWaitWait("This will take a minute. Patience please.");
	    xmlthing.done(callback);
	});
    }

    $(document).ready(initialize);
});
