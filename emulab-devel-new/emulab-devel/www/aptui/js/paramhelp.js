//
// Parameter Set stuff
//
$(function () {
  window.paramHelp = (function()
    {
	'use strict';

	function ShowParameterHelp(paramdefs)
	{
	    console.info("ShowParameterHelp", paramdefs);
	    
	    // We are creating markdown text.
	    var text = "";

	    if (paramdefs == "") {
		HideParameterHelp();
		return;
	    }

	    var doOne = function (param, value, indent) {
		var desc     = param.description;
		var longdesc = param.longDescription;
		var type     = param.type;
		var mvalue   = param.multiValue;
		var spaces   = (indent ? "    " : "");

		text += spaces + "- *" + desc + "*" + "\n\n";
		if (longdesc) {
		    text += spaces + "    ";
		    text += longdesc + "  \n";
		}
		text += spaces + "    ";
		text += "(default value: ";
		if (type == "boolean") {
		    text += "*" + (value ? "True" : "False") + "*";
		}
		else if (value === "") {
		    text += '""';
		}
		else {
		    text += "*" + String(value) + "*";
		}
		if (mvalue) {
		    text += ", multiValue: *True*";
		}
		text += ")" + "\n\n";
	    };

	    _.each(paramdefs, function (param, name) {
		var desc     = param.description;
		var longdesc = param.longDescription;
		var value    = param.defaultValue;
		var type     = param.type;
		var mvalue   = param.multiValue;

		// Not going to get too fancy with structs yet.
		if (type == "struct") {
		    if (mvalue) {
			var mtitle = param.multiValueTitle;
			if (!mtitle) {
			    mtitle = desc;
			}
			text += "- *" + mtitle + "*" + "  \n";
			text += "(multiValue Group: *True*)\n\n";
		    }
		    else {
			text += "- *" + desc + "*" + "\n\n";
			if (longdesc) {
			    text += "    ";
			    text += longdesc + "  \n";
			}
		    }
		    _.each(param.parameters, function (param, name) {
			doOne(param, param.defaultValue, true);
		    });
		}
		else {
		    doOne(param, value, false);
		}
	    });
	    console.info(text);
	    $('#profile_parameters').closest(".form-group")
		.removeClass("hidden");
	    $('#profile_parameters').html(marked(text));
	}
	function HideParameterHelp()
	{
	    $('#profile_parameters').closest(".form-group").addClass("hidden");
	    $('#profile_parameters').html("");
	}
	
	// Exports from this module.
	return {
	    "ShowParameterHelp"	  : ShowParameterHelp,
	    "HideParameterHelp"   : HideParameterHelp,
	};
    }
)();
});
