$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['edit-news',
						   'oops-modal',
						   'waitwait-modal',
						   'renderer-modal']);
    var mainString     = templates['edit-news'];
    var oopsString     = templates['oops-modal'];
    var waitwaitString = templates['waitwait-modal'];
    var rendererString = templates['renderer-modal'];
    var mainTemplate = _.template(mainString);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var fields = JSON.parse(_.unescape($('#form-json')[0].textContent));

	GeneratePageBody(fields);

	// Now we can do this. 
	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);	
	$('#renderer_div').html(rendererString);
    }

    //
    // Moved into a separate function since we want to regen the form
    // after each submit, which happens via ajax on this page. 
    //
    function GeneratePageBody(formfields)
    {
	// Generate the template.
	var html = mainTemplate({
	    formfields:		formfields,
	    editing:		window.EDITING,
	});
	html = aptforms.FormatFormFieldsHorizontal(html, {"wide" : true});
	$('#main-body').html(html);

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    container: 'body'
	});
	/*
	 * A double click handler that will render the body in a modal.
	 */
	$('#body').dblclick(function() {
	    var text = $(this).val();
	    $('#renderer_modal_div').html(marked(text));
	    sup.ShowModal("#renderer_modal");
	});

	/*
	 * Handler for updates to the example portals field, on the
	 * the Mothership, where we have multiple portals.
	 */
	if (window.MAINSITE) {
	    $('#edit-news-form .portals_checkbox').click(function(event) {
		var portals =
		    $('.portals_checkbox:checked')
		        .map(function() {
			    return $(this).data("portal");
			})
		        .get()
		        .join();
		
		$('#edit-news-form [name=portals]').val(portals);
	    });
	}
	
	//
	// Handle submit button.
	//
	$('#news-submit-button').click(function (event) {
	    event.preventDefault();
	    SubmitForm();
	});
	aptforms.EnableUnsavedWarning('#edit-news-form');
    }
    //
    // Submit the form.
    //
    function SubmitForm()
    {
	var submit_callback = function(json) {
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    window.location.replace(json.value);
	};
	var checkonly_callback = function(json) {
	    if (json.code) {
		if (json.code != 2) {
		    sup.SpitOops("oops", json.value);		    
		}
		return;
	    }
	    aptforms.SubmitForm('#edit-news-form', "news",
				(window.EDITING ? "modify" : "create"),
				submit_callback);
	};
	aptforms.CheckForm('#edit-news-form', "news",
			   (window.EDITING ? "modify" : "create"),
			   checkonly_callback);
    }

    $(document).ready(initialize);
});


