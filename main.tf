data "template_file" "install" {
  template = file("${path.module}/templates/install-${var.base_os}.tpl")
  vars = {
    cassandra_version = var.cassandra_version
  }
}

data "template_file" "configure" {
  template = file("${path.module}/templates/configure.tpl")

  vars = {
    cluster_name = var.cassandra_cluster_name
    seeds = var.existing_cluster == "true" ? local.seeds_add : local.seeds_new
    auto_bootstrap = var.existing_cluster
    config_home = "${var.base_os}" == "centos" ? "/etc/cassandra/default.conf/cassandra.yaml" : ("${var.base_os}" == "ubuntu" ? "/etc/cassandra/cassandra.yaml": "")
  }
}

data "template_file" "attach_disk" {
  template = file("${path.module}/templates/attach_disk.tpl")
}

data "google_compute_zones" "available" {}

locals {
  count = length(data.google_compute_zones.available.names)
  seeds_new = join("," , concat( slice(google_compute_instance.default.*.network_interface.0.network_ip,0,2),var.add_seeds))
  seeds_add = join("," , var.add_seeds)
  image = "${var.base_os}" == "centos" ? "centos-cloud/centos-7" : ("${var.base_os}" == "ubuntu" ? "ubuntu-os-cloud/ubuntu-1604-lts": "")
}

resource "google_compute_disk" "default" {
  count = local.count

  name  = "${var.project_name}-data-${count.index}"
  type  = "pd-ssd"
  zone  = data.google_compute_zones.available.names[count.index]
  size  = var.data_disk_size
}

resource "google_compute_instance" "default" {
  count = local.count

  name         = "${var.project_name}-${count.index}"
  machine_type = var.machine_type
  zone         = data.google_compute_zones.available.names[count.index]
  allow_stopping_for_update = true

  tags = var.tags

  boot_disk {
    initialize_params {
      image = local.image
      size  = var.boot_disk_size
      type  = "pd-ssd"
    }
  }
  
  attached_disk {
    source = element(google_compute_disk.default.*.name, count.index)
  }

  network_interface {
    subnetwork = var.subnetwork
  }
}

resource "null_resource" "attach_disk" {
  count = local.count

  depends_on = [google_compute_disk.default]

  triggers = {
    script = data.template_file.attach_disk.rendered
  }

  connection {
    type     = "ssh"
    user     = var.ssh_user
    private_key = file("${var.ssh_key_path}")
    host = element(google_compute_instance.default.*.network_interface.0.network_ip, count.index)
  }

  provisioner "remote-exec" {
    inline = [data.template_file.attach_disk.rendered]
  }
}

resource "null_resource" "install" {
  count = local.count

  depends_on = [null_resource.attach_disk]
  triggers = {
    script = data.template_file.install.rendered
  }

  connection {
    type     = "ssh"
    user     = var.ssh_user
    private_key = file("${var.ssh_key_path}")
    host = element(google_compute_instance.default.*.network_interface.0.network_ip, count.index)
  }

  provisioner "remote-exec" {
    inline = [data.template_file.install.rendered]
  }
}

resource "null_resource" "configure" {
  count = local.count
  
  depends_on = [null_resource.install]
  triggers = {
    script = data.template_file.configure.rendered
  }

  connection {
    type     = "ssh"
    user     = var.ssh_user
    private_key = file("${var.ssh_key_path}")
    host = element(google_compute_instance.default.*.network_interface.0.network_ip, count.index)
  }

  provisioner "remote-exec" {
    inline = [data.template_file.configure.rendered]
  }
}
