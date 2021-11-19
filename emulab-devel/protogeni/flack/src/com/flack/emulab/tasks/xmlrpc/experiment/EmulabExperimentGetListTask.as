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

package com.flack.emulab.tasks.xmlrpc.experiment
{
	import com.flack.emulab.EmulabMain;
	import com.flack.emulab.resources.virtual.Experiment;
	import com.flack.emulab.resources.virtual.ExperimentCollection;
	import com.flack.emulab.tasks.xmlrpc.EmulabXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	
	import flash.utils.Dictionary;
	
	public class EmulabExperimentGetListTask extends EmulabXmlrpcTask
	{
		static public const FORMAT_BRIEF:String = "brief";
		static public const FORMAT_FULL:String = "full";
		
		// optional
		private var format:String;
		public function EmulabExperimentGetListTask(newFormat:String = FORMAT_FULL)
		{
			super(
				EmulabMain.manager.api.url,
				EmulabXmlrpcTask.MODULE_EXPERIMENT,
				EmulabXmlrpcTask.METHOD_GETLIST,
				"Get number of used nodes @ " + EmulabMain.manager.api.url,
				"Getting node availability at " + EmulabMain.manager.api.url,
				"# Nodes Used"
			);
			format = newFormat;
			relatedTo.push(EmulabMain.user);
		}
		
		override protected function createFields():void
		{
			addOrderedField(version);
			var args:Dictionary = new Dictionary();
			if(format.length > 0)
				args["format"] = format;
			addOrderedField(args);
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			if (code == EmulabXmlrpcTask.CODE_SUCCESS)
			{
				EmulabMain.user.experiments = new ExperimentCollection();
				for(var projName:String in data)
				{
					var projects:Object = data[projName];
					for(var subGroupName:String in projects)
					{
						var experiments:Array = projects[subGroupName];
						for each(var experimentObj:Object in experiments)
						{
							var userExperiment:Experiment = new Experiment(EmulabMain.manager);
							userExperiment.creator = EmulabMain.user;
							userExperiment.pid = projName;
							userExperiment.gid = subGroupName;
							userExperiment.manager = EmulabMain.manager;
							
							if(experimentObj is String)
								userExperiment.name = experimentObj as String;
							else
							{
								userExperiment.name = experimentObj["name"];
								userExperiment.description = experimentObj["description"];
							}
							EmulabMain.user.experiments.add(userExperiment);
							SharedMain.sharedDispatcher.dispatchChanged(
								FlackEvent.CHANGED_EXPERIMENT,
								userExperiment,
								FlackEvent.ACTION_CREATED
							);
							SharedMain.sharedDispatcher.dispatchChanged(
								FlackEvent.CHANGED_EXPERIMENTS,
								userExperiment,
								FlackEvent.ACTION_ADDED
							);
							
						}
					}
				}
				
				SharedMain.sharedDispatcher.dispatchChanged(
					FlackEvent.CHANGED_USER,
					EmulabMain.user
				);
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}