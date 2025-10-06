<#
    Script: Enable_IIS_And_Host_APP.ps1
    Purpose:
      - Check and enable required IIS features using DISM.
      - Import the WebAdministration module (or load it from system32 if missing).
      - Download and install the URL Rewrite module (if not already installed).
      - Configure a global HTTPS redirection rewrite rule (at the machine level).
      - Create or update two IIS websites (for example, a Blazor app or a static site)
        with proper HTTP (port 80) and HTTPS (port 443) bindings for domains:
        lovelyerp.com and bytebaba.com.
      - Log every major step for clarity.
    Note: Run this script as Administrator.
#>

# =============================
# Helper: Import WebAdministration
# =============================
if (-not (Get-Module -ListAvailable -Name WebAdministration)) {
    Write-Output "⚠ WebAdministration module not immediately found. Attempting to import from system directory..."
    $modulePath = "$env:windir\system32\WindowsPowerShell\v1.0\Modules\WebAdministration\WebAdministration.psd1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath
        Write-Output "✅ WebAdministration module imported from system directory."
    } else {
        Write-Output "❌ WebAdministration module not found. Please install the IIS Management Tools."
        exit
    }
} else {
    Import-Module WebAdministration
    Write-Output "✅ WebAdministration module loaded."
}

# =============================
# Function: Enable-OSFeature via DISM
# =============================
function Enable-OSFeature {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName
    )
    Write-Output "Checking status for feature: $FeatureName ..."
    $featureInfo = dism.exe /Online /Get-FeatureInfo /FeatureName:$FeatureName 2>&1

    if ($featureInfo -match "State : Enabled") {
         Write-Output "✅ Feature '$FeatureName' is already enabled."
    }
    else {
         Write-Output "Enabling feature '$FeatureName'..."
         try {
             $enableResult = dism.exe /Online /Enable-Feature /FeatureName:$FeatureName /All /NoRestart 2>&1
             if ($enableResult -match "Error: 0x800f080c") {
                 Write-Output "⚠ Feature '$FeatureName' is not recognized by this OS. Skipping."
             }
             elseif ($enableResult -match "The operation completed successfully") {
                 Write-Output "✅ Feature '$FeatureName' enabled successfully."
             }
             else {
                 Write-Output "⚠ Failed to enable feature '$FeatureName'. Output:"
                 Write-Output $enableResult
             }
         } catch {
             Write-Output "⚠ Exception while enabling feature '$FeatureName': $_"
         }
    }
}

# =============================
# Function: Ensure Required IIS Features
# =============================
function Ensure-IISFeatures {
    Write-Output "Ensuring required IIS features are installed..."
    # Feature names as accepted by DISM may vary by OS.
    $features = @(
        "IIS-WebServerRole",           # Main IIS role
        "IIS-CommonHttpFeatures",      # Common HTTP features (default document, directory browsing, etc.)
        "IIS-StaticContent",           # To serve static content
        "IIS-HttpRedirect",            # For HTTP redirection
        "IIS-DynamicCompression",      # Dynamic compression (if available)
        "IIS-ApplicationDevelopment",  # Application development tools
        "IIS-NetFxExtensibility45",    # .NET 4.5 extensibility
        "IIS-ASPNET45"                 # ASP.NET 4.5 support (note: feature name may differ)
    )
    
    foreach ($feature in $features) {
        Enable-OSFeature -FeatureName $feature
    }
}

