$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['show-dataset', 'snapshot-dataset', 'oops-modal', 'waitwait-modal']);
    var mainString = templates['show-dataset'];
    var snapshotString = templates['snapshot-dataset'];
    var oopsString = templates['oops-modal'];
    var waitwaitString = templates['waitwait-modal'];


    var mainTemplate    = _.template(mainString);
    var snapTemplate    = _.template(snapshotString);
    var dataset_uuid    = null;
    var embedded        = 0;
    var canrefresh      = 0;
    var cansnapshot     = 0;
    var instances       = null;
    var current_state   = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	dataset_uuid = window.UUID;
	embedded     = window.EMBEDDED;
	canrefresh   = window.CANREFRESH;
	cansnapshot  = window.CANSNAPSHOT;

	var fields = JSON.parse(_.unescape($('#fields-json')[0].textContent));
	if (!embedded && cansnapshot) {
	    instances =
		JSON.parse(_.unescape($('#instances-json')[0].textContent));
	}
	
	// Generate the main template.
	var html   = mainTemplate({
	    formfields:		fields,
	    candelete:	        window.CANDELETE,
	    canapprove:	        window.CANAPPROVE,
	    canrefresh:	        window.CANREFRESH,
	    cansnapshot:        window.CANSNAPSHOT,
	    embedded:		embedded,
	    title:		window.TITLE,
	});
	$('#main-body').html(html);

	// Now we can do this. 
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);	

	// Initialize the popover system.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    container: 'body',
	    placement: 'auto',
	});
	
	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});

	//
	// When embedded, we want the links to go through the outer
	// frame not the inner iframe.
	//
	if (embedded) {
	    $('*[id*=embedded-anchors]').click(function (event) {
		event.preventDefault();
		var url = $(this).attr("href");
		console.info(url);
		window.parent.location.replace("../" + url);
		return false;
	    });
	}
	// Refresh.
	$('#dataset_refresh_button').click(function (event) {
	    event.preventDefault();
	    RefreshDataset();
	});
	
	// Snapshot for imdatasets
	if (cansnapshot) {
	    $('#dataset_snapshot_button').click(function (event) {
		event.preventDefault();
		ShowSnapshotModal(null, null);
	    });
	}
	
	// Confirm Delete
	$('#delete-confirm').click(function (event) {
	    event.preventDefault();
	    DeleteDataset();
	});
	// Confirm Approve
	$('#approve-confirm').click(function (event) {
	    event.preventDefault();
	    ApproveDataset();
	});
	// Confirm Extend
	$('#extend-confirm').click(function (event) {
	    event.preventDefault();
	    ExtendDataset();
	});

	/*
	 * If the state is busy, then lets poll watching for it to
	 * go valid.
	 */
	current_state = fields.dataset_state;
	if (fields.dataset_type == "imdataset" &&
	    (fields.dataset_state == "busy" ||
	     fields.dataset_state == "allocating")) {
	    ShowProgressModal();
	}
	else if (fields.dataset_type != "imdataset") {
	    // Always poll for st/lt change in status.
	    setTimeout(function f() { StateWatch() }, 5000);
	}
    }

    // Periodically ask the server for the status.
    function StateWatch()
    {
	var callback = function(json) {
	    if (json.code) {
		console.info(json);
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (current_state != json.value.state) {
		window.location.reload(true);
		return;
	    }
	    if (json.size) {
		$('#dataset_size').html(json.size);
	    }
	    var next = (json.value.state == "busy" ||
			json.value.state == "allocating" ? 10000 : 60000);
	    
	    setTimeout(function f() { StateWatch() }, next);
	}
	var xmlthing = sup.CallServerMethod(null, "dataset",
					    "getinfo",
					    {"uuid" : dataset_uuid});
	xmlthing.done(callback);
    }
    
    function ShowProgressModal()
    {
        ShowImagingModal(
	    function()
	    {
		return sup.CallServerMethod(null,
					    "dataset",
					    "getinfo",
					    {"uuid" :
					     dataset_uuid});
	    },
	    function(failed)
	    {
		// Update the status/size.
		if (!failed) {
		    var callback = function(json) {
			if (!json.code) {
			    $('#dataset_state').html(json.value.state);
			    $('#dataset_size').html(json.value.size);
			}
		    };
		    var xmlthing = sup.CallServerMethod(null,
							"dataset",
							"getinfo",
							{"uuid" :
							 dataset_uuid});
		    xmlthing.done(callback);
		}
	    });
    }

    //
    // Delete dataset.
    //
    function DeleteDataset()
    {
	var callback = function(json) {
	    sup.HideModal('#waitwait-modal');
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (embedded) {
		window.parent.location.replace("../" + json.value);
	    }
	    else {
		window.location.replace(json.value);
	    }
	}
	sup.HideModal('#delete_modal', function () {
	    sup.ShowModal("#waitwait-modal");
	    var xmlthing = sup.CallServerMethod(null,
						"dataset",
						"delete",
						{"uuid" : dataset_uuid,
						 "embedded" : embedded});
	    xmlthing.done(callback);
	});
    }
    //
    // Refresh
    //
    function RefreshDataset()
    {
	var callback = function(json) {
	    sup.HideModal('#waitwait-modal');
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    window.location.reload(true);
	}
	sup.ShowModal("#waitwait-modal");
	var xmlthing = sup.CallServerMethod(null,
					    "dataset",
					    "refresh",
					    {"uuid" : dataset_uuid});
	xmlthing.done(callback);
    }
    //
    // Approve dataset.
    //
    function ApproveDataset()
    {
	var callback = function(json) {
	    sup.HideModal('#waitwait-modal');
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (embedded) {
		window.parent.location.replace("../" + json.value);
	    }
	    else {
		window.location.replace(json.value);
	    }
	}
	sup.HideModal('#approve_modal');
	sup.ShowModal("#waitwait-modal");
	var xmlthing = sup.CallServerMethod(null,
					    "dataset",
					    "approve",
					    {"uuid" : dataset_uuid});
	xmlthing.done(callback);
    }
    //
    // Extend dataset.
    //
    function ExtendDataset()
    {
	var callback = function(json) {
	    sup.HideModal('#waitwait-modal');
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (embedded) {
		window.parent.location.replace("../" + json.value);
	    }
	    else {
		window.location.replace(json.value);
	    }
	}
	sup.HideModal('#extend_modal');
	sup.ShowModal("#waitwait-modal");
	var xmlthing = sup.CallServerMethod(null,
					    "dataset",
					    "extend",
					    {"uuid" : dataset_uuid});
	xmlthing.done(callback);
    }

    /*
     * Show the snapshot modal/form for imdatasets.
     */
    function ShowSnapshotModal(formfields)
    {
	if (formfields === null) {
	    formfields = {};
	}
	// Generate the main template.
	var html   = snapTemplate({
	    formfields:         formfields,
	    dataset_uuid:       dataset_uuid,
	    embedded:		embedded,
	    instancelist:	instances,
	});
	html = aptforms.FormatFormFieldsHorizontal(html);
	$('#snapshot_div').html(html);

	// Handler for instance change.
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
	
	//
	// Handle submit button.
	//
	$('#snapshot_submit_button').click(function (event) {
	    sup.HideModal("#snapshot_modal");
	    event.preventDefault();
	    SubmitForm();
	});
	sup.ShowModal("#snapshot_modal");
    }

    //
    // Submit the form.
    //
    function SubmitForm()
    {
	var submit_callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (embedded) {
		window.parent.location.replace("../" + json.value);
	    }
	    else {
		window.location.replace(json.value);
	    }
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    aptforms.SubmitForm('#snapshot_dataset_form', "dataset", "modify",
				submit_callback);
	};
	aptforms.CheckForm('#snapshot_dataset_form', "dataset", "modify",
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


