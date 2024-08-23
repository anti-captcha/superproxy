#!/bin/bash

apt update
apt install -y docker.io apache2-utils

CURRENTDIR=$(pwd)

CONFIG_FILE="config.cfg"
NGINX_CONFIG=""
# MySQL connection details
MYSQL_USER="root"
MYSQL_PASSWORD="rootpassword"


die_with_error() {
  echo $1
  exit 1
}
# Function to prompt for configuration details and save to file
create_config() {
  echo "Config file not found. Let's create one."

  # Prompt the user, suggesting the current directory as the default
  read -p "Enter the path to your project directory [$CURRENTDIR]: " project_dir
  # If the user presses Enter without typing, use the current directory as the default
  project_dir=${project_dir:-$CURRENTDIR}

  read -p "Enter project's domain name: " domain
  echo ""
  echo "Enter new credentials to setup administrator account."
  read -p "Enter admin's email: " adminemail
  read -p "Enter admin's password: " adminpassword

  if ask_yes_no "Use SSL wildcard certificate?"; then
    usecertificate="y"

    ask_for_file "Certificate key path: " certificatekey
    ask_for_file "Certificate SSL bundle path: " certificatebundle

  else
    usecertificate="n"
    certificatekey=""
    certificatebundle=""
  fi

  # Save the variables to the config file
  echo "project_dir=\"$project_dir\"" > $CONFIG_FILE
  echo "domain=\"$domain\"" >> $CONFIG_FILE
  echo "adminemail=\"$adminemail\"" >> $CONFIG_FILE
  echo "adminpassword=\"$adminpassword\"" >> $CONFIG_FILE
  echo "usecertificate=\"$usecertificate\"" >> $CONFIG_FILE
  echo "certificatekey=\"$certificatekey\"" >> $CONFIG_FILE
  echo "certificatebundle=\"$certificatebundle\"" >> $CONFIG_FILE

  echo "Configuration saved to $CONFIG_FILE."
}

#!/bin/bash

# Function to ask for a file path and check if it exists
ask_for_file() {
  local question="$1"
  local __resultvar="$2"

  while true; do
    read -p "$question" file

    if [ -f "$file" ]; then
      echo "File exists: $file"
      absolute_path=$(realpath "$file")
      eval $__resultvar="'$absolute_path'"  # Assign the full file path to the provided variable
      break  # Exit the loop if the file exists
    else
      echo "File does not exist. Please try again."
    fi
  done
}

ask_yes_no() {
  while true; do
    read -p "$1 [y/n]: " yn
    case $yn in
        [Yy]* ) return 0;;  # If 'y' or 'Y' is entered, return success
        [Nn]* ) return 1;;  # If 'n' or 'N' is entered, return failure
        * ) echo "Please answer y or n.";;  # If invalid input, ask again
    esac
  done
}


write_nginx_config_no_ssl() {
  if [ -z "$NGINX_CONFIG" ]; then
    echo "The nginx config path is empty."
    exit 1
  fi
  cat <<EOL > "$NGINX_CONFIG"
user nginx;
worker_processes 16;
worker_rlimit_nofile  65536;

error_log  /var/log/nginx/error.log;

pid  /var/run/nginx.pid;


events {
    worker_connections  4024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log   /var/log/nginx/access.log;
    error_log    /var/log/nginx/error.log;

    sendfile     on;

    keepalive_timeout  15;
    client_body_timeout  15;
    client_header_timeout  15;
    client_max_body_size 30m;

    server {
        listen 80;
        server_name $domain;

        charset utf-8;

        location / {
            proxy_pass http://superproxy-frontend:3000;
        }

        location ~ ^/(api/) {
            proxy_pass http://superproxy-api:8000;
        }
    }


    server {

        listen 80;
        server_name api.$domain;

        charset utf-8;

        location / {
            proxy_pass http://superproxy-api:8000/taskapi/;
        }

    }


    server {
        listen 80;
        server_name *.$domain;
        return 301 https://$domain\$request_uri;
    }

}


EOL
   echo "wrote nginx config to $NGINX_CONFIG"
}

