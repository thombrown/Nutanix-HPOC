[System.Net.ServicePointManager]::ServerCertificateValidationCallback =
    [System.Linq.Expressions.Expression]::Lambda(
        [System.Net.Security.RemoteCertificateValidationCallback],
        [System.Linq.Expressions.Expression]::Constant($true),
        [System.Linq.Expressions.ParameterExpression[]](
            [System.Linq.Expressions.Expression]::Parameter([object], 'sender'),
            [System.Linq.Expressions.Expression]::Parameter([X509Certificate], 'certificate'),
            [System.Linq.Expressions.Expression]::Parameter([System.Security.Cryptography.X509Certificates.X509Chain], 'chain'),
            [System.Linq.Expressions.Expression]::Parameter([System.Net.Security.SslPolicyErrors], 'sslPolicyErrors'))).
        Compile()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ntnx_user_name = read-host "Enter username"
$ntnx_user_password_clear = read-host "Enter Password"
$ntnx_cluster_ip = read-host "Enter Cluster IP"


$pair = "$($ntnx_user_name):$($ntnx_user_password_clear)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

Function Get-Image {

    [CmdletBinding()]          

Param($imageName)

    Write-Verbose "You passed the parameter $item into the function"
$out = Invoke-WebRequest -Uri "https://${ntnx_cluster_ip}:9440/api/nutanix/v2.0/images/" -Headers $Headers -Method Get -ContentType 'application/json'
$images = ($out.content | ConvertFrom-Json).entities

($images | Where-Object {$_.name -eq "$imageName"}).vm_disk_id

}

Function New-VM {

    [CmdletBinding()]          

Param($item)

    Write-Verbose "You passed the parameter $item into the function"

    $body = @"
{
	"description": "",
	"memory_mb": 2048,
	"name": "NICVM",
	"num_cores_per_vcpu": 1,
	"num_vcpus": 2,
	"storage_container_uuid": "94bb3404-db96-44d2-a4c7-f0434e0c6e2f",
	"vm_disks": [{
		"is_cdrom": false,
		"vm_disk_clone": {
			"disk_address": {
				"vmdisk_uuid": "$2012image"
			}
		}
	}],
	"vm_nics": [{
		"network_uuid": "04372deb-799d-4fc6-9d4c-ff1dbc20bf5a"
	}]
}
"@

Invoke-WebRequest -Uri "https://${ntnx_cluster_ip}:9440/PrismGateway/services/rest/v2.0/vms/" -Headers $Headers -Method Post -Body $body -ContentType 'application/json'
}


#Use this to call a RESTful API on Powershell Core
#Invoke-WebRequest -Uri "https://remote.thomas-brown.com:9440/PrismGateway/services/rest/v2.0/vms/" -SkipCertificateCheck