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

package com.flack.shared.resources.sites
{
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.utils.ColorUtil;
	import com.flack.shared.utils.NetUtil;
	
	/**
	 * Manager within the GENI world
	 * 
	 * @author mstrum
	 * 
	 */
	public class FlackManager extends IdentifiableObject
	{
		// Denotes the status the manager is in
		public static const STATUS_UNKOWN:int = 0;
		public static const STATUS_INPROGRESS:int = 1;
		public static const STATUS_VALID:int = 2;
		public static const STATUS_FAILED:int = 3;
		
		// Why did it fail?
		public static const FAIL_GENERAL:int = 0;
		public static const FAIL_NOTSUPPORTED:int = 1;
		
		// Meta info
		[Bindable]
		public var url:String = "";
		public function get Hostname():String
		{
			return NetUtil.tryGetBaseUrl(url);
		}
		
		[Bindable]
		public var hrn:String = "";
		
		public var api:ApiDetails;
		public var apis:ApiDetailsCollection = new ApiDetailsCollection();
		
		// Resources
		public var advertisement:Rspec = null;
		
		// State
		private var status:int = STATUS_UNKOWN;
		public function get Status():int
		{
			return status;
		}
		public function set Status(value:int):void
		{
			if(value == status)
				return;
			status = value;
			SharedMain.sharedDispatcher.dispatchChanged(
				FlackEvent.CHANGED_MANAGER,
				this,
				FlackEvent.ACTION_STATUS
			);
		}
		
		public var colorIdx:int = -1;
		
		public var errorType:int = 0;
		[Bindable]
		public var errorMessage:String = "";
		public var errorDescription:String = "";
		
		/**
		 * 
		 * @param newType Type
		 * @param newApi API type
		 * @param newId IDN-URN
		 * @param newHrn Human-readable name
		 * 
		 */
		public function FlackManager(newApi:int = 0,
									newId:String = "",
									newHrn:String = "")
		{
			super(newId);
			api = new ApiDetails(newApi);
			hrn = newHrn;
			
			colorIdx = ColorUtil.getColorIdxFor(id.authority);
		}
		
		/**
		 * 
		 * @return TRUE if it appears the Flash socket security policy isn't installed
		 * 
		 */
		public function mightNeedSecurityException():Boolean
		{
			return errorMessage.search("#2048") > -1;
		}
		
		/**
		 * Clears components, the advertisement, status, and error details
		 * 
		 */
		public function clear():void
		{
			advertisement = null;
			Status = STATUS_UNKOWN;
			errorMessage = "";
			errorDescription = "";
		}
		
		/**
		 * 
		 * @param value Desired client ID
		 * @return Valid client ID usable at this manager
		 * 
		 */
		public function makeValidClientIdFor(value:String):String
		{
			return value;
		}
		
		override public function toString():String
		{
			var result:String = "[FlackManager ID=" + id.full
				+ ", Url=" + url
				+ ", Hrn=" + hrn
				+ ", Api=" + api.type
				+ ", Status=" + Status + "]\n";
			return result += "[/FlackManager]";
		}
	}
}