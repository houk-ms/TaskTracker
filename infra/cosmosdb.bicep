param name string = 'cosmos_${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location
param databaseName string = 'database_${uniqueString(resourceGroup().id)}'
param allowIps array = []
param principalIds array = []
param roleDefinitionId string = '5bd9cd88-fe45-4216-938b-f97437e15450'  // cosmos account contributor role
param keyVaultName string = ''
param secretName string = 'myvault/mysecret'


// create cosmos account
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
	name: name
	location: location
	kind: 'MongoDB'
	properties: {
		databaseAccountOfferType: 'Standard'
		locations: [
			{
				locationName: location
				failoverPriority: 0
			}
		]
		ipRules: [
			for ip in allowIps: {
				ipAddressOrRange: ip
			}
		]
		consistencyPolicy: {
			defaultConsistencyLevel: 'Session'
		}
		enableAutomaticFailover: true
	}
}

// create mongoDB database
resource mongoDB 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-11-15' = {
	parent: cosmosAccount
	name: databaseName
	properties: {
		resource: {
			id: databaseName
		}
		options: {}
	}
}

// create role assignments for the specified principalIds
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, index) in principalIds: {
	scope: cosmosAccount
	name: guid(cosmosAccount.id, principalId, roleDefinitionId, string(index))
	properties: {
		roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
		principalId: principalId
		principalType: 'ServicePrincipal'
	}
}]

// create key vault and secret if keyVaultName is specified
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = if (keyVaultName != ''){
	name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = if (keyVaultName != ''){
	name: secretName
	parent: keyVault
	properties: {
		attributes: {
			enabled: true
		}
		contentType: 'string'
		value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
	}
}


output id string = cosmosAccount.id
output endpoint string = cosmosAccount.properties.documentEndpoint
output keyVaultSecretUri string = (keyVaultName != '' ? keyVaultSecret.properties.secretUriWithVersion : '')
