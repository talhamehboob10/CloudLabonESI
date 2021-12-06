/*
 * Copyright (c) 2008, 2009 University of Utah and the Flux Group.
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

package protogeni.communication
{
	import com.mattism.http.xmlrpc.MethodFault;
	
	import flash.events.ErrorEvent;
	
  public class CommunicationUtil
  {
	  // Namespaces
	  public static var rspec1Namespace:String = "http://www.protogeni.net/resources/rspec/0.1";
	  public static var rspec2Namespace:String = "http://www.protogeni.net/resources/rspec/0.2";
	  
	  // Error codes
	  public static var GENIRESPONSE_SUCCESS : int = 0;
	  public static var GENIRESPONSE_BADARGS : int  = 1;
	  public static var GENIRESPONSE_ERROR : int = 2;
	  public static var GENIRESPONSE_FORBIDDEN : int = 3;
	  public static var GENIRESPONSE_BADVERSION : int = 4;
	  public static var GENIRESPONSE_SERVERERROR : int = 5;
	  public static var GENIRESPONSE_TOOBIG : int = 6;
	  public static var GENIRESPONSE_REFUSED : int = 7;
	  public static var GENIRESPONSE_TIMEDOUT : int = 8;
	  public static var GENIRESPONSE_DBERROR : int = 9;
	  public static var GENIRESPONSE_RPCERROR : int = 10;
	  public static var GENIRESPONSE_UNAVAILABLE : int = 11;
	  public static var GENIRESPONSE_SEARCHFAILED : int = 12;
	  public static var GENIRESPONSE_UNSUPPORTED : int = 13;
	  public static var GENIRESPONSE_BUSY : int = 14;
	  public static var GENIRESPONSE_EXPIRED : int = 15;
	  public static var GENIRESPONSE_INPROGRESS : int = 16;
	  
	  public static function GeniresponseToString(value:int):String
	  {
		  switch(value) {
			  case GENIRESPONSE_SUCCESS : return "Success";
			  case GENIRESPONSE_BADARGS: return "Malformed arguments";
			  case GENIRESPONSE_ERROR: return "General Error";
			  case GENIRESPONSE_FORBIDDEN : return "Forbidden";
			  case GENIRESPONSE_BADVERSION : return "Bad version";
			  case GENIRESPONSE_SERVERERROR : return "Server error";
			  case GENIRESPONSE_TOOBIG : return "Too big";
			  case GENIRESPONSE_REFUSED : return "Refused";
			  case GENIRESPONSE_TIMEDOUT : return "Timed out";
			  case GENIRESPONSE_DBERROR : return "Database error";
			  case GENIRESPONSE_RPCERROR : return "RPC error";
			  case GENIRESPONSE_UNAVAILABLE : return "Unavailable";
			  case GENIRESPONSE_SEARCHFAILED : return "Search failed";
			  case GENIRESPONSE_UNSUPPORTED : return "Unsupported";
			  case GENIRESPONSE_BUSY : return "Busy";
			  case GENIRESPONSE_EXPIRED : return "Expired";
			  case GENIRESPONSE_INPROGRESS : return "In progress";
			  default: return "Other";
		  }
	  }
	  
    private static var sa : String = "sa";
    private static var cm : String = null;
    private static var ses : String = "ses";
    private static var ch : String = "ch";

//    public static var defaultAuthority : String = "myelab.testbed.emulab.net";
    public static var defaultAuthority : String = "emulab.net";

//    public static var defaultHost : String = "myboss.myelab.testbed.emulab.net:446";
    public static var defaultHost : String = "boss.emulab.net";

    public static var sesUrl : String = "https://myboss.emulab.geni.emulab.net/protogeni/xmlrpc/";
//"https://boss.emulab.net:443/protogeni/xmlrpc/";
    public static var chUrl : String = "https://boss.emulab.net/protogeni/xmlrpc/";

    public static var getCredential : Array = new Array(sa, "GetCredential");
    public static var getKeys : Array = new Array(sa, "GetKeys");
    public static var resolve : Array = new Array(sa, "Resolve");
    public static var remove : Array = new Array(sa, "Remove");
    public static var register : Array = new Array(sa, "Register");

    public static var discoverResources : Array = new Array(cm, "DiscoverResources");
	public static var resolveResource : Array = new Array(cm, "Resolve");
	// Ticket
    public static var getTicket : Array = new Array(cm, "GetTicket");
    public static var updateTicket : Array = new Array(cm, "UpdateTicket");
    public static var redeemTicket : Array = new Array(cm, "RedeemTicket");
    public static var releaseTicket : Array = new Array(cm, "ReleaseTicket");
	// Slice
    public static var sliceStatus : Array = new Array(cm, "SliceStatus");
	public static var deleteSlice : Array = new Array(cm, "DeleteSlice");
	// Sliver
    public static var getSliver : Array = new Array(cm, "GetSliver");
    public static var sliverStatus : Array = new Array(cm, "SliverStatus");
    public static var sliverTicket : Array = new Array(cm, "SliverTicket");
    public static var createSliver : Array = new Array(cm, "CreateSliver");
	public static var startSliver : Array = new Array(cm, "StartSliver");
	public static var stopSliver : Array = new Array(cm, "StopSliver");
	public static var restartSliver : Array = new Array(cm, "RestartSliver");
	public static var updateSliver : Array = new Array(cm, "UpdateSliver");

    public static var map : Array = new Array(ses, "Map");

    public static var listComponents : Array = new Array(ch, "ListComponents");
	
	public static function getResponse(name : String, url : String,
									   xml : String) : String
	{
		return "\n-----------------------------------------\n"
		+ "RESPONSE: " + name + "\n"
			+ "URL: " + url + "\n"
			+ "-----------------------------------------\n\n"
			+ xml;
	}
	
	public static function getSend(name : String, url : String,
								   xml : String) : String
	{
		return "\n-----------------------------------------\n"
		+ "SEND: " + name + "\n"
			+ "URL: " + url + "\n"
			+ "-----------------------------------------\n\n"
			+ xml;
	}
	
	public static function getFailure(opName : String, url : String,
									  event : ErrorEvent,
									  fault : MethodFault) : String
	{
		if (fault != null)
		{
			return "FAILURE fault: " + opName + ": " + fault.getFaultString()
				+ "\nURL: " + url + "\n"
				+ "\n";
		}
		else
		{
			return "FAILURE event: " + opName + ": " + event.toString()
				+ "\nURL: " + url + "\n"
				+ "\n";
		}
	}
  }
}
