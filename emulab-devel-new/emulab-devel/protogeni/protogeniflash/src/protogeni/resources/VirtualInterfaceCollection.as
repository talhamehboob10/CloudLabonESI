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
	
	// Collection of interfaces from a node in a sliver/slice
	public class VirtualInterfaceCollection
	{
		public function VirtualInterfaceCollection()
		{
		}
		
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		public function GetByID(urn:String):VirtualInterface {
			for each(var ni:VirtualInterface in collection) {
				if(ni.id == urn)
					return ni;
			}
			return null;
		}
		
		public function Add(ni:VirtualInterface):void {
			for each(var t:VirtualInterface in collection)
			{
				if(t.id == ni.id)
					return;
			}
			collection.addItem(ni);
		}
		
		public function Links():ArrayCollection {
			var ac:ArrayCollection = new ArrayCollection();
			for each(var ni:VirtualInterface in collection) {
				for each(var l:VirtualLink in ni.virtualLinks) {
					ac.addItem(l);
				}
			}
			return ac;
		}
	}
}