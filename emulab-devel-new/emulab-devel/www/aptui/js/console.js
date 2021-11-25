$(function ()
{
    'use strict';
    var authjson   = null;
    var authobject = null;

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	authjson   = _.unescape($('#auth-json')[0].textContent);
	authobject = JSON.parse(authjson);
	if (_.has(authobject, "webssh") && authobject.webssh != 0) {
	    StartConsoleNew();
	}
	else {
	    StartConsole();
	}
    }

    function StartConsole()
    {
	var baseurl = authobject.baseurl;
	
	var callback = function(json) {
	    console.info("StartConsole", json);
	    
            var split   = json.split(':');
            var session = split[0];
    	    var port    = split[1];
            var url     = baseurl;

            if (window.PROXIED) {
		// mod_proxy/mod_rewrite rule
		url = url + '/shellinabox/' + port;
            }
            else {
		url = url + ':' + port;
            }
            url = url + '/' + '#' +
		encodeURIComponent(document.location.href) + ',' + session;
            console.log(url);

	    // We create the console iframe inside the div.
	    var iwidth = "100%";
	    var iheight = 500;

	    var html =
		'<iframe id="console_iframe" ' +
		'width=' + iwidth + ' ' +
		'height=' + iheight + ' ' +
		'src=\'' + url + '\'>';

	    var html =
		'<div style="height:500px; width:100%; ' +
		'      resize:vertical;overflow-y:auto;padding-bottom:10px"> ' +
		'  <iframe id="' + tabname + '_iframe" ' +
		'     width="100%" height="100%"' + 
		'     src=\'' + url + '\'>' +
		'</div>';

	    $('#console-div').html(html);

	    $('#console-close').removeClass("hidden");

	    var killme = function () {
		var url = baseurl + ':' + port + '/quit' +
		    '?session=' + session;

		console.log("killme: " + url);

		$.ajax({
		    "url"     : url,
		    "type"    : 'GET',
		});
	    };

	    // Install a click handler for the close button.
	    $("#console-close").click(function(e) {
		e.preventDefault();
		killme();
		$("#console-close").off("click");
		$(window).off("beforeunload");
	    });

	    // Use an unload event to terminate the console. 
	    $(window).on("beforeunload", function() {
		console.info("Unload function called");
		killme();
	    });
	};

	var callback_failed = function(jqXHR, textStatus) {
	    var acceptURL = baseurl + '/accept_cert.html';
	    
	    console.log("Request failed: ", jqXHR);
	    
	    $('#console-div')
		.html("An SSL certificate must be accepted by your " +
		      "browser to continue.  Please click " +
		      "<a href='" + acceptURL + "'>here</a> " +
		      "to be redirected.");
	}

	var xmlthing = $.ajax({
	    // the URL for the request
     	    url: baseurl + '/d77e8041d1ad',
	    
     	    // the data to send (will be converted to a query string)
	    data: {
		auth: authjson,
	    },
	    
 	    // Needs to be a POST to send the auth object.
	    type: 'POST',
	    
    	    // Ask for plain text for easier parsing. 
	    dataType : 'text',
	});
	xmlthing.done(callback);
	xmlthing.fail(callback_failed);
    }

    function StartConsoleNew()
    {
        var url = authobject.baseurl;

	var loadiframe = function () {
	    console.info("Sending message", url);
	    iframewindow.postMessage(authjson, "*");
	    window.removeEventListener("message", loadiframe, false);
	};
	window.addEventListener("message", loadiframe);

	var html =
	    '<div style="height:31em; width:100%; ' +
	    '      resize:vertical;overflow-y:auto;padding-bottom:10px"> ' +
	    '  <iframe id="console-div-iframe" ' +
	    '     width="100%" height="100%"' + 
	    '     src=\'' + url + '\'></iframe>' +
	    '</div>';

        $('#console-div').html(html);
	$('.stty').removeClass("hidden");

	var iframe = $('#console-div-iframe')[0];
	var iframewindow = (iframe.contentWindow ?
			    iframe.contentWindow :
			    iframe.contentDocument.defaultView);
    }
    
    $(document).ready(initialize);
});
