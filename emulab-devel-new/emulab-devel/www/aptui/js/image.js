//
// Progress Modal
//
$(function () {
window.ShowImagingModal = (function()
    {
	'use strict';

        var imagingString = APT_OPTIONS.fetchTemplate('imaging-modal');
	var imagingTemplate = null;
	var imaging_modal_display = true;
	var imaging_modal_active  = false;
	var status_callback;
	var completion_callback;
	var laststatus = "preparing";

	function ShowImagingModalSecret()
	{
	    //
	    // Ask the server for information to populate the imaging modal. 
	    //
	    var callback = function(json) {
		var value = json.value;
		console.log("ShowImagingModal", json);

		if (json.code) {
		    if (imaging_modal_active) {
			sup.HideModal("#imaging-modal");
			imaging_modal_active = false;
			$('#imaging-modal').off('hidden.bs.modal');
		    }
		    sup.SpitOops("oops", "Server says: <br><pre><code>" +
				 json.value + "</code></pre>");
		    completion_callback(1);
		    return;
		}

		if (! imaging_modal_active && imaging_modal_display) {
		    sup.ShowModal("#imaging-modal");
		    imaging_modal_active  = true;
		    imaging_modal_display = false;

		    // Handler so we know the user closed the modal.
		    $('#imaging-modal').on('hidden.bs.modal', function (e) {
			imaging_modal_active = false;
			$('#imaging-modal').off('hidden.bs.modal');
		    })		
		}

		//
		// Fill in the details. 
		//
		if (! _.has(value, "node_status")) {
		    value["node_status"] = "unknown";
		}
		if (_.has(value, "image_size")) {
		    // We get KB to avoid overflow along the way. 
		    value["image_size"] = filesize(value["image_size"]*1024);
		}
		else {
		    value["image_size"] = "unknown";
		}	    
		$('#imaging_modal_node_status').html(value["node_status"]);
		$('#imaging_modal_image_size').html(value["image_size"]);

		var updateProgress = function (status, laststatus) {
		    if (status == "failed") {
			if (laststatus == "preparing") {
			    $('#tracker-imaging')
				.removeClass('progtrckr-todo');
			    $('#tracker-imaging')
				.addClass('progtrckr-failed');
			}
			if (laststatus == "imaging" ||
			    laststatus == "preparing") {
			    $('#tracker-finishing')
				.removeClass('progtrckr-todo');
			    $('#tracker-finishing')
				.addClass('progtrckr-failed');
			}
			if (laststatus == "imaging" ||
			    laststatus == "preparing" ||
			    laststatus == "finishing") {
			    $('#tracker-copying')
				.removeClass('progtrckr-todo');
			    $('#tracker-copying')
				.addClass('progtrckr-failed');
			}
			$('#tracker-ready').removeClass('progtrckr-todo');
			$('#tracker-ready').addClass('progtrckr-failed');
			$('#tracker-ready').html("Failed");
			return;
		    }
		    switch (status) {
		    case "ready":
			$('#tracker-ready').removeClass('progtrckr-todo');
			$('#tracker-ready').addClass('progtrckr-done');
		    case "copying":
			$('#tracker-copying').removeClass('progtrckr-todo');
			$('#tracker-copying').addClass('progtrckr-done');
		    case "finishing":
			$('#tracker-finishing').removeClass('progtrckr-todo');
			$('#tracker-finishing').addClass('progtrckr-done');
		    case "imaging":
			$('#tracker-imaging').removeClass('progtrckr-todo');
			$('#tracker-imaging').addClass('progtrckr-done');
		    }
		};
		var errmsg = "Internal error creating image";
		var status = null;
		if (_.has(value, "image_status")) {
		    status = value["image_status"];
		}
		//
		// We need to watch for exit before ready or fail.
		// Well, ready before exit is not supposed to happen.
		//
		if (_.has(value, "exited")) {
		    var exitcode = value["exitcode"];
		    
		    if (exitcode != 0 || status == "failed") {
			status = "failed";
			errmsg = value["errmsg"];
		    }
		    else if (status != "ready") {
			status = "failed";
		    }
		}
		if (status == "failed") {
		    updateProgress(status, laststatus);
		    $('#imaging-spinner').addClass("hidden");
		    $('#imaging-close').removeClass("hidden");
		    $('#imaging-modal-failure').html(errmsg);
		    $('#imaging_modal_failed_div').removeClass("hidden");
		    completion_callback(1);
		    return;
		}
		if (status != laststatus) {
		    updateProgress(status, laststatus);
		}
		if (status == "ready") {
		    if (_.has(value, "image_name")) {
			$('#imaging-done-modal-imagename')
			    .text(value["image_name"]);
			$('#imaging-modal-imagename')
			    .text(value["image_name"]);

			if (!imaging_modal_active) {
			    sup.ShowModal("#imaging-done-modal");
			}
			else {
			    $('#imaging_modal_done_div')
				.removeClass("hidden");
			}
		    }
		    $('#imaging_modal_node_status')
			.parent().addClass("hidden");
		    $('#imaging-spinner').addClass("hidden");
		    $('#imaging-close').removeClass("hidden");
		    completion_callback(0);
		    return;
		}
		if (status)
		    laststatus = status;

		// And check again in a little bit.
		setTimeout(function f() { ShowImagingModalSecret() }, 5000);
	    }

	    var $xmlthing = status_callback();
	    $xmlthing.done(callback);
	}

        return function(s_callback, c_callback, nokeyboard)
	{
	    status_callback = s_callback;
	    completion_callback = c_callback;

	    if (imagingTemplate == null) {
		imagingTemplate  = _.template(imagingString);
	    }
	    
	    var callback = function(json) {
		var value = json.value;
		console.log("ShowImagingModal Startup");
		console.log(json);
		
    		var imaging_html = imagingTemplate({
		    "needcopy"   : (_.has(json.value, "copyback_urn") ||
				    _.has(json.value, "copyback_uuid") ?
				    1 : 0),
		    "nokeyboard" : nokeyboard});
		$('#imaging_div').html(imaging_html);
		
		imaging_modal_display = true;	    
		ShowImagingModalSecret();
	    };
	    var $xmlthing = status_callback();
	    $xmlthing.done(callback);
	}
    }
)();
});
