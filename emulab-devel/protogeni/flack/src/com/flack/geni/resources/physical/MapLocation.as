/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */

package com.flack.geni.resources.physical
{
	import com.flack.geni.resources.virt.VirtualLinkCollection;
	import com.flack.geni.resources.virt.VirtualNodeCollection;

	public class MapLocation
	{
		public var latitude:Number;
		public var longitude:Number;
		
		public var locations:Vector.<PhysicalLocation> = new Vector.<PhysicalLocation>();
		
		public var physicalNodes:PhysicalNodeCollection;
		public var physicalLinks:PhysicalLinkCollection;
		public var virtualNodes:VirtualNodeCollection;
		public var virtualLinks:VirtualLinkCollection;
		
		public function MapLocation()
		{
		}
		
		/**
		 * 
		 * @param testLocations Locations we are testing for
		 * @return TRUE if the underlying location(s) is/are the same
		 * 
		 */
		public function sameLocationAs(testLocations:Vector.<PhysicalLocation>):Boolean
		{
			if(testLocations.length != locations.length)
				return false;
			for each(var testLocation:PhysicalLocation in testLocations)
			{
				if(locations.indexOf(testLocation) == -1)
					return false;
			}
			return true;
		}
	}
}