$(function () {
    window.gitrepo = (function () {
        var repoString    = APT_OPTIONS.fetchTemplate('gitrepo-picker');
	var repoTemplate  = _.template(repoString);
	var branchlist    = null;
	var taglist       = null;
	var uuid          = null;

	/*
	 * Get the branches and tags for a profile, and draw the picker.
	 */
	function InitRepoPicker(args)
	{
	    uuid = args.uuid;
	    
	    var callback = function(json) {
		console.info("InitRepoPicker", json);
	    
		if (json.code) {
		    console.info(json);
		    return;
		}
		branchlist = json.value.branchlist;
		taglist    = json.value.taglist;
		ShowRepoPicker(args);
		GetCommitInfo(args);
	    }
	    // Visible cue that something is happening
	    $('#gitpicker-div table').css("opacity", 0.4);

	    // We want to return the deferred.
	    return sup.CallServerMethod(null, "gitrepo", "GetBranchList",
					 {"uuid" : args.uuid}, callback);
	}

	function ShowRepoPicker(args)
	{
	    var html = repoTemplate({"branches" : branchlist,
				     "tags"     : taglist,
				     "uuid"     : uuid});
	    
	    $('#gitpicker-div').removeClass("hidden");
	    $('#gitpicker-div table').css("opacity", '');
	    $('#gitrepo-picker').html(html);
	    if (args.callback !== undefined) {
		$('.branch-button').click(function (event) {
		    event.preventDefault();
		    args.callback($(this).data("which"));
		});
	    }
	    // This activates the popover subsystem.
	    $('#gitpicker-div [data-toggle="popover"]').popover({
		trigger: 'hover',
		placement: 'auto',
		container: 'body'
	    });

	    sup.addPopoverClip('#gitpicker-div .refspec-share-button',
			       function (target) {
				   $(target).parent().popover('hide');
				   var refspec = $(target).data("which");
				   var url = args.share_url +
				       "?refspec=" + refspec;
				   return sup.popoverClipContent(url);
			       });
	}

	/*
	 * Get source code for a branch or tag and send it back to caller.
	 * Also update the info panel as on the manage/show page. 
	 */
	function GetRepoSource(args)
	{
	    var callback = function(json) {
		console.info("GetRepoSource", json);
	    
		if (json.code) {
		    sup.HideWaitWait();
		    sup.SpitOops("oops", json.value);
		    args.callback(null);
		    return;
		}
		sup.HideWaitWait(function() {
		    args.callback(json.value.script, json.value.hash);
		});
		GetCommitInfo(args);
	    }
	    sup.ShowWaitWait("We are getting the source code from the " +
			     "repository. Patience please.");
	    var xmlthing = sup.CallServerMethod(null,
						"gitrepo",
						"GetRepoSource",
						{"uuid"    : args.uuid,
						 "refspec" : args.refspec});
	    xmlthing.done(callback);
	}

	/*
	 * The manage/show page both have a panel for the currently
	 * loaded commit. Update that panel when we get new source.
	 */
	function UpdateInfoPanel(blob)
	{
	    $('#repoinfo-panel .commit-hash').text(blob.hash);
	    $('#repoinfo-panel .commit-author').html(blob.author);
	    $('#repoinfo-panel .commit-refspec').html(blob.refspec);
	    $('#repoinfo-panel .commit-size').html(blob.size);
	    $('#repoinfo-panel .commit-reponame').html(blob.reponame);
	    $('#repoinfo-panel .commit-date')
		.html(moment(blob.when).format("lll"));

	    var log = blob.log;
	    if (log.length <= 20) {
		$('#repoinfo-panel .commit-log-start').html(log);
		$('#repoinfo-panel .commit-log .log').addClass("hidden");
	    }
	    else {
		$('#repoinfo-panel .commit-log-start').html(log.substr(0,20));
		$('#repoinfo-panel .commit-log .log').popover('destroy');
		// DUMB! destroy is async. 
		setTimeout(function () {
		    $('#repoinfo-panel .commit-log .log').popover({
			trigger: 'hover',
			placement: 'auto',
			container: 'body',
			content: "<pre>" + log + "</pre>",
		    });}, 200);		
		$('#repoinfo-panel .commit-log .log').removeClass("hidden");
	    }
	    $('#repoinfo-panel .panel-body').css("opacity", '');
	    $('#repoinfo-panel').removeClass("hidden");
	}

	/*
	 * Ask for commit info, then update the info panel.
	 */
	function GetCommitInfo(args)
	{
	    var callback = function(json) {
		console.info("GetCommitInfo", json);
		
		if (json.code) {
		    console.info("GetCommitInfo", json.value);
		    return;
		}
		UpdateInfoPanel(json.value);
	    }
	    // Visible cue that something is happening
	    $('#repoinfo-panel .panel-body').css("opacity", 0.4);
	    var xmlthing = sup.CallServerMethod(null,
						"gitrepo",
						"GetCommitInfo",
						{"uuid" : args.uuid,
						 "refspec" : args.refspec});
	    xmlthing.done(callback);
	}

	/*
	 * Update from repo, possibly getting a new script or rspec.
	 */
	function UpdateRepo(uuid, caller_callback)
	{
	    var callback = function(json) {
		console.info("UpdateRepo", json);
	    
		if (json.code) {
		    sup.HideWaitWait();
		    sup.SpitOops("oops", json.value);
		    caller_callback(null);
		    return;
		}
		sup.HideWaitWait(function() {
		    caller_callback(json.value);
		});
	    }
	    sup.ShowWaitWait("We are attempting to pull from your repository. "+
			     "Patience please.");
	    var xmlthing = sup.CallServerMethod(null,
						"manage_profile",
						"UpdateRepository",
						{uuid : uuid});
	    xmlthing.done(callback);
	}

	// Exports from this module for use elsewhere
	return {
	    InitRepoPicker: InitRepoPicker,
	    GetRepoSource:  GetRepoSource,
	    UpdateRepo:     UpdateRepo,
	    GetCommitInfo:  GetCommitInfo,
	};
    })();
});
