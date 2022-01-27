﻿[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true, HelpMessage="http://yourreportserver/ReportServer/ReportService2005.asmx")]
	[string]$ReportServerUri,
    [string]$BackupDirectory
)

# https://www.recastsoftware.com/resources/how-do-you-backup-all-of-your-custom-configmgr-reports/

#note this is tested on PowerShell v2 and SSRS 2008 R2
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
 
If (!($ReportServerUri))
{
    Write-Warning "Report Server URI not found."
}
# $ReportServerUri = "http://yourreportserver/ReportServer/ReportService2005.asmx";
$Proxy = New-WebServiceProxy -Uri $ReportServerUri -Namespace SSRS.ReportingService2005 -UseDefaultCredential ;
 
#check out all members of $Proxy
#$Proxy | Get-Member
#http://msdn.microsoft.com/en-us/library/aa225878(v=SQL.80).aspx
 
#second parameter means recursive
$items = $Proxy.ListChildren("/", $true) | `
         Select-Object Type, Path, ID, Name | `
         Where-Object {$_.type -eq "Report"};
 
#create a new folder where we will save the files
#PowerShell datetime format codes http://technet.microsoft.com/en-us/library/ee692801.aspx
 
#create a timestamped folder, format similar to 2011-Mar-28-0850PM
$folderName = Get-Date -format "yyyy-MMM-dd-hhmmtt";
If ($BackupDirectory)
{
    If (Test-Path $BackupDirectory)
    {
        Write-Host "Path exists."
    }
    else {
        Write-Warning "Path doesn't exist."
        exit
    }

    $fullFolderName = Join-Path $BackupDirectory $folderName
    $fullFolderName

    #$fullFolderName = "C:\Temp\" + $folderName;
}
[System.IO.Directory]::CreateDirectory($fullFolderName) | out-null
 
foreach($item in $items)
{
    #need to figure out if it has a folder name
    $subfolderName = split-path $item.Path;
    $reportName = split-path $item.Path -Leaf;
    $fullSubfolderName = $fullFolderName + $subfolderName;
    if(-not(Test-Path $fullSubfolderName))
    {
        #note this will create the full folder hierarchy
        [System.IO.Directory]::CreateDirectory($fullSubfolderName) | out-null
    }
 
    $rdlFile = New-Object System.Xml.XmlDocument;
    [byte[]] $reportDefinition = $null;
    $reportDefinition = $Proxy.GetReportDefinition($item.Path);
 
    #note here we're forcing the actual definition to be 
    #stored as a byte array
    #if you take out the @() from the MemoryStream constructor, you'll 
    #get an error
    [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream(@(,$reportDefinition));
    $rdlFile.Load($memStream);
 
    $fullReportFileName = $fullSubfolderName + "\" + $item.Name +  ".rdl";
    #Write-Host $fullReportFileName;
    $rdlFile.Save( $fullReportFileName);
 
}