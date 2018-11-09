#! /bin/bash

#This script prepares rstudio container before start. 


function processTuple {
	#$1 - LOCAL_FOLDER, $2 - BUCKET_SUBFOLDER, $3 - DATA_FOLDER, $4 - BUCKET_NAME
    NEW_FOLDER="$3/$1";
    mkdir -p "$NEW_FOLDER";
    aws s3 sync --region eu-central-1 s3://"$4"/"$2" "$NEW_FOLDER";
    return 0;
}

function checkArgs {
	if [ -z "$MAPPINGS" ]; then
		echo "MAPPINGS parameter was not set when running 'docker run'! Terminating the startup!";
		exit 1;
	fi
	if [ -z "$USER" ]; then
		echo "USER parameter was not set when running 'docker run'! Terminating the startup!";
		exit 1;
	fi
	if [ -z "$BUCKET_NAME" ]; then
		echo "BUCKET_NAME parameter was not set when running 'docker run'! Terminating the startup!";
		exit 1;
	fi
	if [ -z "$AWS_ACCESS_KEY_ID" ]; then
		echo "AWS_ACCESS_KEY_ID env variable was not set. Terminating the startup!";
		exit 1;
	fi
	if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
		echo "AWS_SECRET_ACCESS_KEY env variable was not set. Terminating the startup!";
		exit 1;	
	fi
}

checkArgs;

DATA_FOLDER="/home/$USER/Roaming";
MAPPING_FILE="/root/.mappings";
mkdir -p "$DATA_FOLDER";

#erase all potential content, if the file existed
> "$MAPPING_FILE";

#process <local_directory_name>:<bucket_subfolder> tuples in MAPPINGS variable
for TUPLE in $(IFS=';'; echo $MAPPINGS); do
    TOKENS=(${TUPLE//:/ });

    if [ ${#TOKENS[@]} != 2 ]; then
        echo "Invalid pair localDir:bucketSubfolder !";
        exit 1;
    fi

    LOCAL_FOLDER=${TOKENS[0]};
    BUCKET_SUBFOLDER=${TOKENS[1]};

	#check local folder name contains only permitted characters
    if ! [[ "$LOCAL_FOLDER" =~ ^([A-Za-z0-9_.-])+$ ]]; then
        echo "Local folder name $LOCAL_FOLDER contains character(s) which is/are not permitted!";
        exit 1;
    fi

	#append mapping to mapping file
	echo "$DATA_FOLDER/$LOCAL_FOLDER:$BUCKET_NAME/$BUCKET_SUBFOLDER" >> "$MAPPING_FILE";
	
	#create a directory in /home/<USER>/Roaming with the name LOCAL_FOLDER and fill it with contents from mapped S3 bucket subfolder
	processTuple "$LOCAL_FOLDER" "$BUCKET_SUBFOLDER" "$DATA_FOLDER" "$BUCKET_NAME";
done

#File appends if the appended lines do not already exist
if [ -z $(cat /etc/sudoers | grep " localhost = (root) NOPASSWD: /root/rstudio-docker-sources/sync-mappings-up") ]; then
	echo "$USER localhost = (root) NOPASSWD: /root/rstudio-docker-sources/sync-mappings-up" >> /etc/sudoers;
fi
if [ -z $(cat /etc/sudoers | grep " ALL = NOPASSWD:SETENV /root/rstudio-docker-sources/sync-mappings-up") ]; then
	echo "$USER ALL = NOPASSWD:SETENV /root/rstudio-docker-sources/sync-mappings-up" >> /etc/sudoers;
fi
if [ -z $(cat /etc/sudoers | grep " localhost = (root) NOPASSWD: /root/rstudio-docker-sources/sync-mappings-down") ]; then
	echo "$USER localhost = (root) NOPASSWD: /root/rstudio-docker-sources/sync-mappings-down" >> /etc/sudoers;
fi
if [ -z $(cat /etc/sudoers | grep " ALL = NOPASSWD:SETENV /root/rstudio-docker-sources/sync-mappings-down") ]; then
	echo "$USER ALL = NOPASSWD:SETENV /root/rstudio-docker-sources/sync-mappings-down" >> /etc/sudoers;
fi
touch "/home/$USER/.profile";
if [ -z $(cat "/home/$USER/.profile" | grep 'alias sync-up="sudo /root/rstudio-docker-sources/sync-mappings-up"') ]; then
	echo 'alias sync-up="sudo -E /root/rstudio-docker-sources/sync-mappings-up"' >> "/home/$USER/.profile";
	source "/home/$USER/.profile";
fi
if [ -z $(cat "/home/$USER/.profile" | grep 'alias sync-down="sudo /root/rstudio-docker-sources/sync-mappings-down"') ]; then
	echo 'alias sync-down="sudo -E /root/rstudio-docker-sources/sync-mappings-down"' >> "/home/$USER/.profile";
	source "/home/$USER/.profile";
fi

#start the normal rstudio container init
/init

