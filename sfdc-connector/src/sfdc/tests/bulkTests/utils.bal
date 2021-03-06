// Copyright (c) 2020 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/log;
import ballerina/test;
import ballerina/lang.'xml as xmllib;
import ballerina/java;
import ballerina/java.arrays as jarrays;

json[] jsonQueryResult = [];
xml xmlQueryResult = xml `<test/>`;
string csvQueryResult = "";

function closeRb(io:ReadableByteChannel ch) {
    var cr = ch.close();
    if (cr is error) {
        log:printError("Error occured while closing the channel: ", err = cr);
    }
}

function checkBatchResults(Result[] results) returns boolean {
    foreach Result res in results {
        if (!res.success) {
            log:printError("Failed result, res=" + res.toString(), err = ());
            return false;
        }
    }
    return true;
}

function checkCsvResult(string result) returns int {
    handle lineArray = split(java:fromString(result), java:fromString("\n"));
    int arrLength = jarrays:getLength(lineArray);
    return arrLength - 1;
}

function getContactIdByName(string firstName, string lastName, string title) returns @tainted string {
    string contactId = "";
    string sampleQuery = "SELECT Id FROM Contact WHERE FirstName='" + firstName + "' AND LastName='" + lastName 
        + "' AND Title='" + title + "'";
    QueryClient queryClient = baseClient->getQueryClient();
    SoqlResult|Error res = queryClient->getQueryResult(sampleQuery);

    if (res is SoqlResult) {
        SoqlRecord[]|error records = res.records;
        if (records is SoqlRecord[]) {
            string id = records[0]["Id"].toString();
            contactId = id;
        } else {
            test:assertFail(msg = "Getting contact ID by name failed. err=" + records.toString());            
        }
    } else {
        test:assertFail(msg = "Getting contact ID by name failed. err=" + res.toString());
    }
    return contactId;
}

function getJsonContactsToDelete(json[] resultList) returns json[] {
    json [] contacts = [];
    foreach var item in resultList {
        string id = item.Id.toString();
        contacts[contacts.length()] = {"Id":id};
    }
    return contacts;
}

function getXmlContactsToDelete(xml resultList) returns xml {
    xmllib:Element contacts = <xmllib:Element> xml `<sObjects xmlns="http://www.force.com/2009/06/asyncapi/dataload"/>`;

    xmlns "http://www.force.com/2009/06/asyncapi/dataload" as ns;

    xmllib:Element ele = <xmllib:Element>resultList;
    foreach var item in ele.getChildren().elements() {
        if (item is xml) {
            string id = (item/<ns:Id>[0]/*).toString();
            xml child = xml `<sObject><Id>${id}</Id></sObject>`;
            contacts.setChildren(contacts.getChildren() + child);
        }
        
    }
    return contacts;
}

function getCsvContactsToDelete(string resultString) returns string {
    string contacts = "Id";
    handle lineArray = split(java:fromString(resultString), java:fromString("\n"));
    int arrLength = jarrays:getLength(lineArray);
    int counter = 1;
    while (counter < arrLength) {
        string? line = java:toString(jarrays:get(lineArray, counter));
        if (line is string) {
            int? inof = line.indexOf(",");
            if (inof is int) {
                string id = line.substring(0, inof);
                contacts = contacts.concat("\n",id);
            }
        }
        counter = counter + 1;
    }
    return contacts;
}
