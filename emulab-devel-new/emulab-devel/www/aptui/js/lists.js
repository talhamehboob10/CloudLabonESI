$(function ()
{
    'use strict';
  
    var templates = APT_OPTIONS.fetchTemplateList(['lists']);
    var mainTemplate    = _.template(templates['lists']);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	var userlist = decodejson('#users-json');
	var projlist = decodejson('#projects-json');
	
	// Generate the main template.
	var html = mainTemplate({
	    "users"     : userlist,
	    "projects"  : projlist,
	});
	$('#main-body').html(html);
	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    delay: {"hide" : 500, "show" : 150},
	    placement: 'auto',
	});
	InitTable("users");
	InitTable("projects");

	// Start out as empty tables.
	$('#search_users_table')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });
	
	$('#search_projects_table')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });

        // Javascript to enable link to tab
        var hash = document.location.hash;
        if (hash) {
            $('.nav-tabs a[href="'+hash+'"]').tab('show');
        }
        // Change hash for page-reload
        $('.nav-tabs a[role="tab"]').on('show.bs.tab', function (e) {
	    history.replaceState('', '', e.target.hash);
        });
	// Move focus to search box.
        $('.nav-tabs a[role="tab"]').on('shown.bs.tab', function (e) {
	    var searchname = e.target.hash + "-search";
	    $(searchname)[0].focus();
	});

	var search_users_timeout = null;
	$("#search-users-search").on("keyup", function (event) {
	    var userInput = $("#search-users-search").val();
	    userInput = userInput.toLowerCase();
	    window.clearTimeout(search_users_timeout);

	    search_users_timeout =
		window.setTimeout(function() {
		    if (userInput.length < 3) {
			return;
		    }
		    UpdateUserSearch(userInput);
		}, 500);
	});

	var search_projects_timeout = null;
	$("#search-projects-search").on("keyup", function (event) {
	    var userInput = $("#search-projects-search").val();
	    userInput = userInput.toLowerCase();
	    window.clearTimeout(search_users_timeout);

	    search_users_timeout =
		window.setTimeout(function() {
		    if (userInput.length < 3) {
			return;
		    }
		    UpdateProjectSearch(userInput);
		}, 500);
	});
    }
    
    function InitTable(name)
    {
	var tablename  = "#" + name + "_table";
	var searchname = "#" + name + "-search";
	
	var table = $(tablename)
		.tablesorter({
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra", "filter"],
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

	// Target the $('.search') input using built in functioning
	// this binds to the search using "search" and "keyup"
	// Allows using filter_liveSearch or delayed search &
	// pressing escape to cancel the search
	$.tablesorter.filter.bindSearch(table, $(searchname));

	// Update the count of matches
	table.bind('filterEnd', function(e, filter) {
	    $('#' + name + ' .match-count').text(filter.filteredRows);
	});
    }

    function UpdateUserSearch(text)
    {
	var callback = function(json) {
	    console.info(json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    var html = "";
	    for (var i in json.value) {
		var user = json.value[i];
		html = html +
		    "<tr>" +
		    "<td><a href='user-dashboard.php?user=" + user.usr_uid + "'>" +
		    user.usr_uid + "</a></td>" +
		    "<td>" + user.usr_name + "</td>" +
		    "<td>" + user.usr_email + "</td>" +
		    "<td>" + user.usr_affil + "</td>" +
		    "<td>" + user.portal + "</td></tr>";
	    }
	    $('#search_users_table tbody').html(html);
	    $('#search_users_table').trigger("update", [false]);
	    $('#search-users .match-count').text(json.value.length);
	};
	var xmlthing = sup.CallServerMethod(null,
					    "lists", "SearchUsers",
					    {"text" : text});
	xmlthing.done(callback);
    }

    function UpdateProjectSearch(text)
    {
	var callback = function(json) {
	    console.info(json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    var html = "";
	    for (var i in json.value) {
		var project = json.value[i];
		html = html +
		    "<tr>" +
		    "<td><a href='show-project.php?project=" + project.pid + "'>" +
		    project.pid + "</a></td>" +
		    "<td><a href='user-dashboard.php?user=" + project.usr_uid + "'>" +
		    project.usr_name + "</a></td>" +
		    "<td>" + project.usr_affil + "</td>" +
		    "<td>" + project.portal + "</td></tr>";
	    }
	    $('#search_projects_table tbody').html(html);
	    $('#search_projects_table').trigger("update", [false]);
	    $('#search-projects .match-count').text(json.value.length);
	};
	var xmlthing = sup.CallServerMethod(null,
					    "lists", "SearchProjects",
					    {"text" : text});
	xmlthing.done(callback);
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    $(document).ready(initialize);
});


