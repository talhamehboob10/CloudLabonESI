$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['approve-projects',
						   'project-approval-list',
						   'waitwait-modal',
						   'oops-modal']);

    var mainString     = templates['approve-projects'];
    var listString     = templates['project-approval-list'];
    var waitwaitString = templates['waitwait-modal'];
    var oopsString     = templates['oops-modal'];
    var table          = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#page-body').html(mainString);
	$('#oops_div').html(oopsString);
	$('#waitwait_div').html(waitwaitString);
	
	LoadTable();
    }

    function LoadTable()
    {
	var callback = function(json) {
	    console.info(json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    var template = _.template(listString);
	    var html = template({"projects" : json.value});
	    $('#projects-content').html(html);
	    InitTable();
	    SetupActionButtons();
	    SetupProjectWhy();
	    $('#projects-loading').addClass("hidden");
	    $('#projects-loaded').removeClass("hidden");
	};
	sup.CallServerMethod(null, "approve-projects", "ProjectList",
			     null, callback);
    }

    function InitTable()
    {
	var tablename  = "#projects-table";
	var searchname = "#projects-search";

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html())
			     .format("ll"));
	    }
	});

	table = $(tablename)
		.tablesorter({
		    theme : 'bootstrap',
		    widgets: ["uitheme", "zebra", "filter", "resizable"],
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
		    }
		});
	// Bind the search box.
	$.tablesorter.filter.bindSearch(table, $(searchname));

	// Initial sort.
	table.find('th:eq(2)').trigger('sort');	
    }

    //
    // Setup the action modals and buttons.
    //
    function SetupActionButtons()
    {
	$(".approve-button").click(function (event) {
	    event.preventDefault();
	    var pid  = $(this).closest('tr').data("pid");
	    $("#approve-confirm").click(function(event) {
		event.preventDefault();
		Approve(pid);
	    });
	    sup.ShowModal("#approve-modal",
			  function () {
			      $("#approve-confirm").off("click");
			  });
	});
	$(".deny-button").click(function (event) {
	    event.preventDefault();
	    var pid  = $(this).closest('tr').data("pid");
	    $("#deny-confirm").click(function(event) {
		event.preventDefault();
		Deny(pid);
	    });
	    sup.ShowModal("#deny-modal",
			  function () {
			      $("#deny-confirm").off("click");
			  });
	});
	$(".request-info-button").click(function (event) {
	    event.preventDefault();
	    var pid  = $(this).closest('tr').data("pid");
	    $("#request-info-confirm").click(function(event) {
		event.preventDefault();
		MoreInfo(pid);
	    });
	    sup.ShowModal("#request-info-modal",
			  function () {
			      $("#request-info-confirm").off("click");
			  });
	});
    }

    //
    // Setup the description textareas for editing/save.
    //
    function SetupProjectWhy()
    {
	$('.collapse').on('show.bs.collapse', function () {
	    var pid  = $(this).closest('tr').data("pid");
	    var chev = "#chevron-" + pid;
	    $(chev).removeClass("glyphicon-chevron-right");
	    $(chev).addClass("glyphicon-chevron-down");
	});
	$('.collapse').on('hide.bs.collapse', function () {
	    var pid  = $(this).closest('tr').data("pid");
	    var chev = "#chevron-" + pid;
	    $(chev).removeClass("glyphicon-chevron-down");
	    $(chev).addClass("glyphicon-chevron-right");
	});
	$(".project-why")
	    .on("change input paste keyup", function() {
		var pid  = $(this).closest('tr').data("pid");
		var save = "#why-save-button-" + pid;
		$(save).removeClass('hidden');
	    });
	$('.why-save-button').click(function (event) {
	    event.preventDefault();
	    var pid  = $(this).closest('tr').data("pid");
	    var save = "#why-save-button-" + pid;
	    SaveProjectWhy(this, function () {
		    $(save).addClass('hidden');
	    });
	});
    }
    // Target is the textarea that changed, need to find the pid from <tr>
    function SaveProjectWhy(target, done)
    {
	var pid  = $(target).closest('tr').data("pid");
	var area = "#textarea-" + pid;
	var description = $(area).val();
	
	console.info("SaveProjectWhy: ", pid, description);

	var callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", "Failed to save project description: " +
			     json.value);
		return;
	    }
	    done();
	};
    	var xmlthing = sup.CallServerMethod(null, "approve-projects",
					    "SaveDescription",
					    {"pid"  : pid,
					     "description" : description});
	xmlthing.done(callback);
    }

    // Request more info.
    function MoreInfo(pid)
    {
	var message = $('#info-body').val();
	sup.HideModal("#request-info-modal");
	console.info("MoreInfo", pid, message);

	var callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", "Failed to send request for more info: " +
			     json.value);
		return;
	    }
	};
    	var xmlthing = sup.CallServerMethod(null, "approve-projects",
					    "MoreInfo",
					    {"pid"      : pid,
					     "message"  : message});
	xmlthing.done(callback);
    }
    
    // Approve
    function Approve(pid)
    {
	sup.HideModal("#approve-modal");
	var message = $('#approve-body').val();
	console.info("Approve", pid, message);

	var callback = function(json) {
	    sup.HideWaitWait();
	    if (json.code) {
		sup.SpitOops("oops", "Failed to approve project: " +
			     json.value);
		return;
	    }
	    // Remove the project from the list. There are two rows.
	    $('tr[data-pid="' + pid + '"]').remove();
	    table.trigger('update');

	    // First project.
	    if (json.value) {
		sup.ShowModal('#first-project-modal');
	    }
	};
	sup.ShowWaitWait("Approving project, this takes a minute or two. " +
			 "Patience please.");
    	var xmlthing = sup.CallServerMethod(null, "approve-projects",
					    "Approve",
					    {"pid"      : pid,
					     "message"  : message});
	xmlthing.done(callback);
    }
    
    // Deny
    function Deny(pid)
    {
	sup.HideModal("#deny-modal");
	var message = $('#deny-body').val();
	var deleteuser = ($('#deny-delete-user').is(":checked") ? 1 : 0);
	var silent = ($('#deny-silent').is(":checked") ? 1 : 0);
	console.info("Deny", pid, message, deleteuser, silent);

	var callback = function(json) {
	    sup.HideWaitWait();
	    if (json.code) {
		sup.SpitOops("oops", "Failed to destroy project: " +
			     json.value);
		return;
	    }
	    // Remove the project from the list. There are two rows.
	    $('tr[data-pid="' + pid + '"]').remove();
	    table.trigger('update');
	};
	sup.ShowWaitWait("Destroying project, this takes a minute. " +
			 "Patience please.");
    	var xmlthing = sup.CallServerMethod(null, "approve-projects",
					    "Deny",
					    {"pid"        : pid,
					     "message"    : message,
					     "deleteuser" : deleteuser,
					     "silent"     : silent});
	xmlthing.done(callback);
    }
    
    $(document).ready(initialize);
});
