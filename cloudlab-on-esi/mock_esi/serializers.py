from rest_framework import serializers

class NodeSerializer(serializers.Serializer):
    nodeName = serializers.CharField()
    nodeStatus = serializers.CharField()
    nodeID = serializers.CharField()

class MessageSerializer(serializers.Serializer):
    message = serializers.CharField()