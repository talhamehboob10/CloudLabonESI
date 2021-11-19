$(function ()
{
    'use strict';

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html())
			     .format("ll"));
	    }
	});
	InitTable("table1");
	InitTable("table2");
    }

    function InitTable(name)
    {
	var tablename  = "#tablesorter_" + name;
	var searchname = "#experiment_search_" + name;

	// Watch for just one table.
	if (!$(tablename).length) {
	    return;
	}
	
	var table = $(tablename)
		.tablesorter({
		    theme : 'green',
		    
		    // initialize zebra and filter widgets
		    widgets: ["zebra", "filter", "resizable"],

		    headers: {
			0: {
			    sorter : "text",
			}
		    },

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
    }

    $(document).ready(initialize);
});
