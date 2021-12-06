//
// Common stuff for profiles.
//
$(function () {
window.profileSupport = (function ()
{
    var imagelistTemplate = null;

    function InitDelete()
    {
	var templates = APT_OPTIONS
	    .fetchTemplateList(['confirm-delete-profile',
				'profile-list-modal']);

	if ($('#confirm-delete-profile-div').html() == "") {
	    $('#confirm-delete-profile-div')
		.html(templates['confirm-delete-profile']);
	}
	imagelistTemplate  = _.template(templates['profile-list-modal']);
    }

    /*
     * Delete profile button
     */
    function DeleteVersion(version_uuid, warn, callback)
    {
	console.info("profile DeleteVersion", version_uuid);
	
	InitDelete();
	// Extra warning in the confirm delete modal.
	if (warn) {
	    $('#confirm-delete-profile-warning').removeClass("hidden");
	}
	else {
	    $('#confirm-delete-profile-warning').addClass("hidden");
	}
	$('#delete-all-versions').prop("checked", false);
	$('.ask-delete-all-versions').removeClass("hidden");
	$('.warn-delete-all-versions').addClass("hidden");
	
	// Bind the handler.
	$('#confirm-delete-profile-button').click(function (event) {
	    event.preventDefault();
	    var args = {
		"uuid" : version_uuid,
		"all"  : $('#delete-all-versions').is(':checked') ? 1 : 0,
	    };
	    sup.HideModal('#confirm-delete-profile-modal', function () {
		DeleteProfileConfirmed(args, false, false, false, callback);
	    });
	});
	sup.ShowModal('#confirm-delete-profile-modal',
		      // Delete handler no matter how it hides.
		      function () {
			  $('#confirm-delete-profile-button').off("click");
		      });
    }
    
    // Delete all versions of the profile. 
    function Delete(uuid, callback)
    {
	console.info("profile Delete", uuid);
	
	InitDelete();
	$('.ask-delete-all-versions').addClass("hidden");
	$('.warn-delete-all-versions').removeClass("hidden");
	
	// Bind the handler.
	$('#confirm-delete-profile-button').click(function (event) {
	    event.preventDefault();
	    var args = {
		"uuid" : uuid,
		"all"  : true,
	    };
	    sup.HideModal('#confirm-delete-profile-modal', function () {
		DeleteProfileConfirmed(args, false, false, false, callback);
	    });
	});
	sup.ShowModal('#confirm-delete-profile-modal',
		      // Delete handler no matter how it hides.
		      function () {
			  $('#confirm-delete-profile-button').off("click");
		      });
    }

    // Delete selected profiles.
    function DeleteSelected(selector, delete_callback)
    {
	var selected = $(selector + " .delete-profile-checkbox:checked");
	
	console.info("DeleteSelected", selector, selected);
	if (selected.length == 0) {
	    return;
	}
	InitDelete();

	var doit = async function() {
	    for (var i = 0; i < selected.length; i++) {
		var foo  = $(selected[i]);
		var row  = $(foo).closest("tr");
		var uuid = $(row).data("uuid");
		var pid  = $(row).data("pid");
		var name = $(row).data("name");
		var deferred = $.Deferred();
		var promise  = deferred.promise();
		console.info(pid, name, uuid);

		var args = {
		    "uuid" : uuid,
		    "pid"  : pid,
		    "name" : name,
		    "all"  : true,
		    "deferred" : deferred,
		};
		var message = "Deleting profile " + name +
		    " in project " + pid;
		
		if ($('#waitwait-modal').is(':visible')) {
		    // Update the message.
		    $('#waitwait-modal .waitwait-message span').html(message);
		}
		else {
		    sup.ShowWaitWait(message);
		}
		DeleteProfileConfirmed(args, false, false, true);
		await promise;
		// Kinda silly, I just want the value from the resolved promise
		var json = null;
		promise.then(function (value) {
		    json = value;
		});
		console.info("json", json);
		if (json) {
		    if (json.code) {
			break;
		    }
		    else {
			delete_callback(uuid, json);
		    }
		}
	    };
	    if ($('#waitwait-modal').is(':visible')) {
		sup.HideWaitWait();
	    }
	};
	// Bind the handler.
	$('#confirm-delete-selected-profiles-button').click(function (event) {
	    event.preventDefault();
	    sup.HideModal('#confirm-delete-selected-profiles-modal',
			  function () {
			      // Force the waitwait with message modal.
			      sup.ShowWaitWait("", undefined, doit);
			  });
	});
	sup.ShowModal('#confirm-delete-selected-profiles-modal',
		      // Delete handler no matter how it hides.
		      function () {
			  $('#confirm-delete-selected-profiles-button')
			      .off("click");
		      });
    }

    //
    // Delete is confirmed
    //
    function DeleteProfileConfirmed(args, force,
				    keepimages, multi, delete_callback)
    {
	var callback = function(json) {
	    console.info(json);

	    if (json.code) {
		if (json.code == 2) {
		    ShowDeletionWarning(args, multi,
					json.value, delete_callback);
		    return;
		}
		sup.HideWaitWait(function () {
		    sup.SpitOops("oops", json.value);
		});
		if (multi) {
		    args.deferred.resolve(json);
		}
		return;
	    }
	    if (multi) {
		args.deferred.resolve(json);
	    }
	    else {
		sup.HideWaitWait();
		if (delete_callback) {
		    delete_callback(args.uuid, json);
		}
	    }
	};
	var server_args = {
	    "uuid"     : args.uuid,
	    "all"      : args.all
	};
	if (force) {
	    args["force"] = 1;
	    if (keepimages) {
		args["keepimages"] = 1;
	    }
	}
	console.info("DeleteProfile", args);
	
	var xmlthing = sup.CallServerMethod(null, "manage_profile",
					    "DeleteProfile", server_args);

	if (multi) {
	    if (! $('#waitwait-modal').is(':visible')) {
		// Do not erase previous message.
		sup.ShowWaitWait(null);
	    }
	}
	else {
	    if (force && !keepimages) {
		sup.ShowWaitWait("Deleting images takes a minute; " +
				 "patience please");
	    }
	    else {
		sup.ShowWaitWait();
	    }
	}
	xmlthing.done(callback);
    }

    // Construct the image list warning from the template.
    function UpdateWarning(images)
    {
	/*
	 * See if we have any profiles to warn about. If only images, then
	 * the warning is different.
	 */
	var noprofiles = 1;
	_.each(images, function(profiles, imagename) {
	    _.each(profiles, function(value, name) {
		noprofiles = 0;
	    });
	});
	
	var html = imagelistTemplate({
	    "images"     : images,
	    "noprofiles" : noprofiles,
	});
	$('#profile-imagelist-modal-div').html(html);
    }

    // Warn about images tied to a profile being deleted.
    function ShowDeletionWarning(args, multi, images, callback)
    {
	UpdateWarning(images);
	
	/*
	 * Bind a handler for the force delete button.
	 */
	$('#confirm-force-delete').click(function (event) {
	    event.preventDefault();
	    // Keep images option.
	    var keepimages = $('#keep-profile-images').is(':checked') ? 1 : 0;

	    sup.HideModal('#profile-list-modal',
			  function () {
			      DeleteProfileConfirmed(args, true,
						     keepimages, multi,
						     callback);
			  });
	})
	$('#cancel-force-delete').click(function (event) {
	    sup.HideModal('#profile-list-modal', function () {
		// When deleting multiple profiles, cancel means move
		// to the the next profile. We do this by resolving
		// the deferred object but passing null.
		if (multi) {
		    args.deferred.resolve(null);
		}
	    });
	});
	sup.HideWaitWait(function () {
	    sup.ShowModal('#profile-list-modal',
			  // Delete handler no matter how it hides.
			  function () {
			      $('#confirm-force-delete').off("click");
			      $('#cancel-force-delete').off("click");
			  });
	});
    }

    // Exports from this module for use elsewhere
    return {
	"Delete"         : Delete,
	"DeleteVersion"  : DeleteVersion,
	"DeleteSelected" : DeleteSelected,
    };
})();
});
