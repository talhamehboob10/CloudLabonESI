//
// Parameter Set stuff
//
$(function () {
  window.paramsets = (function()
    {
	'use strict';
	var PNS = "http://www.protogeni.net/resources/rspec" +
	    "/ext/profile-parameters/1";

	/*
	 * Got this from:
	 * stackoverflow.com/questions/11892118/jquery-parsexml-and-print
	 */
	function xmlToString(xmlData)
	{ 
	    var xmlString;
	    //IE
	    if (window.ActiveXObject){
		xmlString = xmlData.xml;
	    }
	    // code for Mozilla, Firefox, Opera, etc.
	    else {
		var node = xmlData.item(0);
		xmlString = (new XMLSerializer()).serializeToString(node);
	    }
	    return xmlString;
	}   

	//
	// Throw up a modal to create and save a parameter set using the
	// provided profile and instance uuid. 
	//
	function InitSaveParameterSet(domid, profile_uuid, uuidORrspec)
	{
	    console.info("InitSaveParameterSet", domid, profile_uuid);

	    /*
	     * We need to know if the profile is public so we can init
	     * the public checkbox.
	     */
	    sup.CallServerMethod(null, "show-profile",
				 "GetProfile", {"profile" : profile_uuid},
				 function (json) {
				     console.info("profile", json);
				     if (json.code) {
					 sup.SpitOops("oops", json.value);
					 return;
				     }
				     InitAux(domid, profile_uuid, uuidORrspec,
					     json.value);
				 });
	}

	function InitAux(domid, profile_uuid, uuidORrspec, profile)
	{
	    var templates = APT_OPTIONS
		.fetchTemplateList(['save-paramset-modal']);
	    var template  = _.template(templates['save-paramset-modal']);
	    
	    $(domid).html(template({}));

	    var ispublic = profile.profile_public;

	    // If the profile is public, default public checkbox to true.
	    if (ispublic) {
		$('#paramset-public').prop("checked", true);
	    }

	    // Bind the save button.
	    $('#save-paramset-confirm').click(function (event) {
		SaveParameterSet(profile_uuid, uuidORrspec, profile);
	    });
	    sup.ShowModal('#save-paramset-modal', function () {
		$('#save-paramset-confirm').off("click");
	    });

	    // Bind the copy to clipbload button in the saved modal
	    window.APT_OPTIONS.SetupCopyToClipboard("#paramset-saved-modal");
	}

	// Save a paramset set.
	function SaveParameterSet(profile_uuid, uuidORrspec, profile)
	{
	    var name  = $.trim($('#paramset-name').val());
	    var desc  = $.trim($('#paramset-description').val());
	    var bound = $('#paramset-bound').is(':checked') ? 1 : 0;
	    var publc = $('#paramset-public').is(':checked') ? 1 : 0;
	    var ovwrt = $('#paramset-replace').is(':checked') ? 1 : 0;

	    var showError = function (which, error) {
		var id = "#save-paramset-modal ." + which + "-error";

		$(id).html(error);
		$(id).removeClass("hidden");
	    };
	    // Hide errors.
	    $('#save-paramset-modal .paramset-error').addClass("hidden");
	    // No blank fields please
	    if (name == "") {
		showError("name", "Please provide a name");
		return;
	    }
	    if (desc == "") {
		showError("description", "Please provide a description");
		return;
	    }
	    var args = {
		"profile"       : profile_uuid,
		"name"          : name,
		"description"   : desc,
		"bound"         : bound,
		"public"        : publc,
		"replace"       : ovwrt,
	    };
	    if (window.ISADMIN) {
		args["global"] = $('#paramset-global').is(':checked') ? 1 : 0;
	    }
	    if (sup.IsUUID(uuidORrspec)) {
		args["instance_uuid"] = uuidORrspec;
	    }
	    else {
		var xmlDoc   = $.parseXML(uuidORrspec);
		var bindings = xmlDoc.getElementsByTagNameNS(PNS, 'data_set');
		args["bindings"] = xmlToString(bindings);
		/*
		 * Coming from instantiate, need to pass along the specific
		 * repo/hash since might not be on head of default branch
		 * and the user wants it bound.
		 */
		if (bound) {
		    if (window.PROFILE_REFHASH) {
			args["repohash"] = window.PROFILE_REFHASH;
		    }
		    if (window.PROFILE_REFSPEC) {
			args["reporef"] = window.PROFILE_REFSPEC;
		    }
		}
	    }
	    console.info(args);
	    if (false) {
		sup.HideModal('#save-paramset-modal');
		return;
	    }
	    var callback = function (json) {
		console.info(json);
		if (json.code) {
		    var value = json.value;
		    
		    if (typeof json.value === 'object') {
			if (_.has(value, "name")) {
			    showError("name", value.name);
			}
			if (_.has(value, "description")) {
			    showError("description", value.description);
			}
			if (_.has(value, "error")) {
			    showError("general", value.error);
			}
		    }
		    else {
			showError("general", value);
		    }
		    return;
		}
		sup.HideModal('#save-paramset-modal', function () {
		    $('#paramset-saved-link').val(json.value);
		    sup.ShowModal('#paramset-saved-modal');
		});
	    };
	    sup.CallServerMethod(null, "paramsets", "Create", args, callback);
	}

	//
	// Throw up a modal to confirm parameter set deletion,
	//
	function InitDeleteParameterSet(uid, uuid, callback)
	{
	    console.info("InitDeleteParameterSet", uid, uuid);
	    
	    // Bind the confirm button.
	    $('#confirm-delete-paramset').click(function (event) {
		DeleteParameterSet(uid, uuid, callback);
	    });
	    sup.ShowModal('#delete-paramset-modal', function () {
		$('#confirm-delete-paramset').off("click");
	    });
	}

	// Delete a parameter set
	function DeleteParameterSet(uid, uuid, caller_callback)
	{
	    var args = {
		"uid"           : uid,
		"uuid"		: uuid,
	    };
	    var callback = function (json) {
		console.info(json);
		if (json.code) {
		    sup.SpitOops("oops", json.value);
		    return;
		}
		caller_callback();
	    };
	    sup.HideModal('#delete-paramset-modal', function () {
		sup.CallServerMethod(null, "paramsets", "Delete", args, callback);
	    });
	}

	// Exports from this module.
	return {
	    "InitSaveParameterSet"	: InitSaveParameterSet,
	    "InitDeleteParameterSet"    : InitDeleteParameterSet,
	};
    }
)();
});
