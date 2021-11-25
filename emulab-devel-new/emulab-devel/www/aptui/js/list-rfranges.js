$(function ()
{
    'use strict';
    var templates      = APT_OPTIONS.fetchTemplateList(['list-rfranges',
				       'waitwait-modal', 'oops-modal']);
    var template       = _.template(templates['list-rfranges']);
    var waitwait       = templates['waitwait-modal'];
    var oops           = templates['oops-modal'];
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	var xmlthing1 =
	    sup.CallServerMethod(null, "rfrange", "GlobalRanges");
	var xmlthing2 =
	    sup.CallServerMethod(null, "rfrange", "AllProjectRanges");
	var xmlthing3 =
	    sup.CallServerMethod(null, "rfrange", "AllInuseRanges");

	$.when(xmlthing1, xmlthing2, xmlthing3)
	    .done(function(result1, result2, result3) {
		console.info(result1, result2, result3);

		var args = {
		    "global_ranges"  : result1.value,
		    "project_ranges" : result2.value,
		    "inuse_ranges"   : result3.value,
		};
		$('#main-body').html(template(args));

		if (_.size(result1.value)) {
		    $('#global-ranges').removeClass("hidden");

		    $('#global-ranges .tablesorter')
			.tablesorter({
			    theme : 'bootstrap',
			    widgets: ["uitheme", "zebra"],
			    headerTemplate : '{content} {icon}',
			});
		}
		if (_.size(result2.value)) {
		    $('#project-ranges').removeClass("hidden");

		    $('#project-ranges .tablesorter')
			.tablesorter({
			    theme : 'bootstrap',
			    widgets: ["uitheme", "zebra"],
			    headerTemplate : '{content} {icon}',
			});
		}
		if (_.size(result3.value)) {
		    $('#inuse-ranges').removeClass("hidden");

		    $('#inuse-ranges .tablesorter')
			.tablesorter({
			    theme : 'bootstrap',
			    widgets: ["uitheme", "zebra"],
			    headerTemplate : '{content} {icon}',
			});
		}
	    });
    }
    $(document).ready(initialize);
});
