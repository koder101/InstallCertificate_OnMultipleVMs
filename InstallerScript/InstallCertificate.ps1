
##########	VARIABLES to configure : Start

# Set the current directory path.
$dir = "C:\InstallCert\"

# certificate to import
$Cert = "$dir\abc.pfx" 

# common name of certificate to import
$CertCN = "xyz"

# Directory path of remote machine where the certificate will be copied.
$RemoteCertDir = "c:\tempCert\certs\"

$DebugPreference = "continue" #comment out to disable debug info
$certRootStore = "currentuser"
$certStore = "My"

# ExecutionPolicy for running the PowerShell on remote machine.
$NewPolicy = "RemoteSigned"

##########	VARIABLES to configure : End


# Log file name initialisation.
$logfile = "$dir\logs\" + "cert-bulkimport_" + $(get-date -Format "yyyy-MM-dd_HH-mm-ss") + ".log"
$csvfile = "$dir\logs\" + "cert-bulkimport_" + $(get-date -Format "yyyy-MM-dd_HH-mm-ss") + ".csv"
Add-Content -Path $csvfile -Value "Time,Server,Message"

# Read the servers.csv file.
$servers = gc "$dir\servers.csv"
$psexec = "$dir\psexec.exe"

$secure_password = read-host "Enter a Password:" -assecurestring
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure_password) 
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$CertPW = $PlainPassword #password for certificate to import

$currentServer = ""
Write-Host ("Current machine : " + ($env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN))
Write-Host


