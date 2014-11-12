BASH-Import-Script
==================

BASH script to import a CSV and convert it to a Recipient List and delivery a Transmission with SparkPost.

## How to use this

1. Clone the repository
```
git clone https://github.com/SparkPost/sparkpost-csv2tx.git
```

2. Add your information into the "testPeople.csv" using the headers (first row) as a guide

3. Have your SparkPost API Key handy. Need to create a key? Visit: [SparkPost-Creating an API Key](https://sparkpost.com/docs/create-api-key).

4. Create a template in SparkPost (either using the API or the UI). The ID is the "name" of the template.

5. Run the following command from the command line:
```
sh ./csv2tx.sh testPeople <your API Key> <name of new recipient list> <description of new recipient list> <sparkPost template id> <returnPath@yourSendingDomain.tld>
```

This script will:

* Parse the .csv file
* Create JSON which can be used to create a Recipient List Object in SparkPost
    * Translates "recipient_email_address" to "address"
    * Translates ALL OTHER FIELDS into "substitution_data" (lowercases all the keys)
* Creates a new Recipient List with the provided information
* Uses the ID of the newly created Recipient List object in addition to the Template ID you provide to send a transmission using SparkPost


## Issues and Contributing

Please use the Github Issue Tracker (https://github.com/SparkPost/sparkpost-csv2tx/issues) if you find issues.

Please fork this repository and submit pull requests if you would like to contribute to the source code.

### Author

Message Systems, LLC
    Benjamin Dean @bdeanindy

### License
MIT
