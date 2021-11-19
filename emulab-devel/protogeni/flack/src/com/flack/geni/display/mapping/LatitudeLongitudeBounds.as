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

package com.flack.geni.display.mapping
{
	public class LatitudeLongitudeBounds
	{
		public var north:Number;	// highest latitude
		public var south:Number;	// lowest latitude
		public var east:Number;		// right longitude
		public var west:Number;		// left longitude
		
		public function get Center():LatitudeLongitude
		{
			if(!isNaN(north) && !isNaN(south) && !isNaN(east) && !isNaN(west))
			{
				return new LatitudeLongitude((north+south)/2, (east+west)/2);
			}
			else
				return null;
		}
		
		public function get SouthWest():LatitudeLongitude
		{
			if(isNaN(south) && isNaN(west))
				return new LatitudeLongitude(south, west);
			else
				return null;
		}
		
		public function get NorthEast():LatitudeLongitude
		{
			if(isNaN(north) && isNaN(east))
				return new LatitudeLongitude(north, east);
			else
				return null;
		}
		
		public function LatitudeLongitudeBounds(swCorner:LatitudeLongitude = null, neCorner:LatitudeLongitude = null)
		{
			if(neCorner != null && swCorner != null)
			{
				north = neCorner.latitude;
				south = swCorner.latitude;
				east = neCorner.longitude;
				west = swCorner.longitude;
			}
			else
			{
				north = NaN;
				south = NaN;
				east = NaN;
				west = NaN;
			}
		}
	}
}