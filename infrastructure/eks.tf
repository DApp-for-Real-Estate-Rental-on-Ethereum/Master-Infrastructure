module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_public_access  = true

  # Disable control plane logging to stay within Free Tier
  cluster_enabled_log_types = []

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    initial = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "production"
    Project     = "real-estate"
  }
}
