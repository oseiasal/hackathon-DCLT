data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# =============================================================================
# 1. IAM Role OIDC dedicada exclusivamente ao repositório hackathon-DCLT
# =============================================================================
resource "aws_iam_role" "github_actions" {
  name        = var.role_name
  description = "Role OIDC de menor privilegio + ABAC para GitHub Actions (${var.project_name})"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.allowed_subjects
        }
      }
    }]
  })

  tags = {
    Name = var.role_name
  }
}

# =============================================================================
# 2. Policy 1 — Dados, State, ECR, SSM, SQS, DynamoDB, Secrets & Budgets
# =============================================================================
resource "aws_iam_policy" "cicd_data" {
  name        = "${var.project_name}-github-cicd-data"
  description = "Least privilege para S3 tfstate, ECR, SSM, SQS, DynamoDB, Secrets Manager e Budgets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "STSCallerIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:CreateBucket",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-tfstate-*",
          "arn:aws:s3:::${var.project_name}-tfstate-*/*"
        ]
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "ECRProjectRepositories"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "arn:aws:ecr:*:${local.account_id}:repository/${var.project_name}/*"
      },
      {
        Sid      = "SSMDescribe"
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
      {
        Sid      = "SSMProjectParameters"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = "arn:aws:ssm:*:${local.account_id}:parameter/${var.project_name}/*"
      },
      {
        Sid      = "SQSProjectQueues"
        Effect   = "Allow"
        Action   = ["sqs:*"]
        Resource = "arn:aws:sqs:*:${local.account_id}:solidary-*"
      },
      {
        Sid    = "DynamoDBProjectTables"
        Effect = "Allow"
        Action = ["dynamodb:*"]
        Resource = [
          "arn:aws:dynamodb:*:${local.account_id}:table/SolidaryTech*",
          "arn:aws:dynamodb:*:${local.account_id}:table/SolidaryTech*/index/*"
        ]
      },
      {
        Sid    = "SecretsManagerReadProjectAndRDS"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecrets"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:${local.account_id}:secret:rds!*",
          "arn:aws:secretsmanager:*:${local.account_id}:secret:${var.project_name}/*"
        ]
      },
      {
        Sid      = "FinOpsBudgets"
        Effect   = "Allow"
        Action   = ["budgets:*"]
        Resource = "arn:aws:budgets::${local.account_id}:budget/${var.project_name}-*"
      },
      {
        Sid      = "KMSReadAndGrant"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey", "kms:ListAliases", "kms:CreateGrant"]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# 3. Policy 2 — Infraestrutura (EC2/VPC, EKS, RDS, ElastiCache) com ABAC + IAM Escopado
# =============================================================================
resource "aws_iam_policy" "infra_abac" {
  name        = "${var.project_name}-github-infra-abac"
  description = "ABAC por tag Project=${var.project_name} para VPC/EKS/RDS/ElastiCache + IAM escopado"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyForTerraformPlan"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*",
          "eks:List*",
          "rds:Describe*",
          "rds:ListTagsForResource",
          "elasticache:Describe*",
          "elasticache:ListTagsForResource",
          "autoscaling:Describe*",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CreateResourcesWithProjectTag"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:AllocateAddress",
          "ec2:CreateTags",
          "eks:CreateCluster",
          "eks:CreateNodegroup",
          "eks:CreateAccessEntry",
          "eks:TagResource",
          "rds:CreateDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:AddTagsToResource",
          "elasticache:CreateCacheCluster",
          "elasticache:CreateCacheSubnetGroup",
          "elasticache:AddTagsToResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project_name
          }
        }
      },
      {
        Sid    = "ManageProjectTaggedResources"
        Effect = "Allow"
        Action = [
          "ec2:Delete*",
          "ec2:Modify*",
          "ec2:ReleaseAddress",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "eks:Update*",
          "eks:Delete*",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "rds:Modify*",
          "rds:Delete*",
          "elasticache:Modify*",
          "elasticache:Delete*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Sid    = "IAMScopedToProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/${var.project_name}-*"
      },
      {
        Sid    = "EKSOpenIDConnectProviders"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint"
        ]
        Resource = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.*"
      },
      {
        Sid      = "ServiceLinkedRolesForProjectServices"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com",
              "rds.amazonaws.com",
              "elasticache.amazonaws.com",
              "autoscaling.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "DenyDestructiveOnOtherProjects"
        Effect = "Deny"
        Action = [
          "ec2:Delete*",
          "ec2:Terminate*",
          "eks:Delete*",
          "rds:Delete*",
          "elasticache:Delete*"
        ]
        Resource = "*"
        Condition = {
          StringNotEqualsIfExists = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd_data" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.cicd_data.arn
}

resource "aws_iam_role_policy_attachment" "infra_abac" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.infra_abac.arn
}
