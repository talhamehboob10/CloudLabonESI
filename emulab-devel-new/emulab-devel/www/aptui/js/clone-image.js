$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['clone-image',
						   'oops-modal',
						   'waitwait-modal']);
    var mainString     = templates['clone-image'];
    var mainTemplate   = _.template(mainString);
    var formfields     = {};
    var projlist       = null;
    var oslist         = null;
    var osfeatures     = null;
    var alltypes       = null;
    var isadmin        = false;

    function JsonParse(id)
    {
	return 	JSON.parse(_.unescape($(id)[0].textContent));
    }
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	isadmin     = window.ISADMIN;
	projlist    = JsonParse('#projects-json');
	oslist      = JsonParse('#oslist-json');
	osfeatures  = JsonParse('#osfeatures-json');
	alltypes    = JsonParse('#alltypes-json');

	if (window.BASEIMAGE_UUID === undefined) {
	    GeneratePageBody(formfields);
	}
	else {
	    sup.CallServerMethod(null, "image", "GetInfo",
				 {"uuid" : window.BASEIMAGE_UUID},
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
    }

    //
    // Moved into a separate function since we want to regen the form
    // after each submit, which happens via ajax on this page. 
    //
    function GeneratePageBody(formfields)
    {
	var title;
	
	// Generate the template.
	var html = mainTemplate({
	    formfields:		formfields,
	    projects:           projlist,
	    isadmin:		isadmin,
	    alltypes:           alltypes,
	    oslist:		oslist,
	    osfeatures:         osfeatures,
	});
	html = aptforms.FormatFormFieldsHorizontal(html);
	$('#main-body').html(html);

	// Now we can do this. 
	$('#oops_div').html(templates['oops-modal']);
	$('#waitwait_div').html(templates['waitwait-modal']);

	// Set the correct shared/global radio.
	if (formfields["shared"]) {
	    $("#shared-global-radio-shared").prop("checked", "checked");
	}
	else if (formfields["global"]) {
	    $("#shared-global-radio-global").prop("checked", "checked");
	}
	else {
	    $("#shared-global-radio-neither").prop("checked", "checked");
	}
	// Project change handler, change group list
	$('#image_pid').change(function (event) {
	    UpdateGroupSelector();
	});

	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    trigger: 'hover',
	});

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    container: 'body'
	});
	aptforms.EnableUnsavedWarning('#clone-image-form');

	//
	// Handle submit button.
	//
	$('#clone-image-button').click(function (event) {
	    event.preventDefault();
	    SubmitForm();
	});
    }

    /*
     * When the project is changed, change group selector.
     */ 
    function UpdateGroupSelector()
    {
	var pid = $('#image_pid').val();
	var glist = projlist[pid];
	console.info(pid, glist);

	if (glist.length == 1) {
	    var gid = glist[0];

	    // Readonly form control.
	    $('#image_gid').html(
		"<input name=image_gid readonly " +
		    "       class='form-control' value='" + gid + "'>");
	    return;
	}
	var html = "";
	_.each(glist, function(gid) {
	    var selected = "";
	    // Select the project group by default.
	    if (gid == pid) {
		selected = "selected";
	    }
	    html = html +
		"<option " + selected + " value=" + gid + ">" +
		gid + "</option>";
	});
	$('#image_gid').html(
	    "<select name=image_gid class='form-control'>" +
		html + "</select>");
    }
    
    //
    // Submit the form.
    //
    function SubmitForm()
    {
	var submit_callback = function(json) {
	    console.info(json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    var url = json.value;
	    console.info(url);
	    window.location.replace(url);
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    aptforms.SubmitForm('#clone-image-form', "image", "Clone",
				submit_callback,
				"This will take a few minutes; " +
				"please be patient!");
	};
	aptforms.CheckForm('#clone-image-form', "image", "Clone",
			   checkonly_callback);
    }
    
    $(document).ready(initialize);
});


