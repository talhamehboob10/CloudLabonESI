/*
 * Copyright (c) 2009 University of Utah and the Flux Group.
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
 * Simple funciton to handle multiple onload/onunload events
 */
var LOADFUNCTIONS = [];
var UNLOADFUNCTIONS = [];
function addLoadFunction(func) {
    LOADFUNCTIONS.push(func);
}

function addUnloadFunction(func) {
    UNLOADFUNCTIONS.push(func);
}

/*
 * Just loop through our arrays calling all of the appropriate functions
 */
function callAllLoadFunctions() {
    for (var i = 0; i < LOADFUNCTIONS.length; i++) {
        LOADFUNCTIONS[i].call();
    }
}

function callAllUnloadFunctions() {
    for (var i = 0; i < UNLOADFUNCTIONS.length; i++) {
        UNLOADFUNCTIONS[i].call();
    }
}

/*
 * Set the onload and onunload functions to the ones we just made
 */
window.onload = callAllLoadFunctions;
window.onunload = callAllUnloadFunctions;

