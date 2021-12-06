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

package com.flack.geni.display.slicer.graphview
{
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	
	import flash.geom.Point;
	
	import mx.collections.ArrayCollection;
	
	public class CanvasNodeCollection
	{
		public var collection:Vector.<CanvasNode>;
		public function CanvasNodeCollection()
		{
			collection = new Vector.<CanvasNode>();
		}
		
		public function add(node:CanvasNode):void
		{
			collection.push(node);
		}
		
		public function remove(node:CanvasNode):int
		{
			var idx:int = collection.indexOf(node);
			if(idx > -1)
				collection.splice(idx, 1);
			return idx;
		}
		
		public function contains(node:CanvasNode):Boolean
		{
			return collection.indexOf(node) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get VirtualNodes():VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			for each (var cn:CanvasNode in collection)
				nodes.add(cn.Node);
			return nodes;
		}
		
		public function getForVirtualNodes(nodes:VirtualNodeCollection):CanvasNodeCollection
		{
			var results:CanvasNodeCollection = new CanvasNodeCollection();
			for each (var cn:CanvasNode in collection)
			{
				if(nodes.contains(cn.Node))
					results.add(cn);
			}
			return results;
		}
		
		public function getForVirtualNode(node:VirtualNode):CanvasNode
		{
			for each (var cn:CanvasNode in collection)
			{
				if(cn.Node == node)
					return cn;
			}
			return null;
		}
		
		public function seperateNodesByComponentManager():Array
		{
			var completedCms:ArrayCollection = new ArrayCollection();
			var completed:Array = new Array();
			for each(var cn:CanvasNode in collection)
			{
				if(!completedCms.contains(cn.Node.manager))
				{
					var cmNodes:CanvasNodeCollection = new CanvasNodeCollection();
					for each(var sncm:CanvasNode in collection)
					{
						if(sncm.Node.manager == cn.Node.manager)
							cmNodes.add(sncm);
					}
					if(cmNodes.length > 0)
						completed.push(cmNodes);
				}
			}
			return completed;
		}
		
		public function get MiddleX():Number
		{
			var x:Number = 0;
			for each(var cn:CanvasNode in collection)
				x += cn.MiddleX;
			return x/length;
		}
		
		public function get MiddleY():Number
		{
			var y:Number = 0;
			for each(var cn:CanvasNode in collection)
				y += cn.MiddleY;
			return y/length;
		}
	}
}