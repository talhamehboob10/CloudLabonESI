//
// Progress Modal
//
$(function () {
  window.aptforms = (function()
    {
	'use strict';

	function FormatFormFields(html) {
	    var root   = $(html);
	    var list   = root.find('.format-me');
	    
	    list.each(function (index, item) {
		if (item.dataset) {
  		    var key = item.dataset['key'];

		    /*
		     * Wrap in a div we can name. We assume the form
		     * is already form-group'ed as needed. We attach a
		     * name to the wrapper so we can find it later to
		     * add the error stuff.
		     */
		    var wrapper = $("<div id='form-wrapper-" + key + "'>" +
				    "</div>");

		    // How do I just move the item into the wrapper?
		    wrapper.append($(item).clone());
		    $(item).after(wrapper);
		    $(item).remove();
		    
		    /*
		     * A normal placeholder can be used, but sometimes
		     * we want both a placeholder in the input, and a
		     * label outside of other text.
		     */
		    if (_.has(item.dataset, "label")) {
			var label = item.dataset['label'];
			
			wrapper.prepend("<label for='" + key + "' " +
					"       class='control-label'> " +
					_.escape(label) + '</label>');
		    }
		}
	    });
	    return root;
	}

	function FormatFormFieldsHorizontal(html, options) {
	    var root   = $(html);
	    var list   = root.find('.format-me');
	    var wide   = (options && _.has(options, "wide") ? true : false);

	    list.each(function (index, item) {
		if (item.dataset) {
  		    var key = item.dataset['key'];
		    var margin  = 15;
		    var colsize = null;

		    // Squeeze vertical space for this field.
		    if (_.has(item.dataset, "compact")) {
			margin = 0;
		    }
		    // Column size per row,
		    if (_.has(item.dataset, "colsize")) {
			colsize = item.dataset['colsize'];;
		    }
		    // Override wide setting per field
		    if (_.has(item.dataset, "wide")) {
			wide = item.dataset['wide'];;
		    }

		    /*
		     * Wrap in a div we can name. We assume the form
		     * is already form-group'ed as needed. We attach a
		     * name to the wrapper so we can find it later to
		     * add the error stuff. 
		     */
		    var wrapper = $("<div id='form-wrapper-" + key + "' " +
				    "style='margin-bottom: " + margin +
				    "px;'></div>");
		    
		    /*
		     * A normal placeholder can be used, but sometimes
		     * we want both a placeholder in the input, and a
		     * label outside of other text.
		     */
		    if (_.has(item.dataset, "label")) {
			var label_text =
			    "<label for='" + key + "' " +
			    " class='col-sm-3 control-label' ";
			if (_.has(item.dataset, "optional")) {
			    label_text = label_text +
				"style='padding-top: 0px;'";
			}
			label_text = label_text + ">" +
			    item.dataset['label'];

			if (_.has(item.dataset, "help")) {
			    label_text = label_text +
				"<a href='#' class='btn btn-xs' " +
				" style='padding-right: 0px;' " +
				" data-toggle='popover' " +
				" data-html='true' " +
				" data-delay='{\"hide\":1000}' " +
				" data-content='" + item.dataset['help'] + "'>"+
				"<span style='margin-bottom: 4px;' " +
				"  class='glyphicon " +
				"      glyphicon-question-sign'>" +
				" </span></a>";
			}
			if (_.has(item.dataset, "optional")) {
			    label_text = label_text +
				"<br><small>(Optional)</small>";
			}
			label_text = label_text + "</label>";
			wrapper.append($(label_text));
			if (!colsize) {
			    colsize = (wide ? 9 : 6);
			}
		    }
		    var innerdiv =
			$("<div class='col-sm-" + colsize + "'></div>");
		    innerdiv.html($(item).clone());
		    wrapper.append(innerdiv);
		    $(item).after(wrapper);
		    $(item).remove();
		}
	    });
	    return root;
	}

	/*
	 * Add errors to form. Watch for errors that are not associated
	 * with a visible form field, convert to a general error below.
	 */
	function GenerateFormErrors(form, errors) {
	    $(form).find(".format-me").each(function () {
		if (this.dataset) {
  		    var key = this.dataset['key'];

		    if (errors && _.has(errors, key)) {
			$(this).parent().addClass("has-error");

			var html =
			    '<label class="control-label" ' +
			    '  id="label-error-' + key + '" ' +
			    '  for="inputError">' + _.escape(errors[key]) +
			    '</label>';
			    
			$(this).parent().append(html);
			delete errors[key];
		    }
		}
	    });
	    if (!errors || Object.keys(errors).length == 0) {
		return;
	    }
	    /*
	     * Deal with a "general" error. Some of the forms have a specific
	     * spot for this.
	     */
	    if (_.has(errors, "error")) {
		if ($('#general_error').length) {
		    $('#general_error').html(_.escape(errors["error"]));
		}
		else {
		    console.info("General error: " + errors["error"]);
		    alert(errors["error"]);
		}
	    }
	    else {
		var field = Object.keys(errors)[0];
		var error = errors[field];
		
		if ($('#general_error').length) {
		    $('#general_error').html(_.escape(field + ": " + error));
		}
		else {
		    console.info("Form error: " + errors["error"]);
		    alert(errors["error"]);
		}
		
	    }
	}

	/*
	 * Enable a warning if the form is modified and we try to leave
	 * the page. Only allows a single form, but that would be easy
	 * to change if we needed it.
	 */
	var form_modified = false;
	
	function EnableUnsavedWarning(form, modified_callback) {
	    $(form + ' :input').change(function () {
		//console.info("changed");
		if (modified_callback) {
		    modified_callback();
		}
		form_modified = true;
	    });
	    $(form + ' :input').on("input", function () {
		//console.info("changed");
		if (modified_callback) {
		    modified_callback();
		}
		form_modified = true;
	    });

	    // Warn user if they have not saved changes.
	    $(window).on('beforeunload.portal',
	    function() {
		if (! form_modified)
		    return undefined;
		return "You have unsaved changes!";
	    });
	}
	function DisableUnsavedWarning(form) {
	    $(window).off('beforeunload.portal');
	}
	function MarkFormUnsaved() {
	    form_modified = true;
	}

	function ClearFormErrors(form) {
	    $(form).find(".format-me").each(function () {
		if (this.dataset) {
  		    var key = this.dataset['key'];

		    // Remove the error label by id, that we added above.
		    if ($(this).parent().hasClass("has-error")) {
			$(this).parent()
			    .find('#' + 'label-error-' + key).remove();
			$(this).parent().removeClass("has-error");
		    }
		}
	    });
	    $('#general_error').html("");
	}

	/*
	 * Update a form contents from an array.
	 */
	function UpdateForm(form, formfields) {
	    _.each(formfields, function(value, name) {
		$(form).find("[name=" + name + "]").each(function () {
		    console.log(this, this.type);
		    $(this).val(value);
		});
	    });
	}

	/*
	 * Check a form. We add the errors before we return.
	 */
	function CheckForm(form, route, method, callback, formfields) {
	    /*
	     * Convert form data into formfields array, like all our
	     * form handler pages expect.
	     */
	    if (formfields === undefined) {
		formfields  = {};
	    }
	    
	    var fields = $(form).serializeArray();
	    $.each(fields, function(i, field) {
		formfields[field.name] = field.value;
	    });
	    console.info("Checkform", formfields);
	    ClearFormErrors(form);

	    var checkonly_callback = function(json) {
		console.info("CheckForm", json);

		/*
		 * We deal with these errors, the caller handles other errors.
		 */
		if (json.code == 2) {
		    GenerateFormErrors(form, json.value);
		}
		callback(json);
	    };
	    var xmlthing =
		sup.CallServerMethod(null, route, method,
				     {"formfields" : formfields,
				      "checkonly"  : 1,
				      "embedded"   : window.EMBEDDED,
				     });
	    xmlthing.done(checkonly_callback);
	}

	/*
	 * Submit form.
	 */
	function SubmitForm(form, route, method, callback, message, formfields){
	    /*
	     * Convert form data into formfields array, like all our
	     * form handler pages expect.
	     */
	    if (formfields === undefined) {
		formfields  = {};
	    }
	    var fields = $(form).serializeArray();
	    $.each(fields, function(i, field) {
		formfields[field.name] = field.value;
	    });
	    console.info("Submitform", formfields);
	    var submit_callback = function(json) {
		console.info("SubmitForm", json);
		if (!json.code) {
		    DisableUnsavedWarning(form);
		}
		sup.HideWaitWait(function () {
		    callback(json);
		});
	    };
	    sup.ShowWaitWait(message);
	    var xmlthing =
		sup.CallServerMethod(null, route, method,
				     {"formfields" : formfields,
				      "checkonly"  : 0,
				      "embedded"   : window.EMBEDDED,
				     });
	    xmlthing.done(submit_callback);
	}

	// Exports from this module.
	return {
	    "FormatFormFields"           : FormatFormFields,
	    "FormatFormFieldsHorizontal" : FormatFormFieldsHorizontal,
	    "CheckForm"                  : CheckForm,
	    "SubmitForm"                 : SubmitForm,
	    "GenerateFormErrors"         : GenerateFormErrors,
	    "EnableUnsavedWarning"       : EnableUnsavedWarning,
	    "DisableUnsavedWarning"      : DisableUnsavedWarning,
	    "MarkFormUnsaved"            : MarkFormUnsaved,
	    "UpdateForm"                 : UpdateForm,
	    "ClearFormErrors"            : ClearFormErrors,
	};
    }
)();
});
