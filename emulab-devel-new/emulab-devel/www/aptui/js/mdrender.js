$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['mdrender', 'oops-modal']);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	
	$('#main-body').html(templates['mdrender']);
	$('#oops-div').html(templates['oops-div']);

	// Standard option
	marked.setOptions({"sanitize" : true});

	$('#render-button').click(function (event) {
	    console.info(event);
	    $('#rendered div').html(marked($('#markdown textarea').val()));
	    $('#rendered').parent().removeClass("hidden");
	})
    }
    $(document).ready(initialize);
});
