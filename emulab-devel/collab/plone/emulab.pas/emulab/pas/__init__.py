from Products.PluggableAuthService.PluggableAuthService import \
    registerMultiPlugin
from plugins import emulab

def initialize(context):
    ''' Initialize product
    '''
    registerMultiPlugin(emulab.EmulabPlugin.meta_type) # Add to PAS menu
    context.registerClass(emulab.EmulabPlugin,
                          constructors = (emulab.manage_addEmulabPluginForm,
                                          emulab.addEmulabPlugin),
                          visibility = None)
