$(function () {
  window.JacksEditor = (function ()
{
    'use strict';

    var templates = APT_OPTIONS.fetchTemplateList(['edit-modal', 'edit-inline']);
    var editModalString = templates['edit-modal'];
    var editInlineString = templates['edit-inline'];
    var aptContext = {
	canvasOptions: {
	    "defaults": [
		{
		    "name": "Add VM",
		    "image": "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU14-64-STD",
		    "type": "emulab-xen"
		}
	    ],
	    "images": [
		{
		    "id": "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU14-64-STD",
		    "name": "Ubuntu 14.04 LTS 64-bit"
		},
		{
		    "id": "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU16-64-STD",
		    "name": "Ubuntu 16.04 LTS 64-bit"
		}
	    ],
	    "types": [
		{
		    "id": "emulab-xen",
		    "name": "Emulab Xen VM"
		}
	    ]
	}
    };

    var localContext = {
	canvasOptions: {
	    "defaults": [
		{
		    "name": "Xen VM",
		    "image": "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU14-64-STD",
		    "type": "emulab-xen"
		},
		{
		    "name": "Bare Metal PC",
		    "image": "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU14-64-STD",
		    "type": "raw-pc"
		}
	    ],
	    "images": [
		{
		    "id": "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU14-64-STD",
		    "name": "Ubuntu 14.04 LTS 64-bit"
		}
	    ],
	    "types": [
		{
		    "id": "emulab-xen",
		    "name": "Xen VM"
		},
		{
		    "id": "raw-pc",
		    "name": "Bare Metal PC"
		}
	    ]
	}
    };

    var waitingInstances = [];
    var contextFetched = false;

    var contextUrl = null;
    var context = aptContext;
    if (0) {
        context = localContext;
    }
    else if (window.ISCLOUD)
    {
        contextUrl = 'https://www.emulab.net/protogeni/jacks-context/cloudlab-utah.json';
    }
    else if (window.ISEMULAB && window.MAINSITE)
    {
	contextUrl = 'https://www.emulab.net/protogeni/jacks-context/emulab.json';
    }
    else if (window.ISEMULAB && ! window.MAINSITE)
    {
        context = localContext;
    }
    else if (window.ISPNET || window.ISPOWDER)
    {
	contextUrl = 'https://www.emulab.net/protogeni/jacks-context/phantomnet.json';
    }

    if (contextUrl && (window.ISCLOUD || window.ISPNET || window.ISPOWDER ||
		       (window.ISEMULAB && window.MAINSITE)))
    {
	$('#edit_topo_modal_button').prop('disabled', true);
	$.get(contextUrl).then(contextReady, contextFail);
    }
    else
    {
      contextFetched = true;
    }

    function contextReady(data)
    {
        console.info("contextReady", data);
	$('#edit_topo_modal_button').prop('disabled', false);
        context = data;
      var callback = function(json) {
	if (json.code == 0)
	{
	  context.canvasOptions.dynamicImages = json.value[0];
	}
        if ($('#amlist-json').length > 0)
        {
          var amlist = JSON.parse(_.unescape($('#amlist-json')[0].textContent));
          _.each(context.canvasOptions.aggregates, function (value, index) {
	    if (amlist[value.id] === undefined)
	    {
	      value.hidden = true;
	    }
          });
	}
        contextFetched = true;
        _.each(waitingInstances, function (f) {
	  f();
	});
      };
      var xmlthing = sup.CallServerMethod(null, "instantiate", "GetImageList");
      xmlthing.done(callback);
    }

    function contextFail(fail1, fail2)
    {
	console.log('Failed to fetch Jacks context', fail1, fail2);
	alert('Failed to fetch Jacks context from ' + contextUrl);
    }

    function JacksEditor (root, isViewer, isInline,
			  withoutSelection, withoutMenu, withoutMultiSite, options)
    {
      this.showRspec = false;
      if (options)
      {
	this.showRspec = (options.showRspec == true);
      }
	this.root = root;
	this.instance = null;
	this.input = null;
	this.output = null;
	this.xml = null;
	this.mode = 'editor';
	this.selectionPane = true;
	this.menu = true;
	this.multisite = true;
	if (isViewer)
	{
	    this.mode = 'viewer';
	}
	this.shown = false;

	if (isInline) {
		this.inline = 'inline';
	}
	// A little backward, but I didn't want the addition of these parameters to
	// mess up code elsewhere. The previous values for these parts of the context was true.
	if (withoutSelection) {
		this.selectionPane = false;
	}
	if (withoutMenu) {
		this.menu = false;
	}
	if (withoutMultiSite) {
		this.multisite = false;
	}
	this.render();
    }

    JacksEditor.prototype = {

	render: function ()
	{
		if (this.inline == 'inline')
		{
			this.root.html(editInlineString);
		}
		else
		{
	    	this.root.html(editModalString);
	    	this.root.find('#quickvm_editmodal').on('shown.bs.modal', _.bind(this.handleShown, this));
		}
	    if (this.mode !== 'editor')
	    {
		this.root.find('.modal-header h3').html('Topology Viewer');
	    }
	    this.root.find('#edit-save').click(_.bind(this.fetchXml, this));
	    this.root.find('#edit-cancel, #edit-dismiss')
	      .click(_.bind(this.cancelEdit, this));
	    var makeInstance = function () {
	      this.instance = new window.Jacks({
		mode: this.mode,
		source: 'rspec',
		root: '#edit_nopicker',
		multiSite: this.multisite,
		nodeSelect: this.selectionPane,
		readyCallback: _.bind(this.jacksReady, this),
		show: {
		    rspec: this.showRspec,
		    tour: false,
		    version: false,
		    menu: this.menu,
		    selectInfo: this.selectionPane
		},
		canvasOptions: context.canvasOptions,
		constraints: context.constraints
	      });
	    }.bind(this);

	    if (contextFetched)
	    {
	      makeInstance();
	    }
	    else
	    {
	      waitingInstances.push(makeInstance);
	    }
	},

	// Show a modal that lets the user edit their rspec. Callback
	// is called with a new rspec if they click ok.
	show: function (newXml, callback, cancel_callback, button_label)
	{
	    this.xml = newXml;
	    this.callback = callback;
	    if (cancel_callback === undefined) {
		cancel_callback = null;
	    }
	    this.cancel_callback = cancel_callback;
	    if (button_label === undefined || button_label == null) {
		this.root.find('#edit-save').html("Accept");
	    }
	    else {
		this.root.find('#edit-save').html(button_label);
	    }
	    if (this.input)
	    {
	    	if (this.inline == 'inline') {
	    		this.handleShown();
	    	}
	    	else {
			this.root.find('#quickvm_editmodal').modal('show');
	    	}
	    }
	},

	// Hide the modal.
	hide: function ()
	{
	    this.xml = null;
	    this.root.find('#quickvm_editmodal').modal('hide');
	},

	handleShown: function ()
	{
	    var expression = /^\s*$/;
	    if (this.xml && ! expression.exec(this.xml))
	    {
	      var rspecString = this.xml;
	      rspecString = this.xml.replace(v2ns, v3ns);
		this.input.trigger('change-topology',
				   [{ rspec: rspecString }]);
	    }
	    else
	    {
		this.input.trigger('change-topology', [{
		    rspec:
		    '<rspec '+
			'xmlns="http://www.geni.net/resources/rspec/3" '+
			'xmlns:emulab="http://www.protogeni.net/resources/rspec/ext/emulab/1" '+
			'xmlns:tour="http://www.protogeni.net/resources/rspec/ext/apt-tour/1" '+
			'xmlns:jacks="http://www.protogeni.net/resources/rspec/ext/jacks/1" '+
			'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '+
			'xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/request.xsd">'+
			'</rspec>'
		}]);
	    }
	},

	jacksReady: function (input, output)
	{
	    this.input = input;
	    this.output = output;
	    if (this.xml)
	    {
		this.show(this.xml);
	    }
	},

	fetchXml: function ()
	{
	    var that = this;
	    var fetchDone = function (topology) {
		that.output.off('fetch-topology', fetchDone);
		that.callback(topology[0].rspec);
		that.hide();
	    };

	    this.output.on('fetch-topology', fetchDone);
	    this.input.trigger('fetch-topology');
	},

	cancelEdit: function ()
	{
	    this.root.find('#quickvm_editmodal').modal('hide');
	    
	    if (this.cancel_callback !== null) {
		this.cancel_callback();
	    }
	}
    };

    var v2ns = 'http://www.protogeni.net/resources/rspec/2';
    var v3ns = 'http://www.geni.net/resources/rspec/3';

    function convertNamespace(el)
    {
	if (el.namespaceURI === v2ns)
	{
	    el.setAttribute('xmlns', v3ns);
	}
	_.each(el.children, convertNamespace);
    }

    return JacksEditor;
})();
});
