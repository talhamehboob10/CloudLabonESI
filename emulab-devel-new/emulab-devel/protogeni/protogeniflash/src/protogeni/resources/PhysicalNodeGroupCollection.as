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
	
	// Collection of all physical node groups
	public class PhysicalNodeGroupCollection
	{
		public function PhysicalNodeGroupCollection()
		{
		}
		
		public var collection:ArrayCollection = new ArrayCollection();
		
		public function GetByLocation(lat:Number, lng:Number):PhysicalNodeGroup {
			for each(var ng:PhysicalNodeGroup in collection) {
				if(ng.latitude == lat && ng.longitude == lng)
					return ng;
			}
			return null;
		}
		
		public function GetByUrn(urn:String):PhysicalNode {
			for each(var ng:PhysicalNodeGroup in collection) {
				var n:PhysicalNode = ng.GetByUrn(urn);
				if(n != null)
					return n;
			}
			return null;
		}
		
		public function GetByName(name:String):PhysicalNode {
			for each(var ng:PhysicalNodeGroup in collection) {
				var n:PhysicalNode = ng.GetByName(name);
				if(n != null)
					return n;
			}
			return null;
		}
		
		public function GetInterfaceByID(id:String):PhysicalNodeInterface {
			for each(var ng:PhysicalNodeGroup in collection) {
				for each(var n:PhysicalNode in ng.collection) {
					var ni:PhysicalNodeInterface = n.interfaces.GetByID(id);
					if(ni != null)
						return ni;
				}
			}
			return null;
		}
		
		public function Add(g:PhysicalNodeGroup):void {
			collection.addItem(g);
		}
		
		public function GetAll():Array
		{
			var d:Array = [];
			for each(var ng:PhysicalNodeGroup in collection) {
				for each(var n:PhysicalNode in ng.collection)
					d.push(n);
			}
			return d;
		}
	}
}