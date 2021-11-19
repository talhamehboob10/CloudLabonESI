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
	/**
	 * Collection of slices
	 * 
	 * @author mstrum
	 * 
	 */
	public final class VirtualLinkCollection
	{
		public var collection:Vector.<VirtualLink>;
		public function VirtualLinkCollection()
		{
			collection = new Vector.<VirtualLink>();
		}
		
		public function add(slice:VirtualLink):void
		{
			collection.push(slice);
		}
		
		public function remove(slice:VirtualLink):void
		{
			var idx:int = collection.indexOf(slice);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(slice:VirtualLink):Boolean
		{
			return collection.indexOf(slice) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Clone():VirtualLinkCollection
		{
			var links:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
				links.add(link);
			return links;
		}
		
		public function get UnsubmittedChanges():Boolean
		{
			for each(var link:VirtualLink in collection)
			{
				if(link.unsubmittedChanges)
					return true;
			}
			return false;
		}
		
		public function get Experiments():ExperimentCollection
		{
			var experiments:ExperimentCollection = new ExperimentCollection();
			for each(var link:VirtualLink in collection)
			{
				if(!experiments.contains(link.experiment))
					experiments.add(link.experiment);
			}
			return experiments;
		}
		
		public function get Interfaces():VirtualInterfaceCollection
		{
			var interfaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
			for each(var link:VirtualLink in collection)
			{
				for each(var linkInterface:VirtualInterface in link.interfaces.collection)
				{
					if(!interfaces.contains(linkInterface))
						interfaces.add(linkInterface);
				}
			}
			return interfaces;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Slice with the given ID
		 * 
		 */
		public function getByName(name:String):VirtualLink
		{
			for each(var existing:VirtualLink in collection)
			{
				if(existing.name == name)
					return existing;
			}
			return null;
		}
		
		public function isIdUnique(o:*, name:String):Boolean
		{
			var found:Boolean = false;
			for each(var testLink:VirtualLink in collection)
			{
				if(o == testLink)
					continue;
				if(testLink.name == name)
					return false;
			}
			return true;
		}
		
		public function getByExperiment(exp:Experiment):VirtualLinkCollection
		{
			var links:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				if(link.experiment == exp)
					links.add(link);
			}
			
			return links;
		}
		
		public function getConnectedToNodes(nodes:VirtualNodeCollection):VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				var linkNodes:VirtualNodeCollection = link.interfaces.Nodes;
				if(linkNodes.length == nodes.length)
				{
					var found:Boolean = true;
					for each(var linkNode:VirtualNode in linkNodes.collection)
					{
						if(!nodes.contains(linkNode))
							found = false;
					}
					if(found)
						connectedLinks.add(link);
				}
			}
			return connectedLinks;
		}
		
		public function getConnectedToNode(node:VirtualNode):VirtualLinkCollection
		{
			var connectedLinks:VirtualLinkCollection = new VirtualLinkCollection();
			for each(var link:VirtualLink in collection)
			{
				if(link.interfaces.Nodes.contains(node))
					connectedLinks.add(link);
			}
			return connectedLinks;
		}
	}
}