# MatCarv AWS Infrastructure as Code

Este repositório contém a infraestrutura como código (IaC) usando Terraform para provisionar uma arquitetura completa na AWS.

## Arquitetura

A infraestrutura provisiona os seguintes recursos:

### Rede
- **VPC**: 192.168.1.0/24
- **Subnets Públicas**: 2 subnets em AZs diferentes
- **Subnets Privadas**: 2 subnets em AZs diferentes
- **Internet Gateway**: Para acesso à internet das subnets públicas
- **NAT Gateways**: 2 NAT Gateways para acesso à internet das subnets privadas
- **Route Tables**: Configuradas para roteamento adequado

### Computação
- **EC2**: Instância t3a.small com Auto Scaling Group
- **Launch Template**: Configurado com Ubuntu 22.04 LTS
- **EBS**: Volume criptografado com KMS
- **User Data**: Instalação e configuração do Apache HTTP Server

### Banco de Dados
- **RDS MySQL**: Instância db.t4g.small
- **Criptografia**: Habilitada com KMS
- **Backup**: Retenção de 7 dias
- **Multi-AZ**: Configurado para alta disponibilidade
- **Enhanced Monitoring**: Habilitado

### Load Balancer
- **Application Load Balancer (ALB)**: Distribuição de tráfego
- **Target Group**: Configurado para instâncias EC2
- **Health Checks**: Monitoramento da saúde das instâncias
- **SSL/TLS**: Certificado wildcard *.matcarv.com.br via ACM
- **Redirecionamento**: HTTP (80) → HTTPS (443)
- **Access Logs**: Habilitado para bucket S3 matcarv-logs

### Armazenamento e Logs
- **S3 Bucket**: matcarv-logs para armazenar logs do ALB e CloudTrail
- **Criptografia S3**: AES256 server-side encryption
- **Lifecycle Policy**: Retenção de 90 dias para logs
- **Versionamento**: Habilitado com retenção de 30 dias para versões antigas

### Auditoria e Monitoramento
- **CloudTrail**: Auditoria completa de API calls
- **CloudWatch Logs**: Logs do CloudTrail com retenção de 30 dias
- **CloudWatch Dashboard**: Painel de monitoramento da infraestrutura
- **CloudWatch Alarms**: Alertas para métricas críticas
- **CloudWatch Agent**: Monitoramento detalhado de EC2 (CPU, memória, disco)
- **KMS Encryption**: Logs do CloudTrail criptografados
- **Multi-Region**: CloudTrail configurado para todas as regiões
- **Data Events**: Monitoramento de eventos S3

### DNS
- **Route53**: Registro A para app.matcarv.com.br
- **Alias**: Apontando para o ALB

### Segurança
- **Security Groups**: Configurados com acesso restritivo
  - ALB: Acesso público nas portas 80 e 443
  - EC2: Acesso apenas do ALB na porta 80
  - RDS: Acesso apenas do EC2 na porta 3306
- **KMS Keys**: Chaves separadas para EBS e RDS
- **IAM Roles**: Para monitoramento do RDS
- **SSL Certificate**: Certificado wildcard gerenciado pelo ACM

## Pré-requisitos

1. **Terraform**: Versão >= 1.0
2. **AWS CLI**: Configurado com o profile `matcarv`
3. **Zona Route53**: `matcarv.com.br` deve existir na conta AWS
4. **Certificado SSL**: Certificado wildcard `*.matcarv.com.br` deve estar disponível no ACM **na região us-east-1 (Norte da Virgínia)**
5. **Remote State**: Bucket S3 e tabela DynamoDB para armazenar o estado do Terraform

### ⚠️ Importante sobre o Certificado SSL
O certificado SSL deve estar na mesma região da infraestrutura (us-east-1). Se você possui o certificado em outra região:

1. **Opção 1**: Solicitar um novo certificado na região us-east-1
2. **Opção 2**: Alterar a região da infraestrutura para onde o certificado existe
3. **Opção 3**: Temporariamente comentar as configurações HTTPS no `alb.tf` para deploy inicial

### 🗄️ Remote State
Este projeto utiliza **Remote State** com backend S3 para:
- **Armazenar o estado**: Bucket S3 `matcarv-terraform-state`
- **Controle de concorrência**: Tabela DynamoDB `matcarv-terraform-locks`
- **Segurança**: Estado criptografado e versionado

## Configuração

1. Clone o repositório:
```bash
git clone <repository-url>
cd matcarv-aws-iac
```

2. Configure o Remote State (primeira vez apenas):
```bash
./setup-remote-state.sh
```

3. Copie o arquivo de variáveis de exemplo:
```bash
cp terraform.tfvars.example terraform.tfvars
```

4. Edite o arquivo `terraform.tfvars` conforme necessário.

## Deploy

1. Inicialize o Terraform:
```bash
terraform init
```

