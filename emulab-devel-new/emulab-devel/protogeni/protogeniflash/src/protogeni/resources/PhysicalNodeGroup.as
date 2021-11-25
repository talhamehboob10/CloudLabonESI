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
	
	// Group of physical nodes located in one area
	public class PhysicalNodeGroup
	{
		public var latitude:Number = -1;
		public var longitude:Number = -1;
		public var country:String = "";
		public var city:String = "";
		
		public var owner:PhysicalNodeGroupCollection = null;
		public var collection:ArrayCollection = new ArrayCollection;
		public var links:PhysicalLinkGroup = null;
		
		public function PhysicalNodeGroup(lat:Number, lng:Number, cnt:String, own:PhysicalNodeGroupCollection)
		{
			latitude = lat;
			longitude = lng;
			country = cnt;
			owner = own;
		}
		
		public function Add(n:PhysicalNode):void {
			collection.addItem(n);
		}

		public function GetByUrn(urn:String):PhysicalNode {
			for each ( var n:PhysicalNode in collection ) {
				if(n.urn == urn)
					return n;
			}
			return null;
		}
		
		public function GetByName(name:String):PhysicalNode {
			for each ( var n:PhysicalNode in collection ) {
				if(n.name == name)
					return n;
			}
			return null;
		}
		
		public function Available():Number {
			var cnt:Number = 0;
			for each ( var n:PhysicalNode in collection ) {
				if(n.available)
					cnt++;
			}
			return cnt;
		}
		
		public function ExternalLinks():Number {
			var cnt:Number = 0;
			for each ( var n:PhysicalNode in collection ) {
				for each ( var l:PhysicalLink in n.GetLinks() ) {
					if(l.owner != n.owner.links)
						cnt++;
				}
			}
			return cnt;
		}
	}
}