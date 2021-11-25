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
	import com.flack.geni.resources.SliverTypeCollection;

	public class SupportedSliverTypeCollection
	{
		public var collection:Vector.<SupportedSliverType>;
		public function SupportedSliverTypeCollection()
		{
			collection = new Vector.<SupportedSliverType>();
		}
		
		public function add(supportedType:SupportedSliverType):void
		{
			collection.push(supportedType);
		}
		
		public function remove(supportedType:SupportedSliverType):void
		{
			var idx:int = collection.indexOf(supportedType);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(supportedType:SupportedSliverType):Boolean
		{
			return collection.indexOf(supportedType) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get SupportsUnbound():Boolean
		{
			for each(var supportedType:SupportedSliverType in collection)
			{
				if(supportedType.supportsUnbound)
					return true;
			}
			return false;
		}
		
		public function get Bound():SupportedSliverTypeCollection
		{
			var supportedTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
			for each(var supportedType:SupportedSliverType in collection)
			{
				if(supportedType.supportsBound)
					supportedTypes.add(supportedType);
			}
			return supportedTypes;
		}
		
		public function get Unbound():SupportedSliverTypeCollection
		{
			var supportedTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
			for each(var supportedType:SupportedSliverType in collection)
			{
				if(supportedType.supportsUnbound)
					supportedTypes.add(supportedType);
			}
			return supportedTypes;
		}
		
		public function get Shared():SupportedSliverTypeCollection
		{
			var supportedTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
			for each(var supportedType:SupportedSliverType in collection)
			{
				if(supportedType.supportsShared)
					supportedTypes.add(supportedType);
			}
			return supportedTypes;
		}
		
		public function get Exclusive():SupportedSliverTypeCollection
		{
			var supportedTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
			for each(var supportedType:SupportedSliverType in collection)
			{
				if(supportedType.supportsExclusive)
					supportedTypes.add(supportedType);
			}
			return supportedTypes;
		}
		
		public function get SliverTypes():SliverTypeCollection
		{
			var slivers:SliverTypeCollection = new SliverTypeCollection();
			for each(var supportedType:SupportedSliverType in collection)
				slivers.add(supportedType.type);
			return slivers;
		}
		
		public function getByName(name:String):SupportedSliverType
		{
			for each(var supportedType:SupportedSliverType in collection)
			{
				if(supportedType.type.name == name)
					return supportedType;
			}
			return null;
		}
		
		// Always returns a valid supported sliver type object. If the sliver
		// is not defined, the returned supported sliver type will have the
		// default settings.
		public function getByNameOrDefault(name:String):SupportedSliverType
		{
			var supportedSliverType:SupportedSliverType = getByName(name);
			if(supportedSliverType != null)
				return supportedSliverType;
			return new SupportedSliverType(name);
		}
		
		public function getOrCreateByName(name:String):SupportedSliverType
		{
			var supportedType:SupportedSliverType = getByName(name);
			if(supportedType == null)
			{
				supportedType = new SupportedSliverType(name)
				add(supportedType);
			}
			return supportedType;
		}
	}
}