2. Valide a configuração:
```bash
terraform validate
```

3. Visualize o plano de execução:
```bash
terraform plan
```

4. Aplique a infraestrutura:
```bash
terraform apply
```

## Remote State

### 🗄️ Configuração do Backend Remoto
Este projeto utiliza **S3 Backend** para armazenar o estado do Terraform de forma segura e colaborativa:

#### **Recursos do Remote State:**
- **Bucket S3**: `matcarv-terraform-state`
  - Versionamento habilitado
  - Criptografia AES256
  - Acesso público bloqueado
- **Tabela DynamoDB**: `matcarv-terraform-locks`
  - Controle de concorrência
  - Prevenção de conflitos em equipe
  - Locking automático durante operações

#### **Benefícios:**
- ✅ **Colaboração**: Múltiplos desenvolvedores podem trabalhar no mesmo projeto
- ✅ **Segurança**: Estado criptografado e versionado
- ✅ **Backup**: Histórico completo de mudanças
- ✅ **Locking**: Previne operações simultâneas conflitantes
- ✅ **Auditoria**: Rastreamento de todas as modificações

#### **Configuração Inicial:**
```bash
# Execute apenas uma vez para configurar o backend
./setup-remote-state.sh
```

#### **Migração do Estado Local:**
Se você já tem um estado local, o Terraform perguntará se deseja migrar:
```bash
terraform init
# Responda 'yes' quando perguntado sobre migração
```

#### **⚠️ Importante:**
- Execute `setup-remote-state.sh` **apenas uma vez** por projeto
- Mantenha o bucket S3 e tabela DynamoDB seguros
- **Nunca delete** estes recursos sem fazer backup do estado
- O estado contém informações sensíveis (senhas, chaves, etc.)

## Acesso à Aplicação

Após o deploy, a aplicação estará disponível em:
- **URL HTTPS**: https://app.matcarv.com.br
- **URL HTTP**: http://app.matcarv.com.br (redireciona para HTTPS)
- **Load Balancer**: Distribui o tráfego entre as instâncias EC2

## Monitoramento

### 📊 CloudWatch Dashboard
A infraestrutura inclui um dashboard completo do CloudWatch com:

#### **Métricas do EC2:**
- **CPU Utilization**: Monitoramento de uso de CPU das instâncias
- **Memory Utilization**: Uso de memória (via CloudWatch Agent)
- **Network In/Out**: Tráfego de rede das instâncias
- **Disk Usage**: Utilização de disco

#### **Métricas do RDS:**
- **CPU Utilization**: Uso de CPU do banco de dados
- **Database Connections**: Número de conexões ativas
- **Free Storage Space**: Espaço livre em disco
- **Read/Write IOPS**: Operações de I/O por segundo
- **Read/Write Latency**: Latência de operações de leitura/escrita

#### **Métricas do ALB:**
- **Request Count**: Número de requisições
- **Target Response Time**: Tempo de resposta dos targets
- **Healthy/Unhealthy Hosts**: Status dos hosts

#### **Métricas do Auto Scaling:**
- **Group Desired Capacity**: Capacidade desejada
- **Group In Service Instances**: Instâncias em serviço
- **Group Total Instances**: Total de instâncias

### 🚨 CloudWatch Alarms
Alarmes configurados para métricas críticas:

- **EC2 High CPU**: Alerta quando CPU > 80%
- **RDS High CPU**: Alerta quando CPU do RDS > 80%
- **RDS Low Storage**: Alerta quando storage < 2GB
- **ALB High Response Time**: Alerta quando tempo de resposta > 1s
- **ALB Unhealthy Hosts**: Alerta quando há hosts não saudáveis

### 📈 CloudWatch Agent
As instâncias EC2 incluem o CloudWatch Agent para monitoramento detalhado:
- **Métricas de Sistema**: CPU, memória, disco, rede
- **Métricas Customizadas**: Namespace CWAgent
- **Coleta Automática**: Intervalo de 5 minutos
- **Permissões IAM**: Role dedicada para envio de métricas

### 🔗 Acesso ao Dashboard
Após o deploy, acesse o dashboard em:
```
https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=matcarv-infrastructure-dashboard
```

## Segurança

### Criptografia
- **EBS**: Volumes criptografados com KMS
- **RDS**: Banco de dados criptografado com KMS
- **Backups**: Backups automáticos criptografados
- **SSL/TLS**: Certificado wildcard para comunicação segura

### Rede
- **Subnets Privadas**: EC2 e RDS em subnets privadas
- **Security Groups**: Acesso altamente restritivo
  - RDS acessível apenas pelo EC2
  - EC2 acessível apenas pelo ALB
  - ALB acessível publicamente apenas nas portas 80/443
- **NAT Gateways**: Acesso seguro à internet para recursos privados

