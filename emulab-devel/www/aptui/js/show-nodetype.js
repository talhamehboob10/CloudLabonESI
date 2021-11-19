$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-nodetype',
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['show-nodetype']);
    var formfields   = null;
    var allimages    = [];

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
	sup.CallServerMethod(null, "nodetype", "GetInfo",
			     {"type" : window.TYPE},
			     function(json) {
				 console.info("info", json);
				 if (json.code) {
				     alert("Could not get node type info " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBody(json.value);
			     });
    }

    function GeneratePageBody(fields)
    {
	formfields = fields;
	var args = {
	    fields:	fields,
	    isadmin:	window.ISADMIN,
	    "YesNo":    function (val) { return (val ? "Yes" : "No"); },
	};
	if (window.EDITING) {
	    args["oslist"]    = JsonParse("#osinfo-json");
	    args["mfslist"]   = JsonParse("#mfs-json");
	    args["imagelist"] = JsonParse("#images-json");

	    /*
	     * Generate a combined sparse array for adding new OS/Images
	     */
	    _.each(args["oslist"], function (info) {
		allimages[info.osid] = info;
	    });
	    _.each(args["mfslist"], function (info) {
		allimages[info.osid] = info;
	    });
	    _.each(args["imagelist"], function (info) {
		allimages[info.osid] = info;
	    });
	    // Now sort it by OS name.
	    allimages.sort(function (a, b) {
		if (a.name > b.name) return 1;
		if (b.name > a.name) return -1;
		return 0;
	    });
	}
	console.info(args);
	
	// Generate the template.
	var html = mainTemplate(args);
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

	/*
	 * Setup for editing.
	 */
	if (window.EDITING) {
	    $("input.form-control").change(function () {
		var name = $(this).attr("name");
		var val  = $(this).val();
		console.info("changed: " + name, val);
		$(this).closest("tr")
		    .find(".save-row").removeAttr("disabled");
	    });
	    $("select.form-control").change(function () {
		var name = $(this).attr("name");
		var val  = $(this).find('option:selected').val();
		console.info("changed: " + name, val);
		$(this).closest("tr")
		    .find(".save-row").removeAttr("disabled");
	    });
	    // Warn user if they have not saved changes.
	    $(window).on('beforeunload.portal',
			 function() {
			     if ($(".save-row").not(":disabled").length == 0) {
				 return undefined;
			     }
			     return "You have unsaved changes!";
			 });
	    // Handlers for save and delete and add
	    $(".save-row").click(function (event) {
		var row   = $(this).closest("tr");
		var which = $(row).data("which");
		SaveRow(which, row);
	    });
	    $(".delete-row").click(function (event) {
		var row   = $(this).closest("tr");
		var which = $(row).data("which");
		DeleteRow(which, row);
	    });
	    $("#add-feature-button").click(function (event) {
		AddRow("feature");
	    });
	    $("#add-attribute-button").click(function (event) {
		AddRow("attribute");
	    });
	    $("#add-osimage-button").click(function (event) {
		AddOSImageRow();
	    });
	}
    }

    var newFeatureRow =
	'<tr class="new-row">' +
	' <td>' +
	'   <input type="text" ' +
	'          placeholder="Name" ' +
	'          class="form-control row-name"> ' +
	' </td>' +
	' <td>' +
	'   <input type="text" ' +
	'          placeholder="Value" ' +
	'          class="form-control row-value"> ' +
	' </td>' +
	' <td style="width: 16px;' +
	'            padding-right: 2px; padding-left: 2px;"> ' +
	'   <button type="button" ' +
	'           class="btn btn-xs btn-default delete-row"' +
	'           style="color: red">' +
 	'     <span class="glyphicon glyphicon-remove" ' +
	'           data-toggle="tooltip" ' +
	'  	    data-container="body" ' +
	'	    data-trigger="hover" ' +
	'           title="Delete this row"></span>' +
	'   </button>' +
	'   <button type="button" disabled ' +
	'           class="btn btn-xs btn-default save-row"' +
	'           style="color: green">' +
 	'     <span class="glyphicon glyphicon-ok" ' +
	'           data-toggle="tooltip" ' +
	'  	    data-container="body" ' +
	'	    data-trigger="hover" ' +
	'           title="Save change"></span>' +
	'   </button>' +
	' </td>' +
	'</tr>';

    var newAttributeRow =
	'<tr class="new-row">' +
	' <td>' +
	'   <input type="text" ' +
	'          placeholder="Name" ' +
	'          class="form-control row-name"> ' +
	' </td>' +
	' <td>' +
	'   <input type="text" ' +
	'          placeholder="Value" ' +
	'          class="form-control row-value"> ' +
	'   <div> ' +
	'     <select class="form-control row-type"> ' +
	'      <option value="">Select Type</option> ' +
	'      <option value=integer>Integer</option> ' +
	'      <option value=boolean>Boolean</option> ' +
	'      <option value=string>String</option> ' +
	'      <option value=float>Float</option> ' +
	'     </select> ' +
	'   </div> ' +
	' </td>' +
	' <td style="width: 16px; padding-top: 20px; ' +
	'            padding-right: 2px; padding-left: 2px;"> ' +
	'   <button type="button" ' +
	'           class="btn btn-xs btn-default delete-row"' +
	'           style="color: red">' +
 	'     <span class="glyphicon glyphicon-remove" ' +
	'           data-toggle="tooltip" ' +
	'  	    data-container="body" ' +
	'	    data-trigger="hover" ' +
	'           title="Delete this row"></span>' +
	'   </button>' +
	'   <button type="button" disabled ' +
	'           class="btn btn-xs btn-default save-row"' +
	'           style="color: green">' +
 	'     <span class="glyphicon glyphicon-ok" ' +
	'           data-toggle="tooltip" ' +
	'  	    data-container="body" ' +
	'	    data-trigger="hover" ' +
	'           title="Save change"></span>' +
	'   </button>' +
	' </td>' +
	'</tr>';

    var newOSImageRow =
	'<tr class="new-row">' +
	' <td>' +
	'   <input type="text" ' +
	'          placeholder="Name" ' +
	'          class="form-control row-name"> ' +
	' </td>' +
	' <td>' +
	'   <select class="form-control row-value"> ' +
	'    <option value="">Please Select</option> ' +
	'   </select> ' +
	' </td>' +
	' <td style="width: 16px; ' +
	'            padding-right: 2px; padding-left: 2px;"> ' +
	'   <button type="button" ' +
	'           class="btn btn-xs btn-default delete-row"' +
	'           style="color: red">' +
 	'     <span class="glyphicon glyphicon-remove" ' +
	'           data-toggle="tooltip" ' +
	'  	    data-container="body" ' +
	'	    data-trigger="hover" ' +
	'           title="Delete this row"></span>' +
	'   </button>' +
	'   <button type="button" disabled ' +
	'           class="btn btn-xs btn-default save-row"' +
	'           style="color: green">' +
 	'     <span class="glyphicon glyphicon-ok" ' +
	'           data-toggle="tooltip" ' +
	'  	    data-container="body" ' +
	'	    data-trigger="hover" ' +
	'           title="Save change"></span>' +
	'   </button>' +
	' </td>' +
	'</tr>';

    // Add a new feature or attribute
    function AddRow(which)
    {
	var row = (which == "feature" ?
		   $(newFeatureRow) : $(newAttributeRow));
	
	$(row).find("input, select").change(function (event) {
	    var name  = $(row).find(".row-name").val();
	    var value = $(row).find(".row-value").val();

	    if ($.trim(name) == "" || $.trim(value) == "" ||
		(which == "attribute" &&
		 $(row).find(".row-type option:selected").val() == "")) {
		$(row).find(".save-row").attr("disabled", "disabled");
	    }
	    else {
		$(row).find(".save-row").removeAttr("disabled");
	    }
	});
	$(row).data("which", which);
	$(row).find(".save-row").click(function () {
	    SaveRow(which, $(row));
	});
	$(row).find(".delete-row").click(function () {
	    DeleteRow(which, $(row));
	});
	if (which == "feature") {
	    $("#features-table").prepend(row);
	}
	else {
	    $("#attributes-table").prepend(row);
	}
    }
    // Add a new OSImage row
    function AddOSImageRow()
    {
	var row   = $(newOSImageRow);
	var which = "osinfo";
	
	$(row).find("input, select").change(function (event) {
	    var name  = $(row).find(".row-name").val();
	    var value = $(row).find(".row-value").val();

	    if ($.trim(name) == "" || $.trim(value) == "" ||
		$(row).find(".row-type option:selected").val() == "") {
		$(row).find(".save-row").attr("disabled", "disabled");
	    }
	    else {
		$(row).find(".save-row").removeAttr("disabled");
	    }
	});
	$(row).data("which", which);
	$(row).find(".save-row").click(function () {
	    SaveRow(which, $(row));
	});
	$(row).find(".delete-row").click(function () {
	    DeleteRow(which, $(row));
	});
	allimages.forEach(function (info, i) {
	    $(row).find(".row-value").append("<option value=" + info.osid +
					     ">" + info.name + "</option>");
	});
	$("#osinfo-table").prepend(row);
    }
    // Save a row
    function SaveRow(which, row)
    {
	var name    = $(row).find(".row-name").val();
	var value   = (which == "osimage" ?
		       $(row).find(".row-value option:selected").val() :
		       $(row).find(".row-value").val())
	var isnew   = $(row).hasClass("new-row");
	var method  = "";
	console.info("SaveRow", which, isnew, name, value);

	var args = {
	    "type"   : window.TYPE,
	    "name"   : name,
	    "value"  : value,
	}
	if (isnew) {
	    args["isnew"] = true;
	}
	if (which == "feature") {
	    method = "SaveFeature";
	}
	else if (which == "osinfo") {
	    method = "SaveOSImage";
	}
	else if (which == "flag") {
	    method = "SaveFlag";
	}
	else {
	    method = "SaveAttribute";
	}
	if (which == "attribute") {
	    args["attrtype"] = $(row).find(".row-type").val();
	}
	ConfirmAndCall(method, args, function (json) {
	    if (json.code) {
		return;
	    }
	    // Disable save until modified again.
	    $(row).find(".save-row").attr("disabled", "disabled");
	    if (isnew) {
		// Mark the name input as readonly, user cannot change it now.
		$(row).find(".row-name").prop("readonly", true);
		if (which == "attribute") {
		    // Hide the type selector.
		    $(row).find(".row-type").addClass("hidden");
		}
		// Clear new flag.
		$(row).removeClass("new-row");
	    }
	});
    }
    // Delete a row
    function DeleteRow(which, row)
    {
	var name   = $(row).find(".row-name").val();
	var isnew  = $(row).hasClass("new-row");
	var method = "";
	console.info("DeleteRow", isnew, name);

	// If a new row (unsaved), just kill it.
	if (isnew) {
	    // Kill tooltips since they get left behind if visible.
	    $(row).find('[data-toggle="tooltip"]').tooltip('destroy');
	    $(row).remove();
	    return;
	}
	var args = {
	    "type" : window.TYPE,
	    "name" : name,
	}
	if (which == "feature") {
	    method = "DeleteFeature";
	}
	else if (which == "osimage") {
	    method = "DeleteOSImage";
	}
	else {
	    method = "DeleteAttribute";
	}
	ConfirmAndCall(method, args, function (json) {
	    if (json.code) {
		return;
	    }
	    // Kill tooltips since they get left behind if visible.
	    $(row).find('[data-toggle="tooltip"]').tooltip('destroy');
	    $(row).remove();
	});
    }

    // Confirm an action, calling the continuation with json result.
    function ConfirmAndCall(method, args, continuation)
    {
	console.info("ConfirmAndCall", method, args);
	
	$('#confirm-modal').bind("hidden.bs.modal", function (event) {
	    $(this).unbind(event);
	    $('#confirm-change').unbind("click.confirm");
	});
	$('#confirm-change').bind("click.confirm", function (event) {
	    sup.HideModal('#confirm-modal', function () {
		sup.CallServerMethod(null, "nodetype", method, args,
				     function (json) {
					 console.info(json);
					 if (json.code) {
					     sup.SpitOops("oops", json.value);
					     return;
					 }
					 continuation(json);
				     });
	    });
	});
	sup.ShowModal('#confirm-modal');
    }
    $(document).ready(initialize);
});
