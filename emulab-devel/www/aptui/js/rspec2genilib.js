$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['rspec2genilib', 'waitwait-modal', 'oops-modal']);
    var mainString = templates['rspec2genilib'];
    var waitString = templates['waitwait-modal'];
    var oopsString = templates['oops-modal'];
    var mainTemplate    = _.template(mainString);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	
	$('#main-body').html(mainString);
	$('#waitwait_div').html(waitString);
	$('#oops_div').html(oopsString);

	//
	// Fix for filestyle problem; not a real class I guess, it
	// runs at page load, and so the filestyle'd button in the
	// form is not as it should be.
	//
	$('#rspec-upload-button').each(function() {
	    $(this).filestyle({input      : false,
			       buttonText : $(this).attr('data-buttonText'),
			       classButton: $(this).attr('data-classButton')});
	});
	//
	// File upload handler.
	// 
	$('#rspec-upload-button').change(function() {
	    var reader = new FileReader();
	    var button = $(this);

	    reader.onload = function(event) {
		var newrspec = event.target.result;
		    
		/*
		 * Clear the file so that the change handler will
		 * run if the same file is selected again (say, after
		 * fixing a script error).
		 */
		$("#rspec-upload-button").filestyle('clear');
		$("#rspec-textarea").val(newrspec);
		$('#convert-button').removeAttr("disabled");
	    };
	    reader.readAsText(this.files[0]);
	});
	// Enable button when the textarea changes.
	$('#rspec-textarea').change(function() {
	    $('#convert-button').removeAttr("disabled");
	});
	// Send off rspec to server for conversion.
	$('#convert-button').click(function (event) {
	    event.preventDefault();
	    ConvertRspec();
	});
    }

    function ConvertRspec()
    {
	var rspec = $.trim($('#rspec-textarea').val());
	if (!rspec.length) {
	    return;
	}
	console.info(rspec);
	
	var callback = function(json) {
	    console.info(json);
	    sup.HideWaitWait();
	
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $('#genilib-textarea').text(json.value);
	};
	sup.ShowWaitWait("We are converting your rspec to geni-lib");
	var xmlthing = sup.CallServerMethod(null, "rspec2genilib", "Convert",
					    {"rspec" : rspec});
	xmlthing.done(callback);
    }
    
    $(document).ready(initialize);
});


