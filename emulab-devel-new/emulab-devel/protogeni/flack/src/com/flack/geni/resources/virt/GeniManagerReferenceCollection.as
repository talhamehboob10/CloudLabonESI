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
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;

	/**
	 * Collection of references to managers
	 * 
	 * @author mstrum
	 * 
	 */
	public class GeniManagerReferenceCollection
	{
		public var collection:Vector.<GeniManagerReference>;
		public function GeniManagerReferenceCollection()
		{
			collection = new Vector.<GeniManagerReference>();
		}
		
		public function add(referencedManager:*):void
		{
			if(referencedManager is GeniManagerReference)
				collection.push(referencedManager);
			else if(referencedManager is GeniManager)
				collection.push(new GeniManagerReference(referencedManager));
		}
		
		public function remove(referencedManager:*):void
		{
			var idx:int = -1;
			if(referencedManager is GeniManagerReference)
				idx = collection.indexOf(referencedManager);
			else if(referencedManager is GeniManager)
			{
				for each(var ref:GeniManagerReference in collection)
				{
					if(ref.referencedManager == referencedManager)
					{
						idx = collection.indexOf(ref);
						break;
					}
				}
			}
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(referencedManager:*):Boolean
		{
			if(referencedManager is GeniManagerReference)
				return collection.indexOf(referencedManager) > -1;
			else if(referencedManager is GeniManager)
			{
				for each(var ref:GeniManagerReference in collection)
				{
					if(ref.referencedManager == referencedManager)
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
		 * @return Collection of managers referenced
		 * 
		 */
		public function get Managers():GeniManagerCollection
		{
			var managers:GeniManagerCollection = new GeniManagerCollection();
			for each(var managerRef:GeniManagerReference in collection)
				managers.add(managerRef.referencedManager);
			return managers;
		}
		
		/**
		 * 
		 * @param manager Manager we want the reference for
		 * @return Reference to the given manager
		 * 
		 */
		public function getReferenceFor(manager:GeniManager):GeniManagerReference
		{
			for each(var managerRef:GeniManagerReference in collection)
			{
				if(managerRef.referencedManager == manager)
					return managerRef;
			}
			return null;
		}
	}
}