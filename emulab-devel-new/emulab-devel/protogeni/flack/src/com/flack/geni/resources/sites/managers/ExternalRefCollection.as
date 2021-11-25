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

package com.flack.geni.resources.sites.managers
{
	public class ExternalRefCollection
	{
		public var collection:Vector.<ExternalRef>;
		public function ExternalRefCollection()
		{
			collection = new Vector.<ExternalRef>();
		}
		
		public function add(supportedType:ExternalRef):void
		{
			collection.push(supportedType);
		}
		
		public function remove(supportedType:ExternalRef):void
		{
			var idx:int = collection.indexOf(supportedType);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(supportedType:ExternalRef):Boolean
		{
			return collection.indexOf(supportedType) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function getByComponentId(id:String):ExternalRef
		{
			for each(var supportedType:ExternalRef in collection)
			{
				if(supportedType.id.full == id)
					return supportedType;
			}
			return null;
		}
	}
}