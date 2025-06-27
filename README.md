```markdown
# TeamCity SSL Certificate Automation

Automate SSL certificate deployment for TeamCity on Windows using PowerShell and GitHub Actions — from downloading certificates stored in Google Cloud Storage to configuring HTTPS securely and reliably.

---

## 📋 Table of Contents

1. Introduction  
2. Why SSL for TeamCity?  
3. Overview of This Project  
4. Prerequisites  
5. Step-by-Step Setup Guide  
6. Understanding the PowerShell Script  
7. GitHub Actions Workflow Explained  
8. Security Best Practices  
9. Troubleshooting  
10. FAQs  
11. Contributing  
12. License  
13. References  

---

## 🚀 Introduction

TeamCity is a popular continuous integration and deployment server. Securing TeamCity with SSL (HTTPS) is essential to protect data in transit, especially credentials and build artifacts.

This repository provides:

- A **PowerShell script** to automate SSL certificate deployment
- A **GitHub Actions workflow** for secure automation
- Clear guidance for both beginners and advanced users

---

## 🔒 Why SSL for TeamCity?

- Encrypts communication between users and the TeamCity server  
- Prevents man-in-the-middle attacks  
- Enables secure login and data transfer  
- Required for compliance with many security standards  

---

## 📦 Overview of This Project

- Uses `.pfx` certificates stored in **Google Cloud Storage (GCS)**  
- Imports certificates into a Java keystore using `keytool`  
- Manages the TeamCity Windows service lifecycle  
- Supports manual and automated deployment  
- Secures sensitive data using **GitHub Secrets**

---

## ✅ Prerequisites

Ensure you have:

- A TeamCity server running on Windows  
- Java JRE/JDK installed (for `keytool`)  
- Access to a GCS bucket  
- A GitHub account  
- Git and optionally GitHub CLI installed  
- Google Cloud SDK (`gcloud`) installed

📘 **References:**
- [PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/) [1](https://learn.microsoft.com/en-us/powershell/)  
- [Google Cloud SDK Installation](https://cloud.google.com/docs/) [2](https://cloud.google.com/docs/)  
- [Cloud Tools for PowerShell](https://cloud.google.com/tools/powershell/docs/) [3](https://cloud.google.com/tools/powershell/docs/)  
- GitHub Actions Documentation

---

## 🛠️ Step-by-Step Setup Guide

### 1. Generate or Obtain SSL Certificate (.pfx)

Use a trusted CA or create a self-signed certificate:

```powershell
$cert = New-SelfSignedCertificate -DnsName "your.teamcity.domain" -CertStoreLocation Cert:\LocalMachine\My
$pwd = ConvertTo-SecureString -String "YourPfxPassword" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "C:\path\to\teamcity_cert.pfx" -Password $pwd
```

### 2. Upload Certificate to Google Cloud Storage

```bash
gsutil cp C:\path\to\teamcity_cert.pfx gs://your-gcs-bucket/teamcity_cert.pfx
```

📘 [GCS Upload via GitHub Actions](https://github.com/google-github-actions/upload-cloud-storage) [4](https://github.com/google-github-actions/upload-cloud-storage)

### 3. Create GitHub Repository and Store Secrets

- Add `KEYSTORE_PASSWORD` and `GCP_SA_KEY` in **Settings > Secrets and variables > Actions**

### 4. Configure TeamCity for SSL

Edit `server.xml`:

```xml
<Connector port="443" protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true"
           scheme="https" secure="true"
           keystoreFile="C:\TeamCity\conf\.keystore"
           keystorePass="your-keystore-password"
           sslProtocol="TLS" />
```

### 5. Run PowerShell Script Locally

```powershell
.\Install-TeamCitySSLCert.ps1 `
  -GcsBucketName "your-gcs-bucket" `
  -GcsCertObjectName "teamcity_cert.pfx" `
  -TeamCityConfDir "C:\TeamCity\conf" `
  -TeamCityCertDir "C:\TeamCity\Cert" `
  -KeystorePassword "<your-keystore-password>"
```

### 6. Automate with GitHub Actions

Create `.github/workflows/deploy-teamcity-ssl.yml`:

```yaml
name: Deploy TeamCity SSL

on:
  workflow_dispatch:

jobs:
  deploy-ssl:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          project_id: your-gcp-project-id
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          export_default_credentials: true

      - name: Run SSL Deployment Script
        shell: pwsh
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
        run: |
          .\Install-TeamCitySSLCert.ps1 `
            -GcsBucketName "your-gcs-bucket" `
            -GcsCertObjectName "teamcity_cert.pfx" `
            -TeamCityConfDir "C:\TeamCity\conf" `
            -TeamCityCertDir "C:\TeamCity\Cert" `
            -KeystorePassword $env:KEYSTORE_PASSWORD
```

---

## 🧠 Understanding the PowerShell Script

- **Get-KeytoolPath:** Locates `keytool.exe` using `JAVA_HOME`  
- **Get-KeystoreConfiguration:** Parses `server.xml`  
- **Copy-GcsCertificate:** Downloads `.pfx` from GCS  
- **Test-DirectoryOrCreate:** Ensures required directories exist  
- **Main Logic:** Imports certificate, manages TeamCity service, handles errors

📘 [PowerShell Cmdlet Design Guidelines](https://learn.microsoft.com/en-us/powershell/) [1](https://learn.microsoft.com/en-us/powershell/)

---

## 🔐 Security Best Practices

- Use GitHub Secrets for sensitive data  
- Limit service account permissions  
- Use HTTPS for all communications  
- Never commit credentials to your repository

---

## 🧰 Troubleshooting

- `keytool` not found → Ensure `JAVA_HOME` is set  
- Permission errors → Run PowerShell as Administrator  
- GCS access denied → Check service account and secrets  
- TeamCity service fails → Check Windows service logs

---

## ❓ FAQs

**Q:** Can I use this for production?  
**A:** Yes, with trusted certificates and secure secrets.

**Q:** What if my keystore password differs from .pfx?  
**A:** Script assumes they are the same; modify if needed.

**Q:** How do I update the certificate?  
**A:** Upload new `.pfx` to GCS and rerun the script or workflow.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!  
Please open an issue or submit a pull request.

---

## 📄 License

This project is licensed under the MIT License.

---

## 📚 References

- [PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/) [1](https://learn.microsoft.com/en-us/powershell/)  
- [Cloud Tools for PowerShell](https://cloud.google.com/tools/powershell/docs/) [3](https://cloud.google.com/tools/powershell/docs/)  
- [Google Cloud Documentation](https://cloud.google.com/docs/) [2](https://cloud.google.com/docs/)  
- GitHub Actions Documentation  
- [GCS Upload GitHub Action](https://github.com/google-github-actions/upload-cloud-storage) [4](https://github.com/google-github-actions/upload-cloud-storage)

---

**Happy Securing Your TeamCity Server! 🚀**
```