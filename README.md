# Node.js Express App

This is a simple Node.js application built with Express. It serves a "Hello, Kubernetes!" message on the root path.

## Prerequisites

* Node.js and npm installed on your machine
* Docker installed (for building and running the container)
* kubectl (for deploying to Kubernetes, if applicable)

## Getting Started

1. **Clone the repository:**

   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```

2. **Build the Docker image:**

   ```bash
   docker build -t node-app .
   ```

3. **Run the Docker container:**

   ```bash
   docker run -p 8080:8080 node-app
   ```

   This will start the application and make it accessible on `http://localhost:8080`.

4. **(Optional) Deploy to Kubernetes:**
    * Ensure you have a Kubernetes cluster running and `kubectl` configured to connect to it. You can use tools like Minikube or Docker Desktop (which includes a Kubernetes cluster). Start Minikube with `minikube start` or ensure Kubernetes is enabled in Docker Desktop settings.
    * Create a deployment and service using the provided Kubernetes configuration files (e.g., `k8s/deployment.yaml` and `k8s/service.yaml`).  *Note: You will need to create these files if they don't exist.*
    * Deploy the application:
      ```bash
      kubectl apply -f k8s/deployment.yaml
      kubectl apply -f k8s/service.yaml
      ```
    * Access the application through the service's external IP or hostname.
    * **Access the application using k9s:** If you have `k9s` installed and configured to connect to your Kubernetes cluster, you can use it to view and manage your deployment. Run `k9s` in your terminal and navigate to the `pods` or `services` view to see your application.
    * **Set the Kubernetes namespace:** If you want to deploy to a specific namespace, set the context:
      ```bash
      kubectl config set-context --current --namespace=<namespace-name>
      ```

## Project Structure

* `main.js`: The main application file (Node.js with Express).
* `package.json`:  Defines the project's dependencies and scripts.
* `Dockerfile`:  Instructions for building the Docker image.
* `README.md`:  This file.
* `k8s/deployment.yaml`: Kubernetes deployment configuration (example).
* `k8s/service.yaml`: Kubernetes service configuration (example).
* `.dockerignore`:  Specifies files and directories to exclude when building the Docker image.
* `.gitignore`:  Specifies files and directories to exclude from Git version control.
