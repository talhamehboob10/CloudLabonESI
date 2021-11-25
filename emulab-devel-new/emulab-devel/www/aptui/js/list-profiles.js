$(function ()
{
    'use strict';
    var template_list   = ["list-profiles",
			   "oops-modal", "waitwait-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#main-body').html(templates["list-profiles"]);
	$('#oops_div').html(templates["oops-modal"]);
	$('#waitwait_div').html(templates["waitwait-modal"]);

	// Start out as empty table.
	$('#search-profiles-table')
	    .tablesorter({
		theme : 'bootstrap',
		widgets: ["uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });

	// Search box key change handler.
	var search_profiles_timeout = null;
	$("#profile-search-box").on("keyup", function (event) {
	    var userInput = $("#profile-search-box").val();
	    userInput = userInput.toLowerCase();
	    window.clearTimeout(search_profiles_timeout);

	    search_profiles_timeout =
		window.setTimeout(function() {
		    if (userInput.length < 3) {
			return;
		    }
		    UpdateProfileSearch(userInput);
		}, 500);
	});
	$("#profile-search-box").focus();	
    }

    function UpdateProfileSearch(text)
    {
	console.info("UpdateProfileSearch: " + text);
	
	var callback = function(json) {
	    console.info(json);

	    if (json.code) {
		console.info(json.value);
		return;
	    }
	    var html = "";
	    for (var i in json.value) {
		var profile = json.value[i];
		html = html +
		    "<tr>" +
		    "<td>" + profile.profile_link + "</td>" +
		    "<td>" + profile.creator_link + "</td>" +
		    "<td>" + profile.project_link + "</td>" +
		    "<td>" + profile.desc + "</td>" +
		    "<td class='format-date' style='white-space: nowrap;'>" +
		         profile.created + "</td>" +
		    "<td>" + profile.listed + "</td>" +
		    "<td>" + profile.privacy + "</td>" +
		    "</tr>\n";
	    }
	    $('#search-profiles-table tbody').html(html);

	    // Format dates with moment before table update
	    $('.format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    $('#search-profiles-table').trigger("update", [false]);
	    $('.match-count').text(json.value.length);
	};
	var xmlthing = sup.CallServerMethod(null, "manage_profile",
					    "SearchProfiles",
					    {"text" : text});
	xmlthing.done(callback);
    }
    $(document).ready(initialize);
});
