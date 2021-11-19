$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['changepswd',
						   'oops-modal',
						   'waitwait-modal']);
    var mainTemplate = _.template(templates['changepswd']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#oops_div').html(templates['oops-modal']);
	$('#waitwait_div').html(templates['waitwait-modal']);

	var html = aptforms.FormatFormFields(mainTemplate({
	    needold : window.NEEDOLD,
	    key     : window.KEY,
	    user    : window.USER,
	}));
	$('#page-body').html(html);

	$('#submit-button').click(function (event) {
	    event.preventDefault();
	    SubmitForm();
	    return false;
	});
    }
    
    //
    // Submit the form.
    //
    function SubmitForm()
    {
	var submit_callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    sup.ShowModal("#success-modal");
	    setTimeout(function f() {
		window.location.replace("user-dashboard.php");
	    }, 2000);
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    aptforms.SubmitForm('#changepswd-form',
				"changepswd", "changepswd",
				submit_callback);
	};
	aptforms.CheckForm('#changepswd-form',
			   "changepswd", "changepswd",
			   checkonly_callback);
    }
    $(document).ready(initialize);
});