### Certificado SSL
- **Wildcard Certificate**: *.matcarv.com.br gerenciado pelo ACM
- **Redirecionamento HTTP**: Todo tráfego HTTP é redirecionado para HTTPS
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01

## Custos Estimados

Os principais componentes de custo incluem:
- EC2 t3a.small: ~$15/mês
- RDS db.t4g.small: ~$25/mês
- ALB: ~$22/mês
- NAT Gateways: ~$46/mês (2 gateways)
- EBS e outros: ~$15/mês

**Total estimado**: ~$123/mês

> 📊 **Calculadora Interativa**: Abra o arquivo `cost-estimation.html` no seu navegador para uma estimativa detalhada e interativa dos custos com gráficos dinâmicos.

> Use a [Calculadora de Preços AWS](https://calculator.aws) para estimativas mais precisas.

## Calculadora de Custos Interativa

### 💰 Estimativa Dinâmica de Custos
A infraestrutura inclui uma calculadora interativa de custos (`cost-estimation.html`) com:

#### **📊 Recursos da Calculadora:**
- **Gráficos Dinâmicos**: Visualização em tempo real dos custos
- **Configuração Interativa**: Ajuste de parâmetros da infraestrutura
- **Projeções**: Custos mensais, anuais, diários e por hora
- **Detalhamento**: Breakdown completo por recurso
- **Responsiva**: Funciona em desktop e mobile

#### **🎛️ Controles Disponíveis:**
- **Número de Instâncias EC2**: 1-10 instâncias
- **Tipo de Instância EC2**: t3a.small até t3a.xlarge
- **Tipo de Instância RDS**: db.t4g.small até db.t4g.xlarge
- **Armazenamento RDS**: 20GB até 1TB

#### **📈 Gráficos Incluídos:**
- **Pizza**: Distribuição de custos por serviço
- **Linha**: Projeção de custos ao longo de 12 meses
- **Tabela**: Detalhamento completo por recurso

#### **💡 Como Usar:**
1. Abra o arquivo `cost-estimation.html` no navegador
2. Ajuste os parâmetros conforme sua necessidade
3. Visualize os custos atualizados em tempo real
4. Use as informações para planejamento de orçamento

#### **🎯 Recursos Monitorados:**
- EC2 Instances (Auto Scaling)
- RDS MySQL Database
- Application Load Balancer
- NAT Gateways (2x)
- Elastic IPs (2x)
- S3 Bucket (Logs)
- CloudTrail
- CloudWatch (Dashboard + Alarms)
- KMS Keys (3x)
- Route53 Hosted Zone

## Limpeza

Para destruir toda a infraestrutura:
```bash
terraform destroy
```

## Estrutura de Arquivos

```
.
├── README.md                 # Este arquivo
├── main.tf                   # Configuração do provider e data sources
├── vpc.tf                    # VPC, Subnets, Gateways e Roteamento
├── variables.tf              # Definição de variáveis
├── outputs.tf                # Outputs da infraestrutura
├── security_groups.tf        # Security Groups
├── kms.tf                    # Chaves KMS para criptografia
├── ec2.tf                    # Configuração do EC2 e Auto Scaling
├── rds.tf                    # Configuração do RDS MySQL
├── alb.tf                    # Application Load Balancer e SSL
├── route53.tf                # Configuração do Route53
├── s3.tf                     # Bucket S3 para logs
├── cloudtrail.tf             # CloudTrail e CloudWatch Logs
├── cloudwatch.tf             # Dashboard e Alarms do CloudWatch
├── cost-estimation.html      # Calculadora interativa de custos
├── setup-remote-state.sh     # Script para configurar Remote State
├── terraform.tfvars.example  # Exemplo de variáveis
└── .gitignore               # Arquivos ignorados pelo Git
```

## Variáveis Principais

| Variável | Descrição | Valor Padrão |
|----------|-----------|--------------|
| `aws_region` | Região AWS | `us-east-1` |
| `project_name` | Nome do projeto | `matcarv` |
| `vpc_cidr` | CIDR da VPC | `192.168.1.0/24` |
| `instance_type` | Tipo da instância EC2 | `t3a.small` |
| `db_instance_class` | Classe da instância RDS | `db.t4g.small` |
| `domain_name` | Nome do domínio | `app.matcarv.com.br` |

## Troubleshooting

### Problemas Comuns

1. **Profile AWS não encontrado**:
   - Verifique se o profile `matcarv` está configurado no AWS CLI

2. **Zona Route53 não encontrada**:
   - Certifique-se de que a zona `matcarv.com.br` existe na sua conta AWS

3. **Certificado SSL não encontrado**:
   - Verifique se o certificado wildcard `*.matcarv.com.br` está disponível no ACM
   - O certificado deve estar na mesma região da infraestrutura

4. **Limites de recursos**:
   - Verifique os limites da sua conta AWS para VPCs, EIPs, etc.

## Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.