name "db"
description "Database Server Role"
run_list {
  "recipe[mysql::server]"
}
