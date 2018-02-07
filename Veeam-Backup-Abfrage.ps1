[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
        [string] $BRHost = "sBackup"  
)

#region: Start Load VEEAM Snapin (if not already loaded)
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
 if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
  # Error out if loading fails
  Write-Error "`nERROR: Cannot load the VEEAM Snapin."
  Exit
 }
}
#endregion

#region: Start BRHost Connection
Write-Output "Starting to Process Connection to $BRHost ..."
$OpenConnection = (Get-VBRServerSession).Server
if($OpenConnection -eq $BRHost) {
 Write-Output "BRHost is Already Connected..."
} elseif ($OpenConnection -eq $null ) {
 Write-Output "Connecting BRHost..."
 Connect-VBRServer -Server $BRHost
} else {
    Write-Output "Disconnection actual BRHost..."
    Disconnect-VBRServer
    Write-Output "Connecting new BRHost..."
    Connect-VBRServer -Server $BRHost
}

$NewConnection = (Get-VBRServerSession).Server
if ($NewConnection -eq $null ) {
 Write-Error "`nError: BRHost Connection Failed"
 Exit
}
#endregion

#region: Collect Jobs
$JobsBk = @(Get-VBRJob | Where-Object {$_.JobType -eq "Backup"})
#endregion
 
#region: XML Output for PRTG
Write-Host "<prtg>"
foreach ($Job in $JobsBK){
        $Name = "Latest Job Result - " + $Job.Name
        $Result = $Job.Info.LatestStatus        
        Write-Host "<result>"
                        "<channel>$Name</channel>"
                        "<value>$Result</value>"
                        "<showChart>1</showChart>"
                        "<showTable>1</showTable>"
                        "<LimitMaxError>0</LimitMaxError>"
                        "<LimitMode>0</LimitMode>"
                "</result>"
        }
 
Write-Host "</prtg>" 
#endregion

#region: Debug
if ($DebugPreference -eq "Inquire") {
$JobsBK | Format-Table * -Autosize
}
#endregion
