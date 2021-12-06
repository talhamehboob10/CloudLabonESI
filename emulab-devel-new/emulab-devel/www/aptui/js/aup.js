$(function ()
{
    'use strict';
    var template_list   = ["aup"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);
    var mainTemplate    = _.template(templates["aup"]);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#main-body').html(mainTemplate({}));
	$('#aup-panel .scrollable-panel').css("height",
					      $(document).height() - 300);
	$('#aup-panel .scrollable-panel').css("max-height",
					      $(document).height() - 300);

	$('#aup-panel .scrollable-panel').scroll(function () {
	    //console.info($(this).scrollTop(), $(this).innerHeight(),
	    //             $(this)[0].scrollHeight);
	    
	    if ($(this).scrollTop() + $(this).innerHeight() +2 >=
		$(this)[0].scrollHeight) {
		$('#confirm-aup').removeClass("disabled");
	    }
	});
	$.get(window.AUPURL, function(data) {
            $('#aup-panel .scrollable-panel').html(marked(data));
	});
	// Handler for confirm button.
	$('#confirm-aup').click(function (event) {
	    event.preventDefault();
	    Accept();
	});
	sup.ShowModal("#mustaccept-modal");
    }

    function Accept()
    {
	var callback = function(json) {
	    console.log(json);

	    if (json.code) {
		console.info("Could not accept license: " + json.value);
		return;
	    }
	    if (window.REFERRER === undefined) {
		window.location.replace("landing.php");
	    }
	    else {
		window.location.replace(window.REFERRER);
	    }

	};
    	var xmlthing = sup.CallServerMethod(null,"user-dashboard","AcceptAUP");
	xmlthing.done(callback);
    }
    $(document).ready(initialize);
});
