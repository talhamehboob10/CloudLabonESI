from django.urls import path, include
from .views import index, nodeCommands, index_terminal, powerOn, powerOff, status


urlpatterns = [
    path('', index, name='home'),
    path('view/<int:id>/', nodeCommands, name='node'),
    path('terminal/', index_terminal, name='index_terminal'),
    path('powerOn/<int:id>/', powerOn, name="powerOn"),
    path('powerOff/<int:id>/', powerOff, name="powerOff"),
    path('status/<int:id>/', status, name="status"),
    path('api-auth/', include('rest_framework.urls', namespace='rest_framework'))


]