$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['list-wires']);
    var mainTemplate = _.template(templates['list-wires']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	sup.CallServerMethod(null, "wires", "List", null,
			     function(json) {
				 console.info("list", json);
				 if (json.code) {
				     alert("Could not get wire list " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBody(json.value);
			     });
    }

    function GeneratePageBody(wires)
    {
	// Generate the template.
	var html = mainTemplate({
	    wires:		wires,
	    isadmin:		window.ISADMIN,
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

	var table = $(".tablesorter")
		.tablesorter({
		    theme : 'bootstrap',
		    widgets: ["uitheme", "filter"],
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
			filter_columnFilters : true,
			}
		});
	$('#waiting').addClass("hidden");
    }

    $(document).ready(initialize);
});
