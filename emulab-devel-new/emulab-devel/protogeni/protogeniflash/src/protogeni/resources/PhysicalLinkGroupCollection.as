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
	
	// Collection of all physical link groups
	public class PhysicalLinkGroupCollection
	{
		public function PhysicalLinkGroupCollection()
		{
		}
		
		public var collection:ArrayCollection = new ArrayCollection();

		public function Get(lat1:Number, lng1:Number, lat2:Number, lng2:Number):PhysicalLinkGroup {
			for each(var g:PhysicalLinkGroup in collection) {
				if(g.latitude1 == lat1 && g.longitude1 == lng1) {
					if(g.latitude2 == lat2 && g.longitude2 == lng2) {
						return g;
					}
				}
				if(g.latitude1 == lat2 && g.longitude1 == lng2) {
					if(g.latitude2 == lat1 && g.longitude2 == lng1) {
						return g;
					}
				}
			}
			return null;
		}
		
		public function Add(g:PhysicalLinkGroup):void {
			collection.addItem(g);
		}
	}
}