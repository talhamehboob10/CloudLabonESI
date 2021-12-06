$(function ()
{
    'use strict';

    var templates     = APT_OPTIONS.fetchTemplateList(['frequency-graph']);
    var mainTemplate  = _.template(templates['frequency-graph']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var options = {
	    "selector"  : ".frequency-graph-div",
	    "url"       : window.URL,
	    "cluster"   : window.CLUSTER,
	    "node_id"   : window.NODEID,
	    "iface"     : window.IFACE,
	    "url"       : window.URL,
	    "logid"     : window.LOGID,
	    "archived"  : window.ARCHIVED,
	    "baseline"  : window.BASELINE,
	};
	$('#main-body').html(mainTemplate(options));
	// Its a little too big by itself
	//$(".frequency-graph-div").addClass("col-sm-10 col-sm-offset-1");
	ShowFrequencyGraph(options);
    }
    $(document).ready(initialize);
});
