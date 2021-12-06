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
  import com.mattism.http.xmlrpc.ConnectionImpl;
  
  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.SecurityErrorEvent;
  import flash.system.Security;
  import flash.utils.Dictionary;

  public class Operation
  {
    public function Operation(qualifiedMethod : Array = null, newNode:Request = null) : void
    {
      server = null;
	  node = newNode;
      reset(qualifiedMethod);
    }

    public function reset(qualifiedMethod : Array) : void
    {
      cleanup();
      if (qualifiedMethod != null)
      {
        module = qualifiedMethod[0];
        method = qualifiedMethod[1];
      }
      clearFields();
      resetUrl();
      if (server != null)
      {
        server.cleanup();
        server = null;
      }
      success = null;
      failure = null;
    }

    public function resetUrl() : void
    {
      url = "https://" + CommunicationUtil.defaultHost + SERVER_PATH;
      if (module != null)
      {
        url += module;
      }
    }

    public function setUrl(newUrl : String) : void
    {
      url = newUrl;
      if (module != null)
      {
        url += "/" + module;
      }
    }

    public function setExactUrl(newUrl : String) : void
    {
      url = newUrl;
    }

    public function getUrl() : String
    {
      return url;
    }

    public function addField(key : String, value : Object) : void
    {
      param[key] = value;
    }

    public function clearFields() : void
    {
      param = new Object();
    }

    public function call(newSuccess : Function, newFailure : Function) : void
    {
      try
      {
        if (visitedSites[url] != true)
        {
          visitedSites[url] = true;
          var hostPattern : RegExp = /^(http(s?):\/\/([^\/]+))(\/.*)?$/;
          var match : Object = hostPattern.exec(url);
          if (match != null)
          {
            var host : String = match[1];
            Security.loadPolicyFile(host + "/protogeni/crossdomain.xml");
          }
        }
        success = newSuccess;
        failure = newFailure;
        server = new ConnectionImpl(url);
		server.timeout = timeout;
        server.addEventListener(Event.COMPLETE, callSuccess);
        server.addEventListener(ErrorEvent.ERROR, callFailure);
        server.addEventListener(SecurityErrorEvent.SECURITY_ERROR, callFailure);
        server.addParam(param, "struct");
        server.call(method);
      }
      catch (e : Error)
      {

        Main.log.appendMessage(new LogMessage(url, "Error", "\n\nException on XMLRPC Call: "
                                     + e.toString() + "\n\n", true));
      }
    }

    public function getSendXml() : String
    {
		try
		{
			var x:XML = server._method.getXml();
		} catch(e:Error)
		{
			return "";
		}
		
		if(x == null)
			return "";
		else
      		return x.toString();
    }

    public function getResponseXml() : String
    {
      return String(server._response.data);
    }

    private function callSuccess(event : Event) : void
    {
//      cleanup();

      success(node, Number(server.getResponse().code),
//              server.getResponse().value.toString(),
//              String(server.getResponse().output),
              server.getResponse());
    }

    private function callFailure(event : ErrorEvent) : void
    {
//      cleanup();
      failure(node, event, server.getFault());
    }

    public function cleanup() : void
    {
      if (server != null)
      {
        server.removeEventListener(Event.COMPLETE, callSuccess);
        server.removeEventListener(ErrorEvent.ERROR, callFailure);
        server.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,
                                   callFailure);
        server.cleanup();
        server = null;
      }
    }

    private var module : String;
    private var method : String;
    private var url : String;
    private var param : Object;
    private var server : ConnectionImpl;
    private var success : Function;
    private var failure : Function;
	private var node:Request;
	
	public var timeout:int = 60;

    private static var SERVER_PATH : String = "/protogeni/xmlrpc/";

    private static var visitedSites : Dictionary = new Dictionary();
  }
}
