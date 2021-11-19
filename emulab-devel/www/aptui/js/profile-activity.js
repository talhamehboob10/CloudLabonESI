$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['profile-activity']);
    var ajaxurl = null;
    var profileTemplate = _.template(templates['profile-activity']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	ajaxurl  = window.AJAXURL;

	var instances =
	    JSON.parse(_.unescape($('#instances-json')[0].textContent));
	var activity_html = profileTemplate({
	    "pid"        : window.PROFILE_PID,
	    "name"       : window.PROFILE_NAME,
	    "instances"  : instances
	});
	$('#activity-body').html(activity_html);

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	var tablename  = "#profile-activity-table";
	
	var table = $(tablename)
	    .tablesorter({
		    theme : 'bootstrap',
		    headerTemplate : '{content} {icon}',
		    widgets: ["uitheme", "zebra"],
	    });
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	});
    }
    $(document).ready(initialize);
});
