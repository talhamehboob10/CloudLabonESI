$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['manage-profile', 'waitwait-modal', 'renderer-modal', 'showtopo-modal', 'oops-modal', 'rspectextview-modal', 'publish-modal', 'share-modal', 'gitrepo-picker', 'copy-repobased-profile']);
    var manageString = templates['manage-profile'];
    var waitwaitString = templates['waitwait-modal'];
    var rendererString = templates['renderer-modal'];
    var showtopoString = templates['showtopo-modal'];
    var oopsString = templates['oops-modal'];
    var rspectextviewString = templates['rspectextview-modal'];
    var publishString = templates['publish-modal'];
    var shareString = templates['share-modal'];
    var gitrepoString = templates['gitrepo-picker'];
    var copyrepoString = templates['copy-repobased-profile'];

    var profile_uuid = null;
    var profile_name = '';
    var profile_pid = '';
    var profile_version = '';
    var version_uuid = null;
    var snapping     = 0;
    var gotrspec     = 0;
    var gotscript    = 0;
    var goodscript   = 0;
    var fromrepo     = 0;
    var repohash     = null;
    var reporefspec  = null;
    var repobusy     = false;
    var ajaxurl      = "";
    var amlist       = null;
    var modified     = false;
    var editor       = null;
    var myCodeMirror = null;
    var isppprofile  = false;
    var profile      = null;
    var isadmin      = 0; 
    var multisite    = 0; 
    var APT_NS    = "http://www.protogeni.net/resources/rspec/ext/apt-tour/1";
    var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
    var EMULAB_OPS        = "emulab-ops";
    var manageTemplate    = _.template(manageString);
    var waitwaitTemplate  = _.template(waitwaitString);
    var rendererTemplate  = _.template(rendererString);
    var showtopoTemplate  = _.template(showtopoString);
    var rspectextTemplate = _.template(rspectextviewString);
    var oopsTemplate      = _.template(oopsString);
    var shareTemplate     = _.template(shareString);
    var gitrepoTemplate   = _.template(gitrepoString);
    var stepsInitialized  = false;
    var portal_converted  = false;

    var pythonRe = /^import/m;
    var tclRe    = /^source tb_compat/m;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	snapping      = window.SNAPPING;
	version_uuid  = window.VERSION_UUID;
	profile_uuid  = window.PROFILE_UUID;
	ajaxurl       = window.AJAXURL;
	isppprofile   = window.ISPPPROFILE;
	isadmin       = window.ISADMIN;
	multisite     = window.MULTISITE;

	// Standard option
	marked.setOptions({"sanitize" : true});

	var fields   = JSON.parse(_.unescape($('#form-json')[0].textContent));
	var errors   = JSON.parse(_.unescape($('#error-json')[0].textContent));
	var projlist = JSON.parse(_.unescape($('#projects-json')[0].textContent));
	profile = fields;
	var versions = null;
	var sorted_versions = null;
	if (window.VIEWING) {
	    versions =
		JSON.parse(_.unescape($('#versions-json')[0].textContent));

	    sorted_versions = _.sortBy(versions, function(profile) {
		return versions.length - profile.version;
	    });
	}
	amlist = JSON.parse(_.unescape($('#amlist-json')[0].textContent));

	// Notice if we have an rspec in the formfields, to start from.
	if (_.has(fields, "profile_rspec")) {
	    gotrspec = 1;
	}
	// Ditto a script.
	if (_.has(fields, "profile_script") && fields["profile_script"] != "") {
	    gotscript = 1;
	    goodscript = 1;
	    if (_.has(fields, "portal_converted") &&
		fields["portal_converted"] == "yes") {
		portal_converted = 1;
	    }
	}
	// Ditto a repourl
	if (_.has(fields, "profile_repourl") &&
	    fields["profile_repourl"] != "") {
	    fromrepo = 1;
	    repohash = fields["profile_repohash"];
	    setTimeout(function f() { CheckRepoChange() }, 10000);
	}

        // If this is an existing profile, stash the name/project
        if (_.has(fields, "profile_name")) {
	    profile_name = fields['profile_name'];
        }
        if (_.has(fields, "profile_pid")) {
	    profile_pid = fields['profile_pid'];
        }
        if (_.has(fields, "profile_version")) {
	    profile_version = fields['profile_version'];
        }
	
	// no place to show rspec errors, so convert to general error.
	if (_.has(errors, "rspec")) {
	    errors.error = "rspec: " + errors.rspec;
	}

	// Warn user if they have not saved changes.
        $(window).on('beforeunload.portal', function() {
	    if (! modified && ! window.GENILIB_EDITOR_CHANGED())
		return undefined;
	    return "You have unsaved changes!";
        });

	// Generate the templates.
	var manage_html   = manageTemplate({
	    formfields:		fields,
	    projects:		projlist,
	    title:		window.TITLE,
	    notifyupdate:	window.UPDATED,
	    viewing:		window.VIEWING,
	    gotrspec:		gotrspec,
	    gotscript:		gotscript,
	    action:		window.ACTION,
	    button_label:       window.BUTTONLABEL,
	    version_uuid:	window.VERSION_UUID,
	    profile_uuid:	window.PROFILE_UUID,
	    latest_uuid:	window.LATEST_UUID,
	    latest_version:	window.LATEST_VERSION,
	    candelete:		window.CANDELETE,
	    canmodify:		window.CANEDIT,
	    canpublish:		window.CANPUBLISH,
	    isadmin:		window.ISADMIN,
	    isstud:		window.ISSTUD,
	    iscreator:		window.ISCREATOR,
	    isleader:		window.ISLEADER,
	    history:		window.HISTORY,
	    activity:		window.ACTIVITY,
	    paramsets:		window.PARAMSETS,
	    manual:             window.MANUAL,
	    copyuuid:		(window.COPYUUID || null),
	    snapuuid:		(window.SNAPUUID || null),
	    snapnode_id:	(window.SNAPNODE_ID || null),
	    general_error:      (errors.error || ''),
	    isapt:              window.ISAPT,
	    disabled:           window.DISABLED,
	    nodelete:           window.NODELETE,
	    versions:	        versions,
	    sorted_versions:    sorted_versions,
	    withpublishing:     window.WITHPUBLISHING,
	    genilib_editor:     false,
	    canrepo:            window.CANREPO,
	    fromrepo:           fromrepo,
	    portal_converted:   portal_converted
	});
	manage_html = aptforms.FormatFormFieldsHorizontal(manage_html,
							  {"wide" : true});
	$('#page-body').html(manage_html);
	
    	var waitwait_html = waitwaitTemplate({});
	$('#waitwait_div').html(waitwait_html);
    	var showtopo_html = showtopoTemplate({});
        $('#showtopomodal_div').html(showtopo_html);
    	var renderer_html = rendererTemplate({});
	$('#renderer_div').html(renderer_html);
    	var oops_html = oopsTemplate({});
	$('#oops_div').html(oops_html);
	$('#publish_div').html(publishString);
    	var rspectext_html = rspectextTemplate({});
	$('#rspectext_div').html(rspectext_html);
	$('#share_div').html(shareTemplate({
	    formfields: fields,
	    fromrepo:   fromrepo
	}));
	$('#copy_repobased_profile_div').html(copyrepoString);

	// Fireoff repo stuff now.
	if (fromrepo) {
	    SetupRepo();

	    // Handler for the copy repobased profile help modal.
	    // Need to fill in the URL.
	    $('#copy-repobased-profile-modal input')
		.val(fields["profile_repourl"]);
	    $('#copy-repobased-profile-modal .copy-to-clipboard')
		.click(function (e) {
		    e.preventDefault();
		    $('#copy-repobased-profile-modal .gitrepo-url').select();
		    document.execCommand("copy");
		});
	}
	// Copy profile.
	CopyProfile.InitCopyProfile('#copy-profile-button',
				    version_uuid, projlist);
	
	//
	// Fix for filestyle problem; not a real class I guess, it
	// runs at page load, and so the filestyle'd button in the
	// form is not as it should be.
	//
	$('#sourcefile, #rspec_modal_upload_button').each(function() {
	    $(this).filestyle({input      : false,
			       buttonText : $(this).attr('data-buttonText'),
			       classButton: $(this).attr('data-classButton')});
	});

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	    container: 'body',
	});
	// But the repo push URL is handled differently.
	var urlstring = 
	    "<div style='width 100%'> "+
	    "  <input readonly type=text id='push-url-input' " +
	    "       style='display:inline; width: 93%; padding: 2px;' " +
	    "       class='form-control input-sm' "+
	    "       value='" + fields.profile_repopushurl + "'>" +
	    "  <a href='#' class='btn' id='push-url-copy' " +
	    "     style='padding: 0px'>" +
	    "    <span class='glyphicon glyphicon-copy'></span></a></div>";
	
	$('#push-url').click(function (e) {
	    console.info("push-url click");
	    if ($('#push-url-input').length == 0) {
		$('#push-url').popover({
		    html:     true,
		    content:  urlstring,
		    trigger:  'manual',
		    placement:'auto',
		    container:'body',
		});
		$('#push-url').popover('show');
		$('#push-url-copy').click(function (e) {
		    e.preventDefault();
		    $('#push-url-input').select();
		    document.execCommand("copy");
		    $('#push-url').popover('destroy');
		});
		$('#push-url-input').click(function (e) {
		    e.preventDefault();
		    $('#push-url').popover('destroy');
		});
	    }
	    else {
		$('#push-url').popover('destroy');
	    }
	});
	
	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	$('body').show();

	//
	// File upload handler.
	// 
	$('#sourcefile, #rspec_modal_upload_button').change(function() {
	    var reader = new FileReader();
	    var button = $(this);

	    reader.onload = function(event) {
		var newrspec = event.target.result;
		    
		/*
		 * Clear the file so that the change handler will
		 * run if the same file is selected again (say, after
		 * fixing a script error).
		 */
		$("#sourcefile, #rspec_modal_upload_button").filestyle('clear');

		/*
		 * If the modal upload button is used, we want to change the
		 * contents of the modal only. User has to accept the change.
		 */
		if ($(button).attr("id") == "rspec_modal_upload_button") {
		    $('#modal_profile_rspec_textarea').val(newrspec);
		    // The modal shown event updates the code in the modal.
		    $('#rspec_modal').trigger('shown.bs.modal');
		}
		else {
		    changeRspec(newrspec);
		}
	    };
	    reader.readAsText(this.files[0]);
	});

	$('#edit_topo_modal_button').click(function (event) {
	    event.preventDefault();
	    // Do this now instead of on page load, since user might switch
	    // between geni-lib and rspec, and that changes whether the
	    // editor is read-only or writable.
	    CreateJacksEditor();
	    editor.show($('#profile_rspec_textarea').val(),
			function (newrspec) {
			    // Only for a new profile or profile converted
			    if (!fromrepo && portal_converted) {
				ConvertToGenilib(newrspec);
			    }
			    else {
				// Plain old rspec. SAD!
				changeRspec(newrspec);
			    }
			});
	});
	// The Show Source button.
	$('#show_source_modal_button').click(function (event) {
	    //
	    // The "source" is either the script or the XML if there
	    // is no script.
	    //
	    var source = $('#profile_script_textarea').val();
	    var type   = "source";
	    if (source.length > 0 &&
		(window.ACTION === 'edit' ||
		 window.ACTION === 'create') && !fromrepo) {
	        openEditor(source);
	    } else {
	        if (source.length === 0) {
		    source = $('#profile_rspec_textarea').val();
		  type = "rspec";
		}
	        if (profile_uuid) {
	            sup.DownloadOnClick($('#rspec_modal_download_button'),
				        function () { return source; },
				        'profile.xml');
/*		    $('#rspec_modal_download_button')
		        .attr("href",
			      "show-profile.php?uuid=" + profile_uuid +
			      "&" + type + "=true");*/
	        }
	        else {
	            sup.ClearDownloadOnClick($('#rspec_modal_download_button'));
//		    $('#rspec_modal_download_button').addClass("hidden");
	        }
		if (!fromrepo) {
	            $('#rspec_modal_upload_span').removeClass("hidden");
	            $('#rspec_modal_editbuttons').removeClass("hidden");
	            $('#rspec_modal_viewbuttons').addClass("hidden");
	            $('#modal_profile_rspec_textarea').prop("readonly", false);
		}
		else {
		    // No editing repo-based profiles
	            $('#rspec_modal_upload_span').addClass("hidden");
	            $('#rspec_modal_editbuttons').addClass("hidden");
	            $('#rspec_modal_viewbuttons').removeClass("hidden");
	            $('#modal_profile_rspec_textarea').prop("readonly", true);
		}
	        $('#modal_profile_rspec_textarea').val(source);
	        $('#rspec_modal').modal({'backdrop':'static','keyboard':false});
	        $('#rspec_modal').modal('show');
	    }
	});
	// The Show XML button.
	$('#show_xml_modal_button').click(function (event) {
	    //
	    // Show the XML source in the modal. This is used when we
	    // have a script, and the XML was generated. We show the
	    // XML, but it is not intended to be edited.
	    //
	    var source = $.trim($('#profile_rspec_textarea').val());

	    if (profile_uuid) {
	        sup.DownloadOnClick($('#rspec_modal_download_button'),
				    function () { return source; },
				    'profile.xml');
/*		$('#rspec_modal_download_button')
		    .attr("href",
			  "show-profile.php?uuid=" + profile_uuid +
			  "&rspec=true");*/
	    }
	    else {
	        sup.ClearDownloadOnClick($('#rspec_modal_download_button'));
		$('#rspec_modal_download_button').addClass("hidden");
	    }	    
	    $('#rspec_modal_upload_span').addClass("hidden");
	    $('#rspec_modal_editbuttons').addClass("hidden");
	    $('#rspec_modal_viewbuttons').removeClass("hidden");
	    $('#modal_profile_rspec_textarea').val(source);
	    $('#modal_profile_rspec_textarea').prop("readonly", true);
	    $('#rspec_modal').modal({'backdrop':'static','keyboard':false});
	    $('#rspec_modal').modal('show');
	});
	
        $('#rspec_modal').on('shown.bs.modal', function() {
	    var source   = $('#modal_profile_rspec_textarea').val();
	    var mode     = "text/xml";
	    var readonly = window.CLONING || fromrepo ||
		$('#modal_profile_rspec_textarea').prop("readonly");

	    // Need to determine the mode.
	    if (pythonRe.test(source)) {
		mode = "text/x-python";
	    }
	    else if (tclRe.test(source)) {
		mode = "text/x-tcl";
	    }
	    // In case we got here via the modal upload button, need to
	    // kill the current contents. 
	    $('.CodeMirror').remove();
	    
	    myCodeMirror = CodeMirror(function(elt) {
		$('#modal_profile_rspec_div').prepend(elt);
	    }, {
		value: source,
                lineNumbers: true,
		smartIndent: true,
		autofocus: true,
                mode: mode,
		readOnly: readonly,
	    });

	    //
	    // Attempt to catch an insertion of python code, either to
	    // the empty source box, or as a replacement. 
	    //
	    var watchdog_timer;
	    myCodeMirror.on("change", function() {
		clearTimeout(watchdog_timer);
		watchdog_timer =
		    setTimeout(function() {
			var source = myCodeMirror.getValue();
			
			if (pythonRe.test(source)) {
			    myCodeMirror.setOption("mode", "text/x-python");
			}
			else if (tclRe.test(source)) {
			    myCodeMirror.setOption("mode", "text/x-tcl");
			}
		    }, 500);
	    });
        });
	// Collapse; done editing the rspec in the modal.
	$('#collapse_rspec_modal_button').click(function (event) {
	    $('#rspec_modal').modal('hide');
	    changeRspec(myCodeMirror.getValue());
	    $('.CodeMirror').remove();
	    $('#modal_profile_rspec_textarea').val("");
	});
	// Cancel; done editing the rspec in the modal, throw away and cleanup.
	$('#cancel_rspec_modal_button, #close_rspec_modal_button')
	    .click(function (event) {
	    $('#rspec_modal').modal('hide');
	    $('.CodeMirror').remove();
	    $('#modal_profile_rspec_textarea').val("");
	});
	// Auto select the URL if the user clicks in the box.
	$('#profile_url').click(function() {
	    $(this).focus();
	    $(this).select();
	});
	// Handle Tour collapse/expand link..
	$('#profile_steps_collapse').on('hide.bs.collapse', function () {
	    $('#profile_steps_link').text("Show/Edit Tour");
	})	
	$('#profile_steps_collapse').on('show.bs.collapse', function () {
	    $('#profile_steps_link').text("Hide Tour");
	})
	
	// Delete profile button.
	$('#profile_delete_button').click(function (event) {
	    event.preventDefault();
	    profileSupport
		.DeleteVersion(version_uuid,
			       // Extra warning in the confirm modal.
			       window.THIS_VERSION == window.LATEST_VERSION,
			       function (uuid, json) {
				   // Successful deletion, we have to
				   // go someplace else.
				   window.location.replace(json.value);
			       });
	});

	// Git repo URL modal.
	$('#git-repo-confirm').click(function (event) {
	    event.preventDefault();
	    HandleGitRepoChange();
	});
	// Git repo update button
	$('#git-repo-update-button').click(function (event) {
	    event.preventDefault();
	    HandleGitRepoUpdate();
	});
	// Convert rspec profile to geni-lib
	$('#profile-convert-confirm').click(function (event) {
	    event.preventDefault();
	    sup.HideModal('#profile-convert-modal',
			  function () {
			      ConvertToGenilib();
			  });
	});

	//
	// Perform actions on the rspec before submit.
	//
	$('#profile_submit_button').click(function (event) {
	    event.preventDefault();
	    
	    // Prevent submit if the description is empty.
	    var description = $('#profile_description .textdiv').html();
	    if (description === "") {
		alert("Please provide a description. Its required!");
		return false;
	    }
	    // Add steps to the tour.
	    if (SyncSteps()) {
		return false;
	    }
	    if (window.CLONING) {
		/*
		 * If cloning into the system project, need to warn the user
		 * about potentially messing with a system image.
		 */
		var pid;
		if (projlist.length == 1) {
		    pid = $('$profile_pid').val();
		}
		else {
		    pid = $('#profile_pid option:selected').val();
		}
		if (pid == EMULAB_OPS) {
		    $('#cancel-update-systemimage').click(function() {
			sup.HideModal('#confirm-update-systemimage-modal');
		    });
		    $('#confirm-update-systemimage').click(function() {
			sup.HideModal('#confirm-update-systemimage-modal');
			SubmitForm();
		    });
		    sup.ShowModal('#confirm-update-systemimage-modal',
				  function() {
				      $('#cancel-update-systemimage')
					  .off("click");
				      $('#confirm-update-systemimage')
					  .off("click");
				  });
		}
		else {
		    // Need to ask if any extra accounts created.
		    sup.ShowModal('#clone-modal', function () {
			if ($('#clone-modal-update-prepare').is(':checked')) {
			    $('#quickvm_create_profile_form ' +
			      '[name=update_prepare]').val("yes");
			}
			SubmitForm();
		    });
		}
	    }
	    else {
		SubmitForm();
	    }
	});

	/*
	 * Cancel Edit button.
	 */
	$('#cancel_edit_button').click(function (e) {
	    e.preventDefault();

	    /*
	     * Bind a handler for the confirm button,
	     */
	    $('#confirm_cancel_edit').click(function (event) {
		event.preventDefault();
		modified = false;
		window.location.reload();
	    })
	    sup.ShowModal('#confirm_cancel_edit_modal',
			  // Delete handler no matter how it hides.
			  function () {
			      $('#confirm_cancel_edit').off("click");
			  });
	});

	/*
	 * If the description/instructions textarea are edited, copy
	 * the text back into the rspec since that is what actually
	 * gets submitted; the rspec is authoritative.
	 */
	$('#profile_instructions textarea').change(function() {
	    TourModified("instructions");
	    ProfileModified();
	});
	$('#profile_description textarea').change(function() {
	    TourModified("description");
	    ProfileModified();
	});

	// Change handlers for the checkboxes to enable the submit button.
	$('#profile_name').change(function() { ProfileModified(); });
	$('#profile_pid').change(function() { ProfileModified(); });
	$('#profile_listed').change(function() { ProfileModified(); });
	$('#profile_who_public').change(function() { ProfileModified(); });
	$('#profile_who_registered').change(function() { ProfileModified(); });
	$('#profile_who_private').change(function() { ProfileModified(); });
	$('#profile_topdog').change(function() { ProfileModified(); });
	$('#profile_disabled').change(function() { ProfileModified(); });
	$('#profile_nodelete').change(function() { ProfileModified(); });
	$('#profile_project_write').change(function() { ProfileModified(); });
	$('.examples_portals_checkbox').change(function(){ProfileModified(); });
	
	/*
	 * A double click handler that will render the instructions or
	 * description in a modal.
	 */
	$('#profile_description textarea, #profile_instructions textarea')
	    .dblclick(function() {
		var text = $(this).val();
		$('#renderer_modal_div').html(marked(text));
		sup.ShowModal("#renderer_modal");
	    });
	$('#profile_description .textdiv, #profile_instructions .textdiv')
	    .dblclick(function() {
		$('#renderer_modal_div').html($(this).html());
		sup.ShowModal("#renderer_modal");
	    });
	// Handler for publish submit button, which is in the modal.
	$('#publish_submit_button').click(function (event) {
	    event.preventDefault();
	    PublishProfile();
	});
	// Handler for share modal; do not want to show it if the
	// the profile is not saved.
	$('#profile_share_button').click(function() {
	    if (modified) {
		alert("Please save your profile before sharing it!");
		return false;
	    }
	    sup.ShowModal("#share_profile_modal");
	});
	// Bind the copy to clipbload button in the share modal
	window.APT_OPTIONS.SetupCopyToClipboard("#share_profile_modal");
	
	// Handler for updates to the example portals field, on the
	// the Mothership, where we have multiple portals.
	$('.examples_portals_checkbox').click(function(event) {
	    // Gotta be public to list in examples page.
	    if ($('.examples_portals_checkbox:checked').length &&
		!$('#profile_who_public').is(":checked")) {
		event.preventDefault();
		alert("Only public profiles can be listed on "+
		      "the Examples page. Please click that first.");
		return false;
	    }
	    var portals =
		$('.examples_portals_checkbox:checked')
		    .map(function() {
			return $(this).data("portal");
		    })
		    .get()
		    .join();

	    $('#quickvm_create_profile_form ' +
	      '[name=examples_portals]').val(portals);
	});

	/*
	 * If we were given an rspec, suck the description and instructions
	 * out of the rspec and put them into the text boxes.
	 */
	if (gotrspec) {
	    ExtractFromRspec();
	}
	if (gotscript && _.has(fields, "profile_paramdefs")) {
	    paramHelp.ShowParameterHelp(JSON.parse(fields.profile_paramdefs));
	}
	UpdateButtons();
	
	//
	// Show/Hide the Update Successful animation.
	//
	function hideNotifyUpdate() {
	    $('#notifyupdate').fadeOut();
	}
	function showNotifyUpdate() {
	    $("#notifyupdate").addClass("fade in").show();
	    setTimeout(function () {
		hideNotifyUpdate();
	    }, 2000);
	}
	// Schedule to flash on one second after page loaded.
	function initNotifyUpdate() {
	    setTimeout(function () {
		showNotifyUpdate();
	    }, 1000);
	}
	//
	// If taking a disk image, throw up the modal that tracks progress.
	//
	if (snapping) {
	    DisableButtons();
	    ShowProgressModal();
	}
	else {
	    EnableButtons();
	    modified = false;
	    DisableButton("profile_submit_button");
	    DisableButton("cancel_edit_button");
	    if (window.UPDATED) {
		initNotifyUpdate();
	    }
	    else if (gotscript) {
		if (window.CLONING && !portal_converted) {
		    sup.ShowModal('#warn_pp_modal');
		}
	    }
	    else if (_.has(window, "EXPUUID")) {
		ConvertFromExperiment();
	    }
	}
    }

    /*
     * Submit
     */
    function SubmitForm()
    {
	var submit_callback = function(json) {
	    if (json.code) {
		if (json.code == 2) {
		    aptforms.GenerateFormErrors('#quickvm_create_profile_form',
						json.value);		
		    // Make sure we still warn about an unsaved form.
		    aptforms.MarkFormUnsaved();		    
		}
		else {
		    sup.SpitOops("oops", json.value);
		}
		return;
	    }
	    window.location.replace(json.value);
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);
		}
		return;
	    }
	    aptforms.SubmitForm('#quickvm_create_profile_form',
				"manage_profile", "Create",
				submit_callback);
	};
	// Disable unsaved warning.
	modified = 0;
	
	aptforms.CheckForm('#quickvm_create_profile_form',
			   "manage_profile", "Create",
			   checkonly_callback);
    }
    
    // Handler for all paths to rspec change (file upload, jacks, edit).
    function changeRspec(newRspec, repoupdate_callback)
    {
	if (pythonRe.test(newRspec) || tclRe.test(newRspec)) {
	    //
	    // A geni-lib script. We are going to pass the script to
	    // the server to be "run", which returns XML.
	    //
	    // Need to normalize the newline characters for this
	    // comparison to be meaningful, else we think the
	    // source has changed when it really has not.
	    //
	    var newr = $.trim(newRspec);
	    var oldr = $.trim($('#profile_script_textarea').val());
	    newr = newr.replace(new RegExp(/\r?\n|\r/g), " ");
	    oldr = oldr.replace(new RegExp(/\r?\n|\r/g), " ");
	    
	    if (oldr != newr || goodscript == 0) {
		console.info("geni-lib code has changed");
		if (portal_converted) {
		    /*
		     * User might not want to proceed down this path,
		     * will not be able to use Jacks. 
		     */
		    rteCheckScript(newRspec);
		}
	        else {
		    gotscript = 1;
		    checkScript(newRspec, repoupdate_callback);
		}
	    }
	    else if (repoupdate_callback !== undefined) {
		repoupdate_callback(false /* unmodified. */);
	    }
	}
        else
        {
	    // Kill existing script since we are switching back to XML. SAD!
	    if (gotscript) {
		gotscript = 0;
		$('#profile_script_textarea').val("");
	    }
	    NewRspecHandler(newRspec);
	}
    }

    //
    // Gack, initializing the steps table causes the ProfileModified
    // callbacks to get triggered, which is fine except that when the
    // page is first loaded, it happens AFTER the above initialize()
    // function has finished. How the hell is that? Anyway, this kludge
    // makes sure we start with the profile not appearing modified.
    // We could probably do this as a continuation instead, which would
    // be cleaner. 
    //
    var initialized = false;
    function StepsTableLoaded()
    {
	if (!initialized) {
	    modified = false;
	    DisableButton("profile_submit_button");
	    DisableButton("cancel_edit_button");
	}
	initialized = true;
    }
    function ProfileModified()
    {
	if (initialized) {
	    modified = true;
	    DisableButtons();
	    EnableButton("profile_submit_button");
	    EnableButton("cancel_edit_button");
	}
    }

    /*
     * Yank the steps out of the xml and create the editable table.
     * Before the form is submitted, we have to convert (update the
     * table data into steps section of the rspec).
     */
    function InitStepsTable(xml)
    {
	stepsInitialized = true;
	var steps = [];
	var count = 0;
	
	$(xml).find("rspec_tour").each(function() {
	    $(this).find("steps").each(function() {
		$(this).find("step").each(function() {
		    var desc = $(this).find("description").text();
		    var id   = $(this).attr("point_id");
		    var type = $(this).attr("point_type");
		    steps[count++] = {
			'Type' : type,
			'ID'   : id,
			'Description': desc,
		    };
		});
	    });
	});

	$(function () {
	    // Initialize appendGrid
	    $('#profile_steps').appendGrid('init', {
		// We rewrite these to formfields variables before submit.
		idPrefix: "StepsTable",
		caption: null,
		initRows: 0,
		hideButtons: {
		    removeLast: true
		},
		dataLoaded: function (caller) { StepsTableLoaded(); },
		columns: [
                    { name: 'Type', display: 'Type', type: 'select',
		      ctrlAttr: { maxlength: 100 },
		      ctrlCss: { width: '80px'},
		      ctrlOptions: ["node", "link"],
		      onChange: function (evt, rowIndex) { ProfileModified(); },
		    },
                    { name: 'ID', display: 'ID', type: 'text',
		      ctrlAttr: { maxlength: 100,
				},
		      ctrlCss: { width: '100px' },
		      onChange: function (evt, rowIndex) { ProfileModified(); },
		    },
                    { name: 'Description', display: 'Description', type: 'text',
		      ctrlAttr: { maxlength: 100 },
		      onChange: function (evt, rowIndex) { ProfileModified(); },
		    },
		],
		afterRowAppended: function (evt, rowIndex) { ProfileModified(); },
		afterRowInserted: function (evt, rowIndex) { ProfileModified(); },
		afterRowRemoved:  function (evt, rowIndex) { ProfileModified(); },
		afterRowSwapped:  function (evt, rowIndex) { ProfileModified(); },
		initData: steps
	    });
	});
	
	// Show the steps area.
	// $('#profile_steps_div').removeClass("hidden");
    }

    //
    // Sync the steps table to the rspec XML.
    //
    function SyncSteps()
    {
	var rspec   = $('#profile_rspec_textarea').val();
	var expression = /^\s*$/;
	if (expression.exec(rspec)) {
	    return;
	}
	//console.log('"' + rspec + '"');
	var xmlDoc = $.parseXML(rspec);
	var xml    = $(xmlDoc);

	// Kill existing steps section, we create new ones if needed.
	var tour  = $(xml).find("rspec_tour");
	if (tour.length) {
	    var sub   = $(tour).find("steps");
	    $(sub).remove();
	}
	
	if ($('#profile_steps').appendGrid('getRowCount')) {
	    xml  = AddTourSection(xml);
	    xml  = AddTourSubSection(xml, "steps");
	    tour = $(xml).find("rspec_tour");
	    
	    // Get all data rows from the steps table
	    var data = $('#profile_steps').appendGrid('getAllValue');

	    // And create each step.
	    for (var i = 0; i < data.length; i++) {
		var desc = data[i].Description;
		var id   = data[i].ID;
		var type = data[i].Type;

		// Skip completely empty rows.
		if (desc == "" && id == "" && type == "") {
		    continue;
		}
		// But error on partially empty rows.
		if (desc == "" || id == "" || type == "") {
		    alert("Partial step data in step " + i);
		    return -1;
		}
		var newdoc = $.parseXML('<step point_type="' + type + '" ' +
					'point_id="' + id + '">' +
					'<description type="text">' + desc +
					'</description>' +
					'</step>');
		$(tour).find("steps").append($(newdoc).find("step"));
	    }
	}
	// Write it back to the text area.
	var s = new XMLSerializer();
	var str = s.serializeToString(xml[0]);
	//console.info("SyncSteps");
	//console.info(str);
	$('#profile_rspec_textarea').val(str);
	return 0;
    }

    // See if we need to add the tour section to top level.
    function AddTourSection(xml)
    {
	var tour = $(xml).find("rspec_tour");
	if (! tour.length) {
	    var newdoc = $.parseXML('<rspec_tour xmlns=' +
                 '"http://www.protogeni.net/resources/rspec/ext/apt-tour/1">' +
				    '</rspec_tour>');
	    $(xml).find("rspec").prepend($(newdoc).find("rspec_tour"));
	}
	return xml;
    }
    // See if we need to add the tour sub section.
    function AddTourSubSection(xml, which)
    {
	// Add the tour section (if needed).
	xml = AddTourSection(xml);

	var sub = $(xml).find("rspec_tour > " + which);
	if (!sub.length) {
	    var text;
	    
	    if (which == "description") {
		text = "<description type='markdown'></description>";
	    }
	    else if (which == "instructions") {
		text = "<instructions type='markdown'></instructions>";
	    }
	    else if (which == "steps") {
		text = "<steps></steps>";
	    }
	    var newdoc = $.parseXML(text);
	    $(xml).find("rspec_tour").append($(newdoc).find(which));
	}

	return xml;
    }
    //
    // The description or instructions have changed in an rspec based
    // profile, need to write the changes back into the rspec.
    //
    function TourModified(which)
    {
	var text    = $('#profile_' + which + ' textarea').val();
	var rspec   = $('#profile_rspec_textarea').val();
	if (rspec === "") {
	    return;
	}
	console.log("ChangeHandlerAux " + which);
	console.log(text);
	var xmlDoc = $.parseXML(rspec);
	var xml    = $(xmlDoc);

	// Add the tour section and the subsection (if needed).
	xml = AddTourSection(xml);
	xml = AddTourSubSection(xml, which);

	var sub = $(xml).find("rspec_tour > " + which);
	$(sub).text(text);

	//console.log(xml);
	var s = new XMLSerializer();
	var str = s.serializeToString(xml[0]);
	//console.log(str);
	$('#profile_rspec_textarea').val(str);
	// Copy to the hidden area.
	$('#profile_' + which + ' .textdiv').html(marked(text));
    }

    /*
     * Before updating the rspec with a new one, make sure that the new
     * one has a tour section, and if not ask the user if it is okay to
     * use the original tour section. Once we get confirmation, we can
     * continue with the update.
     */
    function NewRspecHandler(newrspec)
    {
	newrspec     = $.trim(newrspec);
	var oldrspec = $.trim($('#profile_rspec_textarea').val());
	gotrspec     = 1;

	// Need to normalize the newline characters for this
	// comparison to be meaningful, else we think the source has
	// changed when it really has not.
	//
	var newr = newrspec.replace(new RegExp(/\r?\n|\r/g), " ");
	var oldr = oldrspec.replace(new RegExp(/\r?\n|\r/g), " ");
	
	if (newr == oldr) {
	    // In case rspec does not change.
	    UpdateButtons();
	    return;
	}
	var findEncoding = RegExp('^\\s*<\\?[^?]*\\?>');
	var match = findEncoding.exec(newrspec);
	if (match) {
	    newrspec = newrspec.slice(match[0].length);
	}
	var newxmlDoc = parseXML(newrspec);
	if (newxmlDoc == null)
	    return;
	var newxml    = $(newxmlDoc);
	var newtour   = $(newxml).find("rspec_tour");
	
	var continuation = function (reuse) {
	    sup.HideModal('#reuse_tour_modal');
	    if (reuse) {
	       $(newxml).find("rspec").prepend($(oldxmlDoc).find("rspec_tour"));
	       var s = new XMLSerializer();
	       newrspec = s.serializeToString(newxml[0]);
	    }
	    $('#profile_rspec_textarea').val(newrspec);
	    ExtractFromRspec();
	    SyncSteps();
	    if (!fromrepo)
		ProfileModified();
	    UpdateButtons();
	};

	// No old rspec, use new one.
	if (oldrspec == "") {
	    continuation(false);
	    return;
	}
	var oldxmlDoc = parseXML(oldrspec);
	if (oldxmlDoc == null)
	    return;
	
	// A script generated rspec, reuse the old tour section.
	if (gotscript && !newtour.length) {
	    continuation(true);
	    return;
	}
	// Otherwise ask.
	var oldxml    = $(oldxmlDoc);
	var oldtour   = $(oldxml).find("rspec_tour");
	
	if (!newtour.length && oldtour.length) {
	    $('#remove_tour_button').click(function (event) {
		continuation(false);
	    });
	    $('#reuse_tour_button').click(function (event) {
		continuation(true);
	    });
	    sup.ShowModal('#reuse_tour_modal');
	    return;
	}
	// Continue with new rspec. 
	continuation(false);
    }

    /*
     * We want to look for and pull out the introduction and overview text,
     * and put them into the text boxes. The user can edit them in the
     * boxes. More likely, they will not be in the rspec, and we have to
     * add them to the rspec_tour section.
     */
    function ExtractFromRspec()
    {
	var rspec  = $('#profile_rspec_textarea').val();
	var xmlDoc = parseXML(rspec);
	if (xmlDoc == null)
	    return;
	var xml    = $(xmlDoc);
	//console.info(rspec);
	//console.info(xml);
	
	$('#profile_description textarea').val("");
	$('#profile_description .textdiv').html("");
	$(xml).find("rspec_tour > description").each(function() {
	    var text = $(this).text();
	    $('#profile_description textarea').val(text);
	    $('#profile_description .textdiv').html(marked(text));
	});
	$('#profile_instructions textarea').val("");
	$('#profile_instructions .textdiv').html("");
	$(xml).find("rspec_tour > instructions").each(function() {
	    var text = $(this).text();
	    $('#profile_instructions textarea').val(text);
	    $('#profile_instructions .textdiv').html(marked(text));
	});
	if (gotscript) {
	    // We got here by a geni-lib script. No editing allowed
	    $('#show_xml_modal_button').removeClass("hidden");
	    $('#profile_description textarea').addClass("hidden");
	    $('#profile_description .textarea').removeClass("hidden");
	    $('#profile_instructions textarea').addClass("hidden");
	    $('#profile_instructions .textarea').removeClass("hidden");
	}
	else {
	    // User can edit the textareas
	    $('#show_xml_modal_button').addClass("hidden");
	    $('#profile_description textarea').removeClass("hidden");
	    $('#profile_description .textarea').addClass("hidden");
	    $('#profile_instructions textarea').removeClass("hidden");
	    $('#profile_instructions .textarea').addClass("hidden");
	}
	// Creating new profile, now we can show the tour/metadata fields.
	$('#tour-text-boxes').removeClass("hidden");
	$('#metadata-fields').removeClass("hidden");

	//
	// First time we see the XML, grab step data out of it. But after
	// that the steps table is authoritative, and so we sync the table
	// back to the XML. 
	//
	if (! stepsInitialized) {
	    InitStepsTable(xml);
	}
    }

    //
    // Progress Modal
    //
    function ShowProgressModal()
    {
        ShowImagingModal(
		         function()
			 {
			     return sup.CallServerMethod(ajaxurl,
							 "manage_profile",
							 "CloneStatus",
							 {"uuid" : version_uuid});
			 },
			 function(failed)
			 {
			     if (failed) {
				 EnableButton("profile_delete_button");
			     }
			     else {
				 EnableButtons();
				 DisableButton("profile_submit_button");
				 DisableButton("cancel_edit_button");
			     }
			 },
	                 true);
    }

    //
    // Show the waitwait modal.
    //
    function WaitWait(message)
    {
	sup.ShowWaitWait(message);
    }

    //
    // Enable/Disable buttons. 
    //
    function EnableButtons()
    {
	EnableButton("profile_delete_button");
	EnableButton("profile_instantiate_button");
	EnableButton("profile_submit_button");
	EnableButton("cancel_edit_button");
	EnableButton("profile_copy_button");
	EnableButton("profile_publish_button");
    }
    function DisableButtons()
    {
	DisableButton("profile_delete_button");
	DisableButton("profile_instantiate_button");
	DisableButton("profile_submit_button");
	DisableButton("cancel_edit_button");
	DisableButton("profile_copy_button");
	DisableButton("profile_publish_button");
    }
    function EnableButton(button)
    {
	ButtonState(button, 1);
    }
    function DisableButton(button)
    {
	ButtonState(button, 0);
    }
    function ButtonState(button, enable)
    {
	if (enable) {
	    $('#' + button).removeAttr("disabled");
	}
	else {
	    $('#' + button).attr("disabled", "disabled");
	}
    }
    function HideButton(button)
    {
	$(button).addClass("hidden");
    }

    //
    // Publish profile.
    //
    function PublishProfile()
    {
	var callback = function(json) {
	    sup.HideModal("#waitwait-modal");
	    //console.info(json.value);

	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // No longer allowed to delete/publish. But maybe we need
	    // an unpublish button? Also update the published field.
	    HideButton('#profile_delete_button');
	    HideButton('#profile_publish_button');
	    $('#profile_published').html(json.value.published);
	}
	sup.HideModal('#publish_modal');
	WaitWait();
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile",
					    "PublishProfile",
					    {"uuid"   : version_uuid});
	xmlthing.done(callback);
    }

    function parseXML(rspec)
    {
	try {
	    var xmlDoc = $.parseXML(rspec);
	    return xmlDoc;
	}
	catch(err) {
	    alert("Could not parse XML!");
	    return -1;
	}
    }

    //
    // Pass a geni-lib script to the server to run (convert to XML).
    //
    function checkScript(script, repoupdate_callback)
    {
	// Save for later.
	$('#profile_script_textarea').val(script);

	var callback = function(json) {
	    sup.HideWaitWait();
	    console.info(json.value);

	    if (json.code) {
		sup.SpitOops("oops",
			     "<pre><code>" +
			     $('<div/>').text(json.value).html() +
			     "</code></pre>");
		return;
	    }
	    if (json.value.rspec != "") {
		goodscript = 1;
		// Kill the rspec so that we always use the new one.
		$('#profile_rspec_textarea').val("");
		NewRspecHandler(json.value.rspec);
		if (_.has(json.value, "paramdefs")) {
		    paramHelp.ShowParameterHelp(
			JSON.parse(json.value.paramdefs));
		}
		else {
		    paramHelp.HideParameterHelp();
		}
		if (repoupdate_callback !== undefined) {
		    repoupdate_callback(true /* modified */);
		}
		// Force this; the script is obviously different, but the
		// the XML might be exactly same. Still want to save it.
		if (!fromrepo || window.ACTION == "create") {
		    ProfileModified();
		}
		// Show the XML source button.
		$('#show_xml_modal_button').removeClass("hidden");
	    } else {
	      goodscript = 0;
	    }
	}
	/*
	 * Send along the project if one is selected; only makes sense
	 * for NS files, which need to do project based checks on a few
	 * things (images and blockstores being the most important).
	 * If this is a modification to an existing profile, we still
	 * have the project name in the same variable.
	 */
	var args = {
	    "script"   : script,
	    "pid"      : $('#profile_pid').val(),
	    "getparams": true,
	};
	if (profile_uuid) {
	    args["profile_uuid"] = profile_uuid;
	}
	if (fromrepo) {
	    if (repoupdate_callback !== undefined) {
		// Pass along flag to update repo (if allowed).
		args["updaterepo"] = true;
	    }
	    else {
		// Pass along refspec for running genilib
		// Will be null on initial profile creation.
		args["refspec"] = reporefspec;
	    }
	}
	WaitWait("We are converting your geni-lib script to XML");
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile",
					    "CheckScript", args);
	xmlthing.done(callback);
    }

    /*
     * User is requesting to create a profile from a git repo.
     * Try to clone that repo and get the script/rspec out of it.
     */
    function HandleGitRepoChange()
    {
	var repourl = $('#git-repo-url').val();
	// Do nothing until we have something.
	if (repourl == "") {
	    return;
	}
	if (repourl.substring(0,8) != "https://") {
	    $('#git-repo-modal [for=git-repo-url]').removeClass("hidden");
	    $('#git-repo-modal .form-group').addClass("has-error");
	    $('#git-repo-modal [for=git-repo-url]')
		.text("URL must start with https://");
	    return;
	}
	// Clear errors
	$('#git-repo-modal [for=git-repo-url]').addClass("hidden");
	$('#git-repo-modal .form-group').removeClass("has-error");
	sup.HideModal('#git-repo-modal');
	
	var callback = function(json) {
	    console.info("HandleGitRepoChange", json);

	    if (json.code) {
		sup.HideWaitWait();
		sup.SpitOops("oops", json.value);
		return;
	    }
	    fromrepo = 1;
	    // Lets not show this anymore.
	    $('#sourcefile-button-div').addClass("hidden");
	    // Add the url to the form.
	    $('#quickvm_create_profile_form #repourl').val(repourl);
	    // Save for later.
	    $('#profile_script_textarea').val(json.value.script);
	    // Kill the rspec so that we always use the new one.
	    $('#profile_rspec_textarea').val("");
	    NewRspecHandler(json.value.rspec);
	    ProfileModified();
	    // Show the XML source button.
	    $('#show_xml_modal_button').removeClass("hidden");
	    sup.HideWaitWait();
	}
	var args = {"repourl" : repourl,
		    // XXX Temporary for usenewgenilib check. 
		    "pid"     : $('#profile_pid').val()};

	// If there is profile name, pass that through so we can look
	// for a script or rspec with the same name (instead of profile.py).
	if ($.trim($('#profile_name').val()) != "") {
	    args["profile_name"] = $.trim($('#profile_name').val());
	}
	WaitWait("We are attempting to clone your repository. " +
		 "Patience please.");
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile",
					    "GetRepository", args);
					    
	xmlthing.done(callback);
    }

    /*
     * Update from origin repository, possibly getting a new script or rspec
     * cause HEAD changed at the origin.
     */
    function HandleGitRepoUpdate()
    {
	console.info("HandleGitRepoUpdate");
	
	var callback = function(blob) {
	    console.info("HandleGitRepoUpdate", blob);
	    if (!blob) {
		repobusy = false;
	    }
	    else {
		// Mark as HEAD in the page.
		repohash = blob.hash;

		/*
		 * If the source was an rspec, we updated the profile
		 * to match the current repo right away. But to make things
		 * nicer for script based profiles, we wait until the
		 * script is converted to an rspec. Cause of workflow, we
		 * end up doing this later so that the user sees a short
		 * delay when hitting the update button for a script based
		 * profile. 
		 */
		if (!pythonRe.test(blob.source)) {
		    NewRspecHandler(blob.source);
		    // Reset the list of tags and branches whenever we
		    // successfully update our clone.
		    SetupRepo(function () { repobusy = false; });
		    return;
		}
		/*
		 * Else we wait till the script converted, the call back is
		 * invoked after CheckScript() finishes. The server side
		 * has done the profile update, so we can finish things up.
		 */
		changeRspec(blob.source, function(modified) {
		    // Reset the list of tags and branches whenever we
		    // successfully update our clone.
		    SetupRepo(function () { repobusy = false; });
		});
	    }
	};
	/*
	 * Need to wait if the auto check for the repo change is
	 * not running. It hurts to run this at the same time that
	 * is running.
	 *
	 * We are never going to set repobusy=false after this, so
	 * CheckRepoChange() will never run again once the user has
	 * used the update button. Not worth the trouble to get the
	 * synchronization correct.
	 */
	var checker = function () {
	    if (!repobusy) {
		// See comment above ...
		repobusy = true;
		gitrepo.UpdateRepo(version_uuid, callback);
		return;
	    }
	    setTimeout(function f() { checker() }, 250);
	};
	checker();
    }

    function SetupRepo(callback)
    {
	console.info("SetupRepo", callback);

	var deferred =
	    gitrepo.InitRepoPicker({
		"uuid"      : version_uuid,
		"share_url" : profile.profile_profile_url,
		"refspec"   : reporefspec,
		"callback"  : function(which) {
		    // So we remember what the user selected.
		    reporefspec = which;
		    UpdateInstantiateButton();
		    SelectRepoTarget(which);
		}
	    });
				   
	$.when(deferred)
	    .done(function (r1) {
		console.info("SetupRepo InitRepoPicker", r1)
		if (callback) {
		    callback();
		}
	    });
    }

    /*
     * User has clicked on a branch/tag. We need to get that branch/tag
     * source code and update the page.
     */
    function SelectRepoTarget(which)
    {
	console.info("SelectRepoTarget: ", which);

	var callback = function (source, hash) {
	    if (source) {
		changeRspec(source);
	    }
	};
	gitrepo.GetRepoSource({
	    "uuid"      : version_uuid,
	    "refspec"   : which,
	    "callback"  : callback
	});
    }

    /*
     * Timer to ask for the current repository hash value to determine
     * if it has changed. 
     */
    function CheckRepoChange()
    {
	//console.info("CheckRepoChange", repobusy);
	
	if (repobusy) {
	    setTimeout(function f() { CheckRepoChange() }, 15000);
	    return;
	}
	repobusy = true;
	
	var callback = function(json) {
	    //console.info("CheckRepoChange", json);
    
	    if (json.code == 0 && repohash != json.value) {
		if (window.confirm("We have detected a change to the " +
				   "profile repository. Do you want to " +
				   "reload this page so you are looking at " +
				   "the latest version?")) {
		    window.location.reload();
		}
		// Do not run the auto check after this, no point.
		repobusy = false;
		return;
	    }
	    setTimeout(function f() { CheckRepoChange() }, 15000);
	    repobusy = false;
	};
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile", "GetRepoHash",
					    {"uuid"   : version_uuid});
	xmlthing.done(callback);
    }

    /*
     * Convert from an NS file. The server will do the conversion and spit
     * back a genilib script.
     */
    function ConvertFromExperiment()
    {
	var callback = function(json) {
	    console.info(json.value);

	    if (json.code) {
		sup.HideWaitWait();
		sup.SpitOops("oops",
			     "<pre><code>" +
			     $('<div/>').text(json.value).html() +
			     "</code></pre>");
		return;
	    }
	    sup.ClearDownloadOnClick($('#rspec_modal_download_button'));
	    sup.HideWaitWait(function () {
		changeRspec(json.value.script);
		// Do this after so we do not do an RTE check up above.
		MarkPortalConverted(true);
	    });
	}
	/*
	 * Send along the project if one is selected; only makes sense
	 * for NS files, which need to do project based checks on a few
	 * things (images and blockstores being the most important).
	 * If this is a modification to an existing profile, we still
	 * have the project name in the same variable.
	 */
	WaitWait("We are converting your NS file to geni-lib");
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile",
					    "ConvertClassic",
					    {"uuid"   : window.EXPUUID,
					     "pid"    : $('#profile_pid').val()});
	xmlthing.done(callback);
    }

    function openEditor(source)
    {
        var readonly = true;
        if ((window.CANEDIT !== 0 ||
	     window.ACTION === 'create') &&
	     fromrepo === 0 &&
	     gotscript == 1)
        {
	    readonly = false;
        }
        window.SHOW_GENILIB_EDITOR(source, closeEditor, readonly, profile_uuid);
    }

    function closeEditor(source)
    {
        if (source !== null)
        {
	    changeRspec(source);
        }
    }

    function ConvertToGenilib(rspec)
    {
	var converting = false;
	
	// Coming out of Jacks, otherwise a conversion.
	if (rspec !== undefined) {
	    changeRspec(rspec);
	}
	else {
	    rspec = $.trim($('#profile_rspec_textarea').val());
	    converting = true;
	}
	
	/*
	 * Convert rspec to geni-lib
	 */
	var callback = function(json) {
	    sup.HideWaitWait();
	    console.info(json.value);
	    if (json.code) {
		$('#profile-conversion-failure-message').html(json.value);
		sup.ShowModal('#profile-convert-failed-modal');
		return;
	    }
	    gotscript = 1;
	    if (converting) {
		MarkPortalConverted(true);
	    }
	    $('#profile_script_textarea').val(json.value.script);
	    NewRspecHandler(json.value.rspec);
	    ProfileModified();
	    // Show the XML source button.
	    $('#show_xml_modal_button').removeClass("hidden");
	    // A conversion, throw up post conversion modal
	    if (converting) {
		// Hide the conversion button.
		$('#profile_convert_button').addClass("hidden");
		// Bind function to switch to the editor.
		$('#profile-converted-viewscript').click(function(event) {
		    sup.HideModal('#profile-converted-modal',
				  function () {
				      openEditor(json.value.script);
				  });
		});
		sup.ShowModal('#profile-converted-modal');
	    }
	};
	if (converting) {
	    WaitWait("Please wait while we convert your rspec to geni-lib");
	}
	else {
	    WaitWait();
	}
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile",
					    "ConvertRspec",
					    {"rspec" : rspec});
	xmlthing.done(callback);

    }

    function CreateJacksEditor()
    {
        var isViewer = window.ISPOWDER || (gotscript && !portal_converted);
	if (editor) {
	    $('#editmodal_div').empty();
	}
	editor = new JacksEditor($('#editmodal_div'),
				 isViewer, false, false, false, !multisite);
	if (isViewer) {
	    $('#edit_container .edit_buttons.readwrite').addClass("hidden");
	    $('#edit_container .edit_buttons.readonly').removeClass("hidden");
	}
	else {
	    $('#edit_container .edit_buttons.readwrite').removeClass("hidden");
	    $('#edit_container .edit_buttons.readonly').addClass("hidden");
	}
    }

    function MarkPortalConverted(converted)
    {
	portal_converted = converted;
	// Mark the form as containing a converted script.
	$('#quickvm_create_profile_form ' +
	  '[name=portal_converted]').val(converted ? "yes" : "no");
    }

    function UpdateButtons()
    {
	console.info(window.VIEWING, window.CANEDIT,
		     fromrepo, gotscript, gotrspec, portal_converted);

	if (! (gotscript || gotrspec)) {
	    if (window.ISPOWDER) {
		$('#edit_topo_modal_button').addClass('hidden');
	    }
	    else {
		$('#edit_topo_modal_button').html('Create Topology');
	    }
	    $('#show_source_modal_button').html('Edit Code');
	}
	else {
	    var caneditcode = (!window.VIEWING || window.CANEDIT ? 1 : 0);
	    var canedittopo = caneditcode;

	    // In general, scripts can be edited, subject to changes below.
	    if (gotscript) {
		caneditcode = 1;
		canedittopo = 0;
	    }
	    if (fromrepo) {
		caneditcode = 0;
		canedittopo = 0;
	    }
	    if (portal_converted) {
		caneditcode = 1;
		canedittopo = 1;
		// Hide the git-repo button.
		$('#git-repo-button-div').addClass("hidden");
	    }
	    $('#edit_topo_modal_button').removeClass('hidden');
	    if (canedittopo && !window.ISPOWDER) {
		$('#edit_topo_modal_button').html('Edit Topology');
	    }
	    else {
		$('#edit_topo_modal_button').html('View Topology');
	    }
	    if (caneditcode) {
		$('#show_source_modal_button').html('Edit Code');
		// Hide the file upload button, user is committed, and
		// there is an upload button in the code editor.
		$('#sourcefile-button-div').addClass("hidden");
	    }
	    else {
		$('#show_source_modal_button').html('View Code');
	    }
	    if (window.CLONING || window.COPYING ||
		window.EXPUUID !== undefined) {
		// Hide the file upload button, user is committed
		$('#sourcefile-button-div').addClass("hidden");
		// Ditto the git-repo button.
		$('#git-repo-button-div').addClass("hidden");
	    }
	}
    }

    /*
     * The user has edited the geni-lib script for a portal converted profile.
     * We attempt to determine of the change will be lost if we convert the
     * generated rspec (from the new geni-lib script) back to geni-lib. If
     * no difference in the edited python and the machine generated python,
     * then life is good. If not, the use has made a change that will be lost
     * so we have to convert to normal geni-lib script; jacks will now run
     * in read-only mode, the user can *only* edit the script.
     */
    function rteCheckScript(script)
    {
	var callback = function (json) {
	    console.info("rteCheckScript", json);
	    // Was having a modal problem.
	    sup.HideWaitWait(function () {
		// No error, we are good to go.
		if (json.code == 0) {
		    checkScript(script);
		    return;
		}
		else if (json.code < 0) {
		    sup.SpitOops("oops", "Internal error processing script");
		    return;
		}
		// A difference we cannot deal with.
		$('#edit-genilib-continue').click(function(event) {
		    sup.HideModal('#edit-genilib-warning-modal',
				  function () {
				      MarkPortalConverted(false);
				      CreateJacksEditor();
				      checkScript(script);
				  });
		});
		$('#rtecheck-failure-message').html(json.value);
		sup.ShowModal('#edit-genilib-warning-modal',
			      function () {
				  $('#edit-genilib-continue').off("click");
			      });
		return;
	    });
	};
	WaitWait("Please wait while we take a look at your script");
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "manage_profile", "RTECheck",
					    {"script"  : script});
	xmlthing.done(callback);
    }

    /*
     * Update the instantiate button when we switch repo targets.
     */
    function UpdateInstantiateButton()
    {
	var url = "instantiate.php?profile=" +
	    version_uuid + "&from=manage-profile";

	if (reporefspec) {
	    url += "&refspec=" + reporefspec;
	}
	$('#profile_instantiate_button').attr("href", url);
    }
    
    $(document).ready(initialize);
});
