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

package com.flack.emulab.tasks.xmlrpc
{
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskGroup;
	import com.flack.shared.tasks.xmlrpc.XmlrpcTask;
	
	import flash.events.Event;
	
	public class EmulabXmlrpcTask extends XmlrpcTask
	{
		// Modules
		public static const MODULE_OSID:String = "osid";
		//public static const MODULE_IMAGEID:String = "imageid";
		public static const MODULE_NODE:String = "node";
		public static const MODULE_EXPERIMENT:String = "experiment";
		public static const MODULE_FS:String = "fs";
		public static const MODULE_USER:String = "user";
		public static const MODULE_EMULAB:String = "emulab";
		
		// Methods
		public static const METHOD_AVAILABLE:String = "available";
		public static const METHOD_ADMINMODE:String = "adminmode";
		public static const METHOD_CONSOLE:String = "console";
		public static const METHOD_CONSTRAINTS:String = "constraints";
		public static const METHOD_CREATEIMAGE:String = "create_image";
		public static const METHOD_ENDEXP:String = "endexp";
		public static const METHOD_EXPINFO:String = "expinfo";
		public static const METHOD_EXPORTS:String = "export";
		public static const METHOD_EVENTSYSCONTROL:String = "eventsys_control";
		public static const METHOD_GETLIST:String = "getlist";
		public static const METHOD_GETVIZ:String = "getviz";
		public static const METHOD_HOSTKEYS:String = "hostkeys";
		public static const METHOD_INFO:String = "info";
		public static const METHOD_MEMBERSHIP:String = "membership";
		public static const METHOD_METADATA:String = "metadata";
		public static const METHOD_MODIFY:String = "modify";
		public static const METHOD_NODECOUNT:String = "nodecount";
		public static const METHOD_NSFILE:String = "nsfile";
		public static const METHOD_NSCHECK:String = "nscheck";
		public static const METHOD_PORTSTATS:String = "portstats";
		public static const METHOD_REBOOT:String = "reboot";
		public static const METHOD_RELOAD:String = "reload";
		public static const METHOD_SAVELOGS:String = "savelogs";
		public static const METHOD_SSHDESCRIPTION:String = "sshdescription";
		public static const METHOD_STARTEXP:String = "startexp";
		public static const METHOD_SWAPEXP:String = "swapexp";
		public static const METHOD_STATE:String = "state";
		public static const METHOD_THUMBNAIL:String = "thumbnail";
		public static const METHOD_VIRTUALTOPOLOGY:String = "virtual_topology";
		
		public static function makeXmlrpcUrl(xmlrpcUrl:String, module:String):String
		{
			if(module.length == 0)
				return xmlrpcUrl;
			if(xmlrpcUrl.charAt(xmlrpcUrl.length-1) != "/")
				xmlrpcUrl += "/";
			return xmlrpcUrl + module;
		}
		
		// Emulab response codes
		public static const CODE_SUCCESS:int = 0;
		public static const CODE_BADARGS:int  = 1;
		public static const CODE_ERROR:int = 2;
		public static const CODE_FORBIDDEN:int = 3;
		public static const CODE_BADVERSION:int = 4;
		public static const CODE_SERVERERROR:int = 5;
		public static const CODE_TOOBIG:int = 6;
		public static const CODE_REFUSED:int = 7;
		public static const CODE_TIMEDOUT:int = 8;
		public static function EmulabresponseToString(value:int):String
		{
			switch(value)
			{
				case CODE_SUCCESS:return "Success";
				case CODE_BADARGS:return "Malformed arguments";
				case CODE_ERROR:return "General Error";
				case CODE_FORBIDDEN:return "Forbidden";
				case CODE_BADVERSION:return "Bad version";
				case CODE_SERVERERROR:return "Server error";
				case CODE_TOOBIG:return "Too big";
				case CODE_REFUSED:return "Refused";
				case CODE_TIMEDOUT:return "Timed out";
				default:return "Other error ("+value+")";
			}
		}
		
		public var version:Number = 0.1;
		
		/**
		 * Code as specified in a XML-RPC result
		 */
		public var code:int;
		
		/**
		 * Output string specified in a XML-RPC result
		 */
		public var output:String;
		
		public function EmulabXmlrpcTask(taskUrl:String,
										 taskModule:String,
										 taskMethod:String,
										 taskName:String = "Emulab XML-RPC Task",
										 taskDescription:String = "Communicates with a Emulab XML-RPC service",
										 taskShortName:String = "",
										 taskParent:TaskGroup = null,
										 taskRetryWhenPossible:Boolean = true)
		{
			super(
				taskUrl,
				taskModule + "." + taskMethod,
				taskName,
				taskDescription,
				taskShortName,
				taskParent,
				taskRetryWhenPossible
			);
		}
		
		/**
		 * Saves Emulab-specific variables
		 * 
		 * @param event
		 * 
		 */
		override public function callSuccess(event:Event):void
		{
			cancelTimers();
			
			var response:Object = server.getResponse();
			
			code = response.code;
			output = response.output;
			
			data = response.value;
			
			var responseMsg:String = "Code = "+EmulabresponseToString(code);
			if(output != null && output.length > 0)
				responseMsg += ",\nOutput = "+output;
			responseMsg += ",\nRaw Response:\n"+server._response.data
			addMessage(
				"Received response",
				responseMsg
			);
			
			afterComplete(false);
		}
		
		/**
		 * Recieved a code which wasn't expected, therefore an error
		 * 
		 */
		public function faultOnSuccess():void
		{
			var errorMessage:String = EmulabresponseToString(code);
			if(output != null && output.length > 0)
				errorMessage += ": " + output;
			afterError(
				new TaskError(
					errorMessage,
					TaskError.FAULT
				)
			);
		}
	}
}