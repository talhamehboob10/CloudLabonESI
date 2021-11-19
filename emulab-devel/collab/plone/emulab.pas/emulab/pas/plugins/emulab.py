import logging
import cgi
import urllib
import re
import os

from Products.PluggableAuthService.plugins.BasePlugin import BasePlugin
from AccessControl.SecurityInfo import ClassSecurityInfo
from AccessControl.SecurityManagement import getSecurityManager
from Products.PluggableAuthService.utils import classImplements
from Globals import InitializeClass
from Products.PluggableAuthService.interfaces.plugins import \
     IAuthenticationPlugin, IExtractionPlugin, IRolesPlugin
from Products.PluggableAuthService.interfaces.plugins import \
     IUserEnumerationPlugin, IGroupsPlugin
from Products.PageTemplates.PageTemplateFile import PageTemplateFile
from zope.component.hooks import getSite
from Products.CMFCore.utils import getToolByName

logger = logging.getLogger('emulabpas')
outfile = logging.FileHandler(filename='/tmp/emulabpas.log')
logger.addHandler(outfile)
# set logging level on whatever zope configured for root logger
#logger.setLevel(logging.getLogger().level)
logger.setLevel(logging.DEBUG)

manage_addEmulabPluginForm = PageTemplateFile('../www/addEmulabPAS',
    globals(), __name__='manage_addEmulabPluginForm')

def addEmulabPlugin(self, id, title='', REQUEST=None):
    ''' Add a Emulab PAS Plugin to Plone PAS
    '''
    o = EmulabPlugin(id, title)
    self._setObject(o.getId(), o)

    if REQUEST is not None:
        REQUEST['RESPONSE'].redirect('%s/manage_main'
            '?manage_tabs_message=Emulab+PAS+Plugin+added.' %
            self.absolute_url())

class EmulabPlugin(BasePlugin):
    ''' Plugin for Emulab PAS
    '''
    meta_type = 'Emulab PAS'
    security = ClassSecurityInfo()

    def __init__(self, id, title=None):
        self._setId(id)
        self.title = title

    def extractCredentials(self, request):
        """Extract credentials from cookie or 'request'

        We try to extract credentials from the Emulab cookie here.

        """
        site = getSite();
	logger.debug("extractCredentials: " + site.id);
	
        if not hasattr(request, 'cookies'):
            logger.debug("No cookies found.")
            return {}
        cookies = request.cookies
        emulab_cookie = cookies.get('emulab_wiki')
        if not emulab_cookie:
            logger.debug("No emulab cookie found.")
            return {}
        logger.debug("extractCredentials: " + str(emulab_cookie));

        # cgi.parse_qs returns values as lists. Why?
        cookiestring = urllib.unquote_plus(emulab_cookie)
        tempdict = cgi.parse_qs(cookiestring)
        realdict = dict([(i, tempdict[i][0]) for i in tempdict])

        logger.debug(str(realdict))

        # Make sure it conforms. 
        if 'hash' not in realdict or 'user' not in realdict:
            return {}

        user_id = realdict['user']
        secret  = realdict['hash']

        logger.debug(secret)

        # If there is a user with this id, we do not authenticate
        # on this path, they have to log in normally.
        #user = self._getPAS().getUserById(user_id)
        #if user is not None:
        #    logger.debug("User '%s' exists, not doing anything.", user_id)
        #    return {}

        result = {}
        result['user_id'] = user_id
        result['login']   = user_id
        result['hash']    = secret
	return result

    # IAuthenticationPlugin implementation
    def authenticateCredentials(self, credentials):
        ''' Authenticate credentials against the fake external database
        '''
        extractor = credentials.get('extractor', 'none')
        if extractor != self.getId():
            return None
        
	logger.debug("authenticateCredentials")
	logger.debug(str(credentials))

        if 'hash' not in credentials or 'user_id' not in credentials:
            return None

        secret  = credentials['hash']
        user_id = credentials['user_id']

        #
        # Sanity check the user_id before we use it to open a file.
        #
        if not re.match("^[-\w]*$", user_id):
            logger.warn("Illegal characters in user_id: " + user_id)
            return None

        if True:
            user = self._getPAS().getUserById(user_id)
            if user:
                current_group_ids = user.getGroupIds()
                logger.debug("Groups for user_id: " + str(current_group_ids))
                if "emulabusers" not in current_group_ids:
                    group_tool = getToolByName(self, 'portal_groups')
                    logger.debug("Adding user id %s to group emulabusers", user_id)
                    group_tool.addPrincipalToGroup(user_id, "emulabusers")
                    pass
                pass
            return (user_id, user_id)

        #
        # Consult external somthing
        #
        try:
            fp = open("/var/db/plone/" + user_id)
            user_secret = fp.readline()
            user_admin  = fp.readline()
        except:
            logger.warn("Could not open or read secret file for " + user_id)
            return None

        user_secret.rstrip("\r\n")
        user_admin.rstrip("\r\n")

        if secret != user_secret:
            return None
        
        return (user_id, user_id)

    def enumerateUsers(self, id=None, login=None, exact_match=False,
                       sort_by=None, max_results=None, **kw):
        key = id or login

        if os.access("/var/db/plone/" + key, os.F_OK):
            logger.debug("enumerateUsers: " + str(key))
            return [{'id'       : key,
                     'login'    : key,
                     'pluginid' : self.getId()
                     }]
        return None
    pass

classImplements(EmulabPlugin, IAuthenticationPlugin, IUserEnumerationPlugin,
                IExtractionPlugin)
InitializeClass(EmulabPlugin)
