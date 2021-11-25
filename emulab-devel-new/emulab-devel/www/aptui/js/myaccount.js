$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['myaccount', 'verify-modal', 'oops-modal', 'waitwait-modal']);
    var myaccountString = templates['myaccount'];
    var verifyString = templates['verify-modal'];
    var oopsString = templates['oops-modal'];
    var waitwaitString = templates['waitwait-modal'];
    var myaccountTemplate = _.template(myaccountString);
    var verifyTemplate    = _.template(verifyString);
    var affiliations = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	// Initial form contents.
	var fields = JSON.parse(_.unescape($('#form-json')[0].textContent));

	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);	

	// Watch for USA
	if (fields.country === "USA") {
	    fields.country = "US";
	}

	// Need the affiliation list before the form can be rendered.
	$.getJSON("affiliations/us.json")
	    .done(function (data) {
		affiliations = data;
		renderForm(fields, null);
	    })
	    .fail(function() {
		alert("Could not get data file: " + window.URL);
	    });
    }

    function renderForm(formfields)
    {
	var verify = verifyTemplate({
	    id: 'verify_modal',
	    label: "Confirm",
	});
	var myaccount = aptforms.FormatFormFields(myaccountTemplate({
	    formfields: formfields,
	    verify_modal: verify,
	}));
	
	$('#page-body').html(myaccount);
	$('#signup_countries').bfhcountries({ country: formfields.country,
					      blank: false, ask: true });
	$('#signup_states').bfhstates({ country: 'signup_countries',
					state: formfields.state,
					blank: false, ask: true });

	$("#affiliation").autocomplete({
	    source: affiliations
	});

	// When the country changes, change the list of affilations.
	$('#signup_countries').change(function (event) {
	    var country = $(this).val().toLowerCase();
	    
	    $.getJSON("affiliations/" + country + ".json")
		.done(function (data) {
		    affiliations = data;
		    
		    $("#affiliation").autocomplete("option", "source", data);
		})
		.fail(function() {
		    console.info("Could not get data file for " + country);
		});
	});
	
	aptforms.EnableUnsavedWarning('#myaccount_form', function () {
	    if (window.NEEDUPDATE && window.UPDATE == "affiliation") {
		if (window.MATCHED) {
		    $('#submit_button').html("Update");
		}
	    }
	    $('#submit_button')
		.removeAttr("disabled");
	});
	$('#submit_button').click(function (event) {
	    event.preventDefault();
	    SubmitForm();
	    return false;
	});
	$('#verify_modal_submit').click(function (event) {
	    event.preventDefault();
	    sup.HideModal('#verify_modal');
	    SubmitForm();
	    return false;
	});
	if (window.NEEDUPDATE) {
	    if (window.UPDATE == "affiliation") {
		if (!window.MATCHED) {
		    // Clear it from the form so the user is forced to enter.
		    $("#affiliation").val("");
		    // Make it easier for user to notice what needs to change.
		    $("#affiliation").closest(".form-group")
			.addClass("has-error");
		    $('#submit_button')
		        .html("Update");
		}
		else {
		    // User just needs to verify.
		    $("#affiliation").closest(".form-group")
			.addClass("has-warning");
		    // Change Button to verify and enable.
		    $('#submit_button')
		        .html("Yes, this is current")
			.removeAttr("disabled");
		}
		sup.ShowModal("#affiliation-update-modal");
	    }
	    else {
		sup.ShowModal("#addrequired-modal");
	    }
	}
    }
    
    //
    // Submit the form.
    //
    function SubmitForm()
    {
	var extras = {
	    "needupdate" : window.NEEDUPDATE ? true : false
	};
	var submit_callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    if (window.REFERRER === undefined) {
		window.location.replace("user-dashboard.php");
	    }
	    else {
		window.location.replace(window.REFERRER);
	    }
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		// Email not verified, throw up form.
		if (json.code == 3) {
		    sup.ShowModal('#verify_modal');
		}
		else if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    aptforms.SubmitForm('#myaccount_form', "myaccount", "update",
				submit_callback, undefined, extras);
	};
	aptforms.CheckForm('#myaccount_form', "myaccount", "update",
			   checkonly_callback, undefined, extras);
    }
    $(document).ready(initialize);
});
