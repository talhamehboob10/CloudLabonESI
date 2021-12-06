/*
 * Copyright (c) 2009 University of Utah and the Flux Group.
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

  class RequestSliceEmbedding extends Request
  {
    public function RequestSliceEmbedding(newManager : ComponentManager,
                                          newNodes : ActiveNodes,
                                          newRequest : String,
                                          newUrl : String) : void
    {
      super("SES");
      manager = newManager;
      nodes = newNodes;
      request = newRequest;
      url = newUrl;
    }

    override public function cleanup() : void
    {
      super.cleanup();
    }

    override public function start(credential : Credential) : Operation
    {
      opName = "Embedding Slice";
      op.reset(Geni.map);
      op.addField("credential", credential.base);
      op.addField("advertisement", manager.getAd());
      op.addField("request", request);
      op.setUrl(url);
      return op;
    }

    override public function complete(code : Number, response : Object,
                                      credential : Credential) : Request
    {
      if (code == 0)
      {
        nodes.mapRequest(response.value, manager);
      }
      return null;
    }

    override public function fail(event : ErrorEvent) : Request
    {
      return null;
    }

    var manager : ComponentManager;
    var nodes : ActiveNodes;
    var request : String;
    var url : String;
  }
}
