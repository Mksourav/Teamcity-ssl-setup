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
   - Generate or Obtain SSL Certificate (.pfx)  
   - Upload Certificate to Google Cloud Storage  
   - Create GitHub Repository and Store Secrets  
   - Configure TeamCity for SSL  
   - Run PowerShell Script Locally  
   - Automate with GitHub Actions  
6. Understanding the PowerShell Script  
7. GitHub Actions Workflow Explained  
8. Security Best Practices  
9. Troubleshooting  
10. FAQs  
11. Contributing  
12. License  

---

## 🚀 Introduction

TeamCity is a popular continuous integration and deployment server. Securing TeamCity with SSL (HTTPS) is essential to protect data in transit, especially credentials and build artifacts.

This repository provides:

- A **PowerShell script** that:
  - Downloads SSL certificates from Google Cloud Storage (GCS)
  - Imports them into a Java keystore using `keytool`
  - Restarts the TeamCity service
- A **GitHub Actions workflow** to automate this process securely using GitHub Secrets
- Clear guidance for both beginners and advanced users

---

## 🔒 Why SSL for TeamCity?

- **Encrypts communication** between users and the TeamCity server  
- Prevents **man-in-the-middle attacks**  
- Enables **secure login and data transfer**  
- Required for compliance with many security standards  

---

## 📦 Overview of This Project

- **Certificate Management:** Uses .pfx (PKCS#12) certificates stored securely in GCS  
- **Keystore Handling:** Imports .pfx into a Java keystore using `keytool`  
- **Service Management:** Stops and starts the TeamCity Windows service safely  
- **Automation:** Supports manual execution and GitHub Actions-based deployment  
- **Security:** Uses GitHub Secrets to handle sensitive data securely  

---

## ✅ Prerequisites

Ensure you have:

- A TeamCity server running on Windows  
- Java JRE/JDK installed (for `keytool`)  
- Access to a Google Cloud Storage bucket  
- A GitHub account and basic repo knowledge  
- Git and optionally GitHub CLI installed  
- Google Cloud SDK (`gcloud`) installed  

---

## 🛠️ Step-by-Step Setup Guide

### 1. Generate or Obtain SSL Certificate (.pfx)

You need a `.pfx` certificate file (PKCS#12 format) containing your SSL certificate and private key.

**Option 1:** Purchase from a Certificate Authority (CA)  
**Option 2:** Create a self-signed certificate for testing:

```powershell
$cert = New-SelfSignedCertificate -DnsName "your.teamcity.domain" -CertStoreLocation Cert:\LocalMachine\My
$pwd = ConvertTo-SecureString -String "YourPfxPassword" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "C:\path\to\teamcity_cert.pfx" -Password $pwd
```

### 2. Upload Certificate to Google Cloud Storage

```bash
gsutil cp C:\path\to\teamcity_cert.pfx gs://your-gcs-bucket/teamcity_cert.pfx
```

### 3. Create GitHub Repository and Store Secrets

- Go to **Settings > Secrets and variables > Actions**
- Add:
  - `KEYSTORE_PASSWORD`: Password for your .pfx and keystore
  - `GCP_SA_KEY`: Google Cloud service account JSON key

### 4. Configure TeamCity for SSL

Edit `C:\TeamCity\conf\server.xml`:

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


## 🧠 Understanding the PowerShell Script

- **Get-KeytoolPath:** Locates `keytool.exe` using `JAVA_HOME`  
- **Get-KeystoreConfiguration:** Parses `server.xml` to extract keystore info  
- **Copy-GcsCertificate:** Downloads `.pfx` from GCS using `gcloud`  
- **Test-DirectoryOrCreate:** Ensures required directories exist  
- **Main Logic:** Imports certificate, manages TeamCity service, handles errors  

---

## 🔄 GitHub Actions Workflow Explained

- **Trigger:** Manual (`workflow_dispatch`)  
- **Environment:** Windows runner with PowerShell  
- **Authentication:** Uses service account key securely  
- **Execution:** Runs PowerShell script with secrets injected  

---

## 🔐 Security Best Practices

- Never commit passwords or keys to your repo  
- Use GitHub Secrets for sensitive data  
- Limit service account permissions  
- Always use HTTPS for communication  

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

## 📬 Contact

For questions or support, open an issue or contact the maintainer.

---

**Happy Securing Your TeamCity Server! 🚀**