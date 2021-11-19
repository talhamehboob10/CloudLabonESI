(function ()
{
 var getQueryParams = function(qs) {
   qs = qs.split('+').join(' ');
   var params = {};
   var re = /[?&]?([^=]+)=([^&]*)/g;
   var tokens = re.exec(qs);
   
   while (tokens) {
     params[decodeURIComponent(tokens[1])]
       = decodeURIComponent(tokens[2]);
     tokens = re.exec(qs);
   }
    
   return params;
 };

 var params = getQueryParams(window.location.search);
 if (! params.source)
 {
   window.JACKS_LOADER = { params: { source: 'utah' } };
 }
}
)();

window.APT_OPTIONS = window.APT_OPTIONS || {};

window.APT_OPTIONS.configObject = {
    baseUrl: '.',
    paths: {
	'jquery-ui': 'js/lib/jquery-ui',
	'jquery-grid':'js/lib/jquery.appendGrid-1.3.1.min',
	'jquery-steps': 'js/lib/jquery.steps.min',
	'formhelpers': 'js/lib/bootstrap-formhelpers',
	'dateformat': 'js/lib/date.format',
	'filestyle': 'js/lib/filestyle',
	'marked': 'js/lib/marked',
	'moment': 'js/lib/moment',
	'underscore': 'js/lib/underscore-min',
	'filesize': 'js/lib/filesize.min',
	'contextmenu': 'js/lib/bootstrap-contextmenu',
	'jacks': 'https://www.emulab.net/protogeni/jacks-utah/js/jacks',
	'constraints': 'https://www.emulab.net/protogeni/jacks-utah/js/Constraints'
    },
    shim: {
	'jquery-ui': { },
	'jquery-grid': { deps: ['jquery-ui'] },
	'jquery-steps': { },
	'formhelpers': { },
	'jacks': { },
	'dateformat': { exports: 'dateFormat' },
	'filestyle': { },
	'marked' : { exports: 'marked' },
	'underscore': { exports: '_' },
	'filesize' : { exports: 'filesize' },
	'contextmenu': { },
    },
    waitSeconds: 0,
    urlArgs: "version=" + APT_CACHE_TOKEN
};

window.APT_OPTIONS.initialize = function (sup)
{
    var embedded = window.EMBEDDED;

    // Eventually make this download without having to follow a link.
    // Just need to figure out how to do that!
    if ($('#download_creds_link').length) {
	$('#download_creds_link').click(function(e) {
	    e.preventDefault();
	    window.location.href = 'getcreds.php';
	    return false;
	});
    }

    /*
     * When the clicks to read new news, tell the server and hide the button
     */
    if ($('#new-news-button').length) {
	$('#new-news-button').click(function (event) {
	    $('#new-news-button').addClass("hidden");
	});
    }
    
    /*
     * Setup a timer to ask for announcements.
     */
    if (window.LOGINUID) {
	setTimeout(function f() { window.APT_OPTIONS.Announcements() }, 10000);
    }
    
    window.APT_OPTIONS.startPage();
    $(window).on('beforeunload.common', APT_OPTIONS.endPage);
    $('body').show();
};

window.APT_OPTIONS.gaAjaxEvent = function (route, method, code)
{
    if (window.GOOGLEUA === undefined) {
	return;
    }
    // Do not report on these long polling calls, swamps the data.
    if (method == "GetInstanceStatus" || method == "SnapshotStatus") {
	return;
    }
    ga('send', 'event', 'ajax', route, method, code);
}

window.APT_OPTIONS.gaButtonEvent = function (event)
{
    if (window.GOOGLEUA === undefined) {
	return;
    }
    var target = event.target;
    var type   = event.type;
    var id     = $(target).attr('id');
    var label  = $(target).text();
    if (id === undefined) {
	id = label.trim();
    }
    //console.info("button", type, id);
    ga('send', 'event', 'button', type, id);
}

window.APT_OPTIONS.gaTabEvent = function (action, id)
{
    if (window.GOOGLEUA === undefined) {
	return;
    }
    //console.info("tab", action, id);
    ga('send', 'event', 'tab', action, id);
}

