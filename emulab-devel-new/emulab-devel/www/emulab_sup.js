/*
 * Copyright (c) 2006-2014 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */
/*
 * Some utility stuff.
 */

var user_agent = navigator.userAgent.toLowerCase();
var is_safari   = false;
var is_firefox  = false;
var is_chrome   = false;

if (user_agent.indexOf("safari") != -1) {
    is_safari = true;
}
if (user_agent.indexOf("firefox") != -1) {
    is_firefox = true;
}
if (user_agent.indexOf("chrome") != -1) {
    is_chrome = true;
    is_safari = false;
}

/* Clear the various 'loading' indicators. */
function ClearBusyIndicators(done_msg)
{
    var busyimg = getObjbyName('busy');
    var loadingspan = getObjbyName('loading');
    var loadingdiv  = getObjbyName('inner_loaddiv');

    if (loadingdiv) {
        loadingdiv.style.display = "none";
    }
    busyimg.style.display = "none";
    busyimg.src = "1px.gif";
    loadingspan.innerHTML = done_msg;
}

function HideBusyIndicators()
{
    var loadingdiv  = getObjbyName('outer_loaddiv');

    ClearBusyIndicators('');
    loadingdiv.style.display = "none";
}

/* Replace the current page */
function PageReplace(URL)
{
    window.location.replace(URL);
}

function IframeDocument(id) 
{
    var oIframe = getObjbyName(id);
    var oDoc    = (oIframe.contentWindow || oIframe.contentDocument);

    if (is_safari) {
	if (oIframe.document)
	    return oIframe.document;
	return null;
    }
    
    if (oDoc.document) {
	return oDoc.document;
    }
    return oDoc;
}

function GraphChange_cb(html) {
    grapharea = getObjbyName('grapharea');
    if (grapharea) {
        grapharea.innerHTML = html;
    }
}

function GraphChange(which) {
    var arg0 = "all";
    var arg1 = "all";
    
    var srcvnode = getObjbyName('trace_srcvnode');
    if (srcvnode) {
	arg0 = srcvnode.options[srcvnode.selectedIndex].value;
    }
    var dstvnode = getObjbyName('trace_dstvnode');
    if (dstvnode) {
	arg1 = dstvnode.options[dstvnode.selectedIndex].value;
    }

    x_GraphShow(which, arg0, arg1, GraphChange_cb);
    return false;
}

function GetMaxHeight(id) {
    var Iframe    = getObjbyName(id);
    var winheight = 0;
    var yoff      = 0;

    // This tells us the total height of the browser window.
    if (window.innerHeight) // all except Explorer
	winheight = window.innerHeight;
    else if (document.documentElement &&
	     document.documentElement.clientHeight)
	// Explorer 6 Strict Mode
	winheight = document.documentElement.clientHeight;
    else if (document.body)
	// other Explorers
	winheight = document.body.clientHeight;

    // Now get the Y offset of the outputframe.
    yoff = Iframe.offsetTop;

    if (winheight != 0) {
	// Now calculate how much room is left and make the iframe
	// big enough to use most of the rest of the window.
	if (yoff != 0)
	    winheight = winheight - (yoff + 100);
	else
	    winheight = winheight * 0.7;
    }
    return winheight;
}

function SetupOutputArea(id, clean) {
    var Iframe    = getObjbyName(id);
    var IframeDoc = IframeDocument(id);
    var winheight = GetMaxHeight(id);

    if (clean == true) {
        IframeDoc.open();
        IframeDoc.write('<html><head><base href=$BASEPATH/></head><body>' +
                        '<pre id=outputarea></pre></body></html>');
        IframeDoc.close();
    }

    Iframe.style.border = "2px solid";
    Iframe.style.width  = "98%";
    Iframe.style.height = winheight + "px";
    Iframe.height       = winheight + "px";
    Iframe.width        = "98%"; 
    Iframe.scrolling    = "auto";
    Iframe.frameBorder  = "1";
}

function HideFrame(id) {
    var Iframe    = getObjbyName(id);
    var IframeDoc = IframeDocument(id);

    Iframe.style.border = "0px none";
    Iframe.style.width  = 0;
    Iframe.style.height = 0;
    Iframe.frameBorder  = 0;
    Iframe.height       = 0;
    Iframe.width        = 0;
    Iframe.scrolling    = "no";
}

function ShowDownLoader(id) {
    var Iframe    = getObjbyName(id);
    var winheight = GetMaxHeight(id);

    Iframe.style.border = "2px solid";
    Iframe.style.width  = "98%";
    Iframe.style.height = winheight + "px";
    Iframe.height       = winheight + "px";
    Iframe.width        = "98%";
    Iframe.scrolling    = "auto";
    Iframe.frameBorder  = "1";
}

