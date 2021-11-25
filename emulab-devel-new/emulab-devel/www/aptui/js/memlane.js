$(function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['memlane',
						   'waitwait-modal',
						   'oops-modal']);
    var mainTemplate = _.template(templates['memlane']);
    var EMULAB_NS    = "http://www.protogeni.net/resources/rspec/ext/emulab/1";
    var amlist       = null;
    var record       = null;
    
    function initialize()
    {
	window.APT_OPTIONS.initialize(sup);
	amlist = decodejson('#amlist-json');

	var xmlthing = sup.CallServerMethod(null, "memlane",
					    "HistoryRecord",
					    {"uuid" : window.uuid});
	xmlthing.done(function (json) {
	    GeneratePageBody(json);
	});
    }

    function GeneratePageBody(json)
    {
	console.info("GeneratePageBody", json);
	
	if (json.code) {
	    sup.SpitOops("oops", json.value);
	    return;
	}
	record = json.value;
	$('#page-body').html(mainTemplate({
	    "record" : json.value,
	}));
	
	// Format dates with moment before display.
	$('.format-date').each(function() {
	    var date = $.trim($(this).html());
	    if (date != "") {
		$(this).html(moment($(this).html()).format("lll"));
	    }
	});
	// Run Again button.
	if (record.profile_uuid) {
	    var url = "instantiate.php?profile=" + record.profile_uuid +
		"&rerun_instance=" + window.uuid;
	    $('#rerun_button').attr("href", url);
	    
	    if (_.has(record, "bindings") && record.cansave_parameters) {
		$('#save_paramset_button')
		    .removeClass("hidden")
		    .popover({trigger:  'hover',
			      placement:'auto',
			      container:'body'})
		    .click(function (event) {
			paramsets.InitSaveParameterSet('#save_paramset_div',
						       record.profile_uuid,
						       window.uuid);
		    });
		
	    }
	}
	$('#waitwait_div').html(templates['waitwait-model']);
	$('#oops_div').html(templates['oops-model']);
	if (json.value.exitcode) {
	    ShowError(json.value);
	}
	ShowTopo(json.value);
	GenerateBindings(json.value);

        // Javascript to enable link to tab
	// Must do this after ShowTopo, since it changes to that tab.
        var hash = document.location.hash;
        if (hash) {
            $('.nav-tabs a[href="'+hash+'"]').tab('show');
        }
        // Change hash for page-reload
        $('a[data-toggle="tab"]').on('show.bs.tab', function (e) {
	    history.replaceState('', '', e.target.hash);
        });
	// Set the correct tab when a user uses their back/forward button
        $(window).on('hashchange', function (e) {
	    var hash = window.location.hash;
	    if (hash == "") {
		hash = "#rspec";
	    }
	    $('.nav-tabs a[href="'+hash+'"]').tab('show');
	});
    }

    var listview_row = 
	"<tr id='listview-row'>" +
	" <td name='client_id'>n/a</td>" +
	" <td name='node_id'>n/a</td>" +
	" <td name='type'>n/a</td>" +
	" <td name='image'>n/a</td>" +
	"</tr>";

    //
    // Show the topology inside the topo container. Called from the status
    // watchdog and the resize wachdog. Replaces the current topo drawing.
    //    
    function ShowTopo(record)
    {
	//
	// Process the nodes in a single manifest.
	//
	var ProcessNodes = function(aggregate_urn, xml) {
	    var rawcount = $(xml).find("node, emulab\\:vhost").length;
	    
	    // Find all of the nodes, and put them into the list tab.
	    // Clear current table.
	    $(xml).find("node, emulab\\:vhost").each(function() {
		// Only nodes that match the aggregate being processed,
		// since we send the same rspec to every aggregate.
		var manager_urn = $(this).attr("component_manager_id");
		if (!manager_urn.length || manager_urn != aggregate_urn) {
		    return;
		}
		var tag    = $(this).prop("tagName");
		var isvhost= (tag == "emulab:vhost" ? 1 : 0);
		var node   = $(this).attr("client_id");
		var stype  = $(this).find("sliver_type");
		var vnode  = this.getElementsByTagNameNS(EMULAB_NS, 'vnode');
		var isfw   = 0;
		var clone  = $(listview_row);

		// Change the ID of the clone so its unique.
		clone.attr('id', 'listview-row-' + node);
		// Set the client_id in the first column.
		clone.find(" [name=client_id]").html(node);
		// And the node_id/type. This is an emulab extension.
		if (vnode.length) {
		    var node_id = $(vnode).attr("name");

		    // Admins get a link to the shownode page.
		    var weburl = amlist[aggregate_urn].weburl +
			"/portal/show-node.php?node_id=" + node_id;
		    var html   = "<a href='" + weburl + "' target=_blank>" +
			node_id + "</a>";
		    clone.find(" [name=node_id]").html(html);
		    clone.find(" [name=type]")
			.html($(vnode).attr("hardware_type"));
		}
		// Convenience.
		clone.find(" [name=select]").attr("id", node);

		if (stype.length &&
		    $(stype).attr("name") === "emulab-blockstore") {
		    clone.find(" [name=menu]").text("n/a");
		    return;
		}
		if (stype.length &&
		    $(stype).attr("name") === "firewall") {
		    isfw = 1;
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

		// Insert into the table, we will attach the handlers below.
		$('#listview_table > tbody:last').append(clone);
	    });
	}
	var slivers = record.slivers;
	var manifests = [];
	var logfiles  = [];

	_.each(slivers, function(sliver) {
	    var manifest = sliver.manifest;
	    var aggregate_urn = sliver.aggregate_urn;
	    if (manifest) {
		manifests.push(manifest);
	    }
	    if (sliver.public_url) {
		logfiles.push({"urn" : sliver.aggregate_urn,
			       "url" : sliver.public_url});
	    }
	    var xmlDoc = $.parseXML(manifest);
	    ProcessNodes(aggregate_urn, $(xmlDoc));
	});

	$("#showtopo_container").removeClass("invisible");
	$('#quicktabs_ul a[href="#topology"]').tab('show');
	if (manifests.length) {
	    $('#quicktabs_ul li').removeClass('hidden');
	    $('#quicktabs_content .tab-pane').removeClass('hidden');
	    $('#quicktabs_ul a[href="#topology"]').tab('show');
	    ShowViewer('#showtopo_statuspage', manifests);
	}
	else {
	    $('#quicktabs_ul a[href="#rspec"]').tab('show');
	}
	ShowRspec(record.rspec);
	if (logfiles.length) {
	    ShowLogfiles(logfiles);
	}
    }

    var jacksInstance;
    var jacksInput;
    var jacksOutput;
    var jacksRspecs;

    function ShowViewer(divname, manifests)
    {
	var first_manifest  = _.first(manifests);
	var rest            = _.rest(manifests);
	var multisite       = rest.length ? true : false;
	
	if (! jacksInstance)
	{
	    jacksInstance = new window.Jacks({
		mode: 'viewer',
		source: 'rspec',
		multiSite: multisite,
		root: divname,
		nodeSelect: true,
		readyCallback: function (input, output) {
		    jacksInput = input;
		    jacksOutput = output;

		    jacksOutput.on('modified-topology', function (object) {
			//console.log("jacksIDs", object, jacksIDs);
			ShowManifest(object.rspec);
		    });
		
		    jacksInput.trigger('change-topology',
				       [{ rspec: first_manifest }]);

		    if (rest.length) {
			_.each(rest, function(manifest) {
			    jacksInput.trigger('add-topology',
					       [{ rspec: manifest }]);
			});
		    }
		},
	        canvasOptions: {
	    "aggregates": [
	      {
		"id": "urn:publicid:IDN+utah.cloudlab.us+authority+cm",
		"name": "Cloudlab Utah"
	      },
	      {
		"id": "urn:publicid:IDN+wisc.cloudlab.us+authority+cm",
		"name": "Cloudlab Wisconsin"
	      },
	      {
		"id": "urn:publicid:IDN+clemson.cloudlab.us+authority+cm",
		"name": "Cloudlab Clemson"
	      },
	      {
		"id": "urn:publicid:IDN+utahddc.geniracks.net+authority+cm",
		"name": "IG UtahDDC"
	      },
	      {
		"id": "urn:publicid:IDN+apt.emulab.net+authority+cm",
		"name": "APT Utah"
	      },
	      {
		"id": "urn:publicid:IDN+emulab.net+authority+cm",
		"name": "Emulab"
	      },
	      {
		"id": "urn:publicid:IDN+wall2.ilabt.iminds.be+authority+cm",
		"name": "iMinds Virt Wall 2"
	      },
	      {
		"id": "urn:publicid:IDN+uky.emulab.net+authority+cm",
		"name": "UKY Emulab"
	      }
	    ]
		},
		show: {
		    rspec: false,
		    tour: false,
		    version: false,
		    selectInfo: true,
		    menu: false
		}
            });
	}
	else if (jacksInput)
	{
	    jacksInput.trigger('change-topology',
			       [{ rspec: first_manifest }]);

	    if (rest.length) {
		_.each(rest, function(manifest) {
		    jacksInput.trigger('add-topology',
				       [{ rspec: manifest }]);
		});
	    }
	}
    }

    //
    // Show the manifest in the tab, using codemirror.
    //
    function ShowManifest(manifest)
    {
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
    }

    //
    // Show the rspec in the tab, using codemirror.
    //
    function ShowRspec(rspec)
    {
	var mode   = "text/xml";

	$("#rspec_textarea").css("height", "300");
	$('#rspec_textarea .CodeMirror').remove();

	var myCodeMirror = CodeMirror(function(elt) {
	    $('#rspec_textarea').prepend(elt);
	}, {
	    value: rspec,
            lineNumbers: false,
	    smartIndent: true,
            mode: mode,
	    readOnly: true,
	});

	$('#show_rspec_tab').on('shown.bs.tab', function (e) {
	    myCodeMirror.refresh();
	});
    }

    function ShowLogfiles(logfiles)
    {
	$('#sliverinfo_dropdown').change(function (event) {
	    var selected =
		$('#sliverinfo_dropdown select option:selected').val();
	    console.info(selected);

	    // Find the URL
	    _.each(logfiles, function(obj) {
		var url  = obj.url;
		var name = amlist[obj.urn].name;

		if (name == selected) {
		    $("#sliverinfo_dropdown a").attr("href", url);
		}
	    });
	});
	if (logfiles.length == 1) {
	    $("#sliverinfo_button").attr("href", logfiles[0].url);
	    $("#sliverinfo_button").removeClass("hidden");
	    $("#sliverinfo_dropdown").addClass("hidden");
	    return;
	}
	// Selection list.
	_.each(logfiles, function(obj) {
	    var url  = obj.url;
	    var name = amlist[obj.urn].name;

	    $("#sliverinfo_dropdown select").append(
		"<option value='" + name + "'>" + name + "</option>");
	});
	$("#sliverinfo_button").addClass("hidden");
	$("#sliverinfo_dropdown").removeClass("hidden");
    }

    function ShowError(record)
    {
	var slivers = record.slivers;
	var logfiles  = [];

	_.each(slivers, function(sliver) {
	    var aggregate_urn = sliver.aggregate_urn;

	    if (sliver.public_url) {
		logfiles.push({"urn" : sliver.aggregate_urn,
			       "url" : sliver.public_url});
	    }
	});
	if (logfiles.length) {
	    ShowLogfiles(logfiles);
	}

	$('#error_panel_text').text(record.exitmessage);
	$('#error_panel').removeClass("hidden");
    }

    //
    // Generate a bindings table.
    //    
    function GenerateBindings(record)
    {
	if (!_.has(record, "bindings")) {
	    $('#quicktabs_content #bindings').addClass("hidden");
	    $('#show_bindings_tab').addClass("hidden");
	    return;
	}
	var bindings  = record.bindings;
	var paramdefs = record.paramdefs;
	var html = GetBindingsTable(paramdefs, bindings);
	
	$('#bindings_table tbody').html(html);
	$('#quicktabs_content #bindings').removeClass("hidden");
	$('#show_bindings_tab').removeClass("hidden");
    }

    // Helper.
    function decodejson(id) {
	return JSON.parse(_.unescape($(id)[0].textContent));
    }
    $(document).ready(initialize);
});
