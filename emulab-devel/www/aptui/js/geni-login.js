$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['geni-login', 'waitwait-modal']);
    var loginString = templates['geni-login'];
    var waitwaitString = templates['waitwait-modal'];
    var embedded = 0;
    
    function initialize()
    {
	embedded = window.EMBEDDED;
	
	$('#page-body').html(loginString);
	$('#waitwait_div').html(waitwaitString);
	// We share code with the modal version of login, and the
	// handler for the button is installed in initialize().
	// See comment there.
	sup.InitGeniLogin(embedded);
	$('#authorize').click(function (event) {
	    event.preventDefault();
	    sup.StartGeniLogin();
	    return false;
	});
	window.APT_OPTIONS.initialize(sup);
    }
    $(document).ready(initialize);
});
