/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation
 * the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the
 * Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR
 * OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */

package com.flack.geni.resources.docs
{
	/**
	 * List of RSPEC versions
	 * 
	 * @author mstrum
	 * 
	 */
	public final class GeniCredentialVersionCollection
	{
		public var collection:Vector.<GeniCredentialVersion> = new Vector.<GeniCredentialVersion>();
		public function GeniCredentialVersionCollection(src:Array = null)
		{
			collection = new Vector.<GeniCredentialVersion>();
			if(src != null)
			{
				for each(var old:GeniCredentialVersion in src)
					collection.push(old);
			}
		}
		
		public function add(s:GeniCredentialVersion):void
		{
			collection.push(s);
		}
		
		public function remove(s:GeniCredentialVersion):void
		{
			var idx:int = collection.indexOf(s);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * Get all RSPEC versions of the given type
		 * 
		 * @param type Type of RSPEC to return
		 * @return Collection of RSPEC versions of the given type
		 * 
		 */
		public function getByType(type:String):GeniCredentialVersionCollection
		{
			var results:GeniCredentialVersionCollection = new GeniCredentialVersionCollection();
			for each(var rspecVersion:GeniCredentialVersion in collection)
			{
				if(rspecVersion.type == type)
					results.add(rspecVersion);
			}
			return results;
		}
		
		/**
		 * 
		 * @return RSPEC types in the collection
		 * 
		 */
		public function get Types():Vector.<String>
		{
			var types:Vector.<String> = new Vector.<String>();
			for each(var rspecVersion:GeniCredentialVersion in collection)
			{
				if(types.indexOf(rspecVersion.type) == -1)
					types.push(rspecVersion.type);
			}
			return types;
		}
	}
}