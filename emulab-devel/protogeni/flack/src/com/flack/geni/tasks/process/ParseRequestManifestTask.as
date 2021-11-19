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

package com.flack.geni.tasks.process
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.RspecUtil;
	import com.flack.geni.plugins.emulab.EmulabBbgSliverType;
	import com.flack.geni.plugins.emulab.EmulabOpenVzSliverType;
	import com.flack.geni.plugins.emulab.EmulabXenSliverType;
	import com.flack.geni.plugins.emulab.RawPcSliverType;
	import com.flack.geni.plugins.shadownet.JuniperRouterSliverType;
	import com.flack.geni.resources.DiskImage;
	import com.flack.geni.resources.Property;
	import com.flack.geni.resources.SliverType;
	import com.flack.geni.resources.SliverTypes;
	import com.flack.geni.resources.physical.HardwareType;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.AggregateSliver;
	import com.flack.geni.resources.virt.ComponentHop;
	import com.flack.geni.resources.virt.ExecuteService;
	import com.flack.geni.resources.virt.GeniManagerReference;
	import com.flack.geni.resources.virt.Host;
	import com.flack.geni.resources.virt.InstallService;
	import com.flack.geni.resources.virt.Ip;
	import com.flack.geni.resources.virt.LinkType;
	import com.flack.geni.resources.virt.LoginService;
	import com.flack.geni.resources.virt.Services;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.geni.resources.virt.VirtualInterfaceCollection;
	import com.flack.geni.resources.virt.VirtualInterfaceReference;
	import com.flack.geni.resources.virt.VirtualLink;
	import com.flack.geni.resources.virt.VirtualLinkCollection;
	import com.flack.geni.resources.virt.VirtualNode;
	import com.flack.geni.resources.virt.VirtualNodeCollection;
	import com.flack.geni.resources.virt.extensions.MCInfo;
	import com.flack.geni.resources.virt.extensions.SliceFlackInfo;
	import com.flack.geni.resources.virt.extensions.slicehistory.SliceHistory;
	import com.flack.geni.resources.virt.extensions.slicehistory.SliceHistoryItem;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingHop;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingLink;
	import com.flack.geni.resources.virt.extensions.stitching.StitchingPath;
	import com.flack.geni.resources.virt.extensions.stitching.SwitchingCapabilityDescriptor;
	import com.flack.geni.resources.virt.extensions.stitching.SwitchingCapabilitySpecificInfoL2sc;
	import com.flack.geni.resources.virt.extensions.stitching.SwitchingCapabilitySpecificInfoLsc;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.resources.docs.Rspec;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.CompressUtil;
	import com.flack.shared.utils.DateUtil;
	import com.flack.shared.utils.StringUtil;
	
	import flash.system.System;
	import flash.utils.Dictionary;
	
	/**
	 * Parses the given RSPEC into the sliver's slice
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ParseRequestManifestTask extends Task
	{
		public var aggregateSliver:AggregateSliver;
		public var rspec:Rspec;
		public var markUnsubmitted:Boolean;
		public var parseManifest:Boolean;
		private var xmlDocument:XML;
		
		/**
		 * 
		 * @param newSliver Sliver for which to parse the rspec for
		 * @param newRspec Rspec to parse
		 * @param shouldMarkUnsubmitted Mark all resources as unsubmitted, must be false to import manifest values
		 * 
		 */
		public function ParseRequestManifestTask(newSliver:AggregateSliver,
												 newRspec:Rspec,
												 shouldMarkUnsubmitted:Boolean = false,
												 shouldParseManifest:Boolean = false)
		{
			super(
				"Process RSPEC @ " + newSliver.manager.hrn,
				"Process the request/manifest for a sliver",
				"Process RSPEC",
				null,
				0,
				0,
				false,
				[newSliver, newSliver.slice, newSliver.manager]
			);
			aggregateSliver = newSliver;
			rspec = newRspec;
			markUnsubmitted = shouldMarkUnsubmitted;
			parseManifest = shouldParseManifest;
		}
		
		override protected function runCleanup():void
		{
			System.disposeXML(xmlDocument);
		}
		
		override protected function runStart():void
		{
			try
			{
				xmlDocument = new XML(rspec.document);
				//var namespaces:Array = xmlDocument.namespaceDeclarations();
			}
			catch(e:Error)
			{
				afterError(
					new TaskError(
						"Bad XML",
						TaskError.CODE_PROBLEM
					)
				);
				return;
			}
			
			try
			{
				var defaultNamespace:Namespace = xmlDocument.namespace();
				switch(defaultNamespace.uri)
				{
					case RspecUtil.rspec01Namespace:
					case RspecUtil.rspec01MalformedNamespace:
						rspec.info = new RspecVersion(RspecVersion.TYPE_PROTOGENI, 0.1);
						break;
					case RspecUtil.rspec02Namespace:
					case RspecUtil.rspec02MalformedNamespace:
						rspec.info = new RspecVersion(RspecVersion.TYPE_PROTOGENI, 0.2);
						break;
					case RspecUtil.rspec2Namespace:
						rspec.info = new RspecVersion(RspecVersion.TYPE_PROTOGENI, 2);
						break;
					case RspecUtil.rspec3Namespace:
						rspec.info = new RspecVersion(RspecVersion.TYPE_GENI, 3);
						break;
					default:
						afterError(
							new TaskError(
								"Namespace not supported. Manifest RSPEC with the namespace '"
								+defaultNamespace.uri+ "' is not supported.",
								TaskError.CODE_PROBLEM
							)
						);
						return;
				}
				aggregateSliver.slice.useInputRspecInfo = new RspecVersion(rspec.info.type, rspec.info.version);
				
				aggregateSliver.markStaged();
				
				var nodesById:Dictionary = new Dictionary();
				var interfacesById:Dictionary = new Dictionary();
				
				var localName:String;
				
				aggregateSliver.extensions.buildFromOriginal(
					xmlDocument,
					[
						defaultNamespace.uri,
						RspecUtil.xsiNamespace.uri,
						RspecUtil.flackNamespace.uri,
						RspecUtil.clientNamespace.uri,
						RspecUtil.historyNamespace.uri
					]
				);
				
				for each(var nodeXml:XML in xmlDocument.defaultNamespace::node)
				{
					// Get IDs
					var managerIdString:String = "";
					var componentIdString:String = "";
					var clientIdString:String = "";
					var sliverIdString:String = "";
					
					if(rspec.info.version < 1)
					{
						if(nodeXml.@component_manager_urn.length() == 1)
							managerIdString = String(nodeXml.@component_manager_urn);
						else if(nodeXml.@component_manager_uuid.length() == 1)
							managerIdString = String(nodeXml.@component_manager_uuid);
						
						if(nodeXml.@component_urn.length() == 1)
							componentIdString = String(nodeXml.@component_urn);
						else if(nodeXml.@component_uuid.length() == 1)
							componentIdString = String(nodeXml.@component_uuid);
						
						clientIdString = String(nodeXml.@virtual_id);
						
						if(nodeXml.@sliver_urn.length() == 1)
							sliverIdString = String(nodeXml.@sliver_urn);
						else if(nodeXml.@sliver_uuid.length() == 1)
							sliverIdString = String(nodeXml.@sliver_uuid);
					}
					else
					{
						if(nodeXml.@component_manager_id.length() == 1)
							managerIdString = String(nodeXml.@component_manager_id);
						
						if(nodeXml.@component_id.length() == 1)
							componentIdString = String(nodeXml.@component_id);
						
						clientIdString = String(nodeXml.@client_id);
						
						sliverIdString = String(nodeXml.@sliver_id);
					}
					
					// Things without client-ids aren't in the sliver at all...
					if(clientIdString.length == 0)
					{
						addMessage(
							"Skipping node with missing client id",
							"Node with the following manifest is missing a client id:\n" +
							nodeXml.toXMLString(),
							LogMessage.LEVEL_WARNING
						);
						continue;
					}
					
					// Managers must be specified...
					if(managerIdString.length == 0)
					{
						afterError(
							new TaskError(
								"No Manager specified for node described as: " + nodeXml.toXMLString(),
								TaskError.CODE_PROBLEM
							)
						);
						return;
					}
					var managerLookupId : String = sliverIdString;
					if (managerLookupId == null || managerLookupId == '')
					{
						managerLookupId = managerIdString;
					}
					var virtualNodeManager:GeniManager = GeniMain.geniUniverse.managers.getById(managerLookupId);
					if(virtualNodeManager == null)
					{
						afterError(
							new TaskError(
								"Manager with ID '"+managerLookupId+"' was not found for node named " + clientIdString + 
								". You may need to refresh the manager if there is a refresh button next to its name on the left.",
								TaskError.CODE_PROBLEM
							)
						);
						return;
					}
					// Don't add outside nodes, they might not exist
					if(virtualNodeManager != aggregateSliver.manager)
					{
						addMessage(
							"Skipping node from other manager",
							"Skipping " + clientIdString + " which will be parsed in the manifest from manager " + virtualNodeManager
						);
						continue;
					}
					
					if(virtualNodeManager == aggregateSliver.manager && rspec.type == Rspec.TYPE_MANIFEST && parseManifest)
					{
						// nodes from their manager's manifests without sliver_ids aren't in the sliver...
						if(sliverIdString.length == 0)
						{
							addMessage(
								"Skipping node with missing sliver id",
								"Node with client id '" + clientIdString + "' doesn't have a sliver id! " +
								"This may indicate that the manager failed to include the information or the node wasn't allocated.",
								LogMessage.LEVEL_WARNING
							);
							continue;
						}
						
						// component_id should always exist in the node's manager's manifest...
						if(componentIdString.length == 0)
						{
							afterError(
								new TaskError(
									"No Component ID set for node described as: " + nodeXml.toXMLString(),
									TaskError.CODE_PROBLEM
								)
							);
							return;
						}
					}
					
					var virtualNode:VirtualNode = aggregateSliver.slice.getByClientId(clientIdString);
					
					// Node not in the slice, need to add
					if(virtualNode == null)
					{
						virtualNode = new VirtualNode(aggregateSliver.slice, virtualNodeManager);
						aggregateSliver.slice.nodes.add(virtualNode);
					}
					else
						virtualNode.manager = virtualNodeManager;
					
					// Have the full info for this node
					if(markUnsubmitted)
						virtualNode.unsubmittedChanges = true;
					else if(virtualNodeManager == aggregateSliver.manager && rspec.type == Rspec.TYPE_MANIFEST)
						virtualNode.unsubmittedChanges = false;
					
					if(virtualNodeManager == aggregateSliver.manager && rspec.type == Rspec.TYPE_MANIFEST && parseManifest)
					{
						virtualNode.id = new IdnUrn(sliverIdString);
						virtualNode.manifest = nodeXml.toXMLString();
					}
					
					if(componentIdString.length > 0)
					{
						virtualNode.physicalId = new IdnUrn(componentIdString);
						if(virtualNode.Physical == null)
						{
							addMessage(
								"Physical Node with ID '"+componentIdString+"' was not found.",
								"Physical Node with ID '"+componentIdString+"' was not found.",
								LogMessage.LEVEL_WARNING
							);
							// If not looking for manifest info, don't care if exists
							// otherwise clear the component_id if not found
							if(rspec.type != Rspec.TYPE_MANIFEST)
								virtualNode.physicalId.full = "";
						}
					}
					
					virtualNode.clientId = clientIdString;
					
					// Deal with the attributes
					if(rspec.info.version < 1)
					{
						virtualNode.exclusive = String(nodeXml.@exclusive) == "1"
							|| String(nodeXml.@exclusive).toLowerCase() == "true";
						if(parseManifest)
						{
							if(nodeXml.@sshdport.length() == 1) {
								if(virtualNode.services.loginServices == null)
									virtualNode.services.loginServices = new Vector.<LoginService>();
								if(virtualNode.services.loginServices.length == 0)
									virtualNode.services.loginServices.push(new LoginService());
								virtualNode.services.loginServices[0].port = String(nodeXml.@sshdport);
							}
							if(nodeXml.@hostname.length() == 1) {
								if(virtualNode.services.loginServices == null)
									virtualNode.services.loginServices = new Vector.<LoginService>();
								if(virtualNode.services.loginServices.length == 0)
									virtualNode.services.loginServices.push(new LoginService());
								virtualNode.services.loginServices[0].hostname = String(nodeXml.@hostname);
							}
						}
						if(nodeXml.@tarfiles.length() == 1) {
							if(virtualNode.services.installServices == null)
								virtualNode.services.installServices = new Vector.<InstallService>();
							if(virtualNode.services.installServices.length == 0)
								virtualNode.services.installServices.push(new InstallService());
							virtualNode.services.installServices[0].url = String(nodeXml.@tarfiles);
						}
						if(nodeXml.@startup_command.length() == 1) {
							if(virtualNode.services.executeServices == null)
								virtualNode.services.executeServices = new Vector.<ExecuteService>();
							if(virtualNode.services.executeServices.length == 0)
								virtualNode.services.executeServices.push(new ExecuteService());
							virtualNode.services.executeServices[0].command = String(nodeXml.@startup_command);
						}
						if(nodeXml.@virtualization_type.length() == 1)
						{
							switch(String(nodeXml.@virtualization_type))
							{
								case JuniperRouterSliverType.TYPE_JUNIPER_LROUTER:
									virtualNode.sliverType = new SliverType(JuniperRouterSliverType.TYPE_JUNIPER_LROUTER);
									break;
								case SliverTypes.EMULAB_VNODE:
								default:
									if(nodeXml.@virtualization_subtype.length() == 1)
									{
										switch(String(nodeXml.@virtualization_subtype))
										{
											case EmulabOpenVzSliverType.TYPE_EMULABOPENVZ:
												virtualNode.sliverType = new SliverType(EmulabOpenVzSliverType.TYPE_EMULABOPENVZ);
												break;
                                                                                        case EmulabXenSliverType.TYPE_EMULABXEN:
                                                                                                virtualNode.sliverType = new SliverType(EmulabXenSliverType.TYPE_EMULABXEN);
                                                                                                break;
											case EmulabBbgSliverType.TYPE_EMULAB_BBG:
												virtualNode.sliverType = new SliverType(EmulabBbgSliverType.TYPE_EMULAB_BBG);
												break;
											case RawPcSliverType.TYPE_RAWPC_V1:
											default:
												virtualNode.sliverType = new SliverType(RawPcSliverType.TYPE_RAWPC_V2);
												break;
										}
									}
									else
										virtualNode.sliverType = new SliverType(RawPcSliverType.TYPE_RAWPC_V2);
									break;
							}
						}
					}
					else
					{
						virtualNode.exclusive = String(nodeXml.@exclusive) == "true" || String(nodeXml.@exclusive) == "1";
					}
					
					// Hack for INSTOOLS w/o namespace
					if(String(nodeXml.@MC) == "1")
					{
						virtualNode.mcInfo = new MCInfo();
						virtualNode.mcInfo.type = String(nodeXml.@mc_type);
					}
					
					// Get interfaces first
					var interfacesXmllist:XMLList = nodeXml.child(new QName(defaultNamespace, "interface"));
					for each(var interfaceXml:XML in interfacesXmllist)
					{
						var virtualInterfaceClientId:String = "";
						var virtualInterfaceSliverId:String = "";
						if(rspec.info.version < 1)
						{
							if(interfaceXml.@virtual_id.length() == 1)
								virtualInterfaceClientId = String(interfaceXml.@virtual_id);
							if(interfaceXml.@sliver_urn.length() == 1)
								virtualInterfaceSliverId = String(interfaceXml.@sliver_urn);
							else
							{
								// V1 didn't have sliver ids for interfaces...
								virtualInterfaceSliverId = IdnUrn.makeFrom(
									aggregateSliver.manager.id.authority,
									"interface",
									virtualInterfaceClientId).full;
							}
						}
						else
						{
							if(interfaceXml.@client_id.length() == 1)
								virtualInterfaceClientId = String(interfaceXml.@client_id);
							if(interfaceXml.@sliver_id.length() == 1)
								virtualInterfaceSliverId = String(interfaceXml.@sliver_id);
						}
						if(virtualInterfaceClientId.length == 0)
						{
							afterError(
								new TaskError(
									"No Client ID set on interface from node "+ virtualNode.clientId + ".",
									TaskError.CODE_PROBLEM
								)
							);
							return;
						}
						
						var virtualInterface:VirtualInterface = virtualNode.interfaces.getByClientId(virtualInterfaceClientId);
						
						/*
						if(rspec.type == Rspec.TYPE_MANIFEST
							&& virtualNode.manager == aggregateSliver.manager
							&& virtualInterfaceSliverId.length == 0)
						{
							// Interface not really used
							if(virtualInterface != null)
								virtualNode.interfaces.remove(virtualInterface);
							addMessage(
								"Skipping interface " + virtualInterfaceClientId + " with missing sliver id",
								"Interface " + virtualInterfaceClientId + " doesn't have a sliver id and will be discarded.",
								LogMessage.LEVEL_WARNING
							);
							continue;
						}
						*/
						
						if(virtualInterface == null)
						{
							virtualInterface = new VirtualInterface(virtualNode);
							virtualNode.interfaces.add(virtualInterface);
						}
						virtualInterface.clientId = virtualInterfaceClientId;
						if(virtualInterfaceSliverId.length > 0 && parseManifest)
							virtualInterface.id = new IdnUrn(virtualInterfaceSliverId);
						
						if(interfaceXml.@component_id.length() == 1 && IdnUrn.isIdnUrn(String(interfaceXml.@component_id)))
						{
							virtualInterface.physicalId = new IdnUrn(String(interfaceXml.@component_id));
							if(virtualInterface.Physical == null)
							{
								// Switched from error to warning
								addMessage(
									"Interface not found. Physical interface with ID '"+String(interfaceXml.@component_id)+"' was not found.",
									"Interface not found. Physical interface with ID '"+String(interfaceXml.@component_id)+"' was not found.",
									LogMessage.LEVEL_WARNING
								);
							}
						}
						
						if(rspec.info.version >= 2)
						{
							if(parseManifest && interfaceXml.@mac_address.length() == 1)
								virtualInterface.macAddress = String(interfaceXml.@mac_address);
							
							for each(var ipXml:XML in interfaceXml.defaultNamespace::ip)
							{
								virtualInterface.ip.bound = true;
								virtualInterface.ip.address = String(ipXml.@address);
								virtualInterface.ip.type = String(ipXml.@type);
								if(ipXml.@mask.length() == 1)
									virtualInterface.ip.netmask = String(ipXml.@mask);
								else if(ipXml.@netmask.length() == 1)
									virtualInterface.ip.netmask = String(ipXml.@netmask);
								if(virtualNode.manager == aggregateSliver.manager)
									virtualInterface.ip.extensions.buildFromOriginal(ipXml, [defaultNamespace.uri]);
							}
						}
						
						var flackNamespace:Namespace = RspecUtil.flackNamespace;
						for each(var interfaceFlackXml:XML in interfaceXml.flackNamespace::interface_info)
						{
							if(interfaceFlackXml.@addressBound.length() == 1)
							{
								var addressBound:Boolean = String(interfaceFlackXml.@addressBound).toLowerCase() == "true" || String(interfaceFlackXml.@addressBound) == "1";
								if(!addressBound && !parseManifest)
									virtualInterface.ip = new Ip();
							}
							if(interfaceFlackXml.@bound.length() == 1)
							{
								virtualInterface.bound = String(interfaceFlackXml.@bound).toLowerCase() == "true" || String(interfaceFlackXml.@bound) == "1";
							}
						}
						
						if(virtualNode.manager == aggregateSliver.manager)
							virtualInterface.extensions.buildFromOriginal(interfaceXml, [defaultNamespace.uri, RspecUtil.flackNamespace.uri]);
						
						interfacesById[virtualInterface.clientId] = virtualInterface;
						if(virtualInterface.id.full.length > 0)
							interfacesById[virtualInterface.id.full] = virtualInterface;
					}
					
					// Bind interfaces that need it.
					if(rspec.type != Rspec.TYPE_MANIFEST) {
						for each(var interfaceToTest:VirtualInterface in virtualNode.interfaces.collection)
						{
							if(interfaceToTest.physicalId.full.length == 0 && virtualNode.Bound)
							{
								var interfaceToAdd:VirtualInterface = virtualNode.allocateExperimentalInterface();
								if (interfaceToAdd != null) {
									interfaceToTest.physicalId.full = interfaceToAdd.physicalId.full;
								} else {
									addMessage(
										"Experimental interface not available.",
										"Experimental interface not available for " + interfaceToTest.clientId + ".",
										LogMessage.LEVEL_WARNING
									);
								}
							}
						}
					}
					
					// go through the other children
					for each(var nodeChildXml:XML in nodeXml.children())
					{
						localName = nodeChildXml.localName();
						// default namespace stuff
						if(nodeChildXml.namespace() == defaultNamespace)
						{
							switch(localName)
							{
								case "disk_image":
									var diskImageV1Name:String = String(nodeChildXml.@name);
									var diskImageV1:DiskImage = new DiskImage(diskImageV1Name);//sliver.manager.diskImages.getByLongId(diskImageV1Name);
									if(nodeChildXml.@url.length() == 1)
										diskImageV1.url = nodeChildXml.@url;
									if(nodeChildXml.@version.length() == 1)
										diskImageV1.version = nodeChildXml.@version;
									diskImageV1.extensions.buildFromOriginal(nodeChildXml, [defaultNamespace.uri]);
									virtualNode.sliverType.selectedImage = diskImageV1;
									break;
								case "node_type":
									virtualNode.hardwareType = new HardwareType(String(nodeChildXml.@type_name), Number(nodeChildXml.@type_slots));
									// Hack for if subvirtualization_type isn't set...
									if(virtualNode.hardwareType.name == "pcvm")
										virtualNode.sliverType.name = EmulabOpenVzSliverType.TYPE_EMULABOPENVZ;
									break;
								case "hardware_type":
									virtualNode.hardwareType = new HardwareType(String(nodeChildXml.@name));
									var emulabNodeTypes:XMLList = nodeChildXml.child(new QName(RspecUtil.emulabNamespace, "node_type"));
									if(emulabNodeTypes.length() == 1)
										virtualNode.hardwareType.slots = Number(emulabNodeTypes[0].@type_slots);
									break;
								case "sliver_type":
									virtualNode.sliverType.name = String(nodeChildXml.@name);
									for each(var sliverTypeChild:XML in nodeChildXml.children())
									{
										if(sliverTypeChild.namespace() == defaultNamespace)
										{
											if(sliverTypeChild.localName() == "disk_image")
											{
												var diskImageV2Name:String = String(sliverTypeChild.@name);
												var diskImageV2:DiskImage = new DiskImage(diskImageV2Name);//sliver.manager.diskImages.getByLongId(diskImageV2Name);
												if(sliverTypeChild.@url.length() == 1)
													diskImageV2.url = sliverTypeChild.@url;
												if(sliverTypeChild.@version.length() == 1)
													diskImageV2.version = sliverTypeChild.@version;
												diskImageV2.extensions.buildFromOriginal(sliverTypeChild, [defaultNamespace.uri]);
												virtualNode.sliverType.selectedImage = diskImageV2;
											}
										}
									}
									virtualNode.sliverType.sliverTypeSpecific = SliverTypes.getSliverTypeInterface(virtualNode.sliverType.name);
									if(virtualNode.sliverType.sliverTypeSpecific != null)
										virtualNode.sliverType.sliverTypeSpecific.applyFromSliverTypeXml(virtualNode, nodeChildXml);
									if(virtualNode.manager == aggregateSliver.manager)
									{
										var knownNamespaces:Array = [defaultNamespace.uri];
										if(virtualNode.sliverType.sliverTypeSpecific != null)
										{
											var sliverNamespace:Namespace = virtualNode.sliverType.sliverTypeSpecific.namespace;
											if(sliverNamespace != null)
												knownNamespaces.push(sliverNamespace.uri);
										}
										virtualNode.sliverType.extensions.buildFromOriginal(nodeChildXml, knownNamespaces);
									}
									break;
								case "services":
									if(virtualNode.manager == aggregateSliver.manager)
									{
										if(rspec.info.version >= 2)
											virtualNode.services = new Services();
										for each(var servicesChild:XML in nodeChildXml.children())
										{
											if(servicesChild.localName() == "login")
											{
												if(parseManifest)
												{
													if(virtualNode.services.loginServices == null)
														virtualNode.services.loginServices = new Vector.<LoginService>();
													
													var loginService:LoginService =
														new LoginService(
															String(servicesChild.@authentication),
															String(servicesChild.@hostname),
															String(servicesChild.@port),
															String(servicesChild.@username)
														);
													if(rspec.info.version < 1)
													{
														if(virtualNode.services.loginServices.length == 1)
														{
															virtualNode.services.loginServices[0].authentication = loginService.authentication;
															virtualNode.services.loginServices[0].hostname = loginService.hostname;
															virtualNode.services.loginServices[0].port = loginService.port;
															virtualNode.services.loginServices[0].username = loginService.username;
														}
														else
															virtualNode.services.loginServices.push(loginService);
													}
													else
													{
														loginService.extensions.buildFromOriginal(servicesChild, [defaultNamespace.uri]);
														virtualNode.services.loginServices.push(loginService);
													}
												}
											}
											else if(servicesChild.localName() == "install")
											{
												var newInstall:InstallService =
													new InstallService(
														String(servicesChild.@url),
														String(servicesChild.@install_path),
														String(servicesChild.@file_type)
													);
												newInstall.extensions.buildFromOriginal(servicesChild, [defaultNamespace.uri]);
												if(virtualNode.services.installServices == null)
													virtualNode.services.installServices = new Vector.<InstallService>();
												virtualNode.services.installServices.push(newInstall);
											}
											else if(servicesChild.localName() == "execute")
											{
												var newExecute:ExecuteService = 
													new ExecuteService(
														String(servicesChild.@command),
														String(servicesChild.@shell)
													);
												newExecute.extensions.buildFromOriginal(servicesChild, [defaultNamespace.uri]);
												if(virtualNode.services.executeServices == null)
													virtualNode.services.executeServices = new Vector.<ExecuteService>();
												virtualNode.services.executeServices.push(newExecute);
											}
										}
										virtualNode.services.extensions.buildFromOriginal(nodeChildXml, [defaultNamespace.uri]);
									}
									break;
								case "host":
									if(parseManifest)
									{
										virtualNode.host = new Host(String(nodeChildXml.@name));
										if(virtualNode.manager == aggregateSliver.manager)
											virtualNode.host.extensions.buildFromOriginal(nodeChildXml, [defaultNamespace.uri]);
									}
									break;
							}
						}
						// Extension stuff
						else
						{
							if(nodeChildXml.namespace() == RspecUtil.flackNamespace)
							{
								virtualNode.flackInfo.x = int(nodeChildXml.@x);
								virtualNode.flackInfo.y = int(nodeChildXml.@y);
								if(nodeChildXml.@unbound.length() == 1)
								{
									virtualNode.flackInfo.unbound = String(nodeChildXml.@unbound).toLowerCase() == "true" || String(nodeChildXml.@unbound) == "1";
									if(virtualNode.flackInfo.unbound && !parseManifest)
										virtualNode.physicalId.full = "";
								}
							} else if(nodeChildXml.namespace() == RspecUtil.emulabNamespace)
							{
								if(nodeChildXml.localName() == "routable_control_ip")
								{
									// TODO: Need to remove this so it isn't saved into extensions
									virtualNode.emulabRoutableControlIp = true;
								}
							}
						}
					}
					
					nodesById[virtualNode.clientId] = virtualNode;
					
					if(virtualNode.manager == aggregateSliver.manager)
					{
						var ignoreUris:Array = [defaultNamespace.uri, RspecUtil.flackNamespace.uri];
						if(!parseManifest)
						{
							ignoreUris.push(RspecUtil.emulabNamespace);
						}
						virtualNode.extensions.buildFromOriginal(
							nodeXml,
							ignoreUris
						);
					}
				}
				
				for each(var checkVirtualNodeForParent:VirtualNode in aggregateSliver.slice.nodes.getByManager(aggregateSliver.manager).collection)
				{
					if(checkVirtualNodeForParent.Physical != null && checkVirtualNodeForParent.Physical.subNodeOf != null)
					{
						var superNodes:VirtualNodeCollection = aggregateSliver.slice.nodes.getBoundTo(checkVirtualNodeForParent.Physical.subNodeOf);
						if(superNodes.length > 0)
						{
							checkVirtualNodeForParent.superNode = superNodes.collection[0];
							if(checkVirtualNodeForParent.superNode.subNodes == null)
								checkVirtualNodeForParent.superNode.subNodes = new VirtualNodeCollection();
							if(!checkVirtualNodeForParent.superNode.subNodes.contains(checkVirtualNodeForParent))
								checkVirtualNodeForParent.superNode.subNodes.add(checkVirtualNodeForParent);
						}
						else
						{
							checkVirtualNodeForParent.superNode = null;
						}
					}
				}
				
				for each(var linkXml:XML in xmlDocument.defaultNamespace::link)
				{
					var virtualLinkClientIdString:String = "";
					var virtualLinkSliverIdString:String = "";
					if(rspec.info.version < 1)
					{
						virtualLinkSliverIdString = String(linkXml.@sliver_urn);
						virtualLinkClientIdString = String(linkXml.@virtual_id);
					}
					else
					{
						virtualLinkSliverIdString = String(linkXml.@sliver_id);
						virtualLinkClientIdString = String(linkXml.@client_id);
					}
					
					var virtualLink:VirtualLink = aggregateSliver.slice.links.getLinkByClientId(virtualLinkClientIdString);
					if(virtualLink == null)
						virtualLink = new VirtualLink(aggregateSliver.slice);
					if(virtualLinkSliverIdString.length > 0 && parseManifest)
						virtualLink.id = new IdnUrn(virtualLinkSliverIdString);
					virtualLink.clientId = virtualLinkClientIdString;
					
					// Get interfaces first, make sure this is valid
					var interfaceRefsXmllist:XMLList = linkXml.child(new QName(defaultNamespace, "interface_ref"));
					
					var skip:Boolean = false;
					for each(var interfaceRefXml:XML in interfaceRefsXmllist)
					{
						var referencedInterfaceClientId:String = "";
						var interfacedInterface:VirtualInterface = null;
						if(rspec.info.version < 1)
						{
							referencedInterfaceClientId = String(interfaceRefXml.@virtual_interface_id);
							// Hack if virtual_interface_id isn't global...
							var referencedNodeClientId:String = String(interfaceRefXml.@virtual_node_id);
							if(referencedNodeClientId.length > 0)
							{
								var interfacedNode:VirtualNode = aggregateSliver.slice.nodes.getNodeByClientId(referencedNodeClientId);
								if(interfacedNode != null)
								{
									interfacedInterface = interfacedNode.interfaces.getByClientId(referencedInterfaceClientId);
									if(referencedInterfaceClientId == "control" && interfacedInterface == null)
									{
										interfacedInterface = new VirtualInterface(interfacedNode, "control");
										interfacedNode.interfaces.add(interfacedInterface);
									}
								}
							}
							else
								interfacedInterface = aggregateSliver.slice.nodes.getInterfaceByClientId(referencedInterfaceClientId);
						}
						else
						{
							referencedInterfaceClientId = String(interfaceRefXml.@client_id);
							interfacedInterface = aggregateSliver.slice.nodes.getInterfaceByClientId(referencedInterfaceClientId);
						}
						
						if(interfacedInterface == null)
						{
							addMessage(
								"Interface not found",
								"Interface not found. Interface with client ID '"+referencedInterfaceClientId+"' was not found.",
								LogMessage.LEVEL_WARNING
							);
							skip = true;
							break;
						}
						
						var interfacedInterfaceReference:VirtualInterfaceReference = virtualLink.interfaceRefs.getReferenceFor(interfacedInterface);
						if(interfacedInterfaceReference == null)
						{
							interfacedInterfaceReference = new VirtualInterfaceReference(interfacedInterface);
							virtualLink.interfaceRefs.add(interfacedInterfaceReference);
						}
						
						if(interfacedInterface.Owner.manager == aggregateSliver.manager)
							interfacedInterfaceReference.extensions.buildFromOriginal(interfaceRefXml, [defaultNamespace.uri]);
						
						if(rspec.info.version < 1)
						{
							if(interfaceRefXml.@tunnel_ip.length() == 1)
								interfacedInterface.ip = new Ip(String(interfaceRefXml.@tunnel_ip));
							else if(interfaceRefXml.@IP.length() == 1)
								interfacedInterface.ip = new Ip(String(interfaceRefXml.@IP));
							if(interfaceRefXml.@netmask.length() == 1)
								interfacedInterface.ip.netmask = String(interfaceRefXml.@netmask);
							if(interfaceRefXml.@component_urn.length() == 1)
								interfacedInterface.physicalId = new IdnUrn(interfaceRefXml.@component_urn);
							if(parseManifest)
							{
								if(interfaceRefXml.@sliver_urn.length() == 1)
									interfacedInterface.id = new IdnUrn(interfaceRefXml.@sliver_urn);
								if(interfaceRefXml.@VMAC.length() == 1)
									interfacedInterface.vmac = String(interfaceRefXml.@VMAC);
								if(interfaceRefXml.@MAC.length() == 1)
									interfacedInterface.macAddress = String(interfaceRefXml.@MAC);
							}
						}
						else
						{
							if(parseManifest && interfaceRefXml.@sliver_id.length() == 1)
								interfacedInterface.id = new IdnUrn(interfaceRefXml.@sliver_id);
							if(interfaceRefXml.@component_id.length() == 1)
							{
								interfacedInterface.physicalId = new IdnUrn(String(interfaceRefXml.@component_id));
								if(interfacedInterface.Physical == null)
								{
									// Switched from error to warning
									addMessage(
										"Interface not found. Physical interface with ID '"+String(interfaceRefXml.@component_id)+"' was not found.",
										"Interface not found. Physical interface with ID '"+String(interfaceRefXml.@component_id)+"' was not found.",
										LogMessage.LEVEL_WARNING
									);
								}
							}
						}
					}
					
					if(skip)
					{
						addMessage(
							"Skipping link",
							"Skipping link due to errors, possibly due to another RSPEC having not been parsed yet.",
							LogMessage.LEVEL_WARNING
						);
						continue;
					}
					
					if(!aggregateSliver.slice.links.contains(virtualLink))
						aggregateSliver.slice.links.add(virtualLink);
					
					// Add the link to the interfaces
					for each(var myInterface:VirtualInterface in virtualLink.interfaceRefs.Interfaces.collection)
					{
						if(!myInterface.links.contains(virtualLink))
							myInterface.links.add(virtualLink);
					}
					
					if(rspec.info.version < 1)
					{
						virtualLink.type.name = String(linkXml.@link_type).toLowerCase();
						switch(virtualLink.type.name)
						{
							case LinkType.GRETUNNEL_V1:
								virtualLink.type.name = LinkType.GRETUNNEL_V2;
								break;
							case LinkType.LAN_V1:
							case LinkType.LAN_V2:
								virtualLink.type.name = LinkType.LAN_V2;
								break;
							case "vlan":
								virtualLink.type.name = LinkType.VLAN;
						}
					}
					
					if(parseManifest && linkXml.@vlantag.length() == 1)
						virtualLink.vlantag = String(linkXml.@vlantag);
					
					for each(var linkChildXml:XML in linkXml.children())
					{
						localName = linkChildXml.localName();
						// default namespace stuff
						if(linkChildXml.namespace() == defaultNamespace)
						{
							switch(localName)
							{
								case "bandwidth":
									virtualLink.Capacity = Number(linkChildXml.toString());
									break;
								case "latency":
									virtualLink.Latency = Number(linkChildXml.toString());
									break;
								case "packet_loss":
									virtualLink.PacketLoss = Number(linkChildXml.toString());
									break;
								case "property":
									var sourceInterface:VirtualInterface = aggregateSliver.slice.nodes.getInterfaceByClientId(linkChildXml.@source_id);
									var destInterface:VirtualInterface = aggregateSliver.slice.nodes.getInterfaceByClientId(linkChildXml.@dest_id);
									var newProperty:Property = virtualLink.properties.getFor(sourceInterface, destInterface);
									if(newProperty == null)
									{
										newProperty = new Property(sourceInterface, destInterface);
										virtualLink.properties.add(newProperty);
									}
									
									if(linkChildXml.@capacity.length() == 1)
										newProperty.capacity = Number(linkChildXml.@capacity);
									if(linkChildXml.@latency.length() == 1)
										newProperty.latency = Number(linkChildXml.@latency);
									if(linkChildXml.@packet_loss.length() == 1)
										newProperty.packetLoss = Number(linkChildXml.@packet_loss);
									newProperty.extensions.buildFromOriginal(linkChildXml, [defaultNamespace.uri]);
									break;
								case "component_hop":
									if(virtualLink.componentHops == null)
										virtualLink.componentHops = new Vector.<ComponentHop>();
									var componentHop:ComponentHop = new ComponentHop(
										linkChildXml.@component_urn,
										linkChildXml.interface_ref.@component_node_urn,
										linkChildXml.interface_ref.@component_interface_id);
									virtualLink.componentHops.push(componentHop);
									if(componentHop.id.name == "ion")
										virtualLink.type.name = LinkType.ION;
									else if(componentHop.id.name == "gpeni")
										virtualLink.type.name = LinkType.GPENI;
									break;
								case "link_type":
									if(linkChildXml.@name.length() == 1)
										virtualLink.type.name = String(linkChildXml.@name).toLowerCase();
									else if(linkChildXml.@type_name.length() == 1)
										virtualLink.type.name = String(linkChildXml.@type_name).toLowerCase();
									switch(virtualLink.type.name)
									{
										case LinkType.GRETUNNEL_V1:
											virtualLink.type.name = LinkType.GRETUNNEL_V2;
											break;
										case LinkType.LAN_V1:
											virtualLink.type.name = LinkType.LAN_V2;
											break;
										case "vlan":
											virtualLink.type.name = LinkType.VLAN;
									}
									virtualLink.type.extensions.buildFromOriginal(linkChildXml, [defaultNamespace.uri]);
									break;
								case "component_manager":
									if(linkChildXml.@name == aggregateSliver.manager.id.full)
									{
										var managerReference:GeniManagerReference = virtualLink.managerRefs.getReferenceFor(aggregateSliver.manager);
										if(managerReference == null)
										{
											managerReference = new GeniManagerReference(aggregateSliver.manager);
											virtualLink.managerRefs.add(managerReference);
										}
										managerReference.extensions.buildFromOriginal(linkChildXml, [defaultNamespace.uri]);
									}
									break;
							}
						}
						// Extensions
						else
						{
							if(linkChildXml.namespace() == RspecUtil.flackNamespace)
							{
								virtualLink.flackInfo.x = int(linkChildXml.@x);
								virtualLink.flackInfo.y = int(linkChildXml.@y);
								if(linkChildXml.@unboundVlantag.length() == 1)
								{
									virtualLink.flackInfo.unboundVlantag = String(linkChildXml.@unboundVlantag).toLowerCase() == "true" || String(linkChildXml.@unboundVlantag) == "1";
									if(virtualLink.flackInfo.unboundVlantag && !parseManifest)
										virtualLink.vlantag = "";
								}
							}
							else if(linkChildXml.namespace() == RspecUtil.sharedVlanNamespace)
							{
								if(linkChildXml.@name.length() == 1)
									virtualLink.sharedVlanName = linkChildXml.@name;
							}
						}
					}
					
					// Make sure links between managers aren't normal
					if(virtualLink.interfaceRefs.Interfaces.Managers.length > 1 && virtualLink.type.name == LinkType.LAN_V2)
					{
					  var isXen:Boolean = true;
					  for each (var ref:VirtualInterfaceReference in virtualLink.interfaceRefs.collection) {
					      if (ref.referencedInterface.Owner.sliverType.name != EmulabXenSliverType.TYPE_EMULABXEN) {
						isXen = false;
						break;
					      }
					  }
					  if (isXen)
					  {
					    virtualLink.type.name = LinkType.GRETUNNEL_V2;
					  }
					  else
					  {
					    virtualLink.type.name = LinkType.EGRE;
					  }
					}
					
					virtualLink.extensions.buildFromOriginal(linkXml, [defaultNamespace.uri, RspecUtil.sharedVlanNamespace.uri]);
					
					switch(virtualLink.type.name)
					{
						case LinkType.VLAN:
							// If a BBG node from this sliver gets a vlantag, edit the vlan link outside of the manager
							var linkManagers:GeniManagerCollection = virtualLink.interfaceRefs.Interfaces.Managers;
							if(virtualLink.vlantag.length > 0 && linkManagers.length == 1 && linkManagers.collection[0] == aggregateSliver.manager)
							{
								var bbgNodes:VirtualNodeCollection = virtualLink.interfaceRefs.Interfaces.Nodes.getBySliverType(EmulabBbgSliverType.TYPE_EMULAB_BBG);
								for each(var bbgNode:VirtualNode in bbgNodes.collection)
								{
									var externalVlans:VirtualLinkCollection = bbgNode.interfaces.Links.getByType(LinkType.VLAN).getConnectedToMultipleManagers();
									var sourceIfaces:VirtualInterfaceCollection = virtualLink.interfaceRefs.Interfaces.getByHostOtherThan(bbgNode);
									var sourceBbgIface:VirtualInterface = virtualLink.interfaceRefs.Interfaces.getByHost(bbgNode);
									for each(var vlan:VirtualLink in externalVlans.collection)
									{
										vlan.vlantag = virtualLink.vlantag;
										var destIfaces:VirtualInterfaceCollection = vlan.interfaceRefs.Interfaces.getByHostOtherThan(bbgNode);
										if(sourceBbgIface != null)
										{
											for each(var destIface:VirtualInterface in destIfaces.collection)
											{
												destIface.ip.address = sourceBbgIface.ip.address;
												destIface.ip.netmask = sourceBbgIface.ip.netmask;
												destIface.ip.type = sourceBbgIface.ip.type;
											}
										}
										
										for each(var sourceIface:VirtualInterface in sourceIfaces.collection)
										{
											vlan.interfaceRefs.add(sourceIface);
											sourceIface.links.add(vlan);
											sourceIface.links.remove(virtualLink);
											virtualLink.interfaceRefs.remove(sourceIface);
										}
										vlan.removeNode(bbgNode);
									}
								}
							}
							break;
						default:
					}
					
					// detect that the link has been entirely created before setting the manifest
					var isManifestFinished:Boolean = rspec.type == Rspec.TYPE_MANIFEST;
					/*for each(var testInterface:VirtualInterface in virtualLink.interfaceRefs.Interfaces.collection)
					{
						if(testInterface.Physical == null)
						{
							isManifestFinished = false;
							break;
						}
					}*/
					
					if(markUnsubmitted)
						virtualLink.unsubmittedChanges = true;
					else if(isManifestFinished)
						virtualLink.unsubmittedChanges = false;
					
					if(isManifestFinished)
						virtualLink.manifest = linkXml.toXMLString();
				}

				// Parse stitching info.
				var stitchingNamespace:Namespace = RspecUtil.stitchingNamespace;
				for each(var stitchingXml:XML in xmlDocument.stitchingNamespace::stitching)
				{
					var lastUpdateTimeString:String = String(stitchingXml.@lastUpdateTime);
					var year:Number = Number(lastUpdateTimeString.substr(0, 4));
					var lastUpdateTime:Date = new Date(
						Number(lastUpdateTimeString.substr(0, 4)),
						Number(lastUpdateTimeString.substr(4, 2)),
						Number(lastUpdateTimeString.substr(6, 2)),
						Number(lastUpdateTimeString.substr(9, 2)),
						Number(lastUpdateTimeString.substr(12, 2)),
						Number(lastUpdateTimeString.substr(15, 2)));
					aggregateSliver.slice.stitching.lastUpdateTime = lastUpdateTime;
					for each(var pathXml:XML in stitchingXml.stitchingNamespace::path)
					{
						var pathVirtualLink:VirtualLink = aggregateSliver.slice.links.getByClientId(String(pathXml.@id)) as VirtualLink;
						// Link not parsed yet.
						if(pathVirtualLink == null)
							continue;
						var path:StitchingPath = aggregateSliver.slice.stitching.paths.getByVirtualLinkClientId(pathVirtualLink.clientId);
						if (path == null) {
							path = new StitchingPath(pathVirtualLink);
							aggregateSliver.slice.stitching.paths.add(path);
						}
						for each(var hopXml:XML in pathXml.stitchingNamespace::hop)
						{
							var hopId:Number = Number(hopXml.@id);
							var hop:StitchingHop = path.hops.getById(hopId);
							if (hop == null) {
								hop = new StitchingHop(hopId);
								path.hops.add(hop);
							}
							for each(var stitchingLinkXml:XML in hopXml.stitchingNamespace::link)
							{
								var linkId:String = String(stitchingLinkXml.@id);
								
								var advertisedLink:StitchingLink = hop.advertisedLink;
								if (advertisedLink == null || advertisedLink.id.full != linkId) {
									advertisedLink = GeniMain.geniUniverse.managers.getComponentById(linkId) as StitchingLink;
									hop.advertisedLink = advertisedLink;
									
									if (advertisedLink == null) {
										addMessage(
											"Advertised stitching link '"+linkId+"' was not found.",
											"Advertised stitching link '"+linkId+"' was not found.",
											LogMessage.LEVEL_WARNING
										);
										continue;
									}
								}
								
								var requestLink:StitchingLink = hop.requestLink;
								if (requestLink == null || requestLink.id.full != linkId) {
									requestLink = new StitchingLink(linkId, advertisedLink.manager);
									hop.requestLink = requestLink;
								}
								
								if (stitchingLinkXml.stitchingNamespace::trafficEngineeringMetric.length() == 1) {
									requestLink.trafficEngineeringMetric = Number(stitchingLinkXml.stitchingNamespace::trafficEngineeringMetric);
								}
								if (stitchingLinkXml.stitchingNamespace::capacity.length() == 1) {
									requestLink.capacity = Number(stitchingLinkXml.stitchingNamespace::capacity);
								}
								
								var switchingCapabilityDescriptors:XMLList = stitchingLinkXml.stitchingNamespace::switchingCapabilityDescriptor;
								for each(var switchingCapabilityDescriptorObj:XML in switchingCapabilityDescriptors)
								{
									var newSwitchingCapabilityDescriptor:SwitchingCapabilityDescriptor = new SwitchingCapabilityDescriptor();
									if (switchingCapabilityDescriptorObj.stitchingNamespace::switchingcapType.length() == 1) {
										newSwitchingCapabilityDescriptor.switchingcapType = String(switchingCapabilityDescriptorObj.stitchingNamespace::switchingcapType);
									}
									if (switchingCapabilityDescriptorObj.stitchingNamespace::encodingType.length() == 1) {
										newSwitchingCapabilityDescriptor.encodingType = String(switchingCapabilityDescriptorObj.stitchingNamespace::encodingType);
									}
									
									var switchingCapabilitySpecificInfos:XMLList = switchingCapabilityDescriptorObj.stitchingNamespace::switchingCapabilitySpecificInfo;
									for each(var switchingCapabilitySpecificInfoObj:XML in switchingCapabilitySpecificInfos)
									{
										if (switchingCapabilitySpecificInfoObj.switchingCapabilitySpecificInfo_L2sc.length() == 1) {
											newSwitchingCapabilityDescriptor.l2scInfo = new SwitchingCapabilitySpecificInfoL2sc();
											var l2scInfoObj:XML = switchingCapabilitySpecificInfoObj.switchingCapabilitySpecificInfo_L2sc[0];
											if (l2scInfoObj.stitchingNamespace::interfaceMTU.length() == 1) {
												newSwitchingCapabilityDescriptor.l2scInfo.interfaceMTU = Number(l2scInfoObj.stitchingNamespace::interfaceMTU);
											}
											if (l2scInfoObj.stitchingNamespace::vlanRangeAvailability.length() == 1) {
												newSwitchingCapabilityDescriptor.l2scInfo.vlanRangeAvailability = String(l2scInfoObj.stitchingNamespace::vlanRangeAvailability);
											}
											if (l2scInfoObj.stitchingNamespace::suggestedVLANRange.length() == 1) {
												newSwitchingCapabilityDescriptor.l2scInfo.suggestedVLANRange = String(l2scInfoObj.stitchingNamespace::suggestedVLANRange);
											}
											if (l2scInfoObj.stitchingNamespace::vlanTranslation.length() == 1) {
												newSwitchingCapabilityDescriptor.l2scInfo.vlanTranslation = l2scInfoObj.stitchingNamespace::vlanTranslation == "true" || l2scInfoObj.stitchingNamespace::vlanTranslation == "1";
											}
										}
										if (switchingCapabilitySpecificInfoObj.switchingCapabilitySpecificInfo_Lsc.length() == 1) {
											newSwitchingCapabilityDescriptor.lscInfo = new SwitchingCapabilitySpecificInfoLsc();
											var lscInfoObj:XML = switchingCapabilitySpecificInfoObj.switchingCapabilitySpecificInfo_Lsc[0];
											if (lscInfoObj.stitchingNamespace::wavelengthSpacing.length() == 1) {
												newSwitchingCapabilityDescriptor.lscInfo.wavelengthSpacing = String(lscInfoObj.stitchingNamespace::wavelengthSpacing);
											}
											if (lscInfoObj.stitchingNamespace::wavelengthRangeAvailability.length() == 1) {
												newSwitchingCapabilityDescriptor.lscInfo.wavelengthRangeAvailability = String(lscInfoObj.stitchingNamespace::wavelengthRangeAvailability);
											}
											if (lscInfoObj.stitchingNamespace::suggestedWavelengthRange.length() == 1) {
												newSwitchingCapabilityDescriptor.lscInfo.suggestedWavelengthRange = String(lscInfoObj.stitchingNamespace::suggestedWavelengthRange);
											}
											if (lscInfoObj.stitchingNamespace::wavelengthTranslation.length() == 1) {
												newSwitchingCapabilityDescriptor.lscInfo.wavelengthTranslation = String(lscInfoObj.stitchingNamespace::wavelengthTranslation);
											}
										}
									}
									
									requestLink.switchingCapabilityDescriptors.add(newSwitchingCapabilityDescriptor);
								}
							}
							
							if (hopXml.stitchingNamespace::nextHop.length() == 1) {
								hop.nextHop = Number(hopXml.stitchingNamespace::nextHop);
							}
						}
					}
				}
				
				if(parseManifest)
				{
					if(xmlDocument.@valid_until.length() == 1)
						aggregateSliver.Expires = DateUtil.parseRFC3339(String(xmlDocument.@valid_until));
					if(xmlDocument.@expires.length() == 1)
						aggregateSliver.Expires = DateUtil.parseRFC3339(String(xmlDocument.@expires));
				}
				
				// History extension
				var sliceHistory:XMLList = xmlDocument.child(new QName(RspecUtil.historyNamespace, "slice_history"));
				aggregateSliver.slice.history = new SliceHistory();
				if(sliceHistory.length() == 1)
				{
					aggregateSliver.slice.history.backIndex = int((sliceHistory[0] as XML).@backIndex);
					aggregateSliver.slice.history.stateName = String((sliceHistory[0] as XML).@note);
					var statesXml:XMLList = (sliceHistory[0] as XML).children();
					for each(var stateXml:XML in statesXml)
						aggregateSliver.slice.history.states.push(new SliceHistoryItem(CompressUtil.uncompress(stateXml.toString()), String(stateXml.@note)));
				}
				
				// Flack extension
				var sliceFlackInfoXml:XMLList = xmlDocument.child(new QName(RspecUtil.flackNamespace, "slice_info"));
				aggregateSliver.slice.flackInfo = new SliceFlackInfo();
				if(sliceFlackInfoXml.length() == 1)
				{
					aggregateSliver.slice.flackInfo.view = String(sliceFlackInfoXml[0].@view);
				}
				
				// Make sure the sliver is saved in the slice if resources were found
				if(aggregateSliver.slice.nodes.getByManager(aggregateSliver.manager).length > 0
					&& !aggregateSliver.slice.aggregateSlivers.contains(aggregateSliver))
				{
					aggregateSliver.slice.aggregateSlivers.add(aggregateSliver);
				}
				
				aggregateSliver.resetToSlivers();
				
				if(markUnsubmitted)
					aggregateSliver.UnsubmittedChanges = true;
				else if(rspec.type == Rspec.TYPE_MANIFEST)
						aggregateSliver.UnsubmittedChanges = false;
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLIVER,
					aggregateSliver,
					FlackEvent.ACTION_POPULATED
				);
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_SLICE,
					aggregateSliver.slice,
					FlackEvent.ACTION_POPULATING
				);
				
				addMessage(
					"Parsed",
					aggregateSliver.manager.hrn +
						"\n" + rspec.info.toString() +
						"\nNodes from sliver: " + aggregateSliver.slice.nodes.getByManager(aggregateSliver.manager).length +
						"\nLinks from sliver: " + aggregateSliver.slice.links.getConnectedToManager(aggregateSliver.manager).length,
					LogMessage.LEVEL_INFO,
					LogMessage.IMPORTANCE_HIGH
				);
				
				super.afterComplete(false);
			}
			catch(e:Error)
			{
				afterError(
					new TaskError(
						StringUtil.errorToString(e),
						TaskError.CODE_UNEXPECTED,
						e
					)
				);
			}
		}
	}
}
