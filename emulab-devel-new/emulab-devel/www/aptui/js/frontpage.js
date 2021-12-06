$(function ()
{
    'use strict';
    var template_list   = ["frontpage", "frontpage-facility",
			   "frontpage-status", 
			   "oops-modal", "waitwait-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var mainTemplate    = _.template(templates["frontpage"]);
    var statusTemplate  = _.template(templates["frontpage-status"]);

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	// Generate the main template.
	var html = mainTemplate({
	});
	$('#main-body').html(html);
	$('#frontpage-facility').html(templates["frontpage-facility"]);
	$('.cluster-status').html(statusTemplate({"typeinfo" : {} }));
	$('#oops_div').html(templates["oops-modal"]);
	$('#waitwait_div').html(templates["waitwait-modal"]);

	updateFacilStats();
    }

    function updateFacilStats()
    {
        $.getJSON("stats-ajax.php", function(data, status) {
            if (status == "success") {
		$('.cluster-status').html(statusTemplate({
		    "typeinfo" : data.typeinfo
		}));
		_.each(data.typeinfo, function(info, type) {
                    var statusid   = "#facility-status-" + type;
                    var progressid = "#facility-full-" + type;
		    var total      = parseInt(info.total);
		    var free       = parseInt(info.free);

                    var pctfull = Math.round(100 * (total - free) / total);
                    $(statusid).html(free);
                    $(progressid).css("width", pctfull + "%");
                    $(progressid).text(pctfull + "% inuse");
		});
		
                $("#facility-experiments")
		    .text(Number(data["active_experiments"]).toLocaleString());
                $("#facility-total-experiments")
		    .text(Number(data["total_experiments"]).toLocaleString());
                $("#facility-total-users")
		    .text(Number(data["distinct_users"]).toLocaleString());
                $("#facility-total-projects")
		    .text(Number(data["projects"]).toLocaleString());
                $("#facility-profiles")
		    .text(Number(data["profiles"]).toLocaleString());
            }
        });
    }
    $(document).ready(initialize);
});
