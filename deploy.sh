#!/bin/bash

# MatCarv AWS Infrastructure Deploy Script
# Este script facilita o deploy da infraestrutura

set -e

echo "🚀 MatCarv AWS Infrastructure Deploy"
echo "===================================="

# Verificar se o Terraform está instalado
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não está instalado. Por favor, instale o Terraform primeiro."
    exit 1
fi

# Verificar se o AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não está instalado. Por favor, instale o AWS CLI primeiro."
    exit 1
fi

# Verificar se o profile matcarv existe
if ! aws configure list-profiles | grep -q "matcarv"; then
    echo "❌ Profile AWS 'matcarv' não encontrado. Configure o profile primeiro:"
    echo "   aws configure --profile matcarv"
    exit 1
fi

# Verificar se o arquivo terraform.tfvars existe
if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Arquivo terraform.tfvars não encontrado. Copiando do exemplo..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ Arquivo terraform.tfvars criado. Edite-o conforme necessário."
    echo "   Pressione Enter para continuar após editar o arquivo..."
    read
fi

echo "🔧 Inicializando Terraform..."
terraform init

echo "✅ Validando configuração..."
terraform validate

echo "📋 Gerando plano de execução..."
terraform plan

echo ""
echo "🤔 Deseja aplicar a infraestrutura? (y/N)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🚀 Aplicando infraestrutura..."
    terraform apply
    
    echo ""
    echo "🎉 Deploy concluído com sucesso!"
    echo "📊 Para ver os outputs:"
    echo "   terraform output"
    echo ""
    echo "🌐 Sua aplicação estará disponível em:"
    terraform output -raw application_url_https 2>/dev/null || echo "   https://app.matcarv.com.br"
    echo "   (HTTP será redirecionado automaticamente para HTTPS)"
else
    echo "❌ Deploy cancelado."
fi
