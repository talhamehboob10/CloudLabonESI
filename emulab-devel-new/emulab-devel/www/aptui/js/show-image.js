$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-image',
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['show-image']);
    var alltypes     = null;
    var curtypes     = null;
    var formfields   = null;
    var YesNo        = function (val) { return (val ? "Yes" : "No"); };

    function JsonParse(id)
    {
	return 	JSON.parse(_.unescape($(id)[0].textContent));
    }
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	alltypes = JsonParse('#alltypes-json');
	$('#oops_div').html(templates['oops-modal']);
	$('#waitwait_div').html(templates['waitwait-modal']);
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
	// Format dates with moment before display.	
	sup.CallServerMethod(null, "image", "GetInfo",
			     {"uuid" : window.UUID,
			      "embedded" : window.EMBEDDED},
			     function(json) {
				 console.info("info", json);
				 if (json.code) {
				     alert("Could not get image info " +
					   "from server: " + json.value);
				     return;
				 }
				 GeneratePageBody(json.value);
			     });
    }

    function GeneratePageBody(fields)
    {
	formfields = fields;
	// Need this for editing types
	curtypes = fields["types"];
	
	// Generate the template.
	var html = mainTemplate({
	    fields:		fields,
	    isadmin:		window.ISADMIN,
	    canedit:            window.CANEDIT,
	    candelete:          window.CANDELETE,
	    "YesNo":            YesNo,
	});
	$('#main-body').html(html);

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});

	// Add the edit button to fields that can be edited.
	if (window.ISADMIN) {
	    $('.editable').append(editbutton);
	}
	else if (window.CANEDIT) {
	    $('.editable').not(".adminonly").append(editbutton);
	}
	// Bind the edit buttons.
	if (window.ISADMIN || window.CANEDIT) {
	    $('.editable .edit-button').click(function (event) {
		event.preventDefault();
		HandEditButton(this);
	    });
	}
	// The admin notes are handled differently.
	if (window.ISADMIN) {
	    $(".adminnotes textarea")
		.on("change input paste keyup", function() {
		    $('#adminnotes-save-button').removeClass('hidden');
		});
	    $('#adminnotes-save-button').click(function (event) {
		event.preventDefault();
		SaveAdminNotes(function () {
		    $('#adminnotes-save-button').addClass('hidden');
		});
	    });
	}
	// And the types are handled differently.
	if ((window.ISADMIN || window.CANEDIT) &&
	    !_.has(fields, "architecture")) {
	    $('.typelist td').first().append(editbutton);
	    $('.typelist .edit-button').click(function (event) {
		event.preventDefault();
		HandEditTypes(this);
	    });
	}
	// And shared/global are handled differently.
	if (window.ISADMIN || window.CANEDIT) {
	    $('.shared-global td').first().append(editbutton);
	    $('.shared-global .edit-button').click(function (event) {
		event.preventDefault();
		HandEditSharedGlobal(this);
	    });
	}
	
	// The delete button.
	if (window.ISADMIN || window.CANDELETE) {
            $('#image-delete-button').click(function (event) {
		// The modal is showing. Bind the confirm button.
		$('#confirm-image-delete').click(function (event) {
		    sup.HideModal('#confirm-image-delete-modal', function () {
			DeleteImage();
		    });
		});
	    });
	    // Kill the handler when the modal is hidden.
	    $('#confirm-image-delete-modal')
		.on('hidden.bs.modal', function (event) {
		    $('#confirm-image-delete').off("click");
		});
	}

	// The snapshot button.
	if (window.CANEDIT) {
            $('#image-snapshot-button').click(function (event) {
		// The modal is showing. Bind the confirm button.
		$('#confirm-image-snapshot').click(function (event) {
		    sup.HideModal('#confirm-snapshot-modal', function () {
			SnapshotImage();
		    });
		});
	    });
	    // Kill the handler when the modal is hidden.
	    $('#confirm-snapshot-modal')
		.on('hidden.bs.modal', function (event) {
		    $('#confirm-image-snapshot').off("click");
		});
	}

	// Copy the osfeatures help string into the popover before init.
	$('#osfeatures-help')
	    .data("content", $('#osfeatures-help-contents').html());
	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	});
	
	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});

	// Look for tooltips on modal buttons.
	$('[data-tooltip]').each(function () {
	    $(this).tooltip({    
		trigger: 'hover',  
		title:    $(this).data("tooltip")});
	});

	//
	// When embedded, we want the links to go through the outer
	// frame not the inner iframe.
	//
	if (window.EMBEDDED) {
	    $('*[id*=embedded-anchors]').click(function (event) {
		event.preventDefault();
		var url = $(this).attr("href");
		console.info(url);
		window.parent.location.replace(url);
		return false;
	    });
	}

	// Prefill for snapshot/clone buttons.
	if (window.SNAPNODE !== undefined) {
	    $('#snapshot-image-nodeid').val(window.SNAPNODE);

	    var url = $('#image-clone-button').prop("href");
	    url += "&node=" + window.SNAPNODE;
	    $('#image-clone-button').prop("href", url);
	}	    

	// Check for imaging.
	if (window.SHOWSNAPSTATUS) {
	    sup.CallServerMethod(null, "image", "SnapshotStatus",
		     {"uuid" : window.UUID},
		     function(json) {
			 console.info("info", json);
			 if (json.code) {
			     console.info("SnapshotStatus: " +
					  json.value);
			     return;
			 }
			 if (_.has(json.value, "exited")) {
			     console.info("SnapshotStatus: already exited " +
					  "with status " + json.value.exitcode);
			     return;
			 }
			 ShowImagingModal(
			     function()
			     {
				 return sup.CallServerMethod(null,
						 "image",
						 "SnapshotStatus",
						 {"uuid" : window.UUID});
			     },
			     function(failed) {
				 if (!failed) {
				     window.SHOWSNAPSTATUS = false;
				     RegeneratePageBody();
				 }
			     },
			     false);
		     });
	}
	else if (window.AUTOSNAP) {
            $('#image-snapshot-button').trigger("click");
	}
    }

    function HandEditButton(target)
    {
	console.info("HandEditButton", target);

	var td_name   = $(target).closest("td");
	var td_field  = $(td_name).next();
	var td_value  = $.trim($(td_field).find("span").text());
	var td_type   = $(td_name).data("fieldtype");
	var td_fname  = $(td_name).data("fieldname");

	console.info(td_name, td_field, td_value, td_type, td_fname);

	// Hide the edit button till we are done.
	$(target).addClass("invisible");

	// Hide the original
	$(td_field).find("span").addClass("hidden");

	// Insert the edit buttons in a new span with input field.
	$(td_field).append(
	    "<span class=editing>" + cancelbutton + savebutton + "</span>");

	// This activates the new tooltips we added above
	$(td_field).find('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});
	
	// Add set the value of the input field.
	if (td_type == "text") {
	    $(td_field).find("span.editing").append(
		"<input type=text class=form-control value=''>")
	    $(td_field).find("input")
		.val(td_value);
	}
	else if (td_type == "checkbox") {
	    $(td_field).find("span.editing").append(
		"<label style='display: block;'> " +
		    "  <input type=checkbox style='margin-right: 5px;'>" +
		    "Yes</label>");
	    
	    if (td_value == "Yes" || td_value == "1") {
		$(td_field).find("input").prop("checked", "checked");
	    }
	    else {
		$(td_field).find("input").prop("checked", false);
	    }
	}
	else {
	    alert("Bad fieldtype in edit");
	    return;
	}

	// Bind a cancel button to set things back the way they were.
	$(td_field).find(".cancel-button").click(function (event) {
	    event.preventDefault();
	    // Kill the span holding the buttons and input field.
	    $(td_field).find(".editing").remove();
	    // Show the original
	    $(td_field).find("span").removeClass("hidden");
	    // Show the edit button again
	    $(target).removeClass("invisible");
	});

	// Bind the save button.
	$(td_field).find(".save-button").click(function (event) {
	    event.preventDefault();
	    var newval;

	    if (td_type == "text") {
		newval = $.trim($(td_field).find("input").val());
	    }
	    else if (td_type == "checkbox") {
		newval = $(td_field).find("input").is(":checked") ? 1 : 0;
	    }
	    sup.CallServerMethod(null, "image", "Modify",
				 {"uuid"  : window.UUID,
				  "field" : td_fname,
				  "value" : newval},
				 function(json) {
				     console.info("info", json);
				     if (json.code) {
					 sup.SpitOops("oops", json.value);
					 return;
				     }
				     // Kill the buttons/input field.
				     $(td_field).find(".editing").remove();
				     // Update and show the original
				     if (td_type == "checkbox") {
					 newval = YesNo(newval);
				     }
				     $(td_field).find("span")
				         .text(newval)
					 .removeClass("hidden");
				     // Show the edit button again
				     $(target).removeClass("invisible");

				     // When changing architecture reload to 
				     // make the page consistent wrt types
				     if (td_fname == "architecture") {
					 RegeneratePageBody();
				     }
				 });
	});
    }

    /*
     * Edit the type list.
     */
    function HandEditTypes(target)
    {
	console.info("HandEditTypes", target);

	var td_name   = $(target).closest("td");
	var td_field  = $(td_name).next();
	var td_value  = $(td_field).find("span").text();

	console.info(td_name, td_field, td_value);

	// Hide the edit button till we are done.
	$(target).addClass("invisible");

	// Hide the original
	$(td_field).find("span").addClass("hidden");

	/*
	 * Generate a list of checkboxes.
	 */
	var html = "";
	_.each(alltypes, function (typename) {
	    var checked = (_.indexOf(curtypes, typename) >= 0 ? "checked" : "");
	    
	    var box = "<span style='margin-right: 8px;'>" +
		"<input type=checkbox " + checked +
		" name='" + typename + "'> " + typename + "</span>";
	    html = html + box;
	});

	// Insert the edit buttons in a new span with the boxes
	$(td_field).append(
	    "<span class=editing>" + cancelbutton + savebutton +
		"<div>" + html + "</div></span>");

	// This activates the new tooltips we added above
	$(td_field).find('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});

	// Bind a cancel button to set things back the way they were.
	$(td_field).find(".cancel-button").click(function (event) {
	    event.preventDefault();
	    // Kill the span holding the buttons and input field.
	    $(td_field).find(".editing").remove();
	    // Show the original
	    $(td_field).find("span").removeClass("hidden");
	    // Show the edit button again
	    $(target).removeClass("invisible");
	});

	// Bind the save button.
	$(td_field).find(".save-button").click(function (event) {
	    event.preventDefault();

	    // Generate a list of checked boxes.
	    var newtypes = [];
	    $(td_field).find(":checked").each(function () {
		newtypes.push($(this).attr("name"));
	    });

	    sup.CallServerMethod(null, "image", "SetTypes",
				 {"uuid"     : window.UUID,
				  "typelist" : newtypes},
		 function(json) {
		     console.info("json", json);
		     if (json.code) {
			 sup.SpitOops("oops", json.value);
			 return;
		     }
		     // Kill the buttons/input field.
		     $(td_field).find(".editing").remove();
		     // Update and show the original
		     $(td_field).find("span")
			 .html(newtypes.join(" &nbsp; "))
			 .removeClass("hidden");
		     // Show the edit button again
		     $(target).removeClass("invisible");

		     // When changing types reload to make the page
		     // consistent wrt architecture
		     RegeneratePageBody();
		 });
	});
    }

    function SaveAdminNotes(done)
    {
	var notes = $(".adminnotes textarea").val();
	
	var callback = function(json) {
	    console.info("json", json);
	    if (json.code) {
		sup.SpitOops("oops", "Failed to save admin notes: " +
			     json.value);
		return;
	    }
	    done();
	};
    	var xmlthing = sup.CallServerMethod(null, "image", "SaveAdminNotes",
					    {"uuid"  : window.UUID,
					     "notes" : notes});
	xmlthing.done(callback);
    }

    /*
     * Edit shared/global
     */
    function HandEditSharedGlobal(target)
    {
	console.info("HandEditSharedGlobal", target);

	var td_name   = $(target).closest("td");
	var td_field  = $(td_name).next();
	var td_value  = $(td_field).find("span").text();

	console.info(td_name, td_field, td_value);

	// Hide the edit button till we are done.
	$(target).addClass("invisible");

	// Hide the original
	$(td_field).find("span").addClass("hidden");

	var radios = 
		'<span class="radios"> ' +
		'  <label class="radio-inline"> ' +
		'     <input type="radio" name="shared-global-radio" ' +
		'            id="shared-global-radio-shared"> Shared ' +
		'  </label> ' +
		'  <label class="radio-inline"> ' +
		'     <input type="radio" name="shared-global-radio" ' +
		' 	     id="shared-global-radio-global"> Global ' +
		'  </label> ' +
		'  <label class="radio-inline"> ' +
		'     <input type="radio" name="shared-global-radio" ' +
		'            id="shared-global-radio-neither"> Neither ' +
		'  </label> ' +
		'</span>';

	// Insert the edit buttons and radios in a new span.
	$(td_field).append(
	    "<span class=editing>" + cancelbutton + savebutton +
		"<div>" + radios + "</div></span>");

	// Set the correct radio.
	if (formfields["shared"]) {
	    $(td_field).find("#shared-global-radio-shared")
		.prop("checked", "checked");
	}
	else if (formfields["global"]) {
	    $(td_field).find("#shared-global-radio-global")
		.prop("checked", "checked");
	}
	else {
	    $(td_field).find("#shared-global-radio-neither")
		.prop("checked", "checked");
	}

	// This activates the new tooltips we added above
	$(td_field).find('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});

	// Bind a cancel button to set things back the way they were.
	$(td_field).find(".cancel-button").click(function (event) {
	    event.preventDefault();
	    // Kill the span holding the buttons and input field.
	    $(td_field).find(".editing").remove();
	    // Show the original
	    $(td_field).find("span").removeClass("hidden");
	    // Show the edit button again
	    $(target).removeClass("invisible");
	});

	// Bind the save button.
	$(td_field).find(".save-button").click(function (event) {
	    event.preventDefault();
	    var shared = $(td_field).find("#shared-global-radio-shared")
		.is(":checked");
	    var global = $(td_field).find("#shared-global-radio-global")
		.is(":checked");

	    sup.CallServerMethod(null, "image", "SetSharing",
				 {"uuid"    : window.UUID,
				  "shared"  : shared ? 1 : 0,
				  "global"  : global ? 1 : 0},
		 function(json) {
		     console.info("json", json);
		     if (json.code) {
			 sup.SpitOops("oops", json.value);
			 return;
		     }
		     // Kill the buttons/input field.
		     $(td_field).find(".editing").remove();
		     // Update and show the original
		     formfields["global"] = global;
		     formfields["shared"] = shared;
		     $(td_field).find("span")
			 .html((shared ? "Yes" : "No") + "/" +
			       (global ? "Yes" : "No"))
			 .removeClass("hidden");
		     // Show the edit button again
		     $(target).removeClass("invisible");
		 });
	});
    }    

    function DeleteImage()
    {
	var purge = $('#image-delete-purge').prop("checked") ? true : false;
	
	var callback = function(json) {
	    console.info("json", json);
	    if (json.code) {
		sup.HideWaitWait(function () {
		    sup.SpitOops("oops", "Failed to delete image: " +
				 json.value);
		    return;
		})
	    }
	    sup.HideWaitWait();
	    if (window.EMBEDDED) {
		window.parent.location.replace("../classic.php");
	    }
	    else {
		window.location.replace("user-dashboard.php");
	    }
	};
	sup.ShowWaitWait();
    	var xmlthing = sup.CallServerMethod(null, "image", "Delete",
					    {"uuid"  : window.UUID,
					     "purge" : purge});
	xmlthing.done(callback);
    }

    function SnapshotImage()
    {
	var nodeid = $.trim($('#snapshot-image-nodeid').val());
	if (nodeid == "") {
	    alert("Please specify the node id");
	    return;
	}
	var callback = function(json) {
	    console.info("json", json);
	    if (json.code) {
		sup.HideWaitWait(function () {
		    sup.SpitOops("oops", "Failed to start image snapshot: " +
				 json.value);
		});
		return;
	    }
	    var url = json.value;
	    console.info(url);
	    window.location.replace(url);
	};
	sup.ShowWaitWait();
    	var xmlthing = sup.CallServerMethod(null, "image", "Snapshot",
					    {"uuid"   : window.UUID,
					     "node_id": nodeid});
	xmlthing.done(callback);
    }
    
    $(document).ready(initialize);
});
