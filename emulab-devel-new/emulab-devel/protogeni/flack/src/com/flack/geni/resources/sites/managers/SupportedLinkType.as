/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
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

package com.flack.geni.resources.sites.managers
{
        import com.flack.geni.resources.virt.LinkType;

        public class SupportedLinkType
        {
                public var name:String;
                public var maxConnections:Number = Number.POSITIVE_INFINITY;
                public var supportsManyManagers:Boolean = false;
                public var requiresIpAddresses:Boolean = false;
                public var supportsSameManager:Boolean = true;
                public var defaultCapacity:Number = NaN;
                public var level:int = int.MAX_VALUE;

                public function SupportedLinkType(newName:String)
                {
                        name = newName;
                        switch(name)
                        {
                                case LinkType.VLAN:
                                        maxConnections = 2;
                                        supportsManyManagers = true;
                                        defaultCapacity = 500;
                                        level = 1500;
                                        break;
                                case LinkType.ION:
                                case LinkType.GPENI:
                                        maxConnections = 2;
                                        supportsManyManagers = true;
                                        supportsSameManager = false;
                                        level = 100;
                                        break;
                                case LinkType.GRETUNNEL_V1:
                                case LinkType.GRETUNNEL_V2:
                        case LinkType.EGRE:
                                        maxConnections = 2;
                                        supportsManyManagers = true;
                                        requiresIpAddresses = true;
                                        level = 50;
                                        break;
                                case LinkType.LAN_V2:
                                        level = 0;
                                        break;
                                case LinkType.STITCHED:
                                        supportsManyManagers = true;
                                        level = 1000;
                                        break;
                                default:
                        }
                }

                public function get Clone():SupportedLinkType
                {
                        var clone:SupportedLinkType = new SupportedLinkType(name);
                        clone.maxConnections = maxConnections;
                        clone.supportsManyManagers = supportsManyManagers;
                        clone.requiresIpAddresses = requiresIpAddresses;
                        clone.supportsSameManager = supportsSameManager;
                        clone.level = level;
                        return clone;
                }
        }
}
