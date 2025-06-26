**TeamCity SSL Certificate Automation**

Automate SSL certificate deployment for TeamCity on Windows using PowerShell and GitHub Actions — from downloading certificates stored in Google Cloud Storage to configuring HTTPS securely and reliably.

**Table of Contents**

1\.   	Introduction

2\.   	Why SSL for TeamCity?

3\.   	Overview of This Project

4\.  	Prerequisites

5\.   	Step-by-Step Setup Guide

o   Generate or Obtain SSL Certificate (.pfx)

o   Upload Certificate to Google Cloud Storage

o   Create GitHub Repository and Store Secrets

o   Configure TeamCity for SSL

o   Run PowerShell Script Locally

o   Automate with GitHub Actions

6\.  	Understanding the PowerShell Script

7\.   	GitHub Actions Workflow Explained

8\.  	Security Best Practices

9\.  	Troubleshooting

10\.   	FAQs

11\.	Contributing

12\.	License

**Introduction**

TeamCity is a popular continuous integration and deployment server. Securing TeamCity with SSL (HTTPS) is essential to protect data in transit, especially credentials and build artifacts.

This repository provides:

·       A **PowerShell script** to download SSL certificates from Google Cloud Storage (GCS), import them into a Java keystore (.keystore), and restart TeamCity.

·       A **GitHub Actions workflow** to automate this process securely using GitHub Secrets.

·       Clear guidance to help beginners and advanced users set up SSL for TeamCity efficiently.

**Why SSL for TeamCity?**

·       **Encrypts communication** between users and the TeamCity server.

·       Prevents **man-in-the-middle attacks**.

·       Enables **secure login and data transfer**.

·       Required for compliance with many security standards.

**Overview of This Project**

