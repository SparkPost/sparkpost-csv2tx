#!/bin/bash
# Author: Benjamin Dean
#
# Params:
    # 1. path/to/file.csv           - MUST contain a field named "recipient_email_address", all other fields are ignored currently
    # 2. sparkPostApiKey            - Optional, defaults to empty string
    # 3. sparkPostRecipientListName - Optional, defaults to empty string
    # 4. sparkPostRecipientListDesc - Optional, defaults to empty string 
    # 5. sparkPostTemplateID        - Optional, defaults to empty string
    # 6. transmissionReturnPath     - Optional, defaults to empty string. Required if sending a transmission
    # 7. recipient_list_id          - Optional, defaults to empty string. Required if trying to override a recipient list (TODO)
    # 8. csvFieldDelimeter          - Optional, defaults to comma 
#
# TODO LIST
    # NEED TO BE ABLE TO APPEND RECIPIENTS TO EXISTING LISTS
    # NEED TO PROVIDE INTERACTIVE SHELL TO MAP THE OPTIONAL HEADERS TO APPROPRIATE REQUEST PROPERTIES
    # NEED TO SUPPORT SEMI-COLON AS LINE BREAKS
    # NEED TO SUPPORT NEWLINE CHARACTERS IN CELLS
#
# Assumptions
# - dos2unix and unix2dos are installed and available in PATH
# - first line is a header row.
# - header row must contain a field named "recipient_email_address" used as Recipient object "address" property
# - Unescaped quotes within cells are tolerated, and escaped.
#

# WORKAROUND FOR OLD/NEW MAC OSX AND NEWLINES
if [ "`echo -n`" = "-n" ]; then
    n="";
    c="\c";
else
    n="-n";
    c="";
fi

######################
# ON TO THE SCRIPT
######################

# Set options to zero-length strings if not provided
function optionProvided() {
    if [ -n $1 ]; then
        echo $1;
    else
        echo '';
    fi
}

# Named parameters from CLI options
SOURCE_CSV=$(optionProvided $1);
API_KEY=$(optionProvided $2);
RECIPIENT_LIST_NAME=$(optionProvided $3);
RECIPIENT_LIST_DESCRIPTION=$(optionProvided $4);
TEMPLATE_ID=$(optionProvided $5);
RETURN_PATH=$(optionProvided $6);
RECIPIENT_LIST_ID=$(optionProvided $7);
DELIMITER=$(optionProvided $8);

# Make sure we default the delimiter to a comma
[ "$DELIMITER" == '' ] && DELIMITER=',';

# VARIABLES
INVALIDATED_HEADER_ROW=; # The first row must be the header row and if it passes invalidation, this variable is populated
RECIPIENT_LIST=;

# Hold on to the original IFS value.
OIFS=$IFS;

# Validate the header and return (via `echo`) it's length.
function count_header_cols(){
  local COLS=0

  IFS=$DELIMITER;
  # We are referencing the first param sent to this function NOT the SOURCE_CSV
  for COL in $1; do
    COLS=$(($COLS+1));
  done;
  echo $COLS;
}

