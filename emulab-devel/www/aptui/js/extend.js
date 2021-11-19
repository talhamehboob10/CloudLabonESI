//
// Progress Modal
//
$(function () {
window.ShowExtendModal = (function()
    {
	'use strict';

        var templates = APT_OPTIONS.fetchTemplateList(['user-extend-modal']);
        var userExtendString  = templates['user-extend-modal'];
      
        var modalname  = '#extend_modal';
	var divname    = '#extend_div';
	var slidername = "#extend_slider";
	var uuid       = 0;
	var callback   = null;
	var maxextend  = null;
	var howlong    = 24; // Number of hours being requested.
	var SLIDERLIMIT= 84 * 24;
	var extension_info  = null;
	var maxextend_date  = null;
	var physnode_count  = 0;
	var physnode_hours  = 0;
	var expires         = null;

	function Initialize()
	{
	    // Click handler.
	    $('button#request-extension').click(function (event) {
		event.preventDefault();
		RequestExtension();
	    });
	    /*
	     * If the modal contains the slider, set it up.
	     */
	    if ($(slidername).length) {
		InitializeSlider();
	    }

	    /*
	     * Callback to format check the date box.
	     */
	    if ($('#datepicker').length) {
		$('#datepicker').off("change");
		$('#datepicker').change(function() {
		    // regular expression to match required date format
		    var re  = /^\d{1,2}\/\d{1,2}\/\d{4}$/;
		    var val = $('#datepicker').val();

		    if (! val.match(re)) {
			alert("Invalid date format: " + val);
			// This does not work.
			$("#datepicker").focus();
			return false;
		    }
		    var howlong = DateToHours($('#datepicker').val());
		    $('#future_usage')
			.val(Math.round(physnode_count * howlong));
		});
	    }

	    /*
	     * Countdown for text box.
	     */
	    $('#why_extend').on('focus keyup', function (e) {
		UpdateCountdown();
	    });
	    // Clear existing text.
	    $('#why_extend').val('');
	    // Current usage.
	    if (physnode_count) {
		$("#extend_usage").removeClass("hidden");
		$('#current_usage').val(Math.round(physnode_hours));
		$('#future_usage').val(Math.round(physnode_count * 24));
	    }
	}

	function InitializeSlider()
	{
	    var labels = [];
	    
	    labels[0] = "1 day";
	    labels[1] = "7 days";
	    labels[2] = "4 weeks";
	    labels[3] = "Longer";

	    $(slidername).slider({value:0,
			   max: 1000,
			   slide: function(event, ui) {
			       return SliderChanged(event, ui.value);
			   },
			   start: function(event, ui) {
			       SliderChanged(event, ui.value);
			   },
			   stop: function(event, ui) {
			       SliderStopped(ui.value);
			   },
			  });

	    // how far apart each option label should appear
	    var width = $(slidername).width() / (labels.length - 1);

	    // Put together the style for <p> tags.
	    var left  = "style='width: " + width/2 +
		"px; display: inline-block; text-align: left;'";
	    var mid   = "style='width: " + width +
		"px; display: inline-block; text-align: center;'";
	    var right = "style='width: " + width/2 +
		"px; display: inline-block; text-align: right;'";

	    // Left most label.
	    var html = "<p " + left + ">" + labels[0] + "</p>";

	    // Middle labels.
	    for (var i = 1; i < labels.length - 1; i++) {
		html = html + "<p " + mid + ">" + labels[i] + "</p>";
	    }

	    // Right most label.
	    html = html + "<p " + right + ">" + labels[labels.length-1] + "</p>";

	    // Overwrite existing legend if we already displayed the modal.
	    if ($('#extend_slider_legend').length) {
		$('#extend_slider_legend').html(html);
	    }
	    else {
		// The entire legend;
		html =
		    '<div id="extend_slider_legend" class="ui-slider-legend">' +
		    html + '</div>';
 
		// after the slider create a containing div with the p tags.
		$(slidername).after(html);
	    }

	    /*
	     * Shade out the right side of the slider, where we will not
	     * let the user slide to, since it is beyond the maximum
	     * allowed extension (cause of a reservation).
	     */
	    if (maxextend != null && maxextend < SLIDERLIMIT) {
		var setvalue = HoursToSetvalue(maxextend);
		var block = $( "<div id='maxextend-div'>" )
		    .appendTo($(slidername));
		block.addClass('ui-slider-range');
		block.addClass('ui-slider-range-max');
		block.css("background", "grey");
		block.css("width", "" + (1000-setvalue)/1000 * 100 + "%");

		var days   = parseInt(maxextend / 24);
		var hours  = maxextend % 24;
		var length;
		if (days) {
		    length = days + " days";
		}
		if (hours) {
		    if (days)
			length = length + " and ";
		    length = length + hours + " hours ";
		}
		var message = "You may not extend this experiment " +
		    "beyond " + length +
		    "because of a pre-scheduled resource reservation. " +
		    "Please be sure to save your " +
		    "work before your experiment is terminated!";

		$('#maxextend-div').popover({
		    trigger:   'manual',
		    placement: 'auto',
		    container: 'body',
		    html:      true,
		    content:   message,
		});
		$('#maxextend-div').data("popped", 0);

		$(modalname).on('hide.bs.modal', function (e) {
		    if ($('#maxextend-div').data("popped")) {
			$('#maxextend-div').popover("hide");
			$('#maxextend-div').data("popped", 0);
		    }
		    $(modalname).off('hide.bs.modal');
		});
	    }
	}

	/*
	 * Pick which instructions to show (label number) based on number
	 * of phys/virt nodes. Hacky.
	 */
	function PickInstructions(hours) {
	    var days = hours / 24;
	    // No physical nodes, we require minimal info and will always
	    // grant the extension.
	    if (physnode_count == 0) return 0;
	    // Long term extension request, must justify.
	    if (days > (12 * 7)) return 3;
	    // Under 10 days of node hours used and asking for a short
	    // extension, minimal info is okay. 
	    if (physnode_hours < (10 * 24) && (physnode_count * days) <= 10) {
		return 0;
	    }
	    if (days <= 7) {
		return 0;
	    }
	    if (days < (12 * 7)) {
		return 1;
	    }
	    return 2;
	}

	function HoursToSetvalue(hours)
	{
	    var setvalue = 0;
	    var day = hours / 24;

	    if (day == 0) {
		setvalue = 0;
	    }
	    else if (day > 0 && day <= 6) {
		setvalue = Math.floor((day - 1) * (330 / 6.0));
	    }
	    else if (day <= 20) {
		setvalue = Math.round((day - 7) * (330 / 20.0)) + 330;
	    }
	    else if (day <= SLIDERLIMIT) {
		setvalue = Math.round(((day / 7) - 4) * (330 / 8.0)) + 660;
	    }
	    else {
		setvalue = 1000;
	    }
	    console.info("setvalue", hours, day, setvalue);
	    return setvalue;
	}

	/*
	 * User has changed the slider. Show new instructions.
	 */
	var minchars  = 120; // For the character countdown.
	var lastvalue = 0;   // Last callback value.
	var lastlabel = 0;   // So we know which div to hide.
	var setvalue  = 0;   // where to jump the slider to after stop.
	function SliderChanged(event, which) {
	    var slider   = $(slidername);

	    if (lastvalue == which) {
		return false;
	    }

	    /*
	     * This is hack to achive a non-linear slider. 
	     */
	    var extend_value = "1 day";
	    if (which <= 330) {
		var divider  = 330 / 6.0;
		var day      = Math.round(which / divider) + 1;
		extend_value = day + " days";
		setvalue     = Math.round((day - 1) * divider);
		howlong      = day * 24;
	    }
	    else if (which <= 660) {
		var divider  = 330 / 20.0;
		var day      = Math.round((which - 330) / divider) + 7;
		extend_value = day + " days";
		setvalue     = Math.round((day - 7) * divider) + 330;
		howlong      = day * 24;
	    }
	    else if (which <= 970) {
		var divider  = 330 / 8.0;
		var week     = Math.round((which - 660) / divider) + 4;
		extend_value = week + " weeks";
		setvalue     = Math.round((week - 4) * divider) + 660;
		howlong      = week * 7 * 24;
	    }
	    else {
		extend_value = "Longer";
		setvalue     = 1000;
		// User has to fill in the date box, then we can figure
		// it out. 
		howlong      = null;
	    }
	    if (maxextend != null) {
		if (howlong && howlong > maxextend) {
		    if (! $('#maxextend-div').data("popped")) {
			$('#maxextend-div').popover("show");
			$('#maxextend-div').data("popped", 1);
		    }
		}
		else {
		    if ($('#maxextend-div').data("popped")) {
			$('#maxextend-div').popover("hide");
			$('#maxextend-div').data("popped", 0);
		    }
		}
		if ((howlong == null && maxextend < SLIDERLIMIT) ||
		    howlong > maxextend) {
		    event.preventDefault();
		    howlong = maxextend;
		    setvalue = which = HoursToSetvalue(maxextend);
		    $(slidername).slider("value", setvalue);
		    // "trigger" another slider changed event
		    //SliderChanged(event, $(slidername).slider("value"));
		    //return;
		}
	    }
	    console.info(howlong);
	    $('#extend_value').html(extend_value);

	    var label = 0;
	    if (howlong) {
		label = PickInstructions(howlong);
	    }
	    else {
		label = 2;
	    }
	    $('#label' + lastlabel + "_request").addClass("hidden");
	    $('#label' + label + "_request").removeClass("hidden");

	    if (howlong) {
		$('#future_usage').val(Math.round(physnode_count * howlong));
	    }

	    // For the char countdown below.
	    minchars = $('#label' + label + "_request").attr('data-minchars');
	    UpdateCountdown();

	    lastvalue = which;
	    lastlabel = label;
	    return true;
	}

	// Jump to closest stop when user finishes moving.
	function SliderStopped(which) {
	   // $(slidername).slider("value", setvalue);
	}

	function UpdateCountdown() {
	    var len   = $('#why_extend').val().length;
	    var msg   = "";

	    if (len) {
		var left  = minchars - len;
		if (left <= 0) {
		    left = 0;
		    $('#extend_counter_alert').addClass("hidden");
		    EnableSubmitButton();
		}
		else if (left) {
		    msg = "You need at least " + left + " more characters";
		    $('#extend_counter_alert').removeClass("hidden");
		    DisableSubmitButton();
		}
	    }
	    else {
                msg = "You need at least " + minchars + " more characters";
                $('#extend_counter_alert').removeClass("hidden");
		DisableSubmitButton();
	    }
	    $('#extend_counter_msg').html(msg);
	}

	/*
	 * Convert date to howlong in days.
	 */
	function DateToHours(str)
	{
	    var today = new Date();
	    var later = new Date(str);
	    var diff  = (later - today);
	    if (diff < 0) {
		alert("No time travel to the past please");
		$("#datepicker").focus();
		return 0;
	    }
	    var hours = parseInt((diff / 1000) / 3600);
	    return (hours < 1 ? 1 : hours);
	}

	function HoursToEnglish(hours)
	{
	    var days  = parseInt(hours / 24);
	    var hours = hours % 24;
	    var str;

            if (days) {
		str = days + " days";
		if (hours) {
                    str = str + " " + hours + " hours";
		}
            }
	    else if (hours) {
		str = hours + " hours";
            }
            else {
		str = "nothing";
            }
	}
	
	//
	// Request experiment extension. 
	//
	function RequestExtension()
	{
	    var reason  = "";

	    if (howlong == null) {
		/*
		 * The value comes from the datepicker.
		 */
		if ($('#datepicker').val() == "") {
		    alert("You have to specify a date!");
		    $("#datepicker").focus();
		    return;
		}
		howlong = DateToHours($('#datepicker').val());
	    }
	    reason = $("#why_extend").val();
	    if (reason.trim().length == 0) {
		$("#why_extend").val("");
		DisableSubmitButton();
		alert("Come on, say something useful please, " +
		      "we really do read these!");
		return;
	    }
	    if (reason.length < minchars) {
		alert("Your reason is too short. Say more please, " +
		      "we really do read these!");
		return;
	    }
	    // Save this for next time we show the modal.
	    extension_info.extension_reason = reason;

	    var args = {"uuid"   : uuid,
			"howlong": howlong,
			"reason" : reason};
	    // Pass through to store with the extension info; harmless if
	    // the user browser messes with it.
	    if (maxextend_date) {
		args["maxextension"] = maxextend_date;
	    }
	    sup.HideModal('#extend_modal', function () {
		sup.ShowWaitWait("This will take a minute; patience please!");
		var xmlthing = sup.CallServerMethod(null, "status",
						    "RequestExtension", args);
		xmlthing.done(function(json) {
		    console.info("RequestExtension:", json);
		    sup.HideWaitWait(function () {
			callback(json);
		    });
		    return;
		});
	    });
	}
	
	//
	// Request as much time as possible, up to the maximum allowed
	// by the reservation system. Put up a modal for confirmation.
	//
	function RequestMaxExtension(hours, actual)
	{
	    $('#restricted_extend_modal #hours').html(hours);

	    // Throw it back to the caller when done.
	    var requestcallback = function(json) {
		sup.HideWaitWait();
		console.info(json.value);
		callback(json);
		return;
	    };
	    // Setup a handler for the confirm button.
	    $('#restricted_extend_modal #confirm-max').click(function(event) {
		sup.HideModal('#restricted_extend_modal');
		sup.ShowWaitWait("This will take a minute; patience please!");

		var reason = "Max allowed extension of " + hours + " hours";
		var xmlthing = sup.CallServerMethod(null,
						    "status",
						    "RequestExtension",
						    {"uuid"   : uuid,
						     "howlong": hours,
						     "reason" : reason,
						    });
		xmlthing.done(requestcallback);
	    });
	    sup.ShowModal('#restricted_extend_modal');
	}

	function EnableSubmitButton()
	{
	    ButtonState('button#request-extension', 1);
	}
	function DisableSubmitButton()
	{
	    ButtonState('button#request-extension', 0);
	}
	function ButtonState(button, enable)
	{
	    if (enable) {
		$(button).removeAttr("disabled");
	    }
	    else {
		$(button).attr("disabled", "disabled");
	    }
	}
	return function(thisuuid, func, studly, guest, expinfo)
	{
	    uuid     = thisuuid;
	    callback = func;
	    expires  = expinfo.expires;
	    extension_info = expinfo.extension_info;
	    physnode_count = expinfo.physnode_count;
	    physnode_hours = expinfo.physnode_hours;

	    $(divname).html(userExtendString);
	    
	    // Fill in the mailto links.
	    var mailto  = "mailto:" + window.SUPPORT;
	    var support = window.APTTILE + " support";
	    $('.supportmail').attr("href", mailto);
	    $('.supportmail').html(support);

	    // We have to wait till the modal is shown to actually set up
	    // some of the content, since we need to know its width.
	    $(modalname).on('shown.bs.modal', function (e) {
		Initialize();
		if (extension_info.extension_reason != "") {
		    $("#why_extend").text(extension_info.extension_reason);
		    $("#why_extend_div").removeClass("hidden");
		}
		if (! guest) {
		    $('#myusage-popover').popover({
			trigger: 'hover',
			placement: 'right',
		    });
		}
		$(modalname).off('shown.bs.modal');
	    });

	    /*
	     * We have to request the max extension before we can setup
	     * the slider. 
	     */
	    var maxcallback = function(json) {
		sup.HideModal('#waitwait-modal');
		if (json.code) {
		    console.info("Failed to get max extension: ", json);
		    $('#error-extend-modal .modal-body').text(json.value);
		    sup.ShowModal("#error-extend-modal");
		    return;		    
		}
		/*
		 * Allow override for testing.
		 */
		var later;
		
		if (window.APT_OPTIONS.MAXEXTEND != null) {
		    later = new Date();
		    later = new Date(later.getTime() + 60 +
				     (window.APT_OPTIONS.MAXEXTEND*3600*1000));
		}
		else {
		    later = new Date(json.value.maxextension);
		    maxextend_date = json.value.maxextension;
		}
		console.info("Max extension date:", later);
		
		/*
		 * See if the difference is less then a day.
		 */
		var now   = new Date(expires);
		var diff  = (later.getTime() - now.getTime()) / (1000 * 3600.0);
		var hours = Math.floor(diff);
		console.info("MaxExtension", now, later, diff, hours);
	
		if (hours == 0) {
		    sup.ShowModal('#no_extend_modal');
		}
		else if (hours < 24) {
		    // Different path; request as much as we can get.
		    RequestMaxExtension(hours, later);
		}
		else {
		    // Maximum number of days beyond current expiration!
		    maxextend = hours;
		    // Show the modal, it is initialized above. 
		    $(modalname).modal('show');
		}
	    }
	    sup.ShowModal('#waitwait-modal');
	    var xmlthing =
		sup.CallServerMethod(null, "status", "MaxExtension",
				     {"uuid" : uuid});
	    xmlthing.done(maxcallback);
	}
    }
)();
});
