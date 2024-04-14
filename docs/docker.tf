terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

resource "docker_network" "jenkins" {
  name = "jenkins"
}

resource "docker_image" "myjenkins_blueocean" {
  name         = "myjenkins-blueocean"
  keep_locally = true
}

resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}

resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

resource "docker_container" "jenkins_container" {
  image = docker_image.myjenkins_blueocean.name
  name  = "jenkins-blueocean"
  restart = "on-failure"
  
  env = [
    "DOCKER_HOST=tcp://docker:2376",
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1"
  ]
  
  ports {
    internal = 8080
    external = 8080
  }

  ports {
    internal = 50000
    external = 50000
  }
  
  volumes {
    volume_name    = docker_volume.jenkins_data.name
    container_path = "/var/jenkins_home"
  }
  
  volumes {
    volume_name    = docker_volume.jenkins_docker_certs.name
    container_path = "/certs/client"
    read_only      = true
  }
  
  networks_advanced {
    name = docker_network.jenkins.name
  }
  
  depends_on = [
    docker_container.jenkins_dind_container
  ]
}

resource "docker_image" "dind_image" {
  name         = "docker:dind"
  keep_locally = false
}

resource "docker_container" "jenkins_dind_container" {
  image = docker_image.dind_image.name
  name  = "jenkins-docker"
  restart = "unless-stopped"
  privileged = true
  env = [
    "DOCKER_TLS_CERTDIR=/certs"
  ]
  
  ports {
    internal = 2376
    external = 2376
  }
  
  ports {
    internal = 3000
    external = 3000
  }
  
  ports {
    internal = 5000
    external = 5000
  }
  
  volumes {
    volume_name    = docker_volume.jenkins_data.name
    container_path = "/var/jenkins_home"
  }
  
  volumes {
    volume_name    = docker_volume.jenkins_docker_certs.name
    container_path = "/certs/client"
    read_only      = true
  }
  
  networks_advanced {
    name = docker_network.jenkins.name
  }
  command = ["--storage-driver", "overlay2"]
}

