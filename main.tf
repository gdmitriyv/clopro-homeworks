# Автоматический поиск актуального ID образа Ubuntu 24.04 LTS
data "yandex_compute_image" "ubuntu_2404" {
  family = "ubuntu-2404-lts"
}

# 1. Создание пустой VPC
resource "yandex_vpc_network" "homework_vpc" {
  name = var.vpc_name
}

# 2. ПУБЛИЧНАЯ ПОДСЕТЬ
resource "yandex_vpc_subnet" "public_subnet" {
  name           = "public"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.homework_vpc.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# 3. NAT-инстанс в публичной подсети
resource "yandex_compute_instance" "nat_instance" {
  name        = "nat-instance"
  zone        = var.default_zone
  platform_id = "standard-v3"

  resources {
    cores         = var.storage_resources.cores
    memory        = var.storage_resources.memory
    core_fraction = var.storage_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1" # Специальный образ NAT от Yandex Cloud
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public_subnet.id
    ip_address = "192.168.10.254" # Фиксированный IP по ТЗ
    nat        = true             # Публичный IP для выхода в интернет
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# 4. Публичная ВМ для проверки доступа
resource "yandex_compute_instance" "public_vm" {
  name        = "public-vm"
  zone        = var.default_zone
  platform_id = "standard-v3"

  resources {
    cores         = var.storage_resources.cores
    memory        = var.storage_resources.memory
    core_fraction = var.storage_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404.id # Динамический поиск образа
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public_subnet.id
    nat       = true # Нужен по ТЗ для прямой проверки интернета
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# 5. ПРИВАТНАЯ ПОДСЕТЬ
resource "yandex_vpc_subnet" "private_subnet" {
  name           = "private"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.homework_vpc.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id # Привязка таблицы маршрутизации
}

# 6. Таблица маршрутизации (Route Table) для приватной сети
resource "yandex_vpc_route_table" "private_rt" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.homework_vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"                                      # Весь исходящий трафик
    next_hop_address   = yandex_compute_instance.nat_instance.network_interface[0].ip_address # Исправленный индекс
  }
}

# 7. Приватная ВМ
resource "yandex_compute_instance" "private_vm" {
  name        = "private-vm"
  zone        = var.default_zone
  platform_id = "standard-v3"

  resources {
    cores         = var.storage_resources.cores
    memory        = var.storage_resources.memory
    core_fraction = var.storage_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2404.id # Динамический поиск образа
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private_subnet.id
    nat       = false # Строго FALSE (нет публичного IP)
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# Вывод IP-адресов после развертывания в консоль
output "public_vm_external_ip" {
  value = yandex_compute_instance.public_vm.network_interface[0].nat_ip_address # Исправленный индекс
}

output "private_vm_internal_ip" {
  value = yandex_compute_instance.private_vm.network_interface[0].ip_address # Исправленный индекс
}
