$(function ()
{
    'use strict';

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	});
	if (window.APT_OPTIONS.PAGEREPLACE !== undefined) {
	    setTimeout(function () {
		window.location.replace(window.APT_OPTIONS.PAGEREPLACE);
	    }, 5000);
	}
    }

    $(document).ready(initialize);
});
