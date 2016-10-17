package main

import logger "log"
import "os"

var log = createLogger()

func createLogger() *logger.Logger {
  return logger.New(os.Stderr, "[runx] ", 0)
}