# =============================
# Function: Install URL Rewrite Module
# =============================
function Install-URLRewrite {
    Write-Output "Checking for URL Rewrite module..."
    $rewritePath = Join-Path $env:ProgramFiles "IIS\URL Rewrite\rewrite.dll"
    if (Test-Path $rewritePath) {
       Write-Output "✅ URL Rewrite module is already installed."
    }
    else {
       Write-Output "URL Rewrite module is not installed. Installing URL Rewrite..."
       # Update the URL below if necessary – this is for URL Rewrite 2.1 (x64)
       $url = "https://download.microsoft.com/download/D/9/1/D91C221B-0077-41B7-B356-436272D93EEE/rewrite_amd64_en-US.msi"
       $tempInstaller = "$env:TEMP\rewrite.msi"
       Write-Output "Downloading URL Rewrite installer from $url..."
       try {
           Invoke-WebRequest -Uri $url -OutFile $tempInstaller -ErrorAction Stop
       }
       catch {
           Write-Output "❌ Failed to download URL Rewrite installer. Error: $_"
           return
       }
       
       Write-Output "Installing URL Rewrite..."
       Start-Process msiexec.exe -ArgumentList "/i `"$tempInstaller`" /quiet /norestart" -Wait
       if (Test-Path $tempInstaller) {
            Remove-Item $tempInstaller -Force
       }
       Write-Output "✅ URL Rewrite module installation attempted (verify installation in IIS if issues occur)."
    }
}

# =============================
# Function: Configure Global HTTPS Redirection
# =============================
function Configure-GlobalHttpsRedirect {
    Write-Output "Configuring global HTTPS redirection rule via URL Rewrite..."
    # Check if a global rule named "RedirectHTTPtoHTTPS" exists.
    $existingRule = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
                         -Filter "system.webServer/rewrite/rules/rule" -Name "name" | `
                         Where-Object { $_ -eq "RedirectHTTPtoHTTPS" }
    if ($existingRule) {
         Write-Output "✅ Global HTTPS redirection rule already exists."
    }
    else {
         $ruleXML = @"
<rule name="RedirectHTTPtoHTTPS" stopProcessing="true">
    <match url="(.*)" />
    <conditions>
        <add input="{HTTPS}" pattern="off" ignoreCase="true" />
    </conditions>
    <action type="Redirect" url="https://{HTTP_HOST}/{R:1}" redirectType="Permanent" />
</rule>
"@
         [xml]$xmlRule = $ruleXML
         Add-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.webServer/rewrite/rules" `
              -Value $xmlRule.rule
         Write-Output "✅ Global HTTPS redirection rule added successfully."
    }
}

# =============================
# Function: Configure-SiteBindings
# Purpose: Add HTTP (port 80) and HTTPS (port 443) bindings for a site.
# =============================
function Configure-SiteBindings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        [Parameter(Mandatory = $true)]
        [string]$Domain
    )
    Write-Output "Configuring bindings for site '$SiteName' with domain '$Domain'..."
    
    # Check if bindings for this domain already exist for the site
    $existingBindings = Get-WebBinding -Name $SiteName | Where-Object { $_.bindingInformation -match $Domain }
    if ($existingBindings) {
         Write-Output "✅ Bindings for '$Domain' already exist for site '$SiteName'. Skipping binding creation."
         return
    }
    
    # Add HTTP binding on port 80
    New-WebBinding -Name $SiteName -Protocol "http" -Port 80 -HostHeader $Domain
    Write-Output "✅ HTTP binding added for $Domain."
    
    # For HTTPS, attempt to find an existing certificate from the LocalMachine\My store.
    $cert = Get-ChildItem Cert:\LocalMachine\My | Select-Object -First 1
    if ($cert) {
         New-WebBinding -Name $SiteName -Protocol "https" -Port 443 -HostHeader $Domain
         # Construct the binding path in the format: IP!Port!HostName (using 0.0.0.0 for all IPs)
         $bindingPath = "IIS:\SslBindings\0.0.0.0!443!$Domain"
         New-Item -Path $bindingPath -Value $cert.Thumbprint -Force | Out-Null
         Write-Output "✅ HTTPS binding added for $Domain."
    } else {
         Write-Output "⚠ No SSL certificate found for $Domain. HTTPS binding not fully configured."
    }
}

# =============================
# Function: Setup IIS Sites
# Purpose: Create (or update) IIS sites and configure bindings.
# =============================
function Setup-IISSites {
    Write-Output "Setting up IIS websites..."

    # Array of site definitions – adjust these paths and domains as needed.
    $sites = @(
        @{ Name = "LovelyERP"; Path = "C:\inetpub\wwwroot\lovelyerp"; Domain = "lovelyerp.com" },
        @{ Name = "ByteBaba";  Path = "C:\inetpub\wwwroot\bytebaba";  Domain = "bytebaba.com" }
    )

    foreach ($site in $sites) {
        # Ensure the physical directory exists.
        if (-not (Test-Path $site.Path)) {
            New-Item -ItemType Directory -Path $site.Path | Out-Null
            Write-Output "✅ Created directory: $($site.Path)"
        } else {
            Write-Output "✅ Directory $($site.Path) already exists."
        }

        # Check if the IIS site already exists.
        $existingSite = Get-Website | Where-Object { $_.Name -eq $site.Name }
        if ($existingSite) {
            Write-Output "✅ IIS site '$($site.Name)' already exists. Skipping creation."
        } else {
            # Create the IIS site on port 80 with the specified host header.
            New-Website -Name $site.Name -PhysicalPath $site.Path -Port 80 -HostHeader $site.Domain
            Write-Output "✅ IIS site '$($site.Name)' created."
            # Configure the HTTP and HTTPS bindings.
            Configure-SiteBindings -SiteName $site.Name -Domain $site.Domain
        }
    }
}

# =============================
# Main Execution Section
# =============================
Write-Output "===== Starting IIS and Website Configuration Script ====="

# 1. Ensure required IIS features are installed.
Ensure-IISFeatures

# 2. Install URL Rewrite if not already installed.
Install-URLRewrite

# 3. Configure global HTTPS redirection (machine-level URL Rewrite rule).
Configure-GlobalHttpsRedirect

# 4. Create or update IIS websites with proper bindings.
Setup-IISSites

# 5. Display a summary of all IIS sites and their bindings.
Write-Output "===== IIS Configuration Summary ====="
Get-Website | Format-Table Name, State, PhysicalPath, Bindings

Write-Output "===== Configuration Completed Successfully! If https is not in binding make create a self sign cert in iis server manger and add https binding-shashi ====="
