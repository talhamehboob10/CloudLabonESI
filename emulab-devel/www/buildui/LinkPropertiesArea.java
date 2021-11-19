/*
 * Copyright (c) 2002-2006 University of Utah and the Flux Group.
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
public class LinkPropertiesArea extends PropertiesArea
{
    public boolean iCare( Thingee t ) {
	return (t instanceof LinkThingee && !(t instanceof LanLinkThingee));
    }

    public String getName() { return "Link Properties"; }
 
    public LinkPropertiesArea() 
    {
	super();
	addProperty("name", "name:", "", true, false);
	addProperty("bandwidth", "bandwidth(Mb/s):", "100", false, false);
	addProperty("latency", "latency(ms):", "0", false, false);
	addProperty("loss", "loss rate(0.0 - 1.0):", "0.0", false, false);	
    }
};
