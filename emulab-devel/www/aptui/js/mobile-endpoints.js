$(function ()
{
    'use strict';

    var template_list = ['mobile-endpoints', "waitwait-modal", "oops-modal"];
    var templates     = APT_OPTIONS.fetchTemplateList(template_list);    
    var mainTemplate  = _.template(templates['mobile-endpoints']);
    var amlist        = null;
    var radioInfo     = null;
    var map           = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	radioInfo = JSON.parse(_.unescape($('#radioinfo-json')[0].textContent));
	console.info("radioinfo", radioInfo);
	amlist    = JSON.parse(_.unescape($('#amlist-json')[0].textContent));
	console.info("amlist", amlist);

	$('#oops_div').html(templates["oops-modal"]);
	$('#waitwait_div').html(templates["waitwait-modal"]);
	
	sup.CallServerMethod(null, "map-support", "GetMobileEndpoints",
			     null, function (json) {
				 console.info("mobile info", json);
				 if (json.code) {
				     sup.SpitOops("Failed to get mobile " +
						  "endpoint info");
				     return;
				 }
				 GeneratePage(json.value.buses,
					      json.value.routes);
			     });
    }

    function GeneratePage(endpoints, routes)
    {
	var options = {
	    "endpoints" : endpoints,
	    "routes"    : routes,
	    "amlist"    : amlist,
	    "radioinfo" : radioInfo
	};
	$('#main-body').html(mainTemplate(options));

	// Format dates with moment before display.
	$('#mobile-endpoints-table .format-date').each(function(){
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html())
			     .format("MMM D, h:mm:ss a"));
	    }
	});
	
	$('#mobile-endpoints-table')
	    .tablesorter({
		theme : 'bootstrap',
		widgets : [ "uitheme", "zebra"],
		headerTemplate : '{content} {icon}',
	    });

	$(".location").click(function (event) {
	    event.preventDefault();
	    var args = {
		"urn"      : $(this).data("urn"),
		"routeid"  : $(this).data("routeid"),
		"type"     : "route",
	    };
	    console.info("clicked", args);

	    GetMapWindow(function (map) {
		console.info("got map", map);
		var foo = map;
		if (navigator.userAgent.indexOf("Chrome") > 0) {
		    foo = window.open('', 'Powder Map');
		}
		foo.focus();
		foo.postMessage(args);
	    });
	})
    }

    /*
     * Create the map window if it does not exist.
     */
    window.GetMapWindow = function(callback) {
	console.info("mobile GetMapWindow");
	if (map && !map.closed) {
	    callback(map);
	    return;
	}
	if (window.opener) {
	    console.info("calling into the opener");
	    window.opener.GetMapWindow(callback);
	    return;
	}
	map = window.open('powder-map.php', 'Powder Map');
	/*
	 * Need to wait for the map to get to the point where sending
	 * it a message can be received, so wait for a message from
	 * it.
	 */
	$(window).on("message", function () {
	    console.info("message received");
	    callback(map);
	});
    }

    $(document).ready(initialize);
});
