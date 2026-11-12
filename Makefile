.PHONY: help deploy deploy-tf deploy-cfn seed test-local clean lint test

ENV ?= dev
SERVICE ?= all

help:
	@echo "Serverless ImageFlow - Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy ENV=dev              Deploy with Terraform"
	@echo "  make deploy-tf ENV=dev           Deploy with Terraform"
	@echo "  make deploy-cfn ENV=dev          Deploy with CloudFormation"
	@echo "  make seed ENV=dev                Seed sample images"
	@echo "  make test-local ENV=dev          Run local tests"
	@echo "  make lint                        Run linters (flake8 + black)"
	@echo "  make test                        Run Python tests"
	@echo "  make clean                       Clean build artifacts"
	@echo "  make destroy                     Destroy infrastructure"

deploy:
	./scripts/deploy.sh --terraform $(ENV)

deploy-tf:
	./scripts/deploy.sh --terraform $(ENV)

deploy-cfn:
	./scripts/deploy.sh --cloudformation $(ENV)

seed:
	./scripts/seed-sample-images.sh $(ENV)

test-local:
	./scripts/test-local.sh $(ENV)

lint:
	flake8 lambda/ --max-line-length=100 --extend-ignore=E203,W503
	black --check lambda/ --line-length=100

test:
	python -m pytest lambda/ -v

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete
	rm -f processor.zip api.zip

destroy:
	./scripts/cleanup.sh $(ENV)
