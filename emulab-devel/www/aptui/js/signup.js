$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['about-account', 'verify-modal', 'signup-personal', 'signup-project', 'signup', 'toomany-modal']);
    var aboutTemplate = _.template(templates['about-account']);
    var verifyTemplate = _.template(templates['verify-modal']);
    var personalTemplate = _.template(templates['signup-personal']);
    var projectTemplate = _.template(templates['signup-project']);
    var signupTemplate = _.template(templates['signup']);
    var affiliations = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	$('#toomany_div').html(templates['toomany-modal']);

	var fields = JSON.parse(_.unescape($('#form-json')[0].textContent));
	var errors = JSON.parse(_.unescape($('#error-json')[0].textContent));
	var licenses = JSON.parse(_.unescape($('#licenses-json')[0].textContent));
	console.info(fields);
	console.info(errors);

	// Need the affiliation list before the form can be rendered.
	$.getJSON("affiliations/us.json")
	    .done(function (data) {
		affiliations = data;

		renderForm(fields, errors, licenses,
			   window.APT_OPTIONS.joinproject,
			   window.APT_OPTIONS.ShowVerifyModal,
			   window.APT_OPTIONS.this_user,
			   (window.APT_OPTIONS.this_user ?
			    window.APT_OPTIONS.promoting : false));

		if (window.APT_OPTIONS.toomany) {
		    sup.ShowModal('#toomany_modal');
		}
	    })
	    .fail(function() {
		alert("Could not get data file: " + window.URL);
	    });
    }

    function renderForm(formfields, errors, licenses, joinproject, showVerify,
			thisUser, promoting)
    {
	var buttonLabel = "Submit Request";
	var pageTitle   = (joinproject ?
			   "Request to join a project" :
			   "Request to start a project");
	
	var about = aboutTemplate({});
	var verify = verifyTemplate({
	    id: 'verify_modal',
	    label: buttonLabel,
	    title: pageTitle
	});
	var personal_html = personalTemplate({
	    formfields: formfields,
	    promoting: promoting
	});
	var project_html = projectTemplate({
	    joinproject: joinproject,
	    formfields: formfields,
	    licenses: licenses,
	});
	var signup = signupTemplate({
	    button_label: buttonLabel,
	    pagetitle: pageTitle,
	    general_error: (errors.error || ''),
	    about_account: (window.ISAPT && !thisUser ? about : null),
	    this_user: thisUser,
	    promoting: promoting,
	    joinproject: joinproject,
	    verify_modal: verify,
	    pubkey: formfields.pubkey,
	    personal_fields: personal_html,
	    project_fields: project_html,
	});
	$('#signup-body').html(aptforms.FormatFormFields(signup));
	aptforms.GenerateFormErrors('#quickvm_signup_form', errors);
	if (showVerify)
	{
	    sup.ShowModal('#verify_modal');
	}
	$('#signup_countries').bfhcountries({ country: formfields.country,
					      blank: false, ask: true });
	$('#signup_states').bfhstates({ country: 'signup_countries',
					state: formfields.state,
					blank: false, ask: true });

	$("#signup_affiliation").autocomplete({
	    source: affiliations
	});

	// When the country changes, change the list of affilations.
	$('#signup_countries').change(function (event) {
	    var country = $(this).val().toLowerCase();
	    
	    $.getJSON("affiliations/" + country + ".json")
		.done(function (data) {
		    affiliations = data;
		    
		    $("#signup_affiliation")
			.autocomplete("option", "source", data);
		})
		.fail(function() {
		    console.info("Could not get data file for " + country);
		});
	});

	/*
	 * When switching from start to join, show the hidden fields
	 * and change the button.
	 */
	$("input[id='startorjoin']").change(function(e){
	    if ($(this).val() == "join") {
		$('#start_project_rollup').addClass("hidden");
		$('#submit_button').text("Submit Request");
		$('#signup_panel_title').text("Request to join a project");
	    }
	    else {
		$('#start_project_rollup').removeClass("hidden");
		$('#submit_button').text("Submit Request");
		$('#signup_panel_title').text("Request to start a project");
	    }
	});

	/*
	 * Handler for the NSF checkbox; show/hide award input
	 */
	$("input[id='nsf-checkbox']").change(function(e) {
	    if ($(this).is(":checked")) {
		$('#nsf-awards-input').removeClass("hidden");
	    }
	    else {
		$('#nsf-awards-input').addClass("hidden");
	    }
	});
	
	aptforms.EnableUnsavedWarning('#quickvm_signup_form');
	
	// Handle submit button.
	$('#submit_button').click(function (event) {
	    aptforms.DisableUnsavedWarning('#quickvm_signup_form');
	});
	if (showVerify) {
	    $('#verify_modal_submit').click(function (event) {
		aptforms.DisableUnsavedWarning('#quickvm_signup_form');
	    });
	}
	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	});
    }
    
    $(document).ready(initialize);
});
