/*
 * Copyright (c) 2009 University of Utah and the Flux Group.
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
 
 package protogeni.resources
{	
	import mx.collections.ArrayCollection;
	
	// Group of physical links
	public class PhysicalLinkGroup
	{
		public var latitude1:Number = -1;
		public var longitude1:Number = -1;
		public var latitude2:Number = -1;
		public var longitude2:Number = -1;
		public var owner:PhysicalLinkGroupCollection = null;
		public var collection:ArrayCollection = new ArrayCollection;
		
		public function PhysicalLinkGroup(lat1:Number, lng1:Number, lat2:Number, lng2:Number, own:PhysicalLinkGroupCollection)
		{
			latitude1 = lat1;
			longitude1 = lng1;
			latitude2 = lat2;
			longitude2 = lng2;
			owner = own;
		}
		
		public function Add(l:PhysicalLink):void {
			collection.addItem(l);
		}

		public function IsSameSite():Boolean {
			return latitude1 == latitude2 && longitude1 == longitude2;
		}
		
		public function TotalBandwidth():Number {
			var bw:Number = 0;
			for each(var l:PhysicalLink in collection) {
				bw += l.bandwidth;
			}
			return bw;
		}
		
		public function AverageBandwidth():Number {
			return TotalBandwidth() / collection.length;
		}
		
		public function Latency():Number {
			var la:Number = 0;
			for each(var l:PhysicalLink in collection) {
				la += l.latency;
			}
			return la / collection.length;
		}
	}
}