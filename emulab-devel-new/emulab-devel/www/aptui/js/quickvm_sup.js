$(function () {
window.sup = (function () {

function ParseURN(urn) 
{
    var parser  = /^urn:publicid:idn\+([^\+]*)\+([^\+]*)\+(.*)$/i;
    var matches = parser.exec(urn);

    if (!matches) {
	return null;
    }
    var hrn = {"domain" : matches[1],
	       "type"   : matches[2],
	       "id"     : matches[3]};
    
    if (hrn.type == "image") {
	parser  = /^([^\/\:]+)(::|:|\/\/)([^\:]+):?(\d+)?$/;
	matches = parser.exec(hrn.id);
	if (matches) {
	    hrn["project"] = matches[1];
	    hrn["image"]   = matches[3];
	    hrn["version"] = null;
	    if (matches.length > 4) {
		hrn["version"] = matches[4];
	    }
	}
    }
    return hrn;
}
function CreateURN(domain, authority, id)
{
    return "urn:publicid:IDN+" + domain + "+" + authority + "+" + id;
}
function IsUUID(uuid)
{
    return /^[\w]{8}-[\w]{4}-[\w]{4}-[\w]{4}-[\w]{12}$/.test(uuid);
}

function ShowModal(which, hidefunction, showfunction) 
{
    var hide_callback = function() {
	$(which).off('hidden.bs.modal', hide_callback);
	hidefunction();
    };
    if (hidefunction !== undefined) {
	$(which).on('hidden.bs.modal', hide_callback);
    }
    var show_callback = function() {
	$(which).off('shown.bs.modal', show_callback);
	showfunction();
    };
    if (showfunction !== undefined) {
	$(which).on('shown.bs.modal', show_callback);
    }
    $(which).modal('show');
}
    
function HideModal(which, continuation) 
{
    var callback = function() {
	$(which).off('hidden.bs.modal', callback);
	continuation();
    };
    if (continuation !== undefined) {
	$(which).on('hidden.bs.modal', callback);
    }
    $(which).modal('hide');
}

function ShowWaitWait(message, hidefunction, showfunction)
{
    if (message === undefined) {
	$('#waitwait-modal .waitwait-message').addClass("hidden");
    }
    else {
	if (message != null) {
	    $('#waitwait-modal .waitwait-message span').html(message);
	}
	$('#waitwait-modal .waitwait-message').removeClass("hidden");
    }
    ShowModal('#waitwait-modal', hidefunction, showfunction);
}
function HideWaitWait(continuation)
{
    $('#waitwait-modal .waitwait-message').addClass("hidden");
    HideModal('#waitwait-modal', continuation);
}
    
function CallServerMethod(url, route, method, args, callback)
{
  // Main body of function moved to common.js
  return APT_OPTIONS.CallServerMethod(url, route, method, args, callback);
}

// button is a jQuery object containing the button(s) to add event to
// getText is a function to fetch the text to be saved. Invoked per click with no arguments and expects a string result. If getText returns null or undefined, no save will happen and no callback will be called.
// filename is the default filename used
// callback is invoked with button, text, and filename as arguments after download.
//
// This function will unset all other onclick events.
function DownloadOnClick(button, getText, filename, callback)
{
  button.off('click');
  button.on('click', function () {
    var text = getText();
    if (text !== undefined && text !== null)
    {
      var file = new Blob([text],
			  { type: 'application/octet-stream' });
      var a = document.createElement('a');
      a.href = window.URL.createObjectURL(file); 
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      $('a').last().remove();
      if (callback !== undefined && callback !== null)
      {
	callback(button, text, filename);
      }
    }
  });
}

function ClearDownloadOnClick(button)
{
  button.off('click');
}
  
var jacksInstance;
var jacksInput;
var jacksOutput;

function maketopmap(divname, xml, showinfo, withoutMultiSite)
{
    var xmlDoc = $.parseXML(xml);
    var xmlXML = $(xmlDoc);

    /*
     * See how many sites. Do not use multiSite if no sites or
     * only one site. Overrides the withoutMultiSite argument if set.
     */
    var sites  = {};

    $(xmlXML).find("node").each(function() {
	var JACKS_NS = "http://www.protogeni.net/resources/rspec/ext/jacks/1";
	var node_id  = $(this).attr("client_id");
	var site     = this.getElementsByTagNameNS(JACKS_NS, 'site');
	if (! site.length) {
	    return;
	}
	var siteid = $(site).attr("id");
	if (siteid === undefined) {
	    console.log("No site ID in " + site);
	    return;
	}
	sites[siteid] = siteid;
    });
    if (Object.keys(sites) <= 1) {
	withoutMultiSite = true;
    }
    
    if (! jacksInstance)
    {
	jacksInstance = new window.Jacks({
	    mode: 'viewer',
	    source: 'rspec',
	    multiSite: (withoutMultiSite ? false : true),
	    root: divname,
	    nodeSelect: showinfo,
	    readyCallback: function (input, output) {
		jacksInput = input;
		jacksOutput = output;
		jacksInput.trigger('change-topology',
				   [{ rspec: xml }]);
	    },
	    show: {
		rspec: false,
		tour: false,
		version: false,
		selectInfo: showinfo,
		menu: false
	    },
	  canvasOptions: {
	    "aggregates": [
	      {
		"id": "urn:publicid:IDN+utah.cloudlab.us+authority+cm",
		"name": "Cloudlab Utah"
	      },
	      {
		"id": "urn:publicid:IDN+wisc.cloudlab.us+authority+cm",
		"name": "Cloudlab Wisconsin"
	      },
	      {
		"id": "urn:publicid:IDN+clemson.cloudlab.us+authority+cm",
		"name": "Cloudlab Clemson"
	      },
	      {
		"id": "urn:publicid:IDN+utahddc.geniracks.net+authority+cm",
		"name": "IG UtahDDC"
	      },
	      {
		"id": "urn:publicid:IDN+apt.emulab.net+authority+cm",
		"name": "Apt Utah"
	      },
	      {
		"id": "urn:publicid:IDN+emulab.net+authority+cm",
		"name": "Emulab"
	      },
	      {
		"id": "urn:publicid:IDN+wall2.ilabt.iminds.be+authority+cm",
		"name": "iMinds Virt Wall 2"
	      },
	      {
		"id": "urn:publicid:IDN+uky.emulab.net+authority+cm",
		"name": "UKY Emulab"
	      }
	    ]
	  }
	});
    }
    else if (jacksInput)
    {
	jacksInput.trigger('change-topology',
			   [{ rspec: xml }]);
    }
}

// Spit out the oops modal.
function SpitOops(id, msg)
{
    var modal_name = "#" + id + "_modal";
    var modal_text_name = "#" + id + "_text";
    $(modal_text_name).html(msg);
    ShowModal(modal_name);
}

function addPopoverClip (id, contentfunction)
{
    $(id).click(function(event) {
	event.preventDefault();
	var button = this;

	// If clicking on the button when the popover is
	// showing, hide it and return.
	if ($(button).data("bs.popover") !== undefined) {
	    $(button).popover('destroy');
	    return;
	}
	var urn = $(button).data("urn");

	$(button).popover({
	    html:     true,
	    content:  contentfunction(this),
	    trigger:  'manual',
	    placement:'auto',
	    container:'body',
	});
	if (0) {
	// If the user clicks somewhere else, kill this popover.
	var hide = function (event) {
	    console.info("hide");
	    $(button).popover('destroy');
	    $('body').off("click", hide);
	};
	// Cannot bind it till the popover is shown.
	$(button).on("shown.bs.popover", function() {
	    $('body').on("click", hide);
	});
	}
	$(button).popover('show');

	// Timeout to hide the popover. I tried the body click event
	// above but it did not work consistently. Will revisit if
	// I hear enough whining.
	var mytimout = setTimeout(function f() {
	    $(button).popover('destroy');
	}, 5000);
	$(button).on("hide.bs.popover", function() {
	    clearTimeout(mytimout);
	});

	// DOM of the popover content.
	var content = $(button).data("bs.popover").tip();

	// Bind the copy-to-clipboard button.
	$(content).find("a").click(function (e) {
	    e.preventDefault();
	    $(content).find("input").select();
	    document.execCommand("copy");
	    $(button).popover('destroy');
	});
	// If user clicks in the input, kill the popover.
	$(content).find("input").click(function (e) {
	    e.preventDefault();
	    $(button).popover('destroy');
	});
    });
}

function popoverClipContent(url) {
    var string =
	"<div style='width 100%'> "+
	"  <input readonly type=text " +
	"       style='display:inline; width: 93%; padding: 2px;'" +
	"       class='form-control input-sm' "+
	"       value='" + url + "'>" +
	"  <a href='#' class='btn urn-copy-button' " +
	"     style='padding: 0px'>" +
	"    <span class='glyphicon glyphicon-copy'></span>" +
	"  </a>" +
	"</div>";
    return string;
}

function GeniAuthenticate(cert, r1, success, failure)
{
    var callback = function(json) {
	console.log('callback');
	if (json.code) {
	    alert("Could not generate secret: " + json.value);
	    failure();
	} else {
	    console.info(json.value);
	    success(json.value.r2_encrypted);
	}
    }
    var $xmlthing = CallServerMethod(null,
				     "geni-login", "CreateSecret",
				     {"r1_encrypted" : r1,
				      "certificate"  : cert});
    $xmlthing.done(callback);
}

function GeniComplete(credential, signature)
{
    //console.log(credential);
    //console.log(signature);
    // signature is undefined if something failed before
    VerifySpeaksfor(credential, signature);
}

var BLOB = null;
var EMBEDDED = false;
    
function InitGeniLogin(embedded)
{
    EMBEDDED = embedded;
    
    // Ask the server for the stuff we need to start and go.
    var callback = function(json) {
	console.info(json);
	BLOB = json.value;
    }
    var $xmlthing = CallServerMethod(null, "geni-login", "GetSignerInfo", null);
    $xmlthing.done(callback);
}

function StartGeniLogin()
{
    genilib.trustedHost = BLOB.HOST;
    genilib.trustedPath = BLOB.PATH;
    genilib.authorize({
	id: BLOB.ID,
	toolCertificate: BLOB.CERT,
	complete: GeniComplete,
	authenticate: GeniAuthenticate
    });
}

function VerifySpeaksfor(speaksfor, signature)
{
    var callback = function(json) {
	HideWaitWait();
	    
	if (json.code) {
	    alert("Could not verify speaksfor: " + json.value);
	    return;
	}
	console.info(json.value);

	//
	// Need to set the cookies we get back so that we can
	// redirect to the status page.
	//
	// Delete existing cookies first
	var expires = "expires=Thu, 01 Jan 1970 00:00:01 GMT;";
	document.cookie = json.value.hashname + '=; ' + expires;
	document.cookie = json.value.crcname  + '=; ' + expires;
	document.cookie = json.value.username + '=; ' + expires;
	    
	var cookie1 = 
	    json.value.hashname + '=' + json.value.hash +
	    '; domain=' + json.value.domain +
	    '; max-age=' + json.value.timeout + '; path=/; secure';
	var cookie2 =
	    json.value.crcname + '=' + json.value.crc +
	    '; domain=' + json.value.domain +
	    '; max-age=' + json.value.timeout + '; path=/';
	var cookie3 =
	    json.value.username + '=' + json.value.user +
	    '; domain=' + json.value.domain +
	    '; max-age=' + json.value.timeout + '; path=/';

	document.cookie = cookie1;
	document.cookie = cookie2;
	document.cookie = cookie3;

	if (json.value.webonly != 0) {
	    alert("You do not belong to any projects at your Portal, " +
		  "so you will have very limited capabilities. Please " +
		  "join or create a project at your Portal, to enable " +
		  "more capabilities.");
	}
	if ($('#login_referrer').length) {
	    window.location.replace($('#login_referrer').val());
	}
	else if (EMBEDDED) {
	    window.parent.location.replace("../" + json.value.url);
	}
	else {
	    window.location.replace(json.value.url);
	}
    }
    ShowWaitWait("This will take a minute; patience please!");
    var $xmlthing = CallServerMethod(null,
				     "geni-login", "VerifySpeaksfor",
				     {"speaksfor" : speaksfor,
				      "signature" : signature,
				      "embedded"  : EMBEDDED});
    $xmlthing.done(callback);
}

function ConfirmModal(args)
{
    var modal = '#' + args.modal;
    var cancel_function = args.cancel_function;
    var confirm_function = args.confirm_function;
    var function_data = args.function_data;

    if (args.prompt) {
	$(modal + ' .prompt').html(args.prompt);
    }
    else {
	$(modal + ' .prompt').html("Confirm?");
    }

    $(modal).on('hidden.bs.modal', function (event) {
	$(this).unbind(event);
	$(modal + ' .confirm-button').off("click");
	$(modal + ' .cancel-button').off("click");
	if (cancel_function !== undefined && cancel_function) {
	    cancel_function(function_data);
	}
    });
    $(modal + ' .confirm-button').click(function (event) {
	$(modal).off('hidden.bs.modal');
	HideModal(modal, function(event) {
	    $(modal + ' .confirm-button').off("click");
	    $(modal + ' .cancel-button').off("click");
	    if (confirm_function !== undefined && confirm_function) {
		confirm_function(function_data);
	    }
	});
    });
    $(modal + ' .cancel-button').click(function (event) {
	// cancel callback called above.
	HideModal(modal);
    });
    ShowModal(modal);
}

  // Input is an image urn.
  // Returns a pretty image name.
  function ImageDisplay(v)
  {
    var sp = v.split('+');
    var display;
    if (sp.length >= 4)
    {
      if (sp[3].substr(0, 12) == 'emulab-ops//')
      {
	display = sp[3].substr(12);
      }
      else
      {
	display = sp[3];
      }
    }
    else
    {
      display = v;
    }
    return display;
  }

// www.w3resource.com/javascript-exercises/javascript-math-exercise-23.php
function newUUID()
{
    var dt = new Date().getTime();
    var uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = (dt + Math.random()*16)%16 | 0;
        dt = Math.floor(dt/16);
        return (c=='x' ? r :(r&0x3|0x8)).toString(16);
    });
    return uuid;
}

// Exports from this module for use elsewhere
return {
    ParseURN: ParseURN,
    CreateURN: CreateURN,
    IsUUID: IsUUID,
    newUUID: newUUID,
    ShowModal: ShowModal,
    HideModal: HideModal,
    ShowWaitWait: ShowWaitWait,
    HideWaitWait: HideWaitWait,
    CallServerMethod: CallServerMethod,
    DownloadOnClick: DownloadOnClick,
    ClearDownloadOnClick: ClearDownloadOnClick,
    maketopmap: maketopmap,
    SpitOops: SpitOops,
    StartGeniLogin: StartGeniLogin,
    InitGeniLogin: InitGeniLogin,
    ImageDisplay: ImageDisplay,
    ConfirmModal: ConfirmModal,
    addPopoverClip: addPopoverClip,
    popoverClipContent: popoverClipContent,
};
})();
});
