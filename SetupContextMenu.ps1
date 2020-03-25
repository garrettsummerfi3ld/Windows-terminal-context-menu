Param(
    [bool]$uninstall=$false
)

# Global definitions
$wtProfilesPath = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json"
$customConfigPath = "$PSScriptRoot\config.json"
$resourcePath = "$env:LOCALAPPDATA\WindowsTerminalContextIcons\"
$contextMenuIcoName = "terminal.ico"
$cmdIcoFileName = "cmd.ico"
$wslIcoFileName = "linux.ico"
$wslUbuntuIcoFileName = "ubuntu.ico"
$wslDebianIcoFileName = "debian.ico"
$wslOpenSuseIcoFileName = "opensuse.ico"
$psIcoFileName = "powershell.ico"
$psCoreIcoFileName = "powershell-core.ico"
$azureCoreIcoFileName = "azure.ico"
$unknownIcoFileName = "unknown.ico"
$menuRegID = "WindowsTerminal"
$contextMenuLabel = "Open Windows Terminal here"
$contextMenuRegPath = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuRegID"
$contextBGMenuRegPath = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuRegID"
$subMenuRegRelativePath = "Directory\ContextMenus\$menuRegID"
$subMenuRegRoot = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuRegID"
$subMenuRegPath = "$subMenuRegRoot\shell\"

# Clear register
if((Test-Path -Path $contextMenuRegPath)) {
    # If reg has existed
    Remove-Item -Recurse -Force -Path $contextMenuRegPath
    Write-Host "Clear reg $contextMenuRegPath"
}

if((Test-Path -Path $contextBGMenuRegPath)) {
    Remove-Item -Recurse -Force -Path $contextBGMenuRegPath
    Write-Host "Clear reg $contextBGMenuRegPath"
}

if((Test-Path -Path $subMenuRegRoot)) {
    Remove-Item -Recurse -Force -Path $subMenuRegRoot
    Write-Host "Clear reg $subMenuRegRoot"
}

if((Test-Path -Path $resourcePath)) {
    Remove-Item -Recurse -Force -Path $resourcePath
    Write-Host "Clear icon content folder $resourcePath"
}

if($uninstall) {
    Exit
}

# Setup icons
[void](New-Item -Path $resourcePath -ItemType Directory)
[void](Copy-Item -Path "$PSScriptRoot\icons\*.ico" -Destination $resourcePath)
Write-Output "Copy icons => $resourcePath"

# Load the custom config
if((Test-Path -Path $customConfigPath)) {
    $rawConfig = (Get-Content $customConfigPath) -replace '^\s*\/\/.*' | Out-String
    $config = (ConvertFrom-Json -InputObject $rawConfig)
}

# Setup First layer context menu
[void](New-Item -Force -Path $contextMenuRegPath)
[void](New-ItemProperty -Path $contextMenuRegPath -Name ExtendedSubCommandsKey -PropertyType String -Value $subMenuRegRelativePath)
[void](New-ItemProperty -Path $contextMenuRegPath -Name Icon -PropertyType String -Value $resourcePath$contextMenuIcoName)
[void](New-ItemProperty -Path $contextMenuRegPath -Name MUIVerb -PropertyType String -Value $contextMenuLabel)
if($config.global.extended) {
    [void](New-ItemProperty -Path $contextMenuRegPath -Name Extended -PropertyType String)
}
Write-Host "Add top layer menu (shell) => $contextMenuRegPath"

[void](New-Item -Force -Path $contextBGMenuRegPath)
[void](New-ItemProperty -Path $contextBGMenuRegPath -Name ExtendedSubCommandsKey -PropertyType String -Value $subMenuRegRelativePath)
[void](New-ItemProperty -Path $contextBGMenuRegPath -Name Icon -PropertyType String -Value $resourcePath$contextMenuIcoName)
[void](New-ItemProperty -Path $contextBGMenuRegPath -Name MUIVerb -PropertyType String -Value $contextMenuLabel)
if($config.global.extended) {
    [void](New-ItemProperty -Path $contextBGMenuRegPath -Name Extended -PropertyType String)
}
Write-Host "Add top layer menu (background) => $contextMenuRegPath"

