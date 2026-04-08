output "nodes" {
  value = {
    for name, server in hcloud_server.nodes : name => {
      public_ip  = server.ipv4_address
      private_ip = one([
        for net in server.network : net.ip
      ])
      role = local.nodes[name].role
    }
  }
}