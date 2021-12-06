// Start a Parameterized Profile
//
// TODO: visual grouping of group/structures and lists.
//       grey out -/+ and use tooltips to tell people about min/max limits.
//
// https://bootsnipp.com/snippets/kM4Q
//
$(function () {
  window.ppstart = (function()
    {
	'use strict';

        var templates = APT_OPTIONS.fetchTemplateList(['ppform-wizard',
						       'image-picker-modal']);
        var ppmodalString = templates['ppform-wizard'];
        var imagePickerString = templates['image-picker-modal'];
	var debug         = 0;
	var editor        = null;
	var editorLarge   = null;
	var paramdefs     = null;
	var ppdivname     = null;
	var uuid          = "";
	var profile       = "";
	var registered    = true;
	var fromrepo      = false;
	var multisite     = 0;
	var RSPEC	  = null;
	var configuredone_callback = null;
	var modified_callback = null;
        var warningsfatal = 1;
        var imagePicker   = null;
	var amlist        = null;
	var prunetypes    = null;
	var rerun_bindings= null;
	var rerun_warnings= null;
	var setStepsMotion= null;
	var resinfo_window= null;
	var ppchanged     = false;

	// List of form elements (fields,groups), in order of appearance.
	var formFields    = [];
	// Map groupId to info about the group, which includes fields in group.
	var formGroups     = {};

	function isNumeric(n) {
	    return !isNaN(parseFloat(n)) && isFinite(n);
	}
	function escapeHtml(unsafe) {
	    return unsafe
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&#039;");
	}
	function Modified() {
	    ppchanged = true;
	    modified_callback();
	}

	var groupTemplateString =
	    '<div class="row group-row" data-fieldid="<%- fieldid %>" ' +
	    '     style="margin-bottom: 5px;">' +
	    ' <div class="col-xs-offset-0">' +
	    '  <div class="panel" ' +
	    '       style="border-width: 0px; border: none;' +
	    '       box-shadow: none; margin-bottom: 0px; padding-top: 0px;">' +
	    '    <div class="panel-heading" ' +
	    '         style="padding-top: 0px; padding-bottom: 0px;">' +
	    '      <h5 style="display: inline-block;">' +
	    '        <a href="#pp-param-group-subpanel-<%- name %>" ' +
	    '           class="subpanel-collapse-chevron" ' +
	    '           data-toggle="collapse">' +
	    '          <span class="glyphicon glyphicon-chevron-right pull-left"' +
	    '                style="font-weight: bold;"></span>' +
	    '             <span style="font-weight: bold;">&nbsp;&nbsp; ' +
	    '                <%- prompt %></span>' +
	    '        </a>' +
	    '      </h5>' +
	    '    </div>' +
	    '    <div id="pp-param-group-subpanel-<%- name %>" ' +
	    '         class="panel-collapse collapse ' +
	    '                pp-param-group-subpanel-collapse"' +
	    '         style="height: auto;">' +
	    '      <div id="pp-param-group-subpanel-body-<%- name %>" ' +
	    '           style="padding-top: 0px; padding-bottom: 0px" ' +
	    '           class="panel-body">' +
	    '      </div>' +
	    '    </div>' +
	    '  </div>' +
	    ' </div>' +
	    '</div>';

	var emptyStructTemplateString =
	    '<div class="struct-row" data-fieldid="<%- fieldid %>"> ' +
	    ' <div class="col-xs-offset-0">' +
	    '  <div class="panel" ' +
	    '       style="border-width: 0px; border: none;' +
	    '       box-shadow: none; margin-bottom: 0px;">' +
	    '    <div class="panel-heading" ' +
	    '         style="padding-top: 0px; padding-bottom: 0px;">' +
	    '      <h5 style="display: inline-block;">' +
	    '             <span style="font-weight: bold;">&nbsp;&nbsp; ' +
	    '                <%- prompt %></span>' +
	    '      </h5>' +
	    '      <span class="multivalue-struct-button-plus" ' +
	    '            data-toggle="tooltip" ' +
	    '            data-container="body" ' +
	    '            data-trigger="hover" ' +
	    '            title="Add another copy"> ' +
	    '        <button type="button" ' +
	    '                class="btn btn-small btn-default" ' +
	    '                style="margin-left: 10px; padding: 3px;">' +
 	    '           <span class="glyphicon glyphicon-plus"></span>' +
	    '        </button>' +
	    '      </span>' +
	    '    </div>' +
	    '  </div>' +
	    ' </div>' +
	    '</div>';

	var structSetTemplateString =
	    '<div class="row structset" data-fieldid="<%- fieldid %>"> ' +
	    ' <div class="col-xs-offset-0">' +
	    '  <div class="panel" ' +
	    '       style="border-width: 0px; border: none;' +
	    '       box-shadow: none; margin-bottom: 0px;">' +
	    '    <div class="panel-heading" ' +
	    '         style="padding-top: 0px; padding-bottom: 0px;">' +
	    '      <h5 style="display: inline-block;">' +
	    '        <a href="#pp-param-structset-subpanel-<%- fieldid %>" ' +
	    '           class="structset-subpanel-collapse-chevron" ' +
	    '           data-toggle="collapse">' +
	    '          <span class="glyphicon ' +
	    '                       glyphicon-chevron-right pull-left"' +
	    '                style="font-weight: bold;"></span>' +
	    '             <span style="font-weight: bold;"' +
	    '                >&nbsp;&nbsp;<%- prompt %></span>' +
	    '        </a>' +
	    '      </h5>' +
	    '      <% if (longhelp) { %> ' +
	    '          <span class="pp-param-popover"> ' +
	    '             <a href="#<%- longhelp_id %>" ' +
	    '                data-toggle="collapse" ' +
	    '                data-trigger="hover"> ' +
	    '               <i class="glyphicon glyphicon-question-sign"></i>' +
	    '             </a></span>' +
	    '      <% } %> ' +
	    '    </div>' +
	    '    <% if (longhelp) { %> ' +
	    '      <div id="<%- longhelp_id %>" ' +
	    '           class="panel-collapse collapse panel panel-info ' +
	    '                  col-xs-10 col-xs-offset-1 pp-param-help-panel" '+
	    '                  style="background-color: #e6f6fa;height: auto;' +
	    '                         margin-top: 5px; margin-bottom: 5px;' +
	    '                         padding: 5px;" ' +
	    '                  data-toggle=collapse><%- longhelp %></div> ' +
	    '    <% } %> ' +
	    '    <div id="pp-param-structset-subpanel-<%- fieldid %>" ' +
	    '         class="panel-collapse collapse ' +
	    '                pp-param-structset-subpanel-collapse"' +
	    '         style="height: auto;">' +
	    '      <div id="pp-param-structset-subpanel-body-<%- fieldid %>" ' +
	    '           style="padding-top: 0px; padding-bottom: 0px;" ' +
	    '           class="panel-body structset-panel-body">' +
	    '      </div>' +
	    '    </div>' +
	    '  </div>' +
	    ' </div>' +
	    '</div>';

	var structTemplateString =
	    '<div class="struct-row" data-fieldid="<%- fieldid %>" ' +
	    '     data-copyindex="<%- index %>"> ' +
	    ' <div class="col-xs-offset-0">' +
	    '  <div class="panel" ' +
	    '       style="border-width: 0px; border: none;' +
	    '       box-shadow: none; margin-bottom: 0px;">' +
	    '    <div class="panel-heading" ' +
	    '         style="padding-top: 0px; padding-bottom: 0px;"> ' +
	    '      <h5 style="display: inline-block;">' +
	    '        <a href="#pp-param-group-subpanel-<%- name %>" ' +
	    '           class="subpanel-collapse-chevron" ' +
	    '           data-toggle="collapse">' +
	    '          <span class="glyphicon ' +
	    '                       glyphicon-chevron-right pull-left"' +
	    '                style="font-weight: bold;"></span>' +
	    '             <span style="font-weight: bold;"' +
	    '                >&nbsp;&nbsp;<%- prompt %></span>' +
	    '        </a>' +
	    '      </h5>' +
	    '      <% if (longhelp) { %> ' +
	    '          <span class="pp-param-popover"> ' +
	    '             <a href="#<%- longhelp_id %>" ' +
	    '                data-toggle="collapse" ' +
	    '                data-trigger="hover"> ' +
	    '               <i class="glyphicon glyphicon-question-sign"></i>' +
	    '             </a></span>' +
	    '      <% } %> ' +
	    '      <% if (multivalue) { %> ' +
	    '        <span data-toggle="tooltip" ' +
	    '              data-container="body" ' +
	    '              data-trigger="hover" ' +
	    '              title="Delete this copy" ' +
	    '              class="multivalue-struct-button-minus"> ' +
            '          <button type="button" ' +
	    '                  class="btn btn-small btn-default" ' +
	    '                  style="margin-left: 5px; padding: 2px;">' +
	    '            <span class="glyphicon glyphicon-minus"></span>' +
	    '          </button></span>' +
	    '        <span data-toggle="tooltip" ' +
	    '              data-container="body" ' +
	    '              data-trigger="hover" ' +
	    '              title="Add another copy" ' +
	    '              class="multivalue-struct-button-plus"> ' +
	    '          <button type="button" ' +
	    '                  class="btn btn-small btn-default" ' +
	    '                  style="margin-left: 0px; padding: 2px;">' +
 	    '            <span class="glyphicon glyphicon-plus"></span>' +
	    '          </button></span>' +
	    '        <span data-toggle="tooltip" ' +
	    '              data-container="body" ' +
	    '              data-trigger="hover" ' +
	    '              title="Move up" ' +
	    '              class="multivalue-struct-button-up"> ' +
	    '          <button type="button" ' +
	    '                  class="btn btn-small btn-default" ' +
	    '                  style="margin-left: 0px; padding: 2px;">' +
 	    '            <span class="glyphicon glyphicon-arrow-up"></span>' +
	    '          </button></span>' +
	    '        <span data-toggle="tooltip" ' +
	    '              data-container="body" ' +
	    '              data-trigger="hover" ' +
	    '              title="Move down" ' +
	    '              class="multivalue-struct-button-down"> ' +
	    '          <button type="button" ' +
	    '                  class="btn btn-small btn-default" ' +
	    '                  style="margin-left: 0px; padding: 2px;">' +
 	    '            <span class="glyphicon glyphicon-arrow-down"></span>' +
	    '          </button></span>' +
	    '      <% } %> ' +
	    '    </div>' +
	    '    <% if (longhelp) { %> ' +
	    '      <div id="<%- longhelp_id %>" ' +
	    '           class="panel-collapse collapse panel panel-info ' +
	    '                  col-xs-10 col-xs-offset-1 pp-param-help-panel" '+
	    '                  style="background-color: #e6f6fa;height: auto;' +
	    '                         margin-top: 5px; margin-bottom: 5px;' +
	    '                         padding: 5px;" ' +
	    '                  data-toggle=collapse><%- longhelp %></div> ' +
	    '    <% } %> ' +
	    '    <div id="pp-param-group-subpanel-<%- name %>" ' +
	    '         class="panel-collapse collapse ' +
	    '                pp-param-group-subpanel-collapse"' +
	    '         style="height: auto;">' +
	    '      <div id="pp-param-group-subpanel-body-<%- name %>" ' +
	    '           style="padding-top: 0px; padding-bottom: 0px;" ' +
	    '           class="panel-body">' +
	    '      </div>' +
	    '    </div>' +
	    '  </div>' +
	    ' </div>' +
	    '</div>';

	var emptyInputTemplateString =
	    '  <span class="multivalue-button-plus" ' +
	    '        data-toggle="tooltip" ' +
	    '        data-container="body" ' +
	    '        data-trigger="hover" ' +
	    '        title="Add value">' +
	    '    <button type="button" ' +
	    '        data-fieldid="<%- fieldid %>" ' +
	    '        data-fieldname="<%- fieldname %>" ' +
	    '        class="btn btn-small btn-default" ' +
	    '        style="margin: 0px; padding: 3px; ' +
	    '               margin-top: 5px; display: inline-block;">' +
 	    '     <span class="glyphicon glyphicon-plus"></span>' +
	    '    </button>' +
	    '  </span>';

	var booleanTemplateString =
	    "<input data-fieldid='<%- fieldid %>' " +
	    "       data-fieldname='<%- fieldname %>' " +
	    "       <%- checked %> " +
	    "       name='<%- name %>' " +
	    "       style='margin: 0px; height: 34px; display: block;' " +
	    "       class='format-me' " +
	    "       data-label='<%- prompt %>' " +
	    "       value='checked' " +
	    "       type='checkbox'>";

	var inputTemplateString =
	    "<input data-fieldid='<%- fieldid %>' " +
	    "       data-fieldname='<%- fieldname %>' " +
	    "       placeholder='<%- placeholder %>' " +
	    "       name='<%- name %>' " +
	    " <% if (multivalue) { %> "+
	    "       style='display: inline-block; width: 75%' " +
	    " <% } %>" +
	    "       value='<%- value %>' " +
	    "       class='form-control format-me' " +
	    "       data-label='<%- prompt %>' " +
	    "       type='text'>";

	var selectTemplateString = 
	    "<select data-fieldid='<%- fieldid %>' " +
	    "        data-fieldname='<%- fieldname %>' " +
	    "        name='<%- name %>' " +
	    " <% if (multivalue) { %> "+
	    "        style='display: inline-block; width: 75%' " +
	    " <% } %>" +
	    "        class='form-control format-me' " +
	    "        data-label='<%- prompt %>' " +
	    "        placeholder='Please Select'>" +
	    " <% _.each(options, function(option, idx) { %> " +
	    "  <% var val,key; %> " +
	    "  <% if (Array.isArray(option)) { %> " +
	    "  <%   val = option[0]; %> " +
	    "  <%   key = option[1]; %> " +
	    "  <% } else { %> " +
	    "  <%   val = key = option; %> "+
	    "  <% } %> " +
	    "   <option " +
	    "    <% if (value && val == value) {%>selected<% } %> "+
	    "     value='<%- val %>'><%- key %></option>" +
	    " <% }) %> " +
	    "</select>";

	var nodeTypeTemplateString = 
	    "<div> " +
	    "  <div class='dropdown'> " +
	    "   <button class='btn btn-default dropdown-toggle' " +
	    "           style='min-width: 150px; text-align: left' " +
	    "           type=button data-toggle=dropdown> " +
	    "    <span class='type-selected'>" +
	    "      <% if (constraints) { %>Please Select" +
	    "         <% } else { %>Any<% } %></span> "+
	    "      <span class=right-caret></span></button>" +
	    "   <ul class='dropdown-menu right-menu scrollable-menu'>" +
	    "   <% if (!constraints) { %> " +
	    "    <li><a href='#' class='clear-select'>" +
	    "       <b>Clear Selection</b></a></li> " +
	    "   <% } %> " +
	    "   </ul>"+
	    " </div>"+
	    " <input class='format-me' " +
	    "        data-fieldid='<%- fieldid %>' " +
	    "        data-fieldname='<%- fieldname %>' " +
	    "        data-label='<%- prompt %>' " +
	    "        name='<%- name %>' type='hidden' " +
	    "        value='<%- value %>'>" +
	    "</div>";

	var imageSelectString = 
	    "<div>" +
	    " <div class='input-group'> " +
	    "   <input id='image-display' " +
	    "          type='text' readonly " +
	    "          class='form-control' " +
	    "          value='<%- display %>'>" +
	    "   <span class='input-group-btn'>" +
	    "     <button class='btn btn-success' id='image-select' " +
	    "             style='height: 34px' " +
	    "             type='button'>" +
	    "       <span class='glyphicon glyphicon-pencil'></span>" +
	    "     </button>" +
	    "   </span> " +
	    " </div>" +
	    " <input id='image-value' class='format-me' " +
	    "        data-fieldid='<%- fieldid %>' " +
	    "        data-fieldname='<%- fieldname %>' " +
	    "        data-label='<%- prompt %>' " +
	    "        name='<%- name %>' type='hidden' " +
	    "        value='<%- value %>'>" +
	    "</div>";

	var multivalueControlString =
	    "<div style='display: inline-block;'>" +
	    " <span class='hidden multivalue-button-minus' " +
	    "       data-toggle='tooltip' " +
	    "       data-container='body' " +
	    "       data-trigger='hover' " +
	    "       title='Delete this copy'> " +
	    "  <button type='button' " +
	    "          class='btn btn-small btn-default' " +
	    "          style='margin-left: 5px; padding: 2px;'>"+
	    "    <span class='glyphicon glyphicon-minus'></span>" +
	    "</button></span>" +
	    "<span class='multivalue-button-plus' " +
	    "       data-toggle='tooltip' " +
	    "       data-container='body' " +
	    "       data-trigger='hover' " +
	    "       title='Add another copy'> " +
	    "  <button type='button' " +
	    "          class='btn btn-small btn-default' " +
	    "          style='margin-left: 0px; padding: 2px'>" +
	    "    <span class='glyphicon glyphicon-plus'></span>" +
	    "</button></span>" +
	    "<span class='multivalue-button-up' " +
	    "       data-toggle='tooltip' " +
	    "       data-container='body' " +
	    "       data-trigger='hover' " +
	    "       title='Move up'> " +
	    "  <button type='button' " +
	    "          class='btn btn-small btn-default' " +
	    "          style='margin-left: 0px; padding: 2px'>" +
	    "    <span class='glyphicon glyphicon-arrow-up'></span>" +
	    "</button></span>" +
	    "<span class='multivalue-button-down' " +
	    "       data-toggle='tooltip' " +
	    "       data-container='body' " +
	    "       data-trigger='hover' " +
	    "       title='Move down'> " +
	    "  <button type='button' " +
	    "          class='btn btn-small btn-default' " +
	    "          style='margin-left: 0px; padding: 2px'>" +
	    "    <span class='glyphicon glyphicon-arrow-down'></span>" +
	    "</button></span></div>";

	var helpPanelToggleString =
	    '<div id="pp-param-help-panel-toggle-state" ' +
	    '     style="display: none">closed</div>' +
	    '<div class="row">' +
	    ' <div class="col-sm-12">' +
	    '  <div id="help_show_all_panel" class="panel" ' +
	    '    style="border-width: 0px; border: none; box-shadow: none;">' +
	    '   <h5>' +
	    '     <a id="pp-param-help-panel-toggle-link" href="#">' +
	    '       <span id="pp-param-help-panel-toggle-glyph-span" ' +
	    '             class="glyphicon glyphicon-plus pull-left" ' +
	    '             style="font-weight: bold; "></span>' +
	    '       <span id="pp-param-help-panel-toggle-link-span" ' +
	    '             style="font-weight: bold; ">' +
	    '          &nbsp;&nbsp; Show All Parameter Help</span>' +
	    '     </a>' +
	    '   </h5>' +
	    '  </div>' +
	    ' </div>' +
	    '</div>';

	var formString =
	    "<form id='pp-form' " +
	    "      class='form-horizontal' role='form' method='post'>" +
	    "  <div class='row'>" +
	    "    <div id='pp-form-body' class='col-sm-12'></div>" +
	    "  </div>" +
	    "</form>" +
	    "<div id='image-picker-body'></div>";

	var emptyStructTemplate  = _.template(emptyStructTemplateString);
	var structSetTemplate    = _.template(structSetTemplateString);
	var emptyInputTemplate   = _.template(emptyInputTemplateString);
	var structTemplate       = _.template(structTemplateString);
	var groupTemplate        = _.template(groupTemplateString);
	var booleanTemplate      = _.template(booleanTemplateString);
	var inputTemplate        = _.template(inputTemplateString);
	var selectTemplate       = _.template(selectTemplateString);
	var mvalueTemplate       = _.template(multivalueControlString);
	var imageTemplate        = _.template(imageSelectString);
	var nodeTypeTemplate     = _.template(nodeTypeTemplateString);

	/*
	 * Generate various type fragments.
	 */
	function GenerateEmptyField(fieldIndex, details)
	{
	    var html = emptyInputTemplate({
		"fieldid"    : fieldIndex,
		"fieldname"  : details.name,
		"prompt"     : details.description,
	    });
	    return html;
	}
	function GenerateEmptyStruct(fieldIndex, details)
	{
	    var html = emptyStructTemplate({
		"fieldid"    : details.name,
		"fieldname"  : details.name,
		"prompt"     : details.description,
	    });
	    return html;
	}
	function GenerateBoolean(name, fieldIndex, details, value)
	{
	    // Watch for the strings "true" and "false". (json encoding in perl)
	    if (typeof value === "string") {
		value = value.toLowerCase();
		if (value == "true") {
		    value = true;
		}
		else {
		    value = false;
		}
	    }
	    var html = booleanTemplate({
		"fieldid"    : fieldIndex,
		"fieldname"  : details.name,
		"name"       : name,
		"prompt"     : details.description,
		"checked"    : (value ? "checked" : ""),
		"multivalue" : details.multiValue,
	    });
	    if (details.multiValue) {
		html += mvalueTemplate();
	    }
	    return html;
	}
	function GenerateSelect(name, fieldIndex, details, value, legalValues)
	{
	    if (legalValues === undefined) {
		legalValues = details.legalValues;
	    }
	    var html = selectTemplate({
		"fieldid"    : fieldIndex,
		"fieldname"  : details.name,
		"name"       : name,
		"options"    : legalValues,
		"prompt"     : details.description,
		"value"      : value,
		"multivalue" : details.multiValue,
	    });
	    if (details.multiValue) {
		html += mvalueTemplate();
	    }
	    return html;
	}
	function GenerateImage(name, fieldIndex, details, value)
	{
	    var display  = imageDisplay(value);

	    var html = imageTemplate({
		"fieldid"    : fieldIndex,
		"fieldname"  : details.name,
		"name"       : name,
		"prompt"     : details.description,
		"value"      : value,
		"display"    : display,
		"multivalue" : details.multiValue,
	    });
	    return html;
	}
	function GenerateNodeType(name, fieldIndex, details, value)
	{
	    var html = nodeTypeTemplate({
		"fieldid"    : fieldIndex,
		"fieldname"  : details.name,
		"name"       : name,
		"prompt"     : details.description,
		"value"      : value,
		"amlist"     : amlist,
		"constraints": details.inputConstraints,
		"multivalue" : details.multiValue,
	    });
	    return html;
	}
	function GenerateInput(name, fieldIndex, details, value)
	{
	    var placeholder = details.inputFieldHint ?
		details.inputFieldHint : ""
		
	    var html = inputTemplate({
		"fieldid"    : fieldIndex,
		"fieldname"  : details.name,
		"name"       : name,
		"prompt"     : details.description,
		"value"      : value,
		"multivalue" : details.multiValue,
		"placeholder": placeholder,
	    });
	    if (details.multiValue) {
		html += mvalueTemplate();
	    }
	    return html;
	}

	/*
	 * Create initial value dict for a struct, which starts with the
	 * defaultValue array, and then lifts up per-field defaults.
	 */
	function initStructInitialValues(details, defaultValue)
	{
	    var dict = {};

	    // If initialValues is not defined, then use itemDefaultValue
	    if (defaultValue === undefined) {
		if (details.itemDefaultValue) {
		    defaultValue = details.itemDefaultValue;
		}
		else {
		    defaultValue = {};
		}
	    }
	    
	    _.each(details.parameterOrder, function (name) {
		var pdetails = details.parameters[name];

		// Easy case, a plain field.
		if (!pdetails.multiValue) {
		    if (_.has(defaultValue, name)) {
			dict[name] = defaultValue[name];
		    }
		    else {
			dict[name] = pdetails.defaultValue;
		    }
		    return;
		}
		// multivalue fields get a dict too, of all the initial
		// values. Just like what we do when the field is not in
		// a struct. First an error check, we get a list in the
		// paramdefs.
		if (_.has(defaultValue, name) &&
		    !Array.isArray(defaultValue[name])) {
		    alert("Error in multivalue field in struct");
		    return;
		}
		dict[name] = {};

		var i = 0;
		var m = 0;

		// Not sure I like this.
		if (_.has(defaultValue, name)) {
		    m = defaultValue[name].length;
		    if (pdetails.min && pdetails.min > m) {
			m = pdetails.min;
		    }
		}
		else if (pdetails.min) {
		    m = pdetails.min;
		}
		while (i < m) {
		    var tname = name;
		    if (i) {
			tname = tname + "-" + i;
		    }
		    if (_.has(defaultValue, name) &&
			_.size(defaultValue[name]) > i) {
			dict[name][tname] = defaultValue[name][i];
		    }
		    else if (pdetails.defaultValue &&
			     pdetails.defaultValue.length > i) {
			dict[name][tname] = pdetails.defaultValue[i];
		    }
		    else {
			dict[name][tname] = pdetails.itemDefaultValue;
		    }
		    i++;
		}
	    });
	    return dict;
	}

	// A standard (or group) field.
	function initFieldInitialValues(details)
	{
	    var i = 0;
	    var m = 0;

	    // Easy if not multivalue.
	    if (! details.multiValue) {
		var name = details.name;

		//console.info("foo", name, details, details.hide);

		if (rerun_bindings && _.has(rerun_bindings, name)) {
		    if (Array.isArray(rerun_bindings[name])) {
			var warning = {
			    "message" : "The parameter set binding for " +
				name + " refers to a multivalue field, " +
				"but in the current profile it is a single " +
				"value field. Using the default instead."};
			
			console.info(warning);
			details.ppwarnings[name] = warning;
			details.values[name] = details.defaultValue;
		    }
		    else {
			var val = rerun_bindings[name];
			/*
			 * Some bad planning in the past.
			 */
			if (details.type == "boolean" && typeof val === "string") {
			    val = val.toLowerCase();
			    if (val == "true") {
				val = true;
			    }
			    else {
				val = false;
			    }
			}
			details.values[name] = val;
			if (val != details.defaultValue) {
			    details.hide = false;
			}
		    }
		}
		else {
		    details.values[name] = details.defaultValue;
		}
		return;
	    }

	    // Not sure I like this.
	    if (details.defaultValue) {
		if (!Array.isArray(details.defaultValue)) {
		    console.info("Error in multivalue field in field", details);
		    return;
		}
		m = details.defaultValue.length;
		if (details.min && details.min > m) {
		    m = details.min;
		}
	    }
	    else if (details.min) {
		m = details.min;
	    }
			
	    while (i < m) {
		var tname = details.name;
		if (i) {
		    tname = tname + "-" + i;
		}
		if (rerun_bindings &&
		    _.has(rerun_bindings, details.name) &&
		    rerun_bindings[details.name].length > i) {
		    var val = rerun_bindings[details.name][i];
		    /*
		     * Some bad planning in the past.
		     */
		    if (details.type == "boolean" && typeof val === "string") {
			val = val.toLowerCase();
			if (val == "true") {
			    val = true;
			}
			else {
			    val = false;
			}
		    }
		    details.values[tname] = val;
		}
		else if (details.defaultValue &&
		    details.defaultValue.length > i) {
		    details.values[tname] = details.defaultValue[i];
		}
		else {
		    details.values[tname] = details.itemDefaultValue;
		}
		i++;
	    }
	}

	/*
	 * Generate the form parts from the paramdefs block.
	 */
	function InitializeForm(paramdefs)
	{
	    console.info("InitializeForm", paramdefs);

	    // User can select a different profile.
	    formFields    = [];
	    formGroups    = {};
	    
	    /*
	     * First pass, associate form elements with their groups.
	     * This makes it easier to treat the groups as a unit later.
	     */
	    _.each(paramdefs, function(details, name) {
		var groupId     = null;
		var groupName   = null;

		// Backwards compatibility check for the "advanced" group.
		if (_.has(details, "advanced") && details.advanced) {
		    details["groupId"]   = "advanced";
		    details["groupName"] = "Advanced";
		    details["hide"]      = true;
		}
		// More backwards compat, make sure these are defined.
		if (!_.has(details, "multiValue")) {
		    details.multiValue = false;
		}
		if (!_.has(details, "name")) {
		    details.name = name;
		}
		
		if (_.has(details, "groupId") && details.groupId) {
		    groupId       = details.groupId;
		    if (_.has(details, "groupName")) {
			groupName = details.groupName;
		    }
		    else {
			groupName = groupId;
		    }
		    if (!groupName) {
			details.groupName = groupName = groupId;
		    }
		    if (groupName == "Advanced") {
			details.hide = true;
		    }
		    if (!_.has(formGroups, groupId)) {
			var field = {
			    "isgroup" : true,
			    "groupId" : groupId,
			    "type"    : details.type,
			    "hashelp" : false,
			    "visible" : details.hide ? false : true,
			};
			formGroups[groupId] = {
			    "id"         : groupId,
			    "prompt"     : groupName,
			    "fields"     : {},
			    "formfield"  : field,
			    "visible"    : details.hide ? false : true,
			};
			formFields.push(field);
		    }
		}
		else if (details.type == "struct") {
		    // Convenience to match above.
		    details["isgroup"]     = false;
		    details["values"]      = {};
		    // Only for applying parameter sets
		    details["ppwarnings"]  = {};
		    details["visible"]     = {};
		    details["hashelp"]     = false;
		    var visible            = details.hide ? false : true

		    /*
		     * Regarding initial values. When non multivalue, 
		     * defaultValue is a single dict.
		     * For simplicity, generate a dict for the values array
		     * from the per-field default values.
		     * 
		     * When multivalue, defaultValue is optional. If null
		     * we start with no versions of the struct. If defined,
		     * we start with as many versions as are in the list.
		     * Note that missing values in the dicts need to be
		     * lifted up from the per-field default values.
		     */
		    if (details.multiValue) {
			var i = 0;
			var initvals = null;

			if (rerun_bindings &&
			    _.has(rerun_bindings, details.name)) {
			    initvals = rerun_bindings[details.name];
			}
			else if (details.defaultValue) {
			    initvals = details.defaultValue;
			}
			if (initvals) {
			    _.each(initvals, function (initvals) {
				var dict = initStructInitialValues(details,
								   initvals);
				details.values["C-" + i]  = dict;
				details.visible["C-" + i] = visible
				i++;
			    });
			}
			// If min is more then provided initial values,
			// then need to add more initial values.
			while (i < details.min) {
			    var dict = initStructInitialValues(details);
			    details.values["C-" + i]  = dict;
			    details.visible["C-" + i] = visible
			    i++;
			}
		    }
		    else {
			var dict;
			
			if (rerun_bindings &&
			    _.has(rerun_bindings, details.name)) {
			    dict = initStructInitialValues(details,
						   rerun_bindings[details.name]);
			}
			else {
			    dict = initStructInitialValues(details);
			}
			details.values[0]  = dict;
			details.visible[0] = visible
		    }
		    
		    // See if any fields have long help.
		    _.each(details.parameters, function (details) {
			if (details.longDescription) {
			    details.hashelp = true;
			}
		    });
		    formFields.push(details);
		}
		else {
		    // Convenience for later
		    details.groupId = null;
		    details.groupName = null;
		}
		if (groupId) {
		    // Convenience to match above.
		    details["isgroup"]    = false;
		    details["values"]     = {};
		    // Only for applying parameter sets
		    details["ppwarnings"] = {};

		    // Setup the initial fields value.
		    initFieldInitialValues(details);
		    if (details.hide == false) {
			formGroups[groupId].visible = true;
		    }

		    // Add to list of fields in the group.
		    formGroups[groupId].fields[name] = details;
		    
		    // Mark the group as having a long help.
		    if (details.longDescription) {
			formGroups[groupId].formfield.hashelp = true;
		    }
		}
		else if (details.type != "struct") {
		    // Convenience to match above.
		    details["isgroup"]    = false;
		    details["values"]     = {};
		    details["hashelp"]    = false;
		    // Only for applying parameter sets
		    details["ppwarnings"] = {};

		    // Setup the initial field values
		    initFieldInitialValues(details);

		    // Mark the group as having a long help.
		    if (details.longDescription) {
			details.hashelp = true;
		    }

		    // Add to list of fields in the form.
		    formFields.push(details);
		}
		if (!details.description || details.description == "") {
		    details.description = name;
		}
		// Convenience for later.
		details.name = name;
	    });
	    if (debug) {
		console.info("formGroups", formGroups);
		console.info("formFields", formFields);
	    }
	}

	/*
	 * Generate all fields in a multivalue field.
	 */
	function GenerateMultiValueField(tuples, details, fieldIndex, 
					 bindings, structIndex)
	{
	    var hasError   = 0;
	    var hasChanges = 0;

	    if (debug) {
		console.info("GenerateMultiValueField",
			     fieldIndex, structIndex, tuples,
			     details, bindings);
	    }

	    var set = $("<div class='fieldset'></div>");
	    
	    // Watch for a multivalue field with no values yet.
	    if (_.size(tuples) == 0) {
		var outerdiv = GenerateField(details.name,
					     details, fieldIndex,
					     null, null, structIndex);
		set.append(outerdiv);
	    }
	    else {
		// Generate all copies of the field.
		_.each(tuples, function(value, key) {
		    var outerdiv = GenerateField(key, details, fieldIndex,
						 value, bindings, structIndex);
		
		    // Look for a reason to start the panel out uncollapsed.
		    if (outerdiv.hasClass("has-error") ||
			outerdiv.hasClass("has-warning") ||
			outerdiv.hasClass("has-changes")) {
			hasError = 1;
		    }
		    // Count up number of changes for the caller.
		    if (outerdiv.hasClass("has-changes")) {
			hasChanges++;
		    }
		    set.append(outerdiv);
		});
	    }
	    // Bubble up.
	    if (hasChanges) {
		set.addClass("has-changes");
		// Tell caller the number of changes in this group.
		set.data("has-changes", hasChanges);
	    }
	    if (hasError) {
		set.addClass("has-error");
	    }
	    return set;
	}

	function GenerateField(name, details,
			       fieldIndex, value, bindings, structIndex)
	{
	    var type        = details.type;
	    var prompt      = details.description; 
	    var longhelp    = details.longDescription;
	    var advanced    = details.advanced;
	    var multivalue  = details.multiValue;
	    var fieldname   = details.name;
	    var help_panel  = null;
	    var changeMsg   = "";
	    var paramErrors     = new Array();
	    var paramWarnings   = new Array();
	    var fixedValue      = null;
	    var html;

	    if (debug) {
		console.info("GenerateField",
			     name, fieldIndex, structIndex, value, details);
	    }

	    if (bindings) {
		if (_.has(bindings.bindings, fieldname)) {
		    var slot;
		    var binding = bindings.bindings[fieldname];

		    if (multivalue) {
			// Have to find the correct error based on name.
			_.each(binding.value, function (val) {
			    if (val.name == name) {
				slot = val;
			    }
			});
		    }
		    else {
			slot = binding;
		    }
		    if (_.has(slot, "errors")) {
			_.each(slot["errors"], function (i) {
			    var message = bindings.errors[i].message;
			    paramErrors.push(message);
			    // Mark the error/warning as being spit out
			    bindings.errors[i]["notified"] = true;
			});
		    }
		    if (_.has(slot, "warnings")) {
			_.each(slot["warnings"], function (i) {
			    var message = bindings.warnings[i].message;
			    paramWarnings.push(message);
			    // Mark the error/warning as being spit out
			    bindings.warnings[i]["notified"] = true;
			});
		    }
		    if (_.has(slot, "fixedValue")) {
			value = slot["fixedValue"];
			fixedValue =
			    '<span class="text-success">' +
			    ' <b><span class="glyphicon ' +
			    '         glyphicon-exclamation-sign">' +
			    '    </span>&nbsp;' +
			    ' This value has been changed to ' +
			    "'" + value + "' " +
			    'because the profile geni-lib script ' +
			    'suggested it to resolve the problem.</b></span>';
		    }
		}
	    }
	    /*
	     * Look for oddities caused by applying saved parameter sets.
	     */
	    if (rerun_bindings) {
		if (_.has(details.ppwarnings, name)) {
		    var warning = details.ppwarnings[name];

		    paramWarnings.push(warning.message);
		    rerun_warnings.push(warning);
		}
		// A value that is not in the option set.
		else if (details.legalValues) {
		    var okay = false;
		    
		    for (var i = 0; i < details.legalValues.length; ++i) {
			var option = details.legalValues[i];
		       
			if (Array.isArray(option)) {
			    if (value == option[0]) {
				okay = true;
				break;
			    }
			}
			else if (value == option) {
			    okay = true;
			    break;
			}
		    }
		    if (!okay) {
			var message = 
			    "The value in the parameter set " +
			    "is not a valid option. Using the "+
			    "default value instead.";

			paramWarnings.push(message);
			rerun_warnings.push({"message" : message});
		    }
		}
	    }

	    if (value == null) {
		// Special case; a multivalue field with no values.
		html = GenerateEmptyField(fieldIndex, details);
	    }
	    else if (type == "boolean") {
		html = GenerateBoolean(name, fieldIndex, details, value);
	    }
	    else if (type == "nodetype") {
		html = GenerateNodeType(name, fieldIndex, details, value);
	    }
	    else if (type == "fixedendpoint") {
		html = GenerateSelect(name, fieldIndex, details, value,
				     window.powderTypes.fixedEndpoints);
	    }
	    else if (type == "basestation") {
		html = GenerateSelect(name, fieldIndex, details, value,
				      window.powderTypes.baseStations);
	    }
	    else if (details.legalValues &&
		     Array.isArray(details.legalValues) && 
		     details.legalValues.length) {
		html = GenerateSelect(name, fieldIndex, details, value);
	    }
	    else if (type == "image") {
		html = GenerateImage(name, fieldIndex, details, value);
	    }
	    else {
		html = GenerateInput(name, fieldIndex, details, value);
	    }
	    var outerdiv = $("<div class='form-group' " +
			     "     style='margin-bottom: 15px;'></div>");
	    var innerdiv = $("<div class='col-sm-8'></div>");
	    var item     = $(html);

	    // The field desription on the left.
	    var label_text =
		"<label for='" + name + "' " +
		" class='col-sm-4 control-label'> " + prompt;
	    
	    // Extra help is optional.
	    if (longhelp) {
		var help_panel_id = name + "_help_subpanel_collapse";
		if (structIndex) {
		    help_panel_id = help_panel_id + "-" + structIndex;
		}
		longhelp = escapeHtml(longhelp);
		
		label_text = label_text +
		    "<span class='pp-param-popover' " +
		    " data-toggle='popover' " +
		    " data-trigger='hover' " +
		    //" data-delay='{\"hide\":1000}' " +
		    " data-content='" + longhelp + "'>" +
		    " <a href='#" + help_panel_id + "'" +
		    " data-toggle='collapse'>" +
		    "<i class='glyphicon glyphicon-question-sign'></i>" +
		    "</a></span>";
		
		help_panel = 
		    "<div id='" + help_panel_id + "'" +
		    "     class='panel-collapse collapse panel panel-info " +
		    "            col-sm-12 pp-param-help-panel'" +
		    "     style='background-color: #e6f6fa; height: auto; " +
		    "            margin-left: 0px; margin-right: 0px; " +
		    "            margin-top: 5px; margin-bottom: 0px; " +
		    "            padding: 5px;' data-toggle='collapse'>" +
		        longhelp + "</div>";
	    }
	    label_text = label_text + "</label>";
	    outerdiv.append(label_text);
	    innerdiv.html(item);

	    if (type == "nodetype") {
		var html = "";
		var constraints = details.inputConstraints;
		var re = new RegExp('(\>\=|\<\=|\!\=|\=|\>|\<)(.+)');

		var constraint_mapping = {
		    "cores"   : "hw_cpu_cores",
		    "sockets" : "hw_cpu_sockets",
		    "speed"   : "hw_cpu_speed",
		    "threads" : "hw_cpu_threads",
		    "mem"     : "hw_mem_size",
		    "memory"  : "hw_mem_size",
		    "memsize" : "hw_mem_size",
		    "mem_size": "hw_mem_size",
		    "disk"    : "disksize",
		    "disksize": "disksize",
		    "arch"    : "architecture",
		};

		var checkConstraints = function (typeinfo) {
		    // Assume x86_64 architecture.
		    if (!_.has(typeinfo, "architecture")) {
			typeinfo["architecture"] = "x86_64";
		    }
		    var entries = Object.entries(constraints);
		    console.info("checkConstraint:", typeinfo);
		    
		    for (var [constraint, wanted] of entries) {
			console.info("checkConstraint:", constraint, wanted);
			if (!_.has(constraint_mapping, constraint)) {
			    console.info("Unknown constraint: " + constraint);
			    continue;
			}
			var mapping = constraint_mapping[constraint];
			if (!_.has(typeinfo, mapping)) {
			    console.info("No typeinfo: " + constraint);
			    return 0;
			}
			var value = typeinfo[mapping];
			if (0 && amapping == "hw_mem_size") {
			    value = parseFloat(value) / 1024;
			}
			if (isNumeric(value) == isNumeric(wanted) ||
			    !isNumeric(value)) {
			    if (value != wanted) {
				console.info("Failed: ", typeinfo[mapping]);
				return 0;
			    }
			    continue;
			}
			// Typeinfo value is known to be numeric at this point.
			// And "wanted" is not numeric, but might have an
			// operator in the front. Lets find out.
			var results = wanted.match(re);
			console.info("re", results);
			if (!results) {
			    console.info("not an operator");
			    return 0;
			}
			var op  = results[1];
			wanted  = parseFloat(results[2]);
			var res = false;
			if (op == "=") {
			    res = (wanted == value);
			}
			else if (op == "!") {
			    res = (wanted != value);
			}
			else if (op == ">") {
			    res = (value > wanted);
			}
			else if (op == "<") {
			    res = (value < wanted);
			}
			else if (op == ">=") {
			    res = (value >= wanted);
			}
			else if (op == "<=") {
			    res = (value <= wanted);
			}
			if (!res) {
			    console.info("Test failed: ",
					 constraint, op, value, wanted);
			    return 0;
			}
		    }
		    return 1;
		};
		// Lets make sure the value provided is in the list.
		var validoption = false;
		
		/*
		 * Create the menu/submenus for each aggregate and list of
		 * types.  For each type, see if we have attribute info, and
		 * create a popover for it.
		 *
		 * TODO: Add filtering.
		 */
		_.each(amlist, function(aggregate, idx) {
		    var count  = 0;
		    var agghtml = 
			"<li class='dropdown-submenu'> " +
			"  <a href='#' class='dropdown-toggle' " +
			"     data-toggle='dropdown'>" + aggregate.name + "</a>"+
			"    <ul class='dropdown-menu scrollable-submenu'>";
		    
		    _.each(aggregate.typelist, function(typeinfo, type) {
			if (_.has(prunetypes, type)) {
			    return;
			}

			var typehtml =
			    "  <li style='position: relative;'>" +
			    " <a href='#' name='" + type + "' " +
			    "         class='type-select'>" + type + "</a>";

			if (typeinfo) {
			    /*
			     * Filtering check. The constraint list is treated
			     * as an "and" for the purposes of filtering.
			     */
			    if (constraints) {
				if (!checkConstraints(typeinfo)) {
				    return;
				}
			    }
			    var pophtml =
				"<table class='table table-condensed'><tbody> ";

			    _.each(typeinfo, function(val, key) {
				key = key.replace(/^hw_/, "");
				//console.info(val, key);
				
				pophtml +=
				    "<tr><td>" + key +
				    "</td><td>" + val + "</td></tr>";
			    });
			    pophtml += "</tbody></table>";
			    pophtml = escapeHtml(pophtml);
			    
			    typehtml +=
				"<span class='icon-info-right glyphicon " +
 				"  glyphicon-info-sign' " +
				"  data-toggle='popover' data-html=true " +
				"  data-content=\"" + pophtml + "\"></span>";
			}
			else if (constraints) {
			    // If we have constraints but no typeinfo, we treat
			    // that as a hard failure (we filtere it out).
			    return;
			}
			count++;
			typehtml += "</li>";
			agghtml  += typehtml;
			if (value && type == value) {
			    validoption = true;
			}
		    });
		    agghtml += "</ul></li>";
		    if (count) {
			html += agghtml;
		    }
		});
		$(innerdiv).find("ul").append(html);

		// Print a warning if the value is not in the list.
		if (value && !validoption) {
		    // Hmm, problem. Older profiles that were written with
		    // the idea that NODETYPE was a plain string, will be
		    // screwed if they had a string default like "any". So
		    // just map it to Please Select. 
		    if (0) {
			var message;

			if (rerun_bindings) {
			    message =
				"The node type in the parameter set " +
				"is not in the list of types. Using the "+
				"default node type instead.";
			}
			else {
			    message =
				"The default node type is not in the set of " +
				"types.";
			}
			paramWarnings.push(message);
			if (rerun_bindings) {
			    rerun_warnings.push({"message" : message});
			}
		    }
		    value = undefined;
		}

		// Initialize the value (hidden field, button).
		if (value) {
		    $(innerdiv).find("button .type-selected").html(value);
		    $(innerdiv).find("input").val(value);
		}

		// Need to use a click handler cause of popover problems
		// with the submenus.
		$(innerdiv).find(".glyphicon-info-sign").popover({
		    trigger: 'manual',
		    placement: 'auto',
		    container: 'body',
		});
		$(innerdiv).find(".glyphicon-info-sign").click(
		    function (event) {
			event.preventDefault();
			event.stopPropagation();
			$(this).popover('toggle');
		    });

		// Move the main menu to halfway up/down.
		$(innerdiv).find(".dropdown")
		    .on("shown.bs.dropdown", function (event) {
			var height = $(this).find(".right-menu").height();
			//console.info("height", height);
			$(this).find(".right-menu").css("top", 0 - (height / 2));
		    });

		// Make sure popovers are gone when the main menu is gone.
		$(innerdiv).find(".dropdown")
		    .on("hide.bs.dropdown", function (event) {
			$(innerdiv).find(".glyphicon-info-sign").popover("hide");
		    });
		
		$(innerdiv).find(".dropdown-submenu")
		    .hover(
			function(event) {
			    var menu = $(event.target)
				.parent().find(".dropdown-menu");
		    
			    $(menu).css("display", "inline-block");
			    var height = $(menu).height();
			    if (height > 26) {
				height = 0 - (height / 2);
				$(menu).css("bottom", height + "px");
			    }
			},
			function(event) {
			    var menu = $(event.target)
				.parent().find(".dropdown-menu");
			    $(menu).css("display", "none");
			});

		// Make sure popovers are gone when a submenu is gone. We do not
		// get the dropdown events for these, so hook into hover.
		$(innerdiv).find(".dropdown-submenu>.dropdown-menu")
		    .hover(
			function(event) {
			},
			function(event) {
			    $(this).find(".glyphicon-info-sign").popover("hide");
			});
		
		/*
		 * When a selection is made, change the button text to the type
		 * and set the actual input (which is a hidden input).
		 */
		$(innerdiv).find(".type-select").click(function (event) {
		    event.preventDefault();
		    //console.info($(this).attr("name"));
		    $(innerdiv).find("button .type-selected")
			.html($(this).attr("name"));
		    $(innerdiv).find("input").val($(this).attr("name"))
		    // Make sure the popover is gone too.
		    $(innerdiv).find(".glyphicon-info-sign").popover("hide");
		    Modified();
		});
		/*
		 * Since this is not a "select" we need a way to let the
		 * user clear the selection, but not when constrained.
		 */
		if (!constraints) {
		    $(innerdiv).find(".clear-select").click(function (event) {
			event.preventDefault();
			//console.info($(this).html());
			$(innerdiv).find("button .type-selected").html("Any");
			$(innerdiv).find("input").val("");
		    });
		}
	    }

	    // Handle errors and warnings and changed values.
	    if (paramErrors.length || paramWarnings.length) {
		if (paramErrors.length) {
		    var errorMsg = "";

		    for (var i = 0; i < paramErrors.length; ++i) {
			var message = paramErrors[i];

			if (errorMsg)
			    errorMsg += "<br>";

			errorMsg += message
		    }
		    if (fixedValue) {
			errorMsg += "<br>" + fixedValue;
			outerdiv.addClass('has-changes');
		    }
		    outerdiv.addClass('has-error');
		    // This used to have display:inline, but that did
		    // work with multivalue fields.
		    innerdiv.append('<label class="control-label" ' +
				    'style="padding-top: 2px;" ' +
				    'for="inputError">Error: ' +
				    errorMsg + '</label>');
		}
		else if (paramWarnings.length) {
		    var errorMsg = "";

		    for (var i = 0; i < paramWarnings.length; ++i) {
			var message = paramWarnings[i];

			if (errorMsg)
			    errorMsg += "<br>";

			errorMsg += message
		    }
		    if (fixedValue) {
			errorMsg += "<br>" + fixedValue;
			outerdiv.addClass('has-changes');
		    }
		    outerdiv.addClass('has-warning');
		    innerdiv.append('<label class="control-label" ' +
				    'style="display: inline;" ' +
				    'for="inputWarning">Warning: ' +
				    errorMsg + '</label>');
		}
	    }
	    if (help_panel) {
		innerdiv.append(help_panel);
	    }
	    outerdiv.append(innerdiv);

	    if (type == "image") {
		initImagePicker(outerdiv);
	    }
	    
	    // Helper function;
	    var nameList = function () {
		if (formFields[fieldIndex].type == "struct") {
		    /*
		     * This is a bit harder since the values list
		     * we care about is in the struct definition, and
		     * add/remove changes that list, not the values list
		     * in the field itself.
		     */
		    var struct = formFields[fieldIndex];
		    var vlist  = struct.values[structIndex][details.name];

		    names  = Object.keys(vlist);
		}
		else {
		    names  = Object.keys(details.values);
		}
		return names;
	    }

	    /*
	     * Set up handlers for a multivalue field.
	     */
	    if (multivalue && value == null) {
		// Zero length, handler to add first value.
		outerdiv.find(".multivalue-button-plus button")
		    .click(function (event) {
			event.preventDefault();
			// Delete leaves tooltip behind, a bootstrap bug.
			outerdiv.find('[data-toggle="tooltip"]')
			    .tooltip("hide");
			DuplicateField(outerdiv, details, 
				       fieldIndex, structIndex);
			outerdiv.remove();
		    })
	    }
	    else if (multivalue) {
		var names = nameList();
		
		// Always bind this.
		outerdiv.find(".multivalue-button-plus button")
		    .click(function(event) {
			event.preventDefault();
			DuplicateField(outerdiv, details,
				       fieldIndex, structIndex);
		    });
		// Disable plus button if reached maximum number.
		if (details.max && _.size(names) >= details.max) {
		    outerdiv.find(".multivalue-button-plus")
			.attr('title', 'Maximum values is ' + details.max)
			.tooltip('setContent');
		    // Disable the button, but not in a gross way.
		    outerdiv.find(".multivalue-button-plus button")
			.css("pointer-events", "none");
		}
		
		// Always bind this.
		outerdiv.find(".multivalue-button-minus")
		    .removeClass("hidden");
		outerdiv.find(".multivalue-button-minus button")
		    .click(function(event) {
			event.preventDefault();
			DeleteField(outerdiv, details, name,
				    fieldIndex, structIndex);
			    
		    });
		/*
		 * User is allowed to delete fields as long as the number
		 * of fields is greater then the min. Change the tooltip
		 * and disable the button.
		 */
		if (details.min && _.size(names) <= details.min) {
		    outerdiv.find(".multivalue-button-minus")
			.attr('title', 'Minimum values is ' + details.min)
			.tooltip('setContent');
		    // Disable the button, but not in a gross way.
		    outerdiv.find(".multivalue-button-minus button")
			.css("pointer-events", "none");
		}
		if (_.size(names) > 1 && _.last(names) != name) {
		    outerdiv.css("margin-bottom", "2px");
		}

		/*
		 * Up/Down buttons.
		 */
		outerdiv.find(".multivalue-button-up button")
		    .click(function(event) {
			event.preventDefault();
			MoveField("up", outerdiv, details, name,
				  fieldIndex, structIndex);
		    });
		// Disable up button on first value.
		if (_.first(names) == name) {
		    outerdiv.find(".multivalue-button-up")
			.css("pointer-events", "none");
		}
		outerdiv.find(".multivalue-button-down button")
		    .click(function(event) {
			event.preventDefault();
			MoveField("down", outerdiv, details, name,
				  fieldIndex, structIndex);
		    });
		// Disable down button on last value.
		if (_.last(names) == name) {
		    outerdiv.find(".multivalue-button-down")
			.css("pointer-events", "none");
		}
	    }
	    // Init the tooltips
	    outerdiv.find('[data-toggle="tooltip"]').tooltip();
	    return outerdiv;
	}

	// Helper function, map the field to a values array, which is
	// different for structures since it down a couple of levels.
	function valuesList(details, fieldIndex, structIndex)
	{
	    var values;

	    if (debug) {
		console.info("valuesList", fieldIndex, structIndex, details);
	    }
	    
	    if (formFields[fieldIndex].type == "struct") {
		/*
		 * The values list we care about is in the struct
		 * definition, and add/remove changes that list, not
		 * the values list in the field itself.
		 */
		var struct = formFields[fieldIndex];

		values = struct.values[structIndex][details.name];
	    }
	    else {
		values = details.values;
	    }
	    return values;
	}
	// And update the values list.
	function updateValuesList(newvalues, details, fieldIndex, structIndex)
	{
	    // Update the values in the right place, see above.
	    if (formFields[fieldIndex].type == "struct") {
		var struct = formFields[fieldIndex];

		struct.values[structIndex][details.name] = newvalues;
	    }
	    else {
		details.values = newvalues;
	    }
	}

	// Update buttons and margins in a set of fields after change.
	function updateButtonsMargins(fieldset)
	{
	    if (fieldset.length == 1) {
		var field = fieldset[0];

		$(field).find(".multivalue-button-down")
		    .css("pointer-events", "none");
		$(field).find(".multivalue-button-up")
		    .css("pointer-events", "none");
		// Big margin before next field.
		$(field).css("margin-bottom", "15px");
		return
	    }
	    for (var i = 0; i < fieldset.length; i++) {
		var field = fieldset[i];

		if (i == 0) {
		    // No up button on first entry.
		    $(field).find(".multivalue-button-down")
			.css("pointer-events", "auto");
		    $(field).find(".multivalue-button-up")
			.css("pointer-events", "none");
		    // Small margin on the first
		    $(field).css("margin-bottom", "2px");
		}
		else if (i == fieldset.length - 1) {
		    // No down entry on last entry.
		    $(field).find(".multivalue-button-down")
			.css("pointer-events", "none");
		    $(field).find(".multivalue-button-up")
			.css("pointer-events", "auto");
		    // Big margin on the first
		    $(field).css("margin-bottom", "15px");
		}
		else {
		    // Both buttons enabled on middle entries;
		    $(field).find(".multivalue-button-down")
			.css("pointer-events", "auto");
		    $(field).find(".multivalue-button-up")
			.css("pointer-events", "auto");
		    // Small marging in the middle
		    $(field).css("margin-bottom", "2px");
		}
	    }
	}

	/*
	 * Duplicate a single field
	 */
	function DuplicateField(fielddiv, details, fieldIndex, structIndex)
	{
	    var curname;

	    if (debug) {
		console.info("DuplicateField", fieldIndex,
			     structIndex, details);
	    }

	    // Find current field name in the input 
	    fielddiv.find(".format-me").each(function () {
		curname = $(this).attr("name");
	    });

	    // Current values for the field (which one is not multivalue).
	    var values = valuesList(details, fieldIndex, structIndex);
	    var count  = Object.keys(values).length;

	    // Make up a new name and add to the values list, for form regen.
	    // Note that since we allow delete in the middle, we have to
	    // look at the names to make sure we are making up a unique one.
	    var name = details.name;
	    if (count) {
		var i = count;
		while (1) {
		    name = details.name + "-" + i;
		    if (!_.has(values, name)) {
			break;
		    }
		    i++;
		}
	    }

	    /*
	     * Need to regenerate the values object, moving the keys
	     * into the proper order. Note that key ordering is actually
	     * not guaranteed, but every browser does it.
	     */
	    var newvalues = {};
	    var curkeys   = _.keys(values);
	    var newidx    = _.indexOf(curkeys, curname) + 1;

	    // Inserts the new name into the array in the right position.
	    curkeys.splice(newidx, 0, name);

	    // Generate new values object with new key ordering
	    _.each(curkeys, function(key) {
		if (key == name) {
		    newvalues[key] = details.itemDefaultValue;
		}
		else {
		    newvalues[key] = values[key];
		}
	    });
	    //console.info(newvalues);
	    updateValuesList(newvalues, details, fieldIndex, structIndex);
	    values = newvalues;

	    // New copy.
	    var outerdiv = GenerateField(name, details, fieldIndex,
					 details.itemDefaultValue, null,
					 structIndex);

	    // If number of values is now greater then min, enable the
	    // minus buttons and change the tool tip.
	    if (details.min != null && _.size(values) > details.min) {
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-minus")
		    .attr('title', 'Delete this copy')
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-minus button")
		    .css("pointer-events", "auto");
	    }
	    // If number more then max, need to disable the plus signs
	    // change the tooltip message.
	    if (details.max && _.size(values) >= details.max) {
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-plus")
		    .attr('title', 'Maximum value is ' + details.max)
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		// Disable the plus buttons
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-plus button")
		    .css("pointer-events", "none");
	    }

	    /*
	     * Add this new one after the current one.
	     */
	    fielddiv.after(outerdiv);

	    // Update buttons and margins as needed.
	    updateButtonsMargins(fielddiv.closest(".fieldset")
				 .find(".form-group"));

	    // Set focus to new input field. 
	    outerdiv.find("input").focus();

	    Modified();

	    //console.info("details", name, details);
	    //console.info("values", values);
	}

	/*
	 * Delete a single field
	 */
	function DeleteField(fielddiv, details, name, fieldIndex, structIndex)
	{
	    var values    = valuesList(details, fieldIndex, structIndex);

	    // Remove from the list of values (copies) array.
	    delete values[name];

	    // No values left? Need to create the empty version.
	    if (_.size(values) == 0) {
		var div = GenerateField(details.name, details, fieldIndex,
					null, null, structIndex);
		fielddiv.before(div);
		// Delete leaves tooltip behind, seems like a bootstrap bug.
		fielddiv.find('[data-toggle="tooltip"]').tooltip("hide");
		fielddiv.remove();
	    	Modified();
		return;
	    }
	    
	    // If number of values is now <= min, then turn off
	    // all of the minus signs.
	    if (details.min != null && _.size(values) <= details.min) {
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-minus")
		    .attr('title', 'Minimum value is ' + details.min)
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-minus button")
		    .css("pointer-events", "none");
	    }
	    // If below max (and we should be if we get here!), change
	    // the plus sign tooltips back to the right message.
	    if (details.max && _.size(values) < details.max) {
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-plus")
		    .attr('title', 'Add another copy')
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		// Reenable the plus buttons
		fielddiv.closest(".fieldset")
		    .find(".multivalue-button-plus button")
		    .css("pointer-events", "auto");
	    }
	    var fieldset = fielddiv.closest(".fieldset");

	    // Delete leaves tooltip behind, seems like a bootstrap bug.
	    fielddiv.find('[data-toggle="tooltip"]').tooltip("hide");
	    fielddiv.remove();

	    // Update buttons and margins as needed.
	    updateButtonsMargins(fieldset.find(".form-group"));
	    
	    Modified();
	    
	    //console.info("details", name, details);
	    //console.info("values", values);
	}

	/*
	 * Move a field up or down.
	 */
	function MoveField(dir, fielddiv, details, name,
			   fieldIndex, structIndex)
	{
	    var values = valuesList(details, fieldIndex, structIndex);
	    //console.info("MoveField", dir, name, values);

	    /*
	     * Need to regenerate the values object, moving the keys
	     * into the proper order. Note that key ordering is actually
	     * not guaranteed, but every browser does it.
	     */
	    var newvalues = {};
	    var curkeys   = _.keys(values);
	    var oldidx    = _.indexOf(curkeys, name);
	    var newidx    = (dir == "up" ? oldidx - 1 : oldidx + 1);

	    // This moves the element in the array.
	    curkeys.splice(newidx, 0, curkeys.splice(oldidx, 1)[0]);

	    // Generate new values object with new key ordering
	    _.each(curkeys, function(key) {
		newvalues[key] = values[key];
	    });
	    updateValuesList(newvalues, details, fieldIndex, structIndex);
	    values = newvalues;
	    //console.info(newvalues);

	    if (dir == "up") {
		fielddiv.prev().insertAfter(fielddiv);
	    }
	    else {
		fielddiv.next().insertBefore(fielddiv);
	    }

	    // Update buttons and margins as needed.
	    updateButtonsMargins(fielddiv.closest(".fieldset")
				 .find(".form-group"));

	    // Kill the focus on the button which might not be enabled
	    // any longer.
	    $(':focus').blur();
	    
	    Modified();
	}

	function GenerateGroup(fieldIndex, bindings)
	{
	    var field        = formFields[fieldIndex];
	    var groupId      = field.groupId;
	    var group        = formGroups[groupId];
	    var fields       = group.fields;
	    var name         = groupId + "-" + fieldIndex;
	    var hasError     = false;
	    var hasWarning   = false;
	    var hasChanges   = 0;

	    var html = groupTemplate({
		"fieldid"    : groupId,
		"name"       : name,
		"prompt"     : group.prompt,
	    });
	    var groupdiv = $(html);

	    // Each field in the group
	    _.each(fields, function(details) {
		var set;

		if (details.multiValue) {
		    set = GenerateMultiValueField(details.values,
						  details, fieldIndex,
						  bindings, null);
		}
		else {
		    set = GenerateField(details.name, details,
					fieldIndex,
					details.values[details.name],
					bindings, null);
		}
		if (set.hasClass("has-error")) {
		    hasError = 1;
		}
		if (set.hasClass("has-warning")) {
		    hasWarning = 1;
		}
		// Count up number of changes for the caller.
		if (set.hasClass("has-changes")) {
		    hasChanges = hasChanges + set.data("has-changes");
		}
		$(groupdiv).find(".panel-body").append(set);
	    });
	    // Remember visibility for redraw after errors	
	    $(groupdiv).find(".pp-param-group-subpanel-collapse")
		.bind("shown.bs.collapse", function () {
		    var icon = $(this).closest(".panel")
			.find(".subpanel-collapse-chevron .glyphicon");
		    $(icon).removeClass("glyphicon-chevron-right");
		    $(icon).addClass("glyphicon-chevron-down");
		    group.visible = true;
		})
		.bind("hidden.bs.collapse", function () {
		    var icon = $(this).closest(".panel")
			.find(".subpanel-collapse-chevron .glyphicon");
		    $(icon).removeClass("glyphicon-chevron-down");
		    $(icon).addClass("glyphicon-chevron-right");
		    group.visible = false;
		});

	    /*
	     * Expand if errors or was previously visible. We have to
	     * do this the long way to avoid jquery behavior; the event
	     * is not fired until the DOM is updated, which causes the
	     * screen to look funny when the group is opened right after
	     * being drawn closed.
	     */
	    if (hasError || hasWarning || group.visible) {
		$(groupdiv).find(".pp-param-group-subpanel-collapse")
		    .addClass("in");
		$(groupdiv).find(".subpanel-collapse-chevron .glyphicon")
		    .removeClass("glyphicon-chevron-right")
		    .addClass("glyphicon-chevron-down");
	    }
	    // Tell caller the number of changes in this group.
	    $(groupdiv).data("has-changes", hasChanges);

	    return groupdiv;
	}

	function GenerateStruct(fieldIndex, bindings)
	{
	    var details     = formFields[fieldIndex];
	    var values      = details.values;
	    var multivalue  = details.multiValue;
	    var params      = details.parameters;
	    var ordering    = details.parameterOrder;
	    var name        = details.name;
	    var prompt      = details.description ? details.description : name;
	    var hasChanges  = 0;
	    var structdiv;

	    // Process all copies of the struct and append to div.
	    // Multivalue structs look different.
	    if (multivalue) {
		if (details.multiValueTitle) {
		    prompt = details.multiValueTitle;
		}
		var html = structSetTemplate({
		    "fieldid"     : name,
		    "longhelp"    : details.longDescription,
		    "longhelp_id" : "help-" + details.name,
		    "prompt"      : prompt,
		});
		structdiv = $(html);

		/*
		 * Handlers to toggle the chevron. Note that we also get
		 * an event when the inner structdiv panels collapse/show,
		 * cause of event bubble up. I was not able to figure out
		 * how to bind this event to *just* the structset panel,
		 * (which was causing the strucset chevron to flip whenever
		 * an inner one flipped). So, check event target and ignore
		 * if the event is for an inner structdiv.
		 */
		$(structdiv).find(".pp-param-structset-subpanel-collapse")
		    .on("shown.bs.collapse",  function (e) {
			var target = $(e.target);
			if (target
			    .hasClass("pp-param-group-subpanel-collapse")) {
			    return;
			}
			$(this).closest(".panel")
			    .find(".structset-subpanel-collapse-chevron " +
				  ".glyphicon")
			    .removeClass("glyphicon-chevron-right")
			    .addClass("glyphicon-chevron-down");
		    })
		    .on("hidden.bs.collapse", function (e) {
			var target = $(e.target);
			if (target
			    .hasClass("pp-param-group-subpanel-collapse")) {
			    return;
			}
			$(this).closest(".panel")
			    .find(".structset-subpanel-collapse-chevron " +
				  ".glyphicon")
			    .removeClass("glyphicon-chevron-down")
			    .addClass("glyphicon-chevron-right");
		    });

		if (bindings && 
		    _.has(bindings.bindings, name) &&
		    (_.has(bindings.bindings[name], "warnings") ||
		     _.has(bindings.bindings[name], "errors"))) {

		    if (_.has(bindings.bindings[name], "errors")) {
			var errors  = bindings.bindings[name]["errors"];
			var message = "";

			for (var i = 0; i < errors.length; ++i) {
			    var index = errors[i];
			    var text  = bindings.errors[index].message;

			    if (message != "") {
				message += "<br>";
			    }
			    message += text;
			    
			    // Mark the error/warning as being spit out
			    bindings.errors[i]["notified"] = true;
			}
			structdiv.addClass('has-error');

			var html = 
			    '<div class="panel panel-danger ' +
			    '            col-xs-10 col-xs-offset-1" ' +
			    '    style="height: auto;' +
			    '           margin-top: 5px; margin-bottom: 5px;' +
			    '           padding: 0px;">' +
			    ' <div class=panel-heading> ' +
			    message + '</div></div>';
			
			structdiv.find(".structset-panel-body").append(html);
		    }
		    if (_.has(bindings.bindings[name], "warnings")) {
			var warnings = bindings.bindings[name]["warnings"];
			var message  = "";

			for (var i = 0; i < warnings.length; ++i) {
			    var index = warnings[i];
			    var text  = bindings.warnings[index].message;

			    if (message != "") {
				message += "<br>";
			    }
			    message += text;
			    // Mark the error/warning as being spit out
			    bindings.warnings[i]["notified"] = true;
			}
			structdiv.addClass('has-warning');

			var html = 
			    '<div class="panel panel-warning ' +
			    '            col-xs-10 col-xs-offset-1" ' +
			    '    style="height: auto;' +
			    '           margin-top: 5px; margin-bottom: 5px;' +
			    '           padding: 0px;">' +
			    ' <div class=panel-heading> ' +
			    message + '</div></div>';

			structdiv.find(".structset-panel-body").append(html);
		    }
		}
	    }
	    else {
		structdiv = $("<div class='row structset'></div>");
	    }
	    
	    /*
	     * Special case in structs; might not have any default sets.
	     * Kind of a strange UI element.
	     */
	    if (multivalue && _.size(values) == 0) {
		var html = GenerateEmptyStruct(fieldIndex, details);
		var groupdiv = $(html);
		
		groupdiv.find(".multivalue-struct-button-plus button")
		    .click(function(event) {
			event.preventDefault();
			var newdiv = GenerateStructDiv(fieldIndex, 0, null);
			// We leave tooltips behind, seems like a bootstrap bug.
			groupdiv.find('[data-toggle="tooltip"]')
			    .tooltip("hide");
			groupdiv.after(newdiv);
			groupdiv.remove();
			// Set focus to first input
			newdiv.find("input").first().focus();
			Modified();
		    });
		structdiv.find(".structset-panel-body").append(groupdiv);
		return structdiv;
	    }
	    
	    _.each(values, function(values, index) {
		var groupdiv = GenerateStructDiv(fieldIndex, index, bindings);

		// Bubble this up.
		if (groupdiv.hasClass("has-changes")) {
		    hasChanges = hasChanges + groupdiv.data("has-changes");
		}
		if (multivalue) {
		    structdiv.find(".structset-panel-body").append(groupdiv);
		}
		else {
		    structdiv.append(groupdiv);
		}
	    });
	    /*
	     * If a multivalue struct, expand the outer panel if any
	     * of the inner panels is expanded.
	     */
	    if (multivalue) {
		if ($(structdiv)
		    .find('.pp-param-group-subpanel-collapse.in').length) {
		    $(structdiv).find(".pp-param-structset-subpanel-collapse")
			.addClass("in");
		    $(structdiv)
			.find(".structset-subpanel-collapse-chevron .glyphicon")
			.removeClass("glyphicon-chevron-right")
			.addClass("glyphicon-chevron-down");
		}
	    }
	    
	    // Bubble this up.
	    if (hasChanges) {
		structdiv.addClass("has-changes", hasChanges);
	    }
	    return structdiv;
	}

	function GenerateStructDiv(fieldIndex, copyIndex, bindings)
	{
	    var details     = formFields[fieldIndex];
	    var params      = details.parameters;
	    var ordering    = details.parameterOrder;
	    var multivalue  = details.multiValue;
	    var hasError    = false;
	    var hasChanges  = 0;
	    var fieldname   = details.name
	    var prompt      = (details.description ?
			       details.description : fieldname);
	    var isfirst     = false;

	    if (debug) {
		console.info("GenerateStructDiv",
	                     copyIndex, details, _.size(details.values));
	    }

	    /*
	     * If values is undefined, generate a new set of values
	     * from the field default values.
	     */
	    if (_.size(details.values) == 0) {
		details.values[copyIndex] = initStructInitialValues(details);
		// New copies start out visible.
		details.visible[copyIndex] = true;
		isfirst = true;
	    }
	    //console.info("formFields", formFields);
	    var values = details.values[copyIndex];
	    var sname  = fieldname + "-" + fieldIndex + "-" + copyIndex;

	    var html = structTemplate({
		"fieldid"     : fieldname,
		"index"       : copyIndex,
		"name"        : sname,
		"prompt"      : prompt,
		"multivalue"  : multivalue,
		// Multivalue structs get their help up above.
		"longhelp"    : (!multivalue ? details.longDescription : null),
		"longhelp_id" : "help-" + sname,		
	    });
	    var groupdiv = $(html);

	    /*
	     * Look for a struct level warning/error and append before
	     * doing the fields in the struct. Note that when its a
	     * multivalue struct, we want these errors up a level, see
	     * above
	     */
	    if (bindings && !multivalue &&
		_.has(bindings.bindings, fieldname) &&
		(_.has(bindings.bindings[fieldname], "warnings") ||
		 _.has(bindings.bindings[fieldname], "errors"))) {

		if (_.has(bindings.bindings[fieldname], "errors")) {
		    var errors  = bindings.bindings[fieldname]["errors"];
		    var message = "";

		    for (var i = 0; i < errors.length; ++i) {
			var index = errors[i];
			var text  = bindings.errors[index].message;

			if (message != "") {
			    message += "<br>";
			}
			message += text;

			// Mark the error/warning as being spit out
			bindings.errors[i]["notified"] = true;
		    }
		    groupdiv.addClass('has-error');

		    var html = 
			'<div class="panel panel-danger ' +
			'            col-xs-10 col-xs-offset-1" ' +
			'    style="height: auto;' +
			'           margin-top: 5px; margin-bottom: 5px;' +
			'           padding: 0px;">' +
			' <div class=panel-heading> ' +
			message + '</div></div>';

		    $(groupdiv).find(".panel-body").append(html);
		}
		if (_.has(bindings.bindings[fieldname], "warnings")) {
		    var warnings = bindings.bindings[fieldname]["warnings"];
		    var message  = "";

		    for (var i = 0; i < warnings.length; ++i) {
			var index = warnings[i];
			var text  = bindings.warnings[index].message;

			if (message != "") {
			    message += "<br>";
			}
			message += text;

			// Mark the error/warning as being spit out
			bindings.warnings[i]["notified"] = true;
		    }
		    groupdiv.addClass('has-warning');

		    var html = 
			'<div class="panel panel-warning ' +
			'            col-xs-10 col-xs-offset-1" ' +
			'    style="height: auto;' +
			'           margin-top: 5px; margin-bottom: 5px;' +
			'           padding: 0px;">' +
			' <div class=panel-heading> ' +
			message + '</div></div>';

		    $(groupdiv).find(".panel-body").append(html);
		}
	    }
	    
	    _.each(ordering, function (pname) {
		var details = params[pname];
		var value   = values[pname]
		var name    = pname + "-" + copyIndex;
		var binding = null;

		/*
		 * Need to create a version of the bindings (with errors)
		 * that makes sense for GenerateField(), since the errors
		 * are down a couple of levels.
		 */
		if (bindings &&
		    _.has(bindings, "errors") &&
		    _.has(bindings.bindings, fieldname)) {
		    var tmpb   = bindings["bindings"][fieldname].value;
		    var map    = bindings["bindings"][fieldname].index;
		    var idx    = _.indexOf(map, copyIndex);
		    var errors = bindings["errors"];

		    //console.info("bindings:",
	    	    //             copyIndex, fieldname, pname, map,
		    //             tmpb, bindings);

		    // Copy of the errors, then find the right binding for
		    // the field we are operating on.
		    binding = {
			"bindings" : {},
			"errors"   : errors, 
		    };
		    if (multivalue) {
			binding.bindings[pname] = tmpb[idx].value[pname];
		    }
		    else {
			binding.bindings[pname] = tmpb[pname];
		    }
		    //console.info("bb", binding);
		}
		var div;
		if (details.multiValue) {
		    div = GenerateMultiValueField(value, details,
						  fieldIndex,
						  binding, copyIndex);

		    // Look for a reason to start the panel out uncollapsed.
		    if (div.hasClass("has-error")) {
			hasError = 1;
		    }
		    // Count up number of changes for the caller.
		    if (div.hasClass("has-changes")) {
			hasChanges = hasChanges + div.data("has-changes");
		    }
		}
		else {
		    div = GenerateField(name, details, fieldIndex,
					value, binding, copyIndex);

		    // Look for a reason to start the panel out uncollapsed.
		    if (div.hasClass("has-error") ||
			div.hasClass("has-warning") ||
			div.hasClass("has-changes")) {
			hasError = 1;
		    }
		    // Count up number of changes for the caller.
		    if (div.hasClass("has-changes")) {
			hasChanges++;
		    }
		}
		$(groupdiv).find(".panel-body").append(div);
	    });
	    if (details.visible[copyIndex]) {
		$(groupdiv).find(".pp-param-group-subpanel-collapse")
		    .addClass("in")
	    }
	    // Remember visibility for redraw after errors
	    $(groupdiv).find(".pp-param-group-subpanel-collapse")
		.bind("shown.bs.collapse", function () {
		    var icon = $(this).closest(".panel")
			.find(".subpanel-collapse-chevron .glyphicon");
		    $(icon).removeClass("glyphicon-chevron-right");
		    $(icon).addClass("glyphicon-chevron-down");
		    details.visible[copyIndex] = true;
		})
		.bind("hidden.bs.collapse", function () {
		    var icon = $(this).closest(".panel")
			.find(".subpanel-collapse-chevron .glyphicon");
		    $(icon).removeClass("glyphicon-chevron-down");
		    $(icon).addClass("glyphicon-chevron-right");
		    details.visible[copyIndex] = false;
		});
	    
	    /*
	     * Expand if errors or was previously visible or when adding
	     * the first one.
	     * Note that we have to
	     * do this the long way to avoid jquery behavior; the event
	     * is not fired until the DOM is updated, which causes the
	     * screen to look funny when the group is opened right after
	     * being drawn closed.
	     */
	    if (hasError || details.visible[copyIndex] || isfirst) {
		$(groupdiv).find(".pp-param-group-subpanel-collapse")
		    .addClass("in");
		$(groupdiv).find(".subpanel-collapse-chevron .glyphicon")
		    .removeClass("glyphicon-chevron-right")
		    .addClass("glyphicon-chevron-down");
	    }

	    if (multivalue) {
		/*
		 * Bind the buttons
		 */
		groupdiv.find(".multivalue-struct-button-minus button")
		    .click(function (event) {
			event.preventDefault();
			DeleteStruct(groupdiv, fieldIndex, copyIndex);
		    });
		groupdiv.find(".multivalue-struct-button-plus button")
		    .click(function (event) {
			event.preventDefault();
			DuplicateStruct(groupdiv, fieldIndex, copyIndex);
		    });
		groupdiv.find(".multivalue-struct-button-down button")
		    .click(function (event) {
			event.preventDefault();
			MoveStruct("down", groupdiv, fieldIndex, copyIndex);
		    });
		groupdiv.find(".multivalue-struct-button-up button")
		    .click(function (event) {
			event.preventDefault();
			MoveStruct("up", groupdiv, fieldIndex, copyIndex);
		    });

		// Disable plus button if reached maximum number.
		if (details.max && 
		    _.keys(details.values).length >= details.max) {
		    groupdiv.find(".multivalue-struct-button-plus")
			.attr('title', 'Maximum values is ' + details.max)
			.tooltip('setContent');
		    // Disable the button, but not in a gross way.
		    groupdiv.find(".multivalue-struct-button-plus button")
			.css("pointer-events", "none");
		}
	    
		/*
		 * User is allowed to delete structs as long as the number
		 * of fields is greater then the min. Change the tooltip
		 * and disable the button.
		 */
		if (details.min && 
		    _.keys(details.values).length <= details.min) {
		    groupdiv.find(".multivalue-struct-button-minus")
			.attr('title', 'Minimum values is ' + details.min)
			.tooltip('setContent');
		    // Disable the button, but not in a gross way.
		    groupdiv.find(".multivalue-struct-button-minus button")
			.css("pointer-events", "none");
		}

		// Disable up button on first value.
		if (copyIndex == _.first(_.keys(details.values))) {
		    groupdiv.find(".multivalue-struct-button-up")
			.css("pointer-events", "none");
		}
		// Disable down button on last value.
		if (copyIndex == _.last(_.keys(details.values))) {
		    groupdiv.find(".multivalue-struct-button-down")
			.css("pointer-events", "none");
		}
	    }
	    // Bubble these up.
	    if (hasChanges) {
		$(groupdiv).addClass("has-changes");
		$(groupdiv).data("has-changes", hasChanges);
	    }
	    if (hasError) {
		$(groupdiv).addClass("has-error");
	    }
	    // Init the tooltips
	    groupdiv.find('[data-toggle="tooltip"]').tooltip();
	    
	    return groupdiv;
	}

	/*
	 * Update buttons and margins on a multivalue structure.
	 */
	function updateStructButtonsMargins(structset)
	{
	    if (structset.length == 1) {
		var struct = structset[i];

		$(struct).find(".multivalue-struct-button-down")
		    .css("pointer-events", "none");
		$(struct).find(".multivalue-struct-button-up")
		    .css("pointer-events", "none");
		return;
	    }
	    for (var i = 0; i < structset.length; i++) {
		var struct = structset[i];

		if (i == 0) {
		    // No up button on first entry.
		    $(struct).find(".multivalue-struct-button-down")
			.css("pointer-events", "auto");
		    $(struct).find(".multivalue-struct-button-up")
			.css("pointer-events", "none");
		}
		else if (i == structset.length - 1) {
		    // No down entry on last entry.
		    $(struct).find(".multivalue-struct-button-down")
			.css("pointer-events", "none");
		    $(struct).find(".multivalue-struct-button-up")
			.css("pointer-events", "auto");
		}
		else {
		    // Both buttons enabled on middle entries;
		    $(struct).find(".multivalue-struct-button-down")
			.css("pointer-events", "auto");
		    $(struct).find(".multivalue-struct-button-up")
			.css("pointer-events", "auto");
		}
	    }
	}

	/*
	 * Duplicate a structure. 
	 */
	function DuplicateStruct(formdiv, fieldIndex, copyIndex)
	{
	    var details     = formFields[fieldIndex];
	    var params      = details.parameters;
	    var ordering    = details.parameterOrder;
	    var newIndex    = 0;

	    if (debug) {
		console.info("DuplicateStruct", copyIndex, details.values);
	    }

	    // Make up a new name and add to the values list, for form regen.
	    // Note that since we allow delete in the middle, we have to
	    // look at the names to make sure we are making up a unique one.
	    while (1) {
		var name = "C-" + newIndex;
		if (!_.has(details.values, name)) {
		    newIndex = name;
		    break;
		}
		newIndex++;
	    }

	    // Need to insert the new entry into the dict in the
	    // right position.
	    var newvalues = {};
	    var curkeys   = _.keys(details.values);
	    var oldidx    = _.indexOf(curkeys, copyIndex);
	    var newidx    = oldidx + 1;
	    
	    // This adds the element in the correct position.
	    curkeys.splice(newidx, 0, newIndex);
	    
	    // Generate new values object with new key ordering
	    _.each(curkeys, function(key) {
		if (key == newIndex) {
		    // Generate new set of values from the field default values.
		    newvalues[key] = initStructInitialValues(details);
		}
		else {
		    newvalues[key] = details.values[key];
		}
	    });
	    details.values = newvalues;
	    
	    // New copies start out visible.
	    details.visible[newIndex] = true;

	    // Generate a new div.
	    var groupdiv = GenerateStructDiv(fieldIndex, newIndex, null);

	    // If number of values is now greater then min, enable the
	    // minus buttons and change the tool tip.
	    if (details.min != null && _.size(details.values) > details.min) {
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-minus")
		    .attr('title', 'Delete this copy')
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-minus button")
		    .css("pointer-events", "auto");
	    }
	    // If number more then max, need to disable the plus signs
	    // change the tooltip message.
	    if (details.max && _.size(details.values) >= details.max) {
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-plus")
		    .attr('title', 'Maximum value is ' + details.max)
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		// Disable the plus buttons
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-plus button")
		    .css("pointer-events", "none");
	    }
	    /*
	     * Add this new one after the current one.
	     */
	    formdiv.after(groupdiv);

	    // Reset up/down buttons as needed.
	    var structset = formdiv.closest(".structset").find(".struct-row");
	    updateStructButtonsMargins(structset);

	    // Set focus to first input
	    groupdiv.find("input").first().focus();

	    Modified();
	}
	
	/*
	 * Delete a struct copy.
	 */
	function DeleteStruct(formdiv, fieldIndex, copyIndex)
	{
	    var details   = formFields[fieldIndex];

	    // Remove from the list of values (copies) array.
	    delete details.values[copyIndex];

	    // No values left? Need to create the empty version and return.
	    if (_.size(details.values) == 0) {
		var html = GenerateEmptyStruct(fieldIndex, details);
		var groupdiv = $(html);

		groupdiv.find(".multivalue-struct-button-plus button")
		    .click(function(event) {
			event.preventDefault();
			var newdiv = GenerateStructDiv(fieldIndex, 0, null);
			// We leave tooltips behind, seems like a bootstrap bug.
			groupdiv.find('[data-toggle="tooltip"]')
			    .tooltip("hide");
			groupdiv.after(newdiv);
			groupdiv.remove();
			// Set focus to first input
			newdiv.find("input").first().focus();
			Modified();
		    });
		// We leave tooltips behind, seems like a bootstrap bug.
		formdiv.find('[data-toggle="tooltip"]').tooltip("hide");
		formdiv.after(groupdiv);
		formdiv.remove();
		Modified();
		return;
	    }

	    // If number of values is now <= min, then turn off
	    // all of the minus signs.
	    if (details.min != null && _.size(details.values) <= details.min) {
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-minus")
		    .attr('title', 'Minimum value is ' + details.min)
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-minus button")
		    .css("pointer-events", "none");
	    }
	    // If below max (and we should be if we get here!), change
	    // the plus sign tooltips back to the right message.
	    if (details.max && _.size(details.values) < details.max) {
		formdiv.closest("structset")
		    .find(".multivalue-struct-button-plus")
		    .attr('title', 'Add another copy')
		    .tooltip('fixTitle')
		    .tooltip('setContent');
		// Reenable the plus buttons
		formdiv.closest(".structset")
		    .find(".multivalue-struct-button-plus button")
		    .css("pointer-events", "auto");
	    }
	    var structset = formdiv.closest(".structset");
	    
	    // Delete leaves tooltip behind, seems like a bootstrap bug.
	    formdiv.find('[data-toggle="tooltip"]').tooltip("hide");
	    formdiv.remove();

	    // Reset up/down buttons as needed.
	    updateStructButtonsMargins(structset.find(".struct-row"));

	    Modified();
	}

	/*
	 * Move a struct up or down.
	 */
	function MoveStruct(dir, formdiv, fieldIndex, structIndex)
	{
	    var details   = formFields[fieldIndex];

	    //console.info("MoveStruct",
	    //             dir, fieldIndex, structIndex, details.values);

	    /*
	     * Need to regenerate the values object, moving the keys
	     * into the proper order. Note that key ordering is actually
	     * not guaranteed, but every browser does it.
	     */
	    var newvalues = {};
	    var curkeys   = _.keys(details.values);
	    var oldidx    = _.indexOf(curkeys, structIndex);
	    var newidx    = (dir == "up" ? oldidx - 1 : oldidx + 1);

	    // This moves the element in the array.
	    curkeys.splice(newidx, 0, curkeys.splice(oldidx, 1)[0]);

	    // Generate new values object with new key ordering
	    _.each(curkeys, function(key) {
		newvalues[key] = details.values[key];
	    });
	    //console.info(newvalues);
	    details.values = newvalues;

	    if (dir == "up") {
		formdiv.prev().insertAfter(formdiv);
	    }
	    else {
		formdiv.next().insertBefore(formdiv);
	    }

	    // Reset up/down buttons as needed.
	    var structset = formdiv.closest(".structset").find(".struct-row");
	    updateStructButtonsMargins(structset);

	    // Kill the focus on the button which might not be enabled
	    // any longer.
	    $(':focus').blur();
	    
	    Modified();
	}

	function GenerateForm(bindings)
	{
	    var html    = "";
	    var hasHelp = false;
	    var groupsWithErrors = new Array();
	    var groupErrorOpenerScript = "";
	    var numParameterErrors = 0;
	    var numParameterWarnings = 0;
	    var fixedValuesChanges = 0;

	    /*
	     * Empty. Create one for parameter set warnings. We do this
	     * only on the first generation of the form, once submitted
	     * we do not want to show these warnings. See below, we clear
	     * the bindings and warnings in the submit function.
	     */
	    if (rerun_bindings) {
		rerun_warnings = new Array();
	    }
	    
	    // Compute the general warning and error message text now.
	    if (bindings &&
		(_.has(bindings, "errors") || _.has(bindings, "warnings"))) {
		if (_.has(bindings, "errors")) {
		    numParameterErrors = _.size(bindings.errors);
		}
		if (_.has(bindings, "warnings")) {
		    numParameterWarnings = _.size(bindings.warnings);
		}
	    }
	    $('#ppmodal-body').empty();
	    var root = $(formString);
	    $('#ppmodal-body').append(root)
	    
	    // Process each field/group.
	    _.each(formFields, function(def, fieldIndex) {
		if (def.type == "struct") {
		    var structdiv = GenerateStruct(fieldIndex, bindings);

		    // Look for changes that need to be declared below.
		    if ($(structdiv).hasClass("has-changes")) {
			fixedValuesChanges +=
			    $(groupdiv).data("has-changes");
		    };
		    $('#pp-form-body').append(structdiv);
		    
		    // Long form help, see below.
		    if (def.hashelp) {
			hasHelp = true;
		    }
		}
		else if (def.isgroup) {
		    // Generate all fields in the group.
		    var groupdiv = GenerateGroup(fieldIndex, bindings);

		    // Look for changes that need to be declared below.
		    if ($(groupdiv).hasClass("has-changes")) {
			fixedValuesChanges +=
			    $(groupdiv).data("has-changes");
		    }
		    $('#pp-form-body').append(groupdiv);

		    // Long form help, see below.
		    if (def.hashelp) {
			hasHelp = true;
		    }
		}
		else {
		    var details = def;
		    var set;

		    // Long form help, see below.
		    if (details.hashelp) {
			hasHelp = true;
		    }
		    if (details.multiValue) {
			set = GenerateMultiValueField(details.values,
						      details, fieldIndex,
						      bindings, null);
		    }
		    else {
			set = GenerateField(details.name, details,
					    fieldIndex,
					    details.values[details.name],
					    bindings, null);
		    }
		    // Look for changes that need to be declared below.
		    if ($(set).hasClass("has-changes")) {
			fixedValuesChanges +=
			    $(set).data("has-changes");
		    }
		    $('#pp-form-body').append(set);
		}
	    });
	    
	    // Setup the help-all toggle, if there were help items.
	    if (hasHelp) {
		$('#ppmodal-body').prepend(helpPanelToggleString);
	    }

	    // Init the popovers.
	    $('#ppmodal-body').find('[data-toggle="popover"]').popover();
	    // Init the tooltips
	    $('#ppmodal-body').find('[data-toggle="tooltip"]').tooltip();

	    // Tell caller when user changes anything.
	    $('#pp-form-body input, #pp-form-body select').change(function() {
		Modified();
	    });

	    // Show warnings, errors, changes, etc.
	    var addMessage = function (style, message) {
		var ht =
		    '<div class="row">' +
		    ' <div class="col-sm-12">' +
		    '  <div class="panel panel-' + style +'" ' +
		    '       style="margin-bottom: 10px;">' +
		    '   <div class="panel-heading">' + message +
		    '</div></div></div></div>';
		root.prepend(ht);
	    };

	    if (fixedValuesChanges > 0) {
		var ht = "" + fixedValuesChanges + ' item ';
		if (fixedValuesChanges > 1)
		    ht += 'values have';
		else
		    ht += 'value has';
		ht +=
		    ' been changed' +
		    ' in response to these bad parameter values, because' +
		    " this profile's geni-lib script suggested they would" +
		    ' help.  Please check them.';
		addMessage("success", ht);
	    }
	    if (numParameterWarnings > 0) {
		var ht = "";

		if (numParameterWarnings > 1) {
		    ht = '<b>There were ' + numParameterWarnings +
			' Parameter Warnings</b>.  Please check the warning' +
			' messages near each affected parameter; you will' +
			' <b>not</b> be notified about subsequent warnings.';
		}
		else if (numParameterWarnings > 0) {
		    ht = '<b>There was 1 Parameter Warning</b>.  Please check' +
			' the warning message near the affected parameter; ' +
			' you will <b>not</b> be notified about subsequent ' +
			' warnings.';
		}
		/*
		 * Ick, if the user messed up the arguments to the
		 * warning in the script, it might not show up alongside
		 * the parameter, and the instantiator will be
		 * confused. So dump any "unconsumed" warnings with this
		 * message at the top.
		 */
		_.each(bindings.warnings, function (warning) {
		    if (!_.has(warning, "notified")) {
			ht += "<br><b>Oops, warning not associated with a " +
			    "parameter:</b> " + warning.message;
		    }
		});
		addMessage("warning", ht);
	    }
	    if (numParameterErrors > 0) {
		var ht = "";

		if (numParameterErrors > 1) {
		    ht += '<b>There were ' + numParameterErrors +
			' Parameter Errors</b>.  Please check the error' +
			' messages near each affected parameter and fix the' +
			' errors.';
		}
		else if (numParameterErrors > 0) {
		    ht += '<b>There was 1 Parameter Error</b>.  Please check' +
			' the error message near the affected parameter and' +
			' fix it.';
		}
		/*
		 * Ick, if the user messed up the arguments to the
		 * error in the script, it might not show up alongside
		 * the parameter, and the instantiator will be
		 * confused. So dump any "unconsumed" errors with this
		 * message at the top.
		 */
		_.each(bindings.errors, function (error) {
		    if (!_.has(error, "notified")) {
			ht += "<br><b>Oops, error not associated with a " +
			    "parameter:</b> " + error.message;
		    }
		});
		addMessage("error", ht);
	    }
	    if (rerun_bindings) {
		/*
		 * When applying a parameter set, watch for any parms in the
		 * set that are not in this (version of) the profile. We want
		 * to warn users about that. We do not warn about parameters
		 * in the profile that are *not* in the rerun set, since there
		 * will always be valid defaults for those.
		 */
		_.each(rerun_bindings, function (val, name) {
		    var messages = [];
		    
		    // Bindings reference a param not in the paramdefs
		    if (!_.has(paramdefs, name)) {
			console.info("binding not in params", name, val);

			messages.push("The parameter set has a binding for '" +
				      name + "' but that is not a parameter " +
				      "in the profile.");
		    }
		    if (messages.length) {
			addMessage("warning", messages.join("<br>"));
		    }
		});

		if (_.size(rerun_warnings)) {
		    var len = _.size(rerun_warnings);
		    var ht  = "";

		    if (len > 1) {
			ht += '<b>There were ' + len + 
			    ' Parameter Set warnings</b>. ' +
			    'Please check the warnings below.';
		    }
		    else {
			ht += '<b>There was 1 Parameter Set warning</b>. ' +
			    'Please check the warning ' +
			    'message near the affected parameter.';
		    }
		    addMessage("warning", ht);
		}
	    }
	    
	    imagePicker = new jacksmod.ImagePicker();
	    $('#image-picker-body').html(imagePickerString);
	    $('#imagepicker-modal .modal-body > div').append(imagePicker.el);
	    
	    //
	    // Handle the toggle-all help panels link.  Bootstrap
	    // doesn't give us a simple way to collapse multiple panels
	    // unless they're in an accordion... so do it the
	    // old-fashioned way, manual modal state in a hidden div.
	    //
	    $('#pp-param-help-panel-toggle-link').on('click',function() {
		//event.preventDefault();
		var state = $('#pp-param-help-panel-toggle-state').html();
		var list = document.
		    getElementsByClassName("pp-param-help-panel");
		for (var i = 0; i < list.length; ++i) {
		    if (state == 'opened') {
			$(list[i]).collapse('hide');
		    }
		    else {
			$(list[i]).collapse('show');
		    }
		}
		if (state == 'opened') {
		    $('#pp-param-help-panel-toggle-state')
			.html('closed');
		    $('#pp-param-help-panel-toggle-link-span')
			.html('&nbsp;&nbsp; Show All Parameter Help');
		    $('#pp-param-help-panel-toggle-glyph-span')
			.removeClass('glyphicon-minus-sign');
		    $('#pp-param-help-panel-toggle-glyph-span')
			.addClass('glyphicon-plus-sign');
		}
		else {
		    $('#pp-param-help-panel-toggle-state')
			.html('opened');
		    $('#pp-param-help-panel-toggle-link-span').
			html('&nbsp;&nbsp; Hide All Parameter Help');
		    $('#pp-param-help-panel-toggle-glyph-span')
			.removeClass('glyphicon-plus-sign');
		    $('#pp-param-help-panel-toggle-glyph-span')
			.addClass('glyphicon-minus-sign');
		}
		// Now open all the param group panels, in case they have help:
		list = $('#ppmodal-body')
		    .find(".pp-param-group-subpanel-collapse");
		for (var i = 0; i < list.length; ++i) {
		    $(list[i]).collapse('show');
		}
	    });
	}

	/*
	 * Initialize the parameter buttons.
	 */
	function InitializePPButtons()
	{
	    // The whole group is hidden cause the template is shared with
	    // the old wizard.
	    $('#ppform-buttons').removeClass("hidden");	    

	    $('#ppform-buttons [data-toggle="popover"]')
		.popover({
		    trigger: 'hover',
		    delay: { "show": 300, "hide": 100 },
		    placement: 'left',
		    container: 'body',
		});

	    /*
	     * save paramset bindings button. We need to convert to
	     * XML first since the paramsets stuff operates from the
	     * rspec. We only need to convert if the params are
	     * unmodified.
	     */
	    $('#ppform-buttons .p-save')
		.click(function (event) {
		    var callback = function (success) {
			if (success) {
			    paramsets.InitSaveParameterSet('#save_paramset_div',
							   uuid, RSPEC);
			}
		    };
		    if (ppchanged) {
			HandleSubmit(callback);
		    }
		    else {
			callback(true);
		    }
		});

	    // Only the "defaults" button starts out visible and active
	    $('#ppform-buttons .p-defaults')
		.click(function (event) {
		    event.preventDefault();
		    // Need to kill the rerun bindings when user picks defaults.
		    ClearAlert();
		    LoadBindings(null);
		});

	    // We can bind this function, the button will be hidden as needed.
	    $('#ppform-buttons .p-last')
		.click(function (event) {
		    event.preventDefault();
		    // Hide the popover
		    $(this).popover("hide");
		    LoadPreviousBindings();
		});
	    
	    $('#ppform-buttons .p-resources')
		.click(function (event) {
		    event.preventDefault();
		    resinfo_window =
			window.open("resinfo.php?embedded=true",
				    "Resource Availability",
				    "width=1200,height=800");
		});
	    if (window.ISPOWDER) {
		$('#ppform-buttons .p-powdermap')
		    .removeClass("hidden")
		    .click(function (event) {
			event.preventDefault();
			resinfo_window =
			    window.open("powder-map.php?embedded=true" +
					"&nomobile=1",
					"Radio Map",
					"width=1200,height=800");
		    });
	    }
	}

	/*
	 * Load bindings from a previous experiment.
	 */
	function LoadPreviousBindings(instance_uuid)
	{
	    ClearAlert();
	    
	    var callback = function(json) {
		console.info("LoadPreviousBindings", json);
		if (json.code) {
		    sup.SpitOops("oops", json.value);
		    setStepsMotion(true);
		    return;
		}
		LoadBindings(json.value.bindings);
		if (json.value.version_uuid != uuid ||
		    (fromrepo && json.value.repohash != window.PROFILE_REFHASH)) {
		    InstanceWarning(json.value, instance_uuid);
		}
		setStepsMotion(true);
	    };
	    var args = {
		"profile" : profile
	    };
	    if (instance_uuid) {
		args["rerun_uuid"] = instance_uuid;
	    }
	    setStepsMotion(false);
	    var xmlthing = sup.CallServerMethod(null, "instantiate",
						"GetPreviousBindings", args);
	    xmlthing.done(callback);
	}

	/*
	 * Update bindings.
	 */
	function LoadBindings(bindings)
	{
	    rerun_bindings = bindings;
	    InitializeForm(paramdefs);
	    GenerateForm(null);
	    // Always force a rerun of the script, do not worry about
	    // a new set of bindings that are identical.
	    Modified();
	}

	/*
	 * Alert user when trying to apply a bound paramset to the wrong place
	 */
	function ParamsetWarning(set)
	{
	    var url = "instantiate.php?profile=" + set.version_uuid +
		"&rerun_paramset=" + set.uuid;
	    var link = "<a href='" + url + "'>here</a>";
	    
	    var warning = "The parameter set you applied is bound to a different ";
	    if (set.version_uuid != uuid) {
		warning += "version of this profile. ";
	    }
	    else {
		warning += "commit of the repository for this profile. ";
	    }
	    warning += "This is typically okay, but might not be what you intended. " +
		"Click " + link + " to instantiate the correct version of the profile. ";
		
	    $('#ppalert').html("WARNING: " + warning);
	    $('#ppalert').removeClass("hidden");
	}
	/*
	 * Ditto for applying instance bindings to wrong version.
	 */
	function InstanceWarning(set, instance_uuid)
	{
	    var url = "instantiate.php?profile=" + set.version_uuid +
		"&rerun_instance=" + instance_uuid;
	    var link = "<a href='" + url + "'>here</a>";
	    
	    var warning = "The bindings applied from the instance are for a different ";
	    if (set.version_uuid != uuid) {
		warning += "version of this profile. ";
	    }
	    else {
		warning += "commit of the repository for this profile. ";
	    }
	    warning +=
		"This is typically okay, but might not be what you intended. " +
		"Click " + link + " to instantiate the correct version of the profile. ";
		
	    $('#ppalert').html("WARNING: " + warning);
	    $('#ppalert').removeClass("hidden");
	}
	function ClearAlert()
	{
	    $('#ppalert').addClass("hidden");
	}

	/*
	 * Setup the parameter buttons for this specific profile.
	 */
	function SetupPPButtons(hasactivity, paramsets, recents)
	{
	    // If the use has previous activity on this profile, we can
	    // show the last and activity buttons.
	    if (hasactivity) {
		// History button opens up new window.
		$('#ppform-buttons .p-history')
		    .attr("href", "profile-activity.php?uuid=" + uuid)
		$('#ppform-buttons .p-history').parent()
		    .removeClass("hidden");

		$('#ppform-buttons .p-last').parent()
		    .removeClass("hidden");
	    }
	    //
	    var addpset = function (menu, set) {
		var item = $("<li>" +
			     " <a href='#'>" + set.name  + "</a>" +
			     "</li>");
		// Add a popover to show the description.
		$(item).popover({
		    html:     false,
		    content:  set.description,
		    trigger:  'hover',
		    placement:'left',
		    container:'body',
		});
		// Handler to regenerate the form.
		$(item).find("a").click(function (event) {
		    event.preventDefault();
		    ClearAlert();
		    LoadBindings(set.bindings);
		    /*
		     * Warn user if the paramset is bound and being applied to
		     * a different version (of the repo).
		     */
		    if (set.version_uuid) {
			if (set.version_uuid != uuid ||
			    (fromrepo && set.repohash !=
			     window.PROFILE_REFHASH)) {
			    ParamsetWarning(set);
			}
		    }
		});
		$(menu).append(item);
	    };
	    // Create dropdown menu for the paramsets.
	    if (paramsets) {
		if (_.size(paramsets.owner)) {
		    _.each(paramsets.owner, function(set, index) {
			addpset($('#ppform-buttons .p-choose ul'), set);
		    });
		    $('#ppform-buttons .p-choose').removeClass("hidden");
		}
		if (_.size(paramsets.global)) {
		    _.each(paramsets.global, function(set, index) {
			addpset($('#ppform-buttons .p-choose-public ul'), set);
		    });
		    $('#ppform-buttons .p-choose-public').removeClass("hidden");
		}
	    }
	    // Create dropdown menu for the 10 most recent
	    if (recents) {
		_.each(recents, function(info, index) {
		    var iname  = info["instance_name"];
		    var pname  = info["profile_name"];
		    var item = $("<li>" +
				 " <a href='#'>" + iname + "</a>" +
				 "</li>");

		    // Handler to regenerate the form.
		    $(item).find("a").click(function (event) {
			event.preventDefault();
			LoadPreviousBindings(info["instance_uuid"]);
		    });
		    
		    $('#ppform-buttons .p-recent ul').append(item);
		});
		$('#ppform-buttons .p-recent')
		    .removeClass("hidden");
	    }
	}
	    
        function HandleSubmit(callback, jacksGraphCallback)
	{
	    console.info("HandleSubmit", ppchanged);
	    
	    if (!ppchanged) {
		callback(true);
		ShowThumbnail(RSPEC, jacksGraphCallback);
		return;
	    }
	    // Submit with check only at first, since this will return
	    // very fast, so no need to throw up a waitwait.
	    SubmitForm(1, callback, jacksGraphCallback);
	}

	//
	// Configuration is done, we have the new rspec.
	//
	function ConfigureDone()
	{
	    // warnings are fatal again if they go backwards
	    warningsfatal = 1;

	    configuredone_callback(RSPEC);
	}

	//
	// Submit the form. If no errors, we get back the rspec. Throw that
	// up in a Jack editor window. 
	//
        function SubmitForm(checkonly, steps_callback, jacksGraphCallback)
	{
	    console.info("SubmitForm", checkonly, steps_callback);
	    var nosubmit = 0;
	    
	    // Current form contents as formfields array.
	    var bindings    = {};
	
 	    var callback = function(json) {
		console.info("submit results", json);
		
		if (!checkonly) {
		    sup.HideModal("#waitwait-modal");
		}
		if (json.code) {
		    if (checkonly && json.code == 2) {
			// Regenerate page with errors from the PHP fast
			// type-checking code.
			GenerateForm(json.value);
		    }
		    else {
			var newjsonval = null;
			var ex;

			//
			// If geni-lib scripts error out, they can
			// return a JSON list of errors and warnings.
			// So, if the json.value return bits can be
			// parsed by JSON.parse, assume they have
			// meaning.
			//
			try {
			    newjsonval = JSON.parse(json.value);
			}
			catch (ex) {
			    newjsonval = null;
			}

			if (newjsonval != null) {
			    // Disable first-time warnings; too complicated
			    // to track which values caused warnings and have
			    // been changed...
			    warningsfatal = 0;

			    console.info(newjsonval);

			    // These *are* the droids we are looking for...
			    GenerateForm(newjsonval);
			}
			else {
			    sup.SpitOops("oops", json.value);
			}
		    }
		    if (steps_callback) {
			steps_callback(false);
		    }
		    return;
		}
		if (checkonly) {
		    // Form checked out okay, submit again to generate rspec.
		    SubmitForm(0, steps_callback, jacksGraphCallback);
		}
		else {
		    RSPEC = json.value.rspec;
		    ppchanged = false;
		    ConfigureDone();
		    if (resinfo_window) {
			resinfo_window.close();
			resinfo_window = null;
		    }
		    // Must be after the callback, so that any changes to
		    // the aggregate selector is reflected in the final tab
		    if (steps_callback) {
			steps_callback(true);
		    }
		    if (jacksGraphCallback) {
			ShowThumbnail(RSPEC, jacksGraphCallback);
		    }
		}
	    }
	    /*
	     * Convert form data into formfields array, like all our
	     * form handler pages expect. The wrinkle is that fields
	     * declared as multivalue are returned as a list, and groups
	     * that are declared as multivalue are returned as a list
	     * of objects. Otherwise, just a plain formfields array.
	     */
	    $('#pp-form-body').find(".format-me").each(function () {
		var fieldId   = $(this).data("fieldid");
		var fieldname = $(this).data("fieldname");
		var name      = $(this).attr("name");
		var value     = $(this).val();
		var tagname   = $(this).prop('tagName');

		//
		// Add back any unchecked inputs with "" values, since
		// serializeArray() does not include un"successful" elements
		// (see https://api.jquery.com/serializeArray/ and
		// https://www.w3.org/TR/html401/interact/forms.html#h-17.13.2)
		//
		//console.info(this, $(this).attr("type"));
		if (tagname == "INPUT" &&
		    $(this).attr("type") == "checkbox") {
		    if ($(this).is(":checked")) {
			value = true;
		    }
		    else {
			value = false;
		    }
		}
		var field = formFields[fieldId];

		//console.info(name, fieldname, fieldId, value, field);
		
		if (field.type == "struct") {
		    var details    = field;
		    var pdetails   = field.parameters[fieldname];
		    var structname = details.name;
		    var formgroup  = $(this).closest(".struct-row");
		    var copyindex  = $(formgroup).data("copyindex");
		    var formdata   = {
			// Need the name for the error array, which is
			// a flat list right now. Maybe change later.
			"name"  : name,
			"value" : value,
		    };
		    //console.info("struct", details,
		    //             pdetails, structname, copyindex);

		    // List of dicts for multivalue, dict for non-multivalue
		    if (details.multiValue) {
			if (!_.has(bindings, structname)) {
			    bindings[structname] =
				{"value" : [], "index" : []};
			}
			/*
			 * ICK. 
			 */
			if (_.indexOf(bindings[structname]["index"],
				      copyindex) < 0) {
			    bindings[structname]["index"].push(copyindex);
			    bindings[structname]["value"].push({"value" : {}});
			}
			var idx =
			    _.indexOf(bindings[structname].index, copyindex);
			var curvalues =
			    bindings[structname].value[idx].value;
			
			if (pdetails.multiValue) {
			    if (!_.has(curvalues, fieldname)) {
				curvalues[fieldname] = {"value" : []};
			    }
			    curvalues[fieldname].value.push(formdata);
			    // Update the the master with the new value
			    details.values[copyindex][fieldname][name] = value;
			}
			else {
			    curvalues[fieldname] = formdata;
			    // Update the the master with the new value
			    details.values[copyindex][fieldname] = value;
			}
		    }
		    else {
			if (!_.has(bindings, structname)) {
			    bindings[structname] = {"value": {}};
			}
			if (pdetails.multiValue) {
			    if (!_.has(bindings[structname].value, fieldname)) {
				bindings[structname].value[fieldname] =
				    {"value" : []};
			    }
			    bindings[structname].value[fieldname]
				["value"].push(formdata);
			    // Update the the master with the new value
			    details.values[copyindex][fieldname][name] = value;
			}
			else {
			    bindings[structname].value[fieldname] = formdata;
			    // Update the the master with the new value
			    details.values[copyindex][fieldname] = value;
			}
		    }
		}
		else if (field.isgroup) {
		    var groupId   = field.groupId;
		    var group     = formGroups[field.groupId];
		    var details   = group.fields[fieldname];

		    // Update the the master with the new value, so that
		    // we can regenerate the form with errors later.
		    details.values[name] = value;

		    if (details.multiValue) {
			// We use a list for a multivalue field. 
			if (!_.has(bindings, fieldname)) {
			    bindings[fieldname] = {"value" : []};
			}
			bindings[fieldname].value.push({
			    // Need the name for the error array, which is
			    // a flat list right now. Maybe change later.
			    "name"  : name,
			    "value" : value,
			});
		    }
		    else {
			bindings[fieldname] = {
			    // Need the name for the error array, which is
			    // a flat list right now. Maybe change later.
			    "name"  : name,
			    "value" : value,
			};
		    }
		}
		else {
		    var details = field;

		    if (details.multiValue) {
			// We use a list for a multivalue field. 
			if (!_.has(bindings, fieldname)) {
			    bindings[fieldname] = {"value" : []};
			}
			bindings[fieldname].value.push({
			    // Need the name for the error array, which is
			    // a flat list right now. Maybe change later.
			    "name"  : name,
			    "value" : value,
			});
		    }
		    else {
			bindings[fieldname] = {
			    // Need the name for the error array, which is
			    // a flat list right now. Maybe change later.
			    "name"  : name,
			    "value" : value,
			};
		    }
		    // Update the the master with the new value, so that
		    // we can regenerate the form with errors later.
		    field.values[name] = value;
		}
	    });
	    /*
	     * Hmm, one problem with traversing the form contents, is that
	     * we miss multivalue fields that are allowed to go to zero.
	     * When that happens, we need to send a zero length array in
	     * the bindings to tell geni-lib that it went to zero. 
	     */
	    _.each(formFields, function (details, idx) {
		if (details.multiValue) {
		    if (!_.has(bindings, details.name)) {
			bindings[details.name] = {"value" : "", "index" : []};
		    }
		}
	    });
	    
	    console.info("formFields", formFields);
	    console.info("bindings", bindings);
	    if (0) {
		return;
	    }
	    // On first submit we kill the rerun bindings and warnings.
	    rerun_bindings = rerun_warnings = null;
	    // This clears any errors before new submit.
	    // Yep, total redraw of the form, but so what.
	    GenerateForm(null);

 	    if (nosubmit) {
		return;
	    }
	    var formfields = {
		"bindings" : bindings
	    }

	    //
	    // XXX: Look for paramdefs/script in the main form and pass along.
	    // There is no need to pass the script along, we should get it from
	    // the profile (or repo) on the server side. The paramdefs is generated
	    // on the fly from the script, so we have to pass that along (with
	    // repo based profiles, we have to go find the exact script each time).
	    //
	    if ($('#paramdefs').val() !== undefined) {
		formfields["paramdefs"] = $('#paramdefs').val();
		formfields["script"]    = $('#script_textarea').val();
	    }
	    //console.info("formfields", formfields);
	    
	    // Not in checkform mode, this will take time.
	    if (!checkonly) {
		sup.ShowModal("#waitwait-modal");
	    }
	    var args = {
		"formfields"    : formfields,
		"profile"       : profile,
		"checkonly"     : checkonly,
		"newparams"     : 1,
		"warningsfatal" : warningsfatal,
	    };
	    if (window.TARGET_REPOREF !== undefined) {
		args["refspec"] = window.TARGET_REPOREF;
	    }
	    var xmlthing =
		sup.CallServerMethod(null, "manage_profile",
				     "BindParameters", args);
	    xmlthing.done(callback);
	}

	function countNodes()
	{
	    //console.info("countNodes");
	    var xmlDoc = $.parseXML(RSPEC);
	    var count  = $(xmlDoc).find("node").length;
	    //console.info(count);
	    return count;
	}

	function StartPP(args) {
	    registered     = args.registered;
	    multisite      = args.multisite;
	    ppdivname      = args.ppdivname;
	    amlist         = args.amlist;
	    prunetypes     = args.prunetypes;
	    fromrepo       = args.fromrepo;
	    
	    if (formFields.length && uuid == args.uuid) {
		GenerateForm(null);
		return;
	    }
	    configuredone_callback = args.config_callback;
	    modified_callback = args.modified_callback;
	    setStepsMotion = args.setStepsMotion;
	    
	    /*
	     * Need to ask for the profile parameter form fragment and
	     * the initial values.
	     */
	    var callback = function(json) {
		console.info("GetParameters", json);
		if (json.code) {
		    sup.SpitOops("oops", json.value);
		}
		uuid      = args.uuid;
		profile   = args.profile;
		paramdefs = json.value.paramdefs;
		ppchanged = true;

		// Insert into the provided container.
		$('#' + ppdivname).html(ppmodalString);
		// Init the parameter buttons.
		InitializePPButtons();
		// Setup the parameter buttons for this profile.
		SetupPPButtons(json.value.hasactivity,
			       json.value.paramsets, json.value.recents);
		
		if (args.rerun_instance !== undefined ||
		    args.rerun_paramset !== undefined) {
		    rerun_bindings = json.value.rerun_bindings;
		}
		else {
		    rerun_bindings = null;
		}
		InitializeForm(paramdefs);
		GenerateForm(null);
		setStepsMotion(true);

		if (args.rspec) {
		    RSPEC = args.rspec;
		    ConfigureDone();
		    //ShowEditor();
		    ShowThumbnail(RSPEC, args.jacksGraphCallback);
		}
		if (! $('#pp-wizard-ready').length) {
		    $('#' + ppdivname).append("<div class='hidden' " +
					      " id='pp-wizard-ready'></div>");
		}
	    }
	    setStepsMotion(false);
	    var blob = {"profile" : args.profile};
	    if (args.rerun_instance !== undefined) {
		blob["rerun_instance"] = args.rerun_instance;
	    }
	    else if (args.rerun_paramset !== undefined) {
		blob["rerun_paramset"] = args.rerun_paramset;
	    }
	    //
	    // XXX: Look for paramdefs/script in the form and pass that along.
	    // This is for repo-based profiles.
	    //
	    if ($('#paramdefs').val() !== undefined) {
		blob["paramdefs"] = $('#paramdefs').val();
	    }
	    var xmlthing = sup.CallServerMethod(null, "instantiate",
						"GetParameters", blob);
	    xmlthing.done(callback);
	}

      var thumbnail = null;
      var jacksGraphCallback = null;
      function ShowThumbnail(selected_rspec, updateJacksGraph)
      {
	if (updateJacksGraph)
	{
	  jacksGraphCallback = updateJacksGraph;
	}
	var root = $('#stepsContainer-p-2 #inline_jacks');
	if (! thumbnail)
	{
	  thumbnail = new jacksmod.Thumb(setJacksGraph);
	  root.append(thumbnail.el);
	}
	thumbnail.replaceRspec(selected_rspec);
	if (countNodes() > 100)
	{
	  $('#stepsContainer #inline_overlay').addClass("hidden");
	}
	else
	{
	  $('#stepsContainer #inline_overlay').removeClass("hidden");
	}
	
      }

      function setJacksGraph(newGraph)
      {
	if (jacksGraphCallback)
	{
	  jacksGraphCallback(newGraph);
	}
      }
 

	function ChangeJacksRoot(root, selectionPane) {
	  // console.info("ChangeJacksRoot: ", root, selectionPane);
	  if (RSPEC)
	    {
	      if (countNodes() > 100) {
		  $('#stepsContainer #inline_overlay').addClass("hidden");
		  $('#inline_jacks #edit_dialog #edit_container')
		      .addClass("hidden");
		  return;
	      }
	      else {
		  $('#stepsContainer #inline_overlay').removeClass("hidden");
		  $('#inline_jacks #edit_dialog #edit_container')
		      .removeClass("hidden");
	      }
	      editor = new JacksEditor(root, true, true, selectionPane, true);
	      editor.show(RSPEC);
	  }
	}
	function ShowEditor() {
	  // console.info("ShowEditor");
	  if (RSPEC)
	  {
//	      if (countNodes() > 100) {
//		  $('#stepsContainer #inline_overlay').addClass("hidden");
//		  $('#inline_jacks #edit_dialog #edit_container')
//		      .addClass("hidden");
//		  return;
//	      }
//	      else {
		  $('#stepsContainer #inline_overlay').removeClass("hidden");
		  $('#inline_jacks #edit_dialog #edit_container')
		      .removeClass("hidden");
//	      }
	      editor.show(RSPEC);
	  }
	}

      var globalImages = [
	{
	  urn: 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU16-64-STD',
	  version: '',
	  description: 'Ubuntu 16.04 standard image'
	},
	{
	  urn: 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU14-64-STD',
	  version: '',
	  description: 'Ubuntu 14.04 standard image'
	},
	{
	  urn: 'urn:publicid:IDN+emulab.net+image+emulab-ops//CENTOS66-64-STD',
	  version: '',
	  description: 'CentOS 6.6 standard image'
	},
	{
	  urn: 'urn:publicid:IDN+emulab.net+image+emulab-ops//CENTOS71-64-STD',
	  version: '',
	  description: 'CentOS 7.1 standard image'
	},
      	{
	  urn: 'urn:publicid:IDN+emulab.net+image+emulab-ops//FBSD103-64-STD',
	  version: '',
	  description: 'FreeBSD 10.3 standard image'
	},
      ];
      var userImages = [
	{
	  urn: 'urn:publicid:IDN+emulab.net+image+testbed//JONS_COOL_IMAGE',
	  version: '45ac6de',
	  description: 'This image is super cool because it was created in an awesome fashion. You should totally pick this image, dood.'
	},
	{
	  urn: 'urn:publicid:IDN+emulab.net+image+testbed//JONS_BAD_HAIR_DAY_IMAGE',
	  version: 'deadbe4f',
	  description: 'You don not want this image, man. It was created under a bad moon in the middle of a total solar eclipse and is cursed for all time.'
	},
      ];
      
        function initImagePicker(dom) {
	  dom.find('button#image-select').click(function (event) {
	    var callback = function(json) {
	      $('#waitwait-modal').modal('hide');

	      if (json.code == 0) {
		sup.ShowModal('#imagepicker-modal');
		imagePicker.pick(dom.find('input#image-value').val(), json.value[0]);
	      } else {
		sup.SpitOops('oops', json.value);
	      }
	    }
	    $('#waitwait-modal').modal('show');
	    var xmlthing = sup.CallServerMethod(null, "instantiate", "GetImageList");
	    xmlthing.done(callback);

	    
	    var closeFunction = function () {
	      imagePicker.off('selected');
	      imagePicker.off('closed');
	      sup.HideModal('#imagepicker-modal');
	    };
	    imagePicker.on('selected', function (item) {
	      dom.find('input#image-value').val(item);
	      dom.find('input#image-display').val(imageDisplay(item));
	      closeFunction();
	    });
	    imagePicker.on('closed', closeFunction);
	    $('#imagepicker-modal .modal-header button.close').on('click', closeFunction);	    
	    event.preventDefault();
	  });
        }

      function imageDisplay(v) {
	var sp = v.split('+');
	var display;
	if (sp.length >= 4)
	{
	  if (sp[3].substr(0, 12) == 'emulab-ops//')
	  {
	    display = sp[3].substr(12);
	  }
	  else
	  {
	    display = sp[3];
	  }
	}
	else
	{
	  display = v;
	}
	return display;
      }
      
	return {
		HandleSubmit: HandleSubmit,
		StartPP: StartPP,
	        ChangeJacksRoot: ChangeJacksRoot,
	        ShowThumbnail: ShowThumbnail,
	};
    }
)();
});
