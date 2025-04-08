# Maven Basics

## What is Maven?
Maven is a build automation and project management tool for Java-based projects, using XML-based configuration.

### Key Features:
- **Dependency Management:** Automatically downloads and manages project dependencies.
- **Build Lifecycle:** Standardized build process (compile, test, package, deploy).
- **Plugins:** Extensible via plugins for additional functionality.

### Project Structure:
- `pom.xml`: Core configuration file defining dependencies, plugins, and build settings.
- `src/main/java`: Application source code.
- `src/main/resources`: Configuration files and resources.
- `src/test/java`: Test cases.
- `target/`: Compiled code and packaged artifacts.

### Basic Maven Commands:
```bash
mvn clean             # Removes compiled files  
mvn compile           # Compiles source code  
mvn test              # Runs unit tests  
mvn package           # Packages compiled code into a JAR/WAR  
mvn install           # Installs the package into the local repository  
mvn deploy            # Deploys the package to a remote repository  
mvn dependency:tree   # Shows dependency hierarchy  
```

---

## Maven with Jenkins & SonarQube Integration

### 1. How Maven Works with Jenkins and SonarQube?
- **Maven:** Builds and manages dependencies.
- **Jenkins:** Automates Maven builds, runs tests, and deploys artifacts.
- **SonarQube:** Analyzes code quality and security vulnerabilities.

---

## Installing and Using Maven in Jenkins

### 1. Install Maven in Jenkins
- Open Jenkins Dashboard → *Manage Jenkins* → *Global Tool Configuration*.
- Scroll to the Maven section.
- Click "Add Maven", provide a name (e.g., Maven), and select:
  - **Install Automatically** (Jenkins downloads Maven), or
  - Manually provide the Maven installation path.
- Click Save.

### 2. Create a Maven Job in Jenkins
- Go to Jenkins Dashboard → Click *New Item*.
- Enter the project name and select *Maven Project* → Click OK.
- In the **Build** section:
  - Set Root POM (e.g., `pom.xml`).
  - Set Goals and Options (e.g., `clean package`).
- In **Source Code Management**, select Git and enter the repository URL.
- Click Save and *Build Now*.

### 3. Run Maven Build in Jenkins
- Jenkins fetches the code, runs Maven commands, and builds the project.
- You can check logs under *Build History* → Click the latest build → *Console Output*.

---

## SonarQube

### What is SonarQube?
SonarQube is an open-source platform for continuous code quality inspection, detecting bugs, vulnerabilities, and code smells. It provides insights into code health and ensures adherence to coding standards.

### SonarQube Architecture:
- **Web Server:** Handles user requests and API interactions.
- **Compute Engine:** Runs the code analysis and rules.
- **Database:** Stores analysis data, project info, and configurations.
- **Plugins:** Extend functionality for integration with CI/CD tools.

### Working Mechanism:
- Code is analyzed using **SonarScanner**.
- **Quality Gates** evaluate the analysis results.
- Feedback is provided to developers if issues are found.

### SonarQube Workflow:
1. Code is pushed to VCS (e.g., GitHub).
2. SonarScanner analyzes the code in the CI/CD pipeline (Jenkins connects SonarQube with the token stored in Jenkins credentials).
3. Results are sent to SonarQube and evaluated against quality gates.
4. Feedback is given to Jenkins based on whether the quality gates pass or fail (SonarQube uses webhooks to send results back to Jenkins).

---

## SonarQube Installation Setup: Step-by-Step Guide

### 1. Install SonarQube Using Docker Compose
Create a `docker-compose.yml` file:

```yaml
version: '3.7'
services:
  sonarqube:
    image: sonarqube:latest
    ports:
      - "9000:9000"
    environment:
      - SONARQUBE_JDBC_URL=jdbc:postgresql://postgres:5432/sonar
    depends_on:
      - postgres

  postgres:
    image: postgres:latest
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
```

Run:
```bash
docker-compose up -d
```

Access SonarQube UI at: `http://localhost:9000`  
(Default credentials: `admin/admin`)

### 2. Generate SonarQube Token
- Log in to SonarQube at `http://localhost:9000`.
- Go to *My Account* → *Security* → *Generate Tokens*.
- Create a new token (e.g., `Jenkins Integration`) and save it.

### 3. Store SonarQube Token in Jenkins Credentials
- Go to *Manage Jenkins* → *Manage Credentials*.
- Under appropriate domain, click **(+) Add Credentials**.
  - Kind: `Secret text`
  - Secret: *SonarQube Token*
  - ID: `sonarqube-token`

### 4. Add SonarQube Server URL in Jenkins
- Go to *Manage Jenkins* → *Configure System*.
- Scroll to **SonarQube Servers** → *Add SonarQube*.
- URL: `http://localhost:9000`
- Authentication: Token → Select `sonarqube-token`
- Save.

### 5. Create Jenkinsfile for SonarQube Integration
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                script {
                    withSonarQubeEnv('SonarQube') {
                        sh 'mvn clean install sonar:sonar -Dsonar.login=$SONAR_TOKEN'
                    }
                }
            }
        }
    }
}
```

### 6. Set Up SonarQube Webhook
- In SonarQube: *Administration* → *Configuration* → *Webhooks*.
- Click **Create Webhook**
  - URL: `http://your-jenkins-url.com/sonarqube-webhook/`
  - Events: e.g., Quality Gate status changed

### 7. Test the Integration
- Trigger a build in Jenkins.
- Webhook notifies Jenkins with SonarQube results.
- Jenkins build reflects quality gate status.

---

## Maven with Jenkins & SonarQube Integration (From Scratch)

### 1. How Maven Works with Jenkins and SonarQube?
- **Maven:** Builds and manages dependencies.
- **Jenkins:** Automates Maven builds.
- **SonarQube:** Analyzes code quality.

### 2. Installation & Setup

#### A. Jenkins
- Install Jenkins
- Install plugins:
  - *Maven Integration Plugin*
  - *SonarQube Scanner Plugin*
- Configure Maven:
  - *Manage Jenkins* → *Global Tool Configuration* → Add Maven

#### B. SonarQube
- Install SonarQube (server or Docker)
- Start SonarQube: `http://localhost:9000`
- Generate token: *My Account* → *Security* → *Generate Token*
- In Jenkins:
  - *Configure System* → *SonarQube Servers*
  - Add URL + token

---

### 3. Integration Steps

#### A. Jenkinsfile for Maven + SonarQube
```groovy
pipeline {
    agent any
    tools {
        maven 'Maven'  // Use the Maven tool configured in Jenkins
    }
    environment {
        SONARQUBE_URL = 'http://your-sonarqube-server:9000'
    }
    stages {
        stage('Checkout Code') {
            steps {
                git 'https://github.com/your-repo.git'
            }
        }
        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }
        stage('Post Build Actions') {
            steps {
                echo 'Build and SonarQube analysis complete'
            }
        }
    }
}
```

---

### 4. Running the Integration
- Push `Jenkinsfile` to your repo.
- Trigger build in Jenkins.
- Check SonarQube dashboard for results.