
$(function ()
{
    'use strict';

    var templates = APT_OPTIONS
	.fetchTemplateList(['status', 'waitwait-modal',
			    'oops-modal', 'register-modal', 'terminate-modal',
			    'oneonly-modal', 'approval-modal', 'linktest-modal',
			    'linktest-md', "destroy-experiment",
			    "prestage-table", "frequency-graph"]);

    var statusString = templates['status'];
    var waitwaitString = templates['waitwait-modal'];
    var oopsString = templates['oops-modal'];
    var registerString = templates['register-modal'];
    var terminateString = templates['terminate-modal'];
    var oneonlyString = templates['oneonly-modal'];
    var approvalString = templates['approval-modal'];
    var linktestString = templates['linktest-modal'];
    var destroyString  = templates['destroy-experiment'];

    var expinfo     = null;
    var nodecount   = 0;
    var ajaxurl     = null;
    var uuid        = null;
    var oneonly     = 0;
    var isadmin     = 0;
    var isfadmin    = 0;
    var isguest     = 0;
    var isstud      = 0;
    var wholedisk   = 0;
    var isscript    = 0;
    var dossh       = 1;
    var jacksIDs    = {};
    var jacksSites  = {};
    var publicURLs  = null;
    var inrecovery  = {};
    var extension_blob    = null;
    var manifests         = {};
    var status_collapsed  = false;
    var status_message    = "";
    var status_html       = "";
    var statusTemplate    = _.template(statusString);
    var terminateTemplate = _.template(terminateString);
    var prestageTemplate  = _.template(templates['prestage-table']);
    var instanceStatus    = "";
    var lastStatus        = "";
    var lockdown_code     = "";
    var consolenodes      = {};
    var showlinktest      = false;
    var hidelinktest      = false;
    var projlist          = null;
    var amlist            = null;
    var lastSliverStatus  = null;
    var jacksInstance     = null;
    var changingtopo      = false;
    var slowdown          = false;
    var radioinfo         = null;
    var radios            = {};
    var monitorTemplate   = null;
    var EMULAB_OPS        = "emulab-ops";
    var EMULAB_NS = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
    var GENIRESPONSE_REFUSED = 7;
    var GENIRESPONSE_ALREADYEXISTS = 17;
    var GENIRESPONSE_INSUFFICIENT_NODES = 26;
    var MAXJACKSNODES = 300;

    // CONFIRM Hack. Fix later.
    var CONFIRMTYPES = [ "c6320", "c8220", "m400", "m510",
			 "c220g1", "c220g2" ];

    function TimeStamp(message)
    {
	if (0) {
	    var microtime = window.performance.now() / 1000.0
	    console.info("TIMESTAMP: " + microtime + " " + message);
	}
    }

    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	ajaxurl       = window.APT_OPTIONS.AJAXURL;
	uuid          = window.APT_OPTIONS.uuid;
	oneonly       = window.APT_OPTIONS.oneonly;
	isadmin       = window.APT_OPTIONS.isadmin;
	isfadmin      = window.APT_OPTIONS.isfadmin;
	isstud        = window.APT_OPTIONS.isstud;
	isguest       = (window.APT_OPTIONS.registered ? false : true);
	wholedisk     = window.APT_OPTIONS.wholedisk;
	dossh         = window.APT_OPTIONS.dossh;
	isscript      = window.APT_OPTIONS.isscript;
	hidelinktest  = window.APT_OPTIONS.hidelinktest;
	lockdown_code = uuid.substr(2, 5);

	// Standard option
	marked.setOptions({"sanitize" : true});

	if ($('#projects-json').length) {
	    projlist = decodejson('#projects-json');
	    // console.info(projlist);
	}
	amlist = decodejson('#amlist-json');
	console.info(amlist);
	if (window.ISPOWDER) {
	    radioinfo = decodejson('#radioinfo-json');
	    monitorTemplate = _.template(templates['frequency-graph']);
	}

	/*
	 * Need to grab the experiment info so we can draw the page.
	 */
	sup.CallServerMethod(null, "status", "ExpInfo",
			     {"uuid" : uuid},
			     function(json) {
				 console.info("expinfo", json);
				 if (json.code) {
				     console.info("Could not get experiment "+
						  "info: " + json.value);
				     return;
				 }
				 expinfo = json.value;
				 GeneratePageBody();
			     });
    }

    function GeneratePageBody()
    {
	instanceStatus  = expinfo.status;
	extension_blob  = expinfo.extension_info;

	// For tutorials
	if (expinfo.project == "sigcomm2019") {
	    slowdown = true;
	}
	
	// Generate the templates.
	var template_args = {
	    uuid:		uuid,
	    expinfo:            expinfo,
	    registered:		window.APT_OPTIONS.registered,
	    isadmin:            window.APT_OPTIONS.isadmin,
	    isfadmin:           window.APT_OPTIONS.isfadmin,
	    isstud:             window.APT_OPTIONS.isstud,
	    extensions:         extension_blob.extensions,
	    errorURL:           window.HELPFORUM,
	    lockdown_code:      lockdown_code,
	};
	var html = statusTemplate(template_args);
	$('#status-body').html(html);
	$('#waitwait_div').html(waitwaitString);
	$('#oops_div').html(oopsString);
	$('#register_div').html(registerString);
	$('#terminate_div').html(terminateTemplate(template_args));
	$('#oneonly_div').html(oneonlyString);
	$('#approval_div').html(approvalString);
	$('#linktest_div').html(linktestString);
	$('#destroy_div').html(destroyString);
	
	// Not allowed to copy repobased profiles.
	if (expinfo.repourl) {
	    $('#copy_button').addClass("hidden");
	}
	if (expinfo.started) {
	    $('.exp-running').removeClass("hidden");
	}

	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	ProgressBarUpdate();

	if (!slowdown) {
	    // Periodic check for max allowed extension
	    LoadMaxExtension();
	    setInterval(LoadMaxExtension, 3600 * 1000);
	}

	// This activates the popover subsystem.
	$('[data-toggle="popover"]').popover({
	    trigger: 'hover',
	    placement: 'auto',
	});
	$('[data-toggle="tooltip"]').tooltip({
	    placement: 'top',
	});

	// Use an unload event to terminate any shells.
	$(window).bind("unload", function() {
//	    console.info("Unload function called");
	
	    $('#quicktabs_content div').each(function () {
		var $this = $(this);
		// Skip the main profile tab
		if ($this.attr("id") == "profile") {
		    return;
		}
		var tabname = $this.attr("id");
	    
		// Trigger the custom event.
		$("#" + tabname).trigger("killssh");
	    });
	});

	// Take the user to the registration page.
	$('button#register-account').click(function (event) {
	    event.preventDefault();
	    sup.HideModal('#register_modal');
	    var uid   = expinfo.creator;
	    var email = expinfo.creator_email;
	    var url   = "signup.php?uid=" + uid + "&email=" + email + "";
	    var win   = window.open(url, '_blank');
	    win.focus();
	});

	// Setup the extend modal.
	$('button#extend_button').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    event.preventDefault();
	    if (isfadmin) {
		sup.ShowModal("#extend_history_modal");
		return;
	    }
	    if (expinfo.lockout && !isadmin) {
		if (extension_blob.extension_disabled_reason != "") {
		    $("#extensions-disabled-reason .reason")
			.text(extension_blob.extension_disabled_reason);
		    $("#extensions-disabled-reason").removeClass("hidden");
		}
		sup.ShowModal("#no-extensions-modal");
		return;
	    }
	    if (isadmin) {
		window.location.replace("adminextend.php?uuid=" + uuid);
		return;
	    }
            ShowExtendModal(uuid,
			    RequestExtensionCallback, isstud, isguest, expinfo);
	});
	
	// Handler for the refresh button
	$('button#refresh_button').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    event.preventDefault();
	    DoRefresh();
	});
	// Handler for the reload topology button
	$('button#reload-topology-button').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    event.preventDefault();
	    DoReloadTopology();
	});
	// Handler for the ignore failure button (in the modal).
	$('button#ignore-failure-confirm').click(function (event) {
	    event.preventDefault();
	    IgnoreFailure();
	});

	// Terminate an experiment.
	$('button#terminate').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    var lockdown_override = "";
	    event.preventDefault();
	    sup.HideModal('#terminate_modal');

	    if (expinfo.user_lockdown) {
		if (lockdown_code != $('#terminate_lockdown_code').val()) {
		    sup.SpitOops("oops", "Refusing to terminate; wrong code");
		    return;
		}
		lockdown_override =  $('#terminate_lockdown_code').val();
	    }
	    var callback = function(json) {
		sup.HideModal("#waitwait-modal");
		if (json.code) {
		    sup.SpitOops("oops", json.value);
		    return;
		}
		var url = 'landing.php';
		window.location.replace(url);
	    }
	    sup.ShowModal("#waitwait-modal");

	    var xmlthing = sup.CallServerMethod(ajaxurl,
						"status",
						"TerminateInstance",
						{"uuid" : uuid,
						 "lockdown_override" :
						   lockdown_override});
	    xmlthing.done(callback);
	});
	SetupWarnKill();
	SetupSnapshotModal();

	/*
	 * Attach an event handler to the profile status collapse.
	 * We want to change the text inside the collapsed view
	 * to the expiration countdown, but remove it when expanded.
	 * In other words, user always sees the expiration.
	 */
	$('#profile_status_collapse').on('hide.bs.collapse', function () {
	    status_collapsed = true;
	    // Copy the current expiration over.
	    var current_expiration = $("#instance_expiration").html();
	    $('#status_message').html("Experiment expires: " +
				      current_expiration);
	});
	$('#profile_status_collapse').on('show.bs.collapse', function () {
	    status_collapsed = false;
	    // Reset to status message.
	    $('#status_message').html(status_message);
	});
	// Chevron toggle handlers
	$('#profile_status_collapse, #profile_instructions_collapse')
	    .on('show.bs.collapse', function (event) {
		var id = $(this).data("chevron");
		$('#' + id + ' .glyphicon')
		    .removeClass("glyphicon-chevron-right")
		    .addClass("glyphicon-chevron-down");
	    })
	    .on('hide.bs.collapse', function (event) {
		var id = $(this).data("chevron");
		$('#' + id + ' .glyphicon')
		    .removeClass("glyphicon-chevron-down")
		    .addClass("glyphicon-chevron-right");

	    });
	if (instanceStatus == "ready") {
	    $('#profile_status_collapse').collapse("hide");
 	    $('#profile_status_collapse').trigger('hide.bs.collapse');
	}
	else {
	    $('#profile_status_collapse').collapse("show");
 	    $('#profile_status_collapse').trigger('show.bs.collapse');
	}
	
        $('#instructions').on('hide.bs.collapse', function () {
	    APT_OPTIONS.updatePage({ 'status_instructions': 'hidden' });
	});
        $('#instructions').on('show.bs.collapse', function () {
	    APT_OPTIONS.updatePage({ 'status_instructions': 'shown' });
	});
	$('#quicktabs_ul li a').on('shown.bs.tab', function (event) {
	    window.APT_OPTIONS.gaTabEvent("show",
					  $(event.target).attr('href'));
	});
	$('#prestage-panel .info-button').click(function (event) {
	    event.preventDefault();
	    sup.ShowModal('#prestage-info-modal');
	});
	
        addTutorialNotifyTab('profile');
        addTutorialNotifyTab('listview');
        addTutorialNotifyTab('manifest');
        addTutorialNotifyTab('Idlegraphs');
	StartCountdownClock(expinfo.expires);
	StartStatusWatch();
	if (window.APT_OPTIONS.oneonly) {
	    sup.ShowModal('#oneonly-modal');
	}
	if (window.APT_OPTIONS.thisUid == expinfo.creator &&
	    expinfo.extension_info.extension_denied) {
	    ShowExtensionDeniedModal();
	}
	else if (window.APT_OPTIONS.snapping) {
	    ShowProgressModal();
	}
	else if (!expinfo.started && expinfo.start_at) {
	    ShowRspec();
	    ShowBindings();
	}
     }

  function addTutorialNotifyTab(id)
  {
    var allTabs = $('#quicktabs_ul li');
    allTabs.each(function () {
      if ($(this).find('a').attr('href') === ('#' + id)) {
	$(this).on('show.bs.tab', function () {
	  APT_OPTIONS.updatePage({ 'status_tab': id });
	});
      }
    });
  }
  
    //
    // The status watch is a periodic timer, but we sometimes want to
    // hold off running it for a while, and other times we want to run
    // it before the next time comes up. We use flags for both of these
    // cases.
    //
    var statusBusy = 0;
    var statusHold = 0;
    var statusID;

    function StartStatusWatch()
    {
	GetStatus();
	statusID = setInterval(GetStatus, (slowdown ? 20000 : 5000));
    }
    
    function GetStatus()
    {
	//console.info("GetStatus", statusBusy, statusHold);
	
	// Clearly not thread safe, but its okay.
	if (statusBusy || statusHold)
	    return;
	statusBusy = 1;
	
	var callback = function(json) {
	    // Watch for logged out, stop the loop. User will need to reload.
	    if (json.code == 222) {
		clearInterval(statusID);
		alert("You are no longer logged in, please refresh to " +
		      "continue getting page updates");
	    }
	    else {
		StatusWatchCallBack(json, function () {
		    if (instanceStatus == 'terminated') {
			clearInterval(statusID);
		    }
		    else {
			// Okay to do again next timeout.
			statusBusy = 0;
		    }
		});
	    }
	}
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "GetInstanceStatus",
					     {"uuid" : uuid});
	xmlthing.fail(function(jqXHR, textStatus) {
	    console.info("GetStatus failed: " + textStatus);
	    statusBusy = 0;
	});
	xmlthing.done(callback);
    }

    // Call back for above.
    function StatusWatchCallBack(json, donefunc)
    {
	//console.info("StatusWatchCallBack: ", json);
	if (json.code) {
	    // GENIRESPONSE_SEARCHFAILED
	    if (json.code == 12) {
		instanceStatus = "terminated";
	    }
	    else if (lastStatus != "terminated") {
		instanceStatus = "unknown";
	    }
	}
	else {
	    instanceStatus = json.value.status;
	}
	// The urls can show up at any time cause of async/early return.
	if (_.has(json.value, "sliverstatus")) {
	    ShowSliverURLs(json.value.sliverstatus);
	}
	if (0) {
	    console.info("GetStatus", instanceStatus,
			 expinfo.paniced, json.value.paniced);
	}
	// See if a transition from scheduled to started
	if (!expinfo.started && json.value.started) {
	    ExperimentStarted();
	}
	// Watch for experiment going into or out of panic mode.
	if (expinfo.paniced && !json.value.paniced) {
	    // Left panic mode.
	    expinfo.paniced = 0;
	}
	if (expinfo.paniced || json.value.paniced) {
	    expinfo.paniced = 1;
	    instanceStatus = "quarantined";
	}
	if (instanceStatus != lastStatus) {
            APT_OPTIONS.updatePage({ 'instance-status': instanceStatus });
	    //console.info("New Status: ", json);
	
	    status_html = json.value.status;

	    var bgtype = "panel-info";
	    status_message = "Please wait while we get your experiment ready";

	    // Ditto the logfile.
	    if (_.has(json.value, "logfile_url")) {
		ShowLogfile(json.value.logfile_url);
	    }
	    if (instanceStatus == 'stitching') {
		status_html = "stitching";
	    }
	    else if (instanceStatus == 'pending') {
		status_html = "pending";
		ProgressBarUpdate();
		status_message = "Some or all aggregates currently unreachable";
	    }
	    else if (instanceStatus == 'scheduled') {
		status_html = "scheduled";
		ProgressBarUpdate();
		status_message = "Your experiment is scheduled to start later";
	    }
	    else if (instanceStatus == 'prestaging') {
		status_html = "prestaging";
		status_message = "Copying images to target clusters";
		ProgressBarUpdate();
	    }
	    else if (instanceStatus == 'provisioning') {
		status_html = "provisioning";
		ProgressBarUpdate();
	    }
	    else if (instanceStatus == 'provisioned') {
		ProgressBarUpdate();
		status_html = "booting";
		if (json.value.canceled) {
		    status_html += " (but canceled)";
		}
		else if (aggregatesDeferred(json.value)) {
		    status_html += " (but some aggregates deferred)";
		}
	    }
	    else if (json.value.canceled) {
		status_message = "Your experiment has been canceled!";
		status_html = "<font color=red>canceled</font>";
		ProgressBarUpdate();
	    }
	    else if (instanceStatus == 'ready') {
		bgtype = "panel-success";
		status_message = "Your experiment is ready!";

		if (servicesExecuting(json.value)) {
		    status_html = "<font color=green>booted</font>";
		    status_html += " (startup services are still running)";
		}		
		else {
		    status_html = "<font color=green>ready</font>";
		    if (aggregatesDeferred(json.value)) {
			status_html += " (but some aggregates deferred)";
		    }
		}
		if (lastStatus == "failed") {
		    $('#error_panel').addClass("hidden");
		    $('#ignore-failure').addClass("hidden");
		}
		ProgressBarUpdate();
		ShowIdleDataTab();
		if (json.value.haveopenstackstats) {
		    ShowOpenstackTab();
		}
	    }
	    else if (instanceStatus == 'failed') {
		bgtype = "panel-danger";

		if (_.has(json.value, "reason")) {
		    status_message = "Something went wrong!";
		    $('#error_panel_text').text(json.value.reason);
		    $('#error_panel').removeClass("hidden");
		}
		else {
		    status_message = "Something went wrong, sorry! " +
			"We've been notified.";
		}
		if (_.has(json.value, "code") &&
		    json.value.code == GENIRESPONSE_INSUFFICIENT_NODES) {
		    $('#error_panel .resource-error').removeClass("hidden");
		}
		if (json.value.canclearerror) {
		    $('#ignore-failure').removeClass("hidden");
		}
		
		status_html = "<font color=red>failed</font>";
		ProgressBarUpdate();
	    }
	    else if (instanceStatus == 'quarantined') {
		bgtype = "panel-warning";
		status_message = "Your experiment has been quarantined";
		status_html = "<font color=red>quarantined</font>";
		ProgressBarUpdate();
	    }
	    else if (instanceStatus == 'imaging') {
		bgtype = "panel-warning";
		status_message = "Your experiment is busy while we  " +
		    "copy your disk";
		status_html = "<font color=red>imaging</font>";
	    }
	    else if (instanceStatus == 'linktest') {
		bgtype = "panel-warning";
		status_message = "Your experiment is busy while we  " +
		    "run linktest";
		status_html = "<font color=red>linktest</font>";
	    }
	    else if (instanceStatus == 'imaging-failed') {
		bgtype = "panel-danger";
		status_message = "Your disk image request failed!";
		status_html = "<font color=red>imaging-failed</font>";
	    }
	    else if (instanceStatus == 'terminating' ||
		     instanceStatus == 'terminated') {
		status_html = "<font color=red>" + instanceStatus + "</font>";
		bgtype = "panel-danger";
		status_message = "Your experiment has been terminated!";
		StartCountdownClock.stop = 1;
		if (lastStatus == "failed") {
		    $('#ignore-failure').addClass("hidden");
		}
	    }
	    else if (instanceStatus == "unknown") {
		status_html = "<font color=red>" + instanceStatus + "</font>";
		bgtype = "panel-warning";
		status_message = "The server is temporarily unavailable. " +
		    "Please check back later.";
	    }
	    if (instanceStatus == "quarantined") {
		$('#explain-quarantine').removeClass("hidden");
		$('#warnkill-experiment-button').addClass("hidden");
		$('#release-quarantine-button').removeClass("hidden");
		$('#quarantine_checkbox').prop("checked", true);
	    }
	    else {
		$('#explain-quarantine').addClass("hidden");
		$('#release-quarantine-button').addClass("hidden");
		$('#warnkill-experiment-button').removeClass("hidden");
		$('#quarantine_checkbox').prop("checked", false);
	    }
	    $("#status_panel")
		.removeClass('panel-success panel-danger ' +
			     'panel-warning panel-default panel-info')
		.addClass(bgtype);
	    UpdateButtons(instanceStatus);
	}
	else if (lastStatus == "ready" && instanceStatus == "ready") {
	    if (servicesExecuting(json.value)) {
		status_html = "<font color=green>booted</font>";
		status_html += " (startup services are still running)";
	    }		
	    else {
		status_html = "<font color=green>ready</font>";
		if (aggregatesDeferred(json.value)) {
		    status_html += " (but some aggregates deferred)";
		}
	    }
	}
	lastStatus = instanceStatus;
	/*
	 * We get a prestageStatus array from the server when we need
	 * to show that progress. Otherwise hide it.
	 */
	if (_.has(json.value, "prestageStatus")) {
	    ShowPrestageInfo(json.value.prestageStatus);
	}
	else {
	    HidePrestageInfo();
	}

	// Okay, now we can update if they have not changed.
	if (!status_collapsed) {
	    if ($("#status_message").html() != status_message) {
		$("#status_message").html(status_message);
	    }
	}
	if ($("#quickvm_status").html() != status_html) {
	    $("#quickvm_status").html(status_html);
	    $("#quickvm_status_hidden").html(instanceStatus);
	}

	// Add manifests as we get them or on topo change.
	if (expinfo.started && _.has(json.value, "sliverstatus")) {
	    /*
	     * Watch for a change in the aggregates that requires that
	     * we clean the topology/list tabs and draw new ones. Basically,
	     * need to compare against last time, and look for deletions.
	     */
	    if (lastSliverStatus != null) {
		$.each(lastSliverStatus , function(urn) {
		    if (!_.has(json.value.sliverstatus, urn)) {
			console.info("Topology has changed: " +
				     urn + " removed");
			changingtopo = true;
		    }
		});
		$.each(json.value.sliverstatus, function (urn) {
		    if (!_.has(lastSliverStatus, urn)) {
			console.info("Topology has changed: " +
				     urn + " added");
			changingtopo = true;
		    }
		});
	    }
	    // This will not do anything unless it needs to.
	    ShowTopo(json.value.sliverstatus, function () {
		// Do this after updates for manifest, which is async.
		UpdateSliverStatus(json.value.sliverstatus);
		// Also save the sliverstatus so we can detect changes
		lastSliverStatus = json.value.sliverstatus;
		// Async activity is now done, we can tell the caller.
		// Be nice to use a promise, but have not figured them out yet
		donefunc();
	    });
	}
	else {
	    // Async activity is now done, we can tell the caller.
	    // Be nice to use a promise, but have not figured them out yet
	    donefunc();
	}
    }

    /*
     * Set the button enable/disable according to current status.
     */
    function UpdateButtons(status)
    {
	var terminate;
	var refresh;
	var reloadtopo;
	var extend;
	var snapshot;
	var destroy;
	var release = 0;

	switch (status)
	{
	    case 'provisioning':
	    case 'imaging':
	    case 'linktest':
	    case 'terminating':
	    case 'terminated':
	    case 'unknown':
	        terminate = refresh = reloadtopo = extend = snapshot = 0;
	        destroy = 0;
  	        break;

	    case 'provisioned':
	    case 'scheduled':
	    case 'pending':
	        refresh = reloadtopo = extend = snapshot = destroy = 0;
  	        terminate = 1;
  	        break;
	    
	    case 'ready':
	        terminate = refresh = reloadtopo = extend = snapshot = 1;
	        destroy = 1;
  	        break;

	    case 'quarantined':
	        refresh = reloadtopo = extend = snapshot = destroy = 0;
	        release = 1;
	        // We let admins terminate/refresh a quarantined experiment.
	        if (isadmin) {
		    terminate = refresh = 1;
		}
  	        break;

	    case 'failed':
	    case 'imaging-failed':
	        refresh = reloadtopo = terminate = destroy = 1;
	        extend = snapshot = 0;
  	        break;
	}

	// When admin lockdown is set, we never enable this button.
	if (expinfo.admin_lockdown || !window.APT_OPTIONS.canterminate) {
	    terminate = 0;
	}
	ButtonState('terminate', terminate);
	ButtonState('refresh', refresh);
	ButtonState('reloadtopo', reloadtopo);
	ButtonState('extend', extend);
	ButtonState('snapshot', snapshot);
	ButtonState('destroy', destroy);
	ButtonState('release', release);
	ToggleLinktestButtons(status);
    }
    function EnableButton(button)
    {
	ButtonState(button, 1);
    }
    function DisableButton(button)
    {
	ButtonState(button, 0);
    }
    function ButtonState(button, enable)
    {
	if (button == "terminate") {
	    button = "#terminate_button";
	    // When admin lockdown is set, we never enable this button.
	    if (expinfo.admin_lockdown || !window.APT_OPTIONS.canterminate) {
		enable = 0;
	    }
	}
	else if (button == "destroy")
	    button = "#warnkill-experiment-button";
	else if (button == "release")
	    button = "#release-quarantine-button";
	else if (button == "extend")
	    button = "#extend_button";
	else if (button == "refresh")
	    button = "#refresh_button";
	else if (button == "reloadtopo")
	    button = "#reload-topology-button";
	else if (button == "snapshot")
	    button = "#snapshot_button";
	else if (button == "start-linktest")
	    button = "#linktest-modal-button";
	else if (button == "stop-linktest")
	    button = "#linktest-stop-button";
	else
	    return;

	if (enable) {
	    $(button).removeAttr("disabled");
	}
	else {
	    $(button).attr("disabled", "disabled");
	}
    }

    //
    // Found this with a Google search; countdown till the expiration time,
    // updating the display. Watch for extension via the reset variable.
    //
    function StartCountdownClock(when)
    {
	// Use this static variable to force clock reset.
	StartCountdownClock.reset = when;

	// Force init below
	when = null;
    
	// Use this static variable to force clock stop
	StartCountdownClock.stop = 0;
    
	// date counting down to
	var target_date;

	// text color.
	var color = "";
    
	// update the tag with id "countdown" every 1 second
	var updater = setInterval(function () {
	    // Clock stop
	    if (StartCountdownClock.stop) {
		// Amazing that this works!
		clearInterval(updater);
	    }
	
	    // Clock reset
	    if (StartCountdownClock.reset != when) {
		when = StartCountdownClock.reset;
		if (when === "n/a") {
		    StartCountdownClock.stop = 1;
		    return;
		}

		// Reformat in local time and show the user.
		var local_date = new Date(when);

		$("#quickvm_expires").html(moment(when).format('lll'));

		// Countdown also based on local time. 
		target_date = local_date.getTime();
	    }
	
	    // find the amount of "seconds" between now and target
	    var current_date = new Date().getTime();
	    var seconds_left = (target_date - current_date) / 1000;

	    if (seconds_left <= 0) {
		// Amazing that this works!
		clearInterval(updater);
		return;
	    }

	    var newcolor   = "";
	    var statusbg   = "panel-success";
	    var statustext = "Your experiment is ready";

	    $("#quickvm_countdown").html(moment(when).fromNow());

	    if (seconds_left < 3600) {
		newcolor   = "text-danger";
		statusbg   = "panel-danger";
		statustext = "Extend your experiment before it expires!";
	    }	    
	    else if (seconds_left < 2 * 3600) {
		newcolor   = "text-warning";
		statusbg   = "panel-warning";
		statustext = "Your experiment is going to expire soon!";
	    }
	    if (newcolor != color) {
		$("#quickvm_countdown")
		    .removeClass("text-warning text-danger")
		    .addClass(newcolor);

		if (status_collapsed) {
		    // Save for when user "shows" the status panel.
		    status_message = statustext;
		    // And update the panel header with new expiration.
		    $('#status_message').html("Experiment expires: " +
			$("#instance_expiration").html());
		}
		else {
		    $("#status_message").html(statustext);
		}
		$("#status_panel")
		    .removeClass('panel-success panel-danger ' +
				 'panel-info panel-default panel-info')
		    .addClass(statusbg);

		color = newcolor;
	    }
	}, 1000);
    }

    //
    // Request experiment extension. Not well named; we always grant the
    // extension. Might need more work later if people abuse it.
    //
    function RequestExtensionCallback(json)
    {
	var message;
	
	if (json.code) {
	    if (json.code == 2) {
		$('#approval_text').html(json.value);
		sup.ShowModal('#approval_modal');
		return;
	    }
	    sup.SpitOops("oops", json.value);
	    return;
	}
	var expiration = json.value.expiration;
	$("#quickvm_expires").html(moment(expiration).format('lll'));
	// Reset the countdown clock.
	StartCountdownClock.reset = expiration;

	// Warn the user if we granted nothing.
	if (json.value.granted == 0) {
	    if (json.value.message != "") {
		$('#no-extension-granted-modal .reason')
		    .text(json.value.message);
		$('#no-extension-granted-modal .reason-div')
		    .removeClass("hidden");
	    }
	    else {
		$('#no-extension-granted-modal .reason')
		    .text("");
		$('#no-extension-granted-modal .reason-div')
		    .addClass("hidden");
	    }
	    sup.ShowModal('#no-extension-granted-modal');
	}
    }

    //
    // Request a refresh from the backend cluster, to see if the sliverstatus
    // has changed. 
    //
    function DoRefresh()
    {
	var callback = function(json) {
	    sup.HideModal('#waitwait-modal');
	    //console.info(json);
	    
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    // Trigger status update.
	    GetStatus();
	}
	sup.ShowModal('#waitwait-modal');
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "Refresh",
					     {"uuid" : uuid});
	xmlthing.done(callback);
    }

    //
    // Request a reload of the manifests (and thus the topology) from the
    // backend clusters.
    //
    function DoReloadTopology()
    {
	var callback = function(json) {
	    //console.info(json);
	    if (json.code) {
		statusHold = 0;
		sup.HideModal('#waitwait-modal');
		sup.SpitOops("oops", "Failed to reload topo: " + json.value);
		return;
	    }
	    changingtopo = true;	    
	    statusHold = 0;
	    // Trigger status update.
	    GetStatus();
	    sup.HideModal('#waitwait-modal');
	}
	statusHold = 1;
	sup.ShowModal('#waitwait-modal');
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "ReloadTopology",
					     {"uuid" : uuid});
	xmlthing.done(callback);
    }

    var svgimg = document.createElementNS('http://www.w3.org/2000/svg','image');
    svgimg.setAttributeNS(null,'class','node-status-icon');
    svgimg.setAttributeNS(null,'height','15');
    svgimg.setAttributeNS(null,'width','15');
    svgimg.setAttributeNS('http://www.w3.org/1999/xlink','href',
			  'fonts/record8.svg');
    svgimg.setAttributeNS(null,'x','13');
    svgimg.setAttributeNS(null,'y','-23');
    svgimg.setAttributeNS(null, 'visibility', 'visible');

    // Store old status blob details for comparison to current.
    var oldStatusDetails = {};

    // Helper for above and called from the status callback.
    function UpdateSliverStatus(statusblob)
    {
	if (nodecount > MAXJACKSNODES) {
	    return;
	}
	$.each(statusblob , function(urn, iblob) {
	    // Will not have node details until manifest is ready.
	    if (!_.has(iblob, "details")) {
		if (iblob.deferred != 0) {
		    deferAggregate(iblob);
		}
		return;
	    }
	    if (iblob.status == "terminated" ||
		iblob.status == "canceled") {
		TerminatedAggregate(iblob.status, urn);
		return;
	    }
	    if (iblob.offline) {
		OfflineAggregate(urn);
		return;
	    }
	    $.each(iblob.details, function(node_id, details) {
		var jacksID  = jacksIDs[node_id];
		// No manifest yet for this node.
		if (jacksID === undefined) {
		    return;
		}
		/*
		 * Use cached details to see if anything has changed, to
		 * avoid regenerating the html and updating the popovers.
		 * On a small experiment this does not matter, but with a
		 * couple 100 nodes, we burn a lot of CPU doing this.
		 *
		 * Put the jacksID into the details for the
		 * comparison.  The JackID appears to change at some
		 * point, so by putting it into the details we stash,
		 * we can make it part of the comparison.
		 */
		details["jacksID"] = jacksID;
		
		if (_.has(oldStatusDetails, node_id)) {
		    if (_.isEqual(details, oldStatusDetails[node_id])) {
			//console.info(node_id + " has not changed");
			return;
		    }
		}
		//console.info(node_id + " has changed", details, jacksID);
		oldStatusDetails[node_id] = details;
		
		// Is the node in recovery. Panic mode does not count.
		var recovery = false;
		if (!expinfo.paniced &&
		    _.has(details, "recovery") && details.recovery != 0) {
		    recovery = true;
		    inrecovery[node_id] = true;
		}
		else {
		    inrecovery[node_id] = false;
		}
		
		$('#listview-row-' + node_id + ' td[name="status"]')
		    .html(recovery ? "<b>recovery</b>" : details.status);

		if (details.status == "ready") {
		    // Greenish.
		    var color = "#91E388";
		    if (recovery) {
			// warning
			color = "#fcf8e3";
		    }
		    $('#' + jacksID + ' .node .nodebox')
			.css("fill", color);
		    $('#listview-row-' + node_id + ' td[name="node_id"], ' +
		      '#listview-row-' + node_id + ' td[name="client_id"]')
			.css("color", "#3c763d;");
		}
		else if (details.status == "failed") {
		    // Bootstrap bg-danger color
		    $('#' + jacksID + ' .node .nodebox')
			.css("fill", "#e67795");
		    $('#listview-row-' + node_id + ' td[name="node_id"], ' +
		      '#listview-row-' + node_id + ' td[name="client_id"]')
			.css("color", "#a94442");
		}
		else {
		    // Bootstrap bg-warning color
		    $('#' + jacksID + ' .node .nodebox')
			.css("fill", "#fcf8e3");
		    $('#listview-row-' + node_id + ' td[name="node_id"], ' +
		      '#listview-row-' + node_id + ' td[name="client_id"]')
			.css("color", "");
		}
		var cluster_id = amlist[urn].nickname;
		
		var html =
		    "<table class='table table-condensed border-none'><tbody> " +
		    "<tr><td class='border-none'>Node:</td><td class='border-none'>" +
		        details.component_urn + "</td></tr>" +
		    "<tr><td class='border-none'>ID:</td><td class='border-none'>" +
		        details.client_id + "</td></tr>" +
		    "<tr><td class='border-none'>Cluster:</td><td class='border-none'>" +
		        cluster_id + "</td></tr>" +
		    "<tr><td class='border-none'>Status:</td><td class='border-none'>" +
   		    (recovery ? "<b>recovery</b>" : details.status) +
		          "</td></tr>" +
		    "<tr><td class='border-none'>Raw State:</td>" +
		        "<td class='border-none'>" +
		    details.rawstate + "</td></tr>";

		if (_.has(details, "frisbeestatus")) {
		    var mb_written = details.frisbeestatus.MB_written;
		    var imagename  = details.frisbeestatus.imagename;
		    html = html +
			"<tr><td class='border-none'>Image:</td>" +
		        "    <td class='border-none'>" +
		              imagename + "</td></tr>" +
			"<tr><td class='border-none'>Written:</td>" +
		        "    <td class='border-none'>" +
		              mb_written + " MB</td></tr>";			
		}
		if (_.has(details, "execute_state")) {
		    var tag;
		    var icon;
			
		    if (details.execute_state == "running") {
			tag  = "Running";
			icon = "record8.svg";
		    }
		    else if (details.execute_state == "exited") {
			if (details.execute_status != 0) {
			    tag  = "Exited (" + details.execute_status + ")";
			    icon = "cancel22.svg";
			}
			else {
			    tag  = "Finished";
			    icon = "check64.svg";
			}
		    }
		    else {
			tag  = "Pending";
			icon = "button14.svg"
		    }
		    html += "<tr><td class='border-none'>Startup Service:</td>" +
			"<td class='border-none'>" + tag + "</td></tr>";
		    
		    $('#' + jacksID + ' .node .node-status')
		        .css("visibility", "visible");

		    if (!$('#' + jacksID +
			   ' .node .node-status-icon').length) {
			$('#' + jacksID + ' .node .node-status')
		            .append(svgimg.cloneNode());
		    }
		    $('#' + jacksID + ' .node .node-status-icon')
			.attr("href", "fonts/" + icon);
		    
		    if ($('#' + jacksID + ' .node .node-status-icon')
			.data("bs.tooltip")) {
			$('#' + jacksID + ' .node .node-status-icon')
			    .data("bs.tooltip").options.title = tag;
		    }
		    else {
			$('#' + jacksID + ' .node .node-status-icon')
			    .tooltip({"title"     : tag,
				      "trigger"   : "hover",
				      "html"      : true,
				      "container" : "body",
				      "placement" : "auto right",
				     });
		    }
		    $('#listview-row-' + node_id + ' td[name="startup"]')
			.html(tag);
		}
		html += "</tbody></table>";
		UpdateNodePopover(node_id, jacksID, html);
	    });
	});
    }

    // Update the popover the node icon box
    function UpdateNodePopover(node_id, jacksID, html)
    {
	//console.info("UpdateNodePopover", node_id, jacksID, html);
	
	if ($('#' + jacksID).data("bs.popover")) {
	    $('#' + jacksID).data("bs.popover").options.content = html;

	    var isVisible = $('#' + jacksID)
		.data('bs.popover').tip().hasClass('in');
	    
	    if (isVisible) {
		$('#' + jacksID)
		    .data('bs.popover').tip()
		    .find('.popover-content').html(html);
	    }
	}
	else {
	    $('#' + jacksID)
		.popover({"content"   : html,
			  "trigger"   : "hover",
			  "html"      : true,
			  "container" : "body",
			  "placement" : "auto",
			 });
	}
	// And a popover on the listview page, using the same html.
	var id = '#listview-row-' + node_id + ' td[name="status"]';
	
	if ($(id).data("bs.popover")) {
	    $(id).data("bs.popover").options.content = html;

	    var isVisible = $(id)
		.data('bs.popover').tip().hasClass('in');
	    
	    if (isVisible) {
		$(id)
		    .data('bs.popover').tip()
		    .find('.popover-content').html(html);
	    }
	}
	else {
	    $(id).popover({"content"   : html,
			   "trigger"   : "hover",
			   "html"      : true,
			   "container" : "body",
			   "placement" : "auto",
			  });
	    $(id).css('text-decoration', 'underline');
	}
    }

    function deferAggregate(sliver)
    {
	var urn    = sliver.aggregate_urn;
	var reason = sliver.deferred_reason;
	var cause  = sliver.deferred_cause;
	    
	if (!_.has(jacksSites, urn)) {
	    // Manifest not processed yet.
	    return;
	}
	$.each(jacksSites[urn], function(node_id, jacksID) {
	    var html;
	    
	    //console.info("deferAggregate: ", urn, node_id, jacksID);
	    $('#' + jacksID + ' .node .nodebox')
		.css("fill", "#ff9248");

	    if (reason) {
		html = reason;
	    }
	    else {
		html =
		    "This node is currently unavailable and cannot be added " +
		    "to your experiment. We will continue trying to contact " +
		    "this node.";
	    }
	    if (cause) {
		html = html + "<br><pre>" + cause + "</pre>";
	    }
	    UpdateNodePopover(node_id, jacksID, html);
	});
    }

    function OfflineAggregate(urn)
    {
	if (!_.has(jacksSites, urn)) {
	    // Manifest not processed yet.
	    return;
	}
	$.each(jacksSites[urn], function(node_id, jacksID) {
	    //console.info("deferAggregate: ", urn, node_id, jacksID);
	    $('#' + jacksID + ' .node .nodebox')
		.css("fill", "#fcf8e3");

	    var html = "This node is currently unreachable, operations on " +
		"this node will fail until it becomes reachable again.";

	    UpdateNodePopover(node_id, jacksID, html);
	});
    }

    function TerminatedAggregate(status, urn)
    {
	if (!_.has(jacksSites, urn)) {
	    // Manifest not processed yet.
	    return;
	}
	$.each(jacksSites[urn], function(node_id, jacksID) {
	    //console.info("deferAggregate: ", urn, node_id, jacksID);
	    $('#' + jacksID + ' .node .nodebox')
		.css("fill", "red");

	    var html;

	    if (status == "terminated") {
		html = "This node has been deallocated and is no longer " +
		    "accessible by this experiment.";
	    }
	    else {
		html = "This node has been marked for removal from your " +
		    "experiment as soon as the aggregate comes back online.";
	    }
	    UpdateNodePopover(node_id, jacksID, html);
	    $('#listview-row-' + node_id + ' td[name="status"]')
		.html("terminated");
	});
    }

    //
    // Check the status blob to see if any nodes have execute services
    // still running.
    //
    function servicesExecuting(blob)
    {
	if (_.has(blob, "sliverstatus")) {
	    for (var urn in blob.sliverstatus) {
		var nodes = blob.sliverstatus[urn];
		for (var nodeid in nodes) {
		    var status = nodes[nodeid];
		    if (_.has(status, "execute_state") &&
			status.execute_state != "exited") {
			return 1;
		    }
		}
	    }
	}
	return 0;
    }
    function hasExecutionServices(blob)
    {
	if (_.has(blob, "sliverstatus")) {
	    for (var urn in blob.sliverstatus) {
		var nodes = blob.sliverstatus[urn];
		for (var nodeid in nodes) {
		    var status = nodes[nodeid];
		    if (_.has(status, "execute_state")) {
			return 1;
		    }
		}
	    }
	}
	return 0;
    }
    //
    // Check the status blob to see if any aggregates are in the
    // the deferred state.
    //
    function aggregatesDeferred(blob)
    {
	if (_.has(blob, "sliverstatus")) {
	    for (var urn in blob.sliverstatus) {
		if (blob.sliverstatus[urn].deferred != 0) {
		    return 1;
		}
	    }
	}
	return 0;
    }
	
    //
    // Request a node reboot or reload from the backend cluster.
    //
    function DoReboot(nodeList)
    {
	DoRebootReload("reboot", nodeList);
    }
    function DoReload(nodeList)
    {
	for (var i = 0; i < nodeList.length; i++) {
	    var node = nodeList[i];

	    if (_.has(inrecovery, node) && inrecovery[node]) {
		alert(node + " is in recovery mode, you cannot reload a node " +
		      "while it is in recovery mode");
		return;
	    }
	}
	DoRebootReload("reload", nodeList);
    }
    function DoPowerCycle(nodeList)
    {
	DoRebootReload("powercycle", nodeList);
    }
    function DoRebootReload(which, nodeList)
    {
	var method = (which == "reload" ? "Reload" :
		      which == "powercycle" ? "PowerCycle" : "Reboot");
	var tag    = (which == "reload" ? "Reload" :
		      which == "powercycle" ? "Power Cycle" : "Reboot");
	
	// Handler for hide modal to unbind the click handler.
	$('#confirm_reload_modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm_reload_button').unbind("click.reload");
	});
	
	// Throw up a confirmation modal, with handler bound to confirm.
	$('#confirm_reload_button').bind("click.reload", function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    sup.HideModal('#confirm_reload_modal');
	    var callback = function(json) {
		sup.HideModal('#waitwait-modal');
	    
		if (json.code) {
		    sup.SpitOops("oops",
				 "Failed to " + which + ": " + json.value);
		    return;
		}
		// Trigger status update.
		GetStatus();
	    }
	    sup.ShowModal('#waitwait-modal');
	    var xmlthing = sup.CallServerMethod(ajaxurl, "status", method,
						{"uuid"     : uuid,
						 "node_ids" : nodeList});
	    xmlthing.done(callback);
	});
	$('#confirm_reload_modal #confirm-which').html(tag);
	sup.ShowModal('#confirm_reload_modal');
    }
	
    //
    // Request a node deletion from the backend cluster.
    //
    function DoDeleteNodes(nodeList)
    {
	// Handler for hide modal to unbind the click handler.
	$('#deletenode_modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('button#deletenode_confirm').unbind("click.deletenode");
	});
	
	// Throw up a confirmation modal, with handler bound to confirm.
	$('button#deletenode_confirm').bind("click.deletenode",
					    function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    sup.HideModal('#deletenode_modal');
	
	    var callback = function(json) {
		console.info(json);
		sup.HideWaitWait();
		
		if (json.code) {
		    $('#error_panel_text').text(json.value);
		    $('#error_panel').removeClass("hidden");
		    return;
		}
		changingtopo = true;
		// Trigger status to change the nodes.
		GetStatus();
	    }
	    sup.ShowWaitWait("This will take several minutes. " +
			     "Patience please.");
	    var xmlthing = sup.CallServerMethod(ajaxurl,
						"status",
						"DeleteNodes",
						{"uuid"     : uuid,
						 "node_ids" : nodeList});
	    xmlthing.done(callback);
	});
        $('#error_panel').addClass("hidden");
	sup.ShowModal('#deletenode_modal');
    }

    /*
     * Boot node into recovery mode MFS
     *
     * In order to show something useful on the confirm modal, we track
     * what nodes we think are in recovery mode. See UpdateSliverStatus().
     */
    function DoRecovery(node)
    {
	// Handler for hide modal to unbind the click handler.
	$('#confirm_recovery_modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm_recovery_button').unbind("click.recovery");
	});
	
	// Throw up a confirmation modal, with handler bound to confirm.
	$('#confirm_recovery_button').bind("click.recovery", function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    sup.HideModal('#confirm_recovery_modal');
	    var callback = function(json) {
		sup.HideModal('#waitwait-modal');
	    
		if (json.code) {
		    sup.SpitOops("oops",
				 "Failed to set recovery mode: " + json.value);
		    return;
		}
	    }
	    var args = {"uuid"  : uuid,
			"node"  : node};
	    // Since we think its in recovery, clear it. 
	    if (_.has(inrecovery, node) && inrecovery[node]) {
		args["clear"] = true;
	    }
	    console.info(inrecovery, args);
	    sup.ShowModal('#waitwait-modal');
	    var xmlthing = sup.CallServerMethod(ajaxurl, "status",
						"Recovery", args);
						
	    xmlthing.done(callback);
	});
	if (_.has(inrecovery, node) && inrecovery[node]) {	
	    $('#confirm_recovery_modal .recovery-off').removeClass("hidden");
	    $('#confirm_recovery_modal .recovery-on').addClass("hidden");
	}
	else {
	    $('#confirm_recovery_modal .recovery-off').addClass("hidden");
	    $('#confirm_recovery_modal .recovery-on').removeClass("hidden");
	}
	sup.ShowModal('#confirm_recovery_modal');
    }
	
    /*
     * Flash a flashable device.
     */
    function DoFlash(node)
    {
	// Handler for hide modal to unbind the click handler.
	$('#confirm_flash_modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#confirm_flash_button').unbind("click.flash");
	});
	
	// Throw up a confirmation modal, with handler bound to confirm.
	$('#confirm_flash_button').bind("click.flash", function (event) {
	    var callback = function(json) {
		sup.HideModal('#waitwait-modal', function () {
		    if (json.code) {
			sup.SpitOops("oops",
				     "Failed to set flash node: " + json.value);
		    }
		    else {
			sup.ShowModal('#flash_done_modal');			
		    }
		});
	    }
	    var args = {"uuid"  : uuid,
			"node"  : node};

	    sup.HideModal('#confirm_flash_modal', function () {
		sup.ShowWaitWait("Flashing takes 1-2 minutes, " +
				 "patience please!");
		var xmlthing = sup.CallServerMethod(ajaxurl, "status",
						    "Flash", args);
		xmlthing.done(callback);
	    });
	});
	sup.ShowModal('#confirm_flash_modal');
    }
	
    /*
     * Fire up the backend of the ssh tab.
     *
     * If the local ops node is using a self-signed certificate (typical)
     * then the ajax call below will fail. But the protocol does not need
     * to tell is anything specific, so we will just assume that it is the
     * reason and try to get the user to accept a certificate from the ops
     * node.
     */
    function StartSSH(tabname, authobject)
    {
	var jsonauth = $.parseJSON(authobject);
	
	var callback = function(stuff) {
	    console.info(stuff);
            var split   = stuff.split(':');
            var session = split[0];
    	    var port    = split[1];

            var url   = jsonauth.baseurl + ':' + port + '/' + '#' +
		encodeURIComponent(document.location.href) + ',' + session;
            console.info(url);
	    var iwidth = "100%";
            var iheight = 400;

            $('#' + tabname).html('<iframe id="' + tabname + '_iframe" ' +
			     'width=' + iwidth + ' ' +
                             'height=' + iheight + ' ' +
                             'src=\'' + url + '\'>');
	    
	    //
	    // Setup a custom event handler so we can kill the connection.
	    //
	    $('#' + tabname).on("killssh",
			   { "url": jsonauth.baseurl + ':' + port + '/quit' +
			     '?session=' + session },
			   function(e) {
//			       console.info("killssh: " + e.data.url);
			       $.ajax({
     				   url: e.data.url,
				   type: 'GET',
			       });
			   });
	}
	var callback_error = function(stuff) {
	    console.info("SSH failure", stuff);
	    var url = jsonauth.baseurl + '/accept_cert.html';
	    // Trigger the kill button to get rid of the dead tab.
	    $("#" + tabname + "_kill").click();
	    // Set the link in the modal.
	    $('#accept-certificate').attr("href", url);
	    sup.ShowModal('#ssh-failed-modal');
	};
	
	var xmlthing = $.ajax({
	    // the URL for the request
	    url: jsonauth.baseurl + '/d77e8041d1ad',
	    //url: jsonauth.baseurl + '/myshbox',
	    
     	    // the data to send (will be converted to a query string)
	    data: {
		auth: authobject,
	    },
 
 	    // Needs to be a POST to send the auth object.
	    type: 'POST',
 
    	    // Ask for plain text for easier parsing. 
	    dataType : 'text',
	});
	xmlthing.done(callback);
	xmlthing.fail(callback_error);
    }

    function StartSSHWebSSH(tabname, authobject)
    {
	var jsonauth = $.parseJSON(authobject);

        var url     = jsonauth.baseurl;
	var iwidth  = "100%";
        var iheight = 400;

	// Backwards compat for a while.
	if (!url.includes("webssh")) {
	    url = url + "/webssh/webssh.html";
	}

	var loadiframe = function () {
	    console.info("Sending message", jsonauth.baseurl);
	    iframewindow.postMessage(authobject, "*");
	    window.removeEventListener("message", loadiframe, false);
	};
	window.addEventListener("message", loadiframe);

	var html = '<iframe id="' + tabname + '_iframe" ' +
	    'width=' + iwidth + ' ' +
            'height=' + iheight + ' ' +
            'src=\'' + url + '\'>';

	var html =
	    '<div style="height:400px; width:100%; ' +
	    '            resize:vertical;overflow-y:auto;padding-bottom:10px"> ' +
	    '  <iframe id="' + tabname + '_iframe" ' +
	    '     width="100%" height="100%"' + 
            '     src=\'' + url + '\'>' +
	    '</div>';
	
        $('#' + tabname).html(html);

	var iframe = $('#' + tabname + '_iframe')[0];
	var iframewindow = (iframe.contentWindow ?
			    iframe.contentWindow :
			    iframe.contentDocument.defaultView);	

	/*
	 * When the user activates this tab, we want to send a message
	 * to the terminal to focus so we do not have to click inside.
	 */
	$('#quicktabs_ul a[href="#' + tabname + '"]')
	    .on('shown.bs.tab', function (e) {
		iframewindow.postMessage("Focus man!", "*");
	    });
    }

    //
    // User clicked on a node, so we want to create a tab to hold
    // the ssh tab with a panel in it, and then call StartSSH above
    // to get things going.
    //
    var sshtabcounter = 0;
    
    function NewSSHTab(hostport, client_id)
    {
	var pair = hostport.split(":");
	var host = pair[0];
	var port = pair[1];

	//
	// Need to create the tab before we can create the topo, since
	// we need to know the dimensions of the tab.
	//
	var tabname = client_id + "_" + ++sshtabcounter + "_tab";
	//console.info(tabname);
	
	if (! $("#" + tabname).length) {
	    // The tab.
	    var html = "<li><a href='#" + tabname + "' data-toggle='tab'>" +
		client_id + "" +
		"<button class='close' type='button' " +
		"        id='" + tabname + "_kill'>x</button>" +
		"</a>" +
		"</li>";	

	    // Append to end of tabs
	    $("#quicktabs_ul").append(html);

	    // GA handler.
	    var ganame = "ssh_" + sshtabcounter;
	    $('#quicktabs_ul a[href="#' + tabname + '"]')
		.on('shown.bs.tab', function (event) {
		    window.APT_OPTIONS.gaTabEvent("show", ganame);
		});
	    window.APT_OPTIONS.gaTabEvent("create", ganame);

	    // Install a click handler for the X button.
	    $("#" + tabname + "_kill").click(function(e) {
		window.APT_OPTIONS.gaTabEvent("kill", ganame);
		e.preventDefault();
		// Trigger the custom event.
		$("#" + tabname).trigger("killssh");
		// remove the li from the ul.
		$(this).parent().parent().remove();
		// Remove the content div.
		$("#" + tabname).remove();
		// Activate the first visible tab.
		$('#quicktabs_ul a:visible:first').tab('show');
	    });

	    // The content div.
	    html = "<div class='tab-pane' id='" + tabname + "'></div>";

	    $("#quicktabs_content").append(html);

	    // And make it active
	    $('#quicktabs_ul a:last').tab('show') // Select last tab
	}
	else {
	    // Switch back to it.
	    $('#quicktabs_ul a[href="#' + tabname + '"]').tab('show');
	    return;
	}

	// Ask the server for an authentication object that allows
	// to start an ssh shell.
	var callback = function(json) {
	    console.info(json.value);

	    if (json.code) {
		sup.SpitOops("oops", "Failed to get ssh auth object: " +
			     json.value);
		return;
	    }
	    else {
		var jsonauth = $.parseJSON(json.value);
		
		if (APT_OPTIONS.webssh &&
		    _.has(jsonauth, "webssh") && jsonauth.webssh != 0) {
		    StartSSHWebSSH(tabname, json.value);
		}
		else {
		    StartSSH(tabname, json.value);
		}
	    }
	}
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "GetSSHAuthObject",
					    {"uuid" : uuid,
					     "hostport" : hostport});
	xmlthing.done(callback);
    }

    // SSH info.
    var hostportList = {};

    // Map client_id to node_id
    var clientid2nodeid = {};

    // Imageable nodes in its own list.
    var imageablenodes = {};

    // Remember passwords to show user later. 
    var nodePasswords = {};

    // Per node context menus.
    var contextMenus = {};

    // Global current showing contect menu. Some kind of bug is leaving them
    // around, so keep the last one around so we can try to kill it.
    var currentContextMenu = null;

    //
    // Show a context menu over nodes in the topo viewer.
    //
    function ContextMenuShow(jacksevent)
    {
	// Foreign admins have no permission for anything.
	if (isfadmin) {
	    return;
	}
	var event = jacksevent.event;
	var client_id = jacksevent.client_id;
	var cid = "context-menu-" + client_id;

	if (currentContextMenu) {
	    $('#context').contextmenu('closemenu');
	    $('#context').contextmenu('destroy');
	}
	if (!_.has(contextMenus, client_id)) {
	    return;
	}

	//
	// We generate a new menu object each time causes it easier and
	// not enough overhead to worry about.
	//
	$('#context').contextmenu({
	    target: '#' + cid, 
	    onItem: function(context,e) {
		window.APT_OPTIONS.gaButtonEvent(e);
		$('#context').contextmenu('closemenu');
		$('#context').contextmenu('destroy');
		// Disabled menu items, but we still want user to see them.
		if ($(e.target).attr("disabled")) {
		    return;
		}
		ActionHandler($(e.target).attr("name"), [client_id]);
	    }
	})
	currentContextMenu = cid;
	$('#' + cid).one('hidden.bs.context', function (event) {
	    currentContextMenu = null;
	});
	$('#context').contextmenu('show', event);
    }
    
    //
    // Same operation, but for the Site tag context menu.
    //
    function SiteContextMenuShow(event, sitetag, urn)
    {
	// Foreign admins have no permission for anything.
	if (isfadmin) {
	    return;
	}
	var nickname = $(sitetag).text();
	var cid = "site-context-menu";

	if (currentContextMenu) {
	    $('#context').contextmenu('closemenu');
	    $('#context').contextmenu('destroy');
	}

	//
	// We generate a new menu object each time causes it easier and
	// not enough overhead to worry about.
	//
	$('#context').contextmenu({
	    target: '#' + cid, 
	    onItem: function(context,e) {
		$('#context').contextmenu('closemenu');
		$('#context').contextmenu('destroy');
		// Disabled menu items, but we still want user to see them.
		if ($(e.target).attr("disabled")) {
		    return;
		}
		SiteActionHandler($(e.target).attr("name"), urn);
	    }
	})
	currentContextMenu = cid;
	$('#' + cid).one('hidden.bs.context', function (event) {
	    currentContextMenu = null;
	});
	$('#context').contextmenu('show', event);
    }

    //
    // Common handler for both the context menu and the listview menu.
    //
    function ActionHandler(action, clientList)
    {
	console.info(action,clientList);
	
	//
	// Do not show in the terminating or terminated state.
	//
	if (lastStatus == "terminated" || lastStatus == "terminating") {
	    alert("Your experiment is no longer active.");
	    return;
	}
	if (lastStatus == "unknown") {
	    alert("Server is temporarily unavailable. Try again later.");
	    return;
	}

	/*
	 * While shell and console can handle a list, I am not actually
	 * doing that, since its a dubious thing to do, and because the
	 * shellinabox code is not very happy trying to start a bunch all
	 * once. 
	 */
	if (action == "shell") {
	    // Do not want to fire off a whole bunch of ssh commands at once.
	    for (var i = 0; i < clientList.length; i++) {
		(function (i) {
		    setTimeout(function () {
			var client_id = clientList[i];
			NewSSHTab(hostportList[client_id], client_id);
		    }, i * 1500);
		})(i);
	    }
	    return;
	}
	if (isguest) {
	    alert("Only registered users can use the " + action + " command.");
	    return;
	}
	if (action == "console") {
	    // Do not want to fire off a whole bunch of console
	    // commands at once.
	    var haveConsoles = [];
	    for (var i = 0; i < clientList.length; i++) {
		if (_.has(consolenodes, clientList[i])) {
		    haveConsoles.push(clientList[i]);
		}
	    }
	    for (var i = 0; i < haveConsoles.length; i++) {
		(function (i) {
		    setTimeout(function () {
			var client_id = haveConsoles[i];
			NewConsoleTab(client_id);
		    }, i * 1500);
		})(i);
	    }
	    return;
	}
	else if (action == "consolelog") {
	    ConsoleLog(clientList[0]);
	}
	else if (action == "reboot") {
	    DoReboot(clientList);
	}
	else if (action == "powercycle") {
	    DoPowerCycle(clientList);
	}
	else if (action == "delete") {
	    DoDeleteNodes(clientList);
	}
	else if (action == "reload") {
	    DoReload(clientList);
	}
	else if (action == "recovery") {
	    DoRecovery(clientList[0]);
	}
	else if (action == "nodetop") {
	    DoTop(clientList[0]);
	}
	else if (action == "monitor") {
	    NewMonitorTab(clientList[0]);
	}
	else if (action == "flash") {
	    DoFlash(clientList[0]);
	}
    }

    //
    // Handler for the Site context menu.
    //
    function SiteActionHandler(action, urn)
    {
	console.info(action, urn);
	
	if (action == "delete") {
	    DoDeleteSite(urn);
	}
    }

    //
    // Show the topology inside the topo container. Called from the status
    // watchdog and the resize wachdog. Replaces the current topo drawing.
    //    
    function ShowTopo(statusblob, donefunc)
    {
	//console.info("ShowTopo", changingtopo, statusblob);

	// For Powder map redraw after topology change.
	var redrawpowdermap = false;

	//
	// Maybe this should come from rspec? Anyway, we might have
	// multiple manifests, but only need to do this once, on any
	// one of the manifests.
	//
	var UpdateInstructions = function(xml,uridata) {
	    var instructionRenderer = new marked.Renderer();
	    instructionRenderer.defaultLink = instructionRenderer.link;
	    instructionRenderer.link = function (href, title, text) {
		var template = UriTemplate.parse(href);
		return this.defaultLink(template.expand(uridata), title, text);
	    };

	    // Suck the instructions out of the tour and put them into
	    // the Usage area.
	    $(xml).find("rspec_tour").each(function() {
		$(this).find("instructions").each(function() {
		    marked.setOptions({ "sanitize" : true,
					"renderer": instructionRenderer });
		
		    var text = $(this).text();
		    // Search the instructions for {host-foo} pattern.
		    var regex   = /\{host-.*\}/gi;
		    var needed  = text.match(regex);
		    if (needed && needed.length) {
			_.each(uridata, function(host, key) {
			    regex = new RegExp("\{" + key + "\}", "gi");
			    text = text.replace(regex, host);
			});
		    }
		    // Stick the text in. 
		    try {
			$('#instructions_text').html(marked(text));
		    }
		    catch(err) {
			console.info(err);
		    }
		    // Make the div visible.
		    $('#instructions_panel').removeClass("hidden");
		    
		});
	    });
	}

	//
	// Process the nodes in a single manifest.
	//
	var ProcessNodes = function(aggregate_urn, xml) {
	    var rawcount = $(xml).find("node, emulab\\:vhost").length;
	    
	    // Find all of the nodes, and put them into the list tab.
	    // Clear current table.
	    $(xml).find("node, emulab\\:vhost").each(function() {
		var node   = $(this).attr("client_id");
		
		// Only nodes that match the aggregate being processed,
		// since we send the same rspec to every aggregate.
		var manager_urn = $(this).attr("component_manager_id");
		if (!manager_urn.length || manager_urn != aggregate_urn) {
		    return;
		}
		//console.info("ProcessNodes", node, manager_urn);
		
		var tag    = $(this).prop("tagName");
		var isvhost= (tag == "emulab:vhost" ? 1 : 0);
		TimeStamp("Processing node " + node);
		var stype  = $(this).find("sliver_type");
		var login  = $(this).find("login");
		var coninfo= this.getElementsByTagNameNS(EMULAB_NS, 'console');
		var pcycle = this.getElementsByTagNameNS(EMULAB_NS, 'powercycle');
		var recover= this.getElementsByTagNameNS(EMULAB_NS, 'recovery');
		var vnode  = this.getElementsByTagNameNS(EMULAB_NS, 'vnode');
		var imageable =
		    this.getElementsByTagNameNS(EMULAB_NS, 'imageable');
		var flashable =
		    this.getElementsByTagNameNS(EMULAB_NS, 'flashable');
		var href   = "n/a";
		var ssh    = "n/a";
		var cons   = "n/a";
		var isfw   = 0;
		var node_id= null;
		var hwtype = null;
		var clone  = $("#listview-row").clone();
		var CMclone= $("#context-menu").clone();
		
		// Cause of nodes in the emulab namespace (vhost).
		if (!login.length) {
		    login = this.getElementsByTagNameNS(EMULAB_NS, 'login');
		}
		var canrecover = 0;
		if (recover.length) {
		    var available = $(recover).attr("available");
		    if (available === "true") {
			canrecover = 1;
		    }
		}

		// Change the ID of the clone so its unique.
		clone.attr('id', 'listview-row-' + node);
		// Set the client_id in the first column.
		clone.find(" [name=client_id]").html(node);
		// And the node_id/type. This is an emulab extension.
		if (vnode.length) {
		    node_id = $(vnode).attr("name");
		    hwtype  = $(vnode).attr("hardware_type");

		    // Link to the (public) shownode page.
		    var weburl = amlist[aggregate_urn].weburl +
			"/portal/show-node.php?node_id=" + node_id;
		    var html   = "<a href='" + weburl + "' target=_blank>" +
			node_id + "</a>";
		    clone.find(" [name=node_id]").html(html);
		    clone.find(" [name=type]").html(hwtype);
		    clientid2nodeid[node] = node_id;

		    // Append to the CONFIRM button URL.
		    if (_.contains(CONFIRMTYPES, hwtype)) {
			var href = $('#confirm-stuff-button').attr("href");
			if (href == "#") {
			    href = "https://confirm.fyi/by-node/?nodes=";
			}
			else {
			    href = href + ",";
			}
			href = href + node_id + ":" + node;
			$('#confirm-stuff-button').attr("href", href);
			$('#confirm-stuff-button').removeClass("hidden");
		    }
		}
		// Convenience.
		clone.find(" [name=select]").attr("id", node);

		// Nice for Cloudlab/Powder
		if (window.ISPOWDER || window.ISCLOUD) {
		    var cluster = amlist[aggregate_urn].abbreviation;
		    
		    clone.find(" [name=cluster]").html(cluster);
		}

		if (stype.length &&
		    $(stype).attr("name") === "emulab-blockstore") {
		    clone.find(" [name=menu]").text("n/a");
		    return;
		}
		if (stype.length &&
		    $(stype).attr("name") === "firewall") {
		    isfw = 1;
		}
		else if (node_id) {
		    if (imageable.length) {
			var available = $(imageable).attr("available");
			if (available === "true") {
			    imageablenodes[node] = node_id;
			}
		    }
		    else {
			// All other named nodes are imageable
			// This can go when all clusters updated
			imageablenodes[node] = node_id;
		    }
		}
		/*
		 * Find the disk image (if any) for the node and display
		 * in the listview.
		 */
		if (vnode.length && $(vnode).attr("disk_image")) {
		    clone.find(" [name=image]")
			.html($(vnode).attr("disk_image"));
		}
		else if (stype.length) {
		    var dimage  = $(stype).find("disk_image");
		    if (dimage.length) {
			var name = $(dimage).attr("name");
			if (name) {
			    var hrn = sup.ParseURN(name);
			    if (hrn && hrn.type == "image") {
				var id = hrn.project + "/" + hrn.image;
				if (hrn.version != null) {
				    id = id + ":" + hrn.version;
				}
				clone.find(" [name=image]").html(id);
			    }
			}
		    }
		}

		if (login.length && dossh) {
		    var user   = window.APT_OPTIONS.thisUid;
		    var host   = $(login).attr("hostname");
		    var port   = $(login).attr("port");
		    var url    = "ssh://" + user + "@" + host + ":" + port +"/";
		    var sshcmd = "ssh -p " + port + " " + user + "@" + host;
		    href       = "<a href='" + url + "'><kbd>" + sshcmd +
			"</kbd></a>";
		
		    var hostport  = host + ":" + port;
		    hostportList[node] = hostport;

		    // Update the row.
		    clone.find(' [name=sshurl]').html(href);
		    
		    // Attach handler to the menu button.
		    clone.find(' [name=shell]')
			.click(function (e) {
			    window.APT_OPTIONS.gaButtonEvent(e);
			    e.preventDefault();
			    ActionHandler("shell", [node]);
			    return false;
			});		    
		}
		else {
		    // Need to do this on the context menu too, but painful.
		    clone.find(' [name=shell]')
			.parent().addClass('disabled');		    
		}

		//
		// Foreign admins do not get a menu, but easier to just
		// hide it.
		//
		if (isfadmin) {
		    clone.find(' [name=action-menu]')
			.addClass("invisible");
		}

		//
		// Now a handler for the console action.
		//
		if (coninfo.length) {
		    // Attach handler to the menu button.
		    clone.find(' [name=console]')
			.click(function (e) {
			    window.APT_OPTIONS.gaButtonEvent(e);
			    ActionHandler("console", [node]);
			});
		    clone.find(' [name=consolelog]')
			.click(function (e) {
			    window.APT_OPTIONS.gaButtonEvent(e);
			    ActionHandler("consolelog", [node]);
			});
		    // Remember we have a console, for the context menu.
		    consolenodes[node] = node;
		}
		else {
		    // Need to do this on the context menu too, but painful.
		    clone.find(' [name=consolelog]')
			.parent().addClass('disabled');		    
		    clone.find(' [name=console]')
			.parent().addClass('disabled');		    
		}
		// Not allowed to delete vhost/firewall or last node at site.
		if (! (isvhost || isfw || rawcount == 1)) {
		    //
		    // Delete button handler
		    //
		    clone.find(' [name=delete]')
			.click(function (e) {
			    window.APT_OPTIONS.gaButtonEvent(e);
			    ActionHandler("delete", [node]);
			});
		}
		else {
		    clone.find(' [name=delete]')
			.parent().addClass('disabled');		    
		}
		if (canrecover) {
		    // Recovery button handler
		    clone.find(' [name=recovery]')
			.click(function (e) {
			    ActionHandler("recovery", [node]);
			});
		}
		else {
		    clone.find(' [name=recovery]')
			.parent().addClass('disabled');		    
		}

		/*
		 * Powder; if the node is a radio (or hosts a radio)
		 * enable the option to load the monitor graph into
		 * a tab.
		 */
		if (window.ISPOWDER && radioinfo && node_id) {
		    var info = IsPowderTransmitter(manager_urn, node_id);
		    if (info) {
			clone.find(' [name=monitor]')
			    .click(function (e) {
				ActionHandler("monitor", [node]);
			    });
			clone.find(' [name=monitor]')
			    .parent().removeClass('hidden');

			// Context menu option
			CMclone.find("li[id=monitor]").removeClass("hidden");

			// Mark it as a radio with its info. 
			radios[node] = info;
		    }

		    if (flashable.length) {
			var available = $(flashable).attr("available");
			if (available === "true") {
			    clone.find(' [name=flash]')
				.click(function (e) {
				    ActionHandler("flash", [node]);
				});
			    clone.find(' [name=flash]')
				.parent().removeClass('hidden');

			    // Context menu option
			    CMclone.find("li[id=flash]").removeClass("hidden");
			}
		    }
		}

		//
		// Power cycle handler
		//
		if (pcycle.length) {
		    // Attach handler to the menu button.
		    clone.find(' [name=powercycle]')
			.click(function (e) {
			    window.APT_OPTIONS.gaButtonEvent(e);
			    ActionHandler("powercycle", [node]);
			});
		    clone.find(' [name=powercycle]')
			.parent().removeClass('hidden');

		    // Context menu option
		    CMclone.find("li[id=powercycle]").removeClass("hidden");
		}

		// Node "top"
		clone.find(' [name=nodetop]')
		    .click(function (e) {
			ActionHandler("nodetop", [node]);
		    });
		clone.find(' [name=nodetop]')
		    .parent().removeClass('hidden');
		// Context menu option
		CMclone.find("li[id=nodetop]").removeClass("hidden");

		// Insert into the table, we will attach the handlers below.
		$('#listview_table > tbody:last').append(clone);

		// Change the ID of the clone so its unique.
		CMclone.attr('id', "context-menu-" + node);

		// Activate tooltips in the menu.
		CMclone.find('[data-toggle="tooltip"]')
		    .tooltip({"trigger"   : "hover",
			      "container" : "body",
			      "placement" : "auto right",
			     });
	    
		// Insert into the context-menus div.
		$('#context-menus').append(CMclone);

		// If no console, then grey out the options.
		if (!_.has(consolenodes, node)) {
		    $(CMclone).find("li[id=console]").addClass("disabled");
		    $(CMclone).find("li[id=consolelog]").addClass("disabled");
		    // For ActionHandler()
		    $(CMclone).find("[name=console]").attr("disabled", true);
		    $(CMclone).find("[name=consolelog]").attr("disabled", true);
		}
		// If no recovery mode, grey out the option.
		if (!canrecover) {
		    $(CMclone).find("li[id=recovery]").addClass("disabled");
		    // For ActionHandler()
		    $(CMclone).find("[name=recovery]").attr("disabled", true);
		}
		if (! (login.length && dossh)) {
		    $(CMclone).find("li[id=shell]").addClass("disabled");
		}
		
		// If a vhost/firewall, then grey out options. Or if there
		// is just one node at this site.
		if (isvhost || isfw || rawcount == 1) {
		    $(CMclone).find("li[id=delete]").addClass("disabled");
		    // For ActionHandler()
		    $(CMclone).find("[name=delete]").attr("disabled", true);
		}
		contextMenus[node] = CMclone;
		nodecount++;
	    });
	}

	/*
	 * After reloading the topology or deleting a node, just rebuild
	 * everything. 
	 */
	if (changingtopo) {
	    // Clear the list view table before adding nodes again.
	    $('#listview_table > tbody').html("");
	    // Reload all manifests.
	    manifests = {};
	    // Need to redo the lists.
	    clientid2nodeid = {};
	    imageablenodes  = {};
	    redrawpowdermap = true;

	    // But might have deleted all the aggregates.
	    if (Object.keys(statusblob).length == 0) {
		changingtopo = false;
		ClearViewer();
		if (window.ISPOWDER) {
		    UpdatePowderMap();
		}
		donefunc();
		return;
	    }
	}
	/*
	 * If we have all the manifests then nothing to do.
	 */
	if (Object.keys(statusblob).length == Object.keys(manifests).length) {
	    donefunc();
	    return;
	}

	// Save off some templatizing data as we process each manifest.
	// Do not need to do this stuff on a topo change.
	var uridata = {};
	    
	// Save off the last manifest xml blob so we quick process the
	// possibly templatized instructions quickly, without reparsing the
	// manifest again needlessly.
	var xml = null;

	/*
	 * This is the continuation we run after we have all the
	 * manifests that are currently available.
	 */
	var gotallmanifests = function() {
	    //console.info("gotallmanifests");
	    
	    // Did we get any new manifests?
	    if (!xml) {
		// Signal GetStatus() looper that we are done, 
		donefunc();
		return;
	    }
	    // Do not show secrets if viewing using foreign admin creds
	    if (!isfadmin) {
		// This will update the instructions.
		FindEncryptionBlocks(xml);
	    }
	    // Update the snapshot modal with new nodes.
	    UpdateSnapshotModal();

	    // Site context menu setup.
	    setTimeout(SetupSiteContextMenus, 3000);

	    if (window.ISPOWDER) {
		if (redrawpowdermap) {
		    UpdatePowderMap()
		}
		else {
		    var showmap = false;

		    // If we have at least one manifest, show the map.
		    $.each(statusblob, function(urn) {
			if (_.has(manifests, urn)) {
			    showmap = true;
			}
		    });
		    if (showmap) {
			ShowPowderMapTab();
		    }
		}
	    }
	    // Signal GetStatus() looper that we are done, 
	    donefunc();
	};

	/*
	 * Process one manifest at a time, then finish with above function.
	 */
	var gotonemanifest = function(aggregate_urn, manifest) {
	    //console.info("gotonemanifest", aggregate_urn);

	    TimeStamp("Proccessing manifest");

	    var xmlDoc = $.parseXML(manifest);
	    xml = $(xmlDoc);
	    MakeUriData(xml,uridata);
	    ProcessNodes(aggregate_urn, xml);
	    TimeStamp("Done proccessing manifest");

	    UpdateInstructions(xml, uridata);

	    /*
	     * Wait until we have first manifest before initializing this,
	     * else the user sees a blank palette.
	     */
	    $("#showtopo_container").removeClass("invisible");
	    $('#quicktabs_ul a[href="#manifest"]')
		.parent().removeClass("hidden");
	    $('#quicktabs_content #manifest').removeClass("hidden");
	    /*
	     * Cannot be hidden to initialize tablesorter
	     */
	    if ($('#quicktabs_content #listview').hasClass("hidden")) {
	   	$('#quicktabs_ul a[href="#listview"]')
		    .parent().removeClass("hidden");
		$('#quicktabs_content #listview').removeClass("hidden");

		$('#listview_table')
		    .tablesorter({
			theme : 'bootstrap',
			widgets : [ "uitheme", "zebra"],
			headerTemplate : '{content} {icon}',
		    });

		// Handler for select/deselect all rows in the list view.
		$('#select-all').change(function () {
		    if ($(this).prop("checked")) {
			$('#listview_table [name=select]')
			    .prop("checked", true);
		    }
		    else {
			$('#listview_table [name=select]')
			    .prop("checked", false);
		    }
		});
		// Handler for the action menu next to the select-all checkbox:
		// Foreign admins do not get a menu, but easier to just hide it.
		if (isfadmin) {
		    $('#listview-action-menu').addClass("invisible");
		}
		else {
		    $('#listview-action-menu li a')
			.click(function (e) {
			    window.APT_OPTIONS.gaButtonEvent(e);
			    var checked = [];

			    // Get the list of checked nodes.
			    $('#listview_table [name=select]').each(function() {
				if ($(this).prop("checked")) {
				    checked.push($(this).attr("id"));
				}
			    });
			    if (checked.length) {
				ActionHandler($(e.target).attr("name"),
					      checked);
			    }
			});
		}
	    }

	    if (Object.keys(statusblob).length > 1 ||
		nodecount < MAXJACKSNODES) {
		if (!jacksInstance) {
		    $('#quicktabs_ul a[href="#topology"]')
			.parent().removeClass("hidden");
		    $('#quicktabs_content #topology').removeClass("hidden");
		    $('#quicktabs_ul a[href="#topology"]').tab('show');
		    ShowViewer('#showtopo_statuspage',
			       Object.keys(statusblob).length > 1, manifest);
		}
		else if (changingtopo) {
		    // When we get first new manifest, clear the viewer palette.
		    ClearViewer(manifest);
		    //AddToViewer(manifest);
		}
		else {
		    AddToViewer(manifest);
		}
	    }
	    else {
		$('#quicktabs_ul a[href="#listview"]').tab('show');
		ShowManifest(manifest);
	    }
	    // Clear changingtopo state on first new manifest.
	    if (changingtopo) {
		changingtopo = false;
	    }

	    /*
	     * No point in showing linktest if no links at any site.
	     * For the moment, we do not count links if they span sites
	     * since linktest does not work across stitched links.
	     *
	     * We reset showlinktest cause we get called again after
	     * a topo change or reload.
	     */
	    showlinktest = false;
	    $(xml).find("link").each(function() {
		var managers = $(this).find("component_manager");
		if (managers.length == 1)
		    showlinktest = true;
	    });
	    SetupLinktest(instanceStatus);

	    // Mark that we have this manifest;
	    manifests[aggregate_urn] = manifest;
	}
	var p = $.when();
	Object.keys(statusblob)
	    .forEach(function(urn) {
		if (_.has(manifests, urn) ||
		    statusblob[urn] == null ||
		    !statusblob[urn].havemanifest) {
		    p = p.then(function () { return 0; });
		}
		else {
		    p = p.then(function() {
			return sup.CallServerMethod(null, "status",
						    "GetInstanceManifest",
						    {"uuid" : uuid,
						     "aggregate_urn" : urn},
			     function (json) {
				 if (json.code) {
				     console.info("GetInstanceManifest:" +
						  json.value);
				     donefunc();
				     return -1;
				 }
				 gotonemanifest(urn, json.value);
				 return 0;
			     });
		    });
		}
	    });
	
	p = p.then(function () { gotallmanifests(); });
    }

    //
    // Show the manifest in the tab, using codemirror.
    //
    function ShowManifest(manifest)
    {
	//console.info("ShowManifest");
	
	var mode   = "text/xml";

	$("#manifest_textarea").css("height", "300");
	$('#manifest_textarea .CodeMirror').remove();

	var myCodeMirror = CodeMirror(function(elt) {
	    $('#manifest_textarea').prepend(elt);
	}, {
	    value: manifest,
            lineNumbers: false,
	    smartIndent: true,
            mode: mode,
	    readOnly: true,
	});

	$('#show_manifest_tab').on('shown.bs.tab', function (e) {
	    myCodeMirror.refresh();
	});
	ShowBindings();
    }

    //
    // Show the rspec in the tab, using codemirror.
    //
    function ShowRspec()
    {
	var mode   = "text/xml";

	$("#rspec_textarea").css("height", "300");
	$('#rspec_textarea .CodeMirror').remove();

	var callback = function (json) {
	    //console.info(json);
	    if (json.code) {
		console.info("Could not get rspec: " + json.value);
		return;
	    }
	    var myCodeMirror = CodeMirror(function(elt) {
		$('#rspec_textarea').prepend(elt);
	    }, {
		value: json.value,
		lineNumbers: false,
		smartIndent: true,
		mode: mode,
		readOnly: true,
	    });

	    $('#show_rspec_tab').on('shown.bs.tab', function (e) {
		myCodeMirror.refresh();
	    });
	    $("#showtopo_container").removeClass("invisible");
	    $('#quicktabs_ul a[href="#rspec"]').parent().removeClass("hidden");
	    $('#quicktabs_content #rspec').removeClass("hidden");
	    $('#quicktabs_ul a[href="#rspec"]').tab('show');
	};
	sup.CallServerMethod(null, "status", "GetRspec",
			     {"uuid"     : uuid}, callback);
    }

    //
    // Show the parameter bindings in the tab.
    //
    function ShowBindings()
    {
	// Only parameterized profiles of course.
	if (! expinfo.paramdefs) {
	    return;
	}
	// Enable the Save Params button. 
	if (expinfo.profile_uuid != "unknown" && expinfo.params &&
	    $('#save_paramset_button').hasClass("hidden")) {
	    $('#save_paramset_button')
		.removeClass("hidden")
		.popover({trigger:  'hover',
			  placement:'auto',
			  container:'body'})
		.click(function (event) {
		    paramsets.InitSaveParameterSet('#save_paramset_div',
						   expinfo.profile_uuid,
						   uuid);
		});
	    $('#rerun_button')
	        .click(function (e) {
		    e.preventDefault();
		    sup.ShowModal("#rerun_modal");
		})
		.removeClass("hidden");
	    // Bind the copy to clipbload button in the share modal
	    window.APT_OPTIONS.SetupCopyToClipboard("#rerun_modal");

	}
	if (expinfo.params &&
	    $('#quicktabs_content #bindings').hasClass("hidden")) {
	    var bindings  = expinfo.params;
	    var paramdefs = expinfo.paramdefs;
	    var html = GetBindingsTable(paramdefs, bindings);
	    $('#bindings_table tbody').html(html);
	    $('#quicktabs_ul a[href="#bindings"]')
		.parent().removeClass("hidden");
	    $('#quicktabs_content #bindings').removeClass("hidden");
	}
    }

    function MakeUriData(xml,uridata)
    {
	xml.find('node').each(function () {
	    var node = $(this);
	    var host = node.find('host').attr('name');
	    if (host) {
		var key = 'host-' + node.attr('client_id');
		uridata[key] = host;
	    }
	});
    }

    function FindEncryptionBlocks(xml)
    {
	var blocks    = {};
	var passwords = xml[0].getElementsByTagNameNS(EMULAB_NS, 'password');

	// Search the instructions for the pattern.
	var regex   = /\{password-.*\}/gi;
	var needed  = $('#instructions_text').html().match(regex);
	//console.log(needed);

	if (!needed || !needed.length)
	    return;

	// Look for all the encryption blocks in the manifest ...
	_.each(passwords, function (password) {
	    var name  = $(password).attr('name');
	    var stuff = $(password).text();
	    var key   = 'password-' + name;

	    // ... and see if we referenced it in the instructions.
	    _.each(needed, function(match) {
		var token = match.slice(1,-1);
		
		if (token == key) {
		    blocks[key] = stuff;
		}
	    });
	});
	// These are blocks that are referenced in the instructions
	// and need the server to decrypt.  At some point we might
	// want to do that here in javascript, but maybe later.
	//console.log(blocks);

	var callback = function(json) {
	    //console.log(json);
	    if (json.code) {
		sup.SpitOops("oops", "Could not decrypt secrets: " +
			     json.value);
		return;
	    }
	    var itext = $('#instructions_text').html();

	    _.each(json.value, function(plaintext, key) {
		key = new RegExp("{" + key + "}", "g");
		// replace in the instructions text.
		itext = itext.replace(key, plaintext);
	    });
	    // Write the instructions back after replacing patterns
	    $('#instructions_text').html(itext);
	};
    	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "DecryptBlocks",
					    {"uuid"   : uuid,
					     "blocks" : blocks});
	xmlthing.done(callback);
    }

    /*
     * Add a context menu to the site tags
     */
    function SetupSiteContextMenus()
    {
	// We do not have Jacks support, so find the site blob labels.
	var sitetags = {};

	$('g.sitelabelgroup text.sitetext').each(function () {
	    var tag = $(this).text();
	    if (tag != "") {
		sitetags[tag] = $(this);
	    }
	});
	console.info("SetupSiteContextMenus", sitetags);
	if (!_.size(sitetags)) {
	    return;
	}
	
	_.each(manifests, function (manifest, urn) {
	    var nickname = amlist[urn].name;

	    if (_.has(sitetags, nickname)) {
		var sitetag  = sitetags[nickname];

		$(sitetag).click(function (event) {
		    SiteContextMenuShow(event, sitetag, urn);
		});
	    }
	});
    }

    /*
     * Delete a site.
     */
    function DoDeleteSite(urn)
    {
	var nickname = amlist[urn].nickname;

	// Handler for hide modal to unbind the click handler.
	$('#deletesite_modal').one('hidden.bs.modal', function (event) {
	    $('#deletesite_confirm').unbind("click.deletesite");
	});
	
	// Throw up a confirmation modal, with handler bound to confirm.
	$('#deletesite_confirm').bind("click.deletesite", function (event) {
	    sup.HideModal('#deletesite_modal');
	
	    var callback = function(json) {
		console.info(json);
		sup.HideWaitWait(function () {		
		    if (json.code) {
			sup.SpitOops("oops", json.value);
			return;
		    }
		});
		// Pickup the change before next interval timeout
		GetStatus();
	    }
	    sup.ShowWaitWait("This will take several minutes. " +
			     "Patience please.");
	    var xmlthing = sup.CallServerMethod(ajaxurl,
						"status",
						"DeleteSite",
						{"uuid"     : uuid,
						 "cluster"  : nickname});
	    xmlthing.done(callback);
	});
        $('#error_panel').addClass("hidden");
	sup.ShowModal('#deletesite_modal');
    }

    function ShowProgressModal()
    {
        ShowImagingModal(
		         function()
			 {
			     return sup.CallServerMethod(ajaxurl,
							 "status",
							 "SnapshotStatus",
							 {"uuid" : uuid});
			 },
			 function(failed)
			 {
			 },
	                 false);
    }

    function SetupSnapshotModal()
    {
	var snapshot_help_timer;
	var clone_help_timer;

	/*
	 * We now show the single imaging button all the time. The workflow
	 * we present later depends on canclone/cansnap. But not allowed
	 * to clone a repo based profile.
	 */
	if (! (window.APT_OPTIONS.canclone_profile ||
	       window.APT_OPTIONS.canupdate_profile ||
	       window.APT_OPTIONS.cansnapshot)) {
	    return;
	}

	$("button#snapshot_button").click(function(event) {
	    $('button#snapshot_button').popover('hide');
	    DoSnapshotNode();
	});

	/*
	 * Various help buttons for snapshot choices.
	 */
	var visibleHelp = null;
	
	$('.snapshot-help-button').each(function () {
	    var target  = $(this).find("span");
	    var which   = target.data("which");
	    var content = null;
	    
	    console.info("foo", this, which, target);

	    switch(which) {
	    case 'update-profile':
		content = $('#snapshot-help-div').html();
		break;
	    case 'copy-profile':
		content = $('#clone-help-div').html();
		break;
	    case 'image-only':
		content = $('#imageonly-help-div').html();
		break;
	    }
	    $(target).popover({
		html:     true,
		content:  content,
		trigger:  'manual',
		placement:'auto',
		container:'body',
	    });
	    
	    $(this).click(function (event) {
		event.preventDefault();

		if (visibleHelp) {
		    var tmp = visibleHelp;
		    visibleHelp = null;
		    
		    tmp.popover('hide');
		    // Clicked on the same one, hide it and leave.
		    if (tmp.data("which") == which) {
			return;
		    }
		}
		$(target).popover('show');
		visibleHelp = $(target);

		// Bind the close button, sleazy internal stuff.
		$(target).data('bs.popover').tip()
		    .find(".close").click(function (event) {
			$(target).popover('hide');
			$(this).off("click");
			visibleHelp = null;
		    });
	    });
	});
	
	$('#snapshot_modal input[type=radio]').on('change', function() {
	    switch($(this).val()) {
	    case 'update-profile':
		$('#snapshot-name-div').addClass("hidden");
		$('#snapshot-wholedisk-div').addClass("hidden");
		break;
	    case 'copy-profile':
		$('#snapshot-name-div .image-only').addClass("hidden");
		$('#snapshot-name-div .copy-profile').removeClass("hidden");
		$('#snapshot-name-div').removeClass("hidden");
		if (wholedisk) {
		    $('#snapshot-wholedisk-div').removeClass("hidden");
		}
		break;
	    case 'image-only':
		$('#snapshot-name-div .copy-profile').addClass("hidden");
		$('#snapshot-name-div .image-only').removeClass("hidden");
		$('#snapshot-name-div').removeClass("hidden");
		if (wholedisk) {
		    $('#snapshot-wholedisk-div').removeClass("hidden");
		}
		break;
	    }
	});

	/*
	 * Hide choices in the snapshot modal per the flags.
	 */
	if (isscript ||
	    (!window.APT_OPTIONS.canclone_profile &&
	     !window.APT_OPTIONS.canupdate_profile)) {
	    $('#snapshot-name-div .image-only').removeClass("hidden");
	    $('#snapshot-name-div').removeClass("hidden");
	    if (wholedisk) {
		$('#snapshot-wholedisk-div').removeClass("hidden");
	    }
	}
	else {
	    if (!window.APT_OPTIONS.canclone_profile) {
		$('#copy-profile-radio').remove();
	    }
	    else if (!window.APT_OPTIONS.canupdate_profile) {
		$('#update-profile-radio').remove();
	    }
	    // As per the 'isscript' test above, one of these must be
	    // available, so make the other the default.
	    if (!window.APT_OPTIONS.canupdate_profile) {
		    $('#copy-profile').prop("checked", true);
		    $('#copy-profile').trigger("change");
	    }
	}
    }

    /*
     * Update the list of nodes in the modal as manifests come in.
     */
    function UpdateSnapshotModal() {
	/*
	 * We now show the single imaging button all the time. The workflow
	 * we present later depends on canclone/cansnap. But not allowed
	 * to clone a repo based profile.
	 */
	if (! (window.APT_OPTIONS.canclone_profile ||
	       window.APT_OPTIONS.canupdate_profile ||
	       window.APT_OPTIONS.cansnapshot)) {
	    return;
	}
	$("#snapshot_button").removeClass("hidden");

	/*
	 * Create an options list for the dropdown. We are going to replace
	 * the existing contents, so add the first option.
	 */
	var html = "<option value=''>Please Select a Node</option>";
		    
	_.each(imageablenodes, function (node_id, client_id) {
	    html = html +
		"<option value='" + client_id + "'>" +
		client_id + " (" + node_id + ")" +
		"</option>";
	});
	$('#snapshot_modal .choose-node select').html(html);

	if (Object.keys(imageablenodes).length == 1) {
	    // One node, stick that into the first sentence.
	    var nodename = Object.keys(imageablenodes)[0];
	    $('#snapshot_modal .one-node .node_id')
		.html(nodename + " (" + imageablenodes[nodename] + ")");
	    $('#snapshot_modal .choose-node').addClass("hidden");
	    $('#snapshot_modal .one-node.text-info').removeClass("hidden");
	    // And select it in the options for later, but stays hidden.
	    $('#snapshot_modal .choose-node select').val(nodename);
	}
	else {
	    $('#snapshot_modal .one-node.text-info').addClass("hidden");
	    $('#snapshot_modal .choose-node').removeClass("hidden");
	}

	/*
	 * If the user decides to create an image only, then lets try
	 * to guide them to reasonable choice for the name to use. 
	 */
	if (Object.keys(imageablenodes).length == 1) {
	    /*
	     * If allowed to update image, then use the current profile name.
	     * Otherwise might as well let them choose the name.
	     */
	    if (window.APT_OPTIONS.cansnapshot) {
		$('#snapshot-name-div input')
		    .val(expinfo.profile_name);
		$('#snapshot-name-div .snapshot-name-warning')
		    .removeClass("hidden");
	    }
	    $('#snapshot_modal .choose-node select').off("change");
	}
	else {
	    /*
	     * Lets append the name of the choosen node to the profile name.
	     */
	    $('#snapshot_modal .choose-node select').off("change");
	    $('#snapshot_modal .choose-node select')
		.on("change", function (event) {
		    var node = $(this).val();
		    var name = expinfo.profile_name + "." + node;
		    $('#snapshot-name-div input').val(name);
		    $('#snapshot-name-div .snapshot-name-warning')
			.removeClass("hidden");
		});
	}
    }

    /*
     * New version of disk image creation.
     */
    function DoSnapshotNode()
    {
	// Do not allow snapshot if the experiment is not in the ready state.
	if (lastStatus != "ready") {
	    alert("Experiment is not ready yet, snapshot not allowed");
	    return;
	}
	// Clear previous errors
	$('#snapshot_modal .snapshot-error').addClass("hidden");
	
	// Default to unchecked any time we show the modal.
	//$('#snapshot_update_prepare').prop("checked", false);
	//$('#snapshot-wholedisk').prop("checked", false);
	
	//
	// Watch for the case that we would create a new version of a
	// system image.  Warn the user of this.
	//
	if (expinfo.project == EMULAB_OPS) {
	    $('#cancel-update-systemimage').click(function() {
		sup.HideModal('#confirm-update-systemimage-modal');
	    });
	    $('#confirm-update-systemimage').click(function() {
		sup.HideModal('#confirm-update-systemimage-modal');
		DoSnapshotNodeAux();
	    });
	    sup.ShowModal('#confirm-update-systemimage-modal',
			  function() {
			      $('#cancel-update-systemimage')
				  .off("click");
			      $('#confirm-update-systemimage')
				  .off("click");
			  });
	    return;
	}
	DoSnapshotNodeAux();
    }
    function DoSnapshotNodeAux()
    {
	var node_id;

	// Handler for the Snapshot confirm button.
	$('button#snapshot_confirm').bind("click.snapshot", function (event) {
	    event.preventDefault();
	    
	    // Clear previous errors
	    $('#snapshot_modal .snapshot-error').addClass("hidden");
	    
	    // Make sure node is selected (one node, it is forced selection).
	    node_id = $('#snapshot_modal .choose-node select ' +
			'option:selected').val();
	    if (node_id === undefined || node_id === '') {
		$('#snapshot_modal .choose-node-error')
		    .text("Please choose a node");
		$('#snapshot_modal .choose-node-error').removeClass("hidden");
		return;
	    }
	    $('#snapshot_modal .choose-node-error').addClass("hidden");

	    // What does the user want to do?
	    var operation =
		(isscript ? "image-only" :
		 $('#snapshot_modal input[type=radio]:checked').val());
	    
	    var args = {"uuid" : uuid,
			"node_id" : node_id,
			"operation" : operation,
			"update_prepare" : 0};
	    // Make sure we got an image/profile name.
	    if (operation == 'image-only') {
		var name = $('#snapshot-name-div input').val();
		if (name == "") {
		    $('#snapshot-name-div .name-error')
			.text("Please provide an image name");
		    $('#snapshot-name-div .name-error').removeClass("hidden");
		    return;
		}
		args["imagename"] = name;
	    }
	    else if (operation == "copy-profile" ||
		     operation == "new-profile") {
		var name = $('#snapshot-name-div input').val();
		if (name == "") {
		    $('#snapshot-name-div .name-error')
			.text("Please provide a profile name");
		    $('#snapshot-name-div .name-error').removeClass("hidden");
		    return;
		}
		args["profilename"] = name;
	    }
	    if ($('#snapshot_update_prepare').is(':checked')) {
		args["update_prepare"] = 1;
	    }
	    if (wholedisk &&
		$('#snapshot-wholedisk').is(':checked') &&
		(operation == "copy-profile" ||
		 operation == "new-profile" || operation == "image-only")) {
		args["wholedisk"] = 1;
	    }
	    args["description"] = 
		$.trim($('#snapshot-description-div textarea').val());

	    if (operation == "copy-profile" || operation == "new-profile") {
		NewProfile(args);
	    }
	    else {
		StartSnapshot(args);
	    }
	});

	// Handler for hide modal to unbind the click handler.
	$('#snapshot_modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('button#snapshot_confirm').unbind("click.snapshot");
	    // Hide any popovers still showing.
	    $('.snapshot-help-button').each(function () {
		var target = $(this).find("span");
		target.popover('hide');
	    });
	});

	sup.ShowModal('#snapshot_modal');
    }
    
    function StartSnapshot(args)
    {
	var callback = function(json) {
	    console.log("StartSnapshot");
	    console.log(json);
	    sup.HideWaitWait(function () {
		if (json.code) {
		    if (json.code == GENIRESPONSE_ALREADYEXISTS &&
			_.has(args, "wholedisk")) {
			sup.SpitOops("oops",
				 "There is already an image with the " +
				 "the name you requested. When using the " +
				 "<em>wholedisk</em> option, you must create " +
				 "a brand new image. " +
				 "If you really want to use this name, " +
				 "please <a href='list-images.php'>" +
				 "delete the existing image first</a>.");
			return;
		    }
		    sup.SpitOops("oops", json.value);
		    return;
		}
		ShowProgressModal();
	    });
	};
	CheckSnapshotArgs(args, function() {
	    sup.HideModal('#snapshot_modal', function () {
		sup.ShowWaitWait("Starting image capture, " +
				 "this can take a minute. " +
				 "Patience please.");

		sup.CallServerMethod(ajaxurl, "status",
				     "SnapShot", args, callback);
	    });
	});
    }

    /*
     * First do an initial check on the arguments.
     */
    function CheckSnapshotArgs(args, continuation)
    {
	args["checkonly"] = 1;
	sup.CallServerMethod(ajaxurl, "status", "SnapShot", args,
	     function (json) {
		 console.info("CheckSnapshotArgs");
		 console.info(json);
		 if (json.code) {
		     if (json.code != 2) {
			 $('#snapshot_modal .general-error')
			     .text(json.value)
			 $('#snapshot_modal .general-error')
			     .removeClass("hidden");
			 return;
		     }
		     if (_.has(json.value, "imagename")) {
			 $('#snapshot_modal .name-error')
			     .html(json.value.imagename);
			 $('#snapshot_modal .name-error')
			     .removeClass("hidden");
		     }
		     if (_.has(json.value, "description")) {
			 $('#snapshot_modal .description-error')
			     .html(json.value.description);
			 $('#snapshot_modal .description-error')
			     .removeClass("hidden");
		     }
		     if (_.has(json.value, "node_id")) {
			 $('#snapshot_modal .choose-node-error')
			     .html(json.value.node_id);
			 $('#snapshot_modal .choose-node-error')
			     .removeClass("hidden");
		     }		     
		     return;
		 }
		 args["checkonly"] = 0;
		 continuation(args);
	     });
    }

    function CheckCreateProfileArgs(args, continuation)
    {
	args["checkonly"] = 1;
	sup.CallServerMethod(ajaxurl, "manage_profile", "Create", args,
	     function (json) {
		 console.info("CheckCreateProfileArgs");
		 console.info(json);
		 if (json.code) {
		     if (json.code != 2) {
			 $('#snapshot_modal .general-error')
			     .text(json.value)
			 $('#snapshot_modal .general-error')
			     .removeClass("hidden");
			 return;
		     }
		     if (_.has(json.value, "profile_name")) {
			 $('#snapshot_modal .name-error')
			     .html(json.value.profile_name);
			 $('#snapshot_modal .name-error')
			     .removeClass("hidden");
		     }
		     return;
		 }
		 args["checkonly"] = 0;
		 continuation(args);
	     });
    }

    /*
     *
     */
    function NewProfile(args)
    {
	var createArgs = {
	    "formfields" : {"action"       : "clone",
			    "profile_pid"  : expinfo.project,
			    "profile_name" : args["profilename"],
			    "profile_who"  : "public",
			    "snapuuid"     : expinfo.uuid,
			    "snapnode_id"  : args.node_id,
			    "update_prepare" : args["update_prepare"],
			   },
	};
	if (args["operation"] == "copy-profile") {
	    createArgs["formfields"]["copy-profile"] =
		expinfo.profile_uuid;
	}
	/*
	 * Callback after creating new profile with snapshot operation.
	 */
	var createprofile_callback = function(json) {
	    console.log("create profile", json);
	    
	    if (json.code) {
		sup.HideWaitWait(function() {
		    sup.SpitOops("oops", "Error creating new profile. Please" +
				 "see the javascript console");
		});
		return;
	    }
	    window.location.replace(json.value);
	}
	 
	/*
	 * Callback after asking the cluster to create the image descriptor.
	 * Now we can go ahead and create the profile and start the imaging
	 * process.
	 */
	var checkimage_callback = function(json) {
	    console.log("create image", json);
	    
	    if (json.code) {
		sup.HideWaitWait(function() {
		    if (json.code == GENIRESPONSE_ALREADYEXISTS) {
			sup.SpitOops("oops",
				     "There is already an image with the " +
				     "same name as your profile; using this " +
				     "name would overwrite the existing image "+
				     "which is probably not what you want. " +
				     "If you really want to use this name, " +
				     "please <a href='list-images.php'>" +
				     "delete the existing image first</a>.");
			return;
		    }
		    sup.SpitOops("oops", json.value);
		});
		return;
	    }
	    var xmlthing =
		sup.CallServerMethod(ajaxurl, "manage_profile",
				     "Create", createArgs);
	    xmlthing.done(createprofile_callback);
	}

	/*
	 * Check args for image/profile before doing anything.
	 */
	CheckSnapshotArgs(args, function() {
	    CheckCreateProfileArgs(createArgs, function () {
		/*
		 * Now create the descriptor but do not image yet. 
		 */
		args["nosnapshot"] = 1;
		args["imagename"]  = args["profilename"];
		sup.HideModal('#snapshot_modal', function () {
		    sup.ShowWaitWait("Please wait while we create your " +
				     "profile and start the imaging process. " +
				     "Patience please!");
		    var xmlthing =
			sup.CallServerMethod(null, "status", "SnapShot", args);
		    xmlthing.done(checkimage_callback);
		});
	    });
	});
    }

    //
    // User clicked on a node, so we want to create a tab to hold
    // the ssh tab with a panel in it, and then call StartSSH above
    // to get things going.
    //
    var constabcounter = 0;

    function NewConsoleTab(client_id)
    {
	sup.ShowModal('#waitwait-modal');

	var callback = function(json) {
	    console.info("NewConsoleTab", json);
	    sup.HideModal('#waitwait-modal');
	    
	    if (json.code) {
		sup.SpitOops("oops", json.value);
		return;
	    }
	    var url = json.value.url + '&noclose=1';

	    if (_.has(json.value, "password")) {
		nodePasswords[client_id] = json.value.password;
	    }
	    
	    //
	    // Need to create the tab before we can create the topo, since
	    // we need to know the dimensions of the tab.
	    //
	    var tabname = client_id + "console_tab";
	    if (! $("#" + tabname).length) {
		// The tab.
		var html = "<li><a href='#" + tabname + "' data-toggle='tab'>" +
		    client_id + "-Cons" +
		    "<button class='close' type='button' " +
		    "        id='" + tabname + "_kill'>x</button>" +
		    "</a>" +
		    "</li>";	

		// Append to end of tabs
		$("#quicktabs_ul").append(html);

		// GA handler.
		var ganame = "console_" + ++constabcounter;
		$('#quicktabs_ul a[href="#' + tabname + '"]')
		    .on('shown.bs.tab', function (event) {
			window.APT_OPTIONS.gaTabEvent("show", ganame);
		    });
		window.APT_OPTIONS.gaTabEvent("create", ganame);

		// Install a kill click handler for the X button.
		$("#" + tabname + "_kill").click(function(e) {
		    window.APT_OPTIONS.gaTabEvent("kill", ganame);
		    e.preventDefault();
		    // remove the li from the ul. this=ul.li.a.button
		    $(this).parent().parent().remove();
		    // Activate the "profile" tab.
		    $('#quicktabs_ul li a:first').tab('show');
		    // Trigger the custom event.
		    $("#" + tabname).trigger("killconsole");
		    // Remove the content div. Have to delay this though.
		    // See below.
		    setTimeout(function(){
			$("#" + tabname).remove() }, 3000);
		});

		// The content div.
		html = "<div class='tab-pane' id='" + tabname + "'></div>";

		$("#quicktabs_content").append(html);

		// And make it active
		$('#quicktabs_ul a:last').tab('show') // Select last tab

		// Now create the console iframe inside the new tab
		if (APT_OPTIONS.webssh && _.has(json.value, "authobject")) {
		    var jsonauth = $.parseJSON(json.value.authobject);
		    
		    if (_.has(jsonauth, "webssh") && jsonauth.webssh != 0) {
			StartConsoleNew(tabname, json.value);
			return;
		    }
		}
		if (1) {
		    var iwidth = "100%";
		    var iheight = 400;
		
		    var html = '<iframe id="' + tabname + '_iframe" ' +
			'width=' + iwidth + ' ' +
			'height=' + iheight + ' ' +
			'src=\'' + url + '\'>';
	    
		    if (_.has(json.value, "password")) {
			html =
			    "<div class='col-sm-4 col-sm-offset-4 " +
			    "     text-center'>" +
			    " <small> " +
			    " <a data-toggle='collapse' " +
			    "    href='#password_" + tabname + "'>Password" +
			    "   </a></small> " +
			    " <div id='password_" + tabname + "' " +
			    "      class='collapse'> " +
			    "  <div class='well well-xs'>" +
			    nodePasswords[client_id] +
			    "  </div> " +
			    " </div> " +
			    "</div> " + html;
		    }		
		    $('#' + tabname).html(html);

		    //
		    // Setup a custom event handler so we can kill the
		    // connection.  Called from the kill click handler
		    // above.
		    //
		    // Post a kill message to the iframe. See nodetipacl.php3.
		    // Since postmessage is async, we have to wait before we
		    // can actually kill the content div with the iframe, cause
		    // its gone before the message is delivered. Just delay a
		    // couple of seconds. Maybe add a reply message later. The
		    // delay is above.
		    //
		    // In firefox, nodetipacl.php3 does not install a handler,
		    // so now the shellinabox code has that handler, and so this
		    // gets posted to the box directly. Oh well, so much for
		    // trying to stay out of the box code.
		    //
		    var sendkillmessage = function (event) {
			var iframe = $('#' + tabname + '_iframe')[0];
			iframe.contentWindow.postMessage("kill", "*");
		    };
		    // This is the handler for the button, which invokes
		    // the function above.
		    $('#' + tabname).on("killconsole", sendkillmessage);
		}
	    }
	    else {
		// Switch back to it.
		$('#quicktabs_ul a[href="#' + tabname + '"]').tab('show');
		return;
	    }
	}
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "ConsoleURL",
					    {"uuid" : uuid,
					     "node" : client_id});
	xmlthing.done(callback);
    }

    function StartConsoleNew(tabname, coninfo)
    {
	var authobject = coninfo.authobject;
	var jsonauth   = $.parseJSON(authobject);
        var url        = jsonauth.baseurl;

	// Backwards compat for a while.
	if (!url.includes("webssh")) {
	    url = url + "/webssh/webssh.html";
	}

	var loadiframe = function () {
	    console.info("Sending message", jsonauth.baseurl);
	    iframewindow.postMessage(authobject, "*");
	    window.removeEventListener("message", loadiframe, false);
	};
	window.addEventListener("message", loadiframe);

	var html =
	    '<div style="height:31em; width:100%; ' +
	    '           resize:vertical;overflow-y:auto;padding-bottom:10px">' +
	    '  <iframe id="' + tabname + '_iframe" ' +
	    '     width="100%" height="100%"' + 
            '     src=\'' + url + '\'></iframe>' +
	    '</div>';
	
	if (_.has(coninfo, "password")) {
	    html =
		"<div class='col-sm-4 col-sm-offset-4 " +
		"     text-center'>" +
		" <small> " +
		" <a data-toggle='collapse' " +
		"    href='#password_" + tabname + "'>Password" +
		"   </a></small> " +
		" <div id='password_" + tabname + "' " +
		"      class='collapse'> " +
		"  <div class='well well-xs'>" + coninfo.password +
		"  </div> " +
		" </div> " +
		"</div> " + html;
	}
	html += 
	    "<center> " +
	    "  If you change the size of the window, you will " +
	    "  need to use <b><em>stty</em></b> to tell your shell. " +
	    "</center>\n";
	
        $('#' + tabname).html(html);

	var iframe = $('#' + tabname + '_iframe')[0];
	var iframewindow = (iframe.contentWindow ?
			    iframe.contentWindow :
			    iframe.contentDocument.defaultView);

	/*
	 * When the user activates this tab, we want to send a message
	 * to the terminal to focus so we do not have to click inside.
	 */
	$('#quicktabs_ul a[href="#' + tabname + '"]')
	    .on('shown.bs.tab', function (e) {
		iframewindow.postMessage("Focus man!", "*");
	    });
    }

    //
    // Console log. We get the url and open up a new tab.
    //
    function ConsoleLog(client_id)
    {
	// Avoid popup blockers by creating the window right away.
	var spinner = 'https://' + window.location.host + '/images/spinner.gif';
	var win = window.open("", '_blank');
	win.document.write("<center><span style='font-size:30px'>" +
			   "Please wait ... </span>" +
			   "<img src='" + spinner + "'/></center>");
	
	sup.ShowModal('#waitwait-modal');

	var callback = function(json) {
	    sup.HideModal('#waitwait-modal');
	    
	    if (json.code) {
		win.close();
		sup.SpitOops("oops", json.value);
		return;
	    }
	    var url   = json.value.logurl;
	    win.location = url;
	    win.focus();
	}
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status",
					    "ConsoleURL",
					    {"uuid" : uuid,
					     "node" : client_id});
	xmlthing.done(callback);
    }

    //
    // Node Top. 
    //
    function DoTop(client_id)
    {
	var callback = function(json) {
	    console.info(json);
	    if (json.code) {
		sup.HideModal('#waitwait-modal', function () {
		    sup.SpitOops("oops", json.value);
		});
		return;
	    }
	    sup.HideModal('#waitwait-modal', function () {
		$('#top-processes-modal pre').text(json.value.result);
		sup.ShowModal('#top-processes-modal');
	    });
	}
	sup.ShowModal('#waitwait-modal');
	var xmlthing = sup.CallServerMethod(ajaxurl,
					    "status", "Top",
					    {"uuid" : uuid,
					     "node" : client_id});
	xmlthing.done(callback);
    }

    //
    // Show the powder map in a tab, inside an iframe.
    //
    function ShowPowderMapTab()
    {
	// Do nothing if already visible.
	if (!$('#quicktabs_content #powder-map').hasClass("hidden")) {
	    return;
	}
	
	// Show the tab.
	$('#quicktabs_ul a[href="#powder-map"]')
	    .parent().removeClass("hidden");
	$('#quicktabs_content #powder-map').removeClass("hidden");

	DrawPowderMapTab();
    }
    function DrawPowderMapTab()
    {
	// Create the powder map iframe inside the tab
	var iwidth  = "100%";
	var iheight = 850;
	var url     = "powder-map.php?embedded=1&experiment=" + uuid;
		
	var html = '<iframe id="powder-map_iframe" ' +
	    'width=' + iwidth + ' ' +
	    'height=' + iheight + ' ' +
	    'src=\'' + url + '\'>';
	    
	$('#powder-map .powder-mapview').html(html);
    }
    function UpdatePowderMap()
    {
	$('#powder-map_iframe')[0].contentWindow.PowderMapUpdate();
    }

    var jacksInput;
    var jacksOutput;
    var jacksRspecs;

    function ShowViewer(divname, multisite, manifest)
    {
	var aggregates = [];
	
	_.each(amlist, function(details, aggregate_urn) {
	    aggregates.push({"id" : aggregate_urn,
			     "name" : details.name});
	});
	
	if (! jacksInstance)
	{
	    jacksInstance = new window.Jacks({
		mode: 'viewer',
		source: 'rspec',
		multiSite: multisite,
		root: divname,
		nodeSelect: false,
		readyCallback: function (input, output) {
		    jacksInput = input;
		    jacksOutput = output;
		    window.jacksInput = input;

		    jacksOutput.on('modified-topology', function (object) {
			_.each(object.nodes, function (node) {
			    jacksIDs[node.client_id] = node.id;
			    if (!_.has(jacksSites, node.aggregate_id)) {
				jacksSites[node.aggregate_id] = {};
			    }
			    jacksSites[node.aggregate_id][node.client_id] =
				node.id;
			});
			//console.log("jacksIDs", object, jacksIDs, jacksSites);
			ShowManifest(object.rspec);
		    });

		    jacksInput.trigger('change-topology',
				       [{ rspec: manifest }]);

		    jacksOutput.on('click-event', function (jacksevent) {
			if (jacksevent.type === 'node' ||
			    jacksevent.type === 'host') {
			    //console.log(jacksevent);
			    ContextMenuShow(jacksevent);
			}
		    });
		},
	        canvasOptions: { "aggregates" : aggregates },
		show: {
		    rspec: false,
		    tour: false,
		    version: false,
		    selectInfo: false,
		    menu: false
		}
            });
	}
    }
    // Clear the Jacks view to get ready for topo change.
    function ClearViewer(manifest)
    {
	if (jacksInput) {
	    jacksInput.trigger('change-topology',
			       [{ rspec: manifest }], {});

	}
    }
    // Add manifest to viewer.
    function AddToViewer(manifest)
    {
	if (jacksInput) {
	    jacksInput.trigger('add-topology', 
			       [{ rspec: manifest }]);
	}
    }

    /*
     * Show links to the logs.
     */
    function ShowSliverURLs(statusblob)
    {
	if (!publicURLs) {
	    $('#sliverinfo_dropdown').change(function (event) {
		var selected =
		    $('#sliverinfo_dropdown select option:selected').val();
		//console.info(selected);

		// Find the URL
		_.each(publicURLs, function(obj) {
		    var url  = obj.url;
		    var name = obj.name;

		    if (name == selected) {
			$("#sliverinfo_dropdown a").attr("href", url);
		    }
		});
	    });
	}
	// Extract the urls from the status blob.
	var urls = [];
	_.each(statusblob, function(blob, aggregate_urn) {
	    if (_.has(blob, "url") && _.has(amlist, aggregate_urn)) {
		urls.push({"url"  : blob.url,
			   "name" : amlist[aggregate_urn].abbreviation});
	    }
	});
	if (urls.length == 0) {
	    return;
	}
	// URLs change over time, but we do not want to redo this
	// after they stop changing.
	if (publicURLs && publicURLs.length == urls.length) {
	    var changed = false;

	    for (var i = 0; i < urls.length; i++) {
		if (urls[i].url != publicURLs[i].url) {
		    changed = true;
		}
	    }
	    if (!changed) {
		return;
	    }
	}
	publicURLs = urls;
	
	if (urls.length == 1) {
	    $("#sliverinfo_button").attr("href", urls[0].url);
	    $("#sliverinfo_button").removeClass("hidden");
	    $("#sliverinfo_dropdown").addClass("hidden");
	    return;
	}
	// Selection list.
	_.each(urls, function(obj) {
	    var url  = obj.url;
	    var name = obj.name;

	    // Add only once of course
	    var option = $('#sliverinfo_dropdown select option[value="' +
			   name + '"]');
	    
	    if (! option.length) {
		$("#sliverinfo_dropdown select").append(
		    "<option value='" + name + "'>" + name + "</option>");
	    }
	});
	$("#sliverinfo_button").addClass("hidden");
	$("#sliverinfo_dropdown").removeClass("hidden");
    }

    function ShowLogfile(url)
    {
	// URLs change over time.
	$("#logfile_button").attr("href", url);
	$("#logfile_button").removeClass("hidden");
    }

    //
    // Create a new tab to show linktest results. Cause of multisite, there
    // can be more then one. 
    //
    var linktesttabcounter = 0;
    
    function NewLinktestTab(name, results, url)
    {
	// Replace spaces with underscore. Silly. 
	var site = name.split(' ').join('_');
	    
	//
	// Need to create the tab before we can create the topo, since
	// we need to know the dimensions of the tab.
	//
	var tabname = site + "_linktest";
	if (! $("#" + tabname).length) {
	    // The tab.
	    var html = "<li><a href='#" + tabname + "' data-toggle='tab'>" +
		name + "" +
		"<button class='close' type='button' " +
		"        id='" + tabname + "_kill'>x</button>" +
		"</a>" +
		"</li>";	

	    // Append to end of tabs
	    $("#quicktabs_ul").append(html);

	    // GA Handler
	    var ganame = "linktest_" + ++linktesttabcounter;
	    $('#quicktabs_ul a[href="#' + tabname + '"]')
		.on('shown.bs.tab', function (event) {
		    window.APT_OPTIONS.gaTabEvent("show", ganame);
		});
	    window.APT_OPTIONS.gaTabEvent("create", ganame);

	    // Install a click handler for the X button.
	    $("#" + tabname + "_kill").click(function(e) {
		window.APT_OPTIONS.gaTabEvent("kill", ganame);
		e.preventDefault();
		// remove the li from the ul.
		$(this).parent().parent().remove();
		// Remove the content div.
		$("#" + tabname).remove();
		// Activate the first visible tab
		$('#quicktabs_ul a:visible:first').tab('show');
	    });

	    // The content div.
	    html = "<div class='tab-pane' id='" + tabname + "'></div>";

	    // Add the tab content wrapper to the DOM,
	    $("#quicktabs_content").append(html);

	    // And make it active
	    $('#quicktabs_ul a:last').tab('show') // Select last tab
	}
	else {
	    // Switch back to it.
	    $('#quicktabs_ul a[href="#' + tabname + '"]').tab('show');
	}

	//
	// Inside tab content is either the results or an iframe to
	// spew the the log file.
	//
	var html;
	
	if (results) {
	    html = "<div style='overflow-y: scroll;'><pre>" +
		results + "</pre></div>";
	}
	else if (url) {
	    // Create the iframe inside the new tab
	    var iwidth = "100%";
	    var iheight = 400;
		
	    html = '<iframe id="' + tabname + '_iframe" ' +
		'width=' + iwidth + ' ' +
		'height=' + iheight + ' ' +
		'src=\'' + url + '\'>';
	}		
	$('#' + tabname).html(html);
    }

    //
    // Linktest support.
    //
    var linktestsetup = 0;
    function SetupLinktest(status) {
	if (hidelinktest || !showlinktest) {
	    // We might remove a node that removes last link.
	    return ToggleLinktestButtons(status);
	}
	if (linktestsetup) {
	    return ToggleLinktestButtons(status);
	}

        linktestsetup = 1;
        var md = templates['linktest-md'];
        $('#linktest-help').html(marked(md));

	// Handler for the linktest modal button
	$('button#linktest-modal-button').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    event.preventDefault();
	    // Make the popover go away when button clicked. 
	    $('button#linktest-modal-button').popover('hide');
	    sup.ShowModal('#linktest-modal');
	});
	// And for the start button in the modal.
	$('button#linktest-start-button').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    event.preventDefault();
	    StartLinktest();
	});
	// Stop button for a running or wedged linktest.
	$('button#linktest-stop-button').click(function (event) {
	    window.APT_OPTIONS.gaButtonEvent(event);
	    event.preventDefault();
	    // Gack, we have to confirm popover hidden, or it sticks around.
	    // Probably cause we disable the button before popover is hidden?
	    $('button#linktest-stop-button')
		.one('hidden.bs.popover', function (event) {
		    StopLinktest();		    
		});
	    $('button#linktest-stop-button').popover('hide');
	});
	ToggleLinktestButtons(status);
    }
    function ToggleLinktestButtons(status) {
	if (hidelinktest || !showlinktest) {
	    $('#linktest-modal-button').addClass("hidden");
	    DisableButton("start-linktest");
	    return;
	}
	if (status == "ready") {
	    $('#linktest-stop-button').addClass("hidden");
	    $('#linktest-modal-button').removeClass("hidden");
	    EnableButton("start-linktest");
	    DisableButton("stop-linktest");
	}
	else if (status == "linktest") {
	    DisableButton("start-linktest");
	    EnableButton("stop-linktest");
	    $('#linktest-modal-button').addClass("hidden");
	    $('#linktest-stop-button').removeClass("hidden");
	}
	else {
	    DisableButton("start-linktest");
	}
    }

    //
    // Fire off linktest and put results into tabs.
    //
    function StartLinktest() {
	sup.HideModal('#linktest-modal');
	var level = $('#linktest-level option:selected').val();
	
	var callback = function(json) {
	    console.log("Linktest Startup");
	    console.log(json);

	    sup.HideWaitWait();
	    statusHold = 0;
	    GetStatus();
	    if (json.code) {
		sup.SpitOops("oops", "Could not start linktest: " + json.value);
		EnableButton("start-linktest");
		return;
	    }
	    $.each(json.value , function(site, details) {
		var name = "Linktest";
		if (Object.keys(json.value).length > 1) {
		    name = name + " " + site;
		}
		
		if (details.status == "stopped") {
		    //
		    // We have the output right away.
		    //
		    NewLinktestTab(name, details.results, null);
		}
		else {
		    NewLinktestTab(name, null, details.url);
		}
	    });
	};
	statusHold = 1;
	DisableButton("start-linktest");
	sup.ShowWaitWait("We are starting linktest ... patience please");
    	var xmlthing = sup.CallServerMethod(null,
					    "status",
					    "LinktestControl",
					    {"action" : "start",
					     "level"  : level,
					     "uuid" : uuid});
	xmlthing.done(callback);
    }

    //
    // Stop a running linktest.
    //
    function StopLinktest() {
	// If linktest completed, we will not be in the linktest state,
	// so nothing to stop. But if the user killed the tab while it
	// is still running, we will want to stop it.
	if (instanceStatus != "linktest")
	    return;
	
	var callback = function(json) {
	    sup.HideWaitWait();
	    statusHold = 0;
	    GetStatus();
	    if (json.code) {
		sup.SpitOops("oops", "Could not stop linktest: " + json.value);
		EnableButton("stop-linktest");
		return;
	    }
	};
	statusHold = 1;
	DisableButton("stop-linktest");
	sup.ShowWaitWait("We are shutting down linktest ... patience please");
    	var xmlthing = sup.CallServerMethod(null,
					    "status",
					    "LinktestControl",
					    {"action" : "stop",
					     "uuid" : uuid});
	xmlthing.done(callback);
    }

    function ProgressBarUpdate()
    {
	//
	// Look at initial status to determine if we show the progress bar.
	//
	var spinwidth = null;
	
	if (instanceStatus == "created") {
	    spinwidth = "25";
	}
	else if (instanceStatus == "provisioning" ||
		 instanceStatus == "stitching") {
	    spinwidth = "33";
	}
	else if (instanceStatus == "provisioned") {
	    spinwidth = "66";
	}
	else if (instanceStatus == "ready" || instanceStatus == "failed" ||
		 instanceStatus == "quarantined" ||
		 instanceStatus == "pending" ||
		 instanceStatus == "scheduled") {
	    spinwidth = null;
	}
	if (spinwidth) {
	    $('#profile_status_collapse').collapse("show");
 	    $('#profile_status_collapse').trigger('show.bs.collapse');
	    $('#status_progress_outerdiv').removeClass("hidden");
	    $("#status_progress_bar").width(spinwidth + "%");	
	    $("#status_progress_div").addClass("progress-striped");
	    $("#status_progress_div").removeClass("progress-bar-success");
	    $("#status_progress_div").removeClass("progress-bar-danger");
	    $("#status_progress_div").addClass("active");
	}
	else {
	    if (! $('#status_progress_outerdiv').hasClass("hidden")) {
		$("#status_progress_div").removeClass("progress-striped");
		$("#status_progress_div").removeClass("active");
		if (instanceStatus == "ready") {
		    $("#status_progress_div").addClass("progress-bar-success");
		}
		else {
		    $("#status_progress_div").addClass("progress-bar-danger");
		}
		$("#status_progress_bar").width("100%");
	    }
	}
    }

    function ShowExtensionDeniedModal()
    {
	if (extension_blob.extension_denied_reason != "") {
	    $("#extension-denied-modal-reason")
		.text(extension_blob.extension_denied_reason);
	}
	else {
	    $("#extension-denied-modal-reason").addClass("hidden");
	}
	$('#extension-denied-modal-dismiss').click(function () {
	    sup.HideModal("#extension-denied-modal");
	    var callback = function(json) {
		if (json.code) {
		    console.info("Could not dismsss: " + json.value);
		    return;
		}
	    };
	    var xmlthing =
		sup.CallServerMethod(null, "status", "dismissExtensionDenied",
				     {"uuid" : uuid});
	    xmlthing.done(callback);
	});
	sup.ShowModal("#extension-denied-modal");
    }

    //
    // Show the openstack tab.
    //
    function ShowOpenstackTab()
    {
	if (! $('#show_openstack_li').hasClass("hidden")) {
	    return;
	}
	$('#show_openstack_li').removeClass("hidden");
	$("#Openstack").removeClass("hidden");

	/*
	 * We cannot draw the graphs until the tab is actually visible,
	 * D3 cannot handle drawing if there is no actual space allocated.
	 * So lets just wait till the user clicks on the tab. 
	 */
	var handler = function () {
	    $('#show_openstack_tab').off("shown.bs.tab", handler);
	    LoadOpenstackTab();
	};
	$('#show_openstack_tab').on("shown.bs.tab", handler);
    }

    //
    // Load the openstack tab.
    //
    function LoadOpenstackTab()
    {
	if ($('#show_openstack_li').hasClass("hidden")) {
	    return;
	}
	/*
	 * This callback is to let us know if there is any actual data.
	 */
	var callback = function (gotdata) {
	    if (!gotdata) {
		$('#Openstack #nodata').removeClass("hidden");
	    }
	};
	ShowOpenstackGraphs({"uuid"      : uuid,
			     "divID"     : '#openstack-div',
			     "refreshID" : '#openstack-refresh-button',
			     "callback"  : callback});
    }

    //
    // Slothd graphs. The tab already exists but is invisible (not hidden).
    //
    function ShowIdleDataTab()
    {
	if (! $('#show_idlegraphs_li').hasClass("hidden")) {
	    return;
	}
	$('#show_idlegraphs_li').removeClass("hidden");
	$("#Idlegraphs").removeClass("hidden");

	/*
	 * We cannot draw the graphs until the tab is actually visible,
	 * D3 cannot handle drawing if there is no actual space allocated.
	 * So lets just wait till the user clicks on the tab. 
	 */
	var handler = function () {
	    $('#show_idlegraphs_tab').off("shown.bs.tab", handler);
	    LoadIdleData();
	};
	$('#show_idlegraphs_tab').on("shown.bs.tab", handler);
    }

    function LoadIdleData()
    {
	/*
	 * This callback is to let us know if there is any actual data.
	 */
	var callback = function (gotdata, ignored) {
	    if (gotdata <= 0) {
		$('#Idlegraphs #nodata').removeClass("hidden");
	    }
	};
	ShowIdleGraphs({"uuid"     : uuid,
			"showwait" : true,
			"loadID"   : "#loadavg-panel-div",
			"ctrlID"   : "#ctrl-traffic-panel-div",
			"exptID"   : "#expt-traffic-panel-div",
			"refreshID": "#graphs-refresh-button",
			"callback" : callback});
    }

    /*
     * Get the max allowed extension and show a warning if its below
     * a couple of days.
     */
    function LoadMaxExtension()
    {
	if (instanceStatus != "ready") {
	    return;
	}
	var maxcallback = function(json) {
	    console.info("LoadMaxExtension: ", json);
	    
	    if (json.code) {
		console.info("Failed to get max extension: " + json.value);
		return;		    
	    }
	    var maxdate = new Date(json.value.maxextension);
	    //console.info("Max extension date:", maxdate);
		    
	    /*
	     * See if the difference is less then two days
	     */
	    var now   = new Date();
	    var hours = Math.floor((maxdate.getTime() -
				    now.getTime()) / (1000 * 3600.0));
	    if (hours > (7 * 24)) {
		return;
	    }
	    //console.info("Max allowed extension hours: ", hours);
	    
	    var when    = moment(maxdate).format('lll');
	    var fromnow = moment(maxdate).fromNow(true) + " from now";
	
	    $('#maximum-extension-string').html(when + " (" + fromnow + ")");
	    if (hours < 48) {
		$('#maximum-extension-string').removeClass("text-warning");
		$('#maximum-extension-string').addClass("text-danger");
	    }
	    else {
		$('#maximum-extension-string').removeClass("text-danger");
		$('#maximum-extension-string').addClass("text-warning");
	    }
	    $('#maximum-extension').removeClass("hidden");
	}
	var xmlthing =
	    sup.CallServerMethod(null, "status", "MaxExtension",
				 {"uuid" : uuid});
	xmlthing.done(maxcallback);
    }

    /*
     * Ask to ignore the current failure.
     */
    function IgnoreFailure() {
	var checkstatus = function() {
	    console.info("ignore checkstatus", instanceStatus);
	    if (instanceStatus == "ready") {
		sup.HideWaitWait();
		return;
	    }
	    setTimeout(function() { checkstatus() }, 1000);
	};
	var callback = function(json) {
	    console.info("ignore callback", json);
	    if (json.code) {
		sup.HideWaitWait(function () {
		    sup.SpitOops("oops", "Could not ignore failure: " +
				 json.value);
		});
		return;
	    }
	    checkstatus();
	};
	sup.HideModal('#ignore-failure-modal', function () {
	    sup.ShowWaitWait();
	    // Oh jeez, the RPC can return before the waitwait modal displays
	    setTimeout(function() {
		var xmlthing =
		    sup.CallServerMethod(null, "status", "IgnoreFailure",
					 {"uuid" : uuid});
		xmlthing.done(callback);
	    }, 1000);
	});
    }

    /*
     * Transition from scheduled to started. Need to request new expinfo.
     */
    function ExperimentStarted()
    {
	console.info("ExperimentStarted");
	
	sup.CallServerMethod(null, "status", "ExpInfo",
			     {"uuid" : uuid},
	     function(json) {
		 console.info("expinfo", json);
		 if (json.code) {
		     console.info("Could not get experiment "+
				  "info: " + json.value);
		     return;
		 }
		 expinfo = json.value;
		 if (expinfo.started) {
		     $('#exp-started-date')
			 .html(moment(expinfo.started).format("lll"));
		     $('.exp-running').removeClass("hidden");
		 }
	     });
    }

    /*
     * Terminate with cause and optionally freeze user.
     */
    function SetupWarnKill()
    {
	if (expinfo.paniced) {
	    $('#warnkill-experiment-button').addClass("hidden");
	    $('#release-quarantine-button').removeClass("hidden");
	}
	else {
	    $('#warnkill-experiment-button').removeClass("hidden");
	    $('#release-quarantine-button').addClass("hidden");
	}
	$('#warnkill-experiment-button').click(function (event) {
	    event.preventDefault();
	    WarnExperiment();
	});
	$('#release-quarantine-button').click(function () {
	    sup.ShowModal('#disable-quarantine-modal');
	});
	$('#confirm-disable-quarantine').click(function () {
	    DisableQuarantine();
	});

	// The Terminate/quarantine is a radio that can be unselected.
	$('#destroy-quarantine-checkbox').change(function () {
	    if ($('#destroy-quarantine-checkbox').is(':checked')) {
		// Flip the other checkbox off
		$('#destroy-terminate-checkbox').prop("checked", false);
	    }
	});
	$('#destroy-terminate-checkbox').change(function () {
	    if ($('#destroy-terminate-checkbox').is(':checked')) {
		// Flip the other checkbox off
		$('#destroy-quarantine-checkbox').prop("checked", false);
	    }
	});
    }
    
    function WarnExperiment()
    {
	// Handler for the Snapshot confirm button.
	$('#destroy-experiment-confirm')
	    .bind("click.destroy", function (event) {
		event.preventDefault();
		var reason = $('#destroy-experiment-reason').val();
		var kill   = $('#destroy-terminate-checkbox').is(':checked');
		var panic  = $('#destroy-quarantine-checkbox').is(':checked');
		var freeze = $('#destroy-freeze-checkbox').is(':checked');
		var poweroff = $('#destroy-poweroff-checkbox').is(':checked');
		var args   = {"uuid" : uuid};
		if (reason != "") {
		    args["reason"] = reason;
		}
		if (freeze) {
		    args["freeze"] = true;
		}
		if (kill) {
		    args["terminate"] = true;
		}
		else if (panic) {
		    args["quarantine"] = true;
		    if (poweroff) {
			args["poweroff"] = true;
		    }
		}
		sup.HideModal("#destroy-experiment-modal", function () {
		    sup.ShowWaitWait("Patience please!");
		    sup.CallServerMethod(null, "status", "Warn", args,
			 function(json) {
			     console.info("warn/kill", json);
			     if (json.code) {
				 sup.HideWaitWait(function () {
				     if (json.code) {
					 sup.SpitOops("oops",
					    "Could not warn/kill experiment: " +
						      json.value);
				     }
				 });
				 return;
			     }
			     sup.HideWaitWait(function () {
				 if (panic) {
				     sup.ShowModal(
					 '#quarantine-inprogress-modal');
				 }
			     });
			 });
		});
	    });
	
	// Handler for hide modal to unbind the click handler.
	$('#destroy-experiment-modal').on('hidden.bs.modal', function (event) {
	    $(this).unbind(event);
	    $('#destroy-experiment-confirm').unbind("click.destroy");
	});
	sup.ShowModal("#destroy-experiment-modal");
    }

    /*
     * Release from quarantine.
     */
    function DisableQuarantine()
    {
	var args = {"uuid"       : uuid,
		    "quarantine" : "clear"};

	sup.HideModal('#disable-quarantine-modal', function () {
	    sup.ShowWaitWait("Patience please!");
	    sup.CallServerMethod(null, "status", "Quarantine", args,
		 function(json) {
		     console.info("DisableQuarantine", json);
		     if (json.code) {
			 sup.HideWaitWait(function () {
			     if (json.code) {
				 sup.SpitOops("oops",
				      "Could not disable quarantine: " + 
					      json.value);
			     }
			 });
			 return;
		     }
		     sup.HideWaitWait(function () {
			 sup.ShowModal('#quarantine-inprogress-modal');
		     });
		 });
	});
    }

    /*
     * Show/Hide the prestaging panel.
     */
    function ShowPrestageInfo(status)
    {
	var html = prestageTemplate({
	    "status" : status,
	    "amlist" : amlist,
	});
	$('#prestage-panel .panel-body').html(html);
	$('#prestage-panel').removeClass("hidden");
    }
    function HidePrestageInfo()
    {
	sup.HideModal('#prestage-info-modal');
	$('#prestage-panel').addClass("hidden");
    }

    /*
     * On the Powder Portal, we want a link to the monitoring graph
     * for nodes marked as a radio (or hosting a radio), that can
     * transmit and is monitored.
     */
    function IsPowderTransmitter(aggregate_urn, node_id)
    {
	var radio = null;
	
	if (_.has(radioinfo, aggregate_urn) &&
	    _.has(radioinfo[aggregate_urn], node_id) &&
	    _.has(radioinfo[aggregate_urn][node_id], "frontends")) {
	    // Look through through the frontends to see if any can
	    // transmit and are monitored.
	    _.each(radioinfo[aggregate_urn][node_id]["frontends"],
		   function (frontend, iface) {
		       if (frontend.transmit_frequencies != "" &&
			   frontend.monitored) {
			   radio = radioinfo[aggregate_urn][node_id];
		       }
		   });
	}
	return radio;
    }

    /*
     * Create a tab for a monitoring graph
     */
    function NewMonitorTab(client_id)
    {
	var info = radios[client_id];
	
	//
	// Create the tab. The template inserted into the tab has a defined
	// height, so do not worry about that here.
	//
	var tabname = client_id + "monitor_tab";
	if (! $("#" + tabname).length) {
	    // The tab.
	    var html = "<li><a href='#" + tabname + "' data-toggle='tab'>" +
		client_id + "-Graph" +
		"<button class='close' type='button' " +
		"        id='" + tabname + "_kill'>x</button>" +
		"</a>" +
		"</li>";	

	    // Append to end of tabs
	    $("#quicktabs_ul").append(html);

	    // Install a kill click handler for the X button.
	    $("#" + tabname + "_kill").click(function(e) {
		e.preventDefault();
		// remove the li from the ul. this=ul.li.a.button
		$(this).parent().parent().remove();
		// Activate the "profile" tab.
		$('#quicktabs_ul li a:first').tab('show');
		// Remove the content div. Have to delay this though.
		$("#" + tabname).remove();
	    });
	    var options = {
		"url"      : amlist[info.aggregate_urn].weburl,
		"selector" : "#" + tabname + " .frequency-graph-div",
		"cluster"  : amlist[info.aggregate_urn].nickname,
		"node_id"  : info.node_id,
		"iface"    : "rf0",
		"logid"    : null,
		"archived" : false,
		"baseline" : false,
	    }
	    var html = monitorTemplate(options);

	    // The content div.
	    html = "<div class='tab-pane' id='" + tabname + "'>" +
		html + "</div>";

	    $("#quicktabs_content").append(html);

	    // And make it active
	    $('#quicktabs_ul a:last').tab('show') // Select last tab

	    // Now we can create the graph.
	    ShowFrequencyGraph(options);
	}
	else {
	    // Switch back to it.
	    $('#quicktabs_ul a[href="#' + tabname + '"]').tab('show');
	    return;
	}
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    
    $(document).ready(initialize);
});
