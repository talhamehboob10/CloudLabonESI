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
        import com.mattism.http.xmlrpc.util.XMLRPCDataTypes;
        import com.mattism.http.xmlrpc.util.XMLRPCUtils;

        public class MethodCallImpl
        implements MethodCall
        {

                private var _VERSION:String = "1.0";
                private var _PRODUCT:String = "MethodCallImpl";
                private var _TRACE_LEVEL:Number = 3;
                private var _parameters:Array;
                private var _name:String;
                private var _xml:XML;

                public function MethodCallImpl(){
                        removeParams();

                        debug("MethodCallImpl instance created. (v" + _VERSION + ")");
                }


                public function setName( name:String ):void {
                        _name=name;
                }

                public function addParam(param_value:Object,param_type:String):void {
                        debug("MethodCallImpl.addParam("+arguments+")");
                        _parameters.push({type:param_type,value:param_value});
                }

                public function removeParams():void {
                        _parameters=new Array();
                }

                public function getXml():XML {
                        debug("getXml()");

                        var ParentNode:XML;
                        var ChildNode:XML;

                        // Create the <methodCall>...</methodCall> root node
                        ParentNode = <methodCall />;
                        _xml = ParentNode;

                        // Create the <methodName>...</methodName> node
                        ChildNode = <methodName>{_name}</methodName>;
                        ParentNode.appendChild(ChildNode);

                        // Create the <params>...</params> node
                        ChildNode = <params />;
                        ParentNode.appendChild(ChildNode);
                        ParentNode = ChildNode;

                        // build nodes that hold all the params
                        debug("Render(): Creating the params node.");

                        var i:Number;
                        for (i=0; i<_parameters.length; i++) {
                                debug("PARAM: " + [_parameters[i].type,_parameters[i].value]);
                                ChildNode = <param />;
                                ChildNode.appendChild( createParamsNode(_parameters[i]) );
                                ParentNode.appendChild(ChildNode);
                        }
                        debug("Render(): Resulting XML document:");
                        debug("Render(): " + _xml.toXMLString());

                        return _xml;
                }


          private function createParamsNode( parameter:Object ):XML
          {
            debug("CreateParameterNode()");
            var Node:XML = <value />;
            var TypeNode:XML;
			
			if(parameter == null)
				return Node;

            if (parameter is String)
				parameter = {value:parameter};
            else if(parameter is Boolean)
				parameter = {value:parameter};
			else if(parameter is Number)
				parameter = {value:parameter};
			else if(parameter is Date)
				parameter = {value:parameter};
            else if (parameter && parameter.value == null)
				parameter = {value:parameter};

            if ( typeof parameter == "object")
            {
              // Default to
              if (!parameter.type){
                var v:Object = parameter.value;
                if ( v is Array )
                  parameter.type=XMLRPCDataTypes.ARRAY;
                else if ( v is String )
                  parameter.type=XMLRPCDataTypes.STRING;
                else if ( v is Boolean )
                  parameter.type=XMLRPCDataTypes.BOOLEAN;
				else if ( v is Number )
					parameter.type=XMLRPCDataTypes.DOUBLE;
				else if ( v is Date )
					parameter.type=XMLRPCDataTypes.DATETIME;
                else if ( v is Object )
                  parameter.type=XMLRPCDataTypes.STRUCT;
                else
                  parameter.type = XMLRPCDataTypes.STRING;
              }

              // Handle Explicit Simple Objects
              if ( XMLRPCUtils.isSimpleType(parameter.type) ) {
                //cdata is really a string type with a cdata wrapper, so don't really make a 'cdata' tag
                parameter = fixCDATAParameter(parameter);

                debug("CreateParameterNode(): Creating object '"+parameter.value+"' as type "+parameter.type);
                if(parameter.type == XMLRPCDataTypes.BOOLEAN)
					parameter.value = parameter.value ? 1 : 0;
				TypeNode = <{parameter.type}>{parameter.value}</{parameter.type}>;
                Node.appendChild(TypeNode);
                return Node;
              }

              // Handle Array Objects
              if (parameter.type == XMLRPCDataTypes.ARRAY) {
                var DataNode:XML;
                debug("CreateParameterNode(): >> Begin Array");
                TypeNode = <array />;
                DataNode = <data />;
                //for (var i:String in parameter.value) {
                //      DataNode.appendChild(createParamsNode(parameter.value[i]));
                //}
                for (var i:int=0; i<parameter.value.length; i++) {
                  DataNode.appendChild( createParamsNode( parameter.value[i] ) );
                }
                TypeNode.appendChild(DataNode);
                debug("CreateParameterNode(): << End Array");
                Node.appendChild(TypeNode);
                return Node;
              }
              // Handle Struct Objects
              if (parameter.type == XMLRPCDataTypes.STRUCT) {
                debug("CreateParameterNode(): >> Begin struct");
                TypeNode = <struct />;
                for (var x:String in parameter.value) {
                  var MemberNode:XML = <member />;

                  // add name node
                  MemberNode.appendChild(<name>{x}</name>);

                  // add value node
//                  MemberNode.appendChild(<value>{parameter.value[x]}</value>);
                  MemberNode.appendChild(createParamsNode(parameter.value[x]));

                  TypeNode.appendChild(MemberNode);
                }
                debug("CreateParameterNode(): << End struct");
                Node.appendChild(TypeNode);
                return Node;
              }
            }

            return Node;
          }


                /*///////////////////////////////////////////////////////
                fixCDATAParameter()
                ?:      Turns a cdata parameter into a string parameter with
                                CDATA wrapper
                IN:         Possible CDATA parameter
                OUT:    Same parameter, CDATA'ed is necessary
                ///////////////////////////////////////////////////////*/
                private function fixCDATAParameter(parameter:Object):Object{
                        if (parameter.type==XMLRPCDataTypes.CDATA){
                                parameter.type=XMLRPCDataTypes.STRING;
                                parameter.value='<![CDATA['+parameter.value+']]>';
                        }
                        return parameter;
                }


                public function cleanUp():void {
                        //removeParams();
                        //parseXML(null);
                }

                private function debug(a:Object):void {
                        trace(a);
                }
        }
}
