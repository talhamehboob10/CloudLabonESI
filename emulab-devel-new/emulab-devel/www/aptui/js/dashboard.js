$(function ()
{
    'use strict';
    var templates = APT_OPTIONS.fetchTemplateList(['dashboard']);
    var dashboardTemplate = _.template(templates['dashboard']);
    var clusterFiles      = ["cloudlab-nofed.json", "cloudlab-fedonly.json"];
    var clusterStats      = {};
    var amlist            = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	amlist = JSON.parse(_.unescape($('#amlist-json')[0].textContent));
	console.info(amlist);

	DashboardLoop();
	setInterval(DashboardLoop,30000);
	setInterval(UpdateTimes,1000);
    }

    function DashboardLoop()
    {
	var callback = function(json) {
	    //console.log(json);
	    if (json.code) {
		console.log("Could not get dashboard data: " + json.value);
		return;
	    }
	    var dashboard_html = dashboardTemplate({"dashboard": json.value,
						    "isadmin"  : window.ISADMIN,
						    "isfadmin" : window.ISFADMIN});
	    $('#page-body').html(dashboard_html);
	    $('#last-refresh').data("time",new Date());
	    
	    // Format dates with moment before display.
	    $('.format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html())
				 .format("ddd h:mm A"));
		}
	    });
	    $('.format-date-withday').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html())
				 .format("MMM D h:mm A"));
		}
	    });
	    $('.format-date-month').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html())
				 .format("ll"));
		}
	    });
	    $('.format-date-relative').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).fromNow());
		}
	    });
	    $('[data-toggle="popover"]').popover({
		trigger: 'hover',
		placement: 'auto',
		html: true,
		content: function () {
		    var uuid = $(this).data("uuid");
		    var html = "<code style='white-space: pre-wrap'>" +
			json.value.error_details[uuid].message + "</code>";
		    return html;
		}
	    });
	    UpdateTimes();
	    UpdateClusterSummary(json.value.typecounts);
	}
	var xmlthing = sup.CallServerMethod(null, "dashboard",
					    "GetStats", null);
	xmlthing.done(callback);
    }

    function UpdateTimes()
    {
        $('.format-date-last-refresh').each(function() {
            var date = $(this).data("time");
            if (date != "") {
                $(this).html(moment(date).fromNow());
            }
        });

    }

    /*
     * Grab the JSON files and reduce it down.
     */
    function UpdateClusterSummary(typecounts)
    {
	var UpdateTable = function() {
	    var html = "";
	    
	    $.each(clusterStats, function(name, site) {
		html = html +
		    "<tr>" +
		    "<td>" + name + "</td>" +
		    "<td>" + site.ratio + "%" + "</td>" +
		    "<td>" + site.inuse + "</td>" +
		    "<td>" + site.total + "</td>" +
		    "</tr>";
	    });
	    //console.info(html);
	    $('#cluster-status-tbody').html(html);
	};

	if (!window.MAINSITE) {
	    $.each(typecounts, function(site, types) {
		var stats = {"total" : 0,
			     "inuse" : 0,
			     "ratio" : 0,
			     "types" : {}};
	    
		$.each(types, function(type, data) {
		    var inuse = data.count - data.free;
		    var total = data.count - 0;
		
		    stats.types[data.type] =
			{"total" : total,
			 "inuse" : inuse,
			 "ratio" : Math.round((inuse / total) * 100)}; 
						  
		    stats.total += total;
		    stats.inuse += inuse;
		    stats.ratio = Math.round((stats.inuse / stats.total) * 100);
		});
		clusterStats[site] = stats;
	    });
	    UpdateTable();
	    return;
	}
	/*
	 * The only reason for using these json files is cause we encode
	 * what node types we care about in the Cloudlab Portal.
	 */
	for (var index = 0; index < clusterFiles.length; index++) {
	    var jqxhr = $.getJSON(clusterFiles[index], function(blob) {
		$.each(blob.children, function(idx, site) {
		    if (!_.has(amlist, site.name)) {
			return;
		    }
		    var stats = {"total" : 0,
				 "inuse" : 0,
				 "ratio" : 0,
				 "types" : {}};
		
		    $.each(site.children, function(idx, type) {
			stats.types[type.name] =
			    {"total" : type.size,
			     "inuse" : type.howfull,
			     "ratio" : Math.round((type.howfull /
						   type.size) * 100)}; 
						  
			stats.total += type.size;
			stats.inuse += type.howfull;
			stats.ratio = Math.round((stats.inuse /
						  stats.total) * 100);
		    });
		    clusterStats[site.name] = stats;
		});
		UpdateTable();
	    })
	    .fail(function() {
		console.log( "error" );
	    });
	}
    }

    $(document).ready(initialize);
});
