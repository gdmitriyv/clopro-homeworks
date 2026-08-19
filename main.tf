# ==============================================================================
# 1. СЕТЕВАЯ ИНФРАСТРУКТУРА
# ==============================================================================

data "yandex_compute_image" "ubuntu_2404" {
  family = "ubuntu-2404-lts"
}

resource "yandex_vpc_network" "homework_vpc" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "public_subnet" {
  name           = "public"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.homework_vpc.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# ==============================================================================
# 2. СЕРВИСНЫЙ АККАУНТ ДЛЯ ГРУППЫ ВМ
# ==============================================================================

resource "yandex_iam_service_account" "sa_ig" {
  name = "sa-instance-group-clean"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_ig_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa_ig.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_ig_vpc" {
  folder_id = var.folder_id
  role      = "vpc.user"
  member    = "serviceAccount:${yandex_iam_service_account.sa_ig.id}"
}

# ==============================================================================
# 3. COMPUTE INSTANCE GROUP (ГРУППА ВМ)
# ==============================================================================

resource "yandex_compute_instance_group" "lamp_group" {
  name               = "lamp-instance-group"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.sa_ig.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.sa_ig_editor,
    yandex_resourcemanager_folder_iam_member.sa_ig_vpc
  ]

  load_balancer {
    target_group_name        = "nlb-target-group"
    target_group_description = "Target group for network load balancer"
  }

  allocation_policy {
    zones = [var.default_zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_creating    = 3
    max_expansion   = 1
    max_deleting    = 1
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  instance_template {
    name     = "lamp-web-server-{instance.index}"
    hostname = "lamp-web-server-{instance.index}"

    platform_id = "standard-v3"
    resources {
      core_fraction = var.storage_resources.core_fraction
      cores         = var.storage_resources.cores
      memory        = var.storage_resources.memory
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd827b91d99psvq5fjit"
        size     = 15
      }
    }

    network_interface {
      network_id = yandex_vpc_network.homework_vpc.id
      subnet_ids = [yandex_vpc_subnet.public_subnet.id]
      nat        = true 
    }

    metadata = {
      ssh-keys  = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
      
      # ВСТАВЛЕНО: Ваша новая прямая интернет-ссылка на картинку в бакете dgv
      user-data = <<EOF
#!/bin/bash
echo '<!DOCTYPE html>
<html>
<head>
    <title>Netology Homework 15.2</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Hello from Netology LAMP Instance Group!</h1>
    <p>Image dynamically loaded from Object Storage:</p>
    <img src="https://storage.yandexcloud.net/dgv/picture.jpg" alt="Netology Image" width="600">
</body>
</html>' > /var/www/html/index.html

systemctl restart apache2
EOF
    }
  }

  health_check {
    interval            = 10
    timeout             = 2
    unhealthy_threshold = 3
    healthy_threshold   = 2
    http_options {
      port = 80
      path = "/"
    }
  }
}

# ==============================================================================
# 4. NETWORK LOAD BALANCER (БАЛАНСИРОВЩИК ТРАФИКА)
# ==============================================================================

resource "yandex_lb_network_load_balancer" "main_nlb" {
  name = "network-load-balancer"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    # СТУДЕНЧЕСКИЙ ИСПРАВЛЕННЫЙ СИНТАКСИС: Добавлен обязательный индекс [0]
    target_group_id = yandex_compute_instance_group.lamp_group.load_balancer[0].target_group_id

    # Слитное написание специально под вашу версию провайдера
    healthcheck {
      name                = "http-health-check"
      interval            = 5
      timeout             = 2
      unhealthy_threshold = 3
      healthy_threshold   = 2
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

# ==============================================================================
# 5. OUTPUTS (ВЫВОД IP АДРЕСА)
# ==============================================================================

output "balancer_public_ip" {
  value       = yandex_lb_network_load_balancer.main_nlb.listener
  description = "Параметры слушателя балансировщика трафика (включая IP-адрес)"
}
