$(function ()
{
    'use strict';
    var templates      = APT_OPTIONS.fetchTemplateList(['sitevars',
						'waitwait-modal', 'oops-modal',
						'confirm-something']);
    var template       = _.template(templates['sitevars']);
    var waitwait       = templates['waitwait-modal'];
    var oops           = templates['oops-modal'];
    var confirmstr     = templates['confirm-something'];
    var sitevars       = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#waitwait_div').html(waitwait);
	$('#oops_div').html(oops);
	$('#confirm_div').html(confirmstr);
	LoadSitevars();
    }

    function LoadSitevars()
    {
	var callback = function(json) {
	    console.log(json);
	    if (json.code) {
		console.log("Could not get status data: " + json.value);
		return;
	    }
	    sitevars = json.value;
	    RenderPage();
	};
	var args = null;
	var xmlthing = sup.CallServerMethod(null, "sitevars",
					    "GetSitevars", args);
	xmlthing.done(callback);
    }

    function RenderPage()
    {
	var html = template({"sitevars" : sitevars});
	$('#page-body').html(html);

	var table = $('#sitevars-table')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra", "stickyHeaders", "filter"],
		headerTemplate : '{content} {icon}',

		widgetOptions: {
		    // include child row content while filtering, if true
		    filter_childRows  : true,
		    // include all columns in the search.
		    filter_anyMatch   : false,
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
	$.tablesorter.filter.bindSearch(table, $('.form-control.search'));

	// Bind the row edit buttons.
	$(".edit-button").click(function (event) {
	    event.preventDefault();
	    HandleEditButton($(this));
	});
	// Bind the row reset buttons.
	$(".reset-button").click(function (event) {
	    event.preventDefault();
	    HandleResetButton($(this));
	});

	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    placement: 'auto',
	});
    }

    // Handle the edit button.
    function HandleEditButton(target)
    {
	var row  = $(target).closest("tr");
	var name = $(row).attr('data-name');
	var cval = $(row).find(".current-value");
	var editing = false;

	// We are in edit mode if the editing area is visible
	if (! $(cval).find(".editing").hasClass("hidden")) {
	    editing = true;
	}
	console.info(name, editing, target);

	// If already editing, ignore the button.
	if (editing) {
	    return;
	}
	// Switch the column to the editable textarea.
	$(cval).find(".notediting").addClass("hidden");
	$(cval).find(".editing").removeClass("hidden");

	// Bind handlers for save/cancel buttons.
	$(cval).find(".cancel-button").click(function (event) {
	    console.info("cancel edit");
	    // Switch the column back to the normal display
	    $(cval).find(".notediting").removeClass("hidden");
	    $(cval).find(".editing").addClass("hidden");
	    $('.cancel-button').off("click");	    
	    $('.save-button').off("click");	    
	});
	$(cval).find(".save-button").click(function (event) {
	    console.info("save edit");
	
	    sup.ConfirmModal({
		"modal"  : "confirm-something",
		"prompt" : "Save new site variable value?",
		"cancel_function" : function (data) {
		    // Nothing to do, user still sees the edit view.
		},
		"confirm_function" : function (data) {
		    var newvalue = $(cval).find("textarea").val();
		    
		    var callback = function (json) {
			console.info(json);
			if (json.code) {
			    sup.SpitOops("oops", json.value);
			    return;
			}
			// Switch the column back to the normal display
			$(cval).find(".notediting").html(_.escape(newvalue));
			$(cval).find(".notediting").removeClass("hidden");
			$(cval).find(".editing").addClass("hidden");
			$('.cancel-button').off("click");
			$('.save-button').off("click");
		    };
		    var args = {
			"name"  : name,
			"value" : newvalue,
		    };
		    sup.CallServerMethod(null, "sitevars", "SetSitevar",
					 args, callback);
	    
		},
	    });
	});
    }

    // Handle the reset button.
    function HandleResetButton(target)
    {
	var row  = $(target).closest("tr");
	var name = $(row).attr('data-name');
	var cval = $(row).find(".current-value");

	console.info("HandleResetButton");

	// We are in edit mode if the editing area is visible
	if (! $(cval).find(".editing").hasClass("hidden")) {
	    alert("Already editing, please cancel or save the edit first");
	    return;
	}
	sup.ConfirmModal({
	    "modal"  : "confirm-something",
	    "prompt" : "Reset site variable to default value?",
	    "cancel_function" : function (data) {
		// Nothing to do
	    },
	    "confirm_function" : function (data) {
		var callback = function (json) {
		    console.info(json);
		    if (json.code) {
			sup.SpitOops("oops", json.value);
			return;
		    }
		    // Set the current value to the default value from DB.
		    $(cval).find(".notediting").html(_.escape(json.value));
		    // Also the textarea in case the user then edits the value.
		    $(cval).find("textarea").html(json.value);
		};
		var args = {
		    "name"  : name,
		};
		sup.CallServerMethod(null, "sitevars", "ResetSitevar",
				     args, callback);
	    },
	});
    }
    
    $(document).ready(initialize);
});
