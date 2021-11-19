$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['images',
						   "image-format-modal"]);
    var mainTemplate = _.template(templates['images']);
    var formatTemplate = _.template(templates['image-format-modal']);
    var filterindex = 7;
    var showformat = false;

    /*
     * Add urn copy-to-clipboard popovers.
     */
    var urnPopoverContent = function (urn) {
	var string =
	    "<div style='width 100%'> "+
	    "  <input readonly type=text " +
	    "       style='display:inline; width: 93%; padding: 2px;' " +
	    "       class='form-control input-sm' "+
	    "       value='" + urn + "'>" +
	    "  <a href='#' class='btn urn-copy-button' " +
	    "     style='padding: 0px'>" +
	    "    <span class='glyphicon glyphicon-copy'></span></a></div>";
	return string;
    };
    function addUrnPopovers(id)
    {
	sup.addPopoverClip('#' + id + ' .urn-button',
			   function (target) {
			       var urn = $(target).data("urn");
			       return urnPopoverContent(urn);
			   });
    }

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	// Image data
	var images = JSON.parse(_.unescape($('#images-json')[0].textContent));
	console.info("images", images);

	// We show the format only if there is more then one format type.
	var formats = {};
	_.each(images, function(value, index) {
	    formats[value.format] = 1;
	});
	if (Object.keys(formats).length > 1) {
	    showformat = true;
	    filterindex++;
	}

	// Generate the main template.
	var html = mainTemplate({
	    "images"  : images,
	    "all"     : window.ISADMIN && window.ALL,
	    "isadmin" : window.ISADMIN,
	    "manual"  : window.MANUAL,
	    "showformat" : showformat,
	});
	$('#main-body').html(html);
	$('#image-format-modal_div').html(formatTemplate({}));

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    placement: 'auto',
	});
	// This activates the tooltip subsystem.
	$('[data-toggle="tooltip"]').tooltip({
	    delay: {"hide" : 500, "show" : 150},
	    placement: 'auto',
	});

	// Set up the urn link popovers to the table.
	addUrnPopovers("images-table");
	
	// Bind handlers for the checkboxes.
	$('#my-images, #project-images, #public-images, ' +
	  '#admin-images, #system-images')
	    .change(function () {
		SetFilters();
	    });

	var table = $("#images-table")
	    .tablesorter({
		theme : 'bootstrap',
		widgets: ["uitheme", "zebra", "filter"],
		headerTemplate : '{content} {icon}',

		widgetOptions: {
		    // include child row content while filtering, if true
		    filter_childRows  : true,
		    // search from beginning
		    filter_startsWith : false,
		    // Set this option to false for case sensitive search
		    filter_ignoreCase : true,
		    // Only one search box.
		    filter_columnFilters : false,
		    // Search as typing
		    filter_liveSearch : true,
		},
	    });
	
	/*
	 * We have to implement our own live search cause we want to combine
	 * the search box with the checkbox filters. To do that, we have to
	 * call SetFilters() on the table directly. 
	 */
	var search_timeout = null;
	
	$("#images-search").on("search keyup", function (event) {
	    var userInput = $("#images-search").val();
	    window.clearTimeout(search_timeout);

	    search_timeout =
		window.setTimeout(function() {
		    var filters = $.tablesorter.getFilters($('#images-table'));
		    filters[filterindex] = userInput;
		    console.info("Search", filters);
		    $.tablesorter.setFilters($('#images-table'), filters, true);
		}, 500);
	});
	SetFilters();
    }

    function SetFilters()
    {
	var tmp = [];
	var filters = $.tablesorter.getFilters($('#images-table'));
	// The "any" filter needs a value or everything disappears.
	// If there is a term in the search box, it will have a value.
	if (filters[filterindex] === undefined) {
	    filters[filterindex] = "";
	}
	if ($('#my-images').is(":checked")) {
	    tmp.push("creator");
	}
	if ($('#project-images').is(":checked")) {
	    tmp.push("project");
	}
	if ($('#system-images').is(":checked")) {
	    tmp.push("system");
	}
	if ($('#public-images').is(":checked")) {
	    tmp.push("public");
	}
	if (window.ALL) {
	    if ($('#admin-images').is(":checked")) {
		tmp.push("admin");
	    }
	}
	if (tmp.length) {
	    // regex search, plain | does not work.
	    filters[filterindex - 1] = "/" + tmp.join("|") + "/";
	}
	else {
	    // Hmm, an empty string will get everything.
	    filters[filterindex - 1] = "WHY";
	}
	console.info("SetFilters", filters);
	$.tablesorter.setFilters($('#images-table'), filters, true);
    }
    
    $(document).ready(initialize);
});
