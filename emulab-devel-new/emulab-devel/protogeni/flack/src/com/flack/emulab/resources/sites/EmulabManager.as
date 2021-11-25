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

package com.flack.emulab.resources.sites
{
	import com.flack.emulab.resources.physical.OsidCollection;
	import com.flack.emulab.resources.physical.PhysicalNodeCollection;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;

	/**
	 * Federated ProtoGENI manager
	 * 
	 * @author mstrum
	 * 
	 */
	public class EmulabManager extends FlackManager
	{
		public var osids:OsidCollection = new OsidCollection();
		[Bindable]
		public var nodes:PhysicalNodeCollection = new PhysicalNodeCollection();
		public function EmulabManager(newId:String)
		{
			super(ApiDetails.API_EMULAB, newId);
			api.version = 0.1;
		}
		
		override public function makeValidClientIdFor(value:String):String
		{
			return value.replace(".", "");
		}
		
		override public function clear():void
		{
			super.clear();
			clearComponents();
		}
		
		public function clearComponents():void
		{
			nodes = new PhysicalNodeCollection();
		}
	}
}