#FUNCTIONS
function log-entry {
    param(
        $message
    )
    $time = Get-date
    Add-Content -Path $logfile -Value "$time`t$message"
	if ($message -ne "`n`n")
        {
		Add-Content -Path $csvfile -Value "$time,$currentServer,$message"
        }
}
function RemoteCopy-Certificate {
    param(
        $server
    )
	$currentServer = $server
    $copyresult = $false
    $RemoteDir = "\\$server\" + $RemoteCertDir.replace(":","$") 
    Write-Debug "Creating directory $RemoteDir"
    log-entry -message "Creating directory $RemoteDir" 
    New-Item -ItemType "directory" $RemoteDir -Force
    $RemoteCertPath = $RemoteDir + (gci $Cert).Name 
    Write-Debug "Copying $Cert to $RemoteDir"
    log-entry -message "Copying $Cert to $RemoteDir"   
    Copy-Item -Path $Cert -Destination $RemoteCertPath -Force
    if (Test-Path -Path $RemoteCertPath) {
        $CopyResult = $true    
        Write-Debug "Copy of $Cert to $RemoteDir succeeded."
        log-entry -message "Copy of $Cert to $RemoteDir succeeded."
    }
    else {
        $CopyResult = $false       
        Write-Debug "Error - Copy of $Cert to $RemoteDir failed."
        log-entry -message "Error - Copy of $Cert to $RemoteDir failed."
    }
    return $CopyResult
}
function Create-ImportScript {
    param(
        $server
    )
	$currentServer = $server
    $ScriptCreateResult = $false
    $RemoteScriptPath = "\\$server\" + $RemoteCertDir.Replace(":","$") + "import-pfx.ps1"   
    $CertPath = "'" + $RemoteCertDir + (gci $Cert).Name + "'"   
    $crtPass = "'" + $CertPW + "'"
    $SB = @"
`n
`ttry {
`$crt = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
`$crt.import($certPath,$crtPass,"Exportable,PersistKeySet")
`$store = new-object System.Security.Cryptography.X509Certificates.X509Store(`'$certStore`',`'$certRootStore`')
`$store.open("MaxAllowed")
`$store.add(`$crt)
`$store.close()
`[System.IO.File]::WriteAllText("$RemoteCertDir\success.txt", '')
`}
`catch
`{
`[System.IO.File]::WriteAllText("$RemoteCertDir\failed.txt", '')
`}
`n
`tfunction List-RemoteCerts {
`       	
`        `$ro = [System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly"        
`        `$store = Get-Item "Cert:\CurrentUser\My"
`        `$store.Open(`$ro)
`        return `$store.Certificates
`}
`tfunction Confirm-CertImport {
`        `$MyCerts = List-RemoteCerts
`        `$MyCerts | % {
`                if (`$_.Subject -like "*$CertCN*") {         
`                        "$CertCN" | Out-File -Append '$RemoteCertDir\output.txt' -Encoding UTF8
`                }
`        }        
`}
`Confirm-CertImport
"@
    log-entry -message "Creating import script $RemoteScriptPath"
    Write-Debug "Creating import script $RemoteScriptPath`:$SB`n"  
    $SB | Out-File $RemoteScriptPath -force
    if (Test-Path -Path $RemoteScriptPath) {
        $ScriptCreateResult = $true    
        Write-Debug "Creation of $RemoteScriptPath succeeded."
        log-entry -message "Creation of $RemoteScriptPath succeeded."
    }
    else {
        $ScriptCreateResult = $false       
        Write-Debug "Error - Creation of $RemoteScriptPath failed."
        log-entry -message "Error - Creation of $RemoteScriptPath failed."
    }
    return $ScriptCreateResult   
}
function Invoke-Importscript {
    param(
        $server
    )
	$currentServer = $server
    $ImportScriptPath = $RemoteCertDir + "import-pfx.ps1"    
    $arg1 = "-acceptEula"
    $arg2 = "$server"
    $arg3 = "cmd /c"
    $arg4 = "`"powershell $ImportScriptPath`"" 
    Write-Debug "invoking remote import script on $server"   
    log-entry -message "invoking remote import script on $server"   
    
    $policy = Invoke-Command -ComputerName $server -ScriptBlock {Get-ExecutionPolicy}
    Write-Debug ("ExecutionPolicy on $server is " + $policy.Value)
    log-entry -message ("ExecutionPolicy on $server is " + $policy.Value)
    if ($policy.Value -ne "Restricted")
    {
        $err = .\PsExec.exe ("\\" + $arg2) $arg1 -n 10 cmd /c $arg4 2>&1
        #$err
    } 
    else
    {
        Write-Debug "Attempting to set ExecutionPolicy on $server to $Policy"   
        log-entry -message "Attempting to set ExecutionPolicy on $server to $Policy"
        Invoke-Command -ComputerName $server -ScriptBlock {Set-ExecutionPolicy -ExecutionPolicy $NewPolicy}
        if ($policy.Value -eq $Policy)
        {
            Write-Debug "New ExecutionPolicy $NewPolicy on $server applied successfully." 
            log-entry -message "New ExecutionPolicy $NewPolicy on $server applied successfully."
            
            $err = .\PsExec.exe ("\\" + $arg2) $arg1 -n 10 cmd /c $arg4 2>&1
        }
        else
        {
            Write-Debug "New ExecutionPolicy $NewPolicy on $server could not be applied." 
            log-entry -message "New ExecutionPolicy $NewPolicy on $server could not be applied."
        }
    }
}
function Remove-TempFiles {
    param(
        $server
    )
	$currentServer = $server
    $RemoteScriptDir = "\\$server\" + $RemoteCertDir.Replace(":","$")   
    Write-Debug "Removing temporary cert and script files from $RemoteScriptDir"
    log-entry -message "Removing temporary cert and script files from $RemoteScriptDir" 
    gci -Recurse -Path $RemoteScriptDir | Remove-Item
}
function List-RemoteCerts {
    param(
        $server
    )
	$currentServer = $server
    $ro = [System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly"
    $lm = [System.Security.Cryptography.X509Certificates.StoreLocation]"LocalMachine"
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store("\\$server\$CertStore", $lm)
    $store.Open($ro)
    return $store.Certificates
}
function Confirm-CertImport {
    param(
        $server
    )
	$currentServer = $server
    Write-Debug "Checking if certificate import on $server was successful."
    log-entry -message "Checking if certificate import on $server was successful."  
    $IsCertThere = $false 
    $outfile = "\\$server\" + $RemoteCertDir.Replace(":","$") + "\success.txt"
	if (Test-Path $outfile)
	{
		$IsCertThere = $true
	}    

	$IsOutputThere = $false
    $outfile = "\\$server\" + $RemoteCertDir.Replace(":","$") + "\output.txt"
	$content = [System.IO.File]::ReadAllText($outfile)
	if (Test-Path $outfile)
	{
		if ($content.Contains($CertCN)) 
		{ $IsOutputThere = $true }
		
	}
	if ($IsCertThere -and $IsOutputThere) { $IsCertThere = $true }
    return $IsCertThere       
}
#SCRIPT MAIN
new-item -itemtype "file" $logfile -force | out-null #create the log file for this script execution
Write-Debug "Script run started."
log-entry -message "Script run started."
$servers | % { #loop through the servers which we will import the certificate to
    Write-Debug "Starting cert import on $_".ToUpper()
	$currentServer = $_
    log-entry "Starting cert import on $_".ToUpper()
    $copyResult = RemoteCopy-Certificate -server $_ # Find out if the copy of the cert to the server was successful
    if ($copyResult) {   #If the copy of the certificate to the server succeeded then proceed.     
        $ScriptCreateResult = Create-ImportScript -server $_ #Find out if the script was created and copied to the server successfully
        if ($ScriptCreateResult) { #if the script was created/copied to the server successfully then proceed.
            Invoke-Importscript -server $_ #import the certificate into the specified store            
            $CertImportResult = Confirm-CertImport -server $_ #check that the cert was imported successfully and write the result to the log.
            if ($CertImportResult) {
                Write-Debug "Success! $CertCN was successfully imported on $_"
                log-entry -message "Success! $CertCN was successfully imported on $_"
            }
            else {
                Write-Debug "Error! Import of $CertCN on $_ failed."
                log-entry -message "Error! Import of $CertCN on $_ failed."
            }
            Remove-TempFiles -server $_ #Remove temp files such as the cert and import script
        }
    }
    Write-Debug "-------------------------------------------------------------------------------------------------------------------------"
    #log-entry "`n`n"
}