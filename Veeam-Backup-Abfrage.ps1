[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
        [string] $BRHost = "sBackup",
    [Parameter(Position=1, Mandatory=$false)]
        $reportMode = "24", # Weekly, Monthly as String or Hour as Integer
    [Parameter(Position=2, Mandatory=$false)]
        $repoCritical = 10,
    [Parameter(Position=3, Mandatory=$false)]
        $repoWarn = 20
  
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


#region: Functions
Function Get-vPCRepoInfo {
[CmdletBinding()]
        param (
                [Parameter(Position=0, ValueFromPipeline=$true)]
                [PSObject[]]$Repository
                )
        Begin {
                $outputAry = @()
                Function Build-Object {param($name, $repohost, $path, $free, $total)
                        $repoObj = New-Object -TypeName PSObject -Property @{
                                        Target = $name
          RepoHost = $repohost
                                        Storepath = $path
                                        StorageFree = [Math]::Round([Decimal]$free/1GB,2)
                                        StorageTotal = [Math]::Round([Decimal]$total/1GB,2)
                                        FreePercentage = [Math]::Round(($free/$total)*100)
                                }
                        Return $repoObj | Select Target, RepoHost, Storepath, StorageFree, StorageTotal, FreePercentage
                }
        }
        Process {
                Foreach ($r in $Repository) {
                 # Refresh Repository Size Info
     [Veeam.Backup.Core.CBackupRepositoryEx]::SyncSpaceInfoToDb($r, $true)
     
     If ($r.HostId -eq "00000000-0000-0000-0000-000000000000") {
      $HostName = ""
     }
     Else {
      $HostName = $($r.GetHost()).Name.ToLower()
     }
     $outputObj = Build-Object $r.Name $Hostname $r.Path $r.info.CachedFreeSpace $r.Info.CachedTotalSpace
     }
                $outputAry += $outputObj
        }
        End {
                $outputAry
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

#region: Convert mode (timeframe) to hours
If ($reportMode -eq "Monthly") {
        $HourstoCheck = 720
} Elseif ($reportMode -eq "Weekly") {
        $HourstoCheck = 168
} Else {
        $HourstoCheck = $reportMode
}
#endregion

#region: Collect Jobs
 $JobsBk = @(Get-VBRJob | ? {$_.JobType -eq "Backup"})
 #endregion
 
 #region: XML Output for PRTG
 Write-Host "<prtg>"
foreach ($Job.Name in $JobsBK){
$Name = "Repo - " + $Job.Name
$count = if ($Job.GetLastResult("Warning") = "Warning"){
	$count = 1}
	else ($Job.GetLastResult("Success") = "Success")
	if{$Count = 0}
	else {$count = 2}
	}
Write-Host "<result>"
               "<channel>$Name</channel>"
               "<value>$count</value>"
               "<showChart>1</showChart>"
               "<showTable>1</showTable>"
               "<LimitMaxError>0</LimitMaxError>"
               "<LimitMode>1</LimitMode>"
               "</result>"
 }
 
Write-Host "</prtg>" 
#endregion

#region: Debug
if ($DebugPreference -eq "Inquire") {
$JobsBK | ft * -Autosize
}
#endregion
