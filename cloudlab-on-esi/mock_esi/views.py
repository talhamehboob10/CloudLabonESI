from django.shortcuts import render
import requests
from rest_framework.decorators import api_view
from .serializers import NodeSerializer, MessageSerializer
from rest_framework.views import Response
import json


def index(request):
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock').json()
    return render(request, 'index.html', {'response': response})


def powerOnHtml(request, id):
    context = {}
    params = {'nodeID': id}
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock/', params=params).json()
    context['name'] = response[0]['nodeName']
    context['id'] = response[0]['nodeID']
    return render(request, 'powerOn.html', context)


def powerOffHtml(request, id):
    context = {}
    params = {'nodeID': id}
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock/', params=params).json()
    context['name'] = response[0]['nodeName']
    context['id'] = response[0]['nodeID']
    return render(request, 'powerOff.html', context)


def nodeCommands(request, id):
    context = {}
    params = {'nodeID': id}
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock/', params=params).json()
    context['name'] = response[0]['nodeName']
    return render(request, 'nodeCommands.html', context)


def index_terminal(request):
    return render(request, 'index_terminal.html')


@api_view(['GET'])
def status(request, id):
    node = getNode(id);
    if node['nodeStatus'] == "False":
        message = "The node is switched off"
    else:
        message = "The node is switched on"
    result = {"message": message}
    response = MessageSerializer(result, many=False).data
    return Response(response)


@api_view(['GET'])
def powerOn(request, id):
    node = getNode(id);
    if node['nodeStatus'] == "False":
        url = 'https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock/'+str(id);
        node['nodeStatus'] = True;
        print(url)
        response = requests.put(url, data=json.dumps(node), headers={'content-type': 'application/json'})
        print(response.text)
        message = "The node has been is switched on."
    else:
        message = "The node is already switched on."
    result = {"message": message}
    response = MessageSerializer(result, many=False).data
    return Response(response)


@api_view(['GET'])
def powerOff(request, id):
    node = getNode(id);
    if node['nodeStatus'] == "False":
        message = "The node is already switched off."
    else:
        url = 'https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock/'+str(id);
        node['nodeStatus'] = False;
        response = requests.put(url, data=json.dumps(node), headers={
            'content-type': 'application/json'})
        print(response.text)
        message = "The node has been switched off."
    result = {"message": message}
    response = MessageSerializer(result, many=False).data
    return Response(response)


def getNode(id):
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock').json()
    data = json.loads(json.dumps(response))
    for i in data:
        if i['nodeID'] == str(id):
            node = {
                "nodeName": i['nodeName'],
                "nodeStatus": str(i['nodeStatus']),
                "nodeID": i['nodeID'],
            }
            break;
    return node;
