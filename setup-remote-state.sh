#!/bin/bash

# Script para configurar o Remote State do Terraform
# Este script cria o bucket S3 e a tabela DynamoDB necessários para o backend remoto

set -e

# Configurações
PROJECT_NAME="matcarv"
AWS_REGION="us-east-1"
AWS_PROFILE="matcarv"
BUCKET_NAME="${PROJECT_NAME}-terraform-state"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"

echo "🚀 Configurando Remote State para o projeto ${PROJECT_NAME}"
echo "=================================================="

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não está instalado. Por favor, instale o AWS CLI primeiro."
    exit 1
fi

# Verificar se o profile existe
if ! aws configure list-profiles | grep -q "${AWS_PROFILE}"; then
    echo "❌ Profile AWS '${AWS_PROFILE}' não encontrado. Configure o profile primeiro:"
    echo "   aws configure --profile ${AWS_PROFILE}"
    exit 1
fi

echo "✅ Profile AWS '${AWS_PROFILE}' encontrado"

# Verificar se o bucket já existe
if aws s3api head-bucket --bucket "${BUCKET_NAME}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}" 2>/dev/null; then
    echo "⚠️  Bucket '${BUCKET_NAME}' já existe"
else
    echo "📦 Criando bucket S3: ${BUCKET_NAME}"
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "🔒 Habilitando versionamento no bucket"
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "🛡️  Habilitando criptografia no bucket"
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }' \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "🚫 Bloqueando acesso público ao bucket"
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "✅ Bucket S3 '${BUCKET_NAME}' criado e configurado com sucesso"
fi

# Verificar se a tabela DynamoDB já existe
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}" 2>/dev/null; then
    echo "⚠️  Tabela DynamoDB '${DYNAMODB_TABLE}' já existe"
else
    echo "🗃️  Criando tabela DynamoDB: ${DYNAMODB_TABLE}"
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "⏳ Aguardando tabela DynamoDB ficar ativa..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "🏷️  Adicionando tags à tabela DynamoDB"
    aws dynamodb tag-resource \
        --resource-arn "arn:aws:dynamodb:${AWS_REGION}:$(aws sts get-caller-identity --profile ${AWS_PROFILE} --query Account --output text):table/${DYNAMODB_TABLE}" \
        --tags '[
            {"Key": "Project", "Value": "'${PROJECT_NAME}'"},
            {"Key": "Environment", "Value": "production"},
            {"Key": "CreatedDate", "Value": "2025-08-26"},
            {"Key": "ManagedBy", "Value": "Terraform"},
            {"Key": "Name", "Value": "'${DYNAMODB_TABLE}'"},
            {"Key": "Description", "Value": "DynamoDB table for Terraform state locking"},
            {"Key": "Service", "Value": "DynamoDB"}
        ]' \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}"
    
    echo "✅ Tabela DynamoDB '${DYNAMODB_TABLE}' criada e configurada com sucesso"
fi

echo ""
echo "🎉 Remote State configurado com sucesso!"
echo ""
echo "📋 Informações do Backend:"
echo "   Bucket S3: ${BUCKET_NAME}"
echo "   Tabela DynamoDB: ${DYNAMODB_TABLE}"
echo "   Região: ${AWS_REGION}"
echo ""
echo "🔧 Próximos passos:"
echo "   1. Execute: terraform init"
echo "   2. Quando solicitado, digite 'yes' para migrar o state para o backend remoto"
echo ""
echo "⚠️  IMPORTANTE: Mantenha o bucket S3 e a tabela DynamoDB seguros!"
echo "   Eles contêm informações sensíveis sobre sua infraestrutura."
