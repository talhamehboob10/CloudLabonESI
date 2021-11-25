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

package com.flack.geni.resources.virt
{
	/**
	 * Collection of interface references
	 * 
	 * @author mstrum
	 * 
	 */
	public class VirtualInterfaceReferenceCollection
	{
		[Bindable]
		public var collection:Vector.<VirtualInterfaceReference>;
		public function VirtualInterfaceReferenceCollection()
		{
			collection = new Vector.<VirtualInterfaceReference>();
		}
		
		public function add(virtualInterface:*):void
		{
			if(virtualInterface is VirtualInterfaceReference)
				collection.push(virtualInterface);
			else if(virtualInterface is VirtualInterface)
				collection.push(new VirtualInterfaceReference(virtualInterface));
		}
		
		public function remove(virtualInterface:*):void
		{
			var idx:int = -1;
			if(virtualInterface is VirtualInterfaceReference)
				idx = collection.indexOf(virtualInterface);
			else if(virtualInterface is VirtualInterface)
			{
				for each(var ref:VirtualInterfaceReference in collection)
				{
					if(ref.referencedInterface == virtualInterface)
					{
						idx = collection.indexOf(ref);
						break;
					}
				}
			}
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(virtualInterface:*):Boolean
		{
			if(virtualInterface is VirtualInterfaceReference)
				return collection.indexOf(virtualInterface) > -1;
			else if(virtualInterface is VirtualInterface)
			{
				for each(var ref:VirtualInterfaceReference in collection)
				{
					if(ref.referencedInterface == virtualInterface)
						return true;
				}
			}
			return false;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @return Virtual interfaces being referenced
		 * 
		 */
		public function get Interfaces():VirtualInterfaceCollection
		{
			var interfaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
			for each(var interfaceRef:VirtualInterfaceReference in collection)
				interfaces.add(interfaceRef.referencedInterface);
			return interfaces;
		}
		
		/**
		 * 
		 * @param iface Virtual interface
		 * @return Reference to given virtual interface
		 * 
		 */
		public function getReferenceFor(iface:VirtualInterface):VirtualInterfaceReference
		{
			for each(var interfaceRef:VirtualInterfaceReference in collection)
			{
				if(interfaceRef.referencedInterface == iface)
					return interfaceRef;
			}
			return null;
		}
	}
}