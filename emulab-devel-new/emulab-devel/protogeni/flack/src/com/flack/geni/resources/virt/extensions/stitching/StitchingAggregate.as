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

package com.flack.geni.resources.virt.extensions.stitching
{
	import com.flack.shared.resources.IdentifiableObject;
	
	public class StitchingAggregate extends IdentifiableObject
	{
		public static const AGGREGATETYPE_PROTOGENI:String = "protogeni";
		
		public static const STITCHINGMODE_CHAIN:String = "chain";
		public static const STITCHINGMODE_TREE:String = "tree";
		public static const STITCHINGMODE_CHAINANDTREE:String = "chainANDTree";
		
		public var url:String = "";
		
		public var aggregateType:String = "";
		public var stitchingMode:String = "";
		public var scheduledServices:Boolean = false;
		public var negotiatedServices:Boolean = false;
		//lifetime
		//capabilities
		
		public var nodes:StitchingNodeCollection = new StitchingNodeCollection();
		public var ports:StitchingPortCollection = new StitchingPortCollection();
		public var links:StitchingLinkCollection = new StitchingLinkCollection();
		
		public function StitchingAggregate(newId:String="")
		{
			super(newId);
		}
		
		public function getById(id:String):*
		{
			var result:* = nodes.getById(id);
			if(result != null) return result;
			result = ports.getById(id);
			if(result != null) return result;
			result = links.getById(id);
			if(result != null) return result;
			return null;
		}
	}
}