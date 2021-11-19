//
// Powder mappings for parameterized profiles.
//
$(function () {
  window.powderTypes = (function()
    {
	'use strict';

	var fixedEndpoints = [
	    ['urn:publicid:IDN+web.powderwireless.net+authority+cm',
	     "Warnock Engineering Building"],
	    ['urn:publicid:IDN+ebc.powderwireless.net+authority+cm',
	     "Eccles Broadcast Building"],
	    ['urn:publicid:IDN+bookstore.powderwireless.net+authority+cm',
	     "Campus Book Store"],
	    ['urn:publicid:IDN+humanities.powderwireless.net+authority+cm',
	     "Irish Tanner Humanities"],
	    ['urn:publicid:IDN+madsen.powderwireless.net+authority+cm',
	     "Madsen Health Clinic"],
	];

	var baseStations = [
	    ['meb',	   "Merrill Engineering Building"],
	    ['honors',     "Honors"],
	    ['dentistry',  "Dentistry"],
	    ['ustar',      "USTAR"],
	    ['smt',        "South Medical Tower"],
	    ['browning',   "Browning Building"],
	    ['bes',        "Social Behavioral Sciences"],
	    ['fm',         "Friendship Manor"],
	];

	// Exports from this module.
	return {
	    "fixedEndpoints"	: fixedEndpoints,
	    "baseStations"      : baseStations,
	};
    }
)();
});
