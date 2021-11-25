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
	public class PhysicalNodeCollection
	{
		public var collection:Vector.<PhysicalNode>;
		public function PhysicalNodeCollection()
		{
			collection = new Vector.<PhysicalNode>();
		}
		
		public function add(ht:PhysicalNode):void
		{
			collection.push(ht);
		}
		
		public function remove(ht:PhysicalNode):void
		{
			var idx:int = collection.indexOf(ht);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(ht:PhysicalNode):Boolean
		{
			return collection.indexOf(ht) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Clone():PhysicalNodeCollection
		{
			var clone:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each(var node:PhysicalNode in collection)
				clone.add(node);
			return clone;
		}
		
		public function getByName(name:String):PhysicalNode
		{
			for each(var node:PhysicalNode in collection)
			{
				if(node.name == name)
					return node;
			}
			return null;
		}
		
		public function get Types():Vector.<String>
		{
			var types:Vector.<String> = new Vector.<String>();
			for each(var node:PhysicalNode in collection)
			{
				if(node.hardwareType.length>0 && types.indexOf(node.hardwareType) == -1)
					types.push(node.hardwareType);
			}
			return types;
		}
		
		public function get AuxTypes():Vector.<String>
		{
			var types:Vector.<String> = new Vector.<String>();
			for each(var node:PhysicalNode in collection)
			{
				for each(var auxType:String in node.auxTypes)
				{
					if(types.indexOf(auxType) == -1)
						types.push(auxType);
				}
			}
			return types;
		}
		
		public function searchByName(name:String):PhysicalNodeCollection
		{
			var nodes:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.name.indexOf(name) != -1)
					nodes.add(n);
			}
			return nodes;
		}
		
		public function getByType(type:String):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.hardwareType == type)
					group.add(n);
			}
			return group;
		}
		
		public function getByAuxType(type:String):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				for each(var auxType:String in n.auxTypes)
				{
					if(auxType == type)
					{
						group.add(n);
						break;
					}
				}
				
			}
			return group;
		}
		
		public function getByAvailability(available:Boolean):PhysicalNodeCollection
		{
			var group:PhysicalNodeCollection = new PhysicalNodeCollection();
			for each (var n:PhysicalNode in collection)
			{
				if(n.available == available)
					group.add(n);
			}
			return group;
		}
		
		public function get Available():PhysicalNodeCollection
		{
			return getByAvailability(true);
		}
	}
}