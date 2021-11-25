$(function ()
{
    'use strict';

    var lastIndex  = 0;

    /*
     * This code witten by Jon; ../../fetchlogfile.html
     */
    function initialize()
    {
	// The URL refers to the old php script that spews the file.
	var url = window.SPEWURL + '&isajax=1';

	// Fetch spewlogfile via AJAX call
	var xhr = new XMLHttpRequest();

	// Every time new data comes in or the state variable changes,
	// this function is invoked.
	xhr.onreadystatechange = function ()
	{
            // xhr.responseText contains all data received so far from
            // spewlogfile
            if (xhr.responseText)
            {
		// Append only new text
		var newText = xhr.responseText.substr(lastIndex);
		lastIndex = xhr.responseText.length;

		var scrollHeight = $('body')[0].scrollHeight;
		var scrollTop    = $(window).scrollTop();
		var innerHeight  = window.innerHeight;
		var shouldScroll = scrollHeight - innerHeight === scrollTop;

		$('pre').append(_.escape(newText));

		if (shouldScroll) {
		    $(window).scrollTop(1000000);
		}
            }
	    //
	    // Request is done, we got everything. 
	    //
	    if (xhr.readyState == 4) {
		//
		// This will clear the busy indicators in the outer page,
		// if there are any.
		//
		if (typeof(parent.loadFinished) == "function") {
		    parent.loadFinished();
		}
	    }
	};
	// Invoke the AJAX
	xhr.open('get', url, true);
	xhr.send();
    }

    $(document).ready(initialize);
});
