#!/bin/bash

CONFIG_DIR="/etc/dockssh.d"

# Function to handle port mapping using iptables
map_ports() {
    config_file=$1

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        if [[ "$line" =~ ^\[.*\]$ ]]; then
            container_name=$(echo "$line" | tr -d '[]')
            container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name")
        else
            host_port=$(echo "$line" | cut -d':' -f1)
            container_port=$(echo "$line" | cut -d':' -f2)

            # Check if rule already exists
            if ! sudo iptables -t nat -C DOCKER -p tcp --dport "$host_port" -j DNAT --to-destination "$container_ip:$container_port" 2>/dev/null; then
                # Add new iptables rule if it doesn't exist
                sudo iptables -t nat -A DOCKER -p tcp --dport "$host_port" -j DNAT --to-destination "$container_ip:$container_port"
                echo "Added new port mapping: $host_port -> $container_ip:$container_port"
            else
                echo "Port mapping already exists: $host_port -> $container_ip:$container_port"
            fi
        fi
    done < "$config_file"
}

# Monitor the configuration directory for changes
inotifywait -m -e modify --format '%w%f' "$CONFIG_DIR" | while read -r config_file; do
    map_ports "$config_file"
done