# Get Windows terminal profile
$rawContent = (Get-Content $wtProfilesPath) -replace '^\s*\/\/.*' | Out-String
$json = (ConvertFrom-Json -InputObject $rawContent);

$profiles = $null;

if($json.profiles.list){
    Write-Host "Working with the new profiles style"
    $profiles = $json.profiles.list;
} else{
    Write-Host "Working with the old profiles style"
    $profiles = $json.profiles;
}

$profileSortOrder = 0

# Setup each profile item
$profiles | ForEach-Object {    
    $profileSortOrder += 1
    $profileSortOrderString = "{0:00}" -f $profileSortOrder 
    $profileName = $_.name
        
    $leagaleName = $profileName -replace '[ \r\n\t]', '-'
    $subItemRegPath = "$subMenuRegPath$profileSortOrderString$leagaleName"
    $subItemCMDPath = "$subItemRegPath\command"

    $isHidden = $_.hidden
    $commandLine = $_.commandline
    $source = $_.source
    $icoPath = ""
    $guid = $_.guid

    $configEntry = $config.profiles.$guid

    if ($isHidden -eq $false) {
        [void](New-Item -Force -Path $subItemRegPath)
        [void](New-Item -Force -Path $subItemCMDPath)

        if ($configEntry.label) {
            [void](New-ItemProperty -Path $subItemRegPath -Name "MUIVerb" -PropertyType String -Value $configEntry.label)
        }
        else {
            [void](New-ItemProperty -Path $subItemRegPath -Name "MUIVerb" -PropertyType String -Value "$profileName")
        }
        
        [void](New-ItemProperty -Path $subItemCMDPath -Name "(default)" -PropertyType String -Value "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe -p `"$profileName`" -d `"%V`"")

        
        if($configEntry.icon){
            $useFullPath = [System.IO.Path]::IsPathRooted($configEntry.icon);
            $tmpIconPath = $configEntry.icon;            
            $icoPath = If (!$useFullPath) {"$resourcePath$tmpIconPath"} Else { "$tmpIconPath" }
        }
        elseif ($_.icon) {
            $icoPath = $_.icon
        }
        elseif(($commandLine -match "^cmd\.exe\s?.*")) {
            $icoPath = "$cmdIcoFileName"
        }
        elseif (($commandLine -match "^powershell\.exe\s?.*")) {
            $icoPath = "$psIcoFileName"
        }
        elseif ($source -eq "Windows.Terminal.Wsl") {
            if ($profileName -eq "Ubuntu"){
                $icoPath = "$wslUbuntuIcoFileName"
            }
            elseif ($profileName -eq "Debian") {
                $icoPath = "$wslDebianIcoFileName"
            }
            else {
                $icoPath = "$wslIcoFileName"
            }
        }
        elseif ($source -eq "Windows.Terminal.PowershellCore") {
            $icoPath = "$psCoreIcoFileName"
        }
        elseif ($source -eq "Windows.Terminal.Azure") {
            $icoPath = "$azureCoreIcoFileName"
        }else{
            # Unhandled Icon
            $icoPath = "$unknownIcoFileName"
            Write-Host "No icon found, using unknown.ico instead"
        }

        if($icoPath -ne "") {
            $fixedPath = If ($configEntry.icon -or $_.icon) { "$icoPath" } Else { "$resourcePath$icoPath" }
            [void](New-ItemProperty -Path $subItemRegPath -Name "Icon" -PropertyType String -Value "$fixedPath")
        }
        Write-Host "Add new entry $profileName => $subItemRegPath"
    }else{
        Write-Host "Skip entry $profileName => $subItemRegPath"
    }
}