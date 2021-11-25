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
	/**
	 * Collection of extension spaces
	 * 
	 * @author mstrum
	 * 
	 */
	public class ExtensionSpaceCollection
	{
		public var collection:Vector.<ExtensionSpace> = new Vector.<ExtensionSpace>();
		public function ExtensionSpaceCollection()
		{
			collection = new Vector.<ExtensionSpace>();
		}
		
		public function add(s:ExtensionSpace):void
		{
			collection.push(s);
		}
		
		public function remove(s:ExtensionSpace):void
		{
			var idx:int = collection.indexOf(s);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Namespaces():Vector.<Namespace>
		{
			var namespaces:Vector.<Namespace> = new Vector.<Namespace>();
			for each(var space:ExtensionSpace in collection)
				namespaces.push(space.namespace);
			return namespaces;
		}
		
		public function getForNamespace(namespace:Namespace):ExtensionSpace
		{
			for each(var space:ExtensionSpace in collection)
			{
				if(space.namespace == namespace)
					return space;
			}
			return null;
		}
	}
}