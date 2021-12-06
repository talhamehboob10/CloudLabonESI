$(function ()
{
    'use strict';
    var template_list   = ["public-profiles", "oops-modal", "waitwait-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var listTemplate    = _.template(templates["public-profiles"]);
    var tables          = ["#most-used", "#recently-used",
			   "#recently-created", "#examples"];

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var most = decodejson('#most-used-json');
	var recent = decodejson('#recently-used-json');
	var created = decodejson('#recently-created-json');
	var examples = decodejson('#examples-json');
	console.info(most, recent);

	// Standard option
	marked.setOptions({"sanitize" : true});

	_.each(most, function(value, name) {
	    value.desc = marked(value.desc)
	});
	_.each(recent, function(value, name) {
	    value.desc = marked(value.desc)
	});
	_.each(created, function(value, name) {
	    value.desc = marked(value.desc)
	});
	_.each(examples, function(value, name) {
	    value.desc = marked(value.desc)
	});
	$('#main-body').html(listTemplate({
	    "most"     : most,
	    "recent"   : recent,
	    "created"  : created,
	    "examples" : examples,
	}));
	$('#oops_div').html(templates["oops-modal"]);
	$('#waitwait_div').html(templates["waitwait-modal"]);

	// Format dates with moment before table update
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("ll"));
	    }
	});

	_.each(tables, function (name) {
	    var table = $(name + ' .tablesorter')
		.tablesorter({
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
		    }
		});
	    $.tablesorter.filter.bindSearch(table, $(name + ' .search'));
	});
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    
    $(document).ready(initialize);
});
