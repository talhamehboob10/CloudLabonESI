$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-node',
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['show-node']);
    var formfields   = null;

    function JsonParse(id)
    {
	return 	JSON.parse(_.unescape($(id)[0].textContent));
    }
    function isEllipsisActive(e) {
	return (e.offsetWidth < e.scrollWidth);
    }
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	RegeneratePageBody();
    }

    var editbutton = 
	'<a href="#" class="pull-right edit-button" ' +
	'   style="margin-left: 5px;"> ' +
	' <span class="glyphicon glyphicon-edit" ' +
	'       style="margin-top: 6px; font-size: 12px;" ' +
	'       data-toggle="tooltip" ' +
	'       data-trigger="hover" ' +
	'       title="Change current value"></span></a>';
    var savebutton = 
	'<a href="#" class="save-button" ' +
	'   style="margin-left: 5px; font-size: 12px"> ' +
	' <span class="glyphicon glyphicon-ok" ' +
	'       style="margin-top: 6px; font-size: 12px;" ' +
	'       data-toggle="tooltip" ' +
	'       data-trigger="hover" ' +
	'       title="Save new value"></span></a>';
    var cancelbutton = 
	'<a href="#" class="cancel-button" ' +
	'   style="margin-left: 5px; font-size: 12px"> ' +
	' <span class="glyphicon glyphicon-remove" ' +
	'       style="margin-top: 6px; font-size: 12px;" ' +
	'       data-toggle="tooltip" ' +
	'       data-trigger="hover" ' +
	'       title="Cancel"></span></a>';

    function RegeneratePageBody()
    {
	sup.CallServerMethod(null, "node", "GetInfo",
			     {"node_id" : window.NODE_ID},
			     function(json) {
				 console.info("info", json);
				 if (json.code) {
				     alert("Could not get node info " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBody(json.value);
			     });
    }

    function GeneratePageBody(fields)
    {
	formfields = fields;
	
	// Generate the template.
	var html = mainTemplate({
	    fields:		fields,
	    isadmin:		window.ISADMIN,
	    isguest:		window.ISGUEST,
	    canedit:            window.CANEDIT,
	    canreboot:          window.CANREBOOT,
	    console:            window.CONSOLE,
	    browserconsole:     window.BROWSERCONSOLE,
	    "YesNo":            function (val) { return (val ? "Yes" : "No"); },
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

	// See https://stackoverflow.com/questions/21168521/table-fixed-header-and-scrollable-body
	var $th = $('.table-fixed').find('thead th')
	$('.table-fixed').on('scroll', function() {
	    $th.css('transform', 'translateY('+ this.scrollTop +'px)');
	});

	// Bind the reboot button
	$('#reboot-button').click(function (event) {
	    event.preventDefault()
	    RebootNode();
	});

        // Javascript to enable link to tab
        if (document.location.hash) {
            var hash = document.location.hash;
	    hash = hash.replace(/(:|\.|\[|\]|,)/g, "\\$1");
	    console.info(hash);
	    if ($(hash).length) {
		var rowTop = $(hash).offset().top;
		var rowPos = $(hash).position()
		var tabTop = $(".table-fixed").offset().top;
		console.info(rowTop, tabTop, rowPos);
		// Scroll the wires table so its in view
		$('body, html').animate({
		    scrollTop: $(".table-fixed").offset().top,
		}, 500, 'linear');

		$(hash).closest("tr").addClass("highlight");
		$('.table-fixed').animate({
		    scrollTop: $(hash).position().top - 100,
		}, 500, 'linear');
	    }
        }
    }

    function RebootNode()
    {
	// Handler for hide modal to unbind the click handler.
	$('#confirm-reboot-modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm-reboot-button').unbind("click.reboot");
	});
	
	// Throw up a confirmation modal, with handler bound to confirm.
	$('#confirm-reboot-button').bind("click.reboot", function (event) {
	    sup.HideModal('#confirm-reboot-modal');
	    var callback = function(json) {
		sup.HideModal('#waitwait-modal');
	    
		if (json.code) {
		    sup.SpitOops("oops",
				 "Failed to reboot node: " + json.value);
		    return;
		}
		window.location.reload();
	    }
	    sup.ShowModal('#waitwait-modal');
	    var xmlthing = sup.CallServerMethod(null, "node", "Reboot",
						{"node_id"  : window.NODE_ID});
	    xmlthing.done(callback);
	});
	sup.ShowModal('#confirm-reboot-modal');
    }
    
    $(document).ready(initialize);
});
