from Products.PlonePAS.Extensions.Install import activatePluginInterfaces
from Products.CMFCore.utils import getToolByName
from StringIO import StringIO
from plugins.emulab import addEmulabPlugin

def importVarius(context):
    ''' Install the EmulabPAS plugin
    '''
    out = StringIO()
    portal = context.getSite()

    uf = getToolByName(portal, 'acl_users')
    installed = uf.objectIds()

    if 'emulabpas' not in installed:
        addEmulabPlugin(uf, 'emulabpas', 'Emulab PAS')
        activatePluginInterfaces(portal, 'emulabpas', out)
    else:
        print >> out, 'emulabpas already installed'

    print out.getvalue()
