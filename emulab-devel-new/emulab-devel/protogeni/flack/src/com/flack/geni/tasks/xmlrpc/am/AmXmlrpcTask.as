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

package com.flack.geni.tasks.xmlrpc.am
{
	import com.flack.geni.resources.docs.GeniCredential;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskGroup;
	import com.flack.shared.tasks.xmlrpc.XmlrpcTask;
	
	import flash.events.Event;

	/**
	 * Supports the syntax for XML-RPC calls with GENI AM v4
	 * 
	 * @author mstrum
	 * 
	 */
	public class AmXmlrpcTask extends XmlrpcTask
	{
		// Methods
		// Added in v1
		public static const METHOD_GETVERSION:String = "GetVersion";
		public static const METHOD_LISTRESOURCES:String = "ListResources";
		// Added in v1 (deprecated)
		public static const METHOD_CREATESLIVER:String = "CreateSliver";
		public static const METHOD_DELETESLIVER:String = "DeleteSliver";
		public static const METHOD_RENEWSLIVER:String = "RenewSliver";
		public static const METHOD_SLIVERSTATUS:String = "SliverStatus";
		// Added in v3
		public static const METHOD_RENEW:String = "Renew";
		public static const METHOD_ALLOCATE:String = "Allocate";
		public static const METHOD_DELETE:String = "Delete";
		public static const METHOD_DESCRIBE:String = "Describe";
		public static const METHOD_PROVISION:String = "Provision";
		public static const METHOD_STATUS:String = "Status";
		public static const METHOD_PERFORMOPERATIONALACTION:String = "PerformOperationalAction";
		// Added in v4
		public static const METHOD_CANCEL:String = "Cancel";
		public static const METHOD_UPDATE:String = "Update";
		// Available at ProtoGENI hosts
		public static const METHOD_LISTIMAGES:String = "ListImages";
		public static const CREATE_IMAGE:String = "CreateImage";
		
		// GENI response codes
		public static const GENICODE_SUCCESS:int = 0;
		public static const GENICODE_BADARGS:int  = 1;
		public static const GENICODE_ERROR:int = 2;
		public static const GENICODE_FORBIDDEN:int = 3;
		public static const GENICODE_BADVERSION:int = 4;
		public static const GENICODE_SERVERERROR:int = 5;
		public static const GENICODE_TOOBIG:int = 6;
		public static const GENICODE_REFUSED:int = 7;
		public static const GENICODE_TIMEDOUT:int = 8;
		public static const GENICODE_DBERROR:int = 9;
		public static const GENICODE_RPCERROR:int = 10;
		public static const GENICODE_UNAVAILABLE:int = 11;
		public static const GENICODE_SEARCHFAILED:int = 12;
		public static const GENICODE_UNSUPPORTED:int = 13;
		public static const GENICODE_BUSY:int = 14;
		public static const GENICODE_EXPIRED:int = 15;
		public static const GENICODE_INPROGRESS:int = 16;
		public static const GENICODE_ALREADYEXISTS:int = 17;
		public static function GeniresponseToString(value:int):String
		{
			switch(value)
			{
				case GENICODE_SUCCESS:return "Success";
				case GENICODE_BADARGS:return "Bad Arguments";
				case GENICODE_ERROR:return "Error";
				case GENICODE_FORBIDDEN:return "Operation Forbidden";
				case GENICODE_BADVERSION:return "Bad Version";
				case GENICODE_SERVERERROR:return "Server Error";
				case GENICODE_TOOBIG:return "Too Big";
				case GENICODE_REFUSED:return "Operation Refused";
				case GENICODE_TIMEDOUT:return "Operation Timed Out";
				case GENICODE_DBERROR:return "Database Error";
				case GENICODE_RPCERROR:return "RPC Error";
				case GENICODE_UNAVAILABLE:return "Unavailable";
				case GENICODE_SEARCHFAILED:return "Search Failed";
				case GENICODE_UNSUPPORTED:return "Operation Unsupported";
				case GENICODE_BUSY:return "Busy";
				case GENICODE_EXPIRED:return "Expired";
				case GENICODE_INPROGRESS:return "In progress";
				case GENICODE_INPROGRESS:return "Already Exists";
				default:return "Other error ("+value+")";
			}
		}
		
		/**
		 * API version to use, NaN means we don't know
		 */
		public var apiVersion:Number = NaN;
		
		/**
		 * Code as specified in a GENI XML-RPC result
		 */
		public var genicode:int;
		
		/**
		 * Output string specified in a GENI XML-RPC result
		 */
		public var output:String;

		public var amType:String = "";
		public var amCode:Number = NaN;
		
		/**
		 * Initializes a GENI AM XML-RPC call
		 * 
		 * @param taskUrl Base URL of the XML-RPC server
		 * @param taskMethodXML-RPC method being called (METHOD_*)
		 * @param taskApiVersion Version of the API to use
		 * @param taskName
		 * @param taskDescription
		 * @param taskShortName
		 * @param taskParent
		 * @param taskRetryWhenPossible
		 * 
		 */
		public function AmXmlrpcTask(taskUrl:String,
									 taskMethod:String,
									 taskApiVersion:Number,
									 taskName:String = "GENI XML-RPC Task",
									 taskDescription:String = "Communicates with a GENI XML-RPC service",
									 taskShortName:String = "",
									 taskParent:TaskGroup = null,
									 taskRetryWhenPossible:Boolean = true)
		{
			super(
				taskUrl,
				taskMethod,
				taskName,
				taskDescription,
				taskShortName,
				taskParent,
				taskRetryWhenPossible
			);
			apiVersion = taskApiVersion;
		}
		
		/**
		 * Saves GENI AM API variables
		 * 
		 * @param event
		 * 
		 */
		override public function callSuccess(event:Event):void
		{
			cancelTimers();
			
			var response:Object = server.getResponse();
			
			// GetVersion doesn't specify, so the api version is in the response
			if(!apiVersion && response.geni_api != null)
			{
				apiVersion = Number(response.geni_api);
			}
			
			switch(apiVersion)
			{
				case 1:
					data = response;
					addMessage(
						"Received response",
						server._response.data
					);
					break;
				case 2:
				case 3:
				default:
					genicode = int(response.code.geni_code);
					output = response.output;
					
					if (response.protogeni_error_log_urn != null)
					{
						errorLogUrn = String(response.protogeni_error_log_urn);
					}
					if (response.protogeni_error_log_url != null)
					{
						errorLogUrl = String(response.protogeni_error_log_url);
					}
					if (response.am_type != null)
					{
						amType = String(response.am_type);
					}
					if (response.am_code != null)
					{
						amCode = Number(response.am_code);
					}
					
					// Restart if busy
					if(genicode == GENICODE_BUSY)
					{
						addMessage(
							"Server is busy",
							"GENI XML-RPC server reported busy. " + output,
							LogMessage.LEVEL_WARNING
						);
						runTryRetry();
						return;
					}
					else
					{
						data = response.value;
						
						var responseMsg:String = "Code = "+GeniresponseToString(genicode);
						if(output != null && output.length > 0)
							responseMsg += ",\nOutput = "+output;
						responseMsg += ",\nRaw Response:\n"+server._response.data
						addMessage(
							"Received response",
							responseMsg
						);
					}
					break;
			}
			
			afterComplete(false);
		}
		
		/**
		 * Recieved a code which wasn't expected, therefore an error
		 * 
		 */
		public function faultOnSuccess():void
		{
			var errorMessage:String = GeniresponseToString(genicode);
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
		
		public static function credentialToObject(credential:GeniCredential, apiVersion:Number):Object
		{
			if(apiVersion < 3)
				return credential.Raw;
			else
			{
				var credentialObject:Object =
					{
						geni_type: credential.version.type,
						geni_version: credential.version.version.toString(),
						geni_value: credential.Raw
					};
				return credentialObject;
			}
		}
	}
}