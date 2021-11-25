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

package com.flack.geni.resources.sites
{
	/**
	 * Collection of geni authorities
	 * 
	 * @author mstrum
	 * 
	 */
	public class GeniAuthorityCollection
	{
		public var collection:Vector.<GeniAuthority>;
		public function GeniAuthorityCollection()
		{
			collection = new Vector.<GeniAuthority>();
		}
		
		public function add(authority:GeniAuthority):void
		{
			var addIdx:int = 0;
			while(addIdx < collection.length)
			{
				if(authority.name < collection[addIdx].name)
					break;
				addIdx++;
			}
			collection.splice(addIdx, 0, authority);
		}
		
		public function remove(authority:GeniAuthority):void
		{
			var idx:int = collection.indexOf(authority);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(authority:GeniAuthority):Boolean
		{
			return collection.indexOf(authority) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param url URL for authority we are looking for
		 * @return Authority with the given url
		 * 
		 */
		public function getByUrl(url:String):GeniAuthority
		{
			for each(var authority:GeniAuthority in collection)
			{
				if(authority.url == url)
					return authority;
			}
			return null;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Authority with the given ID
		 * 
		 */
		public function getById(id:String):GeniAuthority
		{
			for each(var authority:GeniAuthority in collection)
			{
				if(authority.id.full == id)
					return authority;
			}
			return null;
		}
		
		/**
		 * 
		 * @param name Authority of the IDN-URN
		 * @return Authority with a matching authority part of the ID
		 * 
		 */
		public function getByAuthority(name:String):GeniAuthority
		{
			for each(var authority:GeniAuthority in collection)
			{
				if(authority.id.authority == name)
					return authority;
			}
			return null;
		}
	}
}