$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['verify-match',
						   'waitwait-modal',
						   'oops-modal']);
    var mainTemplate = _.template(templates['verify-match']);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var xmlthing = sup.CallServerMethod(null, "user-dashboard",
					    "AccountDetails",
					    {"uid" : window.TARGET_USER});
	// Now we can do this. 
	$('#oops_div').html(templates['waitwait-modal']);	
	$('#waitwait_div').html(templates['oops-modal']);
	
	xmlthing.done(function (json) {
	    GeneratePageBody(json);
	});
    }

    function GeneratePageBody(json)
    {
	console.info(json);

	if (json.code) {
	    sup.SpitOops("oops", json.value);
	    return;
	}
	// Generate the template.
	var html = mainTemplate({
	    "user_info" : json.value,
	});
	$('#main-body').html(html);

	if (_.size(json.value.scopus_info) == 1) {
	    $('#confirm-onlyone-paper').click(function () {
		HandleOne("confirm", json.value.scopus_info);
	    });
	    $('#deny-onlyone-paper').click(function () {
		HandleOne("deny", json.value.scopus_info);
	    });
	}
	else {
	    $('#confirm-papers').click(function () {
		HandleMany(json.value.scopus_info);
	    });

	}
    }

    /*
     * Confirm/Deny in the one paper case.
     */
    function HandleOne(which, scopus_info)
    {
	var scopus_id = _.keys(scopus_info)[0];
	var abstracts   = {};
	
	abstracts[scopus_id] = (which == "deny" ? false : true);
	console.info(abstracts);

	sup.CallServerMethod(null, "user-dashboard", "VerifyScopusInfo",
			     {"uid"  : window.TARGET_USER,
			      "abstracts" : abstracts},
			     function (json) {
				 if (json.code) {
				     console.info(json.value);
				     return;
				 }
				 if (window.REFERRER === undefined) {
				     window.location.replace("landing.php");
				 }
				 else {
				     window.location.replace(window.REFERRER);
				 }
			     });
    }

    /*
     * And the multiple paper case.
     */
    function HandleMany(scopus_info)
    {
	var abstracts = {};

	$('.scopus-row').each(function () {
	    var scopus_id = this.dataset["scopusid"];
	    var checked = $(this).find("input").is(":checked");

	    console.info($(this), scopus_id, checked);
	    abstracts[scopus_id] = checked;
	});
	console.info(abstracts);

	sup.CallServerMethod(null, "user-dashboard", "VerifyScopusInfo",
			     {"uid"  : window.TARGET_USER,
			      "abstracts" : abstracts},
			     function (json) {
				 if (json.code) {
				     console.info(json.value);
				     return;
				 }
				 if (window.REFERRER === undefined) {
				     window.location.replace("landing.php");
				 }
				 else {
				     window.location.replace(window.REFERRER);
				 }
			     });
    }
    
    $(document).ready(initialize);
});
