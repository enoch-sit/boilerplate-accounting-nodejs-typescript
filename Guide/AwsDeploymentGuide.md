# Comprehensive Step-by-Step Guide to Deploying an Accounting Boilerplate to AWS as a Newbie

Deploying a web application like the Node.js and TypeScript accounting boilerplate (available at [GitHub Repository](https://github.com/enoch-sit/boilerplate-accounting-nodejs-typescript)) to AWS can feel overwhelming as a newbie. This guide is designed to make the process clear, manageable, and cost-effective by breaking it down into detailed, step-by-step instructions. We’ll use **Amazon ECS with Fargate** for simplicity and **MongoDB Atlas** for the database, ensuring everything is explained in plain language. By the end, you’ll have your application live on AWS, even with little prior experience.

---

## Introduction

This guide walks you through deploying your accounting boilerplate to AWS using ECS (Elastic Container Service) with Fargate—a serverless option that simplifies infrastructure management—and MongoDB Atlas, a managed database service. Each step includes explanations to help you understand what’s happening, plus cost breakdowns and best practices to keep things affordable and secure. Let’s get started!

---

## Step 1: Set Up Your AWS Account

Before you can deploy anything, you need an AWS account and the tools to interact with it.

### Actions

1. **Sign Up for AWS**:
   - Go to [aws.amazon.com](https://aws.amazon.com).
   - Click **"Create an AWS Account"** and follow the prompts to register (you’ll need a credit card, but we’ll use free tiers where possible).
2. **Install the AWS CLI**:
   - Download the AWS Command Line Interface (CLI) from [aws.amazon.com/cli](https://aws.amazon.com/cli) and install it on your computer.
   - This tool lets you manage AWS services from your terminal.
3. **Set Up an IAM User** (instead of using root credentials):
   - Log in to the AWS Console with your root account.
   - Search for and navigate to "IAM" (Identity and Access Management).
   - Click on "Users" in the left navigation pane, then "Add users".
   - Enter a username (e.g., `deployment-admin`).
   - Select "Access key - Programmatic access" to allow CLI usage.
   - Click "Next: Permissions".
   - Select "Attach existing policies directly" and choose "AdministratorAccess" (for this tutorial; in production, follow the principle of least privilege).
   - Click through the remaining steps and create the user.
   - **Important**: Download the CSV file containing the access key ID and secret access key. This is your only chance to view the secret access key!
4. **Configure the AWS CLI**:
   - Open a terminal (e.g., Command Prompt on Windows, Terminal on Mac/Linux).
   - Run:  

     ```bash
     aws configure
     ```

   - Enter:
     - **AWS Access Key ID** and **Secret Access Key** (from the IAM user you created, NOT from root credentials).
     - **Default region name** (e.g., `us-west-2`—choose one close to you or your users).
     - **Default output format** (e.g., `json`).

### Explanation

An AWS account gives you access to cloud services. The CLI is like a remote control for AWS, making it easier to set things up without always using the web interface. Creating an IAM user instead of using root credentials is an important security best practice.

---

## Step 1.1: Understanding AWS Security Best Practices for Newbies

As a beginner, it's crucial to follow AWS security best practices from the start. One of the most important rules is to never use your root user access keys for everyday tasks.

### Why Not Use Root User Credentials?

1. **Unlimited Power**: The root user has complete access to all AWS services and resources, which violates the security principle of least privilege.
2. **No Restrictions**: You can't limit root user permissions with policies.
3. **Higher Risk**: If root credentials are compromised, attackers gain full control of your AWS account.

### Best Practices for AWS Credentials

1. **Use IAM Users**: Create individual IAM users for specific tasks instead of sharing the root user.
2. **Apply Least Privilege**: Give IAM users only the permissions they need for their specific tasks.
3. **Use Temporary Credentials**: For enhanced security, use IAM roles which provide temporary credentials instead of long-term access keys.

### For Even Better Security (Optional Advanced Setup)

For more advanced security (you can implement this later as you become more comfortable with AWS):

1. **AWS IAM Identity Center**: Set up Identity Center (formerly AWS SSO) for centralized access management:
   - In the AWS Console, search for "IAM Identity Center" and enable it.
   - Create a permission set with appropriate permissions.
   - Assign users to the permission set.
   - Users can then sign in through a portal and get temporary credentials.

2. **Using AWS CLI with IAM Identity Center**:
   - Configure your CLI with SSO credentials:

     ```bash
     aws configure sso
     ```

   - Follow the prompts to set up SSO integration.
   - Before using AWS CLI commands, start a session:

     ```bash
     aws sso login --profile your-sso-profile
     ```

These advanced options provide better security through temporary credentials rather than long-term access keys. As you grow more comfortable with AWS, consider implementing these practices.

---

## Step 2: Create an ECR Repository

You’ll need a place to store your application’s Docker image, which is where Amazon ECR (Elastic Container Registry) comes in.

### Actions

1. **Log In to the AWS Console**:
   - Visit [console.aws.amazon.com](https://console.aws.amazon.com) and sign in.
2. **Go to ECR**:
   - In the search bar at the top, type **"Elastic Container Registry"** and select it.
3. **Create a Repository**:
   - Click **"Create repository"**.
   - Name it (e.g., `auth-service`—something simple and relevant to your app).
   - Leave other settings as default and click **"Create repository"**.
   - Note the repository URI (it’ll look like `<your-aws-account-id>.dkr.ecr.<region>.amazonaws.com/auth-service`).

### Explanation

ECR is like a storage locker for your app’s packaged version (Docker image). You’ll upload it here later so AWS can use it.

---

## Step 3: Set Up an ECS Cluster

Next, set up a cluster in Amazon ECS to manage your application’s containers.

### Actions

1. **Go to ECS**:
   - In the AWS Console, search for **"Amazon Elastic Container Service"** and select it.
2. **Create a Cluster**:
   - Click **"Create cluster"**.
   - Choose **"Networking only"** (this is for Fargate, which is serverless and easier for newbies).
   - Name it (e.g., `auth-service-cluster`).
   - Click **"Create"**.

### Explanation

ECS is the service that runs your app. Fargate means AWS handles the servers, so you don’t have to worry about managing them—perfect for beginners.

---

## Step 4: Set Up MongoDB Atlas

Your accounting app needs a database, and MongoDB Atlas offers a free, managed option that’s easy to set up.

### Actions

1. **Sign Up for MongoDB Atlas**:
   - Go to [mongodb.com](https://www.mongodb.com) and create a free account.
2. **Create a Project**:
   - In the Atlas dashboard, click **"New Project"**.
   - Name it (e.g., `MyAWSProject`) and click **"Create Project"**.
3. **Create a Cluster**:
   - Click **"Build a Cluster"**.
   - Select **AWS** as the provider, choose the same region as your AWS setup (e.g., `us-west-2`), and pick the **M0 free tier** for development.
   - Click **"Create Cluster"** (it takes a few minutes to set up).
4. **Set Up Network Access**:
   - Go to **"Network Access"** in the sidebar.
   - Click **"Add IP Address"**.
   - For testing, enter `0.0.0.0/0` (allows access from anywhere—use a specific IP in production for security).
5. **Create a Database User**:
   - Go to **"Database Access"**.
   - Click **"Add Database User"**.
   - Set a username (e.g., `myuser`) and password (e.g., `mypassword123`), and give "Read and write to any database" permissions.
   - Save it.
6. **Get the Connection String**:
   - Go to your cluster, click **"Connect"**, then **"Connect your application"**.
   - Copy the connection string (e.g., `mongodb+srv://myuser:<password>@cluster0.abcde.mongodb.net/myDatabase?retryWrites=true&w=majority`).
   - Replace `<password>` with your password.

### Explanation

MongoDB Atlas hosts your database in the cloud, saving you from setting up and maintaining it yourself. The free tier is great for learning and testing.

---

## Step 5: Build and Push Your Docker Image

Now, package your app into a Docker image and upload it to ECR.

### Actions

1. **Install Docker**:
   - If you don’t have Docker, download it from [docker.com](https://www.docker.com) and install it.
2. **Navigate to Your Project**:
   - Open a terminal and `cd` to your project folder (where the `Dockerfile` is, e.g., from the GitHub repo).
3. **Build the Docker Image**:
   - Run:  

     ```bash
     docker build -t auth-service-prod .
     ```

4. **Log In to ECR**:
   - Run (replace `<your-region>` and `<your-aws-account-id>` with your details):  

     ```bash
     aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-aws-account-id>.dkr.ecr.<your-region>.amazonaws.com
     ```

5. **Tag the Image**:
   - Run:  

     ```bash
     docker tag auth-service-prod:latest <your-aws-account-id>.dkr.ecr.<your-region>.amazonaws.com/auth-service:latest
     ```

6. **Push the Image**:
   - Run:  

     ```bash
     docker push <your-aws-account-id>.dkr.ecr.<your-region>.amazonaws.com/auth-service:latest
     ```

### Explanation

Docker packages your app (code, dependencies, etc.) into a single unit called an image. Pushing it to ECR makes it available for ECS to deploy.

---

## Step 6: Create an ECS Task Definition

Tell ECS how to run your app by creating a task definition.

### Actions

1. **Go to ECS**:
   - In the AWS Console, navigate to your ECS cluster.
2. **Create a Task Definition**:
   - Click **"Task Definitions"**, then **"Create new task definition"**.
   - Select **"FARGATE"**.
   - Name it (e.g., `auth-service-task`).
   - Set CPU to `256` and memory to `512 MB` (minimum for small apps).
3. **Add a Container**:
   - Under "Container definitions," click **"Add"**.
   - Fill in:
     - **Name**: `auth-service`
     - **Image**: `<your-aws-account-id>.dkr.ecr.<your-region>.amazonaws.com/auth-service:latest`
     - **Port mappings**: Add `3000` (or your app’s port).
     - **Environment variables**:
       - `MONGO_URI`: Paste your MongoDB Atlas connection string.
       - `NODE_ENV`: `production`
     - For sensitive data (e.g., `JWT_SECRET`):
       - Go to **AWS Secrets Manager** in the console, create a secret (e.g., `auth-service-secrets`), add your secret value, and note the ARN.
       - In the task definition, under "Secrets," add `JWT_SECRET` and link it to the ARN.
   - Click **"Add"**, then **"Create"**.

### Explanation

The task definition is like a blueprint for your app, telling AWS what image to use, how much power it needs, and what settings (like database credentials) it requires.

---

## Step 7: Create an ECS Service

Launch your app and keep it running with an ECS service.

### Actions

1. **Go to Your ECS Cluster**:
   - In the ECS console, select your cluster (e.g., `auth-service-cluster`).
2. **Create a Service**:
   - Click **"Services"**, then **"Create"**.
   - Fill in:
     - **Service name**: `auth-service-service`
     - **Launch type**: `FARGATE`
     - **Task definition**: Select `auth-service-task`
     - **Number of tasks**: `1`
     - **Networking**: Choose your default VPC, subnets, and a security group (allow inbound port `3000` or `80` if using a load balancer).
3. **Optional: Add a Load Balancer**:
   - For public access:
     - Go to **EC2 > Load Balancers**, create an **Application Load Balancer (ALB)**, associate it with your VPC and subnets, and set up a target group (port `3000`).
     - In the ECS service setup, under "Load balancing," select "Yes," choose your ALB, and link it to the target group.
   - Click **"Create service"**.

### Explanation

A service ensures your app stays running. The ALB (optional) makes it accessible online by giving you a public URL.

---

## Step 8: Monitor and Test

Check that everything works as expected.

### Actions

1. **Check Service Status**:
   - In the ECS console, go to your service and confirm the task is "Running."
2. **View Logs**:
   - Click on the task, then the **"Logs"** tab to see output in CloudWatch (helps debug if something’s wrong).
3. **Test Your App**:
   - If using an ALB, copy its DNS name (from the EC2 > Load Balancers page) and visit it in a browser.
   - Without an ALB, test locally if possible, or check logs for database connectivity.

### Explanation

Monitoring confirms your app is live, and testing ensures it works (e.g., can connect to MongoDB and serve requests).

---

## Cost Breakdown

Here’s what this might cost you:

- **ECS with Fargate**: ~$12.44/month (256 CPU, 512 MB, running 24/7).
- **MongoDB Atlas**: Free (M0 tier) for development; ~$47.20/month for production (M2 tier).
- **Total**:
  - Development: ~$0 (using free tiers).
  - Production: ~$59.64/month (Fargate + M2).
- **Compared to EKS**: Kubernetes (EKS) adds a $72/month cluster fee, making it pricier and more complex.

### Explanation

Fargate and MongoDB Atlas keep costs low and simple, avoiding extra fees for server management.

---

## Security Tips

- **Secrets**: Use AWS Secrets Manager for sensitive data like `JWT_SECRET`.
- **Network**: Restrict security group access (e.g., only port `80` or `443` for ALB).
- **HTTPS**: If using an ALB, add a free certificate via AWS Certificate Manager (ACM).

### Explanation

These steps protect your app from unauthorized access and ensure secure communication.

---

## Conclusion

Congratulations! You’ve deployed your accounting boilerplate to AWS using ECS with Fargate and MongoDB Atlas. This guide combined all the pieces—AWS setup, database, Docker, and deployment—into a newbie-friendly process. It’s cost-effective, scalable, and secure, letting you focus on your app rather than infrastructure. If you hit issues, check logs or revisit each step—happy deploying!
