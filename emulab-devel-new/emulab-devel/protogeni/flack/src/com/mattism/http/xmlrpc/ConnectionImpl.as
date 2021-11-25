/**
* @author       Matt Shaw <xmlrpc@mattism.com>
* @url          http://sf.net/projects/xmlrpcflash
*                       http://www.osflash.org/doku.php?id=xmlrpcflash
*
* @author   Daniel Mclaren (http://danielmclaren.net)
* @note     Updated to Actionscript 3.0
*/

package com.mattism.http.xmlrpc
{
  import com.flack.shared.SharedMain;
  import com.flack.shared.logging.LogMessage;
  import com.flack.shared.logging.Logger;
  import com.flack.geni.GeniMain;
  
  import flash.events.ErrorEvent;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.TimerEvent;
  import flash.net.URLLoader;
  import flash.net.URLRequest;
  import flash.net.URLRequestMethod;
  import flash.utils.Timer;

  public class ConnectionImpl extends EventDispatcher implements Connection
  {
    // Metadata
    private var _VERSION : String = "1.0.0";
    private var _PRODUCT : String = "ConnectionImpl";

    private var ERROR_NO_URL : String =  "No URL was specified for XMLRPCall.";

    private var _url : String;
    public var _method : MethodCall;
	public var _request : URLRequest;
    private var _rpc_response : Object;
    private var _parser : Parser;
    public var _response:JSLoader;
	private var _parsed_response : Object;

    private var _fault : MethodFault;

    public function ConnectionImpl(url : String)
    {
      //prepare method response handler
      //ignoreWhite = true;

      //init method
      _method = new MethodCallImpl();

      //init parser
      _parser = new ParserImpl();

      //init response
	  _response = new JSLoader();
			
      _response.addEventListener(Event.COMPLETE, _onLoad);
      _response.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);
	  _response.addEventListener(IOErrorEvent.IO_ERROR, ioError);
	  _response.addEventListener(IOErrorEvent.NETWORK_ERROR, ioError);
      if (url)
      {
        setUrl( url );
      }
    }
	
	public function cancel():void {
		_response.close();
	}

    public function cleanup() : void
    {
      _response.removeEventListener(Event.COMPLETE, _onLoad);
      _response.removeEventListener(IOErrorEvent.IO_ERROR, ioError);
	  _response.removeEventListener(IOErrorEvent.NETWORK_ERROR, ioError);
      _response.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);
    }

    public function call(method : String):void
    {
      _call( method );
    }

    private function _call( method:String ):void
    {
      if ( !getUrl() )
      {
        trace(ERROR_NO_URL);
        throw Error(ERROR_NO_URL);
      }
      else
      {
        debug( "Call -> " + method+"() -> " + getUrl());

        _method.setName( method );

        _request = new URLRequest();
		_request.contentType = 'text/xml';
		_request.data = _method.getXml();
		_request.method = URLRequestMethod.POST;
		_request.url = getUrl();

		try {
			_response.load(_request);
		}
		catch (error:ArgumentError)
		{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Argument error on load"));
			trace("An ArgumentError has occurred.");
		}
		catch (error:SecurityError)
		{
			dispatchEvent(new SecurityErrorEvent(SecurityErrorEvent.SECURITY_ERROR, false, false, "Security error on load"));
			trace("A SecurityError has occurred.");
		}
      }
    }

    private function _onLoad( evt:Event ):void
    {
		_fault = null;
		
		try
		{
			if (_response.bytesLoaded == 0)
			{
				trace("XMLRPC Fault: No data");
				dispatchEvent(
					new ErrorEvent(ErrorEvent.ERROR,
						false,
						false,
						"No data"
					)
				);
			}
			else
				trace("XMLRPC result: " + _response.data);
		}
		catch (err:Error)
		{
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR,
				false,
				false,
				"Problem checking result"));
			return;
		}
		
		var responseXML:XML = null;
		try
		{
			responseXML = new XML(_response.data);
		}
		catch (err:Error)
		{
			SharedMain.logger.add(
				new LogMessage(
					null,
					"",
					"Response was not XML",
					_response.data,
					"",
					LogMessage.LEVEL_FAIL
				)
			);
			dispatchEvent(
				new ErrorEvent(
					ErrorEvent.ERROR,
					false,
					false,
					"Response was not XML: " + _response.data
				)
			);
			return;
		}
		
		try
		{
		  if (responseXML.fault.length() > 0)
	      {
	        // fault
	        var parsedFault:Object = parseResponse(responseXML.fault.value.*[0]);
	        _fault = new MethodFaultImpl( parsedFault );
	        trace("XMLRPC Fault (" + _fault.getFaultCode() + "):\n"
	              + _fault.getFaultString());
	
	        dispatchEvent(
				new ErrorEvent(ErrorEvent.ERROR,
					false,
					false,
					_fault.toString()
				)
			);
	      }
	      else if (responseXML.params)
	      {
	        _parsed_response = parseResponse(responseXML.params.param.value[0]);
	
	        dispatchEvent(new Event(Event.COMPLETE));
	      }
	      else
	      {
	        dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Not sure how to parse XML-RPC result."));
	      }
		}
		catch (err:Error)
		{
			dispatchEvent(
				new ErrorEvent(
					ErrorEvent.ERROR,
					false,
					false,
					"Error in _onload: " + err.toString(),
					err.errorID
				)
			);
		}
			
    }

    protected function securityError(event : SecurityErrorEvent) : void
    {
      _fault = null;
      dispatchEvent(event);
    }
	
	protected function ioError(event:IOErrorEvent) : void
	{
		_fault = null;
		dispatchEvent(event);
	}

    private function parseResponse(xml:XML):Object
    {
      return _parser.parse( xml );
    }

    //public function __resolve( method:String ):void { _call( method ); }

    public function getUrl() : String
    {
      return _url;
    }

    public function setUrl(a : String) : void
    {
      _url = a;
    }

    public function addParam(o : Object, type : String) : void
    {
      _method.addParam( o,type );
    }

    public function removeParams() : void
    {
      _method.removeParams();
    }

    public function getResponse() : Object
    {
      return _parsed_response;
    }

    public function getFault() : MethodFault
    {
      return _fault;
    }

    override public function toString() : String
    {
      return '<xmlrpc.ConnectionImpl Object>';
    }

    private function debug(a : String) : void
    {
      /*trace( _PRODUCT + " -> " + a );*/
    }
  }
}
