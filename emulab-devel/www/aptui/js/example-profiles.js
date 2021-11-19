$(function ()
{
    'use strict';
    var template_list   = ["example-profiles"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var listTemplate    = _.template(templates["example-profiles"]);
    var profiles        = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	profiles = decodejson('#profiles-json');

	// Standard option
	marked.setOptions({"sanitize" : true});

	_.each(profiles, function(value, name) {
	    value.desc = marked(value.desc)
	});
	$('#main-body').html(listTemplate({"profiles" : profiles}));

	// Format dates with moment before table update
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("ll"));
	    }
	});

	var table = $('#list-profiles-table')
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
	$.tablesorter.filter.bindSearch(table, $('#list-profiles-search'));
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    
    $(document).ready(initialize);
});