write_nginx_config_ssl() {
  if [ -z "$NGINX_CONFIG" ]; then
    echo "The nginx config path is empty."
    exit 1
  fi
  cat <<EOL > "$NGINX_CONFIG"
user nginx;
worker_processes 16;
worker_rlimit_nofile  65536;

error_log  /var/log/nginx/error.log;

pid  /var/run/nginx.pid;


events {
    worker_connections  4024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log   /var/log/nginx/access.log;
    error_log    /var/log/nginx/error.log;

    sendfile     on;

    keepalive_timeout  15;
    client_body_timeout  15;
    client_header_timeout  15;
    client_max_body_size 30m;

    server {
        listen 80 default_server;

        server_name _;

        return 301 https://$host\$request_uri;
    }

    server {

        listen [::]:443 ssl http2;
        listen 443 ssl;
        server_name $domain;

        ssl_certificate /etc/nginx/bundle.crt;
        ssl_certificate_key /etc/nginx/ssl.key;
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;

        charset utf-8;

        location / {
            proxy_pass http://superproxy-frontend:3000;
        }

        location ~ ^/(api/) {
            proxy_pass http://superproxy-api:8000;
        }

    }


    server {

        listen [::]:443 ssl http2;
        listen 443 ssl;
        server_name api.$domain;

        ssl_certificate /etc/nginx/bundle.crt;
        ssl_certificate_key /etc/nginx/ssl.key;
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;

        charset utf-8;

        location / {
            proxy_pass http://superproxy-api:8000/taskapi/;
        }

    }



    server {

        listen 80;
        server_name api.$domain;

        charset utf-8;

        location / {
            proxy_pass http://superproxy-api:8000/taskapi;
        }

    }

    server {

        listen [::]:443 ssl;
        listen 443 ssl;

        server_name *.$domain;
        return 301 https://$domain\$request_uri;

        ssl_certificate /etc/nginx/bundle.crt;
        ssl_certificate_key /etc/nginx/ssl.key;
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
    }

}
EOL
   echo "wrote nginx config to $NGINX_CONFIG"
}

# Check if config file exists
if [ -f $CONFIG_FILE ]; then
  # Load the variables from the config file
  source $CONFIG_FILE
  echo "Config file found. Loaded configuration."
else
  # Create the config file by asking the user for input
  create_config
fi

if [ -z "$project_dir" ]; then
  echo "The project directory variable is empty."
  create_config
fi

# Further script actions can use the loaded or created variables
echo "Running script with the following configuration:"
echo "Project Directory: $project_dir"
echo "Email: $adminemail"
echo "Password: $adminpassword"
echo "Use SSL: $usecertificate"
echo "Certificate bundle: $certificatebundle"
echo "Certificate key: $certificatekey"
hashed_password=$(htpasswd -bnBC 10 "" "$adminpassword" | tr -d ':\n')

if [ -d "$project_dir" ]; then
  echo "Directory $project_dir exists"
else
  echo "ERROR: Directory $project_dir does not exist"
  exit 1
fi


# Writing NGINX config
mkdir -p "$project_dir/nginx"
NGINX_CONFIG="$project_dir/nginx/nginx.conf"
if [ "$usecertificate" = "y" ]; then

  # Validating certicate

  # Check if the supposed private key actually contains a private key
  if ! grep -q "BEGIN .*PRIVATE KEY" "$certificatekey"; then
      echo "ERROR: The file $certificatekey does not appear to be a private key."
      echo "Possible cause: The files are swapped or the wrong file was provided."
      exit 1
  fi

  # Check if the supposed certificate actually contains a certificate
  if ! grep -q "BEGIN CERTIFICATE" "$certificatebundle"; then
      echo "ERROR: The file $certificatebundle does not appear to be a certificate."
      echo "Possible cause: The files are swapped or the wrong file was provided."
      exit 1
  fi

  # Extract and compare the modulus of the key and certificate
  key_modulus=$(openssl rsa -noout -modulus -in "$certificatekey" 2>/dev/null | openssl md5)
  cert_modulus=$(openssl x509 -noout -modulus -in "$certificatebundle" 2>/dev/null | openssl md5)

  # Compare the moduli
  if [ "$key_modulus" == "$cert_modulus" ]; then
      echo "The private key and certificate match."
  else
      echo "ERROR: The private key and/or certificate are invalid."
      exit 1
  fi

  nginxports="-p 80:80 -p 443:443"
  cp -f $certificatebundle "$project_dir/nginx/bundle.crt"
  cp -f $certificatekey "$project_dir/nginx/ssl.crt"
