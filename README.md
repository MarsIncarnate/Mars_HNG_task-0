# Mars_HNG_task-0
Repository for the Linux User Creation Bash Script task

## LINUX USER CREATION BASH SCRIPT
As part of the requirement for the [HNG11 internship program](https://hng.tech/internship) at [HNG](https://hng.tech/premium), I have been tasked with the assignment to create a linux user creation script that takes the location of a text file containing Users and their respective groups on a Ubuntu machine, creates the users with their groups, creates randomly generated passwords and stores them securely, and logs all the action to /var/log/user_management.log.

**This article explains each step taken in this solution and the reasoning behind it**

### Script Overview

The script expects a text file with each line formatted as username;groups, where multiple groups are separated by commas. The script handles the following tasks:

1. Checks the provided argument.
2. Reads the text file line by line.
3. Creates users and their personal groups.
4. Adds users to additional specified groups.
5. Generates and sets random passwords for users.
6. Logs all actions.
7. Secures the generated passwords.

## Detailed Explanation

### Argument Check

```bash 
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi
```

- Purpose: Ensure the script receives exactly one argument.
- Explanation: The script checks the number of arguments provided. If not exactly one, it prints a usage message and exits. This prevents errors from running the script without the necessary input.

### File Paths

```bash
file="$1"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.csv"
```
- Purpose: Define file paths for the input text file, log file, and password file.
- Explanation: file stores the path to the input text file provided as an argument. log_file and password_file are predefined paths for logging actions and storing passwords.

### Directory and File Setup
```bash
sudo mkdir -p /var/log /var/secure
sudo touch "$log_file"
sudo touch "$password_file"
sudo chmod 600 "$password_file"
```
- Purpose: Ensure necessary directories and files exist with correct permissions.
- Explanation: The script creates the directories /var/log and /var/secure if they do not exist. It also creates the log and password files and sets the password file’s permissions to 600 (read and write for the owner only).

### Password Generation Function
```bash
generate_password() {
    local length="${1:-12}"
    < /dev/urandom tr -dc A-Za-z0-9 | head -c"$length"
}
```
- Purpose: Generate random passwords.
- Explanation: This function generates a random password of a specified length (default is 12 characters) using /dev/urandom, a cryptographic random number generator.

### Logging Function
```bash
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | sudo tee -a "$log_file" > /dev/null
}
```
- Purpose: Log messages with timestamps.
- Explanation: This function logs messages to the log file with a timestamp. It uses sudo tee -a to append messages to the log file and > /dev/null to suppress the command's output.

### Reading the Input File
```bash
while IFS=';' read -r username groups_str; do
```
- Purpose: Read the input file line by line.
- Explanation: The script reads each line of the input file, splitting it into username and groups_str using ; as the delimiter.

### Trimming Whitespace
```bash
    username=$(echo "$username" | tr -d '[:space:]')
    groups_str=$(echo "$groups_str" | tr -d '[:space:]')
```
- Purpose: Remove any leading or trailing whitespace.
- Explanation: The script uses tr -d '[:space:]' to remove all whitespace characters from username and groups_str.

### User Existence Check
```bash
    if ! id "$username" &>/dev/null; then
```
- Purpose: Check if the user already exists.
- Explanation: The script uses id "$username" &>/dev/null to check if the user exists. If the user does not exist, it proceeds to create the user.

### Creating User and Personal Group
```bash
        if sudo groupadd "$username" &>> "$log_file"; then
            log_message "Group $username created successfully."
        else
            log_message "Failed to create group $username."
            echo "Failed to create group $username" >&2
            continue
        fi
```
- Purpose: Create a personal group for the user.
- Explanation: The script attempts to create a group with the username. On success, it logs a success message. On failure, it logs an error message and skips to the next line.

```bash
        if sudo useradd -m -s /bin/bash -g "$username" "$username" &>> "$log_file"; then
            log_message "User $username created successfully."
        else
            log_message "Failed to create user $username."
            echo "Failed to create user $username" >&2
            continue
        fi
```
- Purpose: Create the user and assign them to their personal group.
- Explanation: The script creates the user with a home directory and assigns them to their personal group. It logs success or error messages accordingly.

### Setting Initial Password
```bash
        password=$(generate_password)
        if echo "$username:$password" | sudo chpasswd &>> "$log_file"; then
            log_message "Password for $username set successfully."
        else
            log_message "Failed to set password for $username."
            echo "Failed to set password for $username" >&2
        fi
```
- Purpose: Set an initial random password for the user.
- Explanation: The script generates a random password and sets it for the user using chpasswd. It logs success or error messages.

### Logging Password Securely
```bash
        echo "$username,$password" | sudo tee -a "$password_file" > /dev/null
```
- Purpose: Store the password securely.
- Explanation: The script appends the username and password to the password file using sudo tee -a and > /dev/null to suppress the output.

### Setting Home Directory Permissions
```bash
        if sudo chmod 700 "/home/$username" &>> "$log_file" && sudo chown -R "$username:$username" "/home/$username" &>> "$log_file"; then
            log_message "Permissions set for /home/$username."
        else
            log_message "Failed to set permissions for /home/$username."
            echo "Failed to set permissions for /home/$username" >&2
        fi
```
- Purpose: Set appropriate permissions for the user's home directory.
- Explanation: The script sets the home directory permissions to 700 (owner can read, write, and execute) and changes ownership to the user. It logs success or error messages.

### Handling Existing Users
```bash
    else
        log_message "User $username already exists, skipping creation."
        echo "User $username already exists, skipping creation."
    fi
```
- Purpose: Log and skip existing users.
- Explanation: If the user already exists, the script logs this information and skips to the next line.

### Creating Additional Groups and Adding Users
```bash
    IFS=',' read -ra groups <<< "$groups_str"
    for group in "${groups[@]}"; do
        if ! grep -q "^$group:" /etc/group; then
            if sudo groupadd "$group" &>> "$log_file"; then
                log_message "Group $group created successfully."
                echo "Group $group created successfully."
            else
                log_message "Failed to create group $group."
                echo "Failed to create group $group" >&2
                continue
            fi
        fi
        if sudo usermod -aG "$group" "$username" &>> "$log_file"; then
            log_message "User $username added to group $group."
        else
            log_message "Failed to add $username to group $group."
            echo "Failed to add $username to group $group" >&2
        fi
    done
done < "$file"
```
- Purpose: Create additional groups and add users to them.
- Explanation: The script reads the groups string, splits it into an array of groups, and processes each group. If a group doesn’t exist, it creates the group. Then, it adds the user to each group and logs the actions.

### Logging Script Completion
```bash
log_message "Script completed."
```
- Purpose: Log the completion of the script.
- Explanation: At the end of the script, it logs a message indicating the script has completed its execution.

## Conclusion

This Linux User Creation Bash script makes it possible to automate user and group creation, password management, and logging. It ensures that users are created with secure passwords, appropriate permissions, and logs all actions for audit purposes. Developing it as a part of the [HNG11](https://hng.tech/premium) requirement, is a good exercise t sharpen scripting and process automation skills. For any further questions please contact [me](www.linkedin.com/in/marvellous-adeogun-4a4550216)