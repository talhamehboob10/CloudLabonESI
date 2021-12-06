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
	import mx.controls.Alert;
	
	import protogeni.Util;
	import protogeni.resources.Slice;
	import protogeni.resources.Sliver;

  public class RequestSliceResolve extends Request
  {
    public function RequestSliceResolve(s:Slice, willBeCreating:Boolean = false) : void
    {
		var name:String;
		if(s.hrn == null)
			name = Util.shortenString(s.urn, 12);
		else
			name = s.hrn;
		super("SliceResolve (" + name + ")", "Resolving slice named " + s.hrn, CommunicationUtil.resolve);
		slice = s;
		isCreating = willBeCreating;
		op.addField("credential", Main.protogeniHandler.CurrentUser.credential);
		op.addField("urn", slice.urn);
		op.addField("type", "Slice");
		op.setUrl("https://boss.emulab.net:443/protogeni/xmlrpc");
    }
	
	override public function complete(code : Number, response : Object) : *
	{
		var newRequest:Request = null;
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
		{
			if(isCreating)
			{
				Alert.show("Slice '" + slice.urn + "' already exists");
				Main.log.setStatus("Slice exists", true);
			}
			else
			{
				slice.uuid = response.value.uuid;
				slice.creator = Main.protogeniHandler.CurrentUser;
				slice.hrn = response.value.hrn;
				slice.urn = response.value.urn;
				for each(var sliverCm:String in response.value.component_managers) {
					var newSliver:Sliver = new Sliver(slice);
					newSliver.componentManager = Main.protogeniHandler.ComponentManagers.getByUrn(sliverCm);
					slice.slivers.addItem(newSliver);
				}
				
				Main.protogeniHandler.dispatchSliceChanged(slice);
				newRequest = new RequestSliceCredential(slice);
			}
		}
		else
		{
			if(isCreating)
			{
				newRequest = new RequestSliceRemove(slice);
			}
			else
			{
				Main.protogeniHandler.rpcHandler.codeFailure(name, "Recieved GENI response other than success");
				Main.protogeniHandler.mapHandler.drawAll();
			}
			
		}
		
		return newRequest;
	}

    private var slice : Slice;
	private var isCreating:Boolean;
  }
}
