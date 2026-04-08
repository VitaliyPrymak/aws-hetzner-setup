terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }

  # Remote state in Hetzner Object Storage.
  # Init with: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  config = yamldecode(file("${path.module}/data/config.yaml"))
  nodes  = { for n in local.config.nodes : n.name => n }
}

resource "hcloud_ssh_key" "main" {
  name       = local.config.cluster_name
  public_key = local.config.ssh_public_key
}

resource "hcloud_network" "main" {
  name     = local.config.cluster_name
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_server" "nodes" {
  for_each = local.nodes

  name        = each.value.name
  server_type = each.value.server_type
  image       = each.value.image
  location    = each.value.location
  ssh_keys    = [hcloud_ssh_key.main.id]

  user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
    hostname       = each.value.name
    ssh_user       = local.config.ssh_user
    ssh_public_key = local.config.ssh_public_key
    packages       = concat(local.config.default_packages, lookup(each.value, "extra_packages", []))
  })

  network {
    network_id = hcloud_network.main.id
  }

  depends_on = [hcloud_network_subnet.main]
}

resource "hcloud_firewall" "nodes" {
  name = local.config.cluster_name

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["10.8.0.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5000"
    source_ips = ["10.0.1.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8080"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5432"
    source_ips = ["10.0.1.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "any"
    source_ips = ["10.0.1.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "any"
    source_ips = ["10.0.1.0/24"]
  }
}

resource "hcloud_firewall" "lb" {
  name = "${local.config.cluster_name}-lb"

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "20000"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["10.8.0.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "any"
    source_ips = ["10.0.1.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "any"
    source_ips = ["10.0.1.0/24"]
  }
}

resource "hcloud_firewall" "vpn" {
  name = "${local.config.cluster_name}-vpn"

  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["10.8.0.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "1194"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["10.8.0.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "any"
    source_ips = ["10.0.1.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "any"
    source_ips = ["10.0.1.0/24"]
  }
}

resource "hcloud_firewall_attachment" "nodes" {
  firewall_id = hcloud_firewall.nodes.id
  server_ids = [
    for name, server in hcloud_server.nodes : server.id
    if contains(["worker", "runner"], local.nodes[name].role)
  ]
}

resource "hcloud_firewall_attachment" "lb" {
  firewall_id = hcloud_firewall.lb.id
  server_ids = [
    for name, server in hcloud_server.nodes : server.id
    if contains(["edge"], local.nodes[name].role)
  ]
}

resource "hcloud_firewall_attachment" "vpn" {
  firewall_id = hcloud_firewall.vpn.id
  server_ids = [
    for name, server in hcloud_server.nodes : server.id
    if contains(["edge"], local.nodes[name].role)
  ]
}