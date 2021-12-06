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
	public final class ExperimentCollection
	{
		public var collection:Vector.<Experiment>;
		public function ExperimentCollection()
		{
			collection = new Vector.<Experiment>();
		}
		
		public function add(slice:Experiment):void
		{
			collection.push(slice);
		}
		
		public function remove(slice:Experiment):void
		{
			var idx:int = collection.indexOf(slice);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(slice:Experiment):Boolean
		{
			return collection.indexOf(slice) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param id IDN-URN
		 * @return Slice with the given ID
		 * 
		 */
		public function getByName(name:String):Experiment
		{
			for each(var existing:Experiment in collection)
			{
				if(existing.name == name)
					return existing;
			}
			return null;
		}
		
		
		/**
		 * 
		 * @return Nodes from all the slices
		 * 
		public function get Nodes():VirtualNodeCollection
		{
			var nodes:VirtualNodeCollection = new VirtualNodeCollection();
			return nodes;
		}
		
		public function get Links():VirtualLinkCollection
		{
			var links:VirtualLinkCollection = new VirtualLinkCollection();
			return links;
		}
		*/
	}
}