cat <<EOL > "$project_dir/nginx/Dockerfile"
FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY bundle.crt /etc/nginx/bundle.crt
COPY ssl.crt /etc/nginx/ssl.key

EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
EOL
  write_nginx_config_ssl
else
  nginxports="-p 80:80"
  cat <<EOL > "$project_dir/nginx/Dockerfile"
FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOL
  write_nginx_config_no_ssl
fi

# Checking Docker network
if ! docker network ls --format "{{.Name}}" | grep -q "^superproxy$"; then
  echo "Docker network 'superproxy' does not exist. Creating it..."
  docker network create superproxy
else
  echo "Docker network superproxy already exists."
fi

# Starting MySQL container, ensuring database and admin user
if [ "$(docker ps -a -q -f name=^/superproxy-mysql)" ]; then
    echo "Container superproxy-mysql exists."
else
    echo "Container superproxy-mysql does not exist. Starting mysql..."
    docker run -d --rm --name=superproxy-mysql --network superproxy \
      -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
      -e MYSQL_DATABASE=dbname \
      -e MYSQL_USER=$MYSQL_USER \
      -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
      -v $project_dir/mysql:/var/lib/mysql \
    anticaptcha/superproxy-mysql
fi
until docker exec -i superproxy-mysql mysqladmin ping -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
  echo "Waiting for MySQL container to be ready..."
  sleep 2
done

docker exec -i superproxy-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D dbname -se "CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key(id),
    email VARCHAR(255),
    password_hash VARCHAR(255),
    apikey VARCHAR(255),
    money DECIMAL(20, 5) default 0,
    regdate INT UNSIGNED default 0,
    is_frozen tinyint unsigned default 0,
    is_admin tinyint unsigned default 0
);"
user_exists=$(docker exec -i superproxy-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D dbname -se "SELECT COUNT(*) FROM users WHERE email='$adminemail';")



if [ "$user_exists" -eq 0 ]; then
  echo "User with email $adminemail does not exist. Inserting user..."
  # Insert the user
  random_string=$(head -c 256 /dev/urandom | base64)
  apikey=$(echo $random_string | md5sum | awk '{print $1}')
  utc_seconds=$(date -u +%s)
  docker exec -i superproxy-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D dbname -e "INSERT INTO users (email, password_hash, apikey, money, regdate, is_frozen,is_admin) VALUES ('$adminemail', '$hashed_password','$apikey',0,'$utc_seconds',0,1);"
  echo "Admin user inserted successfully."
else
  echo "Admin user with email $adminemail already exists."
fi

# Starting backend container
if [ "$(docker ps -a -q -f name=^/superproxy-api)" ]; then
    echo "Container superproxy-api exists."
else
  mkdir -p "$project_dir/configs"
  docker pull anticaptcha/superproxy-backend:latest
  docker run --rm -d --name=superproxy-api --network superproxy \
   -e DB_HOST=superproxy-mysql \
   -e DB_PORT=3306 \
   -e DB_USER=$MYSQL_USER \
   -e DB_PASSWORD=$MYSQL_PASSWORD \
   -e DB_NAME=dbname \
   -v $project_dir/configs:/app/configs \
   anticaptcha/superproxy-backend:latest || die_with_error "Could not start superproxy-backend"
fi

# Starting frontend container
if [ "$(docker ps -a -q -f name=^/superproxy-frontend)" ]; then
    echo "Container superproxy-frontend exists."
else
  docker pull anticaptcha/superproxy-frontend:latest
  docker run --rm -d --name=superproxy-frontend --network superproxy anticaptcha/superproxy-frontend:latest || die_with_error "Could not start superproxy-frontend"
fi

if [ "$(docker ps -a -q -f name=^/superproxy-nginx)" ]; then
  echo "Container superproxy-nginx exists."
else
  # Building NGINX image
  cd "$project_dir/nginx"
  docker build -t superproxy-nginx . || die_with_error "Could not build nginx"

  # Starting main NGINX server
  docker run --name superproxy-nginx --network superproxy -d --rm \
   $nginxports \
   superproxy-nginx || die_with_error "Could not start NGINX"
fi


cat <<EOL > "$project_dir/update.sh"
docker stop superproxy-api superproxy-frontend superproxy-nginx
source start.sh
EOL
chmod a+x "$project_dir/update.sh"
echo ""
echo "Superproxy successfully started"
echo ""
echo "To update the project run $project_dir/update.sh"
