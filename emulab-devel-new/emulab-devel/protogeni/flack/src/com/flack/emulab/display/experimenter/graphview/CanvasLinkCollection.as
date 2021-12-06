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

package com.flack.emulab.display.experimenter.graphview
{
	import com.flack.emulab.resources.virtual.VirtualLink;
	import com.flack.emulab.resources.virtual.VirtualLinkCollection;

	public class CanvasLinkCollection
	{
		public var collection:Vector.<CanvasLink>;
		public function CanvasLinkCollection()
		{
			collection = new Vector.<CanvasLink>();
		}
		
		public function add(link:CanvasLink):void
		{
			collection.push(link);
		}
		
		public function remove(link:CanvasLink):int
		{
			var idx:int = collection.indexOf(link);
			if(idx > -1)
				collection.splice(idx, 1);
			return idx;
		}
		
		public function contains(link:CanvasLink):Boolean
		{
			return collection.indexOf(link) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get VirtualLinks():VirtualLinkCollection
		{
			var links:VirtualLinkCollection = new VirtualLinkCollection();
			for each (var cl:CanvasLink in collection)
				links.add(cl.link);
			return links;
		}
		
		public function getForVirtualLinks(links:VirtualLinkCollection):CanvasLinkCollection
		{
			var results:CanvasLinkCollection = new CanvasLinkCollection();
			for each (var cl:CanvasLink in collection)
			{
				if(links.contains(cl.link))
					results.add(cl);
			}
			return results;
		}
		
		public function getForVirtualLink(link:VirtualLink):CanvasLink
		{
			for each (var cl:CanvasLink in collection)
			{
				if(cl.link == link)
					return cl;
			}
			return null;
		}
	}
}