# EntraID App Registration Credential Report
This script is used to make a quick and dirty report of certificates and client secrets used for app registration authentication in Entra ID.

# Reqiured Powershell Module
```
Microsoft.Graph.Authentication
```
# Required Graph API Permissions
```
Application.Read.All
```

# Usage
```
.\report.ps1 -FilePath "app-registration-report.html"
```
