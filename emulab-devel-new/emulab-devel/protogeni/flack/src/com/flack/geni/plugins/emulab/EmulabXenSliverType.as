/*
 * Copyright (c) 2013 University of Utah and the Flux Group.
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

package com.flack.geni.plugins.emulab
{
        import com.flack.geni.plugins.SliverTypeInterface;
        import com.flack.geni.plugins.SliverTypePart;
        import com.flack.geni.resources.physical.PhysicalNode;
        import com.flack.geni.resources.virt.VirtualInterface;
        import com.flack.geni.resources.virt.VirtualNode;

        import mx.collections.ArrayCollection;

        public class EmulabXenSliverType implements SliverTypeInterface
        {
                static public const TYPE_EMULABXEN:String = "emulab-xen";

                public function EmulabXenSliverType()
                {
                }

                public function get Name():String { return TYPE_EMULABXEN; }

                public function get namespace():Namespace
                {
                        return null;
                }

                public function get schema():String
                {
                        return "";
                }

                public function get Part():SliverTypePart
                {
                        return null;
                }

                public function get Clone():SliverTypeInterface
                {
                        var clone:EmulabXenSliverType = new EmulabXenSliverType();
                        return clone;
                }

                public function applyToSliverTypeXml(node:VirtualNode, xml:XML):void
                {
                }

                public function applyFromAdvertisedSliverTypeXml(node:PhysicalNode, xml:XML):void
                {
                }

                public function applyFromSliverTypeXml(node:VirtualNode, xml:XML):void
                {
                }

                public function interfaceRemoved(iface:VirtualInterface):void
                {
                }

                public function interfaceAdded(iface:VirtualInterface):void
                {
                }

                public function canAdd(node:VirtualNode):Boolean
                {
                        return true;
                }

                public function get SimpleList():ArrayCollection
                {
                        return null;
                }
        }
}
