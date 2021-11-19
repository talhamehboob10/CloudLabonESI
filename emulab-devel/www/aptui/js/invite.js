$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['invite']);
    var inviteTemplate    = _.template(templates['invite']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var fields   = JSON.parse(_.unescape($('#form-json')[0].textContent));
	var errors   = JSON.parse(_.unescape($('#error-json')[0].textContent));
	var projlist = JSON.parse(_.unescape($('#projects-json')[0].textContent));

	// Generate the templates.
	var invite_html = inviteTemplate({
	    formfields:		fields,
	    projects:		projlist,
	    general_error:      (errors.error || '')
	});
	$('#invite-body').html(aptforms.FormatFormFields(invite_html));

	// Handle submit button.
	$('#invite-submit-button').click(function (event) {
	    aptforms.DisableUnsavedWarning('#invite_form');
	});
	
	aptforms.GenerateFormErrors('#invite_form', errors);
	aptforms.EnableUnsavedWarning('#invite_form');
    }

    $(document).ready(initialize);
});
