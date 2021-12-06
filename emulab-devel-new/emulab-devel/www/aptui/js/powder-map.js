$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['powder-map']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#main-body').html(_.template(templates['powder-map']));

	if (window.EMBEDDED) {
	    $(".powder-mapview").css("height", "99%");
	}
	var options = {
	    "showfilter"    : window.SHOWFILTER,
	    "showavailable" : window.SHOWAVAILABLE,
	    "showmobile"    : window.SHOWMOBILE,
	    // What the user has reserved.
	    "showreserved"  : window.SHOWRESERVED,
	    "showlegend"    : window.SHOWLEGEND,
	    "showlinks"     : window.SHOWLINKS,
	};
	if (window.EXPERIMENT !== undefined) {
	    options["experiment"] = window.EXPERIMENT;
	}
	if (window.LOCATION !== undefined) {
	    options["location"] = window.LOCATION;
	}
	if (window.ROUTE !== undefined) {
	    options["route"] = window.ROUTE;
	}
	ShowPowderMap(".powder-mapview", options);
    }
    $(document).ready(initialize);
});