·       **Certificate Management:** Uses .pfx (PKCS\#12) certificates stored securely in Google Cloud Storage.

·       **Keystore Handling:** Imports .pfx into a Java keystore using keytool (standard Java tool).

·       **Service Management:** Safely stops and starts the TeamCity Windows service during updates.

·       **Automation:** Supports manual execution or fully automated deployment via GitHub Actions.

·       **Security:** Uses GitHub Secrets to handle sensitive passwords securely.

**Prerequisites**

Before you start, ensure you have:

·       A **TeamCity server** running on Windows.

·       **Java JRE/JDK** installed on the TeamCity server (for keytool).

·       Access to a **Google Cloud Storage bucket** for certificate storage.

·       A **GitHub account** and basic familiarity with repositories.

·       Installed **Git** and optionally **GitHub CLI** on your local machine.

·       Installed **Google Cloud SDK (gcloud)** on the machine running the script or GitHub Actions runner.

**Step-by-Step Setup Guide**

**Generate or Obtain SSL Certificate (.pfx)**

You need a .pfx certificate file (PKCS\#12 format) which contains your SSL certificate and private key.

·       **Option 1: Purchase from a Certificate Authority (CA).**

·       **Option 2: Create a self-signed certificate for testing:**

Using PowerShell:

$cert \= New-SelfSignedCertificate \-DnsName "your.teamcity.domain" \-CertStoreLocation Cert:\\LocalMachine\\My  
 $pwd \= ConvertTo-SecureString \-String "YourPfxPassword" \-Force \-AsPlainText  
 Export-PfxCertificate \-Cert $cert \-FilePath "C:\\path\\to\\teamcity\_cert.pfx" \-Password $pwd

Replace "your.teamcity.domain" and "YourPfxPassword" accordingly.

**Upload Certificate to Google Cloud Storage**

1\.   	Install and initialize [Google Cloud SDK](https://cloud.google.com/sdk/docs/install).

2\.   	Upload your .pfx file:

gsutil cp C:\\path\\to\\teamcity\_cert.pfx gs://your-gcs-bucket/teamcity\_cert.pfx

**Create GitHub Repository and Store Secrets**

1\.   	Create a new GitHub repository for your scripts.

2\.   	In the repo, go to **Settings \> Secrets and variables \> Actions**.

3\.   	Add the following secrets:

o   KEYSTORE\_PASSWORD: Password protecting your .pfx file and keystore.

o   GCP\_SA\_KEY: Your Google Cloud service account JSON key (for GCS access).

**Configure TeamCity for SSL**

Edit C:\\TeamCity\\conf\\server.xml and configure the HTTPS connector:

\<Connector port="443" protocol="org.apache.coyote.http11.Http11NioProtocol"  
        	SSLEnabled="true"  
        	scheme="https" secure="true"  
            keystoreFile="C:\\TeamCity\\conf\\.keystore"  
            keystorePass="your-keystore-password"  
        	sslProtocol="TLS" /\>

**Run PowerShell Script Locally**

Run the PowerShell script with parameters:

.\\Install-TeamCitySSLCert.ps1 \`  
   \-GcsBucketName "your-gcs-bucket" \`  
   \-GcsCertObjectName "teamcity\_cert.pfx" \`  
   \-TeamCityConfDir "C:\\TeamCity\\conf" \`  
   \-TeamCityCertDir "C:\\TeamCity\\Cert" \`  
   \-KeystorePassword "\<your-keystore-password\>"

**Automate with GitHub Actions**

Create .github/workflows/deploy-teamcity-ssl.yml with:

name: Deploy TeamCity SSL

 on:  
   workflow\_dispatch:

 jobs:  
   deploy-ssl:  
 	runs-on: windows-latest

 	steps:  
 	\- uses: actions/checkout@v4

 	\- name: Setup Google Cloud SDK  
   	uses: google-github-actions/setup-gcloud@v1  
   	with:  
     	project\_id: your-gcp-project-id  
     	service\_account\_key: ${{ secrets.GCP\_SA\_KEY }}  
     	export\_default\_credentials: true

 	\- name: Run SSL Deployment Script  
   	shell: pwsh  
   	env:  
     	KEYSTORE\_PASSWORD: ${{ secrets.KEYSTORE\_PASSWORD }}  
  	 run: |  
     	.\\Install-TeamCitySSLCert.ps1 \`  
       	\-GcsBucketName "your-gcs-bucket" \`  
       	\-GcsCertObjectName "teamcity\_cert.pfx" \`  
       	\-TeamCityConfDir "C:\\TeamCity\\conf" \`  
       	\-TeamCityCertDir "C:\\TeamCity\\Cert" \`  
       	\-KeystorePassword $env:KEYSTORE\_PASSWORD

**Understanding the PowerShell Script**

·       **Download Certificate:** Uses gcloud CLI to fetch .pfx from GCS.

·       **Keystore Import:** Uses keytool \-importkeystore to create or update Java keystore.

·       **Service Control:** Stops TeamCity service before import and restarts it afterward.

·       **Error Handling:** Throws detailed errors on failure for easy debugging.

**GitHub Actions Workflow Explained**

·       **Triggers:** Manual (workflow\_dispatch) to run on demand.

·       **Environment:** Windows runner with PowerShell.

·       **Google Cloud Setup:** Authenticates using service account key.

·       **Script Execution:** Runs your PowerShell script with secrets injected securely.

**Security Best Practices**

·       Never commit passwords or keys directly to your repository.

·       Use GitHub Secrets to manage sensitive data.

·       Limit service account permissions to only required scopes.

·       Use HTTPS and secure channels for all communications.

**Troubleshooting**

·       **keytool not found:** Ensure JAVA\_HOME is set on the runner or server.

·       **Permission errors:** Run PowerShell as Administrator.

·       **GCS access denied:** Verify service account permissions and secret correctness.

·       **TeamCity service fails to restart:** Check Windows service logs.

**FAQs**

**Q:** Can I use this for production?  
 **A:** Yes, but ensure certificates are from a trusted CA and secrets are handled securely.

**Q:** What if my keystore password differs from .pfx password?  
 **A:** The script assumes they are the same for simplicity; customize if needed.

**Q:** How do I update the certificate?  
 **A:** Upload new .pfx to GCS and rerun the script or workflow.

**Contributing**

Contributions, issues, and feature requests are welcome\! Please open an issue or submit a pull request.

**License**

This project is licensed under the MIT License.

**Contact**

For questions or support, please open an issue in this repository or contact the maintainer.

**Happy Securing Your TeamCity Server\!** 🚀

If you want, I can also help you generate the exact PowerShell script and GitHub Actions workflow files\!

