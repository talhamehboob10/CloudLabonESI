$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-nodelog',
						   "confirm-something",
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['show-nodelog']);
    var confirmstr   = templates['confirm-something'];
    var formfields   = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	GeneratePageBody();
    }

    function GeneratePageBody()
    {
	sup.CallServerMethod(null, "node", "GetLog",
			     {"node_id" : window.NODE_ID},
			     function(json) {
				 console.info("info", json);
				 if (json.code) {
				     alert("Could not get node log info " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBodyAux(json.value);
			     });
    }

    function GeneratePageBodyAux(entries)
    {
	// Generate the template.
	var html = mainTemplate({
	    entries:		entries,
	    node_id:		window.NODE_ID,
	    isadmin:		window.ISADMIN,
	});
	$('#main-body').html(html);
	// All the way to the bottom.
	$('body, html').animate({
	    scrollTop: $('#log-table').height(),
	}, 1000);

	// Now we can do this.
	$('#oops_div').html(templates['oops-modal']);
	$('#waitwait_div').html(templates['waitwait-modal']);
	$('#confirm_div').html(confirmstr);

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});

	// Bind the new entry button.
	$('#new-entry-button').click(function (event) {
	    event.preventDefault();
	    NewLogEntry();
	});

	// Bind the delete entry buttons
	$('.delete-entry-button').click(function (event) {
	    event.preventDefault();
	    DeleteLogEntry($(this));
	});

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	});
	
	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});
    }

    // Throw up modal to create a new log entry.
    function NewLogEntry()
    {
	// Bind the confirm button.
	$('#save-log-confirm').click(function (event) {
	    SaveLogEntry();
	});
	sup.ShowModal('#save-log-modal', function () {
	    $('#save-log-confirm').off("click");
	});
    }
    function SaveLogEntry()
    {
	var entry = $.trim($('#log-entry').val());

	console.info("SaveLogEntry", entry);

	var showError = function (which, error) {
	    var id = "#save-log-modal ." + which + "-error";

	    $(id).html(error);
	    $(id).removeClass("hidden");
	};

	// Hide errors.
	$('#save-log-modal .log-error').addClass("hidden");
	// No blank fields please
	if (entry == "") {
	    showError("entry", "Please provide a log entry");
	    return;
	}
	var args = {
	    "node_id"   : window.NODE_ID,
	    "log_entry" : entry,
	};
	
	var callback = function (json) {
	    console.info(json);
	    if (json.code) {
		showError("general", json.value);
		return;
	    }
	    sup.HideModal('#save-log-modal');
	    window.location.reload();
	};
	sup.CallServerMethod(null, "node", "SaveLogEntry", args, callback);
    }
    function DeleteLogEntry(item)
    {
	var row   = $(item).closest("tr");
	var logid = $(row).data("logid");
	console.info("DeleteLogEntry", logid);

	var args = {
	    "node_id"  : window.NODE_ID,
	    "log_id"   : logid,
	};
	var callback = function (json) {
	    console.info(json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $(row).remove();
	};
	sup.ConfirmModal({
	    "modal"  : "confirm-something",
	    "prompt" : "Delete Log Entry?",
	    "cancel_function" : function (data) {
		// Nothing to do, user still sees the edit view.
	    },
	    "confirm_function" : function (data) {
		sup.CallServerMethod(null, "node", "DeleteLogEntry",
				     args, callback);
	    },
	});
    }

    $(document).ready(initialize);
});
