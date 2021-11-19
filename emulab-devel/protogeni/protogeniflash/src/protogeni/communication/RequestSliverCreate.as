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
  import flash.events.ErrorEvent;
  
  import protogeni.resources.Slice;
  import protogeni.resources.Sliver;
  import protogeni.resources.VirtualLinkCollection;
  import protogeni.resources.VirtualNodeCollection;

  public class RequestSliverCreate extends Request
  {
    public function RequestSliverCreate(s:Sliver) : void
    {
		super("SliverCreate", "Creating sliver on " + s.componentManager.Hrn + " for slice named " + s.slice.hrn, CommunicationUtil.createSliver);
		sliver = s;
		s.created = false;
		op.addField("slice_urn", sliver.slice.urn);
		op.addField("rspec", sliver.getRequestRspec().toXMLString());
		op.addField("keys", sliver.slice.creator.keys);
		op.addField("credentials", new Array(sliver.slice.credential));
		op.setExactUrl(sliver.componentManager.Url);
		op.timeout = 360;
    }
	
	override public function complete(code : Number, response : Object) : *
	{
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
		{
			sliver.credential = response.value[0];
			sliver.created = true;

			sliver.rspec = new XML(response.value[1]);
			sliver.parseRspec();
			
			var old:Slice = Main.protogeniHandler.CurrentUser.slices.getByUrn(sliver.slice.urn);
			if(old != null)
			{
				if(old.slivers.getByUrn(sliver.urn) != null)
					old.slivers.removeItemAt(old.slivers.getItemIndex(old.slivers.getByUrn(sliver.urn)));
				old.slivers.addItem(sliver);
			}
			
			Main.protogeniHandler.dispatchSliceChanged(sliver.slice);

			return new RequestSliverStatus(sliver);
		}
		else
		{
			// Cancel remaining calls
			var tryDeleteNode:RequestQueueNode = this.node.next;
			while(tryDeleteNode != null && tryDeleteNode is RequestSliverCreate && (tryDeleteNode as RequestSliverCreate).sliver.slice == sliver.slice)
			{
				Main.protogeniHandler.rpcHandler.remove(tryDeleteNode.item);
				tryDeleteNode = tryDeleteNode.next;
			}
			
			// Show the error
			Main.log.open();
		}
		
		return null;
	}

    public var sliver:Sliver;
  }
}
