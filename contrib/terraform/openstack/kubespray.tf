resource "openstack_networking_floatingip_v2" "k8s_master" {
    count = "${var.number_of_k8s_masters}"
    pool = "${var.floatingip_pool}"
}

resource "openstack_networking_floatingip_v2" "k8s_node" {
    count = "${var.number_of_k8s_nodes}"
    pool = "${var.floatingip_pool}"
}


resource "openstack_compute_keypair_v2" "k8s" {
    name = "kubernetes-${var.cluster_name}"
    public_key = "${file(var.public_key_path)}"
}

resource "openstack_compute_secgroup_v2" "k8s_master" {
    name = "${var.cluster_name}-k8s-master"
    description = "${var.cluster_name} - Kubernetes Master"
}

resource "openstack_compute_secgroup_v2" "k8s" {
    name = "${var.cluster_name}-k8s"
    description = "${var.cluster_name} - Kubernetes"
    rule {
        ip_protocol = "tcp"
        from_port = "22"
        to_port = "22"
        cidr = "0.0.0.0/0"
    }
    rule {
        ip_protocol = "icmp"
        from_port = "-1"
        to_port = "-1"
        cidr = "0.0.0.0/0"
    }
    rule {
        ip_protocol = "tcp"
        from_port = "1"
        to_port = "65535"
        self = true
    }
    rule {
        ip_protocol = "udp"
        from_port = "1"
        to_port = "65535"
        self = true
    }
    rule {
        ip_protocol = "icmp"
        from_port = "-1"
        to_port = "-1"
        self = true
    }
}

resource "openstack_compute_instance_v2" "k8s_master" {
    name = "${var.cluster_name}-k8s-master-${count.index+1}"
    count = "${var.number_of_k8s_masters}"
    image_name = "${var.image}"
    flavor_id = "${var.flavor_k8s_master}"
    key_pair = "${openstack_compute_keypair_v2.k8s.name}"
    network {
        name = "${var.network_name}"
    }
    security_groups = [ "${openstack_compute_secgroup_v2.k8s_master.name}",
                        "${openstack_compute_secgroup_v2.k8s.name}" ]
    floating_ip = "${element(openstack_networking_floatingip_v2.k8s_master.*.address, count.index)}"
    metadata = {
        ssh_user = "${var.ssh_user}"
        kubespray_groups = "etcd,kube-master,kube-node,k8s-cluster"
    }
}

resource "openstack_compute_instance_v2" "k8s_node" {
    name = "${var.cluster_name}-k8s-node-${count.index+1}"
    count = "${var.number_of_k8s_nodes}"
    image_name = "${var.image}"
    flavor_id = "${var.flavor_k8s_node}"
    key_pair = "${openstack_compute_keypair_v2.k8s.name}"
    network {
        name = "${var.network_name}"
    }
    security_groups = ["${openstack_compute_secgroup_v2.k8s.name}" ]
    floating_ip = "${element(openstack_networking_floatingip_v2.k8s_node.*.address, count.index)}"
    metadata = {
        ssh_user = "${var.ssh_user}"
        kubespray_groups = "kube-node,k8s-cluster"
    }
}

#output "msg" {
#    value = "Your hosts are ready to go!\nYour ssh hosts are: ${join(", ", openstack_networking_floatingip_v2.k8s_master.*.address )}"
#}
