# Kitchen Stadium

Manage your cloud instances and run one-off processes in the cloud.

*Note*: This gem is still in the process of being open sourced from production code. Stay tuned!

## Installation

For now, clone this repo as a new project.

*TODO*: Make a generator for creating a skeleton.

## Configuration

Fill in the Cheffile with your desired cookbooks, populate the roles/ directory with roles, nodes with nodes, etc.

### Hosts.json

The `config/hosts.json` file is the master list of different types of instances that can be launched, as well as specific named instances that you'd like a separate configuration for. See `config/hosts.json.example`.

## Usage

### Kit

The main program for interaction is `kit`. It will create, list, and destroy running servers. 

`kit create\_instance sellstuff.com web` would create an instance using the web role defined in `roles/web.json`. It will be given a color, similar to how Heroku's database instance naming works. The first one created will probably be "sellstuff.com-web-red".

`kit list` will list all running instances.

`kit destroy sellstuff.com web red` will destroy our newly created server.

### Chairman

`chairman` is a tool for dispatching a single server to run a certain task and then destroy the server. This is useful for long-running batch jobs that need dedicated resources.

`chairman launch sellstuff.com importer` will spin up a new importer instance and then run a capistrano deploy script for the specified task, i.e. `cap sellstuff.com importer red`. Currently, the command to be run by capistrano sits in a switch block in config/deploy.rb, but this will change as this project is generalized.

`chairman exec sellstuff.com importer "rake import"` will execute a custom command, `rake import`, on a newly created instance.

`chairman build sellstuff.com importer` will build an instance from scratch, create an image of it, then update the base configuration for importer with the new image name. This will speed up future calles to `chairman launch`.

## Apologies

I apologize to those annoyed by the myriad chef puns-as-project-names and to the Food Network.
