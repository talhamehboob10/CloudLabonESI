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
	import com.flack.geni.resources.Extensions;
	import com.flack.geni.resources.docs.GeniCredential;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.docs.RspecVersion;
	
	import flash.utils.Dictionary;

	/**
	 * Holds resources for a slice at one manager
	 * 
	 * @author mstrum
	 * 
	 */
	public class AggregateSliver extends IdentifiableObject
	{		
		[Bindable]
		public var slice:Slice;
		[Bindable]
		public var manager:GeniManager;
		
		public var credential:GeniCredential;
		
		[Bindable]
		public var forceUseInputRspecInfo:RspecVersion;
		
		/**
		 * 
		 * @return Manually selected version, slice-selected version, or the max supported version
		 * 
		 */
		public function get UseInputRspecInfo():RspecVersion
		{
			if(forceUseInputRspecInfo != null)
				return forceUseInputRspecInfo;
			else
			{
				if(manager.inputRspecVersions.get(slice.useInputRspecInfo.type, slice.useInputRspecInfo.version) != null)
					return slice.useInputRspecInfo;
				else
					return manager.inputRspecVersions.UsableRspecVersions.MaxVersion;
			}
		}
		
		public function clearStates():void
		{
			Components.clearStates();
		}
		
		public var idsToSlivers:Dictionary = new Dictionary();
		
		public var ticket:Rspec = null;
		public var manifest:Rspec = null;
		
		// Convenience methods
		public function get AllocationState():String
		{
			// Get states for slivers which may have been removed on the canvas.
			var components:VirtualComponentCollection = Components;
			var removedSlivers:SliverCollection = new SliverCollection();
			var states:Vector.<String> = new Vector.<String>();
			for(var sliverId:String in idsToSlivers)
			{
				var component:VirtualComponent = components.getComponentById(sliverId);
				// New component has been added which has not been allocated.
				if(component == null)
				{
					var sliver:Sliver = idsToSlivers[sliverId];
					if(states.indexOf(sliver.allocationState) == -1)
					{
						states.push(sliver.allocationState);
					}
				}
			}
			
			// Get states for components.
			for each(var virtualComponent:VirtualComponent in components.collection)
			{
				if(states.indexOf(virtualComponent.allocationState) == -1)
				{
					states.push(virtualComponent.allocationState);
				}
			}
			
			return Sliver.combineAllocationStates(states);
		}
		public function set AllocationState(value:String):void
		{
			var components:VirtualComponentCollection = Components;
			for each(var component:VirtualComponent in components.collection)
				component.allocationState = value;
		}
		public function get OperationalState():String
		{
			// Get states for slivers which may have been removed on the canvas.
			var components:VirtualComponentCollection = Components;
			var removedSlivers:SliverCollection = new SliverCollection();
			var states:Vector.<String> = new Vector.<String>();
			for(var sliverId:String in idsToSlivers)
			{
				var component:VirtualComponent = components.getComponentById(sliverId);
				// New component has been added which has not been allocated.
				if(component == null)
				{
					var sliver:Sliver = idsToSlivers[sliverId];
					if(states.indexOf(sliver.operationalState) == -1)
					{
						states.push(sliver.operationalState);
					}
				}
			}
			
			for each(var virtualComponent:VirtualComponent in components.collection)
			{
				if(states.indexOf(virtualComponent.operationalState) == -1)
				{
					states.push(virtualComponent.operationalState);
				}
			}
			
			return Sliver.combineOperationalStates(states);
		}
		public function set OperationalState(value:String):void
		{
			var components:VirtualComponentCollection = Components;
			for each(var component:VirtualComponent in components.collection)
				component.operationalState = value;
		}
		public function get EarliestExpiration():Date
		{
			return Components.EarliestExpiration;
		}
		public function set Expires(value:Date):void
		{
			var components:VirtualComponentCollection = Components;
			for each(var component:VirtualComponent in components.collection)
				component.expires = value;
		}
		
		private var unsubmittedChanges:Boolean = true;
		public function get UnsubmittedChanges():Boolean
		{
			if(unsubmittedChanges)
				return true;
			if(Components.UnsubmittedChanges)
				return true;
			return false;
		}
		public function set UnsubmittedChanges(value:Boolean):void
		{
			unsubmittedChanges = value;
		}
		
		public var extensions:Extensions = new Extensions();
		
		public function get Nodes():VirtualNodeCollection
		{
			if(slice != null)
				return slice.nodes.getByManager(manager);
			return new VirtualNodeCollection();
		}
		
		public function get Links():VirtualLinkCollection
		{
			if(slice != null)
				return slice.links.getConnectedToManager(manager);
			return new VirtualLinkCollection();
		}
		
		public function get Components():VirtualComponentCollection
		{
			var components:VirtualComponentCollection = new VirtualComponentCollection();
			components.addAll(Nodes.collection);
			components.addAll(Links.collection);
			return components;
		}
		
		public function get DeletedSlivers():SliverCollection
		{
			var deletedSlivers:SliverCollection = new SliverCollection();
			var components:VirtualComponentCollection = Components;
			for (var sliverId:String in idsToSlivers)
			{
				var sliver:Sliver = idsToSlivers[sliverId];
				if(Sliver.isAllocated(sliver.allocationState) && components.getById(sliverId))
					deletedSlivers.add(sliver);
			}
			return deletedSlivers;
		}
		
		/**
		 * 
		 * @param owner Slice for the sliver
		 * @param newManager Manager where the sliver lies
		 * 
		 */
		public function AggregateSliver(owner:Slice,
							   newManager:GeniManager = null)
		{
			super();
			slice = owner;
			manager = newManager;
		}
		
		/**
		 * Removes status and manifests from everything from this sliver, BUT not the sliver's manifest
		 * 
		 */
		public function markStaged():void
		{
			// XXX unsubmittedChanges?
			
			Components.markStaged();
		}
		
		public function removeFromSlice():void
		{
			// Remove the nodes
			var aggregateNodes:VirtualNodeCollection = Nodes;
			for each(var node:VirtualNode in aggregateNodes.collection)
			{
				node.removeFromSlice();
			}
			
			// Remove the links (should only be any w/o interfaces to nodes)
			var aggregateLinks:VirtualLinkCollection = Links;
			for each(var link:VirtualLink in aggregateLinks.collection)
			{
				link.managerRefs.remove(manager);
				if(link.managerRefs.length == 0 && link.interfaceRefs.length == 0)
					link.removeFromSlice();
			}

			// unsubmittedChanges = true;
			slice.reportedManagers.remove(manager);
			slice.aggregateSlivers.remove(this);
		}
		
		/**
		 * Sets components to the states of the slivers saved into idsToSlivers.
		 * Note this does not inlude uncommittedChanges.
		 * 
		 */
		public function resetToSlivers():void
		{
			if(idsToSlivers != null)
			{
				var components:VirtualComponentCollection = Components;
				for(var sliverId:String in idsToSlivers)
				{
					var sliver:Sliver = idsToSlivers[sliverId];
					if(sliver == null)
						continue;
					var component:VirtualComponent = components.getComponentById(sliverId);
					if(component == null)
						continue;
					component.copyFrom(sliver);
				}
			}
		}
		
		override public function toString():String
		{
			return "[AggregateSliver ID="+id.full+", Manager="+manager.hrn+
				", Allocation State="+Sliver.readableAllocationState(AllocationState)+
					", Operational State="+Sliver.readableOperationalState(OperationalState)+"]";
		}
	}
}