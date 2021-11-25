$(function ()
{
  'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['profile-history']);
    var ajaxurl = null;
    var profileTemplate = _.template(templates['profile-history']);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	ajaxurl  = window.AJAXURL;

	var profiles = JSON.parse(_.unescape($('#profiles-json')[0].textContent));
	var profile_html =
	    profileTemplate({profiles: profiles,
			     withpublishing: window.WITHPUBLISHING});
					    
	$('#history-body').html(profile_html);

	console.info(profiles);
    }
    $(document).ready(initialize);
});
