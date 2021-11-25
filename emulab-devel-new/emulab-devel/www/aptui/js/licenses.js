$(function ()
{
    'use strict';
    var template_list   = ["licenses", "oops-modal", "waitwait-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);
    var licenses        = [];

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#main-body').html(templates["licenses"]);
	$('#oops-div').html(templates["oops-modal"]);
	$('#waitwait-div').html(templates["waitwait-modal"]);
	
	GetLicenses();
    }

    function GetLicenses()
    {
	var callback = function(json) {
	    console.log("GetLicenses", json);

	    if (json.code) {
		console.info("Could not list license: " + json.value);
		return;
	    }
	    licenses = json.value;
	    if (! licenses.length) {
		window.location.replace("landing.php");
		return;
	    }
	    HandleLicense(licenses.shift());
	};
    	var xmlthing = sup.CallServerMethod(null, "licenses", "List");
	xmlthing.done(callback);
    }
    
    function HandleLicense(license)
    {
	console.info("HandleLicense", license);
	
	// Clear for next license.
	$('#description-panel .license').html("").addClass("hidden");
	$('#license-panel .panel-body .license-text').html("");

	// Reset handler for accept button.
	$('#accept-license')
	    .off("click")
	    .click(function (event) {
		event.preventDefault();
		Accept(license);
	    });

	$('#reject-license')
	    .off("click")
	    .click(function (event) {
		event.preventDefault();
		Reject(license);
	    });

	if (license.description_text && license.description_text != "") {
	    var html;
	
	    if (license.description_type == "md") {
		html = marked(license.description_text);
	    }
	    else if (license.description_type == "html") {
		html = license.description_text;
	    }
	    else if (license.description_type == "text") {
		html = "<textarea style='width: 100%;' rows=8>" +
		    license.description_text + "</textarea>";
	    }
	    $('#description-panel .license')
		.html(html)
		.removeClass("hidden");
	}
	var html;
	
	if (license.license_type == "md") {
	    html = marked(license.license_text);
	}
	else if (license.license_type == "html") {
	    html = license.license_text;
	}
	else if (license.license_type == "text") {
	    html = "<textarea style='width: 100%;' rows=20>" +
		license.license_text + "</textarea>";
	}
	$('#license-panel .panel-body .license-text').html(html);
    }

    function Accept(license)
    {
	console.info("Accept", license);
	
	var callback = function(json) {
	    console.log(json);

	    if (json.code) {
		console.info("Could not accept license: " + json.value);
		return;
	    }
	    if (licenses.length) {
		sup.ShowWaitWait("One moment please while we check to see if " +
				 "there are any more licenses to accept ...")

		setTimeout(function () {
		    sup.HideWaitWait();
		    HandleLicense(licenses.shift());
		}, 2000);
		return;
	    }
	    window.location.replace("landing.php");
	};
    	var xmlthing = sup.CallServerMethod(null,
					    "licenses", "Accept",
					    {"idx" : license.idx});
	xmlthing.done(callback);
    }
    function Reject(license)
    {
	console.info("Reject", license);
	
	var callback = function(json) {
	    console.log(json);

	    if (json.code) {
		console.info("Could not reject license: " + json.value);
		return;
	    }
	    if (licenses.length) {
		sup.ShowWaitWait("One moment please while we check to see if " +
				 "there are any more licenses to accept ...")

		setTimeout(function () {
		    sup.HideWaitWait();
		    HandleLicense(licenses.shift());
		}, 2000);
		return;
	    }
	    window.location.replace("landing.php");
	};
    	var xmlthing = sup.CallServerMethod(null,
					    "licenses", "Reject",
					    {"idx" : license.idx});
	xmlthing.done(callback);
    }
    $(document).ready(initialize);
});
