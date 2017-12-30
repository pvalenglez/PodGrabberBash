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
	echo "Obtaining new episodes from podcast:\""$title"\""

    # Initialize list of keywords that are to be removed form chapter names
    podcast_keywords=($(echo "$title" | tr ',' '\n'))

    # Create the podcast folder in case it doesn't exist and cd to id
	mkdir -pv "$title"
	cd "$title"

    # Control variable in case of a new podcast to download a maximum number of 50 chapters
	chapter_counter=0
    # TODO fail if xml2 is not installed
	curl -s $line | xml2 | grep /rss/channel/item | while read line ; do

        # If I've found a chapter title line then initialize it
		if [[ "$line" == *"/rss/channel/item/title"* ]]; then

			chapter_title=$(echo $line | cut -d "=" -f 2)

            # Remove all podcast keywords that are longer than three characteres from
            # the chapter filename
            for keyword in ${podcast_keywords[@]}; do
                if [[ ${#keyword} -gt $KEYWORD_MIN_SIZE ]]; then
                    chapter_title=${chapter_title//$keyword}
                fi
            done

            # Sanitize chapter filename to avoid trouble copying or saving it
			chapter_title=${chapter_title//"/"/" "}
			chapter_title=${chapter_title//"-"/" "}
            chapter_title=${chapter_title//"..."}
            chapter_title=${chapter_title//"."}
            chapter_title=${chapter_title//"("}
            chapter_title=${chapter_title//")"}
            chapter_title=${chapter_title//$LESS_THAN/" "}
            chapter_title=${chapter_title//$GREATER_THAN/" "}
            chapter_title=${chapter_title//$COLON/" "}
            chapter_title=${chapter_title//$DOUBLE_QUOTE/" "}
            chapter_title=${chapter_title//$FORWARD_SLASH/" "}
            chapter_title=${chapter_title//$BACKSLASH/" "}
            chapter_title=${chapter_title//$PIPE/" "}
            chapter_title=${chapter_title//$QUESTION_MARK/" "}
            chapter_title=${chapter_title//$QUESTION_MARK_2/" "}
            chapter_title=${chapter_title//$ASTERISK/" "}
            chapter_title=${chapter_title//"&quot"}
            chapter_title=${chapter_title//";"}
            chapter_title=${chapter_title//"'"}
            chapter_title=${chapter_title//"#"}
            chapter_title=${chapter_title//"—"}
            chapter_title=${chapter_title//"–"}
            chapter_title=$(echo $chapter_title | xargs -0)
            chapter_title=${chapter_title//" "/"."}
            chapter_title=${chapter_title//","}
            chapter_title=${chapter_title//".."}
            chapter_title=${chapter_title//"_"/"."}
			echo "Título del capítulo:" $chapter_title

		elif [[ "$line" == *"/rss/channel/item/enclosure/@url"* ]]; then

			chapter_counter=$(($chapter_counter+1))
			chapter_url=$(echo $line | cut -d "@" -f 2 | cut -d "=" -f 2)

            # If a file with the exact same filename exists, it means I've already downloaded it
            # If not then let's download it
			if [ -f "$chapter_title.mp3" ]; then
				echo "Skipping existing file.."
			else
				#wget -c $chapter_url -O "$chapter_title.mp3"
                echo "$chapter_title.mp3"
                : '
				filename=$chapter_title.mp3

				if ffprobe "$filename" 2>&1 | grep stereo; then
					ffmpeg -i "$filename" -codec:a libmp3lame -q:a 9 -ac 1 "${filename/$DOT_MP3}_conv.mp3" -nostdin
					if [ $? -eq 0 ]; then
						touch -r "$filename" "${filename/$DOT_MP3}_conv.mp3"
						rm -f "$filename";
						mv "${filename/$DOT_MP3}_conv.mp3" "$filename"
					fi
				fi
                '
			fi
	    fi

        # If I've reached the chapter counter limit, stop looping
		if [[ "$chapter_counter" -gt $LIMIT_CHAPTERS ]]; then
			break;
		fi
	done

	cd ..

done < /media/NASDRIVE/podgrab/input_podcasts.txt
