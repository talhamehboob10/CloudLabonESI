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

package com.flack.geni.resources.virt
{
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.IdnUrn;
	
	public class Sliver extends IdentifiableObject
	{
		public static const EMPTY:String = "";
		public static const STAGED:String = "staged";
		public static const UNKNOWN:String = "unknown";
		public static const MIXED_UNALLOCATED:String = "mixed_unallocated";
		public static const MIXED_ALLOCATED:String = "mixed_allocated";
		public static const MIXED_PROVISIONED:String = "mixed_provisioned";
		public static const MIXED_UPDATING:String = "mixed_updating";
		public static const MIXED_FINISHED:String = "mixed_finished";
		public static const MIXED_CHANGING:String = "mixed_changing";
		
		public static const ALLOCATION_UNALLOCATED:String = "geni_unallocated";
		public static const ALLOCATION_ALLOCATED:String = "geni_allocated";
		public static const ALLOCATION_PROVISIONED:String = "geni_provisioned";
		public static const ALLOCATION_UPDATING:String = "geni_updating";
		public static function isAllocated(state:String):Boolean
		{
			switch(state)
			{
				case ALLOCATION_ALLOCATED:
				case ALLOCATION_PROVISIONED:
				case ALLOCATION_UPDATING:
				case MIXED_PROVISIONED:
				case MIXED_ALLOCATED:
				case MIXED_UPDATING:
					return true;
				default:
					return false;
			}
		}
		public static function isProvisioned(state:String):Boolean
		{
			switch(state)
			{
				case ALLOCATION_PROVISIONED:
				case ALLOCATION_UPDATING:
				case MIXED_PROVISIONED:
				case MIXED_UPDATING:
					return true;
				default:
					return false;
			}
		}
		public static function combineAllocationStates(states:Vector.<String>):String
		{
			if(states.length == 0) return Sliver.EMPTY;
			if(states.length == 1) return states[0];
			if(states.indexOf(Sliver.ALLOCATION_UPDATING) || states.indexOf(Sliver.MIXED_UPDATING))
				return Sliver.MIXED_UPDATING;
			if(states.indexOf(Sliver.ALLOCATION_PROVISIONED) || states.indexOf(Sliver.MIXED_PROVISIONED))
				return Sliver.MIXED_PROVISIONED;
			if(states.indexOf(Sliver.ALLOCATION_ALLOCATED) || states.indexOf(Sliver.MIXED_ALLOCATED))
				return Sliver.MIXED_ALLOCATED;
			return Sliver.MIXED_UNALLOCATED;
		}
		public static function readableAllocationState(value:String):String
		{
			switch(value)
			{
				case ALLOCATION_UNALLOCATED: return "Unallocated";
				case ALLOCATION_ALLOCATED: return "Allocated";
				case ALLOCATION_PROVISIONED: return "Provisioned";
				case ALLOCATION_UPDATING: return "Updating";
				case MIXED_PROVISIONED: return "Mixed (some provisioned)";
				case MIXED_ALLOCATED: return "Mixed (some allocated)";
				case MIXED_UNALLOCATED: return "Mixed (non allocated)";
				case MIXED_UPDATING: return "Mixed (some updating)";
				case MIXED_CHANGING: return "Mixed (some changing)";
				default: return value;
			}
		}
		
		// Waiting operational states
		public static const OPERATIONAL_PENDING_ALLOCATION:String = "geni_pending_allocation";
		public static const OPERATIONAL_CONFIGURING:String = "geni_configuring";
		public static const OPERATIONAL_STOPPING:String = "geni_stopping";
		public static const OPERATIONAL_READY_BUSY:String = "geni_ready_busy";
		// Final operational states
		public static const OPERATIONAL_NOTREADY:String = "geni_notready";
		public static const OPERATIONAL_READY:String = "geni_ready";
		public static const OPERATIONAL_FAILED:String = "geni_failed";
		public static function combineOperationalStates(states:Vector.<String>):String
		{
			if(states.length == 0) return Sliver.EMPTY;
			if(states.length == 1) return states[0];
			
			// If anything is changing, return mixed changing.
			for each(var sliverState:String in states)
			{
				if(isOperationalStateChanging(sliverState))
					return Sliver.MIXED_CHANGING;
			}
			
			// If anything failed and states aren't changing, return failed.
			if(states.indexOf(Sliver.OPERATIONAL_FAILED) != -1)
				return Sliver.OPERATIONAL_FAILED;
			
			// If unknown is one of the states, return the other state or mixed if more states are present.
			var unknownIdx:int = states.indexOf(Sliver.UNKNOWN);
			if(unknownIdx != -1)
			{
				states.splice(unknownIdx, 1);
				if(states.length == 1)
					return states[0];
				else
					return Sliver.UNKNOWN;
			}
			
			return Sliver.MIXED_FINISHED;
		}
		public static function readableOperationalState(value:String):String
		{
			switch(value)
			{
				case OPERATIONAL_PENDING_ALLOCATION: return "Pending allocation";
				case OPERATIONAL_CONFIGURING: return "Configuring";
				case OPERATIONAL_STOPPING: return "Stopping";
				case OPERATIONAL_READY_BUSY: return "Ready (busy)";
				case OPERATIONAL_NOTREADY: return "Not ready";
				case OPERATIONAL_READY: return "Ready";
				case OPERATIONAL_FAILED: return "Failed";
				case STAGED: return "Staged";
				case UNKNOWN: return "Unknown";
				case MIXED_FINISHED: return "Mixed (done)";
				case MIXED_CHANGING: return "Mixed (changing)";
				default: return value;
			}
		}
		
		public static function ProtogeniStateStatusToOperationalState(state:String, status:String):String
		{
			if(status == "unknown")
				return UNKNOWN;
			if(status == "failed")
				return OPERATIONAL_FAILED;
			if(status == "ready")
				return OPERATIONAL_READY;
			if(status == "changing" ||
				(state == "started" && status == "notready"))
				return OPERATIONAL_CONFIGURING;
			if(state == "stopped") return OPERATIONAL_NOTREADY;
			return UNKNOWN;
		}
		public static function GeniStatusToOperationalState(status:String):String
		{
			if(status == "unknown") return UNKNOWN;
			if(status == "configuring") return OPERATIONAL_CONFIGURING;
			if(status == "ready") return OPERATIONAL_READY;
			if(status == "failed") return OPERATIONAL_FAILED;
			return UNKNOWN;
		}
		
		public static function describeState(printAllocationState:String,
											 printOperationalState:String):String
		{
			return readableAllocationState(printAllocationState) + "/" +
				readableOperationalState(printOperationalState);
		}
		
		public static function isOperationalStateChanging(testOperationalState:String):Boolean
		{
			switch(testOperationalState)
			{
				case OPERATIONAL_PENDING_ALLOCATION:
				case OPERATIONAL_CONFIGURING:
				case OPERATIONAL_STOPPING:
				case OPERATIONAL_READY_BUSY:
				case MIXED_CHANGING:
					return true;
			}
			return false;
		}
		
		[Bindable]
		public var slice:Slice;
		
		[Bindable]
		public var allocationState:String;
		public var nextAllocationState:String;
		[Bindable]
		public var operationalState:String;
		[Bindable]
		public var error:String;
		public function clearState():void
		{
			allocationState = ALLOCATION_UNALLOCATED;
			nextAllocationState = "";
			operationalState = STAGED;
			error = "";
		}
		
		public var expires:Date = null;
		
		public function markStaged():void
		{
			clearState();
			id = new IdnUrn();
		}
		
		public function Sliver(newId:String="",
							   newSlice:Slice = null,
							   newAllocationState:String = "",
							   newOperationalState:String = "")
		{
			super(newId);
			slice = newSlice;
			clearState();
			if(newAllocationState.length > 0)
				allocationState = newAllocationState;
			if(newOperationalState.length > 0)
				operationalState = newOperationalState;
		}
		
		public function copyFrom(sliver:Sliver):void
		{
			allocationState = sliver.allocationState;
			operationalState = sliver.operationalState;
			expires = sliver.expires;
			error = sliver.error;
		}
		
		public function get ClonedSliver():Sliver
		{
			var sliver:Sliver = new Sliver(id.full, slice, allocationState, operationalState);
			sliver.error = error;
			sliver.expires = expires;
			return sliver;
		}
		
		override public function toString():String
		{
			return "[Sliver ID="+SliverProperties+"]";
		}
		
		public function SliverProperties():String
		{
			return "ID="+id.full+", Allocation State="+readableAllocationState(allocationState)+
				", Operational State="+readableOperationalState(operationalState)+
				(error.length > 1 ? ", Error="+error : "");
		}
	}
}