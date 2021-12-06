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
	import com.flack.emulab.resources.NamedObject;
	import com.flack.emulab.resources.physical.PhysicalNode;
	import com.flack.shared.utils.StringUtil;
	
	public class VirtualNode extends NamedObject
	{
		static public const TYPE_NODE:int = 0;
		static public const TYPE_BRIDGE:int = 1;
		
		static public const FAILUREACTION_FATAL:String = "fatal";
		static public const FAILUREACTION_NONFATAL:String = "nonfatal";
		
		public var experiment:Experiment;
		public var x:Number = NaN;
		public var y:Number = NaN;
		
		public var os:String = "";
		public var startupCommand:String = "";
		public var commandLine:String = "";
		public var tarFiles:Vector.<TarFile> = null;
		public var rpmFiles:Vector.<String> = null;
		
		public var type:int = TYPE_NODE;
		
		public var physicalName:String = "";
		public function set Physical(newPhysicalNode:PhysicalNode):void
		{
			physicalName = newPhysicalNode.name;
			hardwareType = "";
			if(experiment.isIdUnique(this, newPhysicalNode.name))
				name = newPhysicalNode.name;
			else
				name = experiment.getUniqueId(this, newPhysicalNode.name+"-");
		}
		public function get Physical():PhysicalNode
		{
			return experiment.manager.nodes.getByName(physicalName);
		}
		public function get Bound():Boolean
		{
			return physicalName.length > 0;
		}
		
		public var hardwareType:String = ""; // hardware or virtualtype
		public function get Vm():Boolean
		{
			return hardwareType.indexOf("vm") > -1;
		}
		
		public var programAgents:Vector.<ProgramAgent> = null;
		
		// XXX traffic gens
		
		public var failureAction:String = "";
		public var desires:Vector.<NameValuePair> = null;
		
		public var interfaces:VirtualInterfaceCollection = new VirtualInterfaceCollection();
		
		public var unsubmittedChanges:Boolean = true;
		
		public function VirtualNode(newExperiment:Experiment, newName:String="")
		{
			super(newName);
			experiment = newExperiment;
		}
		
		public function allocateExperimentalInterface():VirtualInterface
		{
			return new VirtualInterface(this);
		}
		
		public function removeFromSlice():void
		{
			// Remove connections with links
			while(interfaces.length > 0)
			{
				var iface:VirtualInterface = interfaces.collection[0];
				if(iface.link != null)
				{
					var removeLink:VirtualLink = iface.link;
					removeLink.removeInterface(iface);
					if(removeLink.interfaces.length <= 1)
						removeLink.removeFromSlice();
				}
				interfaces.remove(iface);
			}
			
			experiment.UnsubmittedChanges = true;
			experiment.nodes.remove(this);
		}
		
		public function UnboundCloneFor(newExperiment:Experiment):VirtualNode
		{
			var newClone:VirtualNode = new VirtualNode(newExperiment, "");
			if(newExperiment.isIdUnique(newClone, name))
				newClone.name = name;
			else
				newClone.name = newClone.experiment.getUniqueId(newClone, StringUtil.makeSureEndsWith(name,"-"));
			newClone.os = os;
			newClone.commandLine = commandLine;
			for each(var d:NameValuePair in desires)
				newClone.desires.push(new NameValuePair(d.name, d.value));
			newClone.failureAction = failureAction;
			newClone.hardwareType = hardwareType;
			newClone.startupCommand = startupCommand;
			for each(var rpmFile:String in rpmFiles)
				newClone.rpmFiles.push(rpmFile);
			for each(var tarFile:TarFile in tarFiles)
				newClone.tarFiles.push(new TarFile(tarFile.directory, tarFile.path));
			newClone.type = type;
			return newClone;
		}
	}
}