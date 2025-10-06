⚙️ Enable_IIS_And_Host_APP.ps1

**Automated IIS setup and HTTPS hosting script for Blazor apps, static sites, and enterprise deployments.**

**Set-ExecutionPolicy RemoteSigned run before any ps1 file run , it will allow you to run command with admin previllage .**


This PowerShell script simplifies the process of configuring IIS on Windows machines for secure web hosting. It’s ideal for developers, DevOps engineers, and IT admins who need a fast, repeatable setup for production or staging environments.
 🚀 Features

- ✅ **Enable IIS Features** via DISM  
- 📦 **Import WebAdministration Module** (fallback to system32 if missing)  
- 🌐 **Install URL Rewrite Module** (if not already installed)  
- 🔐 **Configure Global HTTPS Redirection** using machine-level rewrite rules  
- 🌍 **Create or Update IIS Websites** for domains like `lovelyerp.com` and `bytebaba.com`  
- 📋 **Log All Major Steps** for transparency and troubleshooting

 🛠️ Tech Stack

- PowerShell  
- IIS (Internet Information Services)  
- DISM  
- URL Rewrite Module  
- WebAdministration Module

  📌 Usage

⚠️ **Run as Administrator**

 powershell
.\Enable_IIS_And_Host_APP.ps1

 🌐 Use Cases

- Hosting Blazor WebAssembly apps  
- Deploying static websites with HTTPS  
- Automating IIS setup in CI/CD pipelines  
- Enforcing secure redirection across hosted domains

 📁 File Structure
Enable_IIS_And_Host_APP.ps1
src/
  └─ lovelyerp.com/
  └─ bytebaba.com/
logs/
  └─ setup.log

Let me know if you'd like to extend this with badges, CI/CD triggers, or Make.com integration steps. I can also help you modularize this script for multi-domain onboarding.
