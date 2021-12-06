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

package com.flack.geni.tasks.xmlrpc.protogeni
{
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskGroup;
	import com.flack.shared.tasks.xmlrpc.XmlrpcTask;
	
	import flash.events.Event;

	/**
	 * Supports the syntax for XML-RPC calls with ProtoGENI
	 * 
	 * @author mstrum
	 * 
	 */
	public class ProtogeniXmlrpcTask extends XmlrpcTask
	{
		// Modules
		public static const MODULE_AM:String = "am";
		public static const MODULE_CH:String = "ch";
		public static const MODULE_CM:String = "cm";
		public static const MODULE_SA:String = "sa";
		public static const MODULE_SES:String = "ses";
		
		// Methods
		public static const METHOD_CREATESLIVER:String = "CreateSliver";
		public static const METHOD_CREATEIMAGE:String = "CreateImage";
		public static const METHOD_DELETESLICE:String = "DeleteSlice";
		public static const METHOD_DISCOVERRESOURCES:String = "DiscoverResources";
		public static const METHOD_GETCREDENTIAL:String = "GetCredential";
		public static const METHOD_GETKEYS:String = "GetKeys";
		public static const METHOD_GETSLIVER:String = "GetSliver";
		public static const METHOD_GETTICKET:String = "GetTicket";
		public static const METHOD_GETVERSION:String = "GetVersion";
		public static const METHOD_LISTCOMPONENTS:String = "ListComponents";
		public static const METHOD_LISTIMAGES:String = "ListImages";
		public static const METHOD_REDEEMTICKET:String = "RedeemTicket";
		public static const METHOD_RELEASETICKET:String = "ReleaseTicket";
		public static const METHOD_RESTARTSLIVER:String = "RestartSliver";
		public static const METHOD_RESOLVE:String = "Resolve";
		public static const METHOD_REMOVE:String = "Remove";
		public static const METHOD_REGISTER:String = "Register";
		public static const METHOD_RENEWSLICE:String = "RenewSlice";
		public static const METHOD_SHUTDOWN:String = "Shutdown";
		public static const METHOD_SLICESTATUS:String = "SliceStatus";
		public static const METHOD_SLIVERTICKET:String = "SliverTicket";
		public static const METHOD_SLIVERSTATUS:String = "SliverStatus";
		public static const METHOD_STARTSLIVER:String = "StartSliver";
		public static const METHOD_STOPSLIVER:String = "StopSliver";
		public static const METHOD_UPDATESLIVER:String = "UpdateSliver";
		public static const METHOD_UPDATETICKET:String = "UpdateTicket";
		public static const METHOD_WHOAMI:String = "WhoAmI";
		
		/**
		 * Gets the correct url to make the XML-RPC call to
		 * 
		 * @param xmlrpcUrl Base URL for the XML-RPC server
		 * @param module ProtoGENI module used
		 * @return Full URL to make the XML-RPC call
		 * 
		 */
		public static function makeXmlrpcUrl(xmlrpcUrl:String, module:String):String
		{
			if(module.length == 0)
				return xmlrpcUrl;
			if(xmlrpcUrl.charAt(xmlrpcUrl.length-1) != "/")
				xmlrpcUrl += "/";
			return xmlrpcUrl + module;
		}
		
		// ProtoGENI response codes
		public static const CODE_SUCCESS:int = 0;
		public static const CODE_BADARGS:int  = 1;
		public static const CODE_ERROR:int = 2;
		public static const CODE_FORBIDDEN:int = 3;
		public static const CODE_BADVERSION:int = 4;
		public static const CODE_SERVERERROR:int = 5;
		public static const CODE_TOOBIG:int = 6;
		public static const CODE_REFUSED:int = 7;
		public static const CODE_TIMEDOUT:int = 8;
		public static const CODE_DBERROR:int = 9;
		public static const CODE_RPCERROR:int = 10;
		public static const CODE_UNAVAILABLE:int = 11;
		public static const CODE_SEARCHFAILED:int = 12;
		public static const CODE_UNSUPPORTED:int = 13;
		public static const CODE_BUSY:int = 14;
		public static const CODE_EXPIRED:int = 15;
		public static const CODE_INPROGRESS:int = 16;
		public static function GeniresponseToString(value:int):String
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
				case CODE_DBERROR:return "Database error";
				case CODE_RPCERROR:return "RPC error";
				case CODE_UNAVAILABLE:return "Unavailable";
				case CODE_SEARCHFAILED:return "Search failed";
				case CODE_UNSUPPORTED:return "Unsupported";
				case CODE_BUSY:return "Busy";
				case CODE_EXPIRED:return "Expired";
				case CODE_INPROGRESS:return "In progress";
				default:return "Other error";
			}
		}
		
		/**
		 * Code as specified in a ProtoGENI XML-RPC result
		 */
		public var code:int;
		
		/**
		 * Output string specified in a ProtoGENI XML-RPC result
		 */
		public var output:String;
		
		/**
		 * Initializes a ProtoGENI XML-RPC call
		 * 
		 * @param taskUrl Base URL of the XML-RPC server
		 * @param taskModule ProtoGENI module to run (XmlrpcUtil.MODULE_*)
		 * @param taskMethod XML-RPC method being called (XmlrpcUtil.METHOD_*)
		 * @param taskName
		 * @param taskDescription
		 * @param taskParent
		 * @param taskRetryWhenPossible
		 * 
		 */
		public function ProtogeniXmlrpcTask(taskUrl:String,
											taskModule:String,
											taskMethod:String,
											taskName:String = "ProtoGENI XML-RPC Task",
											taskDescription:String = "Communicates with a ProtoGENI XML-RPC service",
											taskShortName:String = "",
											taskParent:TaskGroup = null,
											taskRetryWhenPossible:Boolean = true)
		{
			super(
				makeXmlrpcUrl(taskUrl, taskModule),
				taskMethod,
				taskName,
				taskDescription,
				taskShortName,
				taskParent,
				taskRetryWhenPossible
			);
		}
		
		/**
		 * Saves ProtoGENI-specific variables
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
			if (response.protogeni_error_log_urn != null)
			{
				errorLogUrn = String(response.protogeni_error_log_urn);
			}
			if (response.protogeni_error_log_url != null)
			{
				errorLogUrl = String(response.protogeni_error_log_url);
			}
			
			// Restart if busy
			if(code == CODE_BUSY)
			{
				addMessage(
					"Server is busy",
					"ProtoGENI XML-RPC server reported busy. " + output,
					LogMessage.LEVEL_WARNING
				);
				runTryRetry();
			}
			else
			{
				data = response.value;
				
				var responseMsg:String = "Code = "+GeniresponseToString(code);
				if(output != null && output.length > 0)
					responseMsg += ",\nOutput = "+output;
				responseMsg += ",\nRaw Response:\n"+server._response.data
				addMessage(
					"Received response",
					responseMsg
				);
				
				afterComplete(false);
			}
		}
		
		/**
		 * Recieved a code which wasn't expected, therefore an error
		 * 
		 */
		public function faultOnSuccess():void
		{
			var errorMessage:String = GeniresponseToString(code);
			if(output != null && output.length > 0)
				errorMessage += ": " + output;
			var errorLog:String = ErrorLog;
			if(errorLog.length > 0)
				errorMessage += "\n" + errorLog;
			afterError(
				new TaskError(
					errorMessage,
					TaskError.FAULT
				)
			);
		}
	}
}