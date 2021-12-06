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
  import flash.events.SecurityErrorEvent;
  import flash.utils.ByteArray;
  
  import mx.utils.Base64Decoder;
  
  import protogeni.Util;
  import protogeni.resources.ComponentManager;

  public class RequestDiscoverResources extends Request
  {
	  
    public function RequestDiscoverResources(newCm:ComponentManager) : void
    {
		super("DiscoverResources (" + Util.shortenString(newCm.Hrn, 15) + ")", "Discovering resources for " + newCm.Hrn, CommunicationUtil.discoverResources, true, true, false);
		op.timeout = 60;
		cm = newCm;
		op.addField("credentials", new Array(Main.protogeniHandler.CurrentUser.credential));
		op.addField("compress", true);
		op.setExactUrl(newCm.DiscoverResourcesUrl());
    }
	
	override public function complete(code : Number, response : Object) : *
	{
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
		{
			var decodor:Base64Decoder = new Base64Decoder();
			decodor.decode(response.value);
			var bytes:ByteArray = decodor.toByteArray();
			bytes.uncompress();
			var decodedRspec:String = bytes.toString();
			
			cm.Rspec = new XML(decodedRspec);
			/*try
			{
				cm.Rspec = new XML(decodedRspec);
			} catch(e:Error)
			{
				// Remove prefixes and try again
				var prefixPattern:RegExp = /(<[\/]*)([\w]*:)/gi;
				decodedRspec = decodedRspec.replace(prefixPattern, "$1");
				cm.Rspec = new XML(decodedRspec);
			}*/
			
			cm.processRspec(cleanup);
		}
		else
		{
			cm.errorMessage = response.output;
			cm.errorDescription = CommunicationUtil.GeniresponseToString(code) + ": " + cm.errorMessage;
			cm.Status = ComponentManager.FAILED;
			this.removeImmediately = true;
			Main.protogeniHandler.dispatchComponentManagerChanged(cm);
		}
		
		return null;
	}

    override public function fail(event : ErrorEvent, fault : MethodFault) : *
    {
		cm.errorMessage = event.toString();
		cm.errorDescription = "";
		if(cm.errorMessage.search("#2048") > -1)
			cm.errorDescription = "Stream error, possibly due to server error.  Another possible error might be that you haven't added an exception for:\n" + cm.DiscoverResourcesUrl();
		else if(cm.errorMessage.search("#2032") > -1)
			cm.errorDescription = "IO error, possibly due to the server being down";
		else if(cm.errorMessage.search("timed"))
			cm.errorDescription = event.text;
		
		cm.Status = ComponentManager.FAILED;
		Main.protogeniHandler.dispatchComponentManagerChanged(cm);

      return null;
    }
	
	override public function cancel():void
	{
		cm.Status = ComponentManager.UNKOWN;
		Main.protogeniHandler.dispatchComponentManagerChanged(cm);
		op.cleanup();
	}
	
	override public function cleanup():void
	{
		if(cm.Status == ComponentManager.INPROGRESS)
			cm.Status = ComponentManager.FAILED;
		running = false;
		Main.protogeniHandler.rpcHandler.remove(this, false);
		Main.protogeniHandler.dispatchComponentManagerChanged(cm);
		op.cleanup();
		Main.protogeniHandler.rpcHandler.start();
	}

    private var cm : ComponentManager;
  }
}
