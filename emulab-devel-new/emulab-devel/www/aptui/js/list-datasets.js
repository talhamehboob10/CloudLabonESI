$(function ()
{
    'use strict';
    var ajaxurl = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	ajaxurl  = window.AJAXURL;

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});

	var inittable = function(id) {
	    var table = $(id).tablesorter({
		    theme : 'bootstrap',
		    widgets: ["uitheme", "zebra", "filter"],
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
		    },
		});
	    return table;
	};
	if ($("#main_table").length) {
	    var table = inittable('#main_table');
	    $.tablesorter.filter.bindSearch( table, $('#dataset_search') );
	}
	if ($("#classic_table").length) {
	    var table = inittable('#classic_table');
	}
	//
	// When embedded, we want the Show link to go through the outer
	// frame not the inner iframe.
	//
	if (window.EMBEDDED) {
	    $('*[id*=show-dataset-button]').click(function (event) {
		event.preventDefault();
		var url = $(this).attr("href");
		console.info(url);
		window.parent.location.replace("../" + url);
		return false;
	    });
	    $('*[id*=embedded-anchors]').click(function (event) {
		event.preventDefault();
		var url = $(this).attr("href");
		console.info(url);
		window.parent.location.replace("../" + url);
		return false;
	    });
	}
    }

    $(document).ready(initialize);
});
