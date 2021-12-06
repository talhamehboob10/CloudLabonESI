$(function ()
{
    'use strict';

    var templateList = APT_OPTIONS.fetchTemplateList(['cluster-graphs']);
    var template = _.template(templateList['cluster-graphs']);

    var usefancy = false;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	usefancy = window.USEFANCY;

	$('#cluster-graphs')
	    .html(template({"usefancy" : usefancy}));

	if (usefancy) {
	    bilevelAsterGraph("/cloudlab-nofed.json",
			      "#status-nofed","auto","large");
	    bilevelAsterGraph("/cloudlab-fedonly.json",
			      "#status-fedonly","auto","large");
	}
	else {
	    $('#status-local').load("/node_usage/freenodes.svg");
	}
	setTimeout(function f() { Refresh() }, 30000);
    }

    /*
     * Refresh the graphs.
     */
    function Refresh()
    {
	if (usefancy) {
	    $('#status-fedonly').html("");
	    $('#status-nofed').html("");
	    $("div").remove(".d3-tip");
	
	    bilevelAsterGraph("/cloudlab-nofed.json",
			      "#status-nofed","auto","large");
	    bilevelAsterGraph("/cloudlab-fedonly.json",
			      "#status-fedonly","auto","large");
	}
	else {
	    $('#status-local').html("");
	    $('#status-local').load("/node_usage/freenodes.svg");
	}
	setTimeout(function f() { Refresh() }, 30000);
    }
	
    $(document).ready(initialize);
});
