#!/bin/bash

# Create directories if they don't exist
mkdir -p /var/log /var/secure

# File path and log file
file="/mnt/c/Users/USER/file.txt"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Function to generate a random password
generate_password() {
    local length="${1:-12}"
    < /dev/urandom tr -dc A-Za-z0-9 | head -c"$length"
}

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Loop through each line in the file
while IFS=';' read -r username groups_str; do
    # Trim leading/trailing whitespace from username and groups
    username=$(echo "$username" | tr -d '[:space:]')
    groups_str=$(echo "$groups_str" | tr -d '[:space:]')

    # Create user if it doesn't exist
    if ! id "$username" &>/dev/null; then
        # Create personal group for the user
        if groupadd "$username" &>> "$log_file"; then
            log_message "Group $username created successfully."
        else
            log_message "Failed to create group $username."
            echo "Failed to create group $username" >&2
            continue
        fi
        
        # Create user with home directory and personal group
        if useradd -m -s /bin/bash -g "$username" "$username" &>> "$log_file"; then
            log_message "User $username created successfully."
        else
            log_message "Failed to create user $username."
            echo "Failed to create user $username" >&2
            continue
        fi
        
        # Set initial password for the user
        password=$(generate_password)
        if echo "$username:$password" | chpasswd &>> "$log_file"; then
            log_message "Password for $username set successfully."
        else
            log_message "Failed to set password for $username."
            echo "Failed to set password for $username" >&2
        fi
        
        # Log password securely
        echo "$username:$password" >> "$password_file"

        # Set permissions on home directory
        if chmod 700 "/home/$username" &>> "$log_file" && chown -R "$username:$username" "/home/$username" &>> "$log_file"; then
            log_message "Permissions set for /home/$username."
        else
            log_message "Failed to set permissions for /home/$username."
            echo "Failed to set permissions for /home/$username" >&2
        fi
    else
        log_message "User $username already exists, skipping creation."
        echo "User $username already exists, skipping creation."
    fi

    # Create additional groups if specified
    IFS=',' read -ra groups <<< "$groups_str"
    for group in "${groups[@]}"; do
        # Create group if it doesn't exist
        if ! grep -q "^$group:" /etc/group; then
            if groupadd "$group" &>> "$log_file"; then
                log_message "Group $group created successfully."
                echo "Group $group created successfully."
            else
                log_message "Failed to create group $group."
                echo "Failed to create group $group" >&2
                continue
            fi
        fi

        # Add user to group
        if usermod -aG "$group" "$username" &>> "$log_file"; then
            log_message "User $username added to group $group."
        else
            log_message "Failed to add $username to group $group."
            echo "Failed to add $username to group $group" >&2
        fi
    done
done < "$file"

# Log completion
log_message "Script completed."
