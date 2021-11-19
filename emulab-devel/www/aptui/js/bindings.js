//
// Helper function to generate a table of parameter bindings.
//
$(function () {
window.GetBindingsTable = (function ()
    {
	'use strict';
	var html = "";

	var doItem = function (details, defval, actual, index) {
	    console.info("doItem", details.name, defval, actual, index);
	    
	    var tname  = details.name;
	    if (defval == undefined) {
		if (_.has(details, "multiValue") && details.multiValue) {
		    defval = details.itemDefaultValue;
		    if (index < details.defaultValue.length) {
			defval = details.defaultValue[index];
		    }
		}
		else {
		    defval = details.defaultValue;
		}
	    }
	    if (index != undefined) {
		tname = tname + " " + index;
	    }
	    if (details.type == "boolean") {
		if (defval == true) {
		    defval = "True";
		}
		if (defval == false) {
		    defval = "False";
		}
		if (actual == 1) {
		    actual = "True";
		}
		if (actual == 0) {
		    actual = "False";
		}
	    }
	    if (defval != actual) {
		tname = "<span class=text-danger>" + tname + "</span>";
	    }
	    return "<tr><td>" + tname + "</td>" +
		   "<td>" + defval + "</td>" +
		   "<td>" + actual + "</td></tr>";
	};
	var doMultiItem = function (details, bindings, defvals) {
	    var html = "<tr>" +
		"<td colspan=3><b>" + details.name + "</b></td></tr>";

	    console.info("doMultiItem", bindings, defvals);
		
	    _.each(bindings, function (actual, index) {
		var defval;
		if (defvals && index < defvals.length) {
		    defval = defvals[index];
		}
		html += doItem(details, defval, actual, index);

	    });
	    return html;
	};
	var doStruct = function (details, bindings, defvals) {
	    var html = "";

	    console.info("doStruct", bindings, defvals);
	    
	    _.each(details.parameterOrder, function (name) {
		var d = details.parameters[name];
		var defval;
		if (defvals && _.has(defvals, name)) {
		    defval = defvals[name];
		}
		if (_.has(d, "multiValue") && d.multiValue) {
		    html += doMultiItem(d, bindings[name], defval);
		}
		else {
		    html += doItem(d, defval, bindings[name], undefined);
		}
	    });
	    return html;
	};
	return function(paramdefs, bindings) {
	    html = "";

	    _.each(paramdefs, function (details, name) {
		if (details.type == "struct") {
		    html += "<tr class=group-header>" +
			"<td colspan=3><b>" + name + "</b></td></tr>";

		    if (details.multiValue) {
			_.each(bindings[name], function (b, index) {
			    html += "<tr>" +
				"<td colspan=3><b>" + name + " " + index +
				"</b></td></tr>";

			    // default values is an array for multiValue structs
			    var defvals;
			    if (index < details.defaultValue.length) {
				defvals = details.defaultValue[index];
			    }
			    html += doStruct(details, b, defvals);
			});
		    }
		    else {
			// If not a multivalue, then the bindings for the
			// members are at top level and the default values
			// is an array in the struct details.
			html += doStruct(details, bindings, details.defaultValue);
		    }
		}
		else if (_.has(details, "multiValue") && details.multiValue) {
		    html += doMultiItem(details, bindings[name]);
		}
		else {
		    // Old paramdefs did not have name in the details.
		    // Old paramdefs have nothing but "item"
		    if (!_.has(details, "name")) {
			details["name"] = name;
		    }
		    html += doItem(details, undefined, bindings[name]);
		}
	    });
	    return html;
	}
    }
)();
});

