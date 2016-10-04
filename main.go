package main

import (
  "fmt"
  "log"
  //"os/exec"
  "gopkg.in/yaml.v2"
)

var data = `
composer:
  install:
    help: Install Composer dependencies.
    command: docker-compose -f docker-compose.yml -f docker-utils.yml run composer install
  update:
    help: Update Composer dependencies.
    command: docker-compose -f docker-compose.yml -f docker-utils.yml run composer update
`

type Command struct {
  name string
  help string
  command string
}

func main() {
  var commands []*Command

  dict := make(map[interface{}]interface{})
  err := yaml.Unmarshal([]byte(data), &dict)
  if err != nil {
    log.Fatalf("error: %v", err)
  }

  for i, _ := range dict {
    if commandName, ok := i.(string); ok {
      for j, _ := range dict[commandName].(map[interface{}]interface{}) {
        if subcommandName, ok := j.(string); ok {
          commands = append(commands, &Command{name:commandName + " " + subcommandName})
        }
      }
    }
  }

  for _, c := range commands {
    fmt.Printf("name: %s\nhelp: %s\ncommand: %s\n", c.name, c.help, c.command)
  }

  //composer := m["composer"].(map[interface{}]interface{})
  //fmt.Printf("%v\n", composer["install"])
}
