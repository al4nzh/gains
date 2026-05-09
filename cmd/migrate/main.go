package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"

	"gainsai/internal/config"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	cmd := os.Args[1]

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	m, err := migrate.New("file://migrations", cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("migrate init: %v", err)
	}
	defer m.Close()

	switch cmd {
	case "up":
		if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
			log.Fatalf("up: %v", err)
		}
	case "down":
		if err := m.Down(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
			log.Fatalf("down: %v", err)
		}
	case "version":
		v, dirty, err := m.Version()
		if err != nil && !errors.Is(err, migrate.ErrNilVersion) {
			log.Fatalf("version: %v", err)
		}
		fmt.Printf("version=%d dirty=%v\n", v, dirty)
		return
	case "force":
		if len(os.Args) < 3 {
			log.Fatal("force requires a version number")
		}
		v, err := strconv.Atoi(os.Args[2])
		if err != nil {
			log.Fatalf("force: invalid version: %v", err)
		}
		if err := m.Force(v); err != nil {
			log.Fatalf("force: %v", err)
		}
	default:
		usage()
		os.Exit(1)
	}
	log.Println("done")
}

func usage() {
	fmt.Println("usage: migrate <up|down|version|force <n>>")
}
