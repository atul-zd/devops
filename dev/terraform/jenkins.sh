#!/bin/bash

# Update system packages
sudo apt-get update -y

# Install Java 17
sudo apt-get install -y openjdk-17-jdk openjdk-17-jre

# Add Jenkins repo key
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key

# Add Jenkins repo to sources list
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package index with new Jenkins repo
sudo apt-get update -y

# Install Jenkins
sudo apt-get install -y jenkins


sudo systemctl start jenkins
sudo systemctl enable jenkins
