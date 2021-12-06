$(function ()
{
    'use strict';
    var templates      = APT_OPTIONS.fetchTemplateList(['instance-errors',
				       'waitwait-modal', 'oops-modal']);
    var template       = _.template(templates['instance-errors']);
    var waitwait       = templates['waitwait-modal'];
    var oops           = templates['oops-modal'];
    var page           = 0;
    var pages          = [];
    var earliest       = null;  // Earliest (last) on the page.
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#waitwait_div').html(waitwait);
	$('#oops_div').html(oops);
	LoadErrors();
    }

    function LoadErrors(earliest)
    {
	var callback = function(json) {
	    console.log(json);
	    if (json.code) {
		console.log("Could not get dashboard data: " + json.value);
		return;
	    }
	    if (earliest !== undefined) {
		page++;
	    }
	    pages[page] = json.value;
	    RenderErrors(json.value);
	};
	var args = null;
	if (earliest !== undefined) {
	    args = {"stamp"     : earliest};
	}
	console.info(args);
	var xmlthing = sup.CallServerMethod(null, "experiments",
					    "ExperimentErrors", args);
	xmlthing.done(callback);
    }

    function RenderErrors(errors)
    {
	var html = template({"errors"   : errors,
			     "isadmin"  : window.ISADMIN,
			     "isfadmin" : window.ISFADMIN});
	    
	$('#errors-div').html(html);
	$('#page-number').html(page + 1);
	    
	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html())
			     .format("ddd h:mm A"));
	    }
	});
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	    html: true,
	});
	$('#next-page').click(function (event) {
	    event.preventDefault();
	    LoadErrors(earliest);
	});
	$('#prev-page').click(function (event) {
	    event.preventDefault();
	    if (page > 0) {
		page--;
		RenderErrors(pages[page]);
	    }
	});
	// Remember the last date in the range.
	var last = errors[errors.length - 1];
	earliest = moment(last.started).valueOf() / 1000;

	// Enable previous button after page 0.
	if (page > 0) {
	    $('#prev-page').removeAttr("disabled");
	}
	else {
	    $('#prev-page').attr("disabled");
	}
    }
    
    $(document).ready(initialize);
});
