$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['news',
						   'news-item',
						   'oops-modal',
						   'confirm-modal']);
    var newsString       = templates['news'];
    var oopsString       = templates['oops-modal'];
    var confirmString    = templates['confirm-modal'];
    var newsitemString   = templates['news-item'];
    var newsitemTemplate = _.template(newsitemString);
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);

	$('#main-body').html(newsString);
	$('#oops_div').html(oopsString);	
	$('#confirm_div').html(confirmString);

	/*
	 * Always a handler for more news items
	 */
	$('#more-entries').click(function (event) {
	    event.preventDefault();
	    DisplayNewsItems();
	});

	// Show the new new link if an admin.
	if (window.ISADMIN) {
	    $('#new-news').removeClass("hidden");
	}

	/*
	 * Ask for and display news items
	 */
	DisplayNewsItems();
    }

    /*
     * Ask for several news items, starting at the current index.
     */
    function DisplayNewsItems()
    {
	var count = 6;
	
	var callback = function(json) {
	    console.info(json.value);

	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // No more entries, kill the More Entries clicker.
	    if (json.value.length < count) {
		$('#more-entries').addClass("hidden");
		if (json.value.length == 0) {
		    return;
		}
	    }
	    _.each(json.value, function(blob) {
		//console.info(blob);
		var idx  = blob.idx;
		// Convert the body from markdown.
		blob.body = marked(blob.body);
		
		var html = newsitemTemplate({"fields"  : blob,
					     "isadmin" : window.ISADMIN});
		$('#blog-main').append(html);

		$('#post-' + idx + ' .format-date').each(function() {
		    var date = $.trim($(this).html());
		    if (date != "") {
			$(this).html(moment($(this).html()).format("lll"));
		    }
		});
		$('#post-' + idx + ' #delete-button').click(function() {
		    DeletePost(idx);
		});
		$('#post-' + idx + ' [data-toggle="popover"]').popover({
		    trigger: 'click',
		    placement: 'auto',
		    container: 'body',
		});

		// Update our current news index for more entries later.
		window.IDX = idx;
	    });
	    // But we want to get more at the next lower index.
	    window.IDX--;
	}
	var xmlthing = sup.CallServerMethod(null, "news",
					    "getnews",
					    {"idx"   : window.IDX,
					     "count" : count});
	xmlthing.done(callback);
    }

    /*
     * Delete a Post.
     */
    function DeletePost(idx) {
	// Callback for the delete request.
	var callback = function (json) {
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    $('#post-' + idx).remove();
	};
	// Bind the confirm button in the modal. Do the deletion.
	$('#confirm_modal #confirm_delete').click(function () {
	    sup.HideModal('#confirm_modal');
	    var xmlthing = sup.CallServerMethod(null, "news",
						"delete",
						{"idx" : idx});
	    xmlthing.done(callback);
	});
	// Handler so we know the user closed the modal. We need to
	// clear the confirm button handler.
	$('#confirm_modal').on('hidden.bs.modal', function (e) {
	    $('#confirm_modal #confirm_delete').unbind("click");
	    $('#confirm_modal').off('hidden.bs.modal');
	})
	sup.ShowModal("#confirm_modal");
    }
    
    $(document).ready(initialize);
});


