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

package com.flack.emulab.resources.virtual
{
	import com.flack.emulab.resources.physical.PhysicalNode;

	/**
	 * Collection of slices
	 * 
	 * @author mstrum
	 * 
	 */
	public final class VirtualNodeCollection
	{
		public var collection:Vector.<VirtualNode>;
		public function VirtualNodeCollection()
		{
			collection = new Vector.<VirtualNode>();
		}
		
		public function add(slice:VirtualNode):void
		{
			collection.push(slice);
		}
		
		public function remove(slice:VirtualNode):void
		{
			var idx:int = collection.indexOf(slice);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(slice:VirtualNode):Boolean
		{
			return collection.indexOf(slice) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get UnsubmittedChanges():Boolean
		{
			for each(var node:VirtualNode in collection)
			{
				if(node.unsubmittedChanges)
					return true;
			}
			return false;
		}
		
		public function get Experiments():ExperimentCollection
		{
			var experiments:ExperimentCollection = new ExperimentCollection();
			for each(var node:VirtualNode in collection)
			{
				if(!experiments.contains(node.experiment))
					experiments.add(node.experiment);
			}
			return experiments;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Slice with the given ID
		 * 
		 */
		public function getByName(name:String):VirtualNode
		{
			for each(var existing:VirtualNode in collection)
			{
				if(existing.name == name)
					return existing;
			}
			return null;
		}
		
		public function getByPhysicalName(name:String):VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			for each(var existing:VirtualNode in collection)
			{
				if(existing.physicalName == name)
					nodes.add(existing);
			}
			return nodes;
		}
		
		public function getBoundTo(node:PhysicalNode):VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			for each(var existing:VirtualNode in collection)
			{
				if(existing.Physical == node)
					nodes.add(existing);
			}
			return nodes;
		}
		
		public function searchByName(name:String):VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			for each (var v:VirtualNode in collection)
			{
				if(v.name.indexOf(name) != -1)
					nodes.add(v);
			}
			return nodes;
		}
		
		public function isIdUnique(node:*, name:String):Boolean
		{
			var found:Boolean = false;
			for each(var testNode:VirtualNode in collection)
			{
				if(node == testNode)
					continue;
				if(testNode.name == name)
					return false;
				//if(!testNode.interfaces.isIdUnique(node, name))
				//	return false;
			}
			return true;
		}
	}
}