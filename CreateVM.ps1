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


$ntnx_user_name = "admin"
$ntnx_user_password_clear = read-host "Enter Password"
$ntnx_cluster_ip = "remote.thomas-brown.com"

$url = "https://${ntnx_cluster_ip}:9440/PrismGateway/services/rest/v2.0/vms/"
$Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ntnx_user_name+":"+$ntnx_user_password_clear ))}
$out = Invoke-WebRequest -Uri $url -Headers $Header -Method Get -ContentType 'application/json'
$VMs = ($out.content | ConvertFrom-Json).entities

<#
This JSON creates a VM from a disk in the image service.  Call the Get images endpoint and get the vmdisk_uuid from the disk you want.

{
    "name":"TomsAPIVM",
    "memory_mb":1024,
    "num_vcpus":1,
    "description":"",
    "num_cores_per_vcpu":1,
    "vm_disks":[
    {
    "is_cdrom":false,
    "disk_address":{
    "device_bus":"scsi"
    },
    "vm_disk_clone":{
    "disk_address":{
    "vmdisk_uuid":"1da777dd-bbfb-48a6-b116-d4ebe3442be2"
    }
    }
    }
    ]
    }

    #>

#Use this to call a RESTful API on Powershell Core
#Invoke-WebRequest -Uri "https://remote.thomas-brown.com:9440/PrismGateway/services/rest/v2.0/vms/" -SkipCertificateCheck