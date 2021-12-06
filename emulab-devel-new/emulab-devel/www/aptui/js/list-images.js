$(function ()
{
    'use strict';

    var template_list   = ["image-list", "classic-image-list",
			   "oops-modal", "confirm-delete-image",
			   "waitwait-modal", "image-format-modal"];
    var templates       = APT_OPTIONS.fetchTemplateList(template_list);    
    var listTemplate    = _.template(templates["image-list"]);
    var classicTemplate = _.template(templates["classic-image-list"]);
    var confirmTemplate = _.template(templates["confirm-delete-image"]);
    var formatTemplate  = _.template(templates['image-format-modal']);
    var oopsString      = templates["oops-modal"];
    var waitwaitString  = templates["waitwait-modal"];
    var amlist = null;
    // Results for each AM so we can get it later. 
    var imagelist       = {};

    // Popover for the URN link
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	amlist = decodejson('#amlist-json');
	window.IMLIST = imagelist;

	$('#oops_div').html(oopsString);	
	$('#waitwait_div').html(waitwaitString);
	$('#image-format-modal_div').html(formatTemplate({}));

	LoadData();
	LoadClassic();
    }

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

    /*
     * Load images from each am in the list and generate a table.
     */
    function LoadData()
    {
	var count = Object.keys(amlist).length;
	
	_.each(amlist, function(urn, name) {
	    var callback = function(json) {
		var error = null;
		var images = null;
		var showformat = false;

		console.info(name, json);

		// Kill the spinner.
		count--;
		if (count <= 0) {
		    $('#spinner').addClass("hidden");
		}
		if (json.code) {
		    console.info(name + ": " + json.value);
		    error = json.value;
		}
		else {
		    images = json.value;
		    
		    if (images.length == 0) {
			// No images, say something.
			if (count <= 0 && Object.keys(imagelist) == 0) {
			    $('#no-images-message').removeClass("hidden");
			}
			return;
		    }
		    // Save for later
		    imagelist[name] = images;
		}
		// We show the format only if there is more then one
		// format type.
		var formats = {};
		_.each(images, function(value, index) {
		    _.each(value.versions, function(image, index) {
			formats[image.format] = 1;
		    });
		});
		if (Object.keys(formats).length > 1) {
		    showformat = true;
		}
		// Generate the main template.
		var html = listTemplate({
		    "images"       : images,
		    "showproject"  : window.TARGET_PROJECT === undefined,
		    "showuser"     : window.TARGET_PROJECT !== undefined,
		    "name"         : name,
		    "error"        : error,
		    "showformat"   : showformat,
		});
		html =
		    "<div class='row' id='" + name + "'>" +
		    " <div class='col-xs-12 col-xs-offset-0'>" + html +
		    " </div>" +
		    "</div>";

		$('#main-body').prepend(html);

		// On error, no need for the rest of this.
		if (error)
		    return;

		// Format dates with moment before display.
		$('#' + name + ' .format-date').each(function() {
		    var date = $.trim($(this).html());
		    if (date != "") {
			$(this).html(moment($(this).html()).format("lll"));
		    }
		});

		// Set up the urn link popovers to the table.
		addUrnPopovers(name);
		
		var TableInit = function(tablename) {
		    $('#' + name + ' #' + tablename).removeClass("hidden");
		    
		    var table =
			$('#' + name + ' #' + tablename)
			.tablesorter({
			    theme : 'bootstrap',
			    widgets: ["uitheme", "zebra"],
			    headerTemplate : '{content} {icon}',
			    cssChildRow : 'tablesorter-childRow-versions',
			});
		    
		    table.find('.tablesorter-childRow-versions')
			.addClass('hidden');

		    /*
		     * This little diddy sums up the filesizes for each
		     * image version, and writes into the filesize for
		     * the entire image.
		     */
		    table.find('tr.tablesorter-hasChildRow')
			.each(function() {
			    var sum = 0;
			    var re  = /^(\d+)MB$/;

			    $(this).nextUntil('tr.tablesorter-hasChildRow',
					      '.image-version')
				.each(function() {
				    var size = 
					$(this).find('td.version-filesize')
					.text();
				    var match = size.match(re);
				    if (match) {
					sum = sum + parseInt(match[1]);
				    }
				});
			    $(this).find('td.image-filesize').text(sum + "MB");
			});
		    table.trigger('update');
		    
		    // Toggle child row content. Using delegate cause the
		    // tablesorter example page says to.
		    table.delegate('.toggle-image', 'click', function() {
			// use "nextUntil" to toggle multiple child rows
			// toggle table cells instead of the row

			// Find add/even and add that to child rows so that
			// zebra strip is the same for its children.
			var stripe = "odd";
			if ($(this).closest('tr').hasClass("even")) {
			    stripe = "even";
			}

			$(this)
			    .closest('tr')
			    .nextUntil('tr.tablesorter-hasChildRow',
				       '.image-version')
			    .each(function() {
				// If going to hide the row, want to hide the
				// expanded profile tables too.
				if (! $(this).hasClass("hidden") &&
				    ! $(this).next(".profile-version")
				    .hasClass("hidden")) {
				    $(this)
					.find(".toggle-version")
					.trigger("click");
				}
				$(this)
				    .toggleClass('hidden')
				    .addClass(stripe);
			    });
			$(this).find(".glyphicon")
			    .toggleClass("glyphicon-chevron-right")
			    .toggleClass("glyphicon-chevron-down");
			return false;
		    });
		    table.find(".toggle-version")
			.click(function(event) {
			    event.preventDefault();
			    $(this).closest('tr')
				.next('tr').toggleClass('hidden');
			    $(this).find(".glyphicon")
				.toggleClass("glyphicon-chevron-left")
				.toggleClass("glyphicon-chevron-down");
			});

		    // Bind a delete handler.
		    table.find(".delete-button").click(function(event) {
			event.preventDefault();
			DeleteImage(name, $(this).closest('tr'));
			return false;
		    });
		};
		// Only init/show tables that have something in them.
		if ($('#' + name + ' #images-table-no-profiles tbody')
		    .children().length) {
		    TableInit('images-table-no-profiles');
		}
		if ($('#' + name + ' #images-table-one-profile tbody')
		    .children().length) {
		    TableInit('images-table-one-profile');
		}
		if ($('#' + name + ' #images-table-multi-profile tbody')
		    .children().length) {
		    TableInit('images-table-multi-profile');
		}

		// This activates the popover subsystem.
		$('#' + name + ' [data-toggle="popover"]').popover({
		    trigger: 'hover',
		    placement: 'auto',
		    container: 'body',
		});
		
	    }
	    var args = {"cluster" : name};
	    if (window.TARGET_PROJECT !== undefined) {
		args["pid"] = window.TARGET_PROJECT;
	    }
	    else {
		args["uid"] = window.TARGET_USER;
	    }
	    var xmlthing = sup.CallServerMethod(null, "images",
						"ListImages", args);

	    xmlthing.done(callback);
	});
    }

    /*
     * Delete an Image. Delete the table row when completed
     */
    function DeleteImage(cluster, row) {
	var urn      = $(row).attr('data-urn');
	var index    = parseInt($(row).attr('data-index'));
	var table    = $(row).closest("table");
	console.info(cluster, urn, index);

	// Callback for the delete request.
	var callback = function (json) {
	    sup.HideWaitWait();
	    console.log("delete", json);
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Now to delete the row. This has a little trickiness.
	    if ($(row).hasClass("image-version")) {
		var imageindex = parseInt($(row).attr('data-imageindex'));
		
		//
		// Individual version, delete the row. There should not be
		// a following profile versions row, but watch for it
		// anyway.
		//
		if ($(row).next().hasClass("profile-version")) {
		    $(row).next().remove();
		}
		/*
		 * Is this is the last version of the image, then delete
		 * the image row too. We determine this by looking to see
		 * if the previous row is an image row, and the next row
		 * is an image row (or no row, so last image in the table). 
		 */
		var prev = $(row).closest('tr').prev('tr');
		var next = $(row).closest('tr').next('tr');
		if ($(prev).is("tr.tablesorter-hasChildRow") &&
		    ($(next).is("tr.tablesorter-hasChildRow") ||
		     !$(next).is("tr"))) {
		    $(prev).remove();
		}
		$(row).remove();

		// Mark the image version as deleted in the data object.
		imagelist[cluster][imageindex]
		    .versions[index]["deleted"] = true;
	    }
	    else {
		/*
		 * Entire image delete (all versions). Need to delete the
		 * main row and all rows up to the next image.
		 */
		$(row).closest('tr')
		    .nextUntil('tr.tablesorter-hasChildRow', '.image-version')
		    .remove();
		$(row).remove();

		// Mark the entire image as deleted in the data object.
		imagelist[cluster][index]["deleted"] = true;
	    }
	    table.trigger('update');
	};
	var args = {"urn"     : urn,
		    "pid"     : imagelist[cluster][index]["pid"],
		    "cluster" : cluster};
	/*
	 * Look to see if this is a row with a profile in it, which
	 * should be deleted along with the image. Pass that along,
	 * the backend is going to check anyway.
	 */
	var profiles = null;
	if ($(row).find("td.delete-profile").length) {
	    var uuid = $(row).find("td.delete-profile").attr('data-uuid');
	    args["profile-delete"]  = uuid;
	    args["profile-delete-versions"] = [];
		

	    /*
	     * The confirm modal is a template in case we need to warn
	     * about profiles that will be deleted. Need to find that
	     * list in the saved data structure.
	     */
	    _.each(imagelist[cluster], function(image, index) {
		_.each(image.versions, function(version, index) {
		    if (version.urn == urn) {
			profiles = version.using;
			/*
			 * Add the version list to the args.
			 */
			_.each(profiles, function(profile, i) { 
			    _.each(profile.versions, function(version, j) {
				args["profile-delete-versions"]
				    .push(version.version);
			    });
			});
			// Just one profile can be deleted.
			return;
		    }
		});
	    });
	}
	/*
	 * Some extra text for the title of the confirm modal.
	 */
	var titletext = "";

	if ($(row).hasClass("naked-image")) {
	    // Extra warn about deleting the entire image.
	    titletext = " all versions of ";
	}
	else if ($(row).hasClass("image-version")) {
	    /*
	     * Warn about deleting highest numbered (most recent) version.
	     * Need to check the version list to see if this is the case,
	     * keeping in mind that versions might already have been marked
	     * as deleted.
	     */
	    var imageindex = parseInt($(row).attr('data-imageindex'));
	    var version    = parseInt($(row).attr('data-version'));
	    var max        = 0;

	    _.each(imagelist[cluster][imageindex].versions,
		   function(image, index) {
		       if (!image.deleted && image.version > max) {
			   max = image.version;
		       }
		   });
	    if (version >= max) {
		titletext = " the most recent version of ";
	    }
	}
	var html = confirmTemplate({
	    "profiles"  : profiles,
	    "titletext" : titletext,
	});
	$('#confirm_div').html(html);
	// Format dates with moment before display.
	$('#confirm_div .format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	
	// Bind the confirm button in the modal. Do the deletion.
	$('#confirm-delete-image-modal #confirm-delete-image')
	    .click(function () {
		sup.HideModal('#confirm-delete-image-modal');

		sup.ShowWaitWait('It takes a moment to delete an image; ' +
				 'patience please');

		var xmlthing = sup.CallServerMethod(null, "images",
						    "DeleteImage", args);
		xmlthing.done(callback);
	    });
	sup.ShowModal("#confirm-delete-image-modal",
		      // Delete handler no matter how it hides.
		      function () {
			  $('#confirm-delete-image-modal #confirm-delete-image')
			      .unbind("click");			  
		      });
    }

    /*
     * Load images from each am in the list and generate a table.
     */
    function LoadClassic()
    {
	var callback = function (json) {
	    console.log("classic", json);
	    if (json.code) {
		console.info("failed to get classic list: " + json.value);
		return;
	    }
	    if (json.value.length == 0) {
		return;
	    }
	    // We show the format only if there is more then one format type.
	    var formats = {};
	    _.each(json.value, function(value, index) {
		formats[value.format] = 1;
	    });
		   
	    var html = classicTemplate({
		"images"       : json.value,
		"showformat"   : Object.keys(formats).length > 1,
	    });
	    $('#classic-images-div').html(html);
	    // Format dates with moment before display.
	    $('#classic-images-table .format-date').each(function() {
		var date = $.trim($(this).html());
		if (date != "") {
		    $(this).html(moment($(this).html()).format("ll"));
		}
	    });
	    addUrnPopovers("classic-images-table");
	    $('#classic-images-div').removeClass("hidden");

	    var table = $('#classic-images-table')
		.tablesorter({
		    theme : 'bootstrap',
		    widgets: ["uitheme", "zebra", "filter"],
		    headerTemplate : '{content} {icon}',
		    
		    widgetOptions: {
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
	    $.tablesorter.filter.bindSearch(table, $('#classic-images-search'));
	}
	var args = {"uid" : window.TARGET_USER};
	
	var xmlthing = sup.CallServerMethod(null, "images",
					    "ClassicImages", args);
	xmlthing.done(callback);
    }
    
    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    $(document).ready(initialize);
});


