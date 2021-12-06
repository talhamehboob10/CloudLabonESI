$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['create-dataset', 'dataset-help', 'oops-modal', 'waitwait-modal']);
    var mainString = templates['create-dataset'];
    var helpString = templates['dataset-help'];
    var oopsString = templates['oops-modal'];
    var waitwaitString = templates['waitwait-modal'];
    var mainTemplate = _.template(mainString);
    var fields       = null;
    var fstypes      = null;
    var projlist     = null;
    var instances    = null;
    var amlist       = null;
    var editing      = false;
    var isadmin      = false;
    var embedded     = 0;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	embedded = window.EMBEDDED;
	isadmin  = window.ISADMIN;
	editing  = window.EDITING;
	fields   = JSON.parse(_.unescape($('#form-json')[0].textContent));
	if (! editing) {
	    fstypes = JSON.parse(_.unescape($('#fstypes-json')[0].textContent));
	    projlist =
		JSON.parse(_.unescape($('#projects-json')[0].textContent));
	}
	if (!embedded) {
	    instances =
		JSON.parse(_.unescape($('#instances-json')[0].textContent));
	    if ($('#amlist-json').length) {
		amlist = JSON.parse(_.unescape($('#amlist-json')[0].textContent));
	    }
	}
	GeneratePageBody(fields);

	// Now we can do this. 
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);	
    }

    //
    // Moved into a separate function since we want to regen the form
    // after each submit, which happens via ajax on this page. 
    //
    function GeneratePageBody(formfields)
    {
	// Generate the template.
	var html = mainTemplate({
	    formfields:		formfields,
	    fstypes:		fstypes,
	    projects:           projlist,
	    instancelist:	instances,
	    amlist:		amlist,
	    title:		window.TITLE,
	    embedded:		window.EMBEDDED,
	    editing:		editing,
	    isadmin:		isadmin,
	});
	html = aptforms.FormatFormFieldsHorizontal(html);
	$('#main-body').html(html);

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    container: 'body'
	});
	$('#dataset_help_link').popover({
	    html:     true,
	    content:  helpString,
	    trigger:  'manual',
	    placement:'auto',
	    container:'body',
	});
	$("#dataset_help_link").click(function(event) {
	    event.preventDefault();
	    $('#dataset_help_link').popover('show');
	    $('#dataset_popover_close').on('click', function(e) {
		$('#dataset_help_link').popover('hide');
	    });
	});
	
	// stdatasets need ro show the expiration date.
	var needexpire = false;
	if (formfields["dataset_type"] == "stdataset") {
	    needexpire = true;
	    if (!editing) {
		// Insert datepicker after html inserted.
		$(function() {
		    $("#dataset_expires").datepicker({
			showButtonPanel: true,
			dateFormat: "M d yy 11:59 'PM'",
			minDate: new Date(),
		    });
		    $("#dataset_expires").change(function (event) {
			var when = $("#dataset_expires").val();
			if (when != "") {
			    when = moment(when);
			    console.info(when, when.format());
			    $('#create_dataset_form [name=dataset_expires_gmt]')
				.val(when.format());
			}
		    });
		});
	    }
	    else {
		// Format dates with moment before display.
		var date = $('#dataset_expires').val();
		$('#dataset_expires').val(moment(date).format("lll"));
	    }
	}
	if (!editing) {
	    $('#create_dataset_form [name=dataset_type]').change(function() {
		var val = $(this).val();
		if (val == "stdataset") {
		    $('#dataset_expires_div').removeClass("hidden");
		    $('#dataset_size_div').removeClass("hidden");
		    $('#dataset_fstype_div').removeClass("hidden");
		    $('#dataset_cluster_div').removeClass("hidden");
		    $('#dataset_imageonly_div').addClass("hidden");
		}
		else if (val == "ltdataset") {
		    $('#dataset_expires_div').addClass("hidden");
		    $('#dataset_size_div').removeClass("hidden");
		    $('#dataset_fstype_div').removeClass("hidden");
		    $('#dataset_cluster_div').removeClass("hidden");
		    $('#dataset_imageonly_div').addClass("hidden");
		}
		else {
		    $('#dataset_expires_div').addClass("hidden");
		    $('#dataset_size_div').addClass("hidden");
		    $('#dataset_fstype_div').addClass("hidden");
		    $('#dataset_cluster_div').addClass("hidden");
		    $('#dataset_imageonly_div').removeClass("hidden");
		}
	    });
	}
	if (needexpire) {
	    $('#dataset_expires_div').removeClass("hidden");
	}

	// Handler for project change.
	if (!editing) {
	    $('#dataset_pid').change(function (event) {
		$("span[name='project_name']")
		    .html("project " + $('#dataset_pid option:selected').val());
	    });
	    // Initialize the span with default project.
	    if (projlist.length == 1) {
		$("span[name='project_name']")
		    .html("project " + $('#dataset_pid').html());
	    }
	    else {
		$("span[name='project_name']")
		    .html("project " + $('#dataset_pid option:selected').val());
	    }
  	}
	// Handler for instance change.
	if (instances) {
	    $('#dataset_instance').change(function (event) {
		$("#dataset_instance option:selected" ).each(function() {
		    HandleInstanceChange($(this).val());
		    return;
		});
	    });
	    // After error, need to rebuild selections lists
	    if (formfields.dataset_instance) {
		HandleInstanceChange(formfields.dataset_instance,
				     formfields.dataset_node,
				     formfields.dataset_bsname);
	    }
	}
	aptforms.EnableUnsavedWarning('#create_dataset_form');

	//
	// Handle submit button.
	//
	$('#dataset_submit_button').click(function (event) {
	    event.preventDefault();
	    SubmitForm();
	});
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
	    var url = null;
	    
	    if (editing) {
		url = json.value;
	    }
	    else {
		var dataset_uuid = json.value.dataset_uuid;
		url = "show-dataset.php?uuid=" + dataset_uuid;
	    }
	    var reload = function () {
		if (embedded) {
		    window.parent.location.replace("../" + url);
		}
		else {
		    window.location.replace(url);
		}
	    }
	    // Delay reload to show popup.
	    if (json.value.needapproval) {
		if (_.has(json.value, "unapproved_reason")) {
		    $('#needapproval-text').text(json.value.unapproved_reason);
		}
		sup.ShowModal('#needapproval-modal', function () { reload(); });
		return;
	    }
	    reload();
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    aptforms.SubmitForm('#create_dataset_form', "dataset",
				(editing ? "modify" : "create"),
				submit_callback,
				"This will take a minute or two; " +
				"please be patient!");
	};
	aptforms.CheckForm('#create_dataset_form', "dataset",
			   (editing ? "modify" : "create"),
			   checkonly_callback);
    }

    /*
     * When instance changes, need to get the manifest and find the a
     * node with a blockstore to offer the user. The node and bsname
     * args are optional, used for regenerating the form after an
     * error.
     */
    function HandleInstanceChange(uuid, selected_node, selected_bsname)
    {
	var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
	var noderefs  = {};

	// Clear old handler, set again below.
	$('#dataset_node').off("change");
	    
	var callback = function(json) {
	    /*
	     * Build up selection list of nodes in the instance that
	     * contain block stores.
	     */
	    var options = "";

	    _.each(json.value, function(manifest, aggregate_urn) {
		var xmlDoc = $.parseXML(manifest);
		var xml = $(xmlDoc);

		$(xml).find("node").each(function() {
		    var node   = $(this).attr("client_id");
		    var bslist = this.getElementsByTagNameNS(EMULAB_NS,
							     'blockstore');
		    var selected = (selected_node == node ? "selected" : "");

		    for (var i = 0; i < bslist.length; ++i) {
			var bsname   = $(bslist[i]).attr("name");
			var bsclass  = $(bslist[i]).attr("class");

			if (bsclass == "local") {
			    noderefs[node] = this;

			    options = options +
				"<option value='" + node +
				"' " + selected + " >" +
				node + "</option>";
			    return;
			}
		    }
		});
	    });
	    if (options == "") {
		$('#dataset_node')
		    .html("<option value=''>Please Select</option>");
		$('#dataset_bsname')
		    .html("<option value=''>Please Select</option>");
		
		sup.SpitOops("oops",
			     "The selected instance does not have any nodes " +
			     "that can be used to create an image backed dataset");
		return;
	    }
	    $('#dataset_node')
		    .html("<option value=''>Please Select</option>" + options);
	    $('#dataset_bsname')
		    .html("<option value=''>Please Select</option>");

	    $('#dataset_node').on("change", function (event) {
		$("#dataset_node option:selected").each(function() {
		    HandleInstanceNodeChange(noderefs[$(this).val()]);
		    return;
		});
	    });
	    if (selected_node && selected_bsname) {
		HandleInstanceNodeChange(noderefs[selected_node],
					 selected_bsname);
	    }
	};
	var xmlthing = sup.CallServerMethod(null, "status",
					    "GetInstanceManifest",
					    {"uuid" : uuid});
	xmlthing.done(callback);
    }

    function HandleInstanceNodeChange(noderef, selected_bsname)
    {
	var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";

	/*
	 * Build up selection list of blockstores on the node.
	 */
	var options = "";
	var bslist  = noderef.getElementsByTagNameNS(EMULAB_NS, 'blockstore');

	for (var i = 0; i < bslist.length; ++i) {
	    var bsname   = $(bslist[i]).attr("name");
	    var bsclass  = $(bslist[i]).attr("class");
	    var selected = (selected_bsname == bsname ? "selected" : "");
	    
	    if (bsclass == "local") {
		options = options +
		    "<option value='" + bsname + "' " + selected + " >" +
		    bsname + "</option>";
	    }
	}
	$('#dataset_bsname')
	    .html("<option value=''>Please Select</option>" + options);
    }

    $(document).ready(initialize);
});


