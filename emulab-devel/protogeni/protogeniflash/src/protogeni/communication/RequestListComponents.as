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
	import protogeni.resources.ComponentManager;

  public class RequestListComponents extends Request
  {
    public function RequestListComponents(shouldDiscoverResources:Boolean, shouldStartSlices:Boolean) : void
    {
      super("ListComponents", "Getting the information for the component managers", CommunicationUtil.listComponents);
	  startDiscoverResources = shouldDiscoverResources;
	  startSlices = shouldStartSlices;
    }
	
	override public function start():Operation
	{
		op.addField("credential", Main.protogeniHandler.CurrentUser.credential);
		return op;
	}

	// Should return Request or RequestQueueNode
	override public function complete(code : Number, response : Object) : *
	{
		var newCalls:RequestQueue = new RequestQueue();
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
		{
			for each(var obj:Object in response.value)
			{
				var newCm:ComponentManager = new ComponentManager();
				newCm.Hrn = obj.hrn;
				newCm.Url = obj.url;
				newCm.Urn = obj.urn;
				Main.protogeniHandler.ComponentManagers.add(newCm);
				if(startDiscoverResources)
				{
					newCm.Status = ComponentManager.INPROGRESS;
					newCalls.push(new RequestDiscoverResources(newCm));
				}
				Main.protogeniHandler.dispatchComponentManagerChanged(newCm);
			}
			if(startSlices)
				newCalls.push(new RequestUserResolve());
		}
		else
		{
			Main.protogeniHandler.rpcHandler.codeFailure(name, "Recieved GENI response other than success");
		}
		
		return newCalls.head;
	}
	
	private var startDiscoverResources:Boolean;
	private var startSlices:Boolean;
  }
}
