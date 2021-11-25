$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['matched-papers',
						   'waitwait-modal',
						   'oops-modal']);
    var mainTemplate = _.template(templates['matched-papers']);
    var papers       = null;
    var unmatched    = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	papers = JSON.parse(_.unescape($("#papers-json")[0].textContent));
	console.info(papers);
	unmatched = JSON.parse(_.unescape($("#unmatched-json")[0].textContent));
	console.info(unmatched);

	// Now we can do this. 
	$('#oops_div').html(templates['waitwait-modal']);	
	$('#waitwait_div').html(templates['oops-modal']);

	GeneratePage();
    }

    function GeneratePage()
    {
	// Generate the template.
	var html = mainTemplate({
	    "papers" : papers,
	    "unmatched" : unmatched,
	});
	$('#main-body').html(html);

	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("ll"));
	    }
	});

	// "Uses" radio button handler.
	$('input[type=radio]').change(function() {
	    HandleUsesChange(this);
	});

	var args = {
	    theme : 'bootstrap',
	    widgets : [ "uitheme", "zebra", "filter"],
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
	    sortList: [[1,1]]
	};
	if (window.ISADMIN) {
	    args["textExtraction"] = {
		5: function(node) {return $(node).find("input:checked").val();}
	    };
	}
	var table = $("#papers-table").tablesorter(args);

	// Target the $('.search') input using built in functioning
	// this binds to the search using "search" and "keyup"
	// Allows using filter_liveSearch or delayed search &
	// pressing escape to cancel the search
	$.tablesorter.filter.bindSearch(table, $("#papers-search"));

	// Update the count of matches
	table.bind('filterEnd', function(e, filter) {
	    $(' .papers-match-count').text(filter.filteredRows);
	});

	/*
	 * Generate some stats.
	 */
	if (window.ISADMIN) {
	    var yes = 0;
	    var no  = 0;
	    var unk = 0;
	    _.each(papers, function(info) {
		if (info.uses == "yes") {
		    yes++;
		}
		else if (info.uses == "no") {
		    no++;
		}
		else {
		    unk++;
		}
	    });
	    $('.papers-match-breakdown')
		.html("(" + yes + "/" + no + "/" + unk + ")");
	}

	if (window.ISADMIN && _.size(unmatched)) {
	    $('#unmatched').removeClass("hidden");

	    var args = {
		    theme : 'bootstrap',
		    widgets : [ "uitheme", "zebra", "filter"],
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
		    sortList: [[1,1]]
	    };
	    args["textExtraction"] = {
		5: function(node) {return $(node).find("input:checked").val();}
	    };
	    var table = $("#unmatched-table").tablesorter(args);

	    // Target the $('.search') input using built in functioning
	    // this binds to the search using "search" and "keyup"
	    // Allows using filter_liveSearch or delayed search &
	    // pressing escape to cancel the search
	    $.tablesorter.filter.bindSearch(table, $("#unmatched-search"));

	    // Update the count of matches
	    table.bind('filterEnd', function(e, filter) {
		$(' .unmatched-match-count').text(filter.filteredRows);
	    });
	}
    }

    function HandleUsesChange(target)
    {
	var scopus_id = $(target).closest('tr').data("scopus-id");
	console.info("HandleUsesChange: ", $(target).val(), scopus_id);

	sup.CallServerMethod(null, "scopus", "MarkUses",
			     {"scopus-id" : scopus_id,
			      "uses"      : $(target).val()},
			     function (json) {
				 if (json.code) {
				     console.info(json.value);
				     sup.SpitOops("oops", json.value);
				     return;
				 }
			     });
    }
    
    $(document).ready(initialize);
});
