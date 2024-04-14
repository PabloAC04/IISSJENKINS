# Práctica con Jenkins

En este archivo de markdown se añaden unas instrucciones para replicar el proceso completo de despliegue: **cómo crear la imágen de Jenkins**, **cómo desplegar los contenedores Docker con Terraform**, **cómo configurar Jenkins**, etc...

## Contenido del Dockerfile

Para el contenido del `Dockerfile`, vamos a hacer uso del Dockerfile que se nos presenta en la explicación de la práctica, pero le vamos a añadir algunas líneas con dependencias que necesita el docker.

Este sería contenido del **Dockerfile**:

```hcl
FROM jenkins/jenkins
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv && \
    ln -s /usr/bin/python3 /usr/bin/python

RUN python3 -m venv /opt/venv
RUN . /opt/venv/bin/activate && pip install pytest pyinstaller
ENV PATH="/opt/venv/bin:$PATH"

USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"
```

- `RUN apt-get install -y python3 python3-pip python3-venv`: instala python3, python3-pip (para instalar paquetes de python) y python3-venv (para crear entornos de python configurables).
- `RUN ln -s /usr/bin/python3 /urs/bin/python`: hace una redirección del comando por si se usa el comando python en lugar de python3 se use indistintamente python3.
- `RUN python3 -m venv /opt/venv`: crea un entrono virtual de python3.
- `RUN . /opt/venv/bin/activate && pip install pytest pyinstaller`: activa el entorno de python3  e instala los paquetes *pytest* y *pyinstaller* que se utilizan en el pipeline de Jenkins posteriormente.
- `ENV PATH="/opt/venv/bin:$PATH"`: para asegurarnos de que los comandos futuros usan el entorno virtual.

## Contenido fichero de configuración de Terraform

El contenido del fichero de configuración de Terraform *docker.tf* es el siguiente:

```hcl
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
```

En este caso solo lo muestro, pues considero que no hay mucho que explicar, todo se ve a simple vista.

## Pasos a seguir para completar la configuración de Jenkins

En primer lugar hay que clonar el repositorio con `git clone url`, además tienes que tener instalado en tu máquina tanto **docker** como **terraform**.

### Cómo crear la imágend e Jenkins

Situados en el directorio `docs`, ejecutamos el siguiente comando:
`docker build -t jenkins-blueocean .`

Con este comando se creará la imágen `jenkins-blueocean` que posteriormente será usada.

### Cómo desplegar los contenedores docker con Terraform

De nuevo situados en el directorio `docs`, ejecutamos los siguientes comandos en orden.

1. `terraform init`: con este comando inicializamos el directorio de trabajo de terraform.
2. `terraform plan`: muestra los cambios que va a realizar en el directorio como añadir archivos de estado de terraform.
3. `terraform apply`: realiza los cambios que se habian mostrado con terraform plan y levanta los conternedores y servicios especificados.

### Cómo configurar Jenkins

Para realizar este paso, accedemos a `localhost:8080` y configuramos la cuenta de jenkins con un usuario y contraseña.

Una vez dentro de Jenkins seleccionamos `Nueva Tarea`, seleccionamos un nombre apropiado y seleccionamos la opción `Pipeline`. 
Tras esto continuamos y dentro de la configuración del Pipeline ponemos las siguientes opciones:
- `Definition`: Pipeline script from SCM.
- `SCM`: Git.
- `Repository URL`: https://github.com/PabloAC04/IISSJENKINS
- `Credentials`: los credenciales que crearemos a continuación.
  - `+Add`: seleccionamos Jenkins.
  - `Kind`: Username with password.
  - `Username`: nombre de usuario del repositorio.
  - `Password`: Token de Acceso Personal (PAT).
  - `ID`: Nombre del credencial
- `Script Path`: Jenkinsfile.

### Cómo lanzar el pipeline

Una vez creado el pipeline, pulsamos la opción `Construir ahora`. Entonces se lanzará el pipeline.

### Cómo ver resultados

Para ver los resultados del pipeline, podemos seleccionar la opción `Stages` para ver el recorrido del mismo y ver las acciiones llevadas a cabo.