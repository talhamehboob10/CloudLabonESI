$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['profile-paramsets', 'waitwait-modal',
						   'oops-modal', 'paramsets-list']);
    var profile_uuid = null;
    var profile_name = '';
    var profile_pid  = '';
    var showTemplate = _.template(templates['profile-paramsets']);
    var listTemplate = _.template(templates['paramsets-list']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	
	profile_uuid  = window.PROFILE_UUID;
	profile_pid   = window.PROFILE_PID;
	profile_name  = window.PROFILE_NAME;

	$('#waitwait_div').html(templates['waitwait-modal']);
	$('#oops_div').html(templates['oops-modal']);

	var show_html = showTemplate({
	    "profile_uuid" : profile_uuid,
	    "profile_pid"  : profile_pid,
	    "profile_name" : profile_name,
	});
	$('#page-body').html(show_html);
	$('body').show();
	
	sup.CallServerMethod(null, "show-profile",
			     "GetParamsets", {"uuid" : profile_uuid},
			     function (json) {
				 console.info(json);
				 if (json.code) {
				     sup.SpitOops("oops", json.value);
				     return;
				 }
				 GeneratePage(json.value);
			     });
    }

    function GeneratePage(paramsets)
    {
	var list_html = listTemplate({
	    "paramsets" : paramsets,
	    "isadmin"   : window.ISADMIN,
	});
	$('#paramsets-div').html(list_html);
	
	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});

	$('#paramsets-div .tablesorter')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });
	
	// This activates the popover subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	    placement: 'auto',
	    container: 'body'
	});
    }
    $(document).ready(initialize);
});
