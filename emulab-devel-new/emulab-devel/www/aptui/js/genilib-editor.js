$(function ()
{
  'use strict';

  var templates = APT_OPTIONS.fetchTemplateList(['genilib-editor']);
  var pageString = templates['genilib-editor'];

  var isRendered = false;
  var editor;
  var isWaiting = false;
  var isSplit = false;
  var settingsShown = false;
  var createShown = false;
  var rspec = '';
  var jacks = null;
  var jacksInput = null;
  var jacksOutput = null;
  var callback = null;
  var isReadOnly = false;
  var isShown = false;
  var hasChanged = false;
  var profile_uuid = null;

  function initialize()
  {
    // The including page provides us with a top-level hook and an
    // oops and waitwait modal to invoke.
    $('#genilib-editor-body').hide();
    $('#genilib-editor-body').html(pageString);
    $('#genilib-editor-body .genilib-documentation')
	  .attr("href", window.MANUAL + "/geni-lib.html");
  }

  function render()
  {
    if (! isRendered)
    {
      isRendered = true;
      editor = ace.edit('genilib-editor');
      editor.$blockScrolling = Infinity;
      editor.setTheme('ace/theme/chrome');
      editor.getSession().setUseWrapMode(true);
      editor.getSession().setMode('ace/mode/python');
      editor.getSession().on('change', editorChanged);

      removeSplit();

      loadSettings();

      sup.DownloadOnClick($('#genilib-editor-body #saveButton'), getSaveText, 'saved.py', saveComplete);
    $('#genilib-editor-body #runButton').on('click', run);
      $('#genilib-editor-body #settingsButton').on('click', toggleSettings);
      $('#genilib-editor-body #closeErrorButton').on('click', removeSplit);
      $('#genilib-editor-body #closeSettingsButton').on('click', removeSplit);
      $('#genilib-editor-body #closeJacksButton').on('click', removeSplit);
      $('#genilib-editor-body #settings-root select').on('change', onChangeSettings);
      $('#genilib-editor-body #okButton').on('click', clickOk);
      $('#genilib-editor-body #loadButton').on('click', load);
      $('#genilib-editor-body #cancelButton').on('click', clickCancel);
      $(window).on('popstate', clickBackButton);
    }
  }

  // Hide the current page (#page-body) and show the genilib editor.
  // 'source' is a plaintext genilib source code string
  // 'callback' is called when the user clicks ok or cancel with either the new source (if they clicked ok in edit mode) or null (if they clicked cancel or are in readonly mode).
  window.SHOW_GENILIB_EDITOR = function (source, newCallback,
					 newIsReadOnly, uuid)
  {
    isShown = true;
    callback = newCallback;
    isReadOnly = newIsReadOnly;
    profile_uuid = uuid;
    $('#page-body').hide();
    $('#genilib-editor-body').show();
    render();
    editor.setValue(source);
    editor.selection.clearSelection();
    hasChanged = false;
    if (isReadOnly)
    {
      editor.setReadOnly(true);
      $('#genilib-editor-body #loadButton').hide();
      $('#genilib-editor-body #cancelButton').hide();
      $('#genilib-editor-body #okButton').html('Close');
    }
    else
    {
      editor.setReadOnly(false);
      $('#genilib-editor-body #loadButton').show();
      $('#genilib-editor-body #cancelButton').show();
      $('#genilib-editor-body #okButton').html('Accept');
    }
    $('#genilib-editor').focus();
    editor.focus();
    window.history.pushState(null, "");
  }

  window.GENILIB_EDITOR_CHANGED = function ()
  {
    return hasChanged;
  }

  function clickOk()
  {
    if (isReadOnly)
    {
      hideEditor(null);
    }
    else
    {
      hideEditor(editor.getValue());
    }
  }

  function clickCancel()
  {
    if (! isReadOnly)
    {
      hideEditor(null);
    }
  }

  function hideEditor(source)
  {
    isShown = false;
    hasChanged = false;
    $('#genilib-editor-body').hide();
    $('#page-body').show();
    if (callback)
    {
      callback(source);
    }
  }

  function clickBackButton()
  {
    if (isShown)
    {
      var shouldLeave = ! hasChanged;
      if (! shouldLeave)
      {
	shouldLeave = confirm("You have unsaved changes!");
      }
      if (shouldLeave)
      {
	hideEditor(null);
      }
      else
      {
	event.preventDefault();
	event.stopPropagation();
	window.history.pushState(null, "");
      }
    }
  }

  function removeSplit()
  {
    $('#genilib-editor-body #jacks-root').hide();
    $('#genilib-editor-body #error-root').hide();
    $('#genilib-editor-body #create-root').hide();
    $('#genilib-editor-body #settings-root').hide();
    settingsShown = false;
    createShown = false;
    $('#genilib-editor-body #editor-container')
      .removeClass('col-lg-6 col-md-6')
      .addClass('col-lg-12 col-md-12');
    editor.resize();
  }

  function addSplit()
  {
    $('#genilib-editor-body #editor-container')
      .removeClass('col-lg-12 col-md-12')
      .addClass('col-lg-6 col-md-6');
    editor.resize();
  }

  function editorChanged()
  {
    hasChanged = true;
    if (createShown)
    {
      removeSplit();
    }
  }

  function getSaveText()
  {
    if (! isWaiting)
    {
      return editor.getValue();
    }
    else
    {
      return null;
    }
  }

  function saveComplete()
  {
  }
  
  function load()
  {
    if (! isWaiting && ! isReadOnly)
    {
      $('#genilib-editor-body #load-input').html('<input type="file"/>');
      $('#genilib-editor-body #load-input input').on('change', function () {
	var file = $('#genilib-editor-body #load-input input')[0].files[0];
	if (file)
	{
          var reader = new FileReader();
          reader.onload = function (e) {
            var contents = e.target.result;
	    editor.setValue(contents);
	    editor.selection.clearSelection();
	    removeSplit();
          };
          reader.readAsText(file);
	}
      });
      $('#genilib-editor-body #load-input input').click();
    }
  }

  function run()
  {
    if (! isWaiting)
    {
      removeSplit();
      $('#waitwait-modal').modal('show');
      isWaiting = true;

      var script = editor.getValue();
      var args = {"script" : script};
      if (profile_uuid) {
	  args["uuid"] = profile_uuid;
      }
      var call = sup.CallServerMethod(null, "instantiate", "RunScript", args);
				      
      call.done(runComplete);
    }
  }

  function runComplete(json)
  {
    $('#waitwait-modal').modal('hide');
    isWaiting = false;

    if (json.code == 0)
    {
      rspec = json.value;
      $('#genilib-editor-body #jacks-root').show();
      _.defer(jacksUpdate);
      addSplit();
    }
    else if (json.code == 2)
    {
      $('#genilib-editor-body #error-message').html('');
      var errors = json.value.split('\n');
      for (var i in errors)
      {
	var item = $('<div class="error-item">');

	var re = /[0-9].py", line ([0-9]+)/;
	var found = re.exec(errors[i]);
	if (found !== null)
	{
	  var line = parseInt(found[1], 10);
	  item.append(makeLineButton(line));
	}

	item.append('<pre>' + _.escape(errors[i]) + '</pre></div>');
	$('#genilib-editor-body #error-message').append(item);
      }
      $('#genilib-editor-body #error-root').show();
      addSplit();
    }
    else
    {
      sup.SpitOops('oops', json.value);
    }
  }

  function makeLineButton(line)
  {
    var button = $('<button class="btn btn-default pull-right"><span class="glyphicon glyphicon-share-alt" aria-hidden="true"></span></button>');
    button.on('click', function () {
      editor.gotoLine(line);
    });
    return button;
  }

  function onChangeSettings()
  {
    var settings = saveSettings();
    updateSettings(settings);
  }


  function toggleSettings()
  {
    if (settingsShown)
    {
      removeSplit();
    }
    else
    {
      settingsShown = true;
      $('#genilib-editor-body #settings-root').show();
      $('#genilib-editor-body #jacks-root').hide();
      $('#genilib-editor-body #error-root').hide();
      $('#genilib-editor-body #create-root').hide();
      createShown = false;
      addSplit();
    }
  }

  function loadSettings()
  {
    var settings = {
      'theme': 'chrome',
      'fontsize': '12px',
      'codefolding': 'manual',
      'keybinding': 'ace',
      'showspace': 'disabled'
    };
    try
    {
      var settingsString = window.localStorage.getItem('genilib-editor-settings');
      if (settingsString)
      {
	settings = JSON.parse(settingsString);
      }
    }
    catch (e)
    {
      console.log('Failed to load settings. Falling back to defaults.');
    }

    updateSettings(settings);
  }

  function saveSettings()
  {
    var settings = {};
    $('#genilib-editor-body #settings-root select').each(function () {
      settings[this.id] = $(this).val();
    });
    try
    {
      var settingsString = JSON.stringify(settings);
      window.localStorage.setItem('genilib-editor-settings', settingsString);
    }
    catch (e)
    {
      console.log('Cannot save settings');
    }
    return settings;
  }

  function updateSettings(settings)
  {
    for (var key in settings)
    {
      if ($('#genilib-editor-body #settings-root').find('#' + key).val() !== settings[key])
      {
	$('#genilib-editor-body #settings-root').find('#' + key).val(settings[key]);
      }
    }
    if (editor.getTheme() !== 'ace/theme/' + settings['theme'])
    {
      editor.setTheme('ace/theme/' + settings['theme']);
    }

    if (editor.getFontSize() !== settings['fontsize'])
    {
      editor.setFontSize(settings['fontsize']);
    }

    var shouldFold = (settings['codefolding'] !== 'manual');
    if (editor.getShowFoldWidgets() !== shouldFold)
    {
      editor.setShowFoldWidgets(shouldFold);
    }

    if (editor.getKeyboardHandler() !== settings['keybinding'])
    {
      editor.setKeyboardHandler('ace/keyboard/' + settings['keybinding']);
    }
    var shouldShowSpace = (settings['showspace'] === 'enabled');
    if (editor.getShowInvisibles() !== shouldShowSpace)
    {
      editor.setShowInvisibles(shouldShowSpace);
    }
  }
  
  function jacksUpdate()
  {
    if (jacks)
    {
      if (jacksInput)
      {
	jacksInput.trigger('change-topology',
			   [{ rspec: rspec }]);
      }
    }
    else
    {
      jacks = new window.Jacks({
        mode: 'viewer',
        source: 'rspec',
        root: '#jacks-container',
        readyCallback: jacksReady,
	show:
	{
	  rspec: true,
	  tour: false,
	  version: false,
	  menu: true,
	  selectInfo: true,
	  clear: false
	}
      });
    }
  }

  function jacksReady(input, output)
  {
    jacksInput = input;
    jacksOutput = output;
    jacksInput.trigger('change-topology',
		       [{ rspec: rspec }]);
  }

  $(document).ready(initialize);
});