function ShowEmbedded(id) {
    var Iframe    = getObjbyName(id);
    var winheight = GetMaxHeight(id);

    Iframe.style.height = winheight + "px";
    Iframe.height       = winheight + "px";
}

/* @return The innerHeight of the window. */
function getInnerHeight(id) {
    var retval;
    var win = getObjbyName(id).contentWindow;
    var doc = getObjbyName(id).contentWindow.document;

    if (win.innerHeight)
	// all except Explorer
	retval = win.innerHeight;
    else if (doc.documentElement && doc.documentElement.clientHeight)
	// Explorer 6 Strict Mode
	retval = doc.documentElement.clientHeight;
    else if (doc.body)
	// other Explorers
	retval = doc.body.clientHeight;

    return retval;
}

/* @return The scrollTop of the window. */
function getScrollTop(id) {
    var retval;
    var win = getObjbyName(id).contentWindow;
    var doc = getObjbyName(id).contentWindow.document;

    if (win.pageYOffset)
	// all except Explorer
	retval = win.pageYOffset;
    else if (document.documentElement && document.documentElement.scrollTop)
	// Explorer 6 Strict
	retval = document.documentElement.scrollTop;
    else if (document.body)
	// all other Explorers
	retval = document.body.scrollTop;
    
    return retval;
}

/* @return The height of the document. */
function getScrollHeight(id) {
    var retval;
    var win = getObjbyName(id).contentWindow;
    var doc = getObjbyName(id).contentWindow.document;
    var test1 = doc.body.scrollHeight;
    var test2 = doc.body.offsetHeight;

    if (test1 > test2)
	// all but Explorer Mac
	retval = doc.body.scrollHeight;
    else
	// Explorer Mac;
	// would also work in Explorer 6 Strict, Mozilla and Safari
	retval = doc.body.offsetHeight;

    return retval;
}

/* Write the text to the output area, keeping the cursor at the bottom. */
var lastLength = 0;  // The length of the download text at the last update
var lastLine   = ""; // The last line of the download text.
var firstLine  = 1;  // Flag.

function WriteOutputText(id, stuff) {
    var Iframe = getObjbyName(id);
    var idoc   = IframeDocument(id);
    var output = idoc.getElementById('outputarea');

    /*
     * Append new stuff to the last line from the previous call in case
     * the previous line was only partially downloaded.
     */
    var newData = lastLine + stuff.substring(lastLength);
    var lines   = newData.split("\n");
    var newText = "";

    // Globals
    lastLength = stuff.length;
    lastLine   = "";

    /*
     * Record the size of the document before modifying it so we can see
     * if we can automatically do the scroll.
     */
    var ih = getInnerHeight(id);
    var y  = getScrollTop(id);
    var h  = getScrollHeight(id);
	
    /* Iterate over lines */
    for (i = 0; i < lines.length - 1; i++) {
	var line = lines[i];

	if (firstLine) {
	    if (line.search(/^[ \ ]*$/) >= 0) {
		continue;
	    }
	    firstLine = 0;
	}
	newText += line + "\n";
    }
    // For next call
    lastLine = lines[lines.length - 1];

    // Add the new text to the DOM.
    textNode = idoc.createTextNode(newText);
    output.appendChild(textNode);

    /* See if we should scroll the window down. */
    var nh = getScrollHeight(id);

    if ((h - (y + ih)) < (y == 0 ? 200 : 10)) {
	idoc.documentElement.scrollTop = nh;
	idoc.body.scrollTop = nh;
    }
}

function GetInnerText(el) {
    if (typeof el == "string")
	return el;
    if (typeof el == "undefined")
	return "";
    // Not needed but it is faster    
    if (el.innerText)
	return el.innerText;

    var str = "";
    var cs  = el.childNodes;
    var l   = cs.length;
    
    for (var i = 0; i < l; i++) {
	switch (cs[i].nodeType) {
	case 1: //ELEMENT_NODE
	    str += GetInnerText(cs[i]);
	    break;
	case 3:	//TEXT_NODE
	    str += cs[i].nodeValue;
	    break;
	}
    }
    return str;
}

/*
 * @return The text in the given iframe.  If the text is surrounded by '<pre>'
 * tags (mozilla, IE), they will be stripped.
 */
