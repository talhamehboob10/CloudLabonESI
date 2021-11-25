$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-rfviolations',
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['show-rfviolations']);
    var formfields   = null;

    function JsonParse(id)
    {
	return 	JSON.parse(_.unescape($(id)[0].textContent));
    }
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	RegeneratePageBody();
    }

    function RegeneratePageBody()
    {
	sup.CallServerMethod(null, "node", "GetRFViolations",
			     {"node_id" : window.NODE_ID},
			     function(json) {
				 console.info("info", json);
				 if (json.code) {
				     alert("Could not get rf violations " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBody(json.value);
			     });
    }

    function GeneratePageBody(violations)
    {
	// Generate the template.
	var html = mainTemplate({
	    violations:         violations,
	    isadmin:		window.ISADMIN,
	    isguest:		window.ISGUEST,
	});
	$('#main-body').html(html);

	// Now we can do this.
	$('#oops_div').html(templates['oops-modal']);
	$('#waitwait_div').html(templates['waitwait-modal']);

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

	$('.tablesorter')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });

	// See https://stackoverflow.com/questions/21168521/table-fixed-header-and-scrollable-body
	var $th = $('.table-fixed').find('thead th')
	$('.table-fixed').on('scroll', function() {
	    $th.css('transform', 'translateY('+ this.scrollTop +'px)');
	});
    }
    
    $(document).ready(initialize);
});
