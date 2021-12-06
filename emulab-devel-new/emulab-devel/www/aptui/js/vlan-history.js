$(function ()
{
    'use strict';
    var templates      = APT_OPTIONS.fetchTemplateList(['vlan-history',
				       'waitwait-modal', 'oops-modal']);
    var template       = _.template(templates['vlan-history']);
    var waitwait       = templates['waitwait-modal'];
    var oops           = templates['oops-modal'];
    var first;
    var last;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#waitwait-div').html(waitwait);
	$('#oops-div').html(oops);
	LoadHistory();
    }

    function LoadHistory(operation, argument)
    {
	var args;

	var callback = function(json) {
	    console.log(json);
	    if (json.code) {
		console.log("Could not get history data: " + json.value);
		return;
	    }
	    Render(json.value);
	};
	if (operation) {
	    args = {
		"operation" : operation,
		"argument"  : argument,
		"first"     : first,
		"last"      : last,
	    };
	}
	console.info(args);
	var xmlthing = sup.CallServerMethod(null, "vlan", "History", args);
	xmlthing.done(callback);
    }

    function Render(value)
    {
	var html = template({"records"  : value.records,
			     "isadmin"  : window.ISADMIN,
			     "isfadmin" : window.ISFADMIN});
	    
	$('#history-div').html(html);
	    
	// Format dates with moment before display.
	$('#history-div .format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	$('#history-div [data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	    html: true,
	});
	$(".tablesorter")
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
	
	$('#next-page').click(function (event) {
	    event.preventDefault();
	    LoadHistory("next");
	});
	$('#prev-page').click(function (event) {
	    event.preventDefault();
	    LoadHistory("prev");
	});
	$('#lanid-search-button').click(function (event) {
	    event.preventDefault();
	    LoadHistory("lanid", $('#lanid-search-box').val());
	});
	$('#tag-search-button').click(function (event) {
	    event.preventDefault();
	    LoadHistory("tag", $('#tag-search-box').val());
	});
	$('#date-search-button').click(function (event) {
	    event.preventDefault();
	    var when = moment($('#date-search-box').val()).format();
	    LoadHistory("date", when);
	});
	
	// Remember the boundries of the current page,
	first = value.first;
	last  = value.last;

	// Enable previous button.
	// XXX Need to disable when returning to first page
	$('#prev-page').removeAttr("disabled");
    }
    
    $(document).ready(initialize);
});
