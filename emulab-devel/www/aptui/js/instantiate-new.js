$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['instantiate-new', 'aboutapt', 'aboutcloudlab', 'aboutpnet', 'waitwait-modal', 'rspectextview-modal', 'reservation-graph', 'resgroup-list']);
    var instantiateString = templates['instantiate-new'];
    var aboutaptString = templates['aboutapt'];
    var aboutcloudString = templates['aboutcloudlab'];
    var aboutpnetString = templates['aboutpnet'];
    var waitwaitString = templates['waitwait-modal'];
    var rspecviewString = templates['rspectextview-modal'];
    var ajaxurl;
    var amlist        = null;
    var amstatus      = null;
    var projlist      = null;
    var sysprojlist   = ['emulab-ops', 'PortalProfiles'];
    var psysprojlist  = ['PhantomNet', 'PortalProfiles'];
    var profilelist   = null;
    var recentcount   = 5;
    var amdefault     = null;
    var selected_profile = null;
    var selected_uuid    = null;
    var selected_rspec   = null;
    var selected_version = null;
    var ispprofile    = 0;
    var isscript      = 0;
    var webonly       = 0;
    var isadmin       = 0;
    var multisite     = 0;
    var doconstraints = 0;
    var amValueToKey  = {};
    var showpicker    = 0;
    var portal        = null;
    var fromrepo      = false;
    var registered    = false;
    var JACKS_NS      = "http://www.protogeni.net/resources/rspec/ext/jacks/1";
    var jacks = {
      instance: null,
      input: null,
      output: null
    };
    var editor        = null;
    var ppstart       = window.ppstart;
    var loaded_uuid   = null;
    var ppchanged     = false;
    var monitor       = null;
    var types         = null;
    var prunetypes    = null;
    var hardware      = null;
    var resinfo       = null;
    var radioinfo     = null;
    var maxEndDate    = null;
    var usingRadios   = false;
    var currentStep   = 0;
    var deprecatedList = [];
    var mainTemplate  = _.template(instantiateString);
    var graphTemplate = _.template(templates["reservation-graph"]);
    var reslistTemplate= _.template(templates["resgroup-list"]);

    function enableStepsMotion()
    {
	console.info("enableStepsMotion");
	
	$('#stepsContainer').steps("enableMotion");
	$('body').on("keyup.stepsNav", function (event) {
	    if (event.keyCode === 13) {
		$('#stepsContainer').steps('next');
	    }
	});
	// For Selenium.
	$('#stepsContainer').prepend("<div class='hidden' " +
				     " id='steps-enabled'></div>");	
    }
    function disableStepsMotion()
    {
	console.info("disableStepsMotion");
	
	$('#stepsContainer').steps("disableMotion");
	$('body').off("keyup.stepsNav");
	// For Selenium
	$('#stepsContainer').find("#steps-enabled").remove();
    }
    function setStepsMotion(enable)
    {
	if (enable) {
	    enableStepsMotion();
	}
	else {
	    disableStepsMotion();
	}
    }

    function initialize()
    {
    // Get context for constraints
	var contextUrl = 'https://www.emulab.net/protogeni/jacks-context/cloudlab-utah.json';
	$.get(contextUrl).then(contextReady, contextFail);
	// Standard view option
	marked.setOptions({"sanitize" : true});

	window.APT_OPTIONS.initialize(sup);
	registered = window.REGISTERED;
	webonly    = window.WEBONLY;
	isadmin    = window.ISADMIN;
	multisite  = window.MULTISITE;
	portal     = window.PORTAL;
	ajaxurl    = window.AJAXURL;
	fromrepo   = window.FROMREPO;
	doconstraints = window.DOCONSTRAINTS;
	showpicker    = window.SHOWPICKER;

	if ($('#amlist-json').length) {
	    amlist = decodejson('#amlist-json');
	    _.each(_.keys(amlist), function (key) {
		amValueToKey[amlist[key].name] = key;
	    });
	    amstatus = decodejson('#amstatus-json');
	    console.info("amlist", amlist);
	}
	if ($('#projects-json').length) {
	    projlist = decodejson('#projects-json');
	}
	profilelist = decodejson('#profiles-json');
	console.info("profilelist", profilelist);
	var profileToArray = _.pairs(profilelist);
	prunetypes = decodejson('#prunelist-json');
	console.info(prunetypes);
	if ($('#radioinfo-json').length) {
	    radioinfo = decodejson('#radioinfo-json');
	    console.info("radioinfo", radioinfo);
	}
	console.info("formfields", decodejson('#form-json'));

	/*
	 * Sort the entire list by recently used if a registered user,
	 * else just the use count.
	 */
	if (registered) {
	    profileToArray = _.sortBy(profileToArray, function (value) {
		return value[1].lastused;
	    });
	}
	else {
	    profileToArray = _.sortBy(profileToArray, function (value) {
		return value[1].usecount;
	    });
	}
	// Note that sortBy orders by ascending, so reverse.
	profileToArray = profileToArray.reverse();
	
	var recentlist = _.filter(profileToArray, function(value) {
	    return value[1]['usecount'] > 0;
	});

	var neverUsed = 0;
	if (recentlist.length == 0 || !registered) {
	    neverUsed = 1;
	    recentlist = profileToArray;
	}
	recentlist = _.first(recentlist, recentcount);
	
	_.each(recentlist, function(obj, key) {
	    if (window.ISPNET) {
		if (_.contains(psysprojlist, obj[1].project)) {
		    obj[1].project = "System";
		}
	    }
	    else {
		if (_.contains(sysprojlist, obj[1].project)) {
		    obj[1].project = "System";
		}
	    }
	});
	var projcategories = MakeProfileCategories(profileToArray);

	var html = mainTemplate({
	    formfields:         decodejson('#form-json'),
	    profiles:           profilelist,
	    myprofiles:         projcategories.myprofiles,
	    projprofiles:       projcategories.inproj,
	    systemprofiles:        projcategories.sysproj,
	    otherprofiles:      projcategories.otherproj,
	    recent:             recentlist,
	    showpopular:        neverUsed,
	    favorites:          projcategories.favorite,
	    projects:           projlist,
	    amlist:             amlist,
	    registered:         registered,
	    profilename:        window.PROFILENAME,
	    profileuuid:        window.PROFILEUUID,     
	    profilevers:        window.PROFILEVERS,     
	    showpicker:         showpicker,
	    fromrepo:           fromrepo,
	    clustername:        window.PORTAL_NAME,
	    admin:		isadmin,
	    maxduration:        window.MAXDURATION,
	    clusterselect:      window.CLUSTERSELECT,
	});
	$('#main-body').html(html);

	// Fire this off right away.
	if (window.REGISTERED) {
	    LoadReservationInfo();
	}

	if (projlist)
	    UpdateGroupSelector();

	// Check if the browser has cookies stating what they previoiusly had minimized.
        CookieCollapse('#profile_name > span', 'pp_collpased');
        _.defer(function () {
	    monitor = JSON.parse(_.unescape($('script#amstatus-json').html()));
	    //CreateClusterStatus();
        });
	$('#waitwait_div').html(waitwaitString);
        $('#waitwait-modal').modal({ backdrop: 'static', keyboard: false, show: false });
	$('#rspecview_div').html(rspecviewString);
	$('#rspec_modal_download_button').addClass("hidden");
	
	// The about panel.
	if (window.SHOWABOUT) {
	    $('#about_div').html(window.ISCLOUD ? aboutcloudString :
				 (window.ISPNET ? aboutpnetString : 
				  aboutaptString));
	}
	$('#stepsContainer').steps({
	    headerTag: "h3",
	    bodyTag: "div",
	    transitionEffect: "slideLeft",
	    autoFocus: true,
	    onStepChanging: function(event, currentIndex, newIndex) {
		return StepChanging(this, event, currentIndex, newIndex);
	    },
	    onStepChanged: function(event, currentIndex, priorIndex) {
		// Globally record what step we are on.
		currentStep = currentIndex;
		return StepChanged(this, event, currentIndex, priorIndex);
	    },
	    onFinishing: function(event, currentIndex) {
		_.defer(function () {
		    CheckStep3(function (success) {
			if (success) {
			    Instantiate(event);
			}
			else {
			    $('#stepsContainer-t-3').parent().addClass('error');
			}
		    });
		});
		// Avoid Error indicator until form validation completes.
		return true;
	    },
	});
	setStepsMotion(false);
	
	// Insert datepicker on schedule tab,
	$("#start_day").datepicker({
	    minDate: 0,		/* earliest date is today */
	    disabled: false,
	    showButtonPanel: true,
	    onSelect: function (dateString, dateobject) {
		DateChange("#start_day");
	    }
	});
	$("#end_day").datepicker({
	    minDate: 0,		/* earliest date is today */
	    maxDate: "+1d",
	    showButtonPanel: true,
	    onSelect: function (dateString, dateobject) {
		DateChange("#end_day");
	    }
	});
	$("#start_hour").change(function () {
	    DateChange("#start_hour");
	});
	$('#start-hour-help, #end-hour-help').popover({
	    trigger: 'hover',
	    placement: 'auto',
	    container: 'body',
	});

	// It is okay to initialize this, we do not show the copy
	// button unless appropriate. 
	CopyProfile.InitCopyProfile('#profile-copy-button',
				    window.PROFILE, _.keys(projlist));

	// Format the step labels across the top to match the panel widths.
	$('#stepsContainer .steps').addClass('col-lg-8 col-lg-offset-2 col-md-8 col-md-offset-2 col-sm-10 col-sm-offset-1 col-xs-12 col-xs-offset-0');
	$('#stepsContainer .actions').addClass('col-lg-8 col-lg-offset-2 col-md-8 col-md-offset-2 col-sm-10 col-sm-offset-1 col-xs-12 col-xs-offset-0');

	// Set up jacks swap
	$('#stepsContainer #inline_overlay').click(function() {
		SwitchJacks('large');
	});

	$('#quickvm_topomodal').on('shown.bs.modal', function() {
	    ShowProfileSelection($('#profile_name .current'))
	});

	$('button#reset-form').click(function (event) {
	    event.preventDefault();
	    resetForm($('#quickvm_form'));
	});
	$('button#change-profile').click(function (event) {
	    event.preventDefault();
	    PickerEvent("show");
	    $('#quickvm_topomodal').modal('show');
	});
	$('button#showtopo_cancel').click(function (event) {
	    event.preventDefault();
	    PickerEvent("hide");
	    $('#quickvm_topomodal').modal('hide');
	});
	$('li.profile-item').click(function (event) {
	    event.preventDefault();
	    // Ignore clicks over the project. Probably a better way to do this.
	    if (! $(event.target).is("li")) {
		return;
	    }
	    PickerEvent("switch", $(event.target),
			$('#profile_name').scrollTop());
	    ShowProfileSelection(event.target);
	});
	$('button#showtopo_select').click(function (event) {
	    event.preventDefault();
	    var selected = $('#quickvm_topomodal .selected');
	    PickerEvent("select", selected, $('#profile_name').scrollTop());
	    ChangeProfileSelection(selected);
	    $('#quickvm_topomodal').modal('hide');
	    $('.steps .error').removeClass('error');
	});
	/*
	 * Handler for scroll inside the picker. We want to send the
	 * event when the user stops scrolling.
	 */
	$('#profile_name').scroll(function (event) {
	    clearTimeout($.data(this, 'scrollTimer'));
	    $.data(this, 'scrollTimer', setTimeout(function() {
		PickerEvent("scroll", $('#profile_name').scrollTop());
	    }, 750));	    
	});
	/*
	 * Need to update image constraints when the project selector
	 * is changed.
	 */
	$('#profile_pid').change(function (event) {
	    UpdateGroupSelector();
	    UpdateImageConstraints();
	    return true;
	});

	$('#show_xml_modal_button').click(function (event) {
	    //
	    // Show the XML source in the modal. This is used when we
	    // have a script, and the XML was generated. We show the
	    // XML, but it is not intended to be edited.
	    //
	    $('#rspec_modal_editbuttons').addClass("hidden");
	    $('#rspec_modal_viewbuttons').removeClass("hidden");
	    $('#modal_profile_rspec_textarea').val(selected_rspec);
	    $('#modal_profile_rspec_textarea').prop("readonly", true);
	    $('#modal_profile_rspec_div').addClass("hidden");
	    $('#modal_profile_rspec_textarea').removeClass("hidden");
	    $('#rspec_modal').modal({'backdrop':'static','keyboard':false});
	    $('#rspec_modal').modal('show');
	});
	$('#close_rspec_modal_button').click(function (event) {
	    $('#rspec_modal').modal('hide');
	    $('#modal_profile_rspec_textarea').val("");
	});

	// Profile picker search box.
	var profile_picker_timeout  = null;
	var profile_picker_searched = false;
	
	$("#profile_picker_search").on("keyup", function (event) {
	    var options   = $('#profile_name');
	    var userInput = $("#profile_picker_search").val();
	    userInput = userInput.toLowerCase();
	    window.clearTimeout(profile_picker_timeout);

	    profile_picker_timeout =
		window.setTimeout(function() {
		    var matches = 
			options.children("ul").children("li").filter(function() {
			    var text = $(this).text();
			    text = text.toLowerCase();

			    if (text.indexOf(userInput) > -1)
				return true;
			    return false;
			});
		    options.children("ul").children("li").hide();
		    matches.show();
		    
		    if (userInput == '') {
			$('#title_recently_used').removeClass('hidden');
			$('#recently_used').removeClass('hidden');
			$('#title_favorites').removeClass('hidden');
			$('#favorites').removeClass('hidden');
			profile_picker_searched = false;
		    }
		    else {
			$('#title_recently_used').addClass('hidden');
			$('#recently_used').addClass('hidden');
			$('#title_favorites').addClass('hidden');
			$('#favorites').addClass('hidden');
			if (profile_picker_searched == false) {
			    PickerEvent("search");
			}
			profile_picker_searched = true;
		    }
		}, 500);

	    // User types return while searching, if there was only one
	    // choice, then we select it. Convenience. 
	    if (event.keyCode == 13) {
		var matches = 
		    options.find("li").filter(function() {
			return (!$(this).parent().hasClass('hidden') && $(this).css('display') == 'block');
		    });
		if (matches && matches.length == 1) {
		    PickerEvent("select", $(matched[0]),
				$('#profile_name').scrollTop());
		    ShowProfileSelection(matches[0]);
		}
	    }
	});

	//
	// SSH file upload handler, to move the file contents into
	// the ssh text area. 
	//
	if (!registered) {
	    $('#input_keyfile').change(function() {
		var reader = new FileReader();
		reader.onload = function(event) {
		    /*
		     * Clear the file so that the change handler will
		     * run if the same file is selected again.
		     */
		    $("#input_sshkey").text(event.target.result);
		};
		reader.readAsText(this.files[0]);
	    });
	}
	    
	var startProfile = $('#profile_name li[value = ' + window.PROFILE + ']:first');
	ChangeProfileSelection(startProfile);
	_.delay(function () {
	    $('.dropdown-toggle').dropdown();
	}, 500);

	// Set up the click function for expanding and collapsing profile groups
	$('#profile_name > span').click(function() {
	    var ul = '#'+($(this).attr('id').slice('title-'.length));
	    if ($(this).children('.category_collapsable').hasClass('expanded')) {
		$(ul).addClass('hidden');
		$(this).children('.category_collapsable').removeClass('expanded');
		$(this).children('.category_collapsable').addClass('collapsed');
	    }
	    else {
		$(ul).removeClass('hidden');
		$(this).children('.category_collapsable').addClass('expanded');
		$(this).children('.category_collapsable').removeClass('collapsed');
	    }

	    var collapsed = [];
	    $('#profile_name .category_collapsable.collapsed').each(function() {
		collapsed.push($(this).parent().attr('id'));
	    });

	    SetCookie('pp_collpased',JSON.stringify(collapsed),30);
	});
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }

    // Handler to minimize span elements based on the cookie name
    function CookieCollapse(target, cookieName) {
	var cookie = GetCookie(cookieName);

	if (cookie != null) {  
	    var collapsed = JSON.parse(cookie);
    
	    $(target).each(function() {
		if (_.contains(collapsed, $(this).attr('id'))) {
		    $(this).children('.category_collapsable').removeClass('expanded').addClass('collapsed');
		    var ul = '#'+($(this).attr('id').slice('title-'.length));
		    $(ul).addClass('hidden');
		}
	    });
	}
    } 

    // Put profiles into the correct categories to be built in the template
    function MakeProfileCategories(profiles) {
      var result = {favorite:{},myprofiles:{},inproj:{},sysproj:{},otherproj:{}};

      // This section should probably be rethought as it's not very clean. 
      // Didn't have time to refactor for initial release.
      _.each(profiles, function(obj, key) {
	  key = obj[0];
	  obj = obj[1];
	  
	    var isSystem = (window.ISPNET && _.contains(psysprojlist, obj.project)) || (!window.ISPNET &&_.contains(sysprojlist, obj.project))
	    if (obj.favorite == 1) {
	      if (isSystem	) {
		result.favorite[key] = $.parseJSON(JSON.stringify(obj));
		result.favorite[key].project = "System";
	      }
	      else {
		result.favorite[key] = obj;
	      }
	    }

	    if (window.USERNAME == obj.creator) {
		result.myprofiles[key] = obj;
	    }

	    if (isSystem) {
	      result.sysproj[key] = obj;
	    }

	    if (projlist && _.has(projlist, obj.project)) {
	      if (!result.inproj[obj.project]) {
		result.inproj[obj.project] = {};
	      }
	      result.inproj[obj.project][key] = obj;
	    }
	    else if (!isSystem) {
	      result.otherproj[key] = obj;
	    }
	});
      return result;
    }

    var doingformcheck = 0;

    // Step is changing
    function StepChanging(step, event, currentIndex, newIndex) {
	//console.info("StepChanging: ", step, currentIndex, newIndex);
	//console.info(new Date());
	
	if (currentIndex == 0 && newIndex == 1) {
	    // Check step 0 form values. Any errors, we stop here.
	    if (!registered && !doingformcheck) {
		doingformcheck = 1;
		CheckStep0(function (success) {
		    if (success) {
			$('#stepsContainer-t-0').parent().removeClass('error');
			$('#stepsContainer').steps('next');
		    }
		    else {
			$('#stepsContainer-t-0').parent().addClass('error');
		    }
		    // Here to avoid recursion.
		    doingformcheck = 0;
		});
		// Prevent step from advancing until check is finished.
		return false;
	    } 
	    if (ispprofile) {
		if (selected_uuid != loaded_uuid) {
		    $('#stepsContainer-p-1 > div')
			.attr('style','display:block');
		    ppstart.StartPP({
			profile      : selected_profile,
			uuid         : selected_uuid,
			ppdivname    : "pp-container",
			registered   : registered,
			isadmin      : isadmin,
			config_callback : ConfigureDone,
			modified_callback : function () { ppchanged = true; },
			rspec        : null,
		        multisite    : multisite,
			amlist       : amlist,
			prunetypes   : prunetypes,
			fromrepo     : fromrepo,
			rerun_instance : window.RERUN_INSTANCE,
			rerun_paramset : window.RERUN_PARAMSET,
		        jacksGraphCallback: updateJacksGraph,
			setStepsMotion : setStepsMotion,
		    });
		    loaded_uuid = selected_uuid;
		    ppchanged = true; 
		}
	    }
	    else {
		$('#stepsContainer-p-1 > div').attr('style','display:none');
		loaded_uuid = selected_uuid;
	    }
	}
	else if (currentIndex == 1 && newIndex == 2) {
	    if (ispprofile && ppchanged) {
		console.info("foo", ppchanged);
		ppstart.HandleSubmit(function(success) {
		    if (success) {
			ppchanged = false;
			$('#stepsContainer-t-1').parent().removeClass('error');
			$('#stepsContainer').steps('next');
			// This is for testing with Selenium.
			if (! $('#pp-wizard-done').length) {
			    $('#pp-container').append("<div class='hidden' " +
					  " id='pp-wizard-done'></div>");
			}
		    }
		    else {
			$('#stepsContainer-t-1').parent().addClass('error');
		    }
		}, updateJacksGraph);
		// We do not proceed until the form is submitted
		// properly. This has a bad side effect; the steps
		// code assumes this means failure and adds the error
		// class.
		return false;
	    }
	}
	else if (currentIndex == 2 && newIndex == 3) {
	    // Check step 2 form values. Any errors, we stop here.
	    if (!doingformcheck) {
		doingformcheck = 1;
		CheckStep2(function (success) {
		    if (success) {
			$('#stepsContainer-t-2').parent().removeClass('error');
			$('#stepsContainer').steps('next');
		    }
		    else {
			$('#stepsContainer-t-2').parent().addClass('error');
		    }
		    // Here to avoid recursion.
		    doingformcheck = 0;
		});
		// Prevent step from advancing until check is finished.
		return false;
	    } 
	}
	// Switch Jacks back to the little window when leaving
	// the Finalize step.
	if (currentIndex == 2) {
	    SwitchJacks('small');
	}
	if (currentIndex == 0 && selected_uuid == null) {
	    return false;
	}
	return true;
    }

    // Step is done changing.
    function StepChanged(step, event, currentIndex, priorIndex) {
	//console.info("StepChanged: ", step, currentIndex, priorIndex);
	//console.info(new Date());
	
        APT_OPTIONS.updatePage({ 'instantiate-step': currentIndex });
	var cIndex = currentIndex;
        if (currentIndex == 1) {
	    // If the profile isn't parameterized, skip the second step
	    if (!ispprofile) {
		if (priorIndex < currentIndex) {
		    // Generate the profile on the third tab
		    ppstart.ShowThumbnail(selected_rspec, updateJacksGraph);
		    //ShowProfileSelectionInline($('#profile_name .current'),
			       //$('#stepsContainer-p-2 #inline_jacks'), true);

		    $(step).steps('next');
		    $('#stepsContainer-t-1').parent().removeClass('done')
			.addClass('disabled');
		}
		if (priorIndex > currentIndex) {
		    $(step).steps('previous');
		    cIndex--;
		}
	    }

	    // TEMPORARY STOPGAP
	    // Refer to Issue #71
	    // https://gitlab.flux.utah.edu/emulab/emulab-devel/issues/71
	    if ($('#pp-form #hwinfo').length == 0) {
		$('#pp-form input[data-key=osNodeType]').parent().append(''+
		    '<a href="' + window.MANUAL + '/hardware.html" style="'+
			'position:absolute;'+
			'right:21px;'+
			'top: 8.5px;'+
		    '" target="_blank">'+
		    '<span id="hwinfo" class="glyphicon glyphicon-info-sign" style="font-size:16px;"'+
			'data-toggle="popover" data-trigger="hover"'+
			'data-content="Click here to see what hardware types are available">'+
		    '</span>'+
		    '</a>'+
		'');
	    }

	    $('#hwinfo').popover({
		trigger: 'hover',
		placement: 'auto',
		container: 'body',
	    });

	    // END STOPGAP
	}
	else if (currentIndex == 2) {
	    if (priorIndex == 1) {
		// Keep the two panes the same height
		$('#inline_container').css('height',
			       $('#finalize_container').outerHeight() - 15);

		// Chrome was having an issue where Jacks was not responding to
		// the height change. Had to also add to Jacks root.
		$('#inline_jacks').css('height',
				   $('#finalize_container').outerHeight() - 15);
	    }
	    if (priorIndex < currentIndex) {
		CheckForRadioUsage();
	    }
	}
	else if (currentIndex == 3) {
	    CheckForSpectrum();
	}
	if (currentIndex < priorIndex) {
	    // Disable going forward by clicking on the labels
	    for (var i = cIndex+1; i < $('.steps > ul > li').length; i++) {
		$('#stepsContainer-t-'+i).parent()
		    .removeClass('done').addClass('disabled');
	    }
	}
    }

    /*
     * Check the form values on step 0 of the wizard.
     */
    function CheckStep0(step_callback)
    {
	SubmitForm(1, 0, function (json) {
	    if (json.code == 0) {
		step_callback(true);
		return;
	    }
	    // Internal error.
	    if (json.code < 0) {
		step_callback(false);
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Form error
	    if (json.code == 2) {
		// Regenerate page with errors.
		ShowFormErrors(json.value);
		step_callback(false);
		return;
	    }
	    // Email not verified, throw up form.
	    if (json.code == 3) {
		sup.ShowModal('#verify_modal');
		
		var doverify = function() {
		    var check_callback = function(json) {
			console.info(json);

			if (!json.code) {
			    // Token was good, we can keep going.
			    sup.HideModal('#verify_modal');
			    $('#verify_modal_submit').off("click");
			    $('#verification_token').parent()
				.removeClass("has-error");
			    $('#verification_token_error')
				.addClass("hidden");

			    if (_.has(json.value, "cookies")) {
				SetCookies(json.value.cookies);
			    }
			    // Redirect if so instructed.
			    if (_.has(json.value, "redirect")) {
				window.location.replace(json.value.redirect);
				return;
			    }
			    // Otherwise continue the work flow.
			    step_callback(true);
			    return;
			}
			// Bad token. Show the error. Continue button
			// is still active.
			$('#verification_token').parent().addClass("has-error");
			$('#verification_token_error').removeClass("hidden");
			$('#verification_token_error').html("Incorrect!");
		    };
		    var token = $('#verification_token').val();
		    var xmlthing = sup.CallServerMethod(null, "instantiate",
							"VerifyEmail",
							{"token" : token});
		    xmlthing.done(check_callback);
		};
		$('#verify_modal_submit').on("click", function (event) {
		    // Submit token for check. We loop until it passes.
		    doverify();
		});
	    }
	});
    }
    /*
     * Check the form values on step 2 (Finalize) of the wizard.
     */
    function CheckStep2(step_callback)
    {
	if (!AllClustersSelected()) {
	    ShowFormErrors({"error" :
			    "Please make your cluster selections!"});
	    step_callback(false);
	    return;
	}
	SubmitForm(1, 2, function (json) {
	    if (json.code == 0) {
		step_callback(true);
		DateChange("#start_day");
		return;
	    }
	    // Internal error.
	    if (json.code < 0) {
		step_callback(false);
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Form error
	    if (json.code == 2) {
		// Regenerate page with errors.
		ShowFormErrors(json.value);
		step_callback(false);
		return;
	    }
	});
    }
    /*
     * Check the form values on step 3 (Schedule) of the wizard.
     */
    function CheckStep3(step_callback)
    {
	ClearFormErrors();

	/*
	 * Initial validation on the start/end time.
	 * Also convert to UTC for submit (to capture local timezone).
	 */
	var start_day  = $('#step3-form [name=start_day]').val();
	var start_hour = $('#step3-form [name=start_hour]').val();
	if (start_day && !start_hour) {
	    ShowFormErrors({"start_hour" : "Missing hour"});
	    step_callback(false);
	    return;
	}
	else if (!start_day && start_hour) {
	    ShowFormErrors({"start_day" : "Missing day"});
	    step_callback(false);
	    return;
	}
	var end_day  = $('#step3-form [name=end_day]').val();
	var end_hour = $('#step3-form [name=end_hour]').val();
	if (end_day && !end_hour) {
	    ShowFormErrors({"end_hour" : "Missing hour"});
	    step_callback(false);
	    return;
	}
	else if (!end_day && end_hour) {
	    ShowFormErrors({"end_day" : "Missing day"});
	    step_callback(false);
	    return;
	}
	SubmitForm(1, 3, function (json) {
	    if (json.code == 0) {
		step_callback(true);
		return;
	    }
	    // Internal error.
	    if (json.code < 0) {
		step_callback(false);
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Form error
	    if (json.code == 2) {
		// Regenerate page with errors.
		ShowFormErrors(json.value);
		step_callback(false);
		return;
	    }
	});
    }

    var Instantiate = function () {
        var submitted = false;

        return function (event)
        {
	    if (webonly != 0) {
	        event.preventDefault();
	        sup.SpitOops("oops",
			     "You do not belong to any projects at your Portal, " +
			     "so you have have very limited capabilities. Please " +
			     "join or create a project at your " +
			     (portal && portal != "" ?
			     "<a href='" + portal + "'>Portal</a>" : "Portal") +
			     " to enable more capabilities. Thanks!")
	        return false;
	    }
	    // Prevent double click.
	    if (submitted === true) {
	        // Previously submitted - don't submit again
	        event.preventDefault();
	        console.info("Ignoring double submit");
	        return false;
	    } else {
	        // Mark it so that the next submit can be ignored
	        submitted = true;
	    }

            // Submit with checkonly first, then for real
	    SubmitForm(1, 3, function (json) {
	        //console.info(json);
	        // Internal error.
	        if (json.code < 0) {
		    sup.SpitOops("oops", json.value);
		    submitted = false;
		    return;
	        }
	        // Form error
	        if (json.code == 2) {
	            ShowFormErrors(json.value);
	            submitted = false;
		    return;
	        }
	        $("#waitwait-modal").modal('show');
	        SubmitForm(0, 3, function(json) {
		    if (json.code) {
		        console.info(json);
		        if (json.code == 3) {
		            submitted = false;
			    sup.HideWaitWait(function () {
				HandleLicenseRequirements(json.value);
			    })
			    return;
		        }
		        submitted = false;
			sup.HideWaitWait(function () {			
		            sup.SpitOops("oops", json.value);
			});
			return;
		    }
		    /*
		     * The return value will have a redirect url in it,
		     * and some optional cookies.
		     */
		    if (_.has(json.value, "cookies")) {
		        SetCookies(json.value.cookies);
		    }
		    window.location.replace(json.value.redirect);
	        });
	    });
	    return true;
        };
    }();

    function ShowFormErrors(errors) {
	$('.step-forms').find('.format-me').each(function () {
	    var input = $(this).find(":input")[0];
	    var label = $(this).find(".control-error")[0];
	    var key   = $(input).data("key");
	    if (key && _.has(errors, key)) {
		$(this).addClass("has-error");
		$(label).html(_.escape(errors[key]));
		$(label).removeClass("hidden");
	    }
	});
	// General Error on the last step.
	if (_.has(errors, "error")) {
	    $('#general_error').html(_.escape(errors["error"]));
	}
    }

    function ClearFormErrors() {
	$('.step-forms').find('.format-me').each(function () {
	    var input = $(this).find(":input")[0];
	    var label = $(this).find(".control-error")[0];
	    var key   = $(input).data("key");
	    if (key) {
		$(this).removeClass("has-error");
		$(label).html("");
		$(label).addClass("hidden");
	    }
	});
	$('#general_error').html("");
    }

    function SerializeForm()
    {
	// Current form contents as formfields array.
	var formfields  = {};
	var sites       = {};
	
	// The dates are special
	var start_day  = $('#step3-form [name=start_day]').val();
	var start_hour = $('#step3-form [name=start_hour]').val();
	if (start_day && start_hour) {
	    var start = moment(start_day, "MM/DD/YYYY");
	    start.hour(start_hour);
	    $('#step3-form [name=start]').val(start.format());
	}
	else {
	    $('#step3-form [name=start]').val("");
	}
	var end_day  = $('#step3-form [name=end_day]').val();
	var end_hour = $('#step3-form [name=end_hour]').val();
	if (end_day && end_hour) {
	    var end = moment(end_day, "MM/DD/YYYY");
	    end.hour(end_hour);
	    $('#step3-form [name=end]').val(end.format());
	}
	else {
	    $('#step3-form [name=end]').val("");
	}
	
	// Convert form data into formfields array, like all our
	// form handler pages expect.
	var fields = $('.step-forms').serializeArray();
	$.each(fields, function(i, field) {
	    console.info(field, field.name, field.value);
	    /*
	     * The sites array is special since we want that to be
	     * an array inside of the formfields array, and serialize
	     * is not going to do that for us. 
	     */
	    var site = /^sites\[(.*)\]$/g.exec(field.name);
	    if (site) {
		sites[site[1]] = field.value;
	    }
	    else if (! (field.name == "where" && field.value == "(any)")) {
		formfields[field.name] = field.value;
	    }
	});
	if (Object.keys(sites).length) {
	    formfields["sites"] = sites;
	}
	console.info("SerializeForm", formfields);
	return formfields;
    }

    //
    // Submit the form. The step matters only when checking.
    //
    function SubmitForm(checkonly, step, callback)
    {
	// Current form contents as formfields array.
	var formfields  = SerializeForm();
	
	var rpc_callback = function(json) {
	    console.info(json);
	    callback(json);
	}
	ClearFormErrors();

	var xmlthing = sup.CallServerMethod(null, "instantiate",
					    (checkonly ?
					     "CheckForm" : "Submit"),
					    {"formfields" : formfields,
					     "step"       : step});
	xmlthing.done(rpc_callback);
    }

    function SetCookies(cookies) {
	// Delete existing cookies first
	var expires = "expires=Thu, 01 Jan 1970 00:00:01 GMT;";

	$.each(cookies, function(name, value) {
	    document.cookie = name + '=; ' + expires;

	    var cookie = 
		name + '=' + value.value +
		'; domain=' + value.domain +
		'; max-age=' + value.expires + '; path=/; secure';

	    document.cookie = cookie;
	});
    }

    function SetCookie(name, value, days) {
	// Delete existing cookies first
	var expires = "expires=Thu, 01 Jan 1970 00:00:01 GMT;";
	document.cookie = name + '=; ' + expires;

	var date = new Date();
	date.setTime(date.getTime()+(days*24*60*60*1000))

	var cookie = name + '=' + value +
		'; expires=' + date.toGMTString() + '; path=/';

	document.cookie = cookie;
    }

    // Cookie parser found from Google
    function GetCookie(name) {
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	for(var i=0;i < ca.length;i++) {
	    var c = ca[i];
	    while (c.charAt(0)==' ') c = c.substring(1,c.length);
	    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
    }
    
    function CreateClusterStatus() {
	if (monitor == null || $.isEmptyObject(monitor)) {
	    return;
	}
	// No need to do this if not showing selectors.
	if (!window.CLUSTERSELECT) {
	    return;
	}

	$('#finalize_options .cluster-group').each(function() {
	    if ($(this).hasClass("pickered")) {
		return;
	    }
	    $(this).addClass("pickered");

	    var resourceTypes = ["PC"];
	    // Have to do look this up based off of the site name since that's 
	    // the only hook Jacks is giving.
	    var label = $(this).find('.control-label').attr('name');
	    if (types && label && types[label]) {
		if (types[label]['emulab-xen']) {
		    if (Object.keys(types[label]).length == 1) {
			resourceTypes = [];
		    }
		    resourceTypes.push("VM");
		}
	    }
	    var which = $(this).parent().attr('id');

	    // Decide what classes each option element should have
	    var pickerTarget = '#'+which+' .select_where';
	    var attributes = {}
	    var selected = null;

	    $(pickerTarget).find('option').each(function() {
		var attrs = {}
		var siteName = $(this).attr('value');

		// Hide "Please Select" option
		if (siteName == "") {
		    attrs['class'] = 'enabled';
		}
		else if ($(this).prop('disabled')) {
		    attrs['class'] = 'disabled';
		    attrs['tooltip'] = {
			placement: 'right',
			title: '<div>This testbed is incompatible with the selected profile</div>'
		    }
		}
		else {
		    attrs['class'] = 'enabled';
		    if ($(this).attr('selected')) {
			// Do not not lose selection if its enabled.
			selected = siteName;
		    }
		}

		if (_.contains(window.FEDERATEDLIST, $(this).attr('value'))) {
		    attrs['class'] += " federated";
		}

		attributes[siteName] = attrs;
	    });

	    var dividers = [{ match: 'class',
			      key: 'federated',
			      text: 'Federated Clusters'
			    },
			    { match: 'class',
			      key: 'disabled'
			    }];

	    picker.MakePicker(pickerTarget,
			      function (container, that, target) {
				  ClusterSelected(that, true);
				  wt.StatusClickEvent(container, that, target);
			      },
			      attributes, dividers,
			      {class: 'cluster_picker_status'});

	    // Assign health ratings and icons
	    _.each(amlist, function(details, key) {
		var name = details.name;
		var data = monitor[key];
		var rating, classes;
		var target = $('#'+which+' .cluster_picker_status .dropdown-menu .enabled a:contains("'+name+'")');
		if (data && !$.isEmptyObject(data)) {
		    // Calculate testbed rating and set up tooltips.
		    rating = wt.CalculateRating(data, resourceTypes);
		    classes = wt.AssignStatusClass(rating[0], rating[1]);
		}
		else {
		    rating = wt.InactiveRating();
		    classes = wt.AssignInactiveClass();
		}
		target.parent().attr('data-health', rating[0]).attr('data-rating', rating[1]).attr('urn', key);
		    
		target.addClass(classes[0]).addClass(classes[1]);

		target.append(wt.StatsLineHTML(classes, rating[2]));
	    });

	    $('#'+which+' .cluster_picker_status .dropdown-menu').find('.enabled.native').sort(SortClusterStatus).prependTo($('#'+which+' .cluster_picker_status .dropdown-menu'));
	    $('#'+which+' .cluster_picker_status .dropdown-menu').find('.enabled.federated').sort(SortClusterStatus).insertAfter($('#'+which+' .cluster_picker_status .dropdown-menu .federatedDivider'));

	    var pickerStatus = $('#'+which+' .cluster_picker_status .dropdown-menu .enabled a');

	    // If only two enabled choices, one of which is always the
	    // "Please Select" option, then force that cluster.
	    if (pickerStatus.length == 2) {
		pickerStatus[1].click();
	    }
	    else if (selected) {
		// User already selected an enabled cluster, we want to keep it.
		pickerStatus.filter(function () {
		    if ($(this).attr("value") == selected) {
			$(this).click();
		    }
		});
	    }
	    else {
		// Back to Please Select.
		pickerStatus[0].click();
	    }
	});	  
	
	$('[data-toggle="tooltip"]').tooltip();

	ShowClusterReservations();
    }

    function ShowClusterReservations() {
	if (resinfo == null || $.isEmptyObject(resinfo)) {
	    return
	}

	var project = $('#profile_pid').val();
	var projectReservations = {}
	var requested = 0;
	var inuse = 0;
	var ready = 0;
	var reloading = 0;

	$('#reservation_confirmation').addClass('hidden');
	$('#reservation_warning').addClass('hidden');
	$('#reservation_future').addClass('hidden');

	$('#finalize_options .cluster-group').each(function() {
	    var click  = false;
	    var siteid = $(this).find("> label").attr("name");

	    $(this).find('.dropdown-menu > .enabled:not(.hidden)').each(function() {
		$(this).find('.reservation_tooltip').remove();

		var start = null;
		var end = null;
		var earliest = null;
		var hasReservation = false;
		var currentReservations = false;

		var target = $(this).find('a');
		var cluster = $(this).attr('urn');

		if (_.has(resinfo, cluster) && resinfo[cluster] != null) {
		    if (typeof(resinfo[cluster]) == "string") {
			console.info("Timed out getting reservation system " +
				     "info for cluster " + cluster);
			return;
		    }
		    /*
		     * Upcoming is lower priority so do first.
		     */
		    if (_.has(resinfo[cluster], 'upcoming') &&
			resinfo[cluster]['upcoming'] != null) {
			_.each(resinfo[cluster]['upcoming'],
			       function(thelist, resproj) {
				   _.each(thelist, 
					  function(obj) {
			    console.info("upcoming", obj.starttime,
					 resproj, project);
			    
			    // Current project has a future reservation
			    // Used for cluster icons
			    if (project == resproj) {
				hasReservation = true;
				click = true;

				// Find earliest starting reservation time
				if (earliest == null ||
				    earliest > obj.starttime) {
				    earliest = obj.starttime;
				}
			    }
			    // Do not override a current entry (from above).
			    if (!_.has(projectReservations, resproj)) {
				projectReservations[resproj] = {
				    // Icon for projects
				    class: "futureReservation",
				    // Used for sorting projects
				    attr: {'data-priority': 2}
				}
			    }
			 });
		      });
		    }

		    if (_.has(resinfo[cluster], 'current') &&
			resinfo[cluster]['current'] != null) {
			_.each(resinfo[cluster]['current'],
			       function(thelist, resproj) {
				   _.each(thelist, 
					  function(obj) {
			    var req        = obj.reserved;
			    var used       = obj.used;
			    var type       = obj.nodetype;

			    console.info("current", req, used, obj.ready,
					 obj.reloading, type, resproj, project);
			    
			    // Current project has a current reservation
			    // Used for cluster icons
			    if (project == resproj) {
				hasReservation = true;
				click = true;
				// All nodes for current project reservations.
				requested += parseInt(req);
				inuse += parseInt(used);
				ready += parseInt(obj.ready);
				reloading += parseInt(obj.reloading);
				currentReservations = true;
			    }
			    projectReservations[resproj] = {
				// Icon for projects
				class: "hasReservation",
				// Used for sorting projects
				attr: {'data-priority': 1}
			    }
			  });
		       });
		    }
		    // These are reservations that could interfere with
		    // the user getting nodes. 
		    if (!hasReservation && 
			_.has(resinfo[cluster], 'pressure') &&
			resinfo[cluster]['pressure'] != null) {
			_.each(resinfo[cluster]['pressure'],
			       function(reslist, type) {
				   //console.info("P1", reslist,
				   //             type, hardware, siteid);
				   if (_.has(hardware, siteid) &&
				       _.has(hardware[siteid], type) &&
				       _.has(reslist, project)) {
				       //console.info("P", siteid,
				       //              type, project);
				       if (start == null ||
					   start > reslist[project][0][0]) {
					   start = reslist[project][0][0];
					   end = reslist[project][0][1];
				       }
				   }
			       });
		    }

		    if (hasReservation || start != null) {
			if (0) {
			    console.info("res", project, start, end, earliest,
					 requested, inuse, ready, reloading);
			}
			$(this).attr('data-res-pid', project);
			$(this).attr('data-res-requested', requested);
			$(this).attr('data-res-used', inuse);
			$(this).attr('data-res-ready', ready);
			$(this).attr('data-res-reloading', reloading);
			if (hasReservation) {
			    $(this).removeAttr('data-res-end');
			    $(this).removeAttr('data-res-upcoming');
			    
			    if (currentReservations) {
				$(this).attr('data-now', 'true');
				target.append(wt.HasReservationHTML(project, 'cluster', 2));
			    }
			    else {
				$(this).attr('data-res-upcoming', earliest);
				$(this).attr('data-now', 'false');
				target.append(wt.FutureReservationHTML(project, 'cluster', 2));
			    }
			}
			else if (start) {
			    $(this).attr('data-res-start', start);
			    if (end != null) {
				$(this).removeAttr('data-now');

				$(this).attr('data-res-end', end);
				target.append(wt.ReservationWarningHTML('cluster', 2));
			    }
			}
			$('.reservation_tooltip > div').tooltip();
		    }
		    else {
			$(this).removeAttr('data-now');
			$(this).removeAttr('data-res-pid');
			$(this).removeAttr('data-res-start');
			$(this).removeAttr('data-res-end');
			$(this).removeAttr('data-res-requested');
			$(this).removeAttr('data-res-used');
			$(this).removeAttr('data-res-ready');
			$(this).removeAttr('data-res-reloading');
			$(this).removeAttr('data-res-upcoming');
		    }
		}
	    });

	    var which = $(this).parent().attr('id');

	    $('#'+which+' .cluster_picker_status .dropdown-menu').find('.enabled.native').sort(SortClusterStatus).prependTo($('#'+which+' .cluster_picker_status .dropdown-menu'));
	    $('#'+which+' .cluster_picker_status .dropdown-menu').find('.enabled.federated').sort(SortClusterStatus).insertAfter($('#'+which+' .cluster_picker_status .dropdown-menu .federatedDivider'));

	    var pickerStatus = $('#'+which+' .cluster_picker_status .dropdown-menu .enabled a');
	    if (0 && click) {
		// Do not do this anymore, its annoying.
		pickerStatus[1].click();
	    }
	    else {
		$('#'+which+' .cluster_picker_status .dropdown-menu .selected a').click();
	    }
	});
	if (_.keys(projectReservations).length > 0 && $('#profile_pid_picker').length == 0) {
	    picker.MakePicker('#profile_pid', wt.ResClickEvent, projectReservations);

	    // Add icons
	    $('#profile_pid_picker .dropdown-menu .hasReservation a').append(wt.HasReservationHTML(project, 'project', 1))
	    $('#profile_pid_picker .dropdown-menu .futureReservation a').append(wt.FutureReservationHTML(project, 'project', 1))

	    $('#profile_pid_picker .dropdown-menu > li').sort(SortProfileList).prependTo($('#profile_pid_picker .dropdown-menu'));

	    $($('#profile_pid_picker .dropdown-menu a')[0]).click();
	}
    }

    function SortClusterStatus(a, b) {
	if ((a.dataset.now && !b.dataset.now) || (a.dataset.now == 'true' && b.dataset.now == 'false')) {
	    return -1;
	}

	if ((b.dataset.now && !a.dataset.now) || (b.dataset.now == 'true' && a.dataset.now == 'false')) {
	    return 1;
	}

	var aHealth = Math.ceil((+a.dataset.health)/50);
	var bHealth = Math.ceil((+b.dataset.health)/50);

	if (aHealth > bHealth) {
	    return -1;
	}
	else if (aHealth < bHealth) {
	    return 1;
	}
	return +b.dataset.rating - +a.dataset.rating;
    }

    function SortProfileList(a, b) {
	if ((!a.dataset.priority && b.dataset.priority) || (a.dataset.priority < b.dataset.priority)) {
	    return 1;
	}

	return -1;
    }

    function SwitchJacks(which)
    {
      //console.info("SwitchJacks", which);
      if (which == 'small')
      {
	$('#stepsContainer #finalize_container')
	  .removeClass('col-lg-12 col-md-12 col-sm-12');
	$('#stepsContainer #finalize_container')
	  .addClass('col-lg-8 col-md-8 col-sm-8');
	$('#stepsContainer #inline_large_jacks').html('');
	$('#inline_large_container').addClass('hidden');
	ppstart.ShowThumbnail(selected_rspec, null);
			//if (ispprofile) {
				//ppstart.ChangeJacksRoot($('#stepsContainer-p-2 #inline_jacks'), true);
			//}
			//else {
				//ShowProfileSelectionInline($('#profile_name .current'), $('#stepsContainer-p-2 #inline_jacks'), true);
			//}
	$('#stepsContainer-p-2 #inline_container')
	  .removeClass('hidden');
      }
      else if (which == 'large')
      {
	// Sometimes the steps library will clean up the added elements
	if ($('#inline_large_container').length === 0)
	{        
	  $('<div id="inline_large_container" class="hidden"></div>')
	    .insertAfter('#stepsContainer .content');
	  $('#inline_large_container')
	    .html(''
		  +'<button id="closeLargeInline" type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>'
		  +'<div id="inline_large_jacks"></div>');
	  $('#stepsContainer #inline_large_container')
	    .addClass('col-lg-8 col-lg-offset-2 col-md-8 col-md-offset-2 col-sm-10 col-sm-offset-1 col-xs-12 col-xs-offset-0');
		
	  $('#closeLargeInline').click(function() {
	    SwitchJacks('small');
	  });
	}

	$('#stepsContainer #finalize_container')
	  .removeClass('col-lg-8 col-md-8 col-sm-8');
	$('#stepsContainer #finalize_container')
	  .addClass('col-lg-12 col-md-12 col-sm-12');
	//$('#stepsContainer-p-2 #inline_jacks').html('');
	$('#stepsContainer-p-2 #inline_container')
	  .addClass('hidden');

	if (ispprofile)
	{
	  ppstart.ChangeJacksRoot($('#stepsContainer #inline_large_jacks'), false);
	}
	else
	{
	  ShowProfileSelectionInline($('#profile_name .current'), $('#stepsContainer #inline_large_jacks'), false);
	}
	$('#inline_large_container').removeClass('hidden');
      }
    }

    function resetForm($form) {
	$form.find('input:text, input:password, select, textarea').val('');
    }

    function ShowProfileSelection(selectedElement) {
	if (!$(selectedElement).hasClass('selected')) {
	    $('#profile_name li').each(function() {
		$(this).removeClass('selected');
	    });
	    $(selectedElement).addClass('selected');
	}
	console.info("ShowProfileSelection: " +
		     $(selectedElement).attr('value'));
	
	var continuation = function(profile_blob) {
	    var profileInfo = profilelist[$(selectedElement).attr('value')]
	    var isFavorite = profileInfo.favorite;

	    // Add title name and favorite button
	    $('#showtopo_title').html("<h3>" + profile_blob.name + "</h3>" +
		"<button id='favorite_button' class='btn btn-default btn-sm'>" + 
		"<span id='set_favorite' class='glyphicon glyphicon-star" + ((isFavorite == 1) ? " favorite" : "") + "'></span>" + 
		"</button>");

	    $('#showtopo_author').html(profile_blob.creator);
	    $('#showtopo_project').html(profileInfo.project);  
	    $('#showtopo_version').html(profile_blob.version); 
	    $('#showtopo_last_updated').html(profile_blob.created);
	    $('#showtopo_description').html(profile_blob.description);
	    if (profile_blob.fromrepo) {
		$('#showtopo_repohash').html(profile_blob.repohash);
		$('.showtopo_repoinfo').removeClass("hidden");
		fromrepo = true;
	    }
	    else {
		$('.showtopo_repoinfo').addClass("hidden");
		fromrepo = false;
	    }

	    sup.maketopmap('#showtopo_div',
			   profile_blob.rspec, false, !multisite);

	    // Set favorite toggle click event
	    $('#favorite_button').click(function() {
		ToggleFavorite(selectedElement)}
	    );
	};
	GetProfile($(selectedElement).attr('value'), continuation);
    }
    
    function ToggleFavorite(target) {
	var wasFav = profilelist[$(target).attr('value')].favorite;
	var callback = function(e) {    
	    if (wasFav) {
		$('#set_favorite').removeClass('favorite');
		profilelist[$(target).attr('value')].favorite = 0;
		$('#favorites li[value='+$(target).attr('value')+']').remove();

		// They were selected on the item in the favorites list, which was just removed
		// Adjust their selection to the first instance of that profile.
		if ($('#profile_name .selected').length == 0) {
		    $('#profile_name li[value='+$(target).attr('value')+']')[0].click();
		}

		if ($('#favorites li').length == 0) {
		    $('#title_favorites').addClass('hidden');
		}
	    }
	    else {
		$('#set_favorite').addClass('favorite');
		profilelist[$(target).attr('value')].favorite = 1;

		var clone = $(target).clone();
		$(clone).removeClass('selected');
		$('#favorites').append(clone);
		$(clone).click(function (event) {
		    event.preventDefault();
		    ShowProfileSelection(event.target);
		});

		$('#title_favorites').removeClass('hidden');
	    }
	}
	var $xmlthing = sup.CallServerMethod(ajaxurl,
					     "instantiate", (wasFav ? "ClearFavorite" : "MarkFavorite"),
					     {"uuid" : $(target).attr('value')});
	$xmlthing.done(callback);
    }


    // Used to generate the topology on Tab 3 of the wizard for non-pp profiles
    function ShowProfileSelectionInline(selectedElement, root, selectionPane) {
	console.info("ShowProfileSelectionInline: " +
		     $(selectedElement).attr('value'));

	var xmlDoc = $.parseXML(selected_rspec);
	var nodecount  = $(xmlDoc).find("node").length;
	
//	if (nodecount > 100) {
//	    $('#stepsContainer #inline_overlay').addClass("hidden");
//	    $('#inline_jacks #edit_dialog #edit_container')
//		.addClass("hidden");
//	    return;
//	}
//	else {
	    $('#stepsContainer #inline_overlay').removeClass("hidden");
	    $('#inline_jacks #edit_dialog #edit_container')
		.removeClass("hidden");
//	}
	editor = new JacksEditor(root, true, true,
				 selectionPane, true, !multisite);
      editor.show(selected_rspec);
    }

    function ChangeProfileSelection(selectedElement) {
	if (!$(selectedElement).hasClass('current')) {
	    $('#profile_name li').each(function() {
		$(this).removeClass('current');
	    });
	    $(selectedElement).addClass('current');
	}
	console.info("ChangeProfileSelection: " +
		     $(selectedElement).attr('value'));

	setStepsMotion(false);
	
	var profile_name = $(selectedElement).attr('name');
	var profile_value = $(selectedElement).attr('value');
	$('#selected_profile').attr('value', profile_value);
	$('#selected_profile_text').html("" + profile_name);
	
	var continuation = function(profile_blob) {
	    $('#showtopo_title').html("<h3>" + profile_blob.name + "</h3>");
	    $('#showtopo_description').html(profile_blob.description);
	    $('#selected_profile_description').html(profile_blob.description);
	    $('#finalize_profile_name')
		.text(profile_blob.name + ":" + profile_blob.version);

	    ispprofile       = profile_blob.ispprofile;
	    isscript         = profile_blob.isscript;
	    selected_profile = profile_value;
	    selected_uuid    = profile_blob.uuid;
	    selected_rspec   = SetClusters(profile_blob.rspec);
	    selected_version = profile_blob.version;
	    amdefault        = profile_blob.amdefault;
	    if (ispprofile) {
		$('#save_paramset_button').removeClass("hidden");
	    }
	    else {
		$('#save_paramset_button').addClass("hidden");
	    }
	    $('#profile_show_button')
		.attr("href", "show-profile.php?profile=" + selected_profile);

	    if (window.CANCOPY && !profile_blob.fromrepo) {
		CopyProfile.SwitchProfile(selected_profile);
		$('#profile-copy-button').removeClass("hidden");
	    }
	    else {
		// Not allowed to copy a repo based profile.
		$('#profile-copy-button').addClass("hidden");
	    }
	    if (profile_blob.fromrepo) {
		$('#selected_profile_text')
		    .html(profile_name + " (Repohash: " +
			  profile_blob.repohash + ")");
		window.PROFILE_REFSPEC = profile_blob.reporef;
		window.PROFILE_REFHASH = profile_blob.repohash;
		fromrepo = true;
	    }
	    else {
		window.PROFILE_REFSPEC = null;
		window.PROFILE_REFHASH = null;
		fromrepo = false;
	    }
	    setStepsMotion(true);

	    /*
	     * Change the project; if the user's project list includes
	     * the project the profile belongs to, that becomes the default.
	     */
	    if (0 && projlist && _.has(projlist, profile_blob.pid)) {
		$('#project_selector #profile_pid').val(profile_blob.pid);
		UpdateGroupSelector();
	    }
	    CreateAggregateSelectors(selected_rspec);

	    /*
	     * First time, if skipfirststep is set, do it and clear.
	     */
	    if (window.SKIPFIRSTSTEP) {
		$('#stepsContainer').steps('next');
		window.SKIPFIRSTSTEP = false;
	    }
	};
	GetProfile($(selectedElement).attr('value'), continuation);
    }
    
    function GetProfile(profile, continuation) {
	var callback = function(json) {
	    if (json.code) {
		alert("Could not get profile: " + json.value);
		return;
	    }
	    console.info("GetProfile:", json);
	    
	    var xmlDoc = $.parseXML(json.value.rspec);
	    var xml    = $(xmlDoc);

	    /*
	     * We now use the desciption from inside the rspec, unless there
	     * is none, in which case look to see if the we got one in the
	     * rpc reply, which we will until all profiles converted over to
	     * new format rspecs.
	     */
	    var description = null;
	    $(xml).find("rspec_tour").each(function() {
		$(this).find("description").each(function() {
		    description = marked($(this).text());
		});
	    });
	    if (!description || description == "") {
		description = "Hmm, no description for this profile";
	    }
	    json.value.description = description;
	    continuation(json.value);
	}
	var $xmlthing = sup.CallServerMethod(ajaxurl,
					     "instantiate", "GetProfile",
					     {"profile" : profile});

	/*
	 * If a repo-based and we got a specific branch/tag/hash, we have to
	 * get the source for that, since it will be different then what
	 * is stored in the profile descriptor.
	 */
	if (fromrepo &&
	    (window.TARGET_REFHASH !== undefined ||
	     window.TARGET_REFSPEC !== undefined)) {

	    // This is what we checkout below. 
	    var target = window.TARGET_REFHASH || window.TARGET_REFSPEC;
	    
	    // Rerun refspec is what we need for the form, just passing along.
	    // Might be null (paramset or rerun instance)
	    var refspec = window.TARGET_REFSPEC;

	    // See ppwizard, it will run the script again if the params change
	    // and need to know what to checkout in the jail.
	    window.TARGET_REPOREF = target;

	    $xmlthing.done(function(json) {
		gitrepo.GetRepoSource({
		    "uuid"     : profile,
		    "refspec"  : target,
		    "callback" : function(source, hash) {
		    var pythonRe = /^import/m;

		    // For the form that is submitted.
		    $('#repohash').val(hash);
		    if (refspec) {
			$('#reporef').val(refspec);
		    }
		    // We change this whenever we switch around.
		    window.PROFILE_REFHASH = hash;
		    window.PROFILE_REFSPEC = refspec;
		    
		    // Pass along.
		    json.value.repohash = hash;

		    if (pythonRe.test(source)) {
			ConvertScript(source, profile, target,
				      function(rspec, paramdefs) {
			    // Need to pass these along at submit.
			    $('#rspec_textarea').val(rspec);
			    $('#script_textarea').val(source);
			    json.value.rspec      = rspec;
			    json.value.isscript   = true;
			    //
			    // We can get a parameterized profile, or not.
			    //
			    if (paramdefs === undefined) {
				json.value.ispprofile = false;
			    }
			    else {
				$('#paramdefs').val(paramdefs);
				json.value.ispprofile = true;
			    }
			    callback(json);
			});
		    }
		    else {
			// New rspec, proceed
			json.value.rspec = source;
			// Need to pass this along at submit.
			$('#rspec_textarea').val(source);
			callback(json);
		    }
		}})
	    });
	}
	else {
	    $xmlthing.done(callback);
	}
    }

    //
    // Pass a geni-lib script to the server to run (convert to XML).
    // We use this on repo-based profiles, where we have to get the
    // source code from the repo, and convert to an rspec.
    //
    // We pass along the refspec (which might be a hash) so that the
    // corresponding commit can be checked out in the genilib jail.
    // Really, why are we passing the script around?
    //
    function ConvertScript(script, profile_uuid, refspec, continuation)
    {
	var callback = function(json) {
	    sup.HideWaitWait();

	    if (json.code) {
		sup.SpitOops("oops",
			     "<pre><code>" +
			     $('<div/>').text(json.value).html() +
			     "</code></pre>");
		return;
	    }
	    if (json.value.rspec != "") {
		continuation(json.value.rspec, json.value.paramdefs);
	    }
	}
	sup.ShowWaitWait("We are converting the geni-lib script to an rspec. " +
			 "Patience please.");
	var xmlthing = sup.CallServerMethod(null,
					    "manage_profile",
					    "CheckScript",
					    {"script"       : script,
					     "profile_uuid" : profile_uuid,
					     "refspec"      : refspec,
					     "getparams"    : true});
	xmlthing.done(callback);
    }

    /*
     * Callback from the PP configurator. Stash rspec into the form.
     */
    function ConfigureDone(newRspec) {
	// If not a registered user, we do not get an rspec back, since
	// the user is not allowed to change the configuration.
	if (newRspec) {
	    selected_rspec = SetClusters(newRspec);
	    $('#rspec_textarea').val(selected_rspec);
	    CreateAggregateSelectors(selected_rspec);
	}
	if (window.NOPPRSPEC) {
	    alert("Guest users may configure parameterized profiles " +
		  "for demonstration purposes only. The parameterized " +
		  "configuration will not be used if you Create this " +
		  "experiment.");
	}
    }

    var sites  = {};
    var siteIdToSiteNum = {};
    /*
     * Build up a list of Aggregate selectors. Normally just one, but for
     * a multisite aggregate, need more then one.
     */
    function CreateAggregateSelectors(rspec)
    {
	var xmlDoc = $.parseXML(rspec);
	var xml    = $(xmlDoc);
	var html   = "";
	var bound  = 0;
	var count  = 0;
	var ammap  = {};
	sites = {};

	// No need to do this if not showing selectors.
	if (!window.CLUSTERSELECT) {
	    return;
	}

	var nodecount  = $(xmlDoc).find("node").length;
	if (nodecount > 3000) {
	    doconstraints = 0;
	}
	else {
	    doconstraints = window.DOCONSTRAINTS;
	}
	console.info("CreateAggregateSelectors: ", nodecount, doconstraints);

	/*
	 * Find the sites. Might not be any if not a multisite topology
	 */
	$(xml).find("node").each(function() {
	    var node_id = $(this).attr("client_id");
	    var site    = this.getElementsByTagNameNS(JACKS_NS, 'site');
	    var manager = $(this).attr("component_manager_id");

	    // Keep track of how many bound nodes, of the total.
	    count++;

	    if (manager && manager.length) {
		var parser = /^urn:publicid:idn\+([\w#!:.\-]*)\+/i;
		var matches = parser.exec(manager);
		if (! matches) {
		    console.error("Could not parse urn: " + manager);
		    return;
		}
		// Bound node, no dropdown will be provided for these
		// nodes, and if all nodes are bound, no dropdown at all.
		bound++;
		ammap[manager] = manager;
	    }
	    else if (site.length) {
		var siteid = $(site).attr("id");
		if (siteid === undefined) {
		    console.error("No site ID in " + site);
		    return;
		}
		sites[siteid] = siteid;
	    }
	});
	console.info("CreateAggregateSelectors2: ", count, bound, ammap);

	// All nodes bound, no dropdown.
	if (count == bound) {
	    $("#cluster_selector").addClass("hidden");
	    // Clear the form data.
	    $("#cluster_selector").html("");
	    // Tell the server not to whine about no aggregate selection.
	    $("#fully_bound").val("1");
	    // Need to set the "where" form field so that we pass the
	    // correct default aggregate to the backend.
	    if (_.size(ammap) == 1) {
		var manager = _.keys(ammap)[0];
		var name    = amlist[manager].name;
		
		$("#cluster_selector")
		    .html("<input name='where' type='hidden' " +
			  "value='" + name + "'>");
	    }
	    return;
	}

	// Clear for new profile.
	siteIdToSiteNum = {};
	var sitenum = 0;

	/*
	 * Create the dropdown selection lists. When only one choice, we
	 * force that choice. But if a slection has already been made, then
	 * we want to keep that as the selected cluster, its annoying to
	 * have it changed, since we call this multiple times (after
	 * constraints change, when the reservation info come in).
	 */
	var createDropdowns = function (selected) {
	    var options = "";
	    
	    _.each(amlist, function(details, key) {
		/*
		 * Temp; do not show mobile if not an admin
		 */
		if (0 && details.ismobile == 1 && !isadmin) {
		    return;
		}
		var name = details.name;
		options = options + "<option value='" + name + "'";
		if (amlist.count == 1 || name == selected) {
		    options = options + " selected";
		}
		options = options + ">" + name + "</option>";
	    });
	    return options;
	};

	console.info(sites);
	console.info(ammap);

	// If multisite is disabled for the user, or no sites or 1 site.
	if (!multisite ||
	    (Object.keys(sites).length <= 1))  {
	    var siteid;
	    if (Object.keys(sites).length == 0) {
		siteid = "Site 1";
	    }
	    else {
		siteid = _.values(sites)[0]
	    }
	    /*
	     * Since we call this multiple times (after constraints change,
	     * when the reservation info come in), lets not change the
	     * selection if the user has already made one. 
	     */
	    var selected;
	    if ($('#finalize_options .cluster-group').length) {
		selected = $('#finalize_options .cluster-group ' +
			     'select option:selected').text();
	    }
	    else {
		// Always default Powder dropdown to Emulab
		if (window.ISPOWDER) {
		    selected = "Emulab";
		}
	    }
	    var options = createDropdowns(selected);
	    
	    html = 
		"<div id='nosite_selector' " +
		"     class='form-horizontal experiment_option'>" +
		"  <div class='form-group cluster-group'>" +
		"    <label class='col-sm-4 control-label' name='" + siteid + "' " +
		"           style='text-align: right;'>Cluster:</a>" +
		"    </label> " +
		"    <div class='col-sm-6 site-selector'>" +
		"      <select id='site"+sitenum+"_selector' name='where' " +
		"              data-siteid='nosite_selector' " +
		"              class='form-control select_where'>" +
		"        <option value=''>Please Select</option>" +
		options +
		"      </select>" +
		"    </div>" +
		"<div class='col-sm-4'></div>" +
	    "<div class='col-sm-6 alert alert-danger' id='where-nowhere' style='display: none; margin-top: 5px; margin-bottom: 5px'>This profile <b>will not work on any clusters</b>. Please check your profile or parameters for errors. If you are sure they are correct, you can report the problem to support@cloudlab.us and make sure to link to the problematic profile.</div>" +
	    "<div class='col-sm-4 col-sm-offset-1' style='display: none; margin-top: 5px; margin-bottom: 5px;'><button class='btn btn-default' type='button' data-toggle='collapse' data-target='#nowhere-breakdown' aria-expanded='false' id='nowhere-breakdown-button'>Cluster Compatibility Report</button></div>" +
	        "<div class='col-sm-12 collapse' id='nowhere-breakdown'></div>"+
	        "<div class='col-sm-6 alert alert-warning hidden' id='where-deprecated' style='margin-top: 5px; margin-bottom: 5px'></div>" +
	        "<div class='col-sm-2 site-wait'><img src='images/spinner.gif' /></div>" +
		"  </div>" +
		"</div>";
	}
	else {
	    _.each(sites, function(siteid) {
		siteIdToSiteNum[siteid] = sitenum;
		var selectID = 'site' + sitenum + '_selector';

		/*
		 * Since we call this multiple times (after constraints change,
		 * when the reservation info come in), lets not change the
		 * selection if the user has already made one. 
		 */
		var selected;
		if ($('#' + selectID).length) {
		    selected = $('#' + selectID + ' option:selected').text();
		}
		var options = createDropdowns(selected);

		html = html +
		    "<div id='site"+sitenum+"cluster' " +
		    "     class='form-horizontal experiment_option'>" +
		    "  <div class='form-group cluster-group'>" +
		    "    <label class='col-sm-4 control-label' name='" + siteid + "' " +
		    "           style='text-align: right;'>"+
		    "          Site " + siteid  + " Cluster:</a>" +
		    "    </label> " +
		    "    <div class='col-sm-6 site-selector'>" +
		    "      <select id='" + selectID + "' " +
		    "              data-siteid='" + siteid + "' " +
		    "              name=\"sites[" + siteid + "]\"" +
		    "              class='form-control select_where'>" +
		    "        <option value=''>Please Select</option>" +
		    options +
		    "      </select>" +
		    "    </div>" +
		    "<div class='col-sm-4'></div>" +
		    "<div class='col-sm-6 alert alert-danger' id='where-nowhere' style='display: none; margin-top: 5px; margin-bottom: 5px'>This site <b>will not work on any clusters</b>. All clusters are unselectable.</div>" +
		    "<div class='col-sm-6 alert alert-warning hidden' id='where-deprecated' style='margin-top: 5px; margin-bottom: 5px'></div>" +
	            "<div class='col-sm-2 site-wait'><img src='images/spinner.gif' /></div>" +
	            "  </div>" +
		    "</div>";
		sitenum++;
	    });
	}
	//console.info(html);

	$("#cluster_selector").html("");
	$("#cluster_selector").html(html);
	updateWhere();  
	$("#cluster_selector").removeClass("hidden");

	// This event will be overriden when the fancy cluster status
	// stuff is initialized.
	$('.select_where').change(function (event) {
	    ClusterSelected(event, false);
	});
    }

    /*
     * Make sure all clusters selected before submit.
     */
    function AllClustersSelected() 
    {
	var allgood = 1;

	$('#cluster_selector').find('select').each(function () {
	    if ($(this).val() == null || $(this).val() == "") {
		allgood = 0;
		return;
	    }
	});
	return allgood;
    }
    // Cluster selection mapping by selector id.
    function ClusterSelections()
    {
	var clusters = {};
	
	$('#cluster_selector').find('select').each(function () {
	    var cluster = $(this).val();
	    var urn     = amValueToKey[cluster];
	    
	    clusters[$(this).data("siteid")] = urn;
	});
	return clusters;
    }

    var constraints;
    var validList;
    var jacksGraph;
    var context;

    function contextReady(data)
    {
      context = data;
      if (typeof(context) === 'string')
      {
	context = JSON.parse(context);
      }
      if (context.canvasOptions.defaults.length === 0)
      {
	delete context.canvasOptions.defaults;
      }
      
      jacks.instance = new window.Jacks({
	mode: 'viewer',
	source: 'rspec',
	root: '#jacks-dummy',
	nodeSelect: true,
	readyCallback: function (input, output) {
	  //jacks.input = input;
	  //jacks.output = output;
	  //jacks.output.on('found-images', onFoundImages);
	  //jacks.output.on('found-types', onFoundTypes);
          constraints = new JACKS_LOADER.Constraints(context);
	  updateWhere();
	},
	canvasOptions: context.canvasOptions,
	constraints: context.constraints
      });
      
      //constraints = new JACKS_LOADER.Constraints(context);
      //updateWhere();
    }

    var foundImages = [];

    function onFoundImages(images)
    {
	if (! doconstraints) {
	    return true;
	}
	if (! _.isEqual(foundImages, images)) {
	    foundImages = images;

	    UpdateImageConstraints();
	}
	return true;
    }

    function onFoundTypes(t) 
    {
	//console.info("onFoundTypes", t);
	types = {};
	hardware = {};
	_.each(t, function(item) {
	    types[item.name] = item.types;
	    hardware[item.name] = item.hardware;
	});
    }

    /*
     * Update the image constraints if anything changes.
     */
    function UpdateImageConstraints() {
	if (!foundImages.length || !doconstraints) {
	    return;
	}
      
	$('#stepsContainer .actions a[href="#finish"]').attr('disabled', true);
	var callback = function(json) {
	    if (json.code) {
		alert("Could not get image info: " + json.value);
		return;
	    }
	    // This gets munged someplace, and so the printed value
	    // is not what actually comes back. Copy before print.
	    var mycopy = $.extend(true, {}, json.value);
	    //console.log('json', mycopy);
	    updateDeprecated(json.value[0].images)
	    if (!window.CLUSTERSELECT) {
		showDeprecated($('#nocluster-selector'));
	    }
	    constraints = new JACKS_LOADER.Constraints(context);
	    constraints.addPossibles({ images: foundImages });
	    allowWithSites(json.value[0].images, json.value[0].constraints);
	    CreateAggregateSelectors(selected_rspec);
	    ShowClusterReservations();
	    $('#stepsContainer .actions a[href="#finish"]')
		.removeAttr('disabled');
	};
	/*
	 * Must pass the selected project along for constraint checking.
	 */
	var $xmlthing =
	    sup.CallServerMethod(ajaxurl,
				 "instantiate", "GetImageInfo",
				 {"images"  : foundImages,
				  "project" : $('#project_selector #profile_pid')
						  .val()});
	$xmlthing.done(callback);
	return true;
    }

    // Show the deprecated warnings in the proper cluster selector div.
    function showDeprecated(domNode)
    {
	//console.info("showDeprecated:", domNode, deprecatedList);
	if (deprecatedList.length === 0) {
	    domNode.find('#where-deprecated').hide();
	}
	else {
	    var current = domNode.find('#where-deprecated');
	    current.html('');
	    _.each(deprecatedList, function (item) {
		var errorMessage = '';
		if (item.deprecated_iserror) {
		    errorMessage = ': Using this image will cause your ' +
			'experiment to fail.';
		}
		current.append('<p>Image ' + sup.ImageDisplay(item.id) +
			       ' is deprecated: ' + item.deprecated_message +
			       errorMessage + '</p>');
	    });
	    current.removeClass("hidden");
	}
    }

  function updateDeprecated(images)
  {
    deprecatedList = [];
    _.each(images, function (image) {
      if (image.deprecated)
      {
	deprecatedList.push(image);
      }
    });
  }
  
  function allowWithSites(newImages, newConstraints)
  {
    console.log('newImages', newImages);
    console.log('newConstraints', newConstraints);
    var sites = context.canvasOptions.site_info;
    var finalItems = [];
    _.each(newConstraints, function (item) {
      console.log('item:', item);
      var valid = [];
      _.each(_.keys(sites), function (key) {
	// Items from server might just be comma-separated lists in
	// strings instead of split out properly. Let's split them out
	// here.
	item.node.hardware = splitItems(item.node.hardware);
	item.node.types = splitItems(item.node.types);

	// The image list returned are the only valid images
	if (_.findWhere(newImages, { id: item.node.images[0] }))
	{
	  _.each(item.node.hardware, function (hardware) {
	    if (_.contains(sites[key].hardware, hardware))
	    {
	      finalItems.push({
		node: {
		  hardware: [hardware],
		  images: item.node.images,
		  aggregates: [key]
		}
	      });
	    }
	  });
	  _.each(item.node.types, function (type) {
	    if (_.contains(sites[key].types, type))
	    {
	      finalItems.push({
		node: {
		  types: [type],
		  images: item.node.images,
		  aggregates: [key]
		}
	      });
	    }
	  });
	}
      });
    });
    //console.log(finalItems);
    constraints.allowAllSets(finalItems);
    constraints.allowAllSets([
      {
	node: {
	  aggregates: ['!'],
	  images: ['!'],
	  hardware: ['!']
	}
      },
      {
	node: {
	  aggregates: ['!'],
	  images: ['!'],
	  types: ['!']
	}
      },
    ]);
  }

  function splitItems(list) {
    var result = [];
    _.each(list, function (item) {
      result = result.concat(item.split(','));
    });
    return result;
  }

    function contextFail(fail1, fail2)
    {
	console.log('Failed to fetch context', fail1, fail2);
	alert('Failed to fetch context from ' + contextUrl + '\n\n' + 'Check your network connection and try again or contact testbed support with this message and the URL of this webpage.');
    }

    function updateJacksGraph(newGraph)
    {
      jacksGraph = newGraph;
      validList = new JACKS_LOADER.ValidList(jacksGraph, constraints);
      var images = [];
      _.each(newGraph.nodes, function (node) {
	if (node.image)
	{
	  images = _.union(images, [node.image]);
	}
      }.bind(this));
      onFoundImages(images);
      //console.log('updateJacksGraph');
      updateWhere();
    }

    function updateWhere()
    {
	// Temporary
	if (!window.MAINSITE) {
	    return;
	}
	if (!doconstraints) {
	    CreateClusterStatus();
	    return;
	}
	//console.info("updateWhere");
	
	//if (jacks.input && constraints && selected_rspec)
	//{
	//  jacks.input.trigger('change-topology',
	//		      [{ rspec: selected_rspec }],
	//		      { constrainedFields: finishUpdateWhere });
      //}
      if (jacksGraph && validList && constraints)
      {
	finishUpdateWhere(validList.getNodeCandidates(true),
			  validList.getNodeCandidatesBySite(true));
	$('.site-wait').hide();
	$('.site-selector').show();
      }
      else
      {
      	$('.site-wait').show();
	$('.site-selector').hide();
      }
    }

    function finishUpdateWhere(allNodes, nodesBySite)
    {
        //console.log('finishUpdateWhere');
	if (!multisite || Object.keys(sites).length <= 1) {
	    updateSiteConstraints(allNodes,
				  $('#cluster_selector .cluster-group'));
	}
	else {
	    _.each(_.keys(sites), function (siteId) {
		var nodes   = nodesBySite[siteId];
		var sitenum = siteIdToSiteNum[siteId];
		var domid   = '#cluster_selector #site' + sitenum + 'cluster' +
		    ' .cluster-group';
		if (nodes) {
		    updateSiteConstraints(nodes, $(domid));
		}
		else {
		    console.log('Could not find siteId', siteId, nodesBySite);
		}
	    })
	}

	// Moved here to deal with race condition of custer status
      // getting built before constraints were finished running
        if ($('#profile_pid').val() != $('#profile_pid_picker .dropdown-toggle .value').html()) {
	    $($('#profile_pid_picker .dropdown-menu a')[0]).click();
        }
	CreateClusterStatus();
    }

    function updateSiteConstraints(nodes, domNode)
    {
	if (1) {
	    return 0;
	}
      var allowed = [];
      var rejected = [];
      var breakdown = {};
      var bound = nodes;
      var subclause = 'node';
      var clause = 'aggregates';
      allowed = constraints.getValidList(bound, subclause,
					 clause, rejected,
					 breakdown);
      if (0) {
        console.info('REJECT BREAKDOWN', breakdown);
        console.info('POSSIBLES', constraints.possible);
        console.info('GROUPS', constraints.groups);
	console.info("updateSiteConstraints");
	console.info("domNode:", domNode);
	console.info("bound:", bound);
	console.info("allowed", allowed);
	console.info("rejected", rejected);
      }
	
      updateBreakdown(domNode.find('#nowhere-breakdown'), breakdown);
      if (allowed.length == 0)
      {
	domNode.find('#where-warning').hide();
	domNode.find('#where-nowhere').show();
      }
      else if (rejected.length > 0)
      {
	domNode.find('#where-warning').show();
	domNode.find('#where-nowhere').hide();
      }
      else
      {
	domNode.find('#where-warning').hide();
	domNode.find('#where-nowhere').hide();
      }
      showDeprecated(domNode);
      domNode.find('select').children().each(function () {
	var value = $(this).attr('value');
	// Skip the Please Select option
	if (value == "") {
	    return;
	}
	var key = amValueToKey[value];
	var i = 0;
	var found = false;
	for (; i < allowed.length; i += 1)
	{
	  if (allowed[i] === key)
	  {
	    found = true;
	    break;
	  }
	}
	if (found || isadmin || window.ISSTUD || window.ISPOWDER)
	{
	  $(this).prop('disabled', false);
	  if (allowed.length == 1 ||
	      (window.ISPOWDER && value == "Emulab")) {
	      $(this).attr('selected', "selected");
	      // This does not appear to do anything, at least in Chrome
	      $(this).prop('selected', true);
	  }
	}
	else
	{
	  $(this).prop('disabled', true);
	  $(this).removeAttr('selected');
	  // See above comment.
	  $(this).prop('selected', false);
	}
      });
    }

    function updateBreakdown(dom, breakdown)
    {
      var list = $('<ul class="list-group"></ul>');
      _.each(breakdown, function (site, key) {
	var choices = $('<ul style="margin-left: 20px"></ul>');
	var chosen = {};
	_.each(site, function (candidate) {
	  delete candidate.node.aggregates;
	  var unique = JSON.stringify(candidate.node, undefined, "");
	  if (chosen[unique] === undefined)
	  {
	    chosen[unique] = 1;
	    var line = $('<li></li>');
	    var found = 0;
	    if (candidate.node.hardware !== undefined)
	    {
	      line.append('Hardware <b>' +
			  candidate.node.hardware + '</b>');
	      ++found;
	    }
	    if (candidate.node.types !== undefined)
	    {
	      if (found == 1)
	      {
		line.append(' with ');
	      }
	      line.append('Type <b>' +
			  candidate.node.types + '</b>');
	      ++found
	    }
	    if (candidate.node.images !== undefined)
	    {
	      if (found == 1)
	      {
		line.append(' with ');
	      }
	      else if (found == 2)
	      {
		line.append(' and ');
	      }
	      line.append('Image <b>' +
			  sup.ImageDisplay(candidate.node.images) + '</b>');
	    }
	    choices.append(line);
	  }
	});
	list.append($('<li class="list-group-item">Site <b>' + amlist[key] + 
		      '</b> cannot instantiate </li>').append(choices));
      });
      dom.html(list);
    }
  
    // When the project is changed, look to see if the new project includes
    // multiple subgroups. If only one subgroup, hide the group selector.
    // Otherwise build/show a group selector.
    function UpdateGroupSelector()
    {
	var pid = $('#project_selector #profile_pid').val();
	var glist = projlist[pid];
	console.info(pid, glist);

	if (glist.length == 1) {
	    var gid = glist[0];
	    // No need to show it.
	    $('#group_selector').addClass("hidden");

	    // But need to add an option so we can select it for submit.
	    var html = "<option selected value=" + gid + ">" + gid + "</option>";
	    $('#group_selector #profile_gid').html(html);
	    $('#group_selector #profile_gid').val(gid);
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
		"<option " + selected + " value=" + gid + ">" + gid + "</option>";
	});
	$('#group_selector #profile_gid').html(html);
	$('#group_selector').removeClass("hidden");
    }

    function LoadReservationInfo()
    {
	var callback = function(json) {
	    if (json.code) {
		console.info("Could not get reservation info: " + json.value);
		return;
	    }
	    console.info("resinfo", json.value);
	    resinfo = json.value;
	    
	    ShowClusterReservations();
	};
	var xmlthing =
	    sup.CallServerMethod(null, "reserve", "ReservationInfo", null);
	xmlthing.done(callback);
    }

    // Google Analytics.
    function PickerEvent(action, selected, value)
    {
	if (window.GOOGLEUA === undefined) {
	    return;
	}
	var id = "default";
	if (value === undefined) {
	    value = 0;
	}
	if (action == "scroll") {
	    id = selected.toString();
	    value = selected;
	}
	else if (selected !== undefined) {
	    var info = profilelist[selected.attr('value')];
	    if (info === undefined) {
		// Not sure why this happens
		return;
	    }
	    id = info.pid + "," + info.name;
	}
	//console.info("picker event", action, id, value);
	ga('send', 'event', 'picker', action, id, value);
    }

    function ClusterSelected(selected, pickered)
    {
	var cluster = null;

	/*
	 * Dig out which cluster has been selected. Depending on whether
	 * it came from the plain drop down or the pickered dropdown.
	 */
	if (pickered) {
	    cluster = $(selected).attr("value");
	}
	else {
	    cluster = $(selected.target).find(":selected").val()
	}
	//console.info("ClusterSelected: " + cluster);
    }

    /*
     * When the date selected is today, need to disable the hours
     * before the current hour.
     */
    function DateChange(which)
    {
	var date = $("#step3-form " + which).datepicker("getDate");
	var now = new Date();

	if (which == "#start_day" || which == "#end_day") {
	    var selecter;
	    if (which == "#start_day") {
		selecter = "#step3-form #start_hour";
	    }
	    else {
		selecter = "#step3-form #end_hour";
	    }
	    console.info(moment(date), moment(now));

	    /*
	     * Enable all hours,
	     */
	    for (var i = 0; i <= 24; i++) {
		$(selecter + " option[value='" + i + "']")
		    .removeAttr("disabled");
	    }
	    // Zero out the current choice.
	    $(selecter).val("");

	    // If today, cannot select anything before the current time.
	    if (date == null || moment(date).isSame(moment(now), "day")) {
		for (var i = 0; i <= now.getHours(); i++) {
		    $(selecter + " option[value='" + i + "']")
			.attr("disabled", "disabled");
		}
	    }
	    console.info("bar", maxEndDate);
	    // If there is a max duration set and is equal to the
	    // selected day, must disable everything after the max
	    // hour.
	    if (which == "#end_day" && maxEndDate &&
		moment(date).isSame(moment(maxEndDate), "day")) {
		console.info("foo");

		for (var i = maxEndDate.getHours() + 1; i < 24; i++) {
		    $(selecter + " option[value='" + i + "']")
			.attr("disabled", "disabled");
		}
	    }
	}
	if (1) {
	if (window.ISPOWDER &&
	    (which == "#start_day" || which == "#start_hour")) {
	    if (isadmin || window.USENEWSCHEDULE) {
		/*
		 * The powder portal gets a termination datepicker. Whenever
		 * the start time is changed, recalc the maximum allowed
		 * duration and modify the termination accordingly. Also need
		 * to do this when the project changes.
		 */
		UpdateMaxDuration();
	    }
	    else if ($("#start_day").datepicker("getDate") &&
		     $('#start_hour').val()) {
		var mindate = $("#start_day").datepicker("getDate");
		mindate.setHours($('#start_hour').val());
		var maxdate = new Date(mindate.getTime());
		maxdate.setHours(maxdate.getHours() + window.MAXDURATION);
	    
		console.info(mindate, maxdate);
		$("#end_day").datepicker("option", "minDate", mindate);
		$("#end_day").datepicker("setDate", mindate);
		$("#end_day").datepicker("option", "maxDate", maxdate);
		$("#end_day").datepicker("refresh");
		$("#end_hour").val(maxdate.getHours());
	    }
	}
	}
    }

    /*
     * Ask for the max duration of this experiment, based on reservations
     * approved, to the project selected and the current start date/time
     * in the picker. Any time the project or the start time changes, we
     * update the end date.
     */
    function UpdateMaxDuration()
    {
	var start_day  = $('#step3-form [name=start_day]').val();
	var start_hour = $('#step3-form [name=start_hour]').val();

	console.info("UpdateMaxDuration", start_day, start_hour);
	$('#doesnotfit-warning').addClass("hidden");

	// Only if start time properly set.
	if (! ((start_day && start_hour) || (!start_day && !start_hour))) {
	    return;
	}
	// Current form contents as formfields array.
	var formfields = SerializeForm();

	// Update pickers.
	var callback = function (json) {
	    console.info(json);
	    if (json.code) {
		console.info("UpdateMaxDuration: " . json.value);
		return;
	    }
	    // Saved globally for above
	    var maxdate = json.value;
	    var mindate = $("#start_day").datepicker("getDate");

	    if (!maxdate) {
		if (start_day) {
		    $('#doesnotfit-warning-now').addClass("hidden");
		    $('#doesnotfit-warning-datetime').removeClass("hidden");
		}
		else {
		    $('#doesnotfit-warning-now').removeClass("hidden");
		    $('#doesnotfit-warning-datetime').addClass("hidden");
		}
		$('#bestguess-info').addClass("hidden");
		$('#doesnotfit-warning').removeClass("hidden");
		return;
	    }
	    else {
		$('#doesnotfit-warning').addClass("hidden");
		$('#bestguess-info').removeClass("hidden");
	    }
	    if (!mindate) {
		mindate = new Date();
	    }
	    maxdate = maxEndDate = new Date(maxdate);
	    console.info("UpdateMaxDuration: ", mindate, maxdate);
	    
	    $("#end_day").datepicker("option", "minDate", mindate);
	    $("#end_day").datepicker("option", "maxDate", maxdate);
	    $("#end_day").datepicker("setDate", maxdate);
	    $("#end_day").datepicker("refresh");

	    /*
	     * Enable all hours,
	     */
	    for (var i = 0; i <= 24; i++) {
		$("#end_hour option[value='" + i + "']")
		    .removeAttr("disabled");
	    }
	    /*
	     * If today, disable all hours up to current.
	     */
	    if (moment(maxdate).isSame(Date.now(), "day")) {
		var now = new Date();
		
		for (var i = 0; i <= now.getHours(); i++) {
		    $("#end_hour option[value='" + i + "']")
			.attr("disabled", "disabled");
		}
	    }
	    /*
	     * Disable all hours in the selector beyond the max hour.
	     */
	    for (var i = maxdate.getHours() + 1; i < 24; i++) {
		/*
		 * Before we disable the option, see if it is selected.
		 * If so, we want to make the user re-select the hour.
		 */
		if ($("#end_hour option:selected").val() == i) {
		    $("#end_hour").val("");
		}
		$("#end_hour option[value='" + i + "']")
		    .attr("disabled", "disabled");
	    }
	    /*
	     * And select the max hour for the user.
	     */
	    $("#end_hour").val(maxdate.getHours());
	};
	var args = {"formfields" : formfields,
		    "rspec"      : selected_rspec};
	// Hopefully the prediction info has returned in time.
	if (resinfo) {
	    // Prediction info comes back with pid lowercase cause of
	    // HRN normalization rules.
	    var pid = $('#profile_pid').val().toLowerCase();
	    var forecasts = {};
	    _.each(resinfo, function (info, urn) {
		console.info(urn, info);
		// Ick.
		if (!_.has(info, "pforecasts")) {
		    return;
		}
		forecasts[urn] = {};
		forecasts[urn]["forecast"] = info["pforecasts"][pid];
	    });
	    args["prediction"] = JSON.stringify(forecasts);
	}
	console.info("UpdateMaxDuration args:", args);
	var xmlthing = sup.CallServerMethod(null, "instantiate",
					    "MaxDuration", args);
	xmlthing.done(callback);
    }
    

    /*
     * Handle License requirements.
     */
    function HandleLicenseRequirements(licenses)
    {
	var html = "";

	_.each(licenses, function (details) {
	    var dt = null;

	    if (details.type == "node") {
		dt = "Node " + details.target;
	    }
	    else if (details.type == "type") {
		dt = "Node Type " + details.target;
	    }
	    else if (details.type == "aggregate") {
		dt = "Resource " + details.target;
	    }
	    html = html +
		"<dt>" + dt + "</dt>" +
		"<dd><pre>" + details.description_text + "</pre></dd>";
	});
	$('#request-licenses-modal dl').html(html);
	
	$('#request-license-button').click(function (event) {
	    sup.HideModal('#request-licenses-modal');
	    sup.CallServerMethod(null, "instantiate", "RequestLicenses",
				 {"licenses" : JSON.stringify(licenses)},
				 function (json) {
				     if (json.code) {
					 alert("Could not request resource " +
					       "access: " + json.value);
					 return;
				     }
				     window.location
					 .replace("licenses-pending.php");
				 });
	});
	sup.ShowModal('#request-licenses-modal', function () {
	    $('#request-license-button').off("click");
	});
    }

    /*
     * Check for radio usage and no spectrum defined
     */
    function CheckForRadioUsage()
    {
	var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
	var xmlDoc    = $.parseXML(selected_rspec);
	var spectrum  = xmlDoc.getElementsByTagNameNS(EMULAB_NS, 'spectrum');

	console.info("CheckForRadioUsage");

	// In case user changes profile late.
	usingRadios = false;

	if (radioinfo) {
	    var usingTransmitter = false;
	    
	    /*
	     * Check for radio usage, alert the user that using radios
	     * without a spectrum specification is bad news.
	     */
	    $(xmlDoc).find("node").each(function() {
		// Gotta have a manager to know anything.
		var manager_urn = $(this).attr("component_manager_id");
		if (!manager_urn) {
		    return;
		}
		// Ditto the component ID
		var component_id = $(this).attr("component_id");
		if (!component_id) {
		    return;
		}
		// Might be a urn.
		var hrn = sup.ParseURN(component_id);
		if (hrn) {
		    component_id = hrn.id;
		}
		//console.info("CheckForRadioUsage", manager_urn, component_id);
		
		if (_.has(radioinfo, manager_urn) &&
		    _.has(radioinfo[manager_urn], component_id)) {
		    usingRadios = true;
		    var radio = radioinfo[manager_urn][component_id];

		    if (_.has(radio, "frontends")) {
			_.each(radio.frontends, function (frontend, iface) {
			    if (frontend.transmit_frequencies != "") {
				usingTransmitter = true;
			    }
			});
		    }
		}
	    });
	    if (usingTransmitter && !spectrum.length) {
		sup.ShowModal('#nospectrum-warning');
	    }
	}
    }
     
    /*
     * Check for spectrum used.
     */
    function CheckForSpectrum()
    {
	var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
	var xmlDoc    = $.parseXML(selected_rspec);
	var spectrum  = xmlDoc.getElementsByTagNameNS(EMULAB_NS, 'spectrum');
	var win;

	console.info("CheckForSpectrum", spectrum);

	/*
	 * Kirk requested that we do not predicate this on using spectrum
	 * but always on the Powder portal.
	 */
	if (!window.ISPOWDER) {
            $('#step3-div .reserve-resources-button').off("click");
            $('#step3-div .schedule-experiment').removeClass("hidden");
            $('#step3-div .reserve-resources').addClass("hidden");
            $('#groups-div').addClass("hidden");
            $('#groups').html("");
	    return;
	}
	// But if not using radios, different warning text, it worries people.
	if (usingRadios) {
	    $('#step3-div .reserve-resources .radio-warning')
		.removeClass("hidden");
	    $('#step3-div .reserve-resources .noradio-warning')
		.addClass("hidden");
	}
	else {
	    $('#step3-div .reserve-resources .radio-warning')
		.addClass("hidden");
	    $('#step3-div .reserve-resources .noradio-warning')
		.removeClass("hidden");
	}

	/*
	 * Helper functions
	 */
	var setPickers = function(start, end) {
	    var start = moment(start);
	    var end = moment(end);

	    // If the reservation group starts in the past, do not set
	    // a start time.
	    if (! start.isBefore()) {
		$('#start_day').val(start.format("MM/DD/YYYY"));
		$('#start_hour').val(start.format("H"));
		$("#start_hour option[value='" + start.hour() + "']")
		    .removeAttr("disabled");
	    }
	    else {
		$('#start_day').val("");
		$('#start_hour').val("");
	    }
	    $('#end_day').val(end.format("MM/DD/YYYY"));
	    $('#end_hour').val(end.format("H"));
	    $("#end_hour option[value='" + end.hour() + "']")
		.removeAttr("disabled");
	};
	var clearPickers = function() {
	    // Set the pickers.
	    $('#start_day').val("");
	    $('#start_hour').val("");
	    $('#end_day').val("");
	    $('#end_hour').val("");
		    
	    // These are in the form.
	    $('#step3-form [name=start]').val("");
	    $('#step3-form [name=end]').val("");

	    // Clear checkboxes to make sure there is no confusion.
	    $(".select-reservation")
		.each(function(){ this.checked = false; });
	};

	/*
	 * For resgroup list, we bind a click handler to copy the
	 * start/end into the pickers.
	 */
	var setupCheckboxes = function (resgroups, uuid) {
	    $(".select-reservation").change(function (event) {
		if ($(this).is(":checked")) {
		    // Uncheck other boxes.
		    $(".select-reservation")
			.each(function(){ this.checked = false; });
		    $(this).prop("checked", true);

		    var uuid  = $(this).val();
		    var group = resgroups[uuid];
		    console.info("setupCheckboxes", uuid, group);
		    setPickers(group.start, group.end);
		}
		else {
		    clearPickers();
		}
	    });
	    // Tooltip for the checkboxes.
	    $(".select-reservation").tooltip({
		"container" : "body",
		"trigger"   : "hover",
		"title"     : "Click to copy the start/end time for this " +
		    "reservation, to the start/end inputs above",
	    });
	    
	    // Check this reservation.
	    if (uuid) {
		$('#groups input[type=checkbox][value=' + uuid + ']')
		    .prop("checked", true);
	    }
	}
	/*
	 * Check for existing reservations and draw the list.
	 */
	var showResgroupList = function (uuid) {
	    sup.CallServerMethod(null, "resgroup", "ListReservationGroups",
				 {"project" : $('#profile_pid').val()},
				 function (json) {
				     if (json.code) {
					 console.info(json.value);
					 return;
				     }
				     var groups = json.value;
				     if (_.size(groups)) {
					 $('#groups-div').removeClass("hidden");
					 window.DrawResGroupList('#groups-div',
								 groups);
					 setupCheckboxes(json.value, uuid);
				     }
				     else {
					 $('#groups-div').addClass("hidden");
				     }
				 });
	}
	showResgroupList();
	
	/*
	 * We hide the normal scheduling controls and show a list of
	 * reservations the user can select from for scheduling the
	 * experiment. I think this is going to be very confusing.
	 */
	$('#step3-div .schedule-experiment').addClass("hidden");
	$('#step3-div .reserve-resources').removeClass("hidden");

	/*
	 * Wait for user to decide to create a new reservation.
	 */
	$('#step3-div .reserve-resources-button').click(function (event) {
	    event.preventDefault();
	    if ($('#reservation-iframe').length) {
		return;
	    }
	    
	    /*
	     * Hide steps control buttons until the iframe is closed.
	     */
	    $('#stepsContainer .actions').addClass("hidden");

	    /*
	     * Clear the pickers and the checkboxes.
	     */
	    clearPickers();

	    /*
	     * Place into an iframe in the panel body,
	     */
	    var url  = "resgroup.php?fromrspec=1&embedded=1" +
		"&project=" + $('#profile_pid').val();
	
	    var html = '<iframe id="reservation-iframe" class=col-xs-12 ' +
		'style="padding-left: 0px; padding-right: 0px; border: 0px;" ' +
		'height=1200 ' + 'src=\'' + url + '\'>';
	
	    $('#step3-div .resgroup-div').removeClass("hidden");
	    $('#step3-div .resgroup-div .panel-body').html(html);

	    var iframe = $('#reservation-iframe')[0];
	    var iframewindow = (iframe.contentWindow ?
				iframe.contentWindow :
				iframe.contentDocument.defaultView);

	    iframewindow.addEventListener('DOMContentLoaded', function (event) {
		var html =
		    "<div id=rspec class=hidden>" +
		    "  <textarea type='textarea'>" +
		        selected_rspec + "</textarea>" +
		    "</div>" +
		    "<script type='text/plain' id='cluster-selections'>" +
		       JSON.stringify(ClusterSelections()) +
		    "</script>";
		$("body", iframewindow.document).append(html);
		$("#wrap", iframewindow.document).css("padding", "0px");
	    });

	    // Slow timer to expand the iframe so no scroll bar.
	    var timer = setInterval(function() {
		var doc    = iframewindow.document;
		var height = $("#main-body", doc).css("height");
		var now    = $('#reservation-iframe').css("height");
		if (height != now) {
		    console.info("height", height);
		    $('#reservation-iframe').css("height", height);
		}
	    }, 250);

	    // Helper
	    var closeIframe = function () {
		$('#cancel-reserve-resources-button').off("click");
		$('#reservation-iframe').remove();
		$('#step3-div .resgroup-div').addClass("hidden");
		
		// Show the steps control buttons,
		$('#stepsContainer .actions').removeClass("hidden");
	    };

	    // Cancel operation.
	    $('#cancel-reserve-resources-button').click(function (event) {
		event.preventDefault();
		clearInterval(timer);
		closeIframe();
	    })

	    // Call back after getting the new reservation
	    var gotres_callback = function (json) {
		console.info("gotres_callback", json);
		if (json.code) {
		    sup.HideModal('#waitwait-modal', function () {
			alert("Could not get new reservation info");
		    });
		    return;
		}
		setPickers(json.value.start, json.value.end);
	    };
	    
	    /*
	     * An iframe cannot close itself, but it can call a function
	     * here cause its in the same domain.
	     */
	    window.CloseMyIframe = function (uuid) {
		console.info("Reservation is done", uuid);
		clearInterval(timer);

		if (uuid) {
		    // Look for updated rspec.
		    var rspec = $("#rspec textarea",
				  iframewindow.document).val();

		    if (rspec != selected_rspec) {
			console.info("RSpec changed", rspec);
			$('#rspec_textarea').val(rspec);
			selected_rspec = rspec;
		    }
		    // Redraw the list.
		    showResgroupList(uuid);
		    // Ask for the reservation info so we can set start/end.
		    sup.CallServerMethod(null, "resgroup",
					 "GetReservationGroup",
					 {"uuid"    : uuid},
					 gotres_callback);
		}
		else {
		    console.info("Did not get a uuid from iframe");
		}
		closeIframe();
		return;
	    };
	});
    }
    
    /*
     * Try to select the clusters for the user based on the node types.
     * This might not be possible, if there is a conflict in the types.
     * Do what we can.
     */
    function SetClusters(rspec)
    {
	var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
	var xmlDoc    = $.parseXML(rspec);
	var changed   = false;

	if (0) {
	    return rspec;
	}

	//console.info("SetClusters", rspec);

	// Find all the nodes, look for types nodes
	$(xmlDoc).find("node").each(function() {
	    var node         = this;
	    var node_id      = $(this).attr("client_id");
	    var htype        = $(node).find("hardware_type");
	    var manager_id   = $(node).attr("component_manager_id");

	    // Skip anything with the manager already set.
	    if (manager_id) {
		return;
	    }
	    // Otherwise, we dig inside and find the hardware type.
	    if (!htype) {
		return;
	    }
	    var type = $(htype).attr("name");
	    console.info("SetClusters", node_id, type);
	    
	    /*
	     * Find the cluster that has this type.
	     * Watch for same type at more then one cluster and bail.
	     */
	    var found = 0;
	    
	    _.each(amlist, function (details, urn) {
		if (_.has(details.typeinfo, type)) {
		    console.info("SetClusters", node_id, type, urn);
		    manager_id = urn;
		    found++;
		}
	    })
	    if (found == 1) {
		$(node).attr("component_manager_id", manager_id);
		changed = true;
	    }
	});
	if (changed) {
	    rspec = (new XMLSerializer()).serializeToString(xmlDoc);
	}
	//console.info("SetClusters done", rspec);
	return rspec;
    }

    $(document).ready(initialize);
});
