# Makefile for Java Sample Application
# Google-like engineering practices for microservices development and deployment

# Variables
SHELL := /bin/bash
PROJECT_ROOT := $(shell pwd)
DOCKER_REPO := your-ecr-repo-url
AWS_REGION := us-west-2
ENV ?= dev

# Docker commands
.PHONY: docker-build
docker-build:
	@echo "Building Docker images for all services..."
	docker-compose -f docker-compose.yml build

.PHONY: docker-push
docker-push:
	@echo "Pushing Docker images to ECR..."
	@for service in api-gateway discovery-server inventory-service notification-service order-service product-service; do \
		aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(DOCKER_REPO); \
		docker tag $$service:latest $(DOCKER_REPO)/$$service:$${GITHUB_SHA:-latest}; \
		docker push $(DOCKER_REPO)/$$service:$${GITHUB_SHA:-latest}; \
	done

# Local Development
.PHONY: dev
dev:
	@echo "Starting local development environment..."
	docker compose up -d

.PHONY: clean
clean:
	@echo "Cleaning up resources..."
	docker compose down -v
	./mvnw clean

# Testing
.PHONY: test
test:
	@echo "Running tests for all services..."
	./mvnw verify

.PHONY: lint
lint:
	@echo "Linting code..."
	./mvnw checkstyle:check
	hadolint **/Dockerfile

# Security Scanning
.PHONY: security-scan
security-scan:
	@echo "Scanning for security vulnerabilities..."
	trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed $$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v '<none>')
	./mvnw org.owasp:dependency-check-maven:check

# Terraform Commands
.PHONY: tf-init
tf-init:
	@echo "Initializing Terraform for $(ENV) environment..."
	cd terraform/environments/$(ENV) && terraform init

.PHONY: tf-plan
tf-plan:
	@echo "Planning Terraform deployment for $(ENV) environment..."
	cd terraform/environments/$(ENV) && terraform plan -var-file=terraform.tfvars -out=tfplan

.PHONY: tf-apply
tf-apply:
	@echo "Applying Terraform deployment for $(ENV) environment..."
	cd terraform/environments/$(ENV) && terraform apply tfplan

.PHONY: tf-destroy
tf-destroy:
	@echo "Destroying Terraform resources for $(ENV) environment..."
	cd terraform/environments/$(ENV) && terraform destroy -var-file=terraform.tfvars -auto-approve

# Deployment
.PHONY: deploy
deploy:
	@echo "Deploying to $(ENV) environment..."
	@if [ "$(ENV)" != "dev" ] && [ "$(ENV)" != "prod" ]; then \
		echo "Error: ENV must be either 'dev' or 'prod'"; \
		exit 1; \
	fi
	$(MAKE) docker-build
	$(MAKE) docker-push
	$(MAKE) tf-apply ENV=$(ENV)

# Rollback - requires deployment version as parameter (VERSION=xyz)
.PHONY: rollback
rollback:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION parameter is required"; \
		exit 1; \
	fi
	@echo "Rolling back to version $(VERSION) in $(ENV) environment..."
	aws ecs update-service --cluster $(ENV)-cluster --service $(ENV)-service --force-new-deployment --task-definition $(ENV)-task:$(VERSION)

# Monitoring setup
.PHONY: setup-monitoring
setup-monitoring:
	@echo "Setting up monitoring dashboard and alarms for $(ENV) environment..."
	cd terraform/environments/$(ENV) && terraform apply -var-file=terraform.tfvars -target=module.monitoring

# Help
.PHONY: help
help:
	@echo "Available make commands:"
	@echo "  make dev              - Start local development environment"
	@echo "  make test             - Run tests"
	@echo "  make lint             - Run code linting"
	@echo "  make security-scan    - Run security scanning"
	@echo "  make docker-build     - Build Docker images"
	@echo "  make docker-push      - Push Docker images to repository"
	@echo "  make deploy ENV=dev   - Deploy to dev environment"
	@echo "  make deploy ENV=prod  - Deploy to production environment"
	@echo "  make rollback ENV=dev VERSION=123  - Rollback to a specific version"
	@echo "  make setup-monitoring ENV=dev      - Setup monitoring for environment"
	@echo "  make clean            - Clean up resources"