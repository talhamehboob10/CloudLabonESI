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
	import com.flack.emulab.resources.EmulabUser;
	import com.flack.emulab.resources.NamedObject;
	import com.flack.emulab.resources.sites.EmulabManager;

	/**
	 * Container for slivers
	 * 
	 * @author mstrum
	 * 
	 */
	public class Experiment extends NamedObject
	{
		// http://www.emulab.net/doc/docwrapper.php3?docname=states.html
		public static const STATE_NA:String = "N/A";
		static public const STATE_ACTIVATING:String = "activating";
		static public const STATE_TESTING:String = "testing";
		static public const STATE_ACTIVE:String = "active";
		static public const STATE_SWAPPING:String = "swapping";
		static public const STATE_NEW:String = "new";
		static public const STATE_PRERUN:String = "prerun";
		static public const STATE_SWAPPED:String = "swapped";
		static public const STATE_TERMINATING:String = "terminating";
		static public const STATE_TERMINATED:String = "terminated";
		
		static public const ROUTING_STATIC:String = "Static";
		static public const ROUTING_MANUAL:String = "Manual";
		static public const ROUTING_SESSION:String = "Session";
		
		public var creator:EmulabUser = null;
		public var manager:EmulabManager = null;
		public var pid:String = "";
		public var gid:String = "";
		public var description:String = "";
		public var nsfile:String = "";
		public var state:String = "";
		private var unsubmittedChanges:Boolean = true;
		
		// Manifest stuff
		public var virtualTopology:Object;
		public var viz:Object;
		
		// If set, ignores the rest
		public var elabinelab:ElabInElab = null;
		
		public var forceEndNodeShaping:Boolean = false;
		public var useEndNodeShaping:Boolean = false;
		public var routing:String = "";
		public var tarFiles:Vector.<TarFile> = null;
		public var virtualTypes:Vector.<VirtualType> = null;
		public var useLatestWaData:Boolean = false;
		
		public var waSolverWeightDelay:int = 0;
		public var waSolverWeightBandwidth:int = 0;
		public var waSolverWeightLossRate:int = 0;
		
		public var syncServer:VirtualNode;
		
		public var firewall:Firewall = null;
		
		public var environmentVariables:Vector.<NameValuePair> = null;
		
		public var delayOs:String = "";
		public var jailOs:String = "";
		
		public var nodes:VirtualNodeCollection;
		public var links:VirtualLinkCollection;
		public var trafficFlows:Vector.<TrafficFlow> = new Vector.<TrafficFlow>();
		// events?
		
		public function get StateFinalized():Boolean
		{
			return state == STATE_SWAPPED
				|| state == STATE_ACTIVE
				|| state == STATE_TERMINATED;
		}
		
		public function get UnsubmittedChanges():Boolean
		{
			if(unsubmittedChanges)
				return true;
			if(nodes.UnsubmittedChanges)
				return true;
			if(links.UnsubmittedChanges)
				return true;
			// trafficFlows, etc.
			return false;
		}
		public function set UnsubmittedChanges(value:Boolean):void
		{
			unsubmittedChanges = value;
		}
		
		public function Experiment(newManager:EmulabManager, newName:String = "")
		{
			super(newName);
			manager = newManager;
			clearComponents();
		}
		
		public function getByName(newName:String):*
		{
			var obj:* = nodes.getByName(newName);
			if(obj != null) return obj;
			// interfaces?
			obj = links.getByName(newName);
			if(obj != null) return obj;
			return null;
		}
		
		public function isIdUnique(obj:*, testId:String):Boolean
		{
			var result:* = nodes.getByName(testId);
			if(result != null && result != obj)
				return false;
			// interfaces?
			result = links.getByName(testId);
			if(result != null && result != obj)
				return false;
			return true;
		}
		
		public function getUniqueId(obj:*, base:String, start:int = 0):String
		{
			var start:int = start;
			var highest:int = start;
			while(!links.isIdUnique(obj, base + highest))
				highest++;
			while(!nodes.isIdUnique(obj, base + highest))
				highest++;
			if(name == base + highest)
				highest++;
			if(highest > start)
				return getUniqueId(obj, base, highest);
			else
				return base + highest;
		}
		
		/**
		 * Removes everything from the slice
		 * 
		 */
		public function removeAll():void
		{
			clearComponents();
		}
		
		public function clearComponents():void
		{
			nodes = new VirtualNodeCollection();
			links = new VirtualLinkCollection();
		}
		
		public function resetToLast():void
		{
			// reset other things?
			loadViz();
			loadVirtualTopology();
		}
			
		public function loadVirtualTopology():void
		{
			// XXX
		}
		
		public function loadViz():void
		{
			// XXX
		}
	}
}