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
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;

	public class SupportedLinkTypeCollection
	{
		public var collection:Vector.<SupportedLinkType>;
		public function SupportedLinkTypeCollection()
		{
			collection = new Vector.<SupportedLinkType>();
		}
		
		public function add(supportedType:SupportedLinkType):void
		{
			collection.push(supportedType);
		}
		
		public function remove(supportedType:SupportedLinkType):void
		{
			var idx:int = collection.indexOf(supportedType);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(supportedType:SupportedLinkType):Boolean
		{
			return collection.indexOf(supportedType) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Clone():SupportedLinkTypeCollection
		{
			var clone:SupportedLinkTypeCollection = new SupportedLinkTypeCollection();
			for each(var supportedType:SupportedLinkType in collection)
				clone.add(supportedType);
			return clone;
		}
		
		
		public function getByName(name:String):SupportedLinkType
		{
			for each(var supportedType:SupportedLinkType in collection)
			{
				if(supportedType.name == name)
					return supportedType;
			}
			return null;
		}
		
		public function getOrCreateByName(name:String):SupportedLinkType
		{
			var supportedType:SupportedLinkType = getByName(name);
			if(supportedType == null)
			{
				supportedType = new SupportedLinkType(name)
				add(supportedType);
			}
			return supportedType;
		}
		
		public function supportedFor(nodes:VirtualNodeCollection):SupportedLinkTypeCollection
		{
			var supportedTypes:SupportedLinkTypeCollection = Clone;
			for each(var node:VirtualNode in nodes.collection)
			{
				var supportedSliverType:SupportedSliverType = node.manager.supportedSliverTypes.getByName(node.sliverType.name);
				if(supportedSliverType != null && supportedSliverType.limitToLinkType.length > 0)
				{
					var supportedType:SupportedLinkType = supportedTypes.getByName(node.manager.supportedSliverTypes.getByName(node.sliverType.name).limitToLinkType);
					supportedTypes = new SupportedLinkTypeCollection();
					if(supportedType != null)
						supportedTypes.add(supportedType);
					else
						return supportedTypes;
				}
			}
			return supportedTypes;
		}
		
		public function preferredType(numConnections:int = int.MAX_VALUE):SupportedLinkType
		{
			var preferred:SupportedLinkType = null;
			if(length > 0)
			{
				for(var i:int = 0; i < length; i++)
				{
					var testType:SupportedLinkType = collection[i];
					if(testType.maxConnections >= numConnections && (preferred == null || testType.level < preferred.level))
						preferred = testType;
				}
			}
			return preferred;
		}
	}
}