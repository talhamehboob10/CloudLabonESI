$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-vlan']);
    var mainTemplate = _.template(templates['show-vlan']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	sup.CallServerMethod(null, "vlan", "GetInfo",
			     {"vlan_id" : window.VLAN_ID},
			     function(json) {
				 console.info("info", json);
				 if (json.code) {
				     alert("Could not get vlan info " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBody(json.value);
			     });
    }

    function GeneratePageBody(info)
    {
	// Generate the template.
	var html = mainTemplate({
	    info:	info,
	});
	$('#main-body').html(html);

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	});
	
	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});
    }

    $(document).ready(initialize);
});
