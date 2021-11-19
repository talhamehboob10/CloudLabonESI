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
	import com.flack.geni.RspecUtil;
	import com.flack.geni.plugins.emulab.EmulabOpenVzSliverType;
        import com.flack.geni.plugins.emulab.EmulabXenSliverType;
	import com.flack.geni.plugins.emulab.Pipe;
	import com.flack.geni.plugins.emulab.PipeCollection;
	import com.flack.geni.plugins.emulab.RawPcSliverType;
	import com.flack.geni.resources.DiskImage;
	import com.flack.geni.resources.SliverType;
	import com.flack.geni.resources.SliverTypes;
	import com.flack.geni.resources.physical.HardwareType;
	import com.flack.geni.resources.physical.PhysicalInterface;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.managers.SupportedLinkType;
	import com.flack.geni.resources.sites.managers.SupportedLinkTypeCollection;
	import com.flack.geni.resources.sites.managers.SupportedSliverType;
	import com.flack.geni.resources.virt.extensions.MCInfo;
	import com.flack.geni.resources.virt.extensions.NodeFlackInfo;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.utils.StringUtil;

	/**
	 * Resource within a slice
	 * 
	 * @author mstrum
	 * 
	 */
	public class VirtualNode extends VirtualComponent
	{
		public var physicalId:IdnUrn = new IdnUrn();
		public function get Physical():PhysicalNode
		{
			if(physicalId.full.length > 0)
				return manager.nodes.getById(physicalId.full);
			else
				return null;
		}
		public function set Physical(newPhysicalNode:PhysicalNode):void
		{
			if(newPhysicalNode == null)
			{
				physicalId = new IdnUrn();
				return;
			}
			physicalId = new IdnUrn(newPhysicalNode.id.full);
			
			manager = newPhysicalNode.manager as GeniManager;
			exclusive = newPhysicalNode.exclusive;
			if(clientId.length == 0)
			{
				if(slice.isIdUnique(this, newPhysicalNode.name))
					clientId = manager.makeValidClientIdFor(newPhysicalNode.name);
				else
					clientId = slice.getUniqueId(this, manager.makeValidClientIdFor(newPhysicalNode.name+"-"));
			}
			
			// Set sliver type to known type if it's there
			if(newPhysicalNode.exclusive && newPhysicalNode.sliverTypes.getByName(RawPcSliverType.TYPE_RAWPC_V2) != null)
			{
				sliverType.name = RawPcSliverType.TYPE_RAWPC_V2;
				sliverType.diskImages = newPhysicalNode.sliverTypes.getByName(RawPcSliverType.TYPE_RAWPC_V2).diskImages;
			}
			else if(!newPhysicalNode.exclusive && newPhysicalNode.sliverTypes.getByName(EmulabOpenVzSliverType.TYPE_EMULABOPENVZ) != null)
			{
				sliverType.name = EmulabOpenVzSliverType.TYPE_EMULABOPENVZ;
				sliverType.diskImages = newPhysicalNode.sliverTypes.getByName(EmulabOpenVzSliverType.TYPE_EMULABOPENVZ).diskImages;
			}
                        else if(!newPhysicalNode.exclusive && newPhysicalNode.sliverTypes.getByName(EmulabXenSliverType.TYPE_EMULABXEN) != null)
                        {
                                sliverType.name = EmulabXenSliverType.TYPE_EMULABXEN;
                                sliverType.diskImages = newPhysicalNode.sliverTypes.getByName(EmulabXenSliverType.TYPE_EMULABXEN).diskImages;
                        }
                        else if(!newPhysicalNode.exclusive && newPhysicalNode.sliverTypes.getByName('XOSmall') != null)
                        {
                                sliverType.name = 'XOSmall';
                                sliverType.diskImages = newPhysicalNode.sliverTypes.getByName('XOSmall').diskImages;
                        }
			else if(newPhysicalNode.sliverTypes.length > 0)
			{
				sliverType.name = newPhysicalNode.sliverTypes.collection[0].name;
				sliverType.diskImages = newPhysicalNode.sliverTypes.collection[0].diskImages;
			}
			
			unsubmittedChanges = true;
		}
		public function get Bound():Boolean
		{
			return physicalId.full.length > 0;
		}
		
		public var exclusive:Boolean;
		public function get Vm():Boolean
		{
			var supportedSliverType:SupportedSliverType = manager.supportedSliverTypes.getByName(sliverType.name);
			// Detectable
			if(supportedSliverType == null)
				return supportedSliverType.supportsShared;
			// Hardcoded if detectable setting isn't available
			else
			{
				return hardwareType.name.indexOf("vm") > -1
					|| (Physical != null && !Physical.exclusive)
					|| manager.supportedSliverTypes.getByName(sliverType.name).supportsShared;
			}
			
		}
		
		public var superNode:VirtualNode;
		public var subNodes:VirtualNodeCollection;
		
		public var manager:GeniManager;
		
		[Bindable]
		public var interfaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
		public function get HasUsableExperimentalInterface():Boolean
		{
			var supportedSliverType:SupportedSliverType = manager.supportedSliverTypes.getByName(sliverType.name);
			if(!Bound || Physical == null)
			{
				if(supportedSliverType == null)
					return true;
				else
					return supportedSliverType.supportsInterfaces;
			}
			else
			{
				if(supportedSliverType != null && supportedSliverType.interfacesUnadvertised)
					return true;
			}
			
			for each (var candidate:PhysicalInterface in Physical.interfaces.collection)
			{
				if (candidate.role != PhysicalInterface.ROLE_CONTROL)
				{
					// Use if not bound already
					if(slice.nodes.getInterfaceBoundTo(candidate) == null)
						return true;
				}
			}
			return false;
		}
		public var emulabRoutableControlIp:Boolean = false;
		
		public var host:Host = new Host();
		
		// Sliver
		[Bindable]
		public var sliverType:SliverType;
		
		// Capabilities
		public var hardwareType:HardwareType = new HardwareType();
		
		// Services
		public var services:Services = new Services();
		
		// Flack extension
		public var flackInfo:NodeFlackInfo = new NodeFlackInfo();
		
		// Remove when uky creates an extension
		public var mcInfo:MCInfo;
		
		/**
		 * 
		 * @param newSlice Slice of the node
		 * @param owner Manager where the node is located
		 * @param newName Name
		 * @param newExclusive Exclusivity
		 * @param newSliverType Sliver type
		 * 
		 */
		public function VirtualNode(newSlice:Slice,
									owner:GeniManager = null,
									newName:String = "",
									newExclusive:Boolean = true,
									newSliverType:String = "")
		{
			super(newSlice, owner == null ? newName : owner.makeValidClientIdFor(newName));
			
			manager = owner;
			sliverType = new SliverType(newSliverType);
			exclusive = newExclusive;
		}
		
		public function allocateExperimentalInterface():VirtualInterface
		{
			var supportedSliverType:SupportedSliverType = manager.supportedSliverTypes.getByName(sliverType.name);
			if(!Bound ||
				Physical == null ||
				(supportedSliverType != null &&
					supportedSliverType.interfacesUnadvertised &&
					supportedSliverType.supportsInterfaces))
			{
				return new VirtualInterface(this);
			}
			else
			{
				for each (var candidate:PhysicalInterface in Physical.interfaces.collection)
				{
					if (candidate.role == PhysicalInterface.ROLE_EXPERIMENTAL)
					{
						// Use if not bound already
						if(slice.nodes.getInterfaceBoundTo(candidate) == null)
						{
							var newPhysicalInterface:VirtualInterface = new VirtualInterface(this);
							newPhysicalInterface.Physical = candidate;
							return newPhysicalInterface;
						}
					}
				}
			}
			return null;
		}

		// XXX situations when this can't happen and return failed?
		public function switchTo(newManager:GeniManager):void
		{
			if(newManager == manager)
				return;
			if(manager == null)
			{
				manager = newManager;
				return;
			}
			var newSliver:AggregateSliver = slice.aggregateSlivers.getOrCreateByManager(newManager, slice);
			var oldSliver:AggregateSliver = slice.aggregateSlivers.getOrCreateByManager(manager, slice);
			var oldManager:GeniManager = manager;
			manager = newManager;
			oldSliver.UnsubmittedChanges = true;
			
			var connectedLinks:VirtualLinkCollection = interfaces.Links;
			for each(var vl:VirtualLink in connectedLinks.collection)
			{
				var supportedTypes:SupportedLinkTypeCollection = vl.interfaceRefs.Interfaces.Managers.CommonLinkTypes;
				// Link type not valid anymore, change
				if(supportedTypes.getByName(vl.type.name) == null)
				{
					var selectedType:SupportedLinkType = supportedTypes.preferredType(vl.interfaceRefs.length);
					if(selectedType != null)
						vl.changeToType(selectedType);
					// Link not valid anymore
					else
						vl.removeNode(this);
				}
			}
		}
		
		public function removeFromSlice():void
		{
			// Remove subnodes
			if(subNodes != null)
			{
				for each(var sub:VirtualNode in subNodes.collection)
					sub.removeFromSlice();
			}
				
			// Remove connections with links
			while(interfaces.length > 0)
			{
				var iface:VirtualInterface = interfaces.collection[0];
				while(iface.links.length > 0)
				{
					var removeLink:VirtualLink = iface.links.collection[0];
					removeLink.removeInterface(iface);
					if(removeLink.interfaceRefs.length <= 1)
						removeLink.removeFromSlice();
				}
				interfaces.remove(iface);
			}
			
			var aggregateSliver:AggregateSliver = slice.aggregateSlivers.getOrCreateByManager(manager, slice);
			aggregateSliver.UnsubmittedChanges = true;
			
			slice.nodes.remove(this);
			
			if(!Sliver.isAllocated(aggregateSliver.AllocationState) && aggregateSliver.Nodes.length == 0)
				aggregateSliver.removeFromSlice();
		}
		
		public function UnboundCloneFor(newSlice:Slice):VirtualNode
		{
			var newClone:VirtualNode = new VirtualNode(newSlice, manager, "", exclusive, sliverType.name);
			if(!newClone.flackInfo.unbound)
			{
				if(Vm)
					newClone.physicalId.full = physicalId.full;
			}
			if(newSlice.isIdUnique(newClone, clientId))
				newClone.clientId = clientId;
			else
				newClone.clientId = newClone.slice.getUniqueId(newClone, StringUtil.makeSureEndsWith(clientId,"-"));
			newClone.sliverType = sliverType.Clone;
			if(hardwareType.name.length > 0)
			{
				newClone.hardwareType.name = hardwareType.name;
				newClone.hardwareType.slots = hardwareType.slots;
			}
			
			if(services.executeServices != null)
			{
				newClone.services.executeServices = new Vector.<ExecuteService>();
				for each(var executeService:ExecuteService in services.executeServices)
				{
					var newExecute:ExecuteService = new ExecuteService(executeService.command, executeService.shell);
					newExecute.extensions = executeService.extensions.Clone;
					newClone.services.executeServices.push(newExecute);
				}
			}
			
			if(services.installServices != null)
			{
				newClone.services.installServices = new Vector.<InstallService>();
				for each(var installService:InstallService in services.installServices)
				{
					var newInstall:InstallService = new InstallService(installService.url, installService.installPath, installService.fileType);
					newInstall.extensions = installService.extensions.Clone;
					newClone.services.installServices.push(newInstall);
				}
			}
			newClone.extensions = extensions.Clone;
			// Remove the emulab extensions, it's just manifest stuff
			if(newClone.extensions.spaces != null)
			{
				for(var i:int = 0; i < newClone.extensions.spaces.length; i++)
				{
					if(newClone.extensions.spaces.collection[i].namespace.uri == RspecUtil.emulabNamespace.uri)
					{
						newClone.extensions.spaces.remove(newClone.extensions.spaces.collection[i]);
						i--;
					}
				}
			}
			return newClone;
		}
		
		override public function toString():String
		{
			var result:String = "[VirtualNode "+SliverProperties
				+",\n\t\tClientID="+clientId
				+",\n\t\tComponentID="+(Bound ? physicalId.full : "")
				+",\n\t\tExclusive="+exclusive
				+",\n\t\tManagerID="+manager.id.full
				+",\n\t\tHost="+host.name
				+",\n\t\tSliverType="+sliverType.name
				+",\n\t\tDiskImage="+(sliverType.selectedImage != null ? sliverType.selectedImage.id.full : "")
				+",\n\t\tHardwareType="+hardwareType
				+",\n\t\tFlackX="+flackInfo.x
				+",\n\t\tFlackY="+flackInfo.y
				+",\n\t\tFlackUnbound="+flackInfo.unbound
				+",\n\t\t]";
			// XXX Services
			if(interfaces.length > 0)
			{
				result += "\n\t[Interfaces]";
				for each(var iface:VirtualInterface in interfaces.collection)
				result += "\n\t\t"+iface.toString();
				result += "\n\t[/Interfaces]";
			}
			return result + "\n\t[/VirtualNode]";
		}
	}
}