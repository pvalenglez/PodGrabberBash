#!/bin/bash

# PodGrabber constants
CDATA_BEGIN="<![CDATA["
CDATA_END="]]>"
LIMIT_CHAPTERS=50
LESS_THAN="<"
GREATER_THAN=">"
COLON=":"
DOUBLE_QUOTE=\"
FORWARD_SLASH="/"
BACKSLASH="\\"
PIPE="|"
QUESTION_MARK="\?"
QUESTION_MARK_2="¿"
ASTERISK="\*"
DOT_MP3=".mp3"
KEYWORD_MIN_SIZE=3
SCRIPT_DIR=$(readlink -f ${0%/*})

# Keeps track of the text that is going to be sent as a notification
notification_body=""

#######################################
# Removes bullshit from chapter filenames
# Arguments:
#   $1 -> Chapter filename
#   $2 -> Keywords to remove
# Returns:
#   None
#######################################
sanitize_filename () {
    title=$1
    keywords=$2
    # Remove all podcast keywords that are longer than three characteres from
    # the chapter filename
    for keyword in ${keywords[@]}; do
        if [[ ${#keyword} -gt $KEYWORD_MIN_SIZE ]]; then
            title=${title//$keyword}
        fi
    done

    # Sanitize chapter filename to avoid trouble copying or saving it
	title=${title//"/"/" "}
	title=${title//"-"/" "}
    title=${title//"..."}
    title=${title//"."}
    title=${title//"("}
    title=${title//")"}
    title=${title//$LESS_THAN/" "}
    title=${title//$GREATER_THAN/" "}
    title=${title//$COLON/" "}
    title=${title//$DOUBLE_QUOTE/" "}
    title=${title//$FORWARD_SLASH/" "}
    title=${title//$BACKSLASH/" "}
    title=${title//$PIPE/" "}
    title=${title//$QUESTION_MARK/" "}
    title=${title//$QUESTION_MARK_2/" "}
    title=${title//$ASTERISK/" "}
    title=${title//"&quot"}
    title=${title//";"}
    title=${title//"'"}
    title=${title//"#"}
    title=${title//"—"}
    title=${title//"–"}
    title=$(echo $title | xargs -0)
    title=${title//" "/"."}
    title=${title//","}
    title=${title//".."}
    title=${title//"_"/"."}
}

# Create the podcasts folder in case it doesn't exist and cd to it
mkdir -pv podcasts
cd podcasts

# Read each line of the input file with the podcasts URLs
while read line; do

    # If the podcast is commented out, just skip it
    if [[ ${line:0:1} == '#' ]]; then
        continue;
    fi

    # Retrieve podcast title and remove CDATA tags
	title=$(wget -qO- $line | perl -l -0777 -ne 'print $1 if /<title.*?>\s*(.*?)\s*<\/title/si')
	title=$(echo ${title/$CDATA_BEGIN})
	title=$(echo ${title/$CDATA_END})
	notification_body="$notification_body\nObtaining new episodes from podcast:\""$title"\"\n"

    # Initialize list of keywords that are to be removed form chapter names
    podcast_keywords=($(echo "$title" | tr ',' '\n'))

    # Create the podcast folder in case it doesn't exist and cd to id
	mkdir -pv "$title"
	cd "$title"

    # Control variable in case of a new podcast to download a maximum number of 50 chapters
	chapter_counter=0

    # Fail if xml2 is not installed
    command -v xml2 >/dev/null 2>&1 || { echo >&2 "I require xml2 but it's not installed.  Aborting."; exit 1; }

	while read line ; do

        # If I've found a chapter title line then initialize it
		if [[ "$line" == *"/rss/channel/item/title"* ]]; then

			chapter_title=$(echo $line | cut -d "=" -f 2)
            sanitize_filename $chapter_title $podcast_keywords

		elif [[ "$line" == *"/rss/channel/item/enclosure/@url"* ]]; then

			chapter_counter=$(($chapter_counter+1))
			chapter_url=$(echo $line | cut -d "@" -f 2 | cut -d "=" -f 2)

            # If a file with the exact same filename exists, it means I've already downloaded it
            # If not then let's download it
			if [ -f "$chapter_title.ogg" ]; then
				echo "Skipping existing file.."
			else
				#wget -c $chapter_url -O "$chapter_title.mp3"
                notification_body="$notification_body\n$chapter_title.mp3"

				#filename=$chapter_title.mp3
				#ffmpeg -i "$filename" -q:a 0 -ac 1 "${filename/$DOT_MP3}.ogg" -nostdin
				#if [ $? -eq 0 ]; then
				#	touch -r "$filename" "${filename/$DOT_MP3}.ogg"
				#	rm -f "$filename";
				#fi
			fi
	    fi

        # If I've reached the chapter counter limit, stop looping
		if [[ "$chapter_counter" -gt $LIMIT_CHAPTERS ]]; then
			break;
		fi
    done <<< $(curl -s $line | xml2 | grep /rss/channel/item)

    notification_body="$notification_body\n\n"
	cd ..

done < $SCRIPT_DIR/input_podcasts.txt

current_date=$(date +'%d/%m/%Y')
printf "$notification_body" | mail -v -s "PodGrabber execution ($current_date)"  valeng.pablo@gmail.com
