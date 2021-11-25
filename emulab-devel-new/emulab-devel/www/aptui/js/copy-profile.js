//
// Copy profile helper.
//
$(function () {
window.CopyProfile = (function ()
{
    'use strict';
    var target = null;

    function InitCopyProfile(button, profile, projects)
    {
	var templates = APT_OPTIONS.fetchTemplateList(['copy-profile-modal']);
	var copyTemplate = _.template(templates['copy-profile-modal']);

	// We might change this below
	target = profile;

	$('#copy-profile-modal-div').html(copyTemplate({
	    "projects" : projects,
	}));
	$('#copy-profile-confirm').click(function (e) {
	    e.preventDefault();
	    CopyProfile(target);
	});
	// Copy button throws up a modal.
	$(button).click(function (e) {
	    event.preventDefault();
	    sup.ShowModal('#copy-profile-modal');
	});
    }

    // Switch profile, as for instantiate
    function SwitchProfile(profile)
    {
	target = profile;
    }
    
    function CopyProfile(profile)
    {
	var nameitem = $('#copy-profile-modal .profile-name');
	var piditem  = $('#copy-profile-modal .profile-pid option:selected');
	var name     = $.trim($(nameitem).val());
	var pid      = $.trim($(piditem).val());

	console.info(name, pid);

	// Clear errors.
	$('#copy-profile-modal .copy-profile-error')
	    .addClass("hidden");	

	if (name == "") {
	    $('#copy-profile-modal .name-error')
		.html("Please provide a valid name")
		.removeClass("hidden");
	    return;
	}
	if (pid == "Please Select") {
	    $('#copy-profile-modal .pid-error')
		.html("Please select a project")
		.removeClass("hidden");
	    return;
	}

	var callback = function(json) {
	    console.info("CopyProfile", json);
	    if (json.code) {
		if (json.code == 2) {
		    var errors = json.value;
		    
		    if (_.has(errors, "name")) {
			$('#copy-profile-modal .name-error')
			    .html(errors.name)
			    .removeClass("hidden");
		    }
		    if (_.has(errors, "pid")) {
			$('#copy-profile-modal .pid-error')
			    .html(errors.pid)
			    .removeClass("hidden");
		    }
		}
		else {
		    $('#copy-profile-modal .general-error')
			.html(json.value)
			.removeClass("hidden");
		}
		return;
	    }
	    var url = "manage_profile.php?uuid=" + json.value +
		"&action=edit";
	    $('#profile-copied-modal a').attr("href", url);
	    
	    sup.HideModal('#copy-profile-modal', function () {
		sup.ShowModal('#profile-copied-modal');
	    });
	};
	var xmlthing = sup.CallServerMethod(null,
					    "manage_profile", "Duplicate",
					    {"name"     : name,
					     "pid"      : pid,
					     "profile"  : profile});
	xmlthing.done(callback);
    }
    // Exports from this module for use elsewhere
    return {
	"InitCopyProfile" : InitCopyProfile,
	"CopyProfile"     : CopyProfile,
	"SwitchProfile"   : SwitchProfile,
    };
}
)();
});
