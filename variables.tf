###cloud vars
variable "token" {
  type        = string
  default     = "y0__xD5wYY7GMHdEyD5kbneFjD0mpTmB8oeDyv_SX8KIPrsu4j8SbqHnQ1Z"
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}
variable "cloud_id" {
  type        = string
  default     = "b1gcal7e7b71h8bll679"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  default     = "b1gdfb3utje177var1ls"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}
variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}
variable "default_cidr" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "vpc_name" {
  type        = string
  default     = "develop"
  description = "VPC network&subnet name"
}

variable "storage_resources" {
  type = map(number)
  default = {
      cores = 2
      memory = 1
      core_fraction = 20
  }
}
