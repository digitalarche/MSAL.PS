param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\release\*\*.*.*",
    # Module Version
    [Parameter(Mandatory = $false)]
    [string] $ModuleVersion
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop
[hashtable] $paramUpdateModuleManifest = @{ }
if ($ModuleVersion) { $paramUpdateModuleManifest['ModuleVersion'] = $ModuleVersion }

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName
$paramUpdateModuleManifest['NestedModules'] = $ModuleManifest.NestedModules
$paramUpdateModuleManifest['CmdletsToExport'] = $ModuleManifest.CmdletsToExport
$paramUpdateModuleManifest['AliasesToExport'] = $ModuleManifest.AliasesToExport
[System.IO.DirectoryInfo] $ModuleOutputDirectoryInfo = $ModuleManifestFileInfo.Directory

## Get Module Output FileList
$ModuleFileListFileInfo = Get-ChildItem $ModuleOutputDirectoryInfo.FullName -Recurse -File
$ModuleRequiredAssembliesFileInfo = $ModuleFileListFileInfo | Where-Object Extension -eq '.dll'

## Get Paths Relative to Module Base Directory
$ModuleFileList = Get-RelativePath $ModuleFileListFileInfo.FullName -WorkingDirectory $ModuleOutputDirectoryInfo.FullName -ErrorAction Stop
$ModuleFileList = $ModuleFileList -replace '\\net45\\', '\!!!\' -replace '\\netcoreapp2.1\\', '\net45\' -replace '\\!!!\\', '\netcoreapp2.1\'  # PowerShell Core fails to load assembly if net45 dll comes before netcoreapp2.1 dll in the FileList.
$paramUpdateModuleManifest['FileList'] = $ModuleFileList

if ($ModuleRequiredAssembliesFileInfo) {
    $ModuleRequiredAssemblies = Get-RelativePath $ModuleRequiredAssembliesFileInfo.FullName -WorkingDirectory $ModuleOutputDirectoryInfo.FullName -ErrorAction Stop
    $paramUpdateModuleManifest['RequiredAssemblies'] = $ModuleRequiredAssemblies
}

## Clear RequiredAssemblies
(Get-Content $ModuleManifestFileInfo.FullName -Raw) -replace "(?s)RequiredAssemblies\ =\ @\([^)]*\)", "# RequiredAssemblies = @()" | Set-Content $ModuleManifestFileInfo.FullName
(Get-Content $ModuleManifestFileInfo.FullName -Raw) -replace "(?s)FileList\ =\ @\([^)]*\)", "# FileList = @()" | Set-Content $ModuleManifestFileInfo.FullName

## Update Module Manifest in Module Output Directory
Update-ModuleManifest -Path $ModuleManifestFileInfo.FullName -ErrorAction Stop @paramUpdateModuleManifest
