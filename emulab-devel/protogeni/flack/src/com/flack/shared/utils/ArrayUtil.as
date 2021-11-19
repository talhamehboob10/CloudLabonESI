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

package com.flack.shared.utils
{
	import mx.collections.ArrayCollection;
	
	/**
	 * Various common values/functions used throughout the library
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ArrayUtil
	{
		public static function addIfNonexistingToArray(source:Array, o:*):void
		{
			if(source.indexOf(o) == -1)
				source.push(o);
		}
		
		public static function addIfNonexistingToArrayCollection(source:ArrayCollection, o:*):void
		{
			if(source.getItemIndex(o) == -1)
				source.addItem(o);
		}
		
		public static function findInAny(text:Array,
										 candidates:Array,
										 matchAll:Boolean = false,
										 caseSensitive:Boolean = false):Boolean
		{
			if(!caseSensitive)
			{
				for each(var textTemp:String in text)
				textTemp = textTemp.toLowerCase();
			}
			
			for each(var candidate:String in candidates)
			{
				if(!caseSensitive)
					candidate = candidate.toLowerCase();
				for each(var s:String in text)
				{
					
					if(matchAll)
					{
						if(candidate == s)
							return true;
					}
					else
					{
						if(candidate.indexOf(s) > -1)
							return true;
					}
				}
				
			}
			return false;
		}
		
		public static function areEqual(a:Array,b:Array):Boolean
		{
			// handle null arrays
			if(a == null && b == null)
				return true;
			else if(a == null || b == null)
				return false;
			
			// obviously not equal
			if(a.length != b.length)
				return false;
			
			var len:int = a.length;
			for(var i:int = 0; i < len; i++)
			{
				if(a[i] !== b[i])
					return false;
			}
			return true;
		}
		
		public static function haveSame(a:Array,b:Array):Boolean
		{
			if(a == null || b == null)
				return false;
			if(a.length != b.length)
				return false;
			
			var len:int = a.length;
			for(var i:int = 0; i < len; i++)
			{
				if(b.indexOf(a[i]) == -1)
					return false;
			}
			return true;
		}
		
		public static function overlap(a:Array,b:Array):Boolean
		{
			if(a == null || b == null)
				return false;
			
			for each(var obj:* in a)
			{
				if(b.indexOf(obj) != -1)
					return true;
			}
			return false;
		}
		
		public static function keepUniqueObjects(ac:ArrayCollection,
												 oc:ArrayCollection = null):ArrayCollection
		{
			var newAc:ArrayCollection;
			if(oc != null)
				newAc = oc;
			else
				newAc = new ArrayCollection();
			for each(var o:Object in ac)
			{
				if(o is ArrayCollection)
					newAc = keepUniqueObjects((o as ArrayCollection), newAc);
				else
				{
					if(!newAc.contains(o))
						newAc.addItem(o);
				}
			}
			return newAc;
		}
	}
}
