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

  public class Request
  {
    public function Request(newName:String = "", newDetails:String = "", qualifiedMethod : Array = null, shouldContinueOnErrors:Boolean = false, shouldStartImmediately:Boolean = false, shouldRemoveImmediately:Boolean = true) : void
    {
      op = new Operation(qualifiedMethod, this);
	  op.timeout = 180;
      name = newName;
	  details = newDetails;
	  continueOnError = shouldContinueOnErrors;
	  startImmediately = shouldStartImmediately;
	  removeImmediately = shouldRemoveImmediately;
    }

    public function cleanup() : void
    {
      op.cleanup();
    }
	
	public function cancel():void
	{
		cleanup();
	}

    public function getSendXml() : String
    {
      return op.getSendXml();
    }

    public function getResponseXml() : String
    {
      return op.getResponseXml();
    }

    public function getUrl() : String
    {
      return op.getUrl();
    }

    public function start() : Operation
    {
      return op;
    }

    public function complete(code : Number, response : Object) : *
    {
      return null;
    }

    public function fail(event : ErrorEvent, fault : MethodFault) : *
    {
		return null;
    }

	public var op:Operation;
	[Bindable]
	public var name:String;
	[Bindable]
	public var details:String;
	public var startImmediately:Boolean;
	public var removeImmediately:Boolean;
	public var continueOnError:Boolean;
	public var running:Boolean = false;
	
	public var node:RequestQueueNode;
  }
}
