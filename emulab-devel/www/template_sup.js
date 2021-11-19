/*
 * Copyright (c) 2006 University of Utah and the Flux Group.
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

/*
 * Draw a box around template that is being displayed (in the graph).
 * This turns on a div after setting its x,y,w,h, which we glean from
 * from the coord string of the "area" element. Could be much smarter,
 * but fisrt I would have to be smarter.
 */
function SetActiveTemplate(img_name, div_name, area_name)
{
    var template_image = document.getElementById(img_name);
    var template_div   = document.getElementById(div_name);
    var template_area  = document.getElementById(area_name);

    /*
     * The area coords tell us where to place the red overlay box on the image.
     */
    var myarray = template_area.coords.split(",");

    var x1 = myarray[0] - 0;
    var y1 = myarray[1] - 0;
    var x2 = myarray[2] - 0;
    var y2 = myarray[3] - 0;

    var top    = template_image.offsetTop + y1;
    var left   = template_image.offsetLeft + x1;
    var width  = (x2 - x1) - 2;
    var height = (y2 - y1) - 2;

    template_div.style['top']    = top + "px";
    template_div.style['left']   = left + "px";
    template_div.style['height'] = height + "px";
    template_div.style['width']  = width + "px";
    template_div.style['visibility'] = "visible";
}

/*
 * For initializing template run params
 */
function SetRunParams(names, values)
{
    for (i = 0; i < names.length; i++) {
	var name  = names[i];
	var value = values[i];
	var field = document.getElementById("parameter_" + name);

	if (field) {
	    field.value = value;
	}
    }
}

