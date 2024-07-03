#!/bin/bash

mkdir -p /var/log /var/secure

file="/mnt/c/Users/USER/file.txt"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

generate_password() {
    local length="${1:-12}"
    < /dev/urandom tr -dc A-Za-z0-9 | head -c"$length"
}

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

while IFS=';' read -r username groups_str; do
    username=$(echo "$username" | tr -d '[:space:]')
    groups_str=$(echo "$groups_str" | tr -d '[:space:]')

    if ! id "$username" &>/dev/null; then
        if groupadd "$username" &>> "$log_file"; then
            log_message "Group $username created successfully."
        else
            log_message "Failed to create group $username."
            echo "Failed to create group $username" >&2
            continue
        fi
        
        if useradd -m -s /bin/bash -g "$username" "$username" &>> "$log_file"; then
            log_message "User $username created successfully."
        else
            log_message "Failed to create user $username."
            echo "Failed to create user $username" >&2
            continue
        fi
        
        password=$(generate_password)
        if echo "$username:$password" | chpasswd &>> "$log_file"; then
            log_message "Password for $username set successfully."
        else
            log_message "Failed to set password for $username."
            echo "Failed to set password for $username" >&2
        fi
        
        echo "$username:$password" >> "$password_file"

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

    IFS=',' read -ra groups <<< "$groups_str"
    for group in "${groups[@]}"; do
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

        if usermod -aG "$group" "$username" &>> "$log_file"; then
            log_message "User $username added to group $group."
        else
            log_message "Failed to add $username to group $group."
            echo "Failed to add $username to group $group" >&2
        fi
    done
done < "$file"

log_message "Script completed."
