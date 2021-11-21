from django.shortcuts import render
import requests


def index(request):
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock').json()
    return render(request, 'index.html', {'response': response})


def nodeCommands(request, id):
    context = {}
    params = {'nodeID': id}
    response = requests.get('https://618857b5057b9b00177f9c43.mockapi.io/esi/esimock/', params=params).json()
    context['name'] = response[0]['nodeName']
    return render(request, 'nodeCommands.html', context)
