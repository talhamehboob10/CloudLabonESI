$(function ()
{
    'use strict';

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var callback = function(json) {
	    sup.HideModal("#waitwait-modal");
	    //console.info(json.value);

	    if (json.code) {
		sup.SpitOops("oops", json.value);
	    }
	    $('#page-body').html(json.value);
	}
	sup.ShowModal("#waitwait-modal");
	var xmlthing = sup.CallServerMethod(window.AJAXURL,
					    "approveuser",
					    window.ACTION,
					    {"user_uid"   : window.USER,
                                             "pid"        : window.PROJECT});
	xmlthing.done(callback);
    }
    $(document).ready(initialize);
});