APT_OPTIONS.CallServerMethod = function (url, route, method, args, callback)
{
    // ignore url now.
    url = 'https://' + window.location.host + '/apt/server-ajax.php';
    url = 'server-ajax.php';

    var networkError = {
	"code"  : -1,
	"value" : "Server error, possible network failure. Try again later.",
    };

    if (args == null) {
        args = {"noargs" : "noargs"};
    }
    var jqxhr = $.ajax({
        // the URL for the request
        url: url,
        success: function (json) {
	    window.APT_OPTIONS.gaAjaxEvent(route, method, json.code);
	    if (callback !== undefined) {
		callback(json);
	    }
	},
	error: function (jqXHR, textStatus, errorThrown) {
	    if (callback !== undefined) {
		callback(networkError);
	    }
	},
 
        // the data to send (will be converted to a query string)
        data: {
            ajax_route:     route,
            ajax_method:    method,
            ajax_args:      args,
        },
 
        // whether this is a POST or GET request
        type: "POST",
 
        // the type of data we expect back
        dataType : "json",
    });
    var defer = $.Deferred();
    
    jqxhr.done(function (data) {
	defer.resolve(data);
    });
    jqxhr.fail(function (jqXHR, textStatus, errorThrown) {
	networkError["jqXHR"] = jqXHR;
	defer.resolve(networkError);
    });
    return defer;
};

window.APT_OPTIONS.announceDismiss = function (aid) {
  APT_OPTIONS.CallServerMethod('', 'announcement', 'Dismiss', {'aid': aid}, function(){});
};

window.APT_OPTIONS.announceClick = function (aid) {
  APT_OPTIONS.CallServerMethod('', 'announcement', 'Click', {'aid': aid}, function(){});
};

window.APT_OPTIONS.nagPI = function (pid) {
  APT_OPTIONS.CallServerMethod('', 'nag', 'NagPI', {"pid" : pid},
			       function(json) {
				   if (json.code) {
				       console.info("nagged", json);
				       if (json.code > 0) {
					   alert(json.value);
				       }
				       return;
				   }
				   alert("The Project Leader for project '" +
					 pid + "' " +
					 "has been sent a reminder message.");
			       });
  return false;
};

window.APT_OPTIONS.fetchTemplate = function (name) {
  var result = '';
  var element = document.querySelector('script#' + name);
  if (element)
  {
    result = atob(element.innerHTML);
  }
  return result;
};

window.APT_OPTIONS.fetchTemplateList = function (nameList) {
  var result = {};
  var i = 0;
  for (; i < nameList.length; i += 1)
  {
    var name = nameList[i];
    result[name] = window.APT_OPTIONS.fetchTemplate(name);
  }
  return result;
};

window.APT_OPTIONS.startPage = function () {
  window.APT_OPTIONS.postTutorial({ url: window.location.href });
}

window.APT_OPTIONS.endPage = function () {
  window.APT_OPTIONS.postTutorial({ url: "None" });
}

window.APT_OPTIONS.updatePage = function (data) {
    if (0) {
	window.APT_OPTIONS.postTutorial({ url: window.location.href,
					  update: data });
    }
}

window.APT_OPTIONS.postTutorial = function (data) {
  //console.log('PostTutorial: ', data);
    //console.log('parent: ', window.parent.location.hostname, window.parent.location.port, window.parent.location.protocol);
  if (1) {
      return;
  }
  window.parent.postMessage(data, 'http://tutorial.cloudlab.us:5000');
  try {
    if (window.parent) {
      if (window.parent.location.hostname === 'tutorial.cloudlab.us' &&
	  window.parent.location.port === '5000' &&
	  window.parent.location.protocol === 'http')
      {
	console.log('sending');
	window.parent.postMessage(data, 'http://tutorial.cloudlab.us:5000');
      }
      else if (window.parent.location.hostname === 'tutorial.cloudlab.us' &&
	       window.parent.location.port === '' &&
	       window.parent.location.protocol === 'http')
      {
	window.parent.postMessage(data, 'http://tutorial.clou7dlab.us');
      }
    }
  }
  catch (e) {}
}

window.APT_OPTIONS.Announcements = function () {
    var callback = function(json) {
	if (json.code) {
	    console.info("announcements", json);
	}
	else {
	    var newhtml = "";
	
	    if (json.value.length) {
		//console.info("announcements", json);
		_.each(json.value, function(html) {
		    newhtml += html;
		});
	    }
	    else {
		// Clear current announcements; dismissed in another tab.
		newhtml = "";
	    }
	    $('#portal-announcement-div').html(newhtml);
	}
	setTimeout(function f() { window.APT_OPTIONS.Announcements() }, 60000);
    }

    var xmlthing =
	APT_OPTIONS.CallServerMethod('', 'announcement', 'Announcements', null);
    // We want the callback all the time. 
    xmlthing.done(callback).fail(function () {
	setTimeout(function f() { window.APT_OPTIONS.Announcements() }, 90000);
    });
}

window.APT_OPTIONS.SetupCopyToClipboard = function (id) {
    $(id).find(".copy-to-clipboard a").click(function (e) {
	e.preventDefault();
	var input = $(this).parent().find("input");
	$(input).select();
	document.execCommand("copy");
	window.getSelection().removeAllRanges();	
	$(input)[0].blur();
    });
}
