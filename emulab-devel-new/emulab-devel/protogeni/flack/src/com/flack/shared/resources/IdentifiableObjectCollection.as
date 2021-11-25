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

package com.flack.shared.resources
{
	/**
	 * Collection of components
	 * 
	 * @author mstrum
	 * 
	 */
	public class IdentifiableObjectCollection
	{
		public var collection:Array
		public function IdentifiableObjectCollection(src:Array = null)
		{
			if(src != null)
				collection = src.slice();
			else
				collection = [];
		}
		
		public function add(identifiableObject:IdentifiableObject):void
		{
			collection.push(identifiableObject);
		}
		
		public function addAll(src:Array):void
		{
			for each(var obj:IdentifiableObject in src)
				collection.push(obj);
		}
		
		public function remove(identifiableObject:IdentifiableObject):void
		{
			var idx:int = collection.indexOf(identifiableObject);
			if(idx != -1)
				collection.splice(idx, 1);
		}
		
		public function contains(identifiableObject:IdentifiableObject):Boolean
		{
			return collection.indexOf(identifiableObject) != -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Sliver with the given ID
		 * 
		 */
		public function getById(id:String):IdentifiableObject
		{
			for each(var existing:IdentifiableObject in collection)
			{
				if(existing.id.full == id)
					return existing;
			}
			return null;
		}
		
		/**
		 * 
		 * @param nodes Nodes to see if same
		 * @return TRUE if this collection same as given
		 * 
		 */
		public function sameAs(identifiableObjects:IdentifiableObjectCollection):Boolean
		{
			if(length != identifiableObjects.length)
				return false;
			for each(var identifiableObject:IdentifiableObject in collection)
			{
				if(!identifiableObjects.contains(identifiableObject))
					return false;
			}
			return true;
		}
	}
}