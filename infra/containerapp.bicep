// The template to create an Azure Container App

param name string = 'aca_${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location
param secrets array = []
param containerName string = 'main'
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param containerEnv array = []
param containerAppEnvId string
param containerRegistryName string
param targetPort int = 80
param tags object = {}
param identityType string = 'SystemAssigned'
param userAssignedIdentities object = {}


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
	name: containerRegistryName
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
	name: name
	location: location
	identity: {
		type: identityType
		userAssignedIdentities: contains(identityType, 'UserAssigned') ? userAssignedIdentities : null
	}
	properties: {
		environmentId: containerAppEnvId
		configuration: {
			ingress: {
				external: true
				targetPort: targetPort
			}
			registries: [
				{
					server: containerRegistry.name
					username: containerRegistry.properties.loginServer
					passwordSecretRef: 'acr-password'
				}
			]
			secrets: concat([
				{
					name: 'acr-password'
					value: containerRegistry.listCredentials().passwords[0].value
				}
			], secrets)
		}
		template: {
			containers: [
				{
					name: containerName
					image: containerImage
					env: containerEnv
				}
			]
		}
	}
	tags: tags
}

output id string = containerApp.id
output name string = containerApp.name
output identityPrincipalId string = containerApp.identity.principalId
output outboundIps string[] = containerApp.properties.outboundIpAddresses
output requestUrl string = containerApp.properties.configuration.ingress.fqdn
