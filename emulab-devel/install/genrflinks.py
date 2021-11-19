#!/usr/bin/python

# A ghastly hack to automate the wires table population with RF links.
# This is hopelessly over-specific to the PhantomNet installation at
# the Utah Emulab: for instance, the internal topology of the model
# JFW 50PA-960 attenuator matrix is hard-coded, and it is assumed that
# any NUC node transmitting on port IN/OUT x is also receiving on port
# IN/OUT x+4.  But at least it's better than computing all this stuff
# by hand!

ins = [ "ue1", # 1
        "enodeb03", # 2
        "ue9", # 3
        "ue12", # 4
        "ue2", # 5
        "enodeb04", # 6
        "ue10", # 7
        "ue13", # 8
        "ue3", # 9
        "enodeb05", # 10       
        "ue11", # 11
        "ue14", # 12
        "ue4", # 13
        "enodeb06", # 14
        None, # 15 -- reserved for ue15
        None, # 16 -- reserved for ue16
        "nuc1", # 17
        "nuc4", # 18
        "nuc6", # 19
        "nuc9", # 20
        None, # 21 -- nuc1 RX
        None, # 22 -- nuc4 RX
        None, # 23 -- nuc6 RX
        None, # 24 -- nuc9 RX
        "nuc2", # 25
        "nuc5", # 26
        "nuc7", # 27
        "nuc10", # 28
        None, # 29 -- nuc2 RX
        None, # 30 -- nuc5 RX
        None, # 31 -- nuc7 RX
        None ] # 32 -- nuc10 RX

outs = [ "enodeb01", # 1
         "ue5", # 2
         "enodeb07", # 3
         "nuc11", # 4
         "enodeb02", # 5
         "ue6", # 6
         "enodeb08", # 7
         None, # 8 -- nuc11 RX
         "nuc3", # 9
         "ue7", # 10
         "nuc8", # 11
         None, # 12 -- reserved for nuc12
         None, # 13 -- nuc3 RX
         "ue8", # 14            
         None, # 15 -- nuc8 RX
         None ] # 16 -- reserved for nuc12 RX

nextifs = {}

def offset( node ):
    if node[ 0:2 ] == "ue":
        return 0
    elif node[ 0:2 ] == "en":
        return 1
    else:
        return 2

def makepath( i, o ):
    return str( o * 8 + i / 4 + 1 )
    
for e in range( 16 ):
    if not outs[ e ]: continue
    for u in range( 32 ):
        if not ins[ u ]: continue
        if e % 4 == u % 4:
            if ins[ u ] not in nextifs:
                nextifs[ ins[ u ] ] = 0
            if outs[ e ] not in nextifs:
                nextifs[ outs[ e ] ] = 0
            inif = nextifs[ ins[ u ] ]
            outif = nextifs[ outs[ e ] ]
            incard = inif + offset( ins[ u ] )
            outcard = outif + offset( outs[ e ] )
            if ins[ u ][ 0:3 ] == "nuc" and outs[ e ][ 0:3 ] == "nuc":
                path = makepath( u, e + 4 ) + "," + makepath( u + 4, e )
            elif ins[ u ][ 0:3 ] == "nuc":
                path = makepath( u, e ) + "," + makepath( u + 4, e )
            elif outs[ e ][ 0:3 ] == "nuc":
                path = makepath( u, e ) + "," + makepath( u, e + 4 )
            else:
                path = makepath( u, e )
            print "wap perl -w addrfpath " + ins[ u ] + " " + str( incard ) + " rf" + str( inif ) + " " + outs[ e ] + " " + str( outcard ) + " rf" + str( outif  ) + " " + path
            nextifs[ ins[ u ] ] += 1
            nextifs[ outs[ e ] ] += 1