function GetInputText(id) {
    var ifr    = getObjbyName(id);
    var retval = null;

    try {
	var oDoc = (ifr.contentWindow || ifr.contentDocument);
	if (oDoc.document) {
	    oDoc = oDoc.document;
	}
	for (lpc = 0; lpc < oDoc.childNodes.length; lpc++) {
	    text = GetInnerText(oDoc.childNodes[lpc]);
	    if (text != "") {
		if (retval == null)
		    retval = "";
		retval += text;
	    }
	}
	if (retval.indexOf("<pre>") != -1 || retval.indexOf("<PRE>") != -1) {
	    retval = retval.substring(5, retval.length - 6);
	}
    }
    catch (error) {
    }

    return retval;
}

/*
 * Process, start and stop output.
 */
var OutputInterval;
var InputID;
var OutputID;

function LookforOutput() {
    var stuff;
    
    if ((stuff = GetInputText(InputID)) != null) {
	WriteOutputText(OutputID, stuff);
    }
}

function StartOutput(input_id, output_id) {
    OutputID  = output_id;
    InputID   = input_id;
    firstLine = 1;
    OutputInterval = setInterval('LookforOutput()', 1000);
}

function StopOutput() {
    clearInterval(OutputInterval);
    LookforOutput();
}

/*
 * Cross browser support for finding objects by id.
 */
function getObjbyName(name) {
    if (document.getElementById) {
	return document.getElementById(name);
    }
    else if (document.all) {
	return document.all[name];
    }
    else if (document.layers) {
	return getObjNN4(document,name);
    }
    return null;
}
function getObjNN4(obj,name) {
    var x = document.layers;
    var foundLayer;
    
    for (var i=0; i < x.length; i++) {
	if (x[i].id == name)
	    foundLayer = x[i];
	else if (x[i].layers.length)
	    var tmp = getObjNN4(x[i],name);
	
	if (tmp) foundLayer = tmp;
    }
    return foundLayer;
}

function toggle_tableold(e_table, e_checkbox, e_title, e_footer) {
    var id_table  = getObjbyName(e_table);
    var id_footer = getObjbyName(e_footer);
    var id_title  = getObjbyName(e_title);
    var id_check  = getObjbyName(e_checkbox);
    var checked   = id_check.checked;
    
    //Set the object to table-cell if the browser is
    //Firefox and block if it's anything else.
    if (is_firefox || is_safari) {
	if (! checked) {
            id_table.style.display = "none";
	    if (id_footer) {
		id_footer.style.display = "none";
	    }
	    if (id_title) {
		id_title.style.display = "none";
	    }
         }
         else {
            id_table.style.display = "table";
	    if (id_footer) {
		id_footer.style.display = "block";
	    }
	    if (id_title) {
		id_title.style.display = "block";
	    }
         }
    }
    else {
	if (! checked) {
            id_table.style.display = "none";
	    if (id_footer) {
		id_footer.style.display = "none";
	    }
	    if (id_title) {
		id_title.style.display = "none";
	    }
	}
	else {
            id_table.style.display = "block";
	    if (id_footer) {
		id_footer.style.display = "block";
	    }
	    if (id_title) {
		id_title.style.display = "block";
	    }
	}
    }
    return true;
}

function toggle_table(e_table, e_checkbox) {
    var id_table  = getObjbyName(e_table);
    var id_check  = getObjbyName(e_checkbox);
    var checked   = id_check.checked;
    
    if (! checked) {
	id_table.style.display = "none";
    }
    else {
	id_table.style.display = "block";
    }
    return true;
}

function toggle_menu(e_list, e_arrow) {
    var id_list  = getObjbyName(e_list);
    var id_arrow = getObjbyName(e_arrow);

    if (id_list.style.display == "none") {    
	id_list.style.display = "block";
	id_arrow.src = "menu-expanded.png";
	id_arrow.alt = "Collapse";
    }
    else {
	id_list.style.display = "none";
	id_arrow.src = "menu-collapsed.png";
	id_arrow.alt = "Expand";
    }
    return true;
}

function PopUpWindow(text)
{
    var newWinHeight = 400;
    var newWinWidth  = 700;
    var newWinTop    = (screen.height-newWinHeight)/2;
    var newWinLeft   = (screen.width-newWinWidth)/2;
    
    var winProps = eval('"resizable=yes,menubar=no,toolbar=no,scrollbars=yes,top=" +newWinTop+ ",left=" +newWinLeft+ ",width=" +newWinWidth+ ",height=" +newWinHeight');

    myWindow = window.open('', "XML", winProps);
    myWindow.document.write('<html><head><title>XML</title></head>');
    myWindow.document.write('<body><xmp>' + text + '</xmp></body></html>');
    myWindow.document.close();
}

function PopUpWindowFromDiv(id)
{
    var mydiv = getObjbyName(id);
    PopUpWindow(mydiv.innerHTML);
}