# Return (via `echo`) string name for the attribute
# @param index.
# @param attribute row
function get_attribute() {
  local INDEX=$1;

  IFS=$DELIMITER;
  for COL in $2; do
    if [ $INDEX == '0' ]; then
      # Should we escape the field name or not?
      if [ ${COL:0:1} == '"' -a ${COL:$((${#FOO}-1)):1} == '"' ]; then
        echo "$COL";
      else
        echo "\"$COL\"";
      fi
      return 0;
    fi
    # Decrement the field counter parameter passed into the function
    INDEX=$((INDEX-1));
  done;
}

# Send transmission object
# @param recipient list object
# @param api_key
# @param template id
function make_transmission_request() {
# REQUEST HEADERS
    unset POST_BODY;
    local HEADER_ACCEPT="Accept: application/json";
    local HEADER_CONTENT_TYPE="Content-Type: application/json";
    local HEADER_AUTHORIZATION="Authorization: $API_KEY";
    local RECIPIENT_LIST_ID=$1;
    local BODY_RETURN_PATH=$RETURN_PATH;

    # Open the body
    local POST_BODY="{";

    # RECIPIENTS
    RECIPIENTS='"recipients":{"list_id":"'$RECIPIENT_LIST_ID'"},';
    POST_BODY=$POST_BODY$RECIPIENTS;
    # TEMPLATE ID
    TEMPLATE='"content":{"template_id":"'$TEMPLATE_ID'"},';
    POST_BODY=$POST_BODY$TEMPLATE;
    # RETURN PATH
    RPATH='"return_path":"'$RETURN_PATH'"';
    POST_BODY=$POST_BODY$RPATH;

    # Close the body
    POST_BODY="$POST_BODY}";

    echo "OUR TRANSMISSION POST BODY: $POST_BODY";

    local curl_command=( curl -i -X POST -v -H "${HEADER_ACCEPT}" -H "${HEADER_CONTENT_TYPE}" -H "${HEADER_AUTHORIZATION}" -d "$POST_BODY" https://api.sparkpost.com/api/v1/transmissions )

    #echo "Running: ${curl_command[@]}"
    "${curl_command[@]}"

    echo $REPLY;
}

# Upsert recipient list object (does not offer PUT only GET and POST)
# @param recipient_list_id
# @param api_key
function make_recipient_list_request() {
# REQUEST HEADERS
    local HEADER_ACCEPT="Accept: application/json";
    local HEADER_CONTENT_TYPE="Content-Type: application/json";
    local HEADER_AUTHORIZATION="Authorization: $API_KEY";
    local R_LIST=$(echo $1 | tr -d '\n');

    # Open the body
    local POST_BODY="{";

    # Concatenate the list to the opening of the post body
    local INC_R_LIST="\"recipients\":[$R_LIST]";
    POST_BODY=$POST_BODY$INC_R_LIST;

    # If we have a list name, use it when creating
    if [ -n $RECIPIENT_LIST_NAME ]; then
        local INC_R_LIST_NAME=",\"name\":\"$RECIPIENT_LIST_NAME\"";
        POST_BODY=$POST_BODY$INC_R_LIST_NAME;
    fi

    # If we have a list description, use it when creating
    if [ -n $RECIPIENT_LIST_DESCRIPTION ]; then
        local INCLUDE_DESC=',"description":"'"$RECIPIENT_LIST_DESCRIPTION"'"';
    else
        local INLCUDE_DESC='';
    fi

    # Concatenate the values
    POST_BODY="$POST_BODY$INCLUDE_LIST$INCLUDE_NAME$INCLUDE_DESC";

    # Close the body
    POST_BODY="$POST_BODY}";

    #echo "OUR POST BODY: $POST_BODY";

    # USE -i curl option to see complete output
    local curl_command=( curl -X POST -v -H "${HEADER_ACCEPT}" -H "${HEADER_CONTENT_TYPE}" -H "${HEADER_AUTHORIZATION}" -d "$POST_BODY" https://api.sparkpost.com/api/v1/recipient-lists )

    #echo "Running: ${curl_command[@]}"
    "${curl_command[@]}"

    echo $REPLY;
}

# Lowercase words using POSIX compliant command
# @param word to lowercase
function to_lowercase() {
    # Lowercases the first parameter given to it
    echo $1 | tr '[:upper:]' '[:lower:]';
}

# Search for a needle in the haystack
# @param needle (string to find)
# @param haystack (array to search within)
# @return 0 if found, 1 if not found
function search_array() {
    local INDEX=0;
    local RESULT=-1;
    local NEEDLE=$1;
    local HAYSTACK=$2;

    while [ "$INDEX" -lt "${#HAYSTACK[@]}" ]; do
        local LCV=$(to_lowercase ${HAYSTACK[$INDEX]});
        if [ "$LCV" == "$NEEDLE" ]; then
            RESULT=$INDEX;
        fi
        let "INDEX++";
    done;
    echo $RESULT;
}

# Invalidation for header row of recipient list
# @param line (the first row of the .csv file which should be headers)
# @return 0 for passing invalidation, 1 for failing invalidation (default)
function invalidate_header_row() {
    local INDEX=0;
    local RESULT=-1;
    local INVALIDATION_PASS=1;
    local OPTIONAL_FIELDS_INCLUDED=1;

    IFS=$DELIMITER;
    read && LINE=$REPLY;
    local H_ROW=($LINE);

    # Validation requirements
    local REQUIRED_HEADER_VALUES=("recipient_email_address");
    local ACCEPTED_HEADER_VALUES=("email","emails","email address","emailaddress","email_address","email-address","name","recipient_name","to_name","to name","metadata","meta data","meta","address","email","return_path","returnpath","return path","tags","segment","segmentation","segmentations","substitution_data","substitution-data","substitutiondata","subdata","sub-data","personalization","tokens","customdata","custom_data","custom-data");

    while [ "$INDEX" -lt "${#H_ROW[@]}" ]; do
        local LOWERCASE_TEST_VALUE=$(to_lowercase ${H_ROW[$INDEX]});

        # Check if optional fields were included
        if [ $LOWERCASE_TEST_VALUE != ${REQUIRED_HEADER_VALUES[0]} ]; then
            OPTIONAL_FIELDS_INCLUDED=0; # 0 is true
        fi

        # TODO: We have optional fields, we need to handle them
        if [ !$OPTIONAL_FIELDS_INCLUDED ]; then
            local TEST=$(search_array $LOWERCASE_TEST_VALUE $REQUIRED_HEADER_VALUES);
            [ 0 -eq $TEST ] && RESULT=$INDEX;
        fi

        if [ -1 != $RESULT ] && [ 1 == $INVALIDATION_PASS ]; then
            # failed the invalidation, assign the failure code
            INVALIDATION_PASS=1;
        else
            # passed the invalidation, assign the success code
            INVALIDATION_PASS=0;
        fi
        let "INDEX++";
    done;

    # Make sure we have a .csv with at MINIMUM the "emailAddress" field
    if [ 1 == $INVALIDATION_PASS ]; then
        echo "The CSV file provided must contain one of the valid header names";
        exit 99
    else
        echo $RESULT;
    fi; 
}

function convert_file() {
    local COUNT=0; # row counter
    local INDEX=0; # field counter
    local POS=0; # character counter
    local SIMPLE=1; # `0` if current cell is quoted, `1` if it's simple.
    local LINE; # Current line being processed.
    local OUT; # Value of a cell.

    # Process header.
    read;
    local COLS=$(count_header_cols "$REPLY");

    # Replace the "recipient_email_address" header name with the "address" field in the converted JSON
    local ATTR=$(to_lowercase $REPLY);
    ATTR=${ATTR/"recipient_email_address"/"address"};

    # Setup the delimiter and create an array of the first row
    IFS=$DELIMITER;

    # Read and process lines.
    read && LINE=$REPLY;

    # Go through each line
    while [ -n "$LINE" ]; do
        # If we have a new line and are not at the end of the list add a comma
        [ $COUNT -gt 0 ] && echo $n ',';
        ADDRESS='';
        SD_PREFIX="\"substitution_data\":{";

        while [ $INDEX -lt $COLS ]; do
            # Set the defaults see the local variable declarations for more info
            SIMPLE=1 && POS=0;

            # If this is a complex cell, unset the simple flag and strip the leading double quote.
            # We just check the first character of the field to see if it is wrapped in double
            # quotes to determine if it is a simple or complex field.
            [ "${LINE:0:1}" == '"' ] && SIMPLE=0 && LINE=${LINE:1};

            # Walk the line, striping off completed cells
            while [ $POS -lt ${#LINE} ]; do
                # Does not require additional escaping
                if [ $SIMPLE == 1 ]; then
                    # If we have hit a comma than we are at the end of the field, set the out and move on
                    if [ "${LINE:$POS:1}" == ',' ]; then
                        OUT=${LINE:0:$POS} && LINE=${LINE:$((POS+1))} && break;
                        # Using -a in the conditional to do an AND operator
                        # We are seeing if the next position puts us into the next line and if
                        # the current field count puts us into the next field
                    elif [ $((POS+1)) == ${#LINE} -a $((INDEX+1)) == $COLS ]; then
                        # TODO error handling if a line is missing cells.
                        OUT=${LINE:0:$((POS+1))} && LINE=${LINE:$POS} && break;
                    fi
                else
                    # Two double quotes are an `escaped` quote, switch to JSON escapes.
                    if [ $((POS+1)) -lt ${#LINE} -a "${LINE:$POS:2}" == '""' ]; then
                        ESCAPED='\"';
                        # Inject the escape delimiters here
                        LINE="${LINE:0:$POS}$ESCAPED${LINE:$((POS+2))}"
                        # Bump the position of the character index
                        POS=$((POS+1));
                    elif [ "${LINE:$POS:1}" == '"' ]; then
                        # Sometimes there will be an unescaped quote in the middle of a
                        # cell. This isn't allowed, but we're going to tolerate it for now.
                        # TODO Remove this.
                        if [ "${LINE:$POS:2}" != '",' -a $((POS+1)) != ${#LINE} ]; then
                            ESCAPED='\"';
                            LINE="${LINE:0:$POS}$ESCAPED${LINE:$((POS+1))}";
                            POS=$((POS+2)) && continue;
                        fi
                        OUT=${LINE:0:$POS} && LINE=${LINE:$((POS+2))} && break;
                    fi
                    # If we don't have output and we're at the end of the line we've got
                    # a line break in the cell, so pull the next line in.
                    if [ -z "$OUT" -a $((POS+1)) == ${#LINE} ]; then
                        read && LINE="$LINE\n$REPLY";
                    fi
                fi
                POS=$((POS+1));
            done; # INSIDE CELL LOOP

            # if we are at the first field in a row, we need to mark it as such
            [ $INDEX == 0 ] && printf '%s' "{";

            # if it is not the first field in the index, we need to add a comma
            #[ $INDEX -gt 0 ] && printf '%s' ',';

            # Set the field delimiter to zero-length string
            IFS='';

            # Print "address":"<recipient_email_address>"
            if [ $INDEX == $EMAIL_ADDRESS_FIELD_INDEX ]; then
                ADDRESS="$(get_attribute $INDEX "$ATTR"):\"$OUT\"";
            else
                CURR_SUB_DATA_VAL="$(get_attribute $INDEX "$ATTR"):\"$OUT\"";
                SD=$SD$CURR_SUB_DATA_VAL",";
            fi

            # We are printing the key:value pair (use the field name)
            #printf '%s' "$(get_attribute $INDEX "$ATTR"): \"$OUT\"";

            unset OUT;
            unset CURR_SUB_DATA_VAL;
            INDEX=$((INDEX+1));
        done; # INSIDE FIELD LOOP
        printf $ADDRESS",";
        printf $SD_PREFIX;
        printf $SD"}";
        printf $n "}" && COUNT=$((COUNT+1));
        unset SD;
        unset LINE && read && LINE=$REPLY && INDEX=0;
    done; #INSIDE ROW LOOP
    echo $n;
}

# No source file provided, just send JSON to stdout
if [ -f $SOURCE_CSV ]; then
    # First we need to invalidate the header row of the .csv file (which is required)
    EMAIL_ADDRESS_FIELD_INDEX="$(cat "$1" | invalidate_header_row)"; # Should end script execution if failed

    # If the header invalidation passes, we should continue to convert the CSV to JSON
    RECIPIENT_LIST="$( cat "$1" | convert_file )"

    HTTP_RESPONSE="$(make_recipient_list_request "$RECIPIENT_LIST")";
    # TODO: Need to parse the response and pluck out the recipient_list_id
    echo "$HTTP_RESPONSE" > create_recipient_list_response.json;

    # Extract the ID
    RECIPIENT_LIST_ID="$( egrep -o [[:digit:]]{17} ./create_recipient_list_response.json )";
    #echo "EXTRACTED RECIPIENT_LIST_ID: $RECIPIENT_LIST_ID";

    # TODO: Need to use the recipient_list_id as a param to the transmission object request
    TX_RESPONSE="$(make_transmission_request "$RECIPIENT_LIST_ID")";
    echo $TX_RESPONSE;

    IFS=$OIFS;
else
    echo "Not a valid file.";
    IFS=$OIFS;
    exit 1;
fi
