#!/bin/bash

# Funzione per eseguire la build delle immagini Docker
build_images() {
  echo "Building images..."
  
  # Costruisci l'immagine per i PC
  docker build -t manzolo/ubuntu-network-playground-pc:latest -f images/ubuntu-network-playground-pc/Dockerfile .
  if [ $? -eq 0 ]; then
    echo "Image 'manzolo/ubuntu-network-playground-pc:latest' built successfully."
  else
    echo "Failed to build 'manzolo/ubuntu-network-playground-pc:latest'."
    exit 1
  fi

  # Costruisci l'immagine per i router
  docker build -t manzolo/ubuntu-network-playground-router:latest -f images/ubuntu-network-playground-router/Dockerfile .
  if [ $? -eq 0 ]; then
    echo "Image 'manzolo/ubuntu-network-playground-router:latest' built successfully."
  else
    echo "Failed to build 'manzolo/ubuntu-network-playground-router:latest'."
    exit 1
  fi

  # Costruisci l'immagine per il server web
  docker build -t manzolo/ubuntu-network-playground-webserver:latest -f images/ubuntu-network-playground-webserver/Dockerfile .
  if [ $? -eq 0 ]; then
    echo "Image 'manzolo/ubuntu-network-playground-webserver:latest' built successfully."
  else
    echo "Failed to build 'manzolo/ubuntu-network-playground-webserver:latest'."
    exit 1
  fi

  echo "All images built successfully."
}

# Funzione per eseguire il run con Docker Compose
run_compose() {
  echo "Running Docker Compose..."
  docker compose down && docker compose rm -f && docker compose up -d
}

# Funzione per fermare Docker Compose
stop_compose() {
  echo "Running Docker Compose..."
  docker compose down && docker compose rm -f
}

# Funzione per vedere i log di Docker Compose
show_compose_logs() {
  echo "Show Docker Compose logs..."
  docker compose logs -f
}



# Funzione per entrare in un container
enter_container() {
  local container_name=$1
  echo "Entering container: $container_name"
  docker exec -it $container_name /bin/bash
}

# Menu principale
while true; do
  echo "-----------------------------"
  echo "Docker Network Playground Menu"
  echo "-----------------------------"
  echo "b. Build Images"
  echo "r. Run Docker Compose"
  echo "l. Show Compose Logs"
  echo "s. Stop Compose Logs"
  echo "pc1. Enter PC1"
  echo "pc2. Enter PC2"
  echo "pc3. Enter PC3"
  echo "pc4. Enter PC4"
  echo "pc5. Enter PC5"
  echo "r1. Enter Router1"
  echo "r2. Enter Router2"
  echo "r3. Enter Router3"
  echo "sw. Enter Server Web"
  echo "x. Exit"
  echo "-----------------------------"
  read -p "Choose an option: " choice

  case $choice in
    b)
      build_images
      ;;
    r)
      run_compose
      ;;
    l)
      show_compose_logs
      ;;
    s)
      stop_compose
      ;;
    pc1)
      enter_container "pc1"
      ;;
    pc2)
      enter_container "pc2"
      ;;
    pc3)
      enter_container "pc3"
      ;;
    pc4)
      enter_container "pc4"
      ;;
    pc5)
      enter_container "pc5"
      ;;
    r1)
      enter_container "router1"
      ;;
    r2)
      enter_container "router2"
      ;;
    r3)
      enter_container "router3"
      ;;
    sw)
      enter_container "server_web"
      ;;
    x)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid option. Please choose a valid option."
      ;;
  esac
done