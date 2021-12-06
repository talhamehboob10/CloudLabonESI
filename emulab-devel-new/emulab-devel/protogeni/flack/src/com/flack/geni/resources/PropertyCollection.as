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

package com.flack.geni.resources
{
	import com.flack.geni.resources.virt.VirtualInterface;

	/**
	 * Properties of a link
	 * 
	 * @author mstrum
	 * 
	 */
	public class PropertyCollection
	{
		public var collection:Vector.<Property>;
		public function PropertyCollection()
		{
			collection = new Vector.<Property>();
		}
		
		public function add(property:Property):void
		{
			collection.push(property);
		}
		
		public function remove(property:Property):void
		{
			var idx:int = collection.indexOf(property);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(property:Property):Boolean
		{
			return collection.indexOf(property) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param source Source virtual or physical interface
		 * @param dest Destination virtual or physical interface
		 * @return Property related to the source and destination
		 * 
		 */
		public function getFor(source:*, dest:*):Property
		{
			for each(var property:Property in collection)
			{
				if(property.source == source && property.destination == dest)
					return property;
			}
			return null;
		}
		
		/**
		 * Removes all properties using the given interface
		 * 
		 * @param iface Virtual interface to remove any properties for
		 * 
		 */
		public function removeAnyWithInterface(iface:VirtualInterface):void
		{
			for(var i:int = 0; i < collection.length; i++)
			{
				var property:Property = collection[i];
				if(property.source == iface || property.destination == iface)
				{
					remove(property);
					i--;
				}
			}
		}
		
		/**
		 * Returns whether the properties are set in both directions
		 * 
		 * @return TRUE if properties extend in both directions
		 * 
		 */
		public function get Duplex():Boolean
		{
			for(var i:int = 0; i < collection.length; i++)
			{
				var testProperty:Property = collection[i];
				if(getFor(testProperty.destination, testProperty.source) == null)
					return false;
			}
			return true;
		}
	}
}