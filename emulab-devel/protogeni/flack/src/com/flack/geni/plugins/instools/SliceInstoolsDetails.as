/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * Copyright (c) 2011-2012 University of Kentucky.
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

package com.flack.geni.plugins.instools
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.Slice;
	import com.hurlant.crypto.hash.SHA1;
	import com.hurlant.util.Hex;
	
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	import flash.net.navigateToURL;
	import flash.utils.Dictionary;

	public final class SliceInstoolsDetails
	{
		public var slice:Slice;
		public var apiVersion:Number;
		public var creating:Boolean;
		public var useVirtualMCs:Boolean;
		public var useStableINSTOOLS:Boolean;
		
		public var updated_rspec:Dictionary = new Dictionary();
		public var rspec_version:Dictionary = new Dictionary();
		public var cmurn_to_contact:Dictionary = new Dictionary();
		
		public var instools_status:Dictionary = new Dictionary();
		public var portal_url:Dictionary = new Dictionary();
		public var started_instrumentize:Dictionary = new Dictionary();
		public var started_MC:Dictionary = new Dictionary();
		public var MC_present:Dictionary = new Dictionary();
		
		public function SliceInstoolsDetails(useSlice:Slice, useApiVersion:Number, isCreating:Boolean = true, shouldUseVirtualMCs:Boolean = false, shouldUseStableINSTOOLS:Boolean = true)
		{
			slice = useSlice;
			apiVersion = useApiVersion;
			creating = isCreating;
			useVirtualMCs = shouldUseVirtualMCs;
			useStableINSTOOLS = shouldUseStableINSTOOLS;
		}
		
		public function clearAll():void
		{
			updated_rspec = new Dictionary();
			rspec_version = new Dictionary();
			cmurn_to_contact = new Dictionary();
			instools_status = new Dictionary();
			portal_url = new Dictionary();
			started_instrumentize = new Dictionary();
			started_MC = new Dictionary();
			MC_present = new Dictionary();
		}
		
		public function hasAnyPortal():Boolean
		{
			for each(var sliver:AggregateSliver in slice.aggregateSlivers.collection)
			{
				if(portal_url[sliver.manager.id.full] != null
					&& portal_url[sliver.manager.id.full].length > 0)
					return true;
			}
			return false;
		}
		
		/**
		 * Opens a browser to the instools portal site
		 * 
		 * @param slice
		 * 
		 */
		public function goToPortal():void
		{
			var sh:SHA1 = new SHA1();
			var out:String = Hex.fromArray(sh.hash(Hex.toArray(Hex.fromString(GeniMain.geniUniverse.user.password))));
			//var boo:String = "secretkey";
			//var out:String = Util.rc4encrypt(boo,data);
			//out = encodeURI(out);
			var userinfo:Array = GeniMain.geniUniverse.user.hrn.split(".");
			var portalURL:String = "https://portal.uky.emulab.net/geni/portal/log_on_slice.php";
			var portalVars:URLVariables = new URLVariables();
			portalVars.user = userinfo[1];
			portalVars.cert = userinfo[0];
			portalVars.slice = slice.Name;
			portalVars.pass = out;
			var req:URLRequest = new URLRequest(portalURL);
			req.data = portalVars;
			navigateToURL(req, "_blank");
		}
	}
}