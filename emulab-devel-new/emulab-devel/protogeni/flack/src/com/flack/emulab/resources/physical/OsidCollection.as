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

package com.flack.emulab.resources.physical
{
	/**
	 * Collection of hardware types
	 * @author mstrum
	 * 
	 */
	public class OsidCollection
	{
		public var collection:Vector.<Osid>;
		public function OsidCollection()
		{
			collection = new Vector.<Osid>();
		}
		
		public function add(ht:Osid):void
		{
			var htName:String = ht.name.toLowerCase();
			for(var i:int = 0; i < collection.length; i++)
			{
				if(collection[i].name.toLowerCase() > htName)
				{
					collection.splice(i, 0, ht);
					return;
				}
			}
			collection.push(ht);
		}
		
		public function remove(ht:Osid):void
		{
			var idx:int = collection.indexOf(ht);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(ht:Osid):Boolean
		{
			return collection.indexOf(ht) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function getByName(name:String):Osid
		{
			for each(var osid:Osid in collection)
			{
				if(osid.name == name)
					return osid;
			}
			return null;
		}
		
		public function searchByName(name:String):OsidCollection
		{
			var searchName:String = name.toLowerCase();
			var osids:OsidCollection = new OsidCollection();
			for each (var o:Osid in collection)
			{
				if(o.name.toLowerCase().indexOf(searchName) != -1)
					osids.add(o);
			}
			return osids;
		}
	